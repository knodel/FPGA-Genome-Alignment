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


entity ctr_fifo is
	Port ( 
	  clk1 		: in  STD_LOGIC;
      clk2 		: in  STD_LOGIC;
	  res		: in 	STD_LOGIC;
      din1 		: in  STD_LOGIC_vector(2 downto 0);
      dout2 	: out STD_LOGIC_vector(2 downto 0);
      empty1 	: out STD_LOGIC;
      write1 	: in  STD_LOGIC;
      full2 	: out STD_LOGIC;
      read2 	: in  STD_LOGIC
	);
end ctr_fifo;

architecture Behavioral of ctr_fifo is

	signal data : STD_LOGIC_vector(2 downto 0);

begin

	process(clk1)
	begin
		if rising_edge(clk1) then
			if res = '1' then
				data 		<= (others => '0');
				empty1 	<= '1';
			else
				if write1 = '1' then
					data 		<= din1;
					empty1 	<= '0';
				end if;
			end if;
		end if;
	end process;

end Behavioral;

