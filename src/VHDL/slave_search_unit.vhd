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
-- Slave search unit with LUTs containing the read and comparing
-- it with the text and a saturated counting tree counting the
-- mismatches. The difference to the master is the shared address
-- counter, for extern access to the block RAM. 
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity slave_search_unit is
	generic(
		WIDTH_TEXT 		: positive := 64
	);
	PORT(
			res, clk 		: IN std_logic;
			start_search 	: IN std_logic;
			load_data		: IN std_logic;
			finish_search	: IN std_logic;
			
			addr_count		: IN std_logic;
			set_addr_zero	: IN std_logic;
			
			data_in 			: IN std_logic_vector(31 downto 0);
			text 				: IN std_logic_vector((WIDTH_TEXT*2)-1 downto 0);
			position			: IN std_logic_vector(31 downto 0);
			
			ram_write		: OUT std_logic_vector(0 downto 0);
			data_out 		: OUT std_logic_vector(31 downto 0);
			ram_adr			: OUT std_logic_vector(9 downto 0)
	);
end slave_search_unit;

architecture Behavioral of slave_search_unit is

	component ocrom_chain is
	  generic (
		 WIDTH : positive := 2;              -- Data Width
		 ABITS : positive := 4               -- Address Bits
	  );
	  port (
		 -- Configuration
		 cclk  : in  std_logic;              -- Clock
		 cena  : in  std_logic;              -- Enable: Shift cdin on cclk
		 cdin  : in  std_logic;              -- Chain Input
		 cdout : out std_logic;              -- Chain Output

		 -- Data Output (Async without cclk and cena)
		 addr : in  std_logic_vector(ABITS-1 downto 0);
		 dout : out std_logic_vector(WIDTH-1 downto 0)
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
	
	component saturated_add_tree is
		 Port (
			clk				: in	STD_LOGIC; 
			vector_in 		: in	STD_LOGIC_VECTOR (63 downto 0);
			vector_out 		: out	STD_LOGIC_VECTOR (2 downto 0)
		 );
	end component;
	
	component read_reg is
		generic(
			WIDTH_IN		: positive := 32
		);
		Port ( 
			clk 		: in  STD_LOGIC;
			res 		: in  STD_LOGIC;
			q_in 		: in  STD_LOGIC_VECTOR (WIDTH_IN-1 downto 0);
			q_out 	: out  STD_LOGIC_VECTOR (WIDTH_IN-1 downto 0);
			enable 	: in  STD_LOGIC
		);
	end component;
	
	signal count					: STD_LOGIC;
	signal vector_in				: STD_LOGIC_VECTOR (WIDTH_TEXT-1 downto 0);
	signal ocrom_in				: STD_LOGIC_VECTOR (31 downto 0);
	
	signal mis_count				: STD_LOGIC_VECTOR (2 downto 0);
	signal mis_count_2			: STD_LOGIC_VECTOR (2 downto 0);
	
	signal counter					: std_logic_vector (9 downto 0);
	signal counter_res			: std_logic;
	
	signal count_i					: STD_LOGIC;
	signal counter_res_i			: std_logic;
	
	signal text_i 					: STD_LOGIC_VECTOR (127 downto 0);
	signal oc_ce					: std_logic; 
	
	signal position_i				: STD_LOGIC_VECTOR (31 downto 0);
	
	--mismatch-reg
	signal misreg_ce				: std_logic; 	-- Eneble fuer mismatch Register
	signal control_data			: std_logic_vector (3 downto 0);
	signal mismatch				: std_logic_vector (2 downto 0);
	signal control					: STD_LOGIC;
	signal control_data_in		: std_logic_vector (3 downto 0);
	
	signal min_mismatch			: std_logic_vector (2 downto 0);
	signal reset_min_mismatch 	: STD_LOGIC;
	
	type   tState is (idle, loading_reg, loading_ocrom1, loading_ocrom2, prepare_erase, 
								erase_ram, write_mismatch, write_info_prepare, write_info, 
								waiting, prepare_search, searching, disabled, reset);					
	signal state	 	: tState := idle;
	signal nextState	: tState;
	
begin
	
	--Aufteilung der Steuerdaten (vom Mismatch Register)
	mismatch 							<= control_data(2 downto 0);
	control								<= control_data(3);
	
	control_data_in(2 downto 0) 	<= data_in(2 downto 0);
	control_data_in(3) 				<= data_in(19);
	
	ocrom_in 							<= data_in;	
	
	--getakteter Prozess mit verzoegern des mismatch-zaehlers
	process(clk, res)
	begin
		if rising_edge(clk) then
			if res = '1' then
				state <= idle;
			else
				state	<= nextState;
			end if;
		end if;
	end process;
	
	--register for control information
	process(clk)
	begin
		if rising_edge(clk) then
			if res = '1' then
				control_data <= (others => '0');
			else
				if misreg_ce = '1' then
					control_data <= control_data_in;
				end if;
			end if;
		end if;
	end process;
	
	-- minimal-mismatch-count-register
	process(clk)
	begin
		if rising_edge(clk) then
			if res = '1' then 
				min_mismatch <= (others => '1');
			else
				if start_search = '1' then
					if mis_count < min_mismatch then
						min_mismatch <= mis_count;
					end if;
				elsif reset_min_mismatch = '1' then
					min_mismatch <= (others => '1');
				end if;
			end if;
		end if;
	end process;
	
	position_i <= position;
	
	--Counter for extern access 
	count_i			<= count	or addr_count;
	counter_res_i	<= counter_res or set_addr_zero;


	--Zustandsuebergaenge
	process(state, position_i, mis_count, mismatch, mis_count, start_search, load_data,
							control, counter, data_in, finish_search, min_mismatch)
	begin
	
		nextState 			 <= state;
		
		ram_write 			 <= "0";
		misreg_ce 			 <= '0';
		oc_ce 				 <= '0';
		reset_min_mismatch <= '0';
		
		count					 <= '0';
		counter_res			 <= '0';
		ram_adr				 <= counter(9 downto 0);
		
		data_out 			 <= (others => '0');
		
		case state is
			when reset =>
				counter_res	<= '1';
				reset_min_mismatch <= '1';
				nextState <= idle;
			
			when idle =>
--				counter_res	<= '1';
--				reset_min_mismatch <= '1';
				
				--new reads 
				if load_data = '1' then
					counter_res	<= '1';
					nextState 	<= loading_reg;
				end if;
				
				--only new run with old reads
				if start_search = '1' then
					nextState <= prepare_search;
				end if;
				
			when loading_reg =>
				misreg_ce 	<= '1';
				count 		<=	'1';
				nextState 	<= loading_ocrom1;
			
			when loading_ocrom1 =>
				count 		<=	'1';
				nextState 	<= loading_ocrom2;
				
			when loading_ocrom2 =>
				oc_ce <= '1';
				count <=	'1';
				if counter = conv_std_logic_vector(33, 10) then
					nextState <= prepare_erase;
				end if;
				
			when prepare_erase =>	
				counter_res	<= '1';
				nextState 	<= erase_ram;
				
			when erase_ram =>
				ram_write 	<= "1";
				count 		<=	'1';
				if counter = conv_std_logic_vector(33, 10) then
					nextState <= waiting;
				end if;
			
			when waiting =>
				counter_res	<= '1';
				if start_search = '1' then
					if control = '1' then
						nextState <= prepare_search;
					else
						nextState <= disabled;
					end if;
				end if;
			
			when disabled =>
				--counter_res	<= '1';
				if finish_search = '1' then
					nextState <= reset;
				end if;
				
			when prepare_search => 	--sets pointer for results on ram-address 1
				count 				 <= '1';
				nextState			 <= searching;
				
			when searching =>
				if mis_count <= mismatch then
					nextState <= write_mismatch;
				end if;
				if finish_search = '1' then
					nextState <= write_info_prepare;
				end if;
				
			when write_mismatch =>
				ram_write 	<= "1"; 
				data_out		<= position_i;
				count 		<=	'1';
				nextState 	<= searching;
				
			when write_info_prepare =>			--sets pointer on ram-address 0, without resetting it
				ram_adr		<= conv_std_logic_vector(0, 10);
				nextState 	<= write_info;
				
			when write_info =>
				ram_adr		<= conv_std_logic_vector(0, 10);
				ram_write 	<= "1";
				counter_res	<= '1';
				data_out(9 downto 0) 	<= counter - 1;
				data_out(18 downto 16)	<= min_mismatch;
				data_out(15 downto 10)	<= (others => '0');
				data_out(31 downto 19)	<= (others => '0');
				nextState <= reset;
				
			when others => 
				null;
				
		end case;
	end process;
	
	text_i <= text;
	--Komponenten-------------------------------------------------------
	
	ocrom_a: for K in 0 to 31 generate
		read_ocrom: ocrom_chain
		generic map(
			 WIDTH => 2,     -- Data Width
			 ABITS => 4      -- Address Bits
	  ) port map (
			 cclk  => clk,
			 cena  => oc_ce,
			 cdin  => ocrom_in(k),
			 addr  => text_i((k*4)+3 downto k*4),
			 dout  => vector_in((K*2)+1 downto K*2)
		  );
	end generate;
	
	add: saturated_add_tree
		port map (
			clk 				=> clk,
			vector_in 		=> vector_in,
			vector_out		=> mis_count
		);
			
	c: count_impl
	generic map(
		COUNT_WIDTH => 10
	) port map(
			res 		=> res,
			clk		=> clk,
			set_zero => counter_res_i,
			count		=> count_i,
			counter	=> counter
		);

end Behavioral;
