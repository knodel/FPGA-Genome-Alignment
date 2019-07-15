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
-- Simple counter-implementation
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity count_impl is
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
end count_impl;

architecture Behavioral of count_impl is

	signal c : unsigned(COUNT_WIDTH-1 downto 0);

begin

	process(clk, res, count, set_zero, c)
	begin
		if rising_edge(clk) then
			if res = '1' then
				c <= conv_unsigned(0, COUNT_WIDTH);
			elsif set_zero = '1' then
				c <= conv_unsigned(0, COUNT_WIDTH);
			elsif count = '1' then
				c <= c + 1;
			end if;
		end if;
		counter <= conv_std_logic_vector(c, COUNT_WIDTH);
	end process;

end Behavioral;

