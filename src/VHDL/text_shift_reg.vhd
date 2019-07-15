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
-- Shift register with generic length of in- and output 
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity text_shift_reg is
generic(
		WB		: positive	:= 16;
		OUTB	: positive	:= 2
	);
	
	Port(	
		res, clk 	: in STD_LOGIC;
		start			: in STD_LOGIC;
		text_in		: in STD_LOGIC_VECTOR(1 downto 0);
			
		text_out		: out STD_LOGIC_VECTOR(WB-1 downto 0)
	);
end text_shift_reg;

architecture Behavioral of text_shift_reg is

signal q: std_logic_vector(WB-1 downto 0);

begin

	text_out <= q;

	--schieberegister
	process(clk, res)
	begin
		if rising_edge(clk) then
			if res = '1' then
				q <= (others => '0');
			elsif start = '1' then
				q <= q((WB-OUTB)-1 downto 0) & text_in;
			end if;
		end if;
	end process;

end Behavioral;

