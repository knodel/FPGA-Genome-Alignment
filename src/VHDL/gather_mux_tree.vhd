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
-- Gather tree with a register in each node.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity gather_mux_tree is
	generic(
		DATA_WIDTH 		: positive := 2; 
		MODULES			: positive := 512;
		UNIT_WIDTH		: positive := 9
	);
   Port ( 
		clk 					: in  STD_LOGIC;
		
		gather_data_in 	: in  STD_LOGIC_VECTOR((MODULES*DATA_WIDTH-1) downto 0);
      gather_data_out	: out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		
      unit  				: in  STD_LOGIC_VECTOR (UNIT_WIDTH-1 downto 0)
	);
end gather_mux_tree;

architecture Behavioral of gather_mux_tree is

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
	
	subtype unitpath is std_logic_vector(UNIT_WIDTH-1 downto 0);
	type unitselect is array(natural range<>) of unitpath;	

begin

	gather: block

		constant D 			: positive := 2;-- Node Fan in/out must be 2
		constant M 			: positive := 1+((MODULES-2)/(D-1)); --internal node count

		signal tree			: path(0 to (M+MODULES-1));
		
		signal unit_tree 	: unitselect(0 to (M+MODULES-1));
			
	begin
		--root connection
		process(clk)
		begin
			if rising_edge(clk) then
				gather_data_out <= tree(0);
			end if;
		end process;
			
		--generate leaves 
		genLeaves: for b in 0 to MODULES-1 generate
			tree(M+b) 		<= gather_data_in((b*DATA_WIDTH)+DATA_WIDTH-1 downto b*DATA_WIDTH);
			unit_tree(M+b)	<= unit;
		end generate genLeaves;

		--internal nodes
		genNodes: for b in 0 to M-1 generate
			constant CHILD_FIRST : positive 	:= D*b+1;
			constant CHILD_LAST 	: positive 	:= min(D*b+D, M+MODULES-1);
			constant LEVEL 		: integer 	:= node2level(b+1)-1;
				
			signal node_in_1	: datapath;
			signal node_in_2	: datapath;
			signal node_out	: datapath;
			signal unit_node	: unitpath;
			signal sel			: std_logic;
			
		begin
		
			unit_node 	<= unit_tree(CHILD_FIRST);
			sel 			<= unit_node(UNIT_WIDTH-LEVEL-1); --UNIT_WIDTH-LEVEL-1
			node_in_1 	<= tree(CHILD_FIRST);
			node_in_2 	<= tree(CHILD_LAST);
			
			process(sel, node_in_1, node_in_2)
			begin
				if sel = '0' then
					node_out <= node_in_1;
				else
					node_out <= node_in_2;
				end if;
			end process;
			
			--reg: if (LEVEL = 5) generate
			--begin
				process(clk)
				begin
					if rising_edge(clk) then
						tree(b) 		 <= node_out;
						unit_tree(b) <= unit_node;
					end if;
				end process;
			--end generate; 
			
--			noreg: if (LEVEL /= 5) generate
--			begin
--				tree(b) 		 <= node_out;
--				unit_tree(b) <= unit_node;
--			end generate; 

		end generate genNodes;
		
	end block gather;

end Behavioral;



