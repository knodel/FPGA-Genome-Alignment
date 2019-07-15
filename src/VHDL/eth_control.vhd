--
-- Copyright (c) 2011
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Author: Oliver Knodel <oliver.knodel@mailbox.tu-dresden.de>
-- Project:	FPGA-DNA-Sequence-Search
--
-- The receive state machine disassembles packets into a control-
-- signals and pure data. The data is provided in two differend
-- FIFOs. The stream FIFO allows a streaming with an exact 
-- datarate. 
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity eth_control is
    Port (
		clk_eth 					: in  STD_LOGIC;
		clk						: in  STD_LOGIC;
      res 						: in  STD_LOGIC;
		
		GPIO_LED					: out STD_LOGIC_VECTOR(5 downto 0);
		unit_count				: in STD_LOGIC_VECTOR(15 downto 0);
		
		ext_reset				: out std_logic;
		
		--Control
		ctr_out					: out std_logic_vector(7 downto 0);
		ctr_in					: in std_logic_vector(2 downto 0);
		ctr_out_write			: out std_logic;
		ctr_stream				: in std_logic;
		
		--data-out fifo
		fifo_out_rea			: in std_logic;
		fifo_out_dout			: out std_logic_VECTOR(31 downto 0);
		fifo_out_empty			: out std_logic;
		
		--data-in fifo
		fifo_in_wea				: in std_logic;
		fifo_in_din				: in std_logic_VECTOR(31 downto 0);
		fifo_in_full			: out std_logic;
		
		--text-out fifo
		fifo_text_rea			: in std_logic;
		fifo_text_dout			: out std_logic_VECTOR(1 downto 0);
		fifo_text_empty		: out std_logic;
		
		--Ethernet Signals
		rx_ll_data_in       	: in  std_logic_vector(7 downto 0); -- Input data
		rx_ll_sof_in_n      	: in  std_logic;		-- Input start of frame
		rx_ll_eof_in_n      	: in  std_logic; 		-- Input end of frame
      rx_ll_src_rdy_in_n  	: in  std_logic; 		-- Input source ready
		rx_ll_dst_rdy_in_n  	: out  std_logic;  	-- Input destination ready
		
      rx_ll_data_out      	: out std_logic_vector(7 downto 0); -- Output data
      rx_ll_sof_out_n     	: out std_logic; 		-- Output start of frame
      rx_ll_eof_out_n     	: out std_logic; 		-- Output end of frame
      rx_ll_src_rdy_out_n 	: out std_logic; 		-- Output source ready
      rx_ll_dst_rdy_out_n  : in  std_logic  		-- Input destination ready
	);
end eth_control;

