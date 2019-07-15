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
-- The 8 bit width input signal and 32 width output signal.
-- First Byte is highest Byte in the output. 
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity bus_broad is
	Port ( 
		clk 	: in  STD_LOGIC;
      res 	: in  STD_LOGIC;
		we_in	: in 	STD_LOGIC_vector(0 downto 0);
		we_out: out STD_LOGIC_vector(0 downto 0);
		
		din 	: in 	STD_LOGIC_VECTOR(7 downto 0);
		dout	: out STD_LOGIC_VECTOR(31 downto 0)
	);
end bus_broad;

architecture Behavioral of bus_broad is

	signal reg		: STD_LOGIC_VECTOR(31 downto 0);
	signal counter : STD_LOGIC_VECTOR(1 downto 0);
	signal count	: STD_LOGIC;
	signal c			: unsigned(1 downto 0);

begin

	dout 		<= reg;

	we_out <= "1"	when counter = "11" else "0";
	
	process(clk, res)
	begin
		if rising_edge(clk) then
			if res = '1' then
				reg <= (others => '0');
			elsif we_in = "1" then
				reg <= reg(23 downto 0) & din;
			end if;
		end if;
	end process;
	
	process(clk)
	begin
		if rising_edge(clk) then
			if res = '1' then
				c <= conv_unsigned(0, 2);
			elsif we_in = "1" then
				c <= c + 1;
			end if;
			counter 	<= conv_std_logic_vector(c, 2);
		end if;
		
	end process;


end Behavioral;

