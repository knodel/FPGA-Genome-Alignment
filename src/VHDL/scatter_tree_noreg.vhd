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
-- Scatter tree without registers in the nodes.
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity scatter_tree_noreg is
	generic(
		DATA_WIDTH 		: positive := 8; 
		MODULES			: positive := 8;
		FANOUT			: positive := 2
	);
   Port ( 
		clk 					: in  STD_LOGIC;
		scatter_data_in 	: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
      scatter_data_out	: out STD_LOGIC_VECTOR((DATA_WIDTH*MODULES-1) downto 0)
	);
end scatter_tree_noreg;

architecture Behavioral of scatter_tree_noreg is

	function min(arg1 : integer; arg2 : integer) return integer is
	begin
		if arg1 < arg2 then 
			return arg1; 
		else
			return arg2;
		end if;
	end;

	function node2level(arg : positive) return natural is
		variable tmp : positive;
		variable log : natural;
	begin
		if arg = 1 then
			return 1;
		end if;
    
		tmp := 1;
		log := 1;

		while arg > tmp-1 loop
			tmp := tmp * 2;
			log := log + 1;
		end loop;
		return log-1;
	end;

	subtype datapath is std_logic_vector(DATA_WIDTH-1 downto 0);
	type path is array(natural range<>) of datapath;

begin

	---------------------------SCATTER----------------------------------------------------------------------
	scatter: block

		constant D : positive := FANOUT;-- Node Fan in/out
		constant M : positive := 1+((MODULES-2)/(D-1)); --internal node count

		signal tree: path(0 to (M+MODULES-1));
		
	begin
		--root connection
		tree(0) <= scatter_data_in;
			
		--generate leaves 
		genLeaves: for b in 0 to MODULES-1 generate
			scatter_data_out((b*DATA_WIDTH)+DATA_WIDTH-1 downto b*DATA_WIDTH) <= tree(M+b);
		end generate genLeaves;

		--internal nodes
		genNodes: for b in 0 to M-1 generate
			constant CHILD_FIRST : positive := D*b+1;
			constant CHILD_LAST 	: positive := min(D*b+D, M+MODULES-1);
			constant CHILD_COUNT : positive := CHILD_LAST-CHILD_FIRST+1;
			
			constant LEVEL 		: integer 	:= node2level(b+1)-1;
			
			signal tree_reg : datapath;
				
		begin
		
		--reg: if (LEVEL = 5) generate
			--begin
				--Data Register
--				process(clk)
--				begin
--					if rising_edge(clk) then
						tree_reg <= tree(b);
--					end if;
--				end process;
			--end generate; 
			
--		noreg: if (LEVEL /= 5) generate
--			begin
--				tree_reg <= tree(b);
--			end generate; 
			
			
			--Every child gets the same data
			genDistribution: for i in CHILD_FIRST to CHILD_LAST generate
				tree(i) <= tree_reg;
			end generate genDistribution;
		end generate genNodes;
		
	end block scatter;

end Behavioral;