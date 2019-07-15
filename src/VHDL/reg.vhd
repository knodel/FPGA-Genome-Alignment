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
-- Simple implementation of an register
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity reg_impl is
	generic(
		WIDTH : positive := 16
	);
	
   Port ( 
		clk 		: in	STD_LOGIC;
      res 		: in	STD_LOGIC;
      q_in 		: in	STD_LOGIC_VECTOR (WIDTH-1 downto 0);
      q_out 	: out	STD_LOGIC_VECTOR (WIDTH-1 downto 0);
      enable 	: in	STD_LOGIC
	);
end reg_impl;

architecture Behavioral of reg_impl is

	signal q :  STD_LOGIC_VECTOR (WIDTH-1 downto 0);

begin

	q_out <= q;

	process(clk, res, enable)
	begin
		if rising_edge(clk) then
			if res = '1' then
				q <= (others => '0');
			elsif enable = '1' then
				q <= q_in;
			end if;
		end if;
	end process;

end Behavioral;