architecture Behavioral of eth_control is

	--n to 1 function for register enable
	function nTo1(signal input:  STD_LOGIC_VECTOR(3 downto 0)) return STD_LOGIC_VECTOR is
	variable result : STD_LOGIC_VECTOR(15 downto 0);
	begin
		case (input) is
			when x"0" => result := "0000000000000001";
			when x"1" => result := "0000000000000010";
			when x"2" => result := "0000000000000100";
			when x"3" => result := "0000000000001000";
			when x"4" => result := "0000000000010000";
			when x"5" => result := "0000000000100000";
			when x"6" => result := "0000000001000000";
			when x"7" => result := "0000000010000000";
			when x"8" => result := "0000000100000000";
			when x"9" => result := "0000001000000000";
			when x"A" => result := "0000010000000000";
			when x"B" => result := "0000100000000000";
			when x"C" => result := "0001000000000000";
			when x"D" => result := "0010000000000000";
			when x"E" => result := "0100000000000000";
			when x"F" => result := "1000000000000000";
			when others => result := "0000000000000000";		
		end case;
		return result;
	end nTo1;

	component count_impl is
		generic(
			COUNT_WIDTH : positive := 10
		);
		Port ( 
			clk 		: in  STD_LOGIC;
			res 		: in  STD_LOGIC;
			set_zero : in  STD_LOGIC;
			count		: in  STD_LOGIC;
			counter	: out STD_LOGIC_VECTOR (COUNT_WIDTH-1 downto 0)
		);
	end component;
	
	component reg_impl is
		generic(
			WIDTH : positive := 16
		);
		
		Port ( 
			clk 		: in	STD_LOGIC;
			res 		: in	STD_LOGIC;
			q_in 		: in	STD_LOGIC_VECTOR (WIDTH-1 downto 0);
			q_out 	: out	STD_LOGIC_VECTOR (WIDTH-1 downto 0);
			enable 	: in	STD_LOGIC
		);
	end component;
	
	component out_fifo
		port (
			rst		: IN std_logic;
			wr_clk	: IN std_logic;
			rd_clk	: IN std_logic;
			din		: IN std_logic_VECTOR(7 downto 0);
			wr_en		: IN std_logic;
			rd_en		: IN std_logic;
			dout		: OUT std_logic_VECTOR(31 downto 0);
			full		: OUT std_logic;
			prog_full: OUT std_logic;
			empty		: OUT std_logic
		);
	end component;
	
	component in_fifo
		port (
			rst		: IN std_logic;
			wr_clk	: IN std_logic;
			rd_clk	: IN std_logic;
			din		: IN std_logic_VECTOR(31 downto 0);
			wr_en		: IN std_logic;
			rd_en		: IN std_logic;
			dout		: OUT std_logic_VECTOR(7 downto 0);
			full		: OUT std_logic;
			prog_full: OUT std_logic;
			empty		: OUT std_logic
		);
	end component;
	
	component text_fifo
		port (
			rst 		 	 : IN std_logic;
			wr_clk		 : IN std_logic;
			rd_clk		 : IN std_logic;
			din			 : IN std_logic_VECTOR(7 downto 0);
			wr_en			 : IN std_logic;
			rd_en			 : IN std_logic;
			dout			 : OUT std_logic_VECTOR(1 downto 0);
			full			 : OUT std_logic;
			empty			 : OUT std_logic;
			wr_data_count: OUT std_logic_VECTOR(15	downto 0)
		);
	end component;
	
	component ctr_fifo
		port (
			rst			: IN std_logic;
			wr_clk		: IN std_logic;
			rd_clk		: IN std_logic;
			din			: IN std_logic_VECTOR(7 downto 0);
			wr_en			: IN std_logic;
			rd_en			: IN std_logic;
			dout			: OUT std_logic_VECTOR(1 downto 0);
			full			: OUT std_logic;
			empty			: OUT std_logic
		);
	end component;

	type   rState is (rcvIdle, rcvMac, rcvStatus, rcv_id, rcvData1, rcvData2, rcvEOF, rcvResetFpga,
									false_data, rcvResetFpga2);
	signal rcvState	  : rState := rcvIdle;
	signal nextRcvState : rState;
	
	type   sState is (sendIdle, sendSOF, sendMac, sendCtr, send_error_pos, send_packet_count_lo, 
									send_packet_count_hi, sendRealData, sendData, sendEOF, send_unit_count_lo,
									send_unit_count_hi);
	signal sendState	  	: sState := sendIdle;
	signal nextSendState : sState;
	
	type   iState is (idle, counting, nextPacket, idleWaiting);
	signal idleState	  	: iState := idle;
	signal nextIdleState : iState;
	
	--send and recieve counter
	signal rcv_set_zero 		: STD_LOGIC;
	signal rcv_count	 		: STD_LOGIC;
	signal rcv_counter  		: STD_LOGIC_VECTOR (10 downto 0);
	
	signal send_set_zero 	: STD_LOGIC;
	signal send_count	 		: STD_LOGIC;
	signal send_counter  	: STD_LOGIC_VECTOR (10 downto 0);
	
	signal end_set_zero		: STD_LOGIC;
	signal end_counter 		: STD_LOGIC_VECTOR (7 downto 0);
	signal end_count			: STD_LOGIC;
	
	signal id_set_zero		: STD_LOGIC;
	signal id_counter 		: STD_LOGIC_VECTOR (7 downto 0);
	signal id_count			: STD_LOGIC;
	
	signal idle_set_zero		: STD_LOGIC;
	signal idle_count 		: STD_LOGIC;
	signal idle_counter		: STD_LOGIC_VECTOR (29 downto 0);
	
	--registers for mac-address and type
	signal reg		 			: STD_LOGIC_VECTOR (127 downto 0);
	signal reg_enable			: STD_LOGIC_VECTOR (15 downto 0);
	signal reg_in				: STD_LOGIC_VECTOR (7 downto 0);
	signal reg_mux_out		: STD_LOGIC_VECTOR (7 downto 0);
	signal mux_ctr				: STD_LOGIC_VECTOR (3 downto 0);
	signal frame_id			: STD_LOGIC_VECTOR (7 downto 0);
	
	signal eth_type			: STD_LOGIC_VECTOR (15 downto 0);
	signal eth_ctr				: STD_LOGIC_VECTOR (7 downto 0);
	signal fpga_mac			: STD_LOGIC_VECTOR (47 downto 0);
	
	--control-signals
	signal send_id				: STD_LOGIC;
	signal send_stream		: std_logic;
	signal end_frame			: std_logic;
	signal last_send			: std_logic;
	signal ctr_send_db		: std_logic;
	signal frame_send			: std_logic;
	signal ctr_send_next		: std_logic;
	signal ctr_send_next_1	: std_logic;
	signal ctr_send_next_2	: std_logic;
	signal ctr_send_next_i	: std_logic;
	signal ctr_send_overflow: std_logic;
	signal error				: std_logic;
	signal error_frame		: std_logic;
	signal ctr_send_finished: std_logic;
	signal start_send_stream: std_logic;
	
	--fifo out
	signal fifo_out_din		: std_logic_VECTOR(7 downto 0);
	signal fifo_out_wea		: std_logic;
	signal fifo_out_full		: std_logic;
	
	--fifo in
	signal fifo_in_dout		: std_logic_VECTOR(7 downto 0);
	signal fifo_in_rea		: std_logic;
	signal fifo_in_empty		: std_logic;
	
	--fifo text
	signal fifo_text_din 			: std_logic_VECTOR(7 downto 0);
	signal fifo_text_wea 			: std_logic;
	signal fifo_text_full			: std_logic;
	signal fifo_text_count 			: std_logic_VECTOR(15 downto 0);
	signal fifo_text_count_old1	: std_logic_VECTOR(15 downto 0);
	signal fifo_text_count_old2	: std_logic_VECTOR(15 downto 0);
	signal fifo_text_down 			: std_logic;
	
	signal fifo_text_count_avail 	: std_logic_VECTOR(15 downto 0);
	
	signal ctr_in_i					: std_logic_vector(2 downto 0);
	signal ctr_out_i					: std_logic_vector(7 downto 0);
	
	signal rx_ll_src_rdy_out_i 	: std_logic;
	signal ctr_stream_i 				: std_logic;
	
	signal ext_reset_i				: std_logic;
	
	signal sof1							: std_logic;
	signal led							: std_logic;
	signal dataframe					: std_logic;

	
	
