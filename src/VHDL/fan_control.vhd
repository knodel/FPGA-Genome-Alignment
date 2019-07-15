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
-- Virtex-6 Fan-control with PWM. Three different speeds in 
-- depency of the actual temperature provided by the system
-- monitor instantiated in this module.
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity fan_control is
    Port ( clk 		: in  STD_LOGIC;
           res 		: in  STD_LOGIC;
			  fan_sw		: in  STD_LOGIC;
			  
			  fan_pwm 	: out STD_LOGIC;
			  fan_tach	: out STD_LOGIC
			);
end fan_control;

architecture Behavioral of fan_control is

	component system_monitor
		 port (
				RESET_IN            : in  STD_LOGIC;   -- Reset signal for the System Monitor control logic
			   OT_OUT              : out  STD_LOGIC;  -- Over-Temperature alarm output
				USER_TEMP_ALARM_OUT : out  STD_LOGIC;  -- Temperature-sensor alarm output
				VP_IN               : in  STD_LOGIC;   -- Dedicated Analog Input Pair
				VN_IN               : in  STD_LOGIC
		);
	end component;
	
	signal pwm			: STD_LOGIC;
	signal start_fan	: STD_LOGIC;
	signal fan_max		: STD_LOGIC;
	
	signal c : unsigned(23 downto 0);
begin

	process(clk)
	begin
		if rising_edge(clk) then
			fan_pwm 	<= pwm;
		end if;
	end process;	
	
	fan_tach	<= start_fan or fan_max or fan_sw;
	
	process(clk, c, res, fan_sw, start_fan, fan_max)
	begin
		if rising_edge(clk) then
			if fan_max = '1' or fan_sw = '1' then
				pwm <= '1';
			elsif start_fan = '1' then
				if res = '1' then
					c <= conv_unsigned(0, 24);
				else
					if c(23) = '1' then
						c <= conv_unsigned(0, 24);
						if pwm = '0' then
							pwm <= '1';
						else
							pwm <= '0';
						end if;
					else
						c <= c+1;
					end if;
				end if;
			else
				pwm <= '0';
			end if;
		end if;
	end process;
	
	monitor : system_monitor
	  port map ( 
          RESET_IN            => res, 
          OT_OUT              => fan_max,
          USER_TEMP_ALARM_OUT => start_fan,
          VP_IN               => '0', 
          VN_IN               => '0'
         );


end Behavioral;

