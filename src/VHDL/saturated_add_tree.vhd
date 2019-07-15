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
-- saturated add/count tree with a 3x2 adder-LUT in the first
-- layer and 2x3 saturated adder LUTs in the next four layers.
-- One register after the secont layer in the pipeline
-- enables a high frequency.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity saturated_add_tree is
    Port (
		clk				: in	STD_LOGIC; 
		vector_in 		: in	STD_LOGIC_VECTOR (63 downto 0);
      vector_out 		: out	STD_LOGIC_VECTOR (2 downto 0)
	 );
end saturated_add_tree;

architecture Behavioral of saturated_add_tree is

	component LUT_3E_add is
		Port ( 
			e : in  STD_LOGIC_VECTOR (5 downto 0);
			a : out  STD_LOGIC_VECTOR (2 downto 0)
		);
	end component;
	
	component LUT_2 is
		Port ( 
			e : in  STD_LOGIC_VECTOR (5 downto 0);
			a : out  STD_LOGIC_VECTOR (3 downto 0)
		);
	end component;
	
	component LUT_2E_sat is
		Port ( 
			e : in  STD_LOGIC_VECTOR (5 downto 0);
         a : out  STD_LOGIC_VECTOR (2 downto 0)
		);
	end component;
	
	component adder_carry is
		generic(
			OP_WIDTH : positive := 4 --breite eines Eingangsoperanden
		);
		port(
			e 	: IN 	STD_LOGIC_VECTOR((2*OP_WIDTH)-1 downto 0);
			a	: OUT	STD_LOGIC_VECTOR(OP_WIDTH downto 0)
		);
	end component;
	
	component addsat is
	  generic (
		 K : positive := 2;                            -- Number of Arguments
		 N : positive := 3;                            -- Bit Width of Arguments
		 M : positive := 3                             -- Bit Width of Result
	  );
	  port (
		 args : in  std_logic_vector(K*N-1 downto 0);  -- Arguments: arg_{k-1} & ...& arg_0
		 res  : out std_logic_vector(M  -1 downto 0)   -- Result
	  );
	end component;
	
	signal vector_0_in 	: STD_LOGIC_VECTOR(65 downto 0);--nach 1. LUT-Stufe
	signal vector_0 		: STD_LOGIC_VECTOR(32 downto 0);--nach 1. LUT-Stufe
	signal vector_0_reg	: STD_LOGIC_VECTOR(32 downto 0);
	
	signal vector_1		: STD_LOGIC_VECTOR(14 downto 0);--nach 2. LUT-Stufe
	signal vector_1_reg	: STD_LOGIC_VECTOR(17 downto 0);
	signal vector_2 		: STD_LOGIC_VECTOR(8 downto 0);--nach 1. ADD-Stufe
	signal vector_2_reg	: STD_LOGIC_VECTOR(8 downto 0);
	signal vector_3		: STD_LOGIC_VECTOR(2 downto 0);
	signal vector_3_reg	: STD_LOGIC_VECTOR(5 downto 0);
	
begin
	
	vector_0_in(65 downto 64) 	<= (others => '0');
	vector_0_in(63 downto 0) 	<= vector_in;

	layer_0:	for K in 0 to 10 generate
		lut_0:	LUT_3E_add port map(
			e	=>	vector_0_in((k*6)+5 downto k*6),
			a	=> vector_0((k*3)+2 downto K*3)
		);
	end generate;
	
	layer_1:	for K in 0 to 4 generate
		lut_1:	LUT_2E_sat port map(
			e	=>	vector_0((k*6)+5 downto k*6),
			a	=> vector_1((k*3)+2 downto K*3)
		);
	end generate;	
	
	process(clk)
	begin
		if rising_edge(clk) then
			vector_1_reg(14 downto 0) 	<= vector_1;
			vector_1_reg(17 downto 15) <= vector_0(32 downto 30); 	
		end if;
	end process;
	
	layer_2:	for K in 0 to 2 generate
		lut_2:	LUT_2E_sat port map(
			e	=>	vector_1_reg((k*6)+5 downto k*6),
			a	=> vector_2((k*3)+2 downto K*3)
		);
	end generate;
	
--	process(clk)
--	begin
--		if rising_edge(clk) then
			vector_2_reg <= vector_2;
--		end if;
--	end process;
	
	lut_3:	LUT_2E_sat port map(
		e	=>	vector_2_reg(5 downto 0),
		a	=> vector_3(2 downto 0)
	);
	
--	process(clk)
--	begin
--		if rising_edge(clk) then
			vector_3_reg(2 downto 0) <= vector_3;
			vector_3_reg(5 downto 3) <= vector_2(8 downto 6);
--		end if;
--	end process;
	
	
	lut_4:	LUT_2E_sat port map(
		e	=>	vector_3_reg(5 downto 0),
		a	=> vector_out(2 downto 0)
	);

end Behavioral;