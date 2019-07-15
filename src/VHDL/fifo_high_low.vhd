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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity fifo_high_low is
	Port ( 
			clk_high : in  STD_LOGIC;
			clk_low 	: in  STD_LOGIC;
			din 		: in  STD_LOGIC;
			dout 		: out  STD_LOGIC
		);
end fifo_high_low;

architecture Behavioral of fifo_high_low is

	signal data1 : STD_LOGIC;
	signal data2 : STD_LOGIC;
	signal res	 : STD_LOGIC;
	
begin

	process(clk_high)
	begin
		if rising_edge(clk_high) then
			data1 <= din;
		end if;
	end process;
	
	process(clk_high)
	begin
		if rising_edge(clk_high) then
			if data1 = '1' then
				data2 <= '1';
			end if;
			if res = '1' then
				data2 <= '0';
			end if;
		end if;
--		if res = '1' then
--			data2 <= '0';
--		end if;
	end process;
	
	process(clk_low)
	begin
		if rising_edge(clk_low) then
			dout <= data2;
			if data2 = '1' then
				--dout <= '1';
				res <= '1';
			else
				res <= '0';
				--dout <= '0';
			end if;
		end if;
	end process;

end Behavioral;