begin

	GPIO_LED(5 downto 4)	<= (others => '0');
	GPIO_LED(0)				<= fifo_in_empty;
	GPIO_LED(2)				<= not fifo_in_empty;
	ext_reset <= ext_reset_i;

	frame_id	<= reg(127 downto 120);
	eth_ctr 	<= reg(119 downto 112);
	eth_type <= reg(111 downto 96);
	fpga_mac <=	reg(47 downto 0);
	
	
	fifo_out_din(7 downto 4) 	<= rx_ll_data_in(3 downto 0);
	fifo_out_din(3 downto 0) 	<= rx_ll_data_in(7 downto 4);
	
	fifo_text_din	<= rx_ll_data_in;
	
	ctr_in_i			<= ctr_in;
	ctr_out			<= ctr_out_i;
	
	--clocked process for the state maschines
	process(clk_eth, res)
	begin
		if rising_edge(clk_eth) then
			if res = '1' then
				rcvState 	<= rcvIdle;
				sendState 	<= sendIdle;
				idleState 	<= idle;
			else
				rcvState 	<= nextRcvState;
				sendState 	<= nextSendState;
				idleState	<= nextIdleState;
			end if;
		end if;
	end process;
	
	rx_ll_src_rdy_out_n <= rx_ll_src_rdy_out_i;
	
	--process starts sending stream
	process(clk_eth, res, end_counter, start_send_stream)
	begin
		if rising_edge(clk_eth) then
			if res = '1' then
				send_stream 	<= '0';
				end_frame 		<= '0';
			else
				if start_send_stream = '1' then
					send_stream <= '1';
				end if;
				if end_counter = "00111111" then
					end_frame <= '1';
					send_stream <= '0';
				end if;
				if last_send = '1' then
					end_frame <= '0';
				end if;
			end if;
		end if;
	end process;
	
	process(clk_eth, res, error, frame_send)
	begin
		if rising_edge(clk_eth) then
			if res = '1' then
				error_frame <= '0';
			else
				if error = '1' then
					error_frame <= '1';
				elsif frame_send = '1' then
					error_frame <= '0';
				end if;
			end if;
		end if;
	end process;
	
	--finished search
	process(clk_eth, ctr_in_i, frame_send)
	begin
		if rising_edge(clk_eth) then
			if res = '1' then
				ctr_send_finished <= '0';
			else
				if ctr_in_i = "010" then
					ctr_send_finished <= '1';
				end if;
				if frame_send = '1' then
					ctr_send_finished <= '0';
				end if; 
			end if;
		end if;
	end process;
	
	--send ctr_get_DB frame and DB-stream signal for the text FIFO
	process(clk_eth, ctr_in_i, frame_send)
	begin
		if rising_edge(clk_eth) then
			if res = '1' then
				ctr_send_db <= '0';
			else
				if ctr_in_i = "001" then
					ctr_send_db <= '1';
				end if;
				if frame_send = '1' then
					ctr_send_db <= '0';
				end if; 
			end if;
		end if;
	end process;
	
	--send overflow signal
	process(clk_eth, ctr_in_i, frame_send)
	begin
		if rising_edge(clk_eth) then
			if res = '1' then
				ctr_send_overflow <= '0';
			else
				if ctr_in_i = "011" then
					ctr_send_overflow <= '1';
				end if;
				if frame_send = '1' then
					ctr_send_overflow <= '0';
				end if; 
			end if;
		end if;
	end process;
	
	--send overflow signal
	process(clk_eth, ctr_in_i)
	begin
		if rising_edge(clk_eth) then
			if res = '1' then
				ctr_stream_i <= '0';
			else
				if ctr_in_i = "100" then
					ctr_stream_i <= not ctr_stream_i;
				end if;
			end if;
		end if;
	end process;
	
	--Free-Text-FIFO-Bytes signal
	process(clk)
	begin
		if rising_edge(clk) then
			fifo_text_count_avail <= not fifo_text_count;--"1111111111111111" - fifo_text_count;
		end if;
	end process;
	
	-------------------------------------------------------------
	-- sends next-signal when 50000 cycles in receive idle state 
	-------------------------------------------------------------
	process(idleState, idle_counter, rx_ll_sof_in_n, ctr_send_finished, frame_send, ctr_send_db, rcvstate, dataframe)
	begin
		nextIdleState 	<= idleState;
		
		idle_set_zero 	<= '0';
		idle_count 		<= '0';
		ctr_send_next	<= '0';
		
		case idleState is
		
			when idle =>
				idle_set_zero <= '1';
				if ctr_send_db = '1' then
					nextIdleState <= idleWaiting;
				end if;
				
			when counting =>
				if rcvState = rcvIdle then
					idle_count <= '1';
				else
					idle_set_zero <= '1';
				end if;
				if idle_counter = conv_std_logic_vector(30000, 30) then 
					nextIdleState <= nextPacket;
				end if;
				if ctr_send_finished = '1' then
					nextIdleState <= idle;
				end if;
				
			when nextPacket =>
				ctr_send_next <= '1';
				if frame_send = '1' then
					idle_set_zero <= '1';
					nextIdleState <= idleWaiting;
				end if;
				if ctr_send_finished = '1' then
					nextIdleState <= idle;
				end if;
				
			when idleWaiting =>
				if dataframe = '1' then
					nextIdleState <= counting;
				end if;
				if ctr_send_finished = '1' then
					nextIdleState <= idle;
				end if;
				
				idle_count <= '1';
				if idle_counter = conv_std_logic_vector(100000000, 30) then -- 1s
					nextIdleState <= nextPacket;
				end if;
				
			when others =>
				null;  

		end case;
	end process;
	
	--------------------------------------------------
	-- receving
	--------------------------------------------------
	
	--state transitions
	process(rcvState, rcv_counter, rx_ll_data_in, rx_ll_sof_in_n, rx_ll_src_rdy_in_n, rx_ll_eof_in_n, eth_ctr,
					fifo_out_full, fifo_text_full, ctr_stream, eth_type, frame_id, id_counter, fpga_mac)
	begin
		nextRcvState 		<= rcvState;
		
		rcv_set_zero  		<= '0';
		rcv_count	  		<= '0';
		send_id 	  			<= '0';
		rx_ll_dst_rdy_in_n<= '1';
		fifo_out_wea 		<= '0';
		fifo_text_wea		<= '0';
		error 				<= '0';
		id_count				<= '0';
		ext_reset_i			<= '0';
		ctr_out_i 			<= x"00";
		start_send_stream <= '0';
		id_set_zero			<= '0';
		dataframe 			<= '0';
		ctr_out_write		<= '0';
		
		reg_in				<= (others => '0');
		reg_enable			<= (others => '0');
		
		case rcvState is
		
			when rcvIdle =>
				rcv_set_zero <= '1';
				if rx_ll_src_rdy_in_n = '0' then
					if rx_ll_sof_in_n = '0' then
						id_count <= '1';
						nextRcvState <= rcvMac;
					end if;
				end if;
			
			when rcvMac =>
				rcv_count <= '1';
				rx_ll_dst_rdy_in_n	<= '0';
				reg_in <= rx_ll_data_in;
				reg_enable <= nTo1(rcv_counter(3 downto 0));
				if rcv_counter = conv_std_logic_vector(15, 11) then
					nextRcvState <= rcvStatus;
				end if;
				
			when rcvStatus =>
				rx_ll_dst_rdy_in_n	<= '1';
				rcv_count <= '1';
				if fpga_mac = x"422a02350a00" then
					if eth_type = x"0108" then
						
						if eth_ctr = x"19" then --finished iteration / reset
							nextRcvState <= rcvData1;
						else
							if frame_id /= id_counter then
								error <= '1';
							else
								if eth_ctr = x"20" then		--ctr_getid
									send_id <= '1';
								elsif eth_ctr = x"10" then --ctr_first_data
									fifo_out_wea <= '1';
									dataframe <= '1';
								elsif eth_ctr = x"11" then --ctr_data;
									fifo_out_wea <= '1';
									dataframe <= '1';
								elsif eth_ctr = x"12" then
									dataframe <= '1';
								end if;
								if eth_ctr = x"10" or eth_ctr = x"12" or eth_ctr = x"15" then
									ctr_out_write	<= '1';
									ctr_out_i 		<= eth_ctr;
								end if;
								if eth_ctr = x"15" then
									start_send_stream <= '1';
								end if;
							end if;
							nextRcvState <= rcvData1;
						end if;
					else
						nextRcvState <= false_data;
					end if;
				else
					nextRcvState <= false_data;
				end if;
				
			when rcvData1 =>
				--Signal for two cycles
				if eth_ctr = x"10" or eth_ctr = x"12" or eth_ctr = x"15" then
						ctr_out_i 			<= eth_ctr;
						ctr_out_write		<= '1';
				end if;
				rx_ll_dst_rdy_in_n <= '0';
				nextRcvState <=rcvData2;
				
			when rcvData2 =>
				--rcv_count <= '1';
				if rx_ll_eof_in_n = '0' then --end of frame
					rx_ll_dst_rdy_in_n <= '0';
					nextRcvState <= rcvEOF;
				elsif ctr_stream = '0' then	--write Data in Data-FIFO 
					if eth_ctr = x"10" or eth_ctr = x"11" then 
						if fifo_out_full = '0' then
							fifo_out_wea <= '1';
							rx_ll_dst_rdy_in_n <= '0';
						else
							fifo_out_wea <= '0';			
							rx_ll_dst_rdy_in_n <= '1';
						end if;
					else
						rx_ll_dst_rdy_in_n <= '0';			--reject data
					end if;
				else  --write Data in Text-FIFO 
					if eth_ctr = x"10" or eth_ctr = x"11" then 
						if fifo_text_full = '0' then
							fifo_text_wea <= '1';
							rx_ll_dst_rdy_in_n <= '0';
						else
							fifo_text_wea <= '0';
							rx_ll_dst_rdy_in_n <= '1';
						end if;
					else
						rx_ll_dst_rdy_in_n <= '0';			--reject data
					end if;
				end if;
				ctr_out_i 			<= eth_ctr;
				ctr_out_write		<= '1';
				
			when rcvEOF =>
				if eth_ctr = x"10" or eth_ctr = x"11" then
					fifo_out_wea <= '1';
				end if;
				if eth_ctr = x"19" then --full FPGA reset
					nextRcvState <= rcvResetFpga;
				else
					nextRcvState <= rcvIdle;
				end if;
				
			when rcvResetFpga =>
				ext_reset_i		<= '1';
				id_set_zero		<= '1';
				nextRcvState 	<= rcvResetFpga2;
				
			when rcvResetFpga2 =>
				ext_reset_i		<= '1';
				id_set_zero		<= '1';
				nextRcvState 	<= rcvIdle;
				
			when false_data =>
				rx_ll_dst_rdy_in_n <= '0';
				if rx_ll_eof_in_n = '0' then --end of frame
					nextRcvState <= rcvIdle;
				end if;
		
			when others =>
				null;  

		end case;
	end process;
	
	--------------------------------------------------
	-- sending
	--------------------------------------------------
	
	--state transitions
	process(sendState, rx_ll_dst_rdy_out_n, send_id, eth_ctr, send_counter, send_stream, fifo_in_empty, end_frame, 
				reg_mux_out, fifo_in_dout, ctr_send_next, ctr_send_db, error_frame, ctr_send_finished, id_counter,
				fifo_text_count_avail, ctr_send_overflow)
	begin
		nextSendState <= sendState;
		
		rx_ll_data_out      	<= (others => '0');
      rx_ll_sof_out_n     	<= '1';
      rx_ll_eof_out_n     	<= '1';
      rx_ll_src_rdy_out_i  <= '1';
		
		send_set_zero  		<= '0';
		send_count	 			<= '0';
		end_set_zero			<= '0';
		end_count				<= '0';
		last_send				<= '0';
		mux_ctr					<= (others => '0');
		
		fifo_in_rea				<= '0';
		frame_send				<= '0';
		
		case sendState is
			when sendIdle =>
				send_set_zero <= '1';
				if send_id = '1' or send_stream = '1' or end_frame = '1' or ctr_send_db = '1' or ctr_send_next = '1' or
						error_frame = '1' or ctr_send_finished = '1' or ctr_send_overflow = '1' then
					nextSendState <= sendSOF;
				end if;
				
			when sendSOF =>
				if rx_ll_dst_rdy_out_n = '0' then
					send_count 				<= '1';
					rx_ll_sof_out_n     	<= '0';
					rx_ll_src_rdy_out_i  <= '0';
					rx_ll_data_out			<= reg_mux_out;
					mux_ctr					<= send_counter(3 downto 0);
					nextSendState 			<= sendMac;
				end if;
				
			when sendMac =>
				if rx_ll_dst_rdy_out_n = '0' then
					send_count 				<= '1';
					rx_ll_src_rdy_out_i  <= '0';
					rx_ll_data_out			<= reg_mux_out;
					mux_ctr					<= send_counter(3 downto 0);
					if send_counter = conv_std_logic_vector(13, 11) then
						fifo_in_rea		<= '1';
						nextSendState 	<= sendCtr;
					end if;
				end if;
				
			when sendCtr =>
				if rx_ll_dst_rdy_out_n = '0' then
					send_count <= '1';
					rx_ll_src_rdy_out_i  <= '0';
					if eth_ctr = x"20" then 	--getID
						rx_ll_data_out <= x"22";--Virtex6
						nextSendState 	<= send_unit_count_lo;
					end if;
					if send_stream = '1' then
						rx_ll_data_out <= x"11";--ctr_data
						nextSendState 	<= sendRealData;
					end if;
					if end_frame = '1' then
						rx_ll_data_out <= x"17";--ctr_finished_sending
						end_set_zero	<= '1';
						last_send		<= '1';
						nextSendState 	<= sendData;
					end if;
					if ctr_send_db = '1' then
						rx_ll_data_out <= x"14";
						nextSendState 	<= send_packet_count_lo;
					end if;
					if ctr_send_next = '1' then
						rx_ll_data_out <= x"13";
						nextSendState 	<= send_packet_count_lo;
					end if;
					if error_frame = '1' then
						rx_ll_data_out <= x"24";
						nextSendState 	<= send_error_pos;
					end if;
					if ctr_send_finished = '1' then
						rx_ll_data_out <= x"16";
						nextSendState 	<= sendData;
					end if;
					if ctr_send_overflow = '1' then
						rx_ll_data_out <= x"30";
						nextSendState 	<= sendData;
					end if;
				end if;
				
			when send_packet_count_lo =>
				rx_ll_data_out 		<= fifo_text_count_avail(7 downto 0);--number of packets
				send_count 				<= '1';
				rx_ll_src_rdy_out_i  <= '0';
				nextSendState 			<= send_packet_count_hi;
				
			when send_packet_count_hi =>
				rx_ll_data_out 		<= fifo_text_count_avail(15 downto 8);--number of packets
				send_count 				<= '1';
				rx_ll_src_rdy_out_i  <= '0';
				nextSendState 			<= sendData;
				
			when send_unit_count_lo =>
				rx_ll_data_out 		<= unit_count(7 downto 0);--number of units
				send_count 				<= '1';
				rx_ll_src_rdy_out_i  <= '0';
				nextSendState 			<= send_unit_count_hi;
				
			when send_unit_count_hi =>
				rx_ll_data_out 		<= unit_count(15 downto 8);--number of units
				send_count 				<= '1';
				rx_ll_src_rdy_out_i  <= '0';
				nextSendState 			<= sendData;
			
			when send_error_pos =>
				rx_ll_data_out 		<= id_counter;
				send_count 				<= '1';
				rx_ll_src_rdy_out_i  <= '0';
				nextSendState 			<= sendData;
				
			when sendData =>
				if rx_ll_dst_rdy_out_n = '0' then
					send_count 				<= '1';
					rx_ll_src_rdy_out_i  <= '0';
					if send_counter = conv_std_logic_vector(46, 11) then
						nextSendState <= sendEOF;
					end if;
				end if;
				
			when sendRealData =>
				if rx_ll_dst_rdy_out_n = '0' then
					if fifo_in_empty = '0' then
						send_count 				<= '1';
						rx_ll_data_out(7 downto 4)	<= fifo_in_dout(3 downto 0);
						rx_ll_data_out(3 downto 0)	<= fifo_in_dout(7 downto 4);
						rx_ll_src_rdy_out_i  		<= '0';
						fifo_in_rea						<= '1';
						end_set_zero					<= '1';
						if send_counter = conv_std_logic_vector(1512, 11) then
							nextSendState <= sendEOF;
						end if;
					else
						if end_frame = '1' then
							if send_counter >= conv_std_logic_vector(46, 11) then
								rx_ll_src_rdy_out_i  <= '1';
								nextSendState <= sendEOF;
							else
								send_count 				<= '1';
								rx_ll_src_rdy_out_i  <= '0';
								rx_ll_data_out			<= (others => '0');	
							end if;
						else
							end_count <= '1';
						end if;
					end if;
				end if;
				
			when sendEOF =>
				if rx_ll_dst_rdy_out_n = '0' then
					rx_ll_src_rdy_out_i  <= '0';
					rx_ll_eof_out_n     	<= '0';
					frame_send 				<= '1';
					if send_stream = '1' then
						rx_ll_data_out(7 downto 4)	<= fifo_in_dout(3 downto 0);
						rx_ll_data_out(3 downto 0)	<= fifo_in_dout(7 downto 4);
					end if;
					nextSendState <= sendIdle;
				end if;
				
			when others =>
				null;

		end case;
	end process;
	
	---------------------------------------------------
	-- Multiplexer for send-Header
	---------------------------------------------------
	process(mux_ctr, reg)
	begin
		case mux_ctr is
			when "0000" => reg_mux_out <= reg(55 downto 48);
			when "0001" => reg_mux_out <= reg(63 downto 56);
			when "0010" => reg_mux_out <= reg(71 downto 64);
			when "0011" => reg_mux_out <= reg(79 downto 72);
			
			when "0100" => reg_mux_out <= reg(87 downto 80);
			when "0101" => reg_mux_out <= reg(95 downto 88);
			when "0110" => reg_mux_out <= reg(7 downto 0);
			when "0111" => reg_mux_out <= reg(15 downto 8);
			
			when "1000" => reg_mux_out <= reg(23 downto 16);
			when "1001" => reg_mux_out <= reg(31 downto 24);
			when "1010" => reg_mux_out <= reg(39 downto 32);
			when "1011" => reg_mux_out <= reg(47 downto 40);
			
			when "1100" => reg_mux_out <= reg(103 downto 96);
			when "1101" => reg_mux_out <= reg(111 downto 104);
			when "1110" => reg_mux_out <= reg(119 downto 112);
			when "1111" => reg_mux_out <= reg(127 downto 120);
			
			when others => reg_mux_out <= (others => '0');
		end case;
	end process;
	
	
	rcvCounter: count_impl 
		generic map(
			COUNT_WIDTH => 11
		)
		Port map ( 
			clk 		=> clk_eth,
			res 		=> res,
			set_zero => rcv_set_zero,
			count		=> rcv_count,
			counter	=> rcv_counter
		);
		
	sendCounter: count_impl 
		generic map(
			COUNT_WIDTH => 11
		)
		Port map ( 
			clk 		=> clk_eth,
			res 		=> res,
			set_zero => send_set_zero,
			count		=> send_count,
			counter	=> send_counter
		);
		
	endCounter: count_impl 
		generic map(
			COUNT_WIDTH => 8
		)
		Port map ( 
			clk 		=> clk_eth,
			res 		=> res,
			set_zero => end_set_zero,
			count		=> end_count,
			counter	=> end_counter
		);
		
	idCounter: count_impl 
		generic map(
			COUNT_WIDTH => 8
		)
		Port map ( 
			clk 		=> clk_eth,
			res 		=> res,
			set_zero => id_set_zero,
			count		=> id_count,
			counter	=> id_counter
		);
		
	idleCounter: count_impl 
		generic map(
			COUNT_WIDTH => 30
		)
		Port map ( 
			clk 		=> clk_eth,
			res 		=> res,
			set_zero => idle_set_zero,
			count		=> idle_count,
			counter	=> idle_counter
		);
		
	mac_fpga_reg:	for K in 0 to 15 generate
		mac_reg: reg_impl
		generic map (
			WIDTH 	=> 8
		)
		port map(
			clk		=> clk_eth,
			res		=> res,
			q_out		=>	reg((k*8)+7 downto k*8),
			enable   => reg_enable(k),
			q_in		=> reg_in
		);
	end generate;
	
	FIFO_out : out_fifo
		port map (
			rst 		=> ext_reset_i,
			wr_clk 	=> clk_eth,
			rd_clk 	=> clk,
			
			din 		=> fifo_out_din,
			wr_en 	=> fifo_out_wea,
			rd_en 	=> fifo_out_rea,
			dout 		=> fifo_out_dout,
			full 		=> fifo_out_full,--open,
			prog_full=> open,--fifo_out_full,
			empty 	=> fifo_out_empty
		);
		
	FIFO_in : in_fifo
		port map (
			rst 		=> ext_reset_i,
			wr_clk 	=> clk,
			rd_clk 	=> clk_eth,
			
			din 		=> fifo_in_din,
			wr_en 	=> fifo_in_wea,
			rd_en 	=> fifo_in_rea,
			dout 		=> fifo_in_dout,
			prog_full=> fifo_in_full,
			full 		=> open,--fifo_in_full,
			empty 	=> fifo_in_empty
		);
		
	FIFO_text : text_fifo
		port map (
			rst 				=> ext_reset_i,
			wr_clk 			=> clk_eth,
			rd_clk 			=> clk,
			din 				=> fifo_text_din,
			wr_en 			=> fifo_text_wea,
			rd_en 			=> fifo_text_rea,
			dout 				=> fifo_text_dout,
			full		  	 	=> fifo_text_full,
			empty 			=> fifo_text_empty,
			wr_data_count 	=> fifo_text_count
		);
		
end Behavioral;

