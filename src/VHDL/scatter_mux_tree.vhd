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
-- Scatter tree with a multiplexer in every node. 
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

entity scatter_mux_tree is
	generic(
		DATA_WIDTH 		: positive := 1; 
		MODULES			: positive := 8;
		UNIT_WIDTH		: positive := 3
	);
   Port ( 
		clk 					: in  STD_LOGIC;
		scatter_data_in 	: in  STD_LOGIC_VECTOR(0 downto 0);
      scatter_data_out	: out STD_LOGIC_VECTOR ((MODULES - 1) downto 0);
		
      unit  				: in  STD_LOGIC_VECTOR (UNIT_WIDTH-1 downto 0)
	);
end scatter_mux_tree;

architecture Behavioral of scatter_mux_tree is

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

	signal tree_out	: std_logic_vector(MODULES-1 downto 0);
	
	subtype unitpath is std_logic_vector(UNIT_WIDTH-1 downto 0);
	type unitselect is array(natural range<>) of unitpath;

begin

	---------------------------SCATTER----------------------------------------------------------------------
	scatter: block

		constant D : positive := 2;-- Node Fan in/out
		constant M : positive := 1+((MODULES-2)/(D-1)); --internal node count

		signal tree: std_logic_vector((M+MODULES-1) downto 0);
		
		signal unit_tree 	: unitselect((M+MODULES-1) downto 0);
		
	begin
		--root connection
		tree(0) 			<= scatter_data_in(0);
		unit_tree(0) 	<= unit;
		
		--generate leaves 
		genLeaves: for b in 0 to MODULES-1 generate
			tree_out(b) <= tree(M+b);
		end generate genLeaves;

		scatter_data_out <= tree_out;

		--internal nodes
		genNodes: for b in 0 to M-1 generate
		
			constant CHILD_FIRST : positive 	:= D*b+1;
			constant CHILD_LAST 	: positive 	:= min(D*b+D, M+MODULES-1);
			constant LEVEL 		: integer 	:= node2level(b+1)-1;
			
			signal node_out	: std_logic_vector(1 downto 0);
			signal node_in		: std_logic;
			signal unit_node	: unitpath;
			signal sel			: std_logic;
			
		begin
		
			sel 					<= unit_node(UNIT_WIDTH-LEVEL-1);
			unit_node			<= unit_tree(b);
			node_in				<= tree(b);			
			
			process(sel, node_in)
			begin
				if sel = '0' then
					node_out <= "0" & node_in;
				else
					node_out <= node_in & "0";
				end if;
			end process;
			
			--reg: if (LEVEL = 5) generate
			--begin
				process(clk)
				begin
					if rising_edge(clk) then
						tree(CHILD_FIRST) <= node_out(0);
						tree(CHILD_LAST)	<= node_out(1);
						
						unit_tree(CHILD_FIRST) 	<= unit_node;
						unit_tree(CHILD_LAST)	<= unit_node;
					end if;
				end process;
			--end generate; 
			
--			noreg: if (LEVEL /= 5) generate
--			begin
--				tree(CHILD_FIRST) <= node_out(0);
--				tree(CHILD_LAST)	<= node_out(1);
--					
--				unit_tree(CHILD_FIRST) 	<= unit_node;
--				unit_tree(CHILD_LAST)	<= unit_node;
--			end generate; 
			
		end generate genNodes;
		
	end block scatter;

end Behavioral;

