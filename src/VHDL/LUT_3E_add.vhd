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
-- Adder with three 2-bit width inputs realized in 6-input-LUTs
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity LUT_3E_add is
	Port ( 
		e : in  STD_LOGIC_VECTOR (5 downto 0);
      a : out  STD_LOGIC_VECTOR (2 downto 0)
	);
end LUT_3E_add;

architecture Behavioral of LUT_3E_add is

	function add_6 (signal input:  STD_LOGIC_VECTOR(5 downto 0)) return STD_LOGIC_VECTOR is
		variable result : STD_LOGIC_VECTOR(2 downto 0);
		begin
			case (input) is
			
				when "000000" 	=> result := "000";
				when "000001" 	=> result := "001";
				when "000010" 	=> result := "010";
				
				when "000100" 	=> result := "001";
				when "000101" 	=> result := "010";
				when "000110" 	=> result := "011";
				
				when "001000" 	=> result := "010";
				when "001001" 	=> result := "011";
				when "001010" 	=> result := "100";
				
				when "010000" 	=> result := "001";
				when "010001" 	=> result := "010";
				when "010010" 	=> result := "011";

				when "010100" 	=> result := "010";
				when "010101" 	=> result := "011";
				when "010110" 	=> result := "100";
				
				when "011000" 	=> result := "011";
				when "011001" 	=> result := "100";
				when "011010" 	=> result := "101";
				
				when "100000" 	=> result := "010";
				when "100001" 	=> result := "011";
				when "100010" 	=> result := "100";

				when "100100" 	=> result := "011";
				when "100101" 	=> result := "100";
				when "100110" 	=> result := "101";
				
				when "101000" 	=> result := "100";
				when "101001" 	=> result := "101";
				when "101010" 	=> result := "110";
				
				when others	=> result := "111";
				
			end case;
		return result;
	end add_6;

begin

	a	<= add_6(e);

end Behavioral;

