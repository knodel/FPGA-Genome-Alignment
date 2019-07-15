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
-- The component contains the state-machine controlling one
-- search-iteration and the register with the number of active
-- units. The results will be loaded out of every RAM of the
-- active units after reading the number of positions. The
-- communication with the ethernet-component is realized with
-- a FIFO (todo: ctr_out_fifo).
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity search_control is
    Port ( 
		clk 				: in  std_logic;
		clk_eth			: in  std_logic;
      res 				: in  std_logic;
		ext_reset		: in std_logic;
		
		lcd_data			: out std_logic_vector(31 downto 0);
				
		control 			: OUT STD_LOGIC_VECTOR(8 downto 0);
		overflow			: In 	std_logic;
		bus_free			: IN std_logic;
		
		ctr_out			: OUT std_logic_vector(2 downto 0);
		ctr_in			: IN 	std_logic_vector(7 downto 0);
		ctr_in_write	: IN 	std_logic;
		ctr_stream		: OUT std_logic;
		lcd_state		: OUT std_logic_vector(3 downto 0);
			
		--block RAM
		unit 				: OUT std_logic_vector(8 downto 0);
		we					: OUT std_logic_vector(0 downto 0);
		
		--fifo out
		fifo_out_rea	: OUT std_logic;
		fifo_out_empty	: IN 	std_logic;
		fifo_out_din	: IN 	std_logic_vector(31 downto 0);
		
		-- data-in fifo
		fifo_in_wea		: OUT std_logic;
		fifo_in_full	: IN 	std_logic;
		fifo_in_din		: IN 	std_logic_vector(31 downto 0);
		
		--text-out fifo
		fifo_text_rea	: OUT	std_logic;
		fifo_text_empty: IN 	std_logic
	 );
end search_control;

architecture Behavioral of search_control is

	component count_impl is
		generic(
			COUNT_WIDTH : positive := 10
		);
		Port ( 
			clk 		: in  std_logic;
			res 		: in  std_logic;
			set_zero : in  std_logic;
			count		: in  std_logic;
			counter	: out std_logic_vector (COUNT_WIDTH-1 downto 0)
		);
	end component;
	
	component fifo_high_low is
		Port ( 
			clk_high : in  std_logic;
			clk_low 	: in  std_logic;
			din 		: in  std_logic;
			dout 		: out std_logic
		);
	end component;
	
	component fifo_low_high is
		Port ( 
			clk_low 	: in  std_logic;
			clk_high : in  std_logic;
			din 		: in  std_logic;
			dout 		: out std_logic
		);
	end component;
	
	component ctr_stream_buf is
		Port ( 
			stream_in 	: in  std_logic;
			stream_out 	: out std_logic;
			clk_high 	: in  std_logic;
			clk_low 		: in  std_logic
		);
	end component;
	
	component reg_impl is
		generic(
			WIDTH : positive := 16
		);
		
		Port ( 
			clk 		: in	std_logic;
			res 		: in	std_logic;
			q_in 		: in	std_logic_vector (WIDTH-1 downto 0);
			q_out 	: out	std_logic_vector (WIDTH-1 downto 0);
			enable 	: in	std_logic
		);
	end component;
	
	component delay_signal is
		generic (
			DELAY	: positive := 19 
		);
		Port ( 
			clk 	: in  STD_LOGIC;
			res 	: in  STD_LOGIC;
			din 	: in  STD_LOGIC;
			dout 	: out  STD_LOGIC
		);
	end component;
	
	component ctr_fifo is
		Port (
			wr_rst: in  STD_LOGIC;
			rd_rst: in  STD_LOGIC;
			wr_clk: in  STD_LOGIC;
			rd_clk: in  STD_LOGIC;
			
			din	: in  STD_LOGIC_VECTOR(7 downto 0);
			wr_en	: in  STD_LOGIC;
			rd_en	: in  STD_LOGIC;
			dout	: out STD_LOGIC_VECTOR(7 downto 0);
			full	: out STD_LOGIC;
			empty	: out STD_LOGIC
		);
	end component;
	
	type   ctrState is (waiting, reset, rcv_data1, send_data, get_DB, wait_for_DB, 
									switch_to_DB, switch_from_DB,load_counter, load_VE, load_DB, 
									finishing_search, wait_for_sending, searching, send_finished,
									rcv_data2, next_unit, next_send_unit, finished_iteration,
									read_send_positions, send_position, last_unit, overflow_state, 
									wait_for_next, rcv_wait, resume_search, overflow_wait, waiting_state);
									
	signal state	  				: ctrState := waiting;
	signal nextState 				: ctrState;
	
	signal addr_i					: std_logic_vector (9 downto 0);
	signal unit_i					: std_logic_vector (9 downto 0);
	
	signal addr_res 				: std_logic;
	signal unit_res 				: std_logic;
	
	signal addr_count 			: std_logic;
	signal unit_count 			: std_logic;
	
	signal fifo_in_din_i 		: std_logic_vector (7 downto 0);
	signal fifo_in_wea_i 		: std_logic;
	signal fifo_in_wea_reg		: std_logic;
	signal fifo_in_wea_reg1		: std_logic;
	signal ctr_out_i				: std_logic_vector(2 downto 0);
	signal ctr_in_i				: std_logic_vector(7 downto 0);
	signal ctr_in_read			: std_logic;
	signal ctr_in_empty			: std_logic;
	signal ctr_in_out				: std_logic_vector(7 downto 0);
	signal ctr_stream_i			: std_logic;
	
	signal active_units			: std_logic_vector(9 downto 0);
	signal write_unit_count		: std_logic;
	signal write_unit_count_i	: std_logic;
	signal active_units_in		: std_logic_vector(9 downto 0);
	
	signal positions				: std_logic_vector(9 downto 0);
	signal write_positions		: std_logic;
	signal write_positions_i	: std_logic;
	signal write_positions_reg	: std_logic;
	signal write_positions_reg2: std_logic;
	signal positions_in			: std_logic_vector(9 downto 0);
	
	--control signals
	signal start_search			: std_logic;
	signal load_data				: std_logic;
	signal finish_search			: std_logic;
	signal start_shift			: std_logic;
	signal ext_ram_access		: std_logic;
	signal ram_sector				: std_logic;
	signal set_pos_zero			: std_logic;
	signal set_addr_zero			: std_logic;
	signal start_adr_count		: std_logic;
	signal start_addr_zero		: std_logic;
	
	signal send_positions_i		: std_logic;
	signal we_i						: std_logic_vector(0 downto 0);
	signal last_data				: std_logic;
	signal last_data_res			: std_logic;
	
	signal next_position			: std_logic;

