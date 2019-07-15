-- MIT License
--
-- Copyright (c) 2019 Oliver Knodel
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE. 

--
-- Author: Oliver Knodel <oliver.knodel@mailbox.tu-dresden.de>
-- Project:	FPGA-DNA-Sequence-Search
--
-- Distribution of control- and data signals to the search units.
-- The distribution is organized in binary scatter- and gather trees
-- with a register in each node. Four search units share one text
-- register to reduce the hardware utilization.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity search_top is
	generic(
		WIDTH_TEXT 		: positive := 64; --ocrom: 64
		DOUBLE_UNITS 	: positive := 1 	--max: 350
	);
	Port ( 
		res				: in  STD_LOGIC;
		clk	 			: in  STD_LOGIC;
			
		--Text
		text_in 			: in STD_LOGIC_VECTOR(1 downto 0);
		control 			: in STD_LOGIC_VECTOR(8 downto 0);
		bus_free			: OUT std_logic;
		overflow			: OUT std_logic;

		--Block RAM
		unit 				: IN std_logic_VECTOR(8 downto 0);
		we					: IN std_logic_VECTOR(0 downto 0);
		din				: IN std_logic_VECTOR(31 downto 0);
		dout				: OUT std_logic_VECTOR(31 downto 0)
	);
end search_top;

architecture Behavioral of search_top is

	component double_unit is
		generic(
			WIDTH_TEXT 		: positive := 64 --ocrom: 64
		);
		PORT(
			res, clk 		: IN std_logic;
			
			control			: IN std_logic_vector(8 downto 0);
			text 				: IN std_logic_vector(127 downto 0);
			overflow 		: OUT std_logic;
			
			--Block RAM
			we					: IN std_logic_VECTOR(0 downto 0);
			din				: IN std_logic_VECTOR(7 downto 0);
			dout				: OUT std_logic_VECTOR(31 downto 0)		
		);
	end component;
	
	component text_shift_reg is
		generic(
			WB		: positive	:= 16
		);
		
		Port(	
			res, clk 	: in STD_LOGIC;
			start			: in STD_LOGIC;
			text_in		: in STD_LOGIC_VECTOR(1 downto 0);
			text_out		: out STD_LOGIC_VECTOR(WB-1 downto 0)
		);
	end component;
	
	component count_impl is
		generic(
			COUNT_WIDTH : positive := 10
		);
		Port ( 
			clk 		: in  STD_LOGIC;
			res 		: in  STD_LOGIC;
			set_zero : in  STD_LOGIC;
			count		: in  STD_LOGIC;
			counter	: out STD_LOGIC_VECTOR (COUNT_WIDTH-1 downto 0)
		);
	end component;
	
	component gather_mux_tree is
		generic(
			DATA_WIDTH 		: positive := 2; 
			MODULES			: positive := 8;
			UNIT_WIDTH		: positive := 3
		);
		Port ( 
			clk 					: in  STD_LOGIC;
			gather_data_in 	: in  STD_LOGIC_VECTOR((MODULES*DATA_WIDTH-1) downto 0);
			gather_data_out	: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
			unit  				: in  STD_LOGIC_VECTOR (UNIT_WIDTH-1 downto 0)
		);
	end component;
	
	component scatter_mux_tree is
		generic(
			DATA_WIDTH 		: positive := 1; 
			MODULES			: positive := 8;
			UNIT_WIDTH		: positive := 3
		);
		Port ( 
			clk 					: in  STD_LOGIC;
			scatter_data_in 	: in  STD_LOGIC_VECTOR(0 downto 0);
			scatter_data_out	: out STD_LOGIC_VECTOR ((MODULES - 1) downto 0);
			unit  				: in  STD_LOGIC_VECTOR (UNIT_WIDTH-1 downto 0)
		);
	end component;
	
	component scatter_tree is
		generic(
			DATA_WIDTH 		: positive := 8; 
			MODULES			: positive := 8;
			FANOUT			: positive := 2
		);
		Port ( 
			clk 					: in  STD_LOGIC;
			scatter_data_in 	: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
			scatter_data_out	: out STD_LOGIC_VECTOR((DATA_WIDTH*MODULES-1) downto 0)
		);
	end component;
	
	component scatter_tree_noreg is
		generic(
			DATA_WIDTH 		: positive := 8; 
			MODULES			: positive := 8;
			FANOUT			: positive := 2
		);
		Port ( 
			clk 					: in  STD_LOGIC;
			scatter_data_in 	: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
			scatter_data_out	: out STD_LOGIC_VECTOR((DATA_WIDTH*MODULES-1) downto 0)
		);
	end component;
	
	component gather_or_tree is
		generic(
			MODULES			: positive := 512
		);
		Port ( 
			clk 					: in  STD_LOGIC;
			gather_data_in 	: in  STD_LOGIC_VECTOR((MODULES-1) downto 0);
			gather_data_out	: out STD_LOGIC
		);
	end component;
	
	component bus_reduce is
		Port(
			clk 		: in  STD_LOGIC;
			res 		: in  STD_LOGIC;
				  
			din 		: in  STD_LOGIC_VECTOR(31 downto 0);
			dout 		: out  STD_LOGIC_VECTOR(7 downto 0);	 
			ready		: out STD_LOGIC;
			we_in 	: in  STD_LOGIC_VECTOR(0 downto 0);
			we_out 	: out  STD_LOGIC_VECTOR(0 downto 0));
	end component;

	signal text_all			: std_logic_vector((128*300)-1 downto 0);
	signal text_cluster_out	: std_logic_vector((128*75)-1 downto 0);
	signal text_cluster_in	: std_logic_vector((2*128)-1 downto 0);
	
	signal overflow_all		: std_logic_vector(512-1 downto 0);
	signal din_all				: std_logic_vector((8*512)-1 downto 0);
	signal din_i				: std_logic_vector(7 downto 0);
	
	signal mux_in				: std_logic_vector((512*32)-1 downto 0);
	signal mux_in_reg			: std_logic_vector((512*32)-1 downto 0);
	signal we_all				: std_logic_vector(511 downto 0);
	signal we_i					: std_logic_vector(0 downto 0);
	signal we_reg				: std_logic_vector(0 downto 0);
	signal unit_i				: STD_LOGIC_VECTOR(8 downto 0);
	signal mux_out_reg		: std_logic_vector(31 downto 0);
	
	signal bus_free_i			: std_logic;
	
	signal control_all		: STD_LOGIC_VECTOR((9*512)-1 downto 0);
	signal control_i			: STD_LOGIC_VECTOR(8 downto 0);
	
	signal start_shift		: std_logic;
			
