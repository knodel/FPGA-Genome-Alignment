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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity delay_signal is
	generic (
		DELAY			 	: positive := 3
	);
   Port ( 
		clk 	: in  STD_LOGIC;
      res 	: in  STD_LOGIC;
      din 	: in  STD_LOGIC;
      dout 	: out STD_LOGIC
	);
end delay_signal;

architecture Behavioral of delay_signal is

	signal delay_i : std_logic_vector(DELAY downto 0);

begin

	delay_i(0) 	<= din; 
	dout 			<= delay_i(DELAY);

	genDelay: for i in 0 to DELAY-1 generate
		process(clk, res)
			begin
				if rising_edge(clk) then
					delay_i(i+1) <= delay_i(i);
				end if;
			end process;	
	end generate genDelay;
	

end Behavioral;