begin
	
	active_units_in(9 downto 8) 	<= fifo_in_din(21 downto 20);
	active_units_in(7 downto 4) 	<= fifo_in_din(27 downto 24);
	active_units_in(3 downto 0) 	<= fifo_in_din(31 downto 28);
	
-- positions_in(15 downto 12) 	<= fifo_out_din(19 downto 16);
--	positions_in(11 downto 8) 		<= fifo_out_din(23 downto 20);
	positions_in(9 downto 8) 		<= fifo_out_din(21 downto 20);
	positions_in(7 downto 4) 		<= fifo_out_din(27 downto 24);
	positions_in(3 downto 0) 		<= fifo_out_din(31 downto 28);
	
	lcd_data(9 downto 0) <= unit_i;--active_units;
	lcd_data(31 downto 10) <= (others => '0');
	
	control(0)	<= start_search;
	control(1)	<= load_data;
	control(2)	<= finish_search;
	control(3)	<= start_shift;
	control(4)	<= ext_ram_access;
	control(5)	<= start_adr_count;
	control(6) 	<= ram_sector;
	control(7) 	<= set_pos_zero;
	control(8) 	<= set_addr_zero;
	
--	ctr_in_i <= ctr_in;
	
	process(clk)
	begin
		if rising_edge(clk) then
			if ctr_in_empty = '0' then
				ctr_in_read <= '1';
				ctr_in_i <= ctr_in_out;
			else
				ctr_in_read <= '1';
				ctr_in_i <= (others => '0');
			end if;
		end if;
	end process;

	--register for unit information
	process(clk, ext_reset)
	begin
		if rising_edge(clk) then
			if res = '1' then
				active_units <= (others => '0');
			elsif write_unit_count = '1' then
				active_units 		<= active_units_in;
				send_positions_i	<= fifo_in_din(8);
			end if;
		end if;
		if ext_reset = '1' then
			active_units <= (others => '0');
		end if;
	end process;
	
	--register for positions of a unit found
	process(clk, ext_reset)
	begin
		if rising_edge(clk) then
			if res = '1' then
				positions <= (others => '0');
			elsif write_positions = '1' then
				positions <= positions_in;
			end if;
		end if;
		if ext_reset = '1' then
			positions <= (others => '0');
		end if;
	end process;

	we	<= we_i;

	--clocked process for the state maschines
	process(clk, ext_reset)
	begin
		if rising_edge(clk) then
			if res = '1' then
				state <= waiting;
			else
				write_unit_count		<= write_unit_count_i;
				ram_sector				<= unit_i(0);
				unit 						<= unit_i(9 downto 1);
				state 					<= nextState;
			end if;
		end if;
		if ext_reset = '1' then
			state <= waiting;
		end if;
	end process;
	
	process(clk, last_data_res)
	begin
		if rising_edge(clk) then
			if res = '1' then
				last_data <= '0';
			elsif ctr_in_i = x"12" then --last_data
				last_data <= '1';
			end if;
		end if;
		if last_data_res = '1' then
			last_data <= '0';
		end if;
	end process;

	--state transitions
	process(state, ctr_in_i, fifo_out_empty, addr_i, fifo_text_empty, fifo_in_full, unit_i, active_units, 
					write_positions, positions, send_positions_i, overflow, bus_free, last_data)
	begin
		nextState 			<= state;
		
		start_search 		<= '0';
		load_data 			<= '0';
		finish_search		<= '0';
		ctr_stream_i 		<= '0';
		start_shift			<= '0';
		set_pos_zero		<= '0';
		set_addr_zero		<= '0';
		last_data_res		<= '0';
		
		fifo_out_rea		<= '0';
		fifo_in_wea_i		<= '0';
		we_i					<= "0";
		fifo_text_rea		<= '0';
		write_unit_count_i<= '0';
		
		ext_ram_access 	<= '0';
		
		unit_res				<= '0';
		addr_res				<= '0';
		addr_count			<= '0';
		unit_count			<= '0';
		write_positions_i	<= '0';
		start_adr_count	<= '0';
		
		ctr_out_i			<= "000";
		lcd_state			<= x"0";
		
		case state is
		
			when reset =>
				nextState 	<= waiting;
				
			when waiting =>
				lcd_state 		<= x"1";
				unit_res			<= '1';
				addr_res			<= '1';
				set_pos_zero	<= '1';
				set_addr_zero	<= '1';
				ext_ram_access <= '1';
				if ctr_in_i = x"10" then	 		--ctr_first_data
					nextState 	<= rcv_data1;
				end if;
			
			when rcv_data1 =>
				ext_ram_access 	<= '1';
				lcd_state 			<= x"2";
				if fifo_out_empty = '0' then
					fifo_out_rea 	<= '1';
					we_i 				<= "0";
					nextState 		<= load_counter;
				end if;

			when load_counter =>
				ext_ram_access 	<= '1';
				lcd_state 			<= x"2";
				if fifo_out_empty = '0' then
					fifo_out_rea 		<= '1';
					write_unit_count_i<= '1';
					nextState 			<= rcv_data2;
				end if;
			
			when rcv_data2 =>
				lcd_state 			<= x"2";
				ext_ram_access 	<= '1';
				if ((fifo_out_empty = '0') and (bus_free = '1')) then
					fifo_out_rea 	<= '1';
					addr_count	 	<= '1';
					we_i 				<= "1";
				end if;
				if addr_i = conv_std_logic_vector(33, 10) then
					addr_res	 		<= '1';
					nextState <= next_unit;
				end if;
				
			when next_unit =>
				ext_ram_access 	<= '1';
				if ((fifo_out_empty = '0') and (bus_free = '1')) then
					fifo_out_rea 	<= '1';
					set_pos_zero	<= '1';
					if unit_i = active_units then
						unit_res		<= '1';
						nextState 	<= load_VE;
					else
						unit_count	<= '1';
						nextState 	<= rcv_data2;
					end if;
				end if;
			
			--loading information into the VE register
			when load_VE =>
				lcd_state 		<= x"2";
				addr_count		<= '1';
				load_data 		<= '1';
				if addr_i = conv_std_logic_vector(100, 10) then
					addr_res	 	<= '1';
					nextState 	<= get_DB;
				end if;
				
			when get_DB =>
				set_addr_zero	<= '1';
				--set_pos_zero	<= '1';
				ctr_stream_i 	<= '1';
				lcd_state 		<= x"2";
				ctr_out_i 		<= "001";		--ctr_send_DB
				nextState 		<= switch_to_DB;
				
			when switch_to_DB	=>
				ctr_stream_i 	<= '1';
				lcd_state 		<= x"2";
				nextState 		<= wait_for_DB;
				
			when wait_for_DB =>
				ctr_stream_i 	<= '1';
				lcd_state 		<= x"2";
				--set_pos_zero	<= '1';
				if ctr_in_i = x"10" then		--ctr_first_data
					addr_res	 	<= '1';
					nextState 	<= load_DB;
				end if;
				
			when load_DB => 
				ctr_stream_i 		<= '1';
				lcd_state 			<= x"2";
				if fifo_text_empty = '0' then
					start_shift		<= '1';
					fifo_text_rea	<= '1';
					addr_count		<= '1';
					if addr_i = conv_std_logic_vector(61, 10) then
						addr_res	 	<= '1';
						nextState 	<= searching;
					end if;
				end if;
				
			when resume_search => --after overflow
				--set_pos_zero	<= '1';
				addr_res	 		<= '1';
				ctr_stream_i 	<= '1';
				if last_data = '1' then 	--last_data
					nextState 	<= finishing_search;
				end if;
				nextState 		<= searching;
				
			when searching =>
				ctr_stream_i 		<= '1';
				lcd_state 			<= x"5";
				if last_data = '1' then 	--last_data
					nextState 		<= finishing_search;
				end if;
				if overflow = '1' and send_positions_i = '1' then
					nextState 		<= overflow_state;
				end if;
				if fifo_text_empty = '0' then
					start_shift		<= '1';
					start_search 	<= '1';
					fifo_text_rea	<= '1';
				end if;
				
				
			when finishing_search =>
				ctr_stream_i 		<= '1';
				lcd_state 			<= x"5";
				if overflow = '1' then
					nextState 		<= overflow_state;
				end if;
				if fifo_text_empty = '0' then
					start_shift		<= '1';
					start_search	<= '1';
					fifo_text_rea	<= '1'; 
				else
					nextState 		<= switch_from_DB;
				end if;
				
			when overflow_state =>
				lcd_state 			<= x"3";
				ctr_out_i 		<= "011";		--overflow signal
				ctr_stream_i 	<= '1';
				--set_pos_zero	<= '1';
				lcd_state 		<= x"1";
				finish_search	<= '1';
				addr_res	 		<= '1';
				nextState 		<= overflow_wait;
				
			when overflow_wait =>
				lcd_state 			<= x"3";
				lcd_state 		<= x"1";
				ctr_stream_i	<= '1';
				if ctr_in_i = x"31" then
					nextState 	<= wait_for_sending;
				end if;
				
			when switch_from_DB =>
				lcd_state 			<= x"3";
				ctr_out_i 		<= "010";		--finished search -> 0x16
				nextState 		<= send_finished;
				
			when send_finished =>
				lcd_state 			<= x"3";
				finish_search	<= '1';
				lcd_state 		<= x"3";
				--set_pos_zero	<= '1';
				nextState 		<= wait_for_sending;
				
			when wait_for_sending =>
				lcd_state 			<= x"3";
				if ctr_in_i = x"15" then 	--ctr_get_data
					nextState 	<= send_data;
					set_pos_zero	<= '1';
					addr_res		<= '1';
				end if;
			
			
			--reads the first line of the block ram
			when send_data =>
				ext_ram_access 	<= '1';
				lcd_state 			<= x"3";
				if fifo_in_full = '0'  then
					fifo_in_wea_i 		<= '1';
					write_positions_i	<= '1';
					start_adr_count	<= '1';
					addr_count			<= '1';
					if send_positions_i = '0' then			
						nextState 	<= next_send_unit;		--next unit, if no positions neccessary 
					else
						nextState 	<= read_send_positions;	--reads the number of positions the unit founds
					end if;
				end if;
			
			--saves number of positions in local register
			when read_send_positions =>
				ext_ram_access 	<= '1';
				lcd_state 			<= x"3";
				if write_positions = '1'  then				
					nextState 	<= send_position;				
				end if;
			---------------------------------------------------------------------------------------------------	
			when send_position =>
				ext_ram_access 	<= '1';
				lcd_state 			<= x"2";
				if fifo_in_full = '0'  then
					if (addr_i(9 downto 0) <= positions(9 downto 0)) then
					--if next_position = '1' then
						fifo_in_wea_i 		<= '1';
						start_adr_count	<= '1';
						addr_count			<= '1';
						nextState <= send_position;
					else
						addr_res		<= '1';
						nextState <= wait_for_next;
					end if;
					if (addr_i(9 downto 0) = conv_std_logic_vector(1024, 10)) then
						nextState <= last_unit;
					end if;
				end if;
				
				when waiting_state =>
					nextState 	<= send_position;
				
			---------------------------------------------------------------------------------------------------	
			when wait_for_next =>
				addr_count	<= '1';
				lcd_state 		<= x"3";
				if addr_i = conv_std_logic_vector(20, 10) then--12 ok
					nextState 	<= next_send_unit;
				end if;
				
			when next_send_unit =>
				ext_ram_access <= '1';
				lcd_state 		<= x"3";
				if (unit_i = active_units) then--or (unit_i = conv_std_logic_vector(512, 9)) then
					unit_res		<= '1';
					addr_res		<= '1';
					set_pos_zero<= '1';
					nextState 	<= last_unit;
				else
					unit_count	<= '1';
					addr_res		<= '1';
					set_pos_zero<= '1';
					nextState 	<= send_data;
				end if;
				
			when last_unit =>
				ext_ram_access <= '1';
				lcd_state 		<= x"3";
				fifo_in_wea_i 	<= '1';
				set_pos_zero	<= '1';
				nextState 		<= finished_iteration;
				
			when finished_iteration =>
				if ctr_in_i = x"18" then --next segement
					last_data_res	<= '1';
					nextState 	<= get_DB;
				end if;
				if ctr_in_i = x"31" then --continue search
					nextState 	<= resume_search;
				end if;
				if ctr_in_i = x"19" then
					last_data_res	<= '1';
					nextState 	<= reset;
				end if;
				
			when others =>
				null;
		
		end case;
	end process;
	
	addrCounter: count_impl 
		generic map(
			COUNT_WIDTH => 10
		)
		Port map ( 
			clk 		=> clk,
			res 		=> res,
			set_zero => addr_res,
			count		=> addr_count,
			counter	=> addr_i
		);
		
	unitCounter: count_impl 
		generic map(
			COUNT_WIDTH => 10
		)
		Port map ( 
			clk 		=> clk,
			res 		=> res,
			set_zero => unit_res,
			count		=> unit_count,
			counter	=> unit_i
		);
		
	ctr_buf_out: for K in 0 to 2 generate
		ctr_high_low: fifo_high_low 
			Port map ( 
				clk_high => clk,
				clk_low 	=> clk_eth,
				din 		=> ctr_out_i(k),
				dout 		=> ctr_out(k)
			);
	end generate;
	
	ctr_buf_stream: ctr_stream_buf 
		Port map( 
			stream_in  	=> ctr_stream_i,	
			stream_out 	=> ctr_stream,
			clk_high 	=> clk,
			clk_low 		=> clk_eth
		);
		
	fifo_delay: delay_signal
		generic map(
			DELAY			 	=> 23
		) Port map( 
			clk 				=> clk,
			res 				=> res,
			din 				=> fifo_in_wea_i,
			dout 				=> fifo_in_wea
		);
		
	pos_delay: delay_signal
		generic map(
			DELAY			 	=> 23
		) Port map( 
			clk 				=> clk,
			res 				=> res,
			din 				=> write_positions_i,
			dout 				=> write_positions
		);
		
	ctr_in_fifo: ctr_fifo 
		Port map(
			wr_rst	=> '0',
			rd_rst	=>	res,
			wr_clk	=> clk_eth,
			rd_clk	=> clk,
			
			din		=> ctr_in,
			wr_en		=> ctr_in_write,
			rd_en		=> ctr_in_read,
			dout		=>	ctr_in_out,
			full		=> open,
			empty		=> ctr_in_empty
		);
		
--	ctr_out_fifo: ctr_fifo 
--		Port map(
--			wr_rst	=> res,
--			rd_rst	=>	'0',
--			wr_clk	=> clk,
--			rd_clk	=> clk_eth,
--			
--			din		=> 
--			wr_en		=> 
--			rd_en		=> 
--			dout		=>
--			full		=> open,
--			empty		=> 
--		);

end Behavioral;

