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
-- lcd-module with 32-bit width data input on the second line
-- and 4-bit input for visualization of a state in the first
-- line of the lcd
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity lcd_top is
	port(
		clk			: in std_logic;
		rst			: in std_logic;
		data			: in std_logic_vector(31 downto 0);
		lcd_state	: in std_logic_vector(3 downto 0);
		
		-- LCD
		lcd_dat		: inout std_logic_vector(3 downto 0);
		lcd_e			: out std_logic;
		lcd_rs		: out std_logic;
		lcd_rw		: out std_logic
	);
end lcd_top;


architecture Behavioral of lcd_top is

	component lcd4 is
	  port(
		 -- Global Reset and Clock
		 rst, clk	: in std_logic;

		 -- Upper Layer Interface
		 stb      : in  std_logic;
		 addr     : in  std_logic;
		 din      : in  std_logic_vector(7 downto 0);
		 rdy      : out std_logic;
		 
		 -- LCD Connections
		 lcd_e   : out   std_logic;                    -- Enable
		 lcd_rs  : out   std_logic;                    -- Register Select
		 lcd_rw  : out   std_logic;                    -- Read / Write
		 lcd_dat : inout std_logic_vector(3 downto 0)  -- Data
	  );
	end component;
	
	component lcd_control is
		port(
			 rst, clk : in std_logic;
			 lcd_state: in std_logic_vector(3 downto 0);
			 stb      : out  std_logic;
			 addr     : out  std_logic;
			 din      : out  std_logic_vector(7 downto 0);
			 rdy      : in std_logic;
			 dat_adr	 : in	std_logic_vector(31 downto 0)
		);
	end component;

	
	signal stb	:	std_logic;
	signal addr	:	std_logic;
	signal din	:	std_logic_vector(7 downto 0);
	signal rdy	:	std_logic;

begin

	interface: lcd4
		port map(
			rst 		=> rst,
			clk 		=> clk,
			
			stb  		=> stb,   
			addr    	=> addr,
			din     	=> din,
			rdy     	=> rdy,
			
			lcd_e   	=> lcd_e,
			lcd_rs  	=> lcd_rs,
			lcd_rw  	=> lcd_rw,
			lcd_dat 	=> lcd_dat
		);
		
	controller: lcd_control
		port map(
			rst		=> rst,
			clk		=> clk,
			lcd_state=> lcd_state,
			stb		=> stb,
			addr		=> addr,
			din		=> din,
			rdy		=> rdy,
			dat_adr	=> data
		);

end Behavioral;

