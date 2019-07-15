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
-- Reduces the 32 bit width data input to 8 bit data out. The
-- ready signal shows the transmitter that one cycle is over.
-- Highest Byte in the 32 bit input is first Bayte in the
-- output.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity bus_reduce is
	Port(
		clk 		: in  STD_LOGIC;
      res 		: in  STD_LOGIC;
			  
      din 		: in  STD_LOGIC_VECTOR(31 downto 0);
      dout 		: out  STD_LOGIC_VECTOR(7 downto 0);
			 
		ready		: out STD_LOGIC;
      we_in 	: in  STD_LOGIC_vector(0 downto 0);
      we_out 	: out  STD_LOGIC_vector(0 downto 0));
end bus_reduce;

architecture Behavioral of bus_reduce is

	signal reg : std_logic_vector(31 downto 0);
	signal c : unsigned(1 downto 0);
	signal counter : std_logic_vector(1 downto 0);
	signal we_i : std_logic_vector(3 downto 0);
	

begin

	--schieberegister
	process(clk, res)
	begin
		if rising_edge(clk) then
			if res = '1' then
				we_i <= (others => '0');
				reg <= (others => '0');
			elsif we_in = "1" then
				we_i <= (others => '1');
				reg <= din;
			else
				reg <= reg(23 downto 0) & "00000000";
				we_i <= we_i(2 downto 0) & "0";
			end if;
		end if;
	end process;

	dout <= reg(31 downto 24);
	we_out(0) <= we_i(3);
	ready <= not we_i(3);

end Behavioral;