begin

	start_shift 				<= control_i(3);
		
	process(clk)
	begin
		if rising_edge(clk) then
			unit_i 		<= unit;
			control_i 	<= control;
		end if;
	end process;
	
	 serialize: bus_reduce PORT MAP (
          clk 		=> clk,
          res 		=> res,
          we_in 	=> we,
          we_out 	=> we_i,
			 ready 	=> bus_free,
          din 		=> din,
          dout 	=> din_i
        );
	
	enable_scatter: scatter_mux_tree
		generic map(
			DATA_WIDTH 	=> 1,
			MODULES		=> 512,
			UNIT_WIDTH	=> 9
		)
		Port map( 
			clk 					=> clk,
			scatter_data_in 	=> we_i,
			scatter_data_out	=> we_all,
			unit  				=> unit_i
		);
		
	data_gather: gather_mux_tree
		generic map(
			DATA_WIDTH 		=> 32, 
			MODULES			=> 512,
			UNIT_WIDTH		=> 9
		)
		Port  map( 
			clk 					=> clk,
			gather_data_in 	=> mux_in,
			gather_data_out	=> dout,
			unit  				=> unit_i
		);
		
	control_scatter: scatter_tree
		generic map(
			DATA_WIDTH 		=> 9,
			MODULES			=> 512,
			FANOUT			=> 2
		)
		Port map( 
			clk 					=> clk,
			scatter_data_in 	=> control_i,
			scatter_data_out	=> control_all
		);
		
	------------------------------------------------------------
	text_scatter_1: scatter_tree
		generic map(
			DATA_WIDTH 		=> 2,
			MODULES			=> 128,
			FANOUT			=> 2
		)
		Port map( 
			clk 					=> clk,
			scatter_data_in 	=> text_in,
			scatter_data_out	=> text_cluster_in
		);
	
	text_cluster:	for K in 0 to 74 generate
		reg_text: text_shift_reg
		generic map (
			WB 		=> WIDTH_TEXT*2
		)
		port map(
			res 		=> res,
			clk 		=> clk,
			start 	=> start_shift,
			text_in	=> text_cluster_in((k*2)+1 downto k*2),
			text_out	=> text_cluster_out((k*128)+127 downto k*128)
		);	
	end generate;
	
	text_scatter_2_gen:	for K in 0 to 74 generate
		text_scatter_2: scatter_tree_noreg
		generic map(
			DATA_WIDTH 		=> 128,
			MODULES			=> 4,
			FANOUT			=> 2
		)
		Port map( 
			clk 					=> clk,
			scatter_data_in 	=> text_cluster_out((k*128)+127 downto k*128),
			scatter_data_out	=> text_all((k*512)+511 downto k*512)
		);
	end generate;
	-------------------------------------------------------------------------
	
	din_scatter: scatter_tree
		generic map(
			DATA_WIDTH 		=> 8,
			MODULES			=> 512,
			FANOUT			=> 2
		)
		Port map( 
			clk 					=> clk,
			scatter_data_in 	=> din_i,
			scatter_data_out	=> din_all
		);
		
	or_gather: gather_or_tree
		generic map (
			MODULES			=> 512
		)
		Port map( 
			clk 					=> clk,	
			gather_data_in 	=> overflow_all,
			gather_data_out	=> overflow
		);

	S:	for K in 0 to DOUBLE_UNITS-1 generate
		search_units: double_unit
			generic map (
				WIDTH_TEXT 	=> WIDTH_TEXT
			) port map(
				res 				=> res,
				clk 				=> clk,
				
				control			=> control_all((k*9)+8 downto k*9),	
				text				=> text_all((k*128)+127 downto k*128),
				overflow			=> overflow_all(k),
				
				we					=> we_all(k downto k),
				din				=> din_all((k*8)+7 downto k*8),
				dout				=> mux_in((k*32)+31 downto k*32)
			);
	end generate;
		

		
end Behavioral;

