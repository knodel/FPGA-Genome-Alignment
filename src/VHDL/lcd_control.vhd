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
-- Controller for initialization of the LCD and data-writing
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity lcd_control is
	port(
		 rst, clk : in std_logic;
		 lcd_state: in std_logic_vector(3 downto 0);
		 stb      : out std_logic;
		 addr     : out std_logic;
		 din      : out std_logic_vector(7 downto 0);
		 rdy      : in std_logic;
		 dat_adr	 : in	std_logic_vector(31 downto 0)
	);
end lcd_control;

architecture Behavioral of lcd_control is

	function ascii (signal input:  STD_LOGIC_VECTOR(3 downto 0)) return STD_LOGIC_VECTOR is
	variable result : STD_LOGIC_VECTOR(7 downto 0);
	begin
		case (input) is
			when x"0" => result := x"30";
			when x"1" => result := x"31";
			when x"2" => result := x"32";
			when x"3" => result := x"33";
			when x"4" => result := x"34";
			when x"5" => result := x"35";
			when x"6" => result := x"36";
			when x"7" => result := x"37";
			when x"8" => result := x"38";
			when x"9" => result := x"39";
			when x"A" => result := x"41";
			when x"B" => result := x"42";
			when x"C" => result := x"43";
			when x"D" => result := x"44";
			when x"E" => result := x"45";
			when x"F" => result := x"46";
			when others => result := x"00";		
		end case;
		return result;
	end ascii;

	type   tState is (init, init1, init2, init3, init4, init5, init6, init7, waiting, waiting1, waiting2,
								waiting3, waiting4, waiting5, waiting6, waiting7, waiting8, waiting9, waiting10,
								receive1, receive2, receive3, receive4, receive5, receive6, receive7, receive8, 
								send1, send2, send3, send4, send5,
								pos, pos1, pos2, pos3, pos4, pos5, pos6, pos7, pos8, pos9, pos10, pos11, pos12,
								pos13, pos14, pos15, pos16, pos17,
								search1, search2, search3, search4, search5, search6, search7, search8, search9, search10);
	signal state	 : tState := init;
	signal nextState : tState;

