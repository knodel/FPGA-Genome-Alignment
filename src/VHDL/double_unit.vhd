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
-- Implementation of a search module containing a block RAM and
-- two search units (master and slave). 
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity double_unit is
	generic(
		WIDTH_TEXT : positive := 64
	);
	PORT(
		res, clk 	: IN std_logic;
		
		control		: IN std_logic_vector(8 downto 0);
		text 			: IN std_logic_vector(127 downto 0);
		overflow 	: OUT std_logic;
		
		--Block RAM
		we				: IN std_logic_VECTOR(0 downto 0);
		din			: IN std_logic_VECTOR(7 downto 0);
		dout			: OUT std_logic_VECTOR(31 downto 0)
				
	);
end double_unit;

architecture Behavioral of double_unit is

	component master_search_unit is
		generic(
			WIDTH_TEXT 		: positive := 64		
		);
		PORT(
				res, clk 		: IN std_logic;
				start_search 	: IN std_logic;
				load_data		: IN std_logic;
				finish_search	: IN std_logic;
				
				data_in 			: IN std_logic_vector(31 downto 0);
				text 				: IN std_logic_vector((WIDTH_TEXT*2)-1 downto 0);
				position			: IN std_logic_vector(31 downto 0);
				
				ram_write		: OUT std_logic_vector(0 downto 0);
				data_out 		: OUT std_logic_vector(31 downto 0);
				ram_adr			: OUT std_logic_vector(9 downto 0)
		);
	end component;
	
	component slave_search_unit is
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
	end component;
	
	component block_ram
		port (
			clka		: IN std_logic;
			wea		: IN std_logic_VECTOR(0 downto 0);
			addra		: IN std_logic_VECTOR(9 downto 0);
			dina		: IN std_logic_VECTOR(31 downto 0);
			douta		: OUT std_logic_VECTOR(31 downto 0);
			
			clkb		: IN std_logic;
			web		: IN std_logic_VECTOR(0 downto 0);
			addrb		: IN std_logic_VECTOR(9 downto 0);
			dinb		: IN std_logic_VECTOR(31 downto 0);
			doutb		: OUT std_logic_VECTOR(31 downto 0)
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
	
	component bus_broad is
		Port ( 
			clk 	: in  STD_LOGIC;
			res 	: in  STD_LOGIC;
			
			we_in	: in 	STD_LOGIC_VECTOR(0 downto 0);
			we_out: out STD_LOGIC_VECTOR(0 downto 0);
			din 	: in 	STD_LOGIC_VECTOR(7 downto 0);
			dout	: out STD_LOGIC_VECTOR(31 downto 0)
		);
	end component;

	--Block-Ram - master
	signal master_ram_write	: std_logic_vector(0 downto 0);
	signal master_data_in 	: std_logic_vector(31 downto 0);
	signal master_data_out 	: std_logic_vector(31 downto 0);
	signal master_ram_addr	: std_logic_vector(9 downto 0);
	
	--Block-Ram - slave
	signal slave_ram_write	: std_logic_vector(0 downto 0);
	signal slave_data_in 	: std_logic_vector(31 downto 0);
	signal slave_data_out 	: std_logic_vector(31 downto 0);
	signal slave_ram_addr	: std_logic_vector(9 downto 0);
	
	signal din_ram				: std_logic_vector(31 downto 0);
	signal data_out		 	: std_logic_vector(31 downto 0);
	signal data_in				: std_logic_vector(31 downto 0);
	signal sector_addr		: std_logic_vector(9 downto 0);
	signal mux_data_in		: std_logic_vector(31 downto 0);
	signal mux_ram_write		: std_logic_vector(0 downto 0);
	
	signal text_out 			: std_logic_vector((WIDTH_TEXT*2)-1 downto 0);
	signal position_reg		: std_logic_vector(31 downto 0);
	
	signal sector_addr_reg		: std_logic_vector(9 downto 0);
	signal master_ram_addr_reg	: std_logic_vector(9 downto 0);
	
	signal position				: std_logic_vector(31 downto 0);
	
	signal we_i		: std_logic_vector(0 downto 0);
	signal addr_i	: std_logic_vector(9 downto 0);
	signal din_i	: std_logic_vector(31 downto 0);
	
	--control signals
	signal control_i			: std_logic_vector(8 downto 0);
	signal control_reg		: std_logic_vector(8 downto 0);
	signal start_search		: std_logic;
	signal load_data			: std_logic;
	signal finish_search		: std_logic;
	signal ext_ram_access	: std_logic;
	signal double_reads		: std_logic;
	signal ram_sector			: std_logic;
	signal start_adr_count	: std_logic;
	signal set_pos_zero		: std_logic;
	signal count				: std_logic;
	signal addr_count			: std_logic;
	signal set_addr_zero		: std_logic;
	
begin

	start_search 				<= control_i(0);
	load_data 					<= control_i(1);
	finish_search 				<= control_i(2);
	ext_ram_access 			<= control_i(4);
	start_adr_count 			<= control_i(5);
	ram_sector					<= control_i(6);
	set_addr_zero 				<= control_i(7);
	set_pos_zero				<= control_i(8);
	
	data_in(31 downto 28) 	<= din_i(3 downto 0);
	data_in(27 downto 24) 	<= din_i(7 downto 4);
	data_in(23 downto 20) 	<= din_i(11 downto 8);
	data_in(19 downto 16) 	<= din_i(15 downto 12);
	data_in(15 downto 12) 	<= din_i(19 downto 16);
	data_in(11 downto 8) 	<= din_i(23 downto 20);
	data_in(7 downto 4) 		<= din_i(27 downto 24);
	data_in(3 downto 0) 		<= din_i(31 downto 28);

	dout(31 downto 28) 		<= data_out(3 downto 0);
	dout(27 downto 24) 		<= data_out(7 downto 4);
	dout(23 downto 20) 		<= data_out(11 downto 8);
	dout(19 downto 16) 		<= data_out(15 downto 12);
	dout(15 downto 12) 		<= data_out(19 downto 16);
	dout(11 downto 8) 		<= data_out(23 downto 20);
	dout(7 downto 4) 			<= data_out(27 downto 24);
	dout(3 downto 0) 			<= data_out(31 downto 28);
	
	slave_data_in 				<= data_out;
	
	count 		<= start_search;
	addr_count	<= start_adr_count or we_i(0);
		
	process(clk)
	begin
		if rising_edge(clk) then
			addr_i 		<= slave_ram_addr;--position(9 downto 0);
			control_i 	<= control;
		end if;
	end process;
	
	deserialize: bus_broad 
		port map(
			clk 	=> clk,
			res 	=> res,
			
			we_in	=> we,
			we_out=> we_i,
			din 	=> din,
			dout	=> din_i
		);
	
	process(clk)
	begin
		if rising_edge(clk) then
			if start_search = '1' then
				if (master_ram_addr = sector_addr) then--or (master_ram_addr >= "1111111110") then
					overflow <= '1';
				else
					overflow <= '0';
				end if;
			else
				overflow <= '0';
			end if;
		end if;
	end process;
	------------------------------------------------------------
	
	--sector address transformation (host/slave)
	process(ext_ram_access, ram_sector, slave_ram_addr, addr_i)
	begin
		if ext_ram_access = '1' then
			if ram_sector = '1' then
				sector_addr <= "1111111111" - addr_i;
			else
				sector_addr <= addr_i;
			end if;
		else
			sector_addr <= "1111111111" - slave_ram_addr;
		end if;
	end process;
	
	--data-in mux (host/slave)
	process(ext_ram_access, data_in, slave_data_out)
	begin
		case ext_ram_access is
			when '1' 	=> mux_data_in <= data_in;
			when '0' 	=> mux_data_in <= slave_data_out;
			when others => mux_data_in <= (others => '0');
		end case;
	end process;
	
	--we mux (host/slave)
	process(ext_ram_access, we_i, slave_ram_write)
	begin
		case ext_ram_access is
			when '1' 	=> mux_ram_write <= we_i;
			when '0' 	=> mux_ram_write <= slave_ram_write;
			when others => mux_ram_write <= (others => '0');
		end case;
	end process;
	
	------------------------------------------------------------------------
	
	text_out <= text;
	
	master: master_search_unit
		generic map (
			WIDTH_TEXT 		=> WIDTH_TEXT
		)port map(
			res 				=> res,
			clk 				=> clk,
			start_search	=> start_search,
			load_data 		=> load_data,
			finish_search	=> finish_search,
			
			data_in 			=> master_data_in,
			text 				=> text_out,
			position 		=> position,
			
			ram_write		=> master_ram_write,
			data_out			=> master_data_out,
			ram_adr			=> master_ram_addr
		);
		
	block_0 : block_ram
		port map (
			--master/host
			clka	 => clk,
			wea	 => mux_ram_write,
			addra	 => sector_addr,
			dina	 => mux_data_in,
			douta	 => data_out,
			
			--slave
			clkb 	 => clk,
			web  	 => master_ram_write,
			addrb  => master_ram_addr,
			dinb 	 => master_data_out,
			doutb  => master_data_in
		);
		
	slave: slave_search_unit
		generic map (
			WIDTH_TEXT 		=> WIDTH_TEXT
		)port map(
			res 				=> res,
			clk 				=> clk,
			start_search	=> start_search,
			load_data 		=> load_data,
			finish_search	=> finish_search,
			
			addr_count		=>	addr_count,
			set_addr_zero	=>	set_addr_zero,
			
			data_in 			=> slave_data_in,
			text 				=> text_out,
			position 		=> position,
			
			ram_write		=> slave_ram_write,
			data_out			=> slave_data_out,
			ram_adr			=> slave_ram_addr
		);
		
	position_counter: count_impl
		generic map (
			COUNT_WIDTH => 32
		)
		port map(
			res 		=> res,
			clk		=> clk,
			set_zero => set_pos_zero,
			count		=> count,
			counter	=> position
		);

end Behavioral;
