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

entity ctr_stream_buf is
   Port ( 
		stream_in 	: in  STD_LOGIC;
      stream_out 	: out  STD_LOGIC;
      clk_high 	: in  STD_LOGIC;
      clk_low 		: in  STD_LOGIC
	);
end ctr_stream_buf;

architecture Behavioral of ctr_stream_buf is

	signal stream : STD_LOGIC;

begin

	process(clk_high)
	begin
		if rising_edge(clk_high) then
			stream <= stream_in;
		end if;
	end process;

	process(clk_low)
	begin
		if rising_edge(clk_low) then
			stream_out <= stream;
		end if;
	end process;

end Behavioral;