begin

	--getakteter Prozess zur steuerung der Statemachine
	process(clk, rst)
	begin
	if rising_edge(clk) then
		if rst = '1' then
			state <= init;
		else
			state <= nextState;
		end if;
	end if;
	end process;

	--Zustandsuebergaenge
	process(state, rdy, lcd_state, dat_adr)
	begin
		nextState <= state;
		addr <= '0';
		stb <= '0';
		din <= "00000000";	
		
		case state is
		
			---------------------   initialisierung   ----------
	
			when init =>
				if rdy = '1' then
					nextState <= init1;
				end if;
			
			when init1 =>
				stb <= '1';
				din <= "00101100";--Function Set (4 Bit interface, 2-line, 5x11 dots)
				if rdy = '1' then
					nextState <= init2;
				end if;
			
			when init2 =>
				stb <= '1';
				din <= "00101100";--Function Set
				if rdy = '1' then
					nextState <= init3;
				end if;
			
			when init3 =>
				stb <= '1';
				din <= "00101100";--Function Set
				if rdy = '1' then
					nextState <= init4;
				end if;
				
			when init4 =>
				stb <= '1';
				din <= "00101100";--Function Set
				if rdy = '1' then
					nextState <= init5;
				end if;
			
			when init5 =>
				stb <= '1';
				din <= "00001100";--display on, cursor off, blink off
				if rdy = '1' then
					nextState <= init6;
				end if;
				
			when init6 =>
				stb <= '1';
				din <= "00000001";--clear display
				if rdy = '1' then
					nextState <= init7;
				end if;
				
			when init7 =>
				stb <= '1';
				din <= "00000110"; --entire shift off
				if rdy = '1' then
					nextState <= waiting; 
				end if;
			
			---------------------   initialisierung abgeschlossen   ----------
			
			when waiting =>
				if lcd_state = x"1" then
					nextState <= waiting1;
				elsif lcd_state = x"2" then
					nextState <= receive1;
				elsif lcd_state = x"3" then
					nextState <= send1;
				elsif lcd_state = x"4" then
					nextState <= waiting1;
				elsif lcd_state = x"5" then
					nextState <= search1;
				else
					nextState <= pos;
				end if;
				
			---------------------   waiting   ----------	
				
			when waiting1 =>
				stb <= '1';
				addr <= '0';
				din <= "10000000";--zeile ("11000000";--zeile 2)
				if rdy = '1' then
					nextState <= waiting2;
				end if;
				
			when waiting2 =>
				stb <= '1';
				addr <= '1';
				din <= x"77";--w
				if rdy = '1' then
					nextState <= waiting3;
				end if;
				
			when waiting3 =>
				stb <= '1';
				addr <= '1';
				din <= x"61";--a
				if rdy = '1' then
					nextState <= waiting4;
				end if;
				
			when waiting4 =>
				stb <= '1';
				addr <= '1';
				din <= x"69";--i
				if rdy = '1' then
					nextState <= waiting5;
				end if;
				
			when waiting5 =>
				stb <= '1';
				addr <= '1';
				din <= x"74";--t
				if rdy = '1' then
					nextState <= waiting6;
				end if;
				
			when waiting6 =>
				stb <= '1';
				addr <= '1';
				din <= x"69";--i
				if rdy = '1' then
					nextState <= waiting7;
				end if;
				
			when waiting7 =>
				stb <= '1';
				addr <= '1';
				din <= x"6E";--n
				if rdy = '1' then
					nextState <= waiting8;
				end if;

			when waiting8 =>
				stb <= '1';
				addr <= '1';
				din <= x"67";--g
				if rdy = '1' then
					nextState <= waiting9;
				end if;	

			when waiting9 =>
				stb <= '1';
				addr <= '1';
				din <= x"a0";--leer
				if rdy = '1' then
					nextState <= waiting10;
				end if;	
				
			when waiting10 =>
				stb <= '1';
				addr <= '1';
				din <= x"a0";--leer
				if rdy = '1' then
					nextState <= pos;
				end if;	
			
			---------------------   receive   ----------	
				
			when receive1 =>
				stb <= '1';
				addr <= '0';
				din <= "10000000";--zeile ("11000000";--zeile 2)
				if rdy = '1' then
					nextState <= receive2;
				end if;
				
			when receive2 =>
				stb <= '1';
				addr <= '1';
				din <= x"72";--r
				if rdy = '1' then
					nextState <= receive3;
				end if;
				
			when receive3 =>
				stb <= '1';
				addr <= '1';
				din <= x"65";--e
				if rdy = '1' then
					nextState <= receive4;
				end if;
				
			when receive4 =>
				stb <= '1';
				addr <= '1';
				din <= x"63";--c
				if rdy = '1' then
					nextState <= receive5;
				end if;
				
			when receive5 =>
				stb <= '1';
				addr <= '1';
				din <= x"65";--e
				if rdy = '1' then
					nextState <= receive6;
				end if;
				
			when receive6 =>
				stb <= '1';
				addr <= '1';
				din <= x"69";--i
				if rdy = '1' then
					nextState <= receive7;
				end if;
				
			when receive7 =>
				stb <= '1';
				addr <= '1';
				din <= x"76";--v
				if rdy = '1' then
					nextState <= receive8;
				end if;

			when receive8 =>
				stb <= '1';
				addr <= '1';
				din <= x"65";--e
				if rdy = '1' then
					nextState <= pos;
				end if;
				
			---------------------   send   ----------	
				
			when send1 =>
				stb <= '1';
				addr <= '0';
				din <= "10000000";--zeile ("11000000";--zeile 2)
				if rdy = '1' then
					nextState <= send2;
				end if;
				
			when send2 =>
				stb <= '1';
				addr <= '1';
				din <= x"73";--s
				if rdy = '1' then
					nextState <= send3;
				end if;
				
			when send3 =>
				stb <= '1';
				addr <= '1';
				din <= x"65";--e
				if rdy = '1' then
					nextState <= send4;
				end if;
				
			when send4 =>
				stb <= '1';
				addr <= '1';
				din <= x"6e";--n
				if rdy = '1' then
					nextState <= send5;
				end if;
				
			when send5 =>
				stb <= '1';
				addr <= '1';
				din <= x"64";--d
				if rdy = '1' then
					nextState <= pos;
				end if;
				
			---------------------   search   ----------	
				
			when search1 =>
				stb <= '1';
				addr <= '0';
				din <= "10000000";--zeile ("11000000";--zeile 2)
				if rdy = '1' then
					nextState <= search2;
				end if;
				
			when search2 =>
				stb <= '1';
				addr <= '1';
				din <= x"73";--s
				if rdy = '1' then
					nextState <= search3;
				end if;
				
			when search3 =>
				stb <= '1';
				addr <= '1';
				din <= x"65";--e
				if rdy = '1' then
					nextState <= search4;
				end if;
				
			when search4 =>
				stb <= '1';
				addr <= '1';
				din <= x"61";--a
				if rdy = '1' then
					nextState <= search5;
				end if;
				
			when search5 =>
				stb <= '1';
				addr <= '1';
				din <= x"72";--r
				if rdy = '1' then
					nextState <= search6;
				end if;
				
			when search6 =>
				stb <= '1';
				addr <= '1';
				din <= x"63";--c
				if rdy = '1' then
					nextState <= search7;
				end if;
				
			when search7 =>
				stb <= '1';
				addr <= '1';
				din <= x"68";--h
				if rdy = '1' then
					nextState <= search8;
				end if;
			
			when search8 =>
				stb <= '1';
				addr <= '1';
				din <= x"69";--i
				if rdy = '1' then
					nextState <= search9;
				end if;
				
			when search9 =>
				stb <= '1';
				addr <= '1';
				din <= x"6E";--n
				if rdy = '1' then
					nextState <= search10;
				end if;
			
			when search10 =>
				stb <= '1';
				addr <= '1';
				din <= x"67";--g
				if rdy = '1' then
					nextState <= pos;
				end if;
			
			---------- position -------
			
			when pos =>
				stb <= '1';
				addr <= '1';
				din <= x"20";--leer
				if rdy = '1' then
					nextState <= pos;
				end if;
				nextState <= pos1;
			
			when pos1 =>
				stb <= '1';
				addr <= '0';
				din <= "11000000";--zeile 2
				if rdy = '1' then
					nextState <= pos2;
				end if;
				
			when pos2 =>
				stb <= '1';
				addr <= '1';
				din <= x"75"; --u
				if rdy = '1' then
					nextState <= pos3;
				end if;
				
			when pos3 =>
				stb <= '1';
				addr <= '1';
				din <= x"6E"; --n
				if rdy = '1' then
					nextState <= pos4;
				end if;
			
			when pos4 =>
				stb <= '1';
				addr <= '1';
				din <= x"69"; --i
				if rdy = '1' then
					nextState <= pos5;
				end if;

			when pos5 =>
				stb <= '1';
				addr <= '1';
				din <= x"74"; --t
				if rdy = '1' then
					nextState <= pos6;
				end if;
				
			when pos6 =>
				stb <= '1';
				addr <= '1';
				din <= x"73"; --s
				if rdy = '1' then
					nextState <= pos7;
				end if;
			
			when pos7 =>
				stb <= '1';
				addr <= '1';
				din <= x"3A"; --:
				if rdy = '1' then
					nextState <= pos8;
				end if;
				
			when pos8 =>
				stb <= '1';
				addr <= '1';
				din <= x"20"; --leer
				if rdy = '1' then
					nextState <= pos9;
				end if;
				
			when pos9 =>
				stb <= '1';
				addr <= '1';
				din <= x"20"; --leer
				if rdy = '1' then
					nextState <= pos10;
				end if;
				
			when pos10 =>
				stb <= '1';
				addr <= '1';
				din <= ascii(dat_adr(31 downto 28));--1. Stelle
				if rdy = '1' then
					nextState <= pos11;
				end if;
				
			when pos11 =>
				stb <= '1';
				addr <= '1';
				din <= ascii(dat_adr(27 downto 24));--2. Stelle
				if rdy = '1' then
					nextState <= pos12;
				end if;
				
			when pos12 =>
				stb <= '1';
				addr <= '1';
				din <= ascii(dat_adr(23 downto 20));--3. Stelle
				if rdy = '1' then
					nextState <= pos13;
				end if;
				
			when pos13 =>
				stb <= '1';
				addr <= '1';
				din <= ascii(dat_adr(19 downto 16));--4. Stelle
				if rdy = '1' then
					nextState <= pos14;
				end if;
				
			when pos14 =>
				stb <= '1';
				addr <= '1';
				din <= ascii(dat_adr(15 downto 12));--5. Stelle
				if rdy = '1' then
					nextState <= pos15;
				end if;
				
			when pos15 =>
				stb <= '1';
				addr <= '1';
				din <= ascii(dat_adr(11 downto 8));--6. Stelle
				if rdy = '1' then
					nextState <= pos16;
				end if;
				
			when pos16 =>
				stb <= '1';
				addr <= '1';
				din <= ascii(dat_adr(7 downto 4));--7. Stelle
				if rdy = '1' then
					nextState <= pos17;
				end if;
				
			when pos17 =>
				stb <= '1';
				addr <= '1';
				din <= ascii(dat_adr(3 downto 0));--8. Stelle
				if rdy = '1' then
					nextState <= waiting;
				end if;
			
			when others => 
				null;
			
			end case;	
	end process;

end Behavioral;

