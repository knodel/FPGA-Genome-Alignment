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
-- Top-Module of the design containing ethernet-, control-
-- and search modules.
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

entity ml605_top is
	generic (
		WIDTH_TEXT 		: positive := 64; --ocrom: 64
		DOUBLE_UNITS 	: positive := 250 --max: 300 
	);
	Port ( 
		--Clock and Reset
		SYSCLK_N		: in STD_LOGIC;
		SYSCLK_P		: in STD_LOGIC;
		CPU_RESET	: in STD_LOGIC;
		PHY_RESET	: out std_logic;
				
		--Fan-Controll
		SM_FAN_PWM 	: out STD_LOGIC;
		SM_FAN_TACH : out STD_LOGIC;
				
		--LED and Switches
		GPIO_LED		: out STD_LOGIC_VECTOR(7 downto 0);
		GPIO_DIP_SW	: in STD_LOGIC;
				
		--LCD
		LCD_DB		: inout STD_LOGIC_VECTOR(3 downto 0);
		LCD_E_LS		: out STD_LOGIC;
		LCD_RS_LS	: out STD_LOGIC;
		LCD_RW_LS	: out STD_LOGIC;
		
	   -- Ethernet PHY signals (alphabetical)
      -- GMII Interface
      GMII_TXD                 : out std_logic_vector(7 downto 0);
      GMII_TX_EN               : out std_logic;
      GMII_TX_ER               : out std_logic;
      GMII_TX_CLK              : out std_logic;
      GMII_RXD                 : in  std_logic_vector(7 downto 0);
      GMII_RX_DV               : in  std_logic;
      GMII_RX_ER               : in  std_logic;
      GMII_RX_CLK              : in  std_logic;
      MII_TX_CLK               : in  std_logic
	);
end ml605_top;

architecture Behavioral of ml605_top is
	
	component clock
		port(
			-- Clock in ports
			CLK_IN1_P         : in     std_logic;
			CLK_IN1_N         : in     std_logic;
		   -- Clock out ports
			CLK_OUT1          : out    std_logic;
			CLK_OUT2          : out    std_logic;
			CLK_OUT3          : out    std_logic;
			-- Status and control signals
			RESET             : in     std_logic;
			LOCKED            : out    std_logic
		 );
	end component;
	
	component fan_control is
		Port ( 
			clk 		: in  STD_LOGIC;
         res 		: in  STD_LOGIC;
			fan_sw	: in  STD_LOGIC;
			  
			fan_pwm 	: out STD_LOGIC;
			fan_tach	: out STD_LOGIC
		);
	end component;
	
	component lcd_top is
		port(
			clk			: in   std_logic;
			rst			: in   std_logic;
			data			: in std_logic_vector(31 downto 0);
			lcd_state	: in std_logic_vector(3 downto 0);
			
			-- LCD
			lcd_dat		: inout std_logic_vector(3 downto 0);
			lcd_e			: out   std_logic;
			lcd_rs		: out   std_logic;
			lcd_rw		: out   std_logic
		);
	end component;
	
	component search_top is
		generic(
			WIDTH_TEXT 		: positive := 64;--Zeichen
			DOUBLE_UNITS 	: positive := 1
		);
		Port ( 
			res				: in  STD_LOGIC;
         clk	 			: in  STD_LOGIC;
			
			--Text
			text_in 			: in STD_LOGIC_VECTOR(1 downto 0);
			
			--Steuersignale
			control 			: in STD_LOGIC_VECTOR(8 downto 0);
			overflow			: OUT std_logic;
			bus_free			: OUT std_logic;
			
			--Block RAM
			unit 				: IN std_logic_VECTOR(8 downto 0);
			we					: IN std_logic_VECTOR(0 downto 0);
			din				: IN std_logic_VECTOR(31 downto 0);
			dout				: OUT std_logic_VECTOR(31 downto 0)
		);
	end component;
	
	component search_control is
		 Port ( 
			clk 				: in  STD_LOGIC;
			clk_eth			: in  STD_LOGIC;
			res 				: in  STD_LOGIC;
			
			ext_reset		: in std_logic;
			lcd_data			: out std_logic_vector(31 downto 0);
			
			--Control
			ctr_out			: out std_logic_vector(2 downto 0);
			ctr_in			: in  std_logic_vector(7 downto 0);
			ctr_in_write	: IN 	std_logic;
			ctr_stream		: OUT std_logic;
			
			control 			: OUT STD_LOGIC_VECTOR(8 downto 0);
			overflow			: IN std_logic;
			bus_free			: IN std_logic;
			
			lcd_state		: OUT std_logic_vector(3 downto 0);
					
			--Block RAM
			unit 				: OUT std_logic_VECTOR(8 downto 0);
			we					: OUT std_logic_VECTOR(0 downto 0);
			
			--fifo out
			fifo_out_rea	: out std_logic;
			fifo_out_empty	: in std_logic;
			
			-- data-in fifo
			fifo_in_wea				: out std_logic;
			fifo_in_full			: in std_logic;
			fifo_in_din				: in std_logic_VECTOR(31 downto 0);
			fifo_out_din			: in 	std_logic_vector(31 downto 0);
			
			--text-out fifo
			fifo_text_rea			: out std_logic;
			fifo_text_empty		: in std_logic

		 );
	end component;
	
	component ethernet_top is
		port(
			res							 : in  std_logic;
			ext_reset					: out std_logic;
			
			GPIO_LED						: out STD_LOGIC_VECTOR(5 downto 0);
			
			--Control
			unit_count					 : in STD_LOGIC_VECTOR(15 downto 0);
			ctr_out						 : out std_logic_vector(7 downto 0);
			ctr_in						 : in std_logic_vector(2 downto 0);
			ctr_out_write				 : out std_logic;
			ctr_stream					 : in std_logic;
			
			-- data-out fifo
			fifo_out_rea				 : in std_logic;
			fifo_out_dout				 : out std_logic_VECTOR(31 downto 0);
			fifo_out_empty				 : out std_logic;
			
			-- data-in fifo
			fifo_in_wea					 : in std_logic;
			fifo_in_din					 : in std_logic_VECTOR(31 downto 0);
			fifo_in_full				 : out std_logic;
			
			--text-out fifo
			fifo_text_rea				: in std_logic;
			fifo_text_dout				: out std_logic_VECTOR(1 downto 0);
			fifo_text_empty			: out std_logic;
			--fifo_text_count 		: out std_logic_VECTOR(11 downto 0);

			-- Client receiver interface
			EMACCLIENTRXDVLD         : out std_logic;
			EMACCLIENTRXFRAMEDROP    : out std_logic;
			EMACCLIENTRXSTATS        : out std_logic_vector(6 downto 0);
			EMACCLIENTRXSTATSVLD     : out std_logic;
			EMACCLIENTRXSTATSBYTEVLD : out std_logic;

			-- Client transmitter interface
			CLIENTEMACTXIFGDELAY     : in  std_logic_vector(7 downto 0);
			EMACCLIENTTXSTATS        : out std_logic;
			EMACCLIENTTXSTATSVLD     : out std_logic;
			EMACCLIENTTXSTATSBYTEVLD : out std_logic;

			-- MAC control interface
			CLIENTEMACPAUSEREQ       : in  std_logic;
			CLIENTEMACPAUSEVAL       : in  std_logic_vector(15 downto 0);

			-- Clock Signal
			GTX_CLK                  : in  std_logic;

			-- GMII Interface
			GMII_TXD                 : out std_logic_vector(7 downto 0);
			GMII_TX_EN               : out std_logic;
			GMII_TX_ER               : out std_logic;
			GMII_TX_CLK              : out std_logic;
			GMII_RXD                 : in  std_logic_vector(7 downto 0);
			GMII_RX_DV               : in  std_logic;
			GMII_RX_ER               : in  std_logic;
			GMII_RX_CLK              : in  std_logic;

			-- Reference clock for IODELAYs
			REFCLK                   : in  std_logic;

			-- Asynchronous reset
			RESET                    : in  std_logic
		);
	end component;
	
	------------------------------------------------
	-- Signal Declarations
	------------------------------------------------
	
	--Clock
	signal clk					: std_logic; --200 MHz
	signal clk100				: std_logic; --100 MHz
	signal clk125				: std_logic; --125 MHz	
	signal locked				: std_logic;

	
	--Reset
	signal fpga_cpu_reset	: std_logic;
	signal async_rst			: std_logic;
	signal res_0 				: std_logic;
	signal res100_0 			: std_logic;
	signal res125_0 			: std_logic;
	signal ext_reset			: std_logic;
	
	--Synchron Reset-Signals
	signal res					: std_logic;
	signal res100 				: std_logic;
	signal res125 				: std_logic;
	
  --Ethernet
  
	signal tx_ll_data_0_i      : std_logic_vector(7 downto 0);
	signal tx_ll_sof_n_0_i     : std_logic;
	signal tx_ll_eof_n_0_i     : std_logic;
	signal tx_ll_src_rdy_n_0_i : std_logic;
	signal tx_ll_dst_rdy_n_0_i : std_logic;

	signal rx_ll_data_0_i      : std_logic_vector(7 downto 0);
	signal rx_ll_sof_n_0_i     : std_logic;
	signal rx_ll_eof_n_0_i     : std_logic;
	signal rx_ll_src_rdy_n_0_i : std_logic;
	signal rx_ll_dst_rdy_n_0_i : std_logic;
	signal rx_ll_status_i		: std_logic_vector(3 downto 0);	
	
	--search_control -> search
	signal overflow 		: std_logic;
	signal control 		: STD_LOGIC_VECTOR(8 downto 0);
	signal bus_free		: std_logic;
	
	signal ctr_out			: std_logic_vector(7 downto 0);
	signal ctr_in			: std_logic_vector(2 downto 0);
	signal ctr_out_write	: std_logic;
	signal ctr_stream		: std_logic;
	
	signal unit 			: std_logic_VECTOR(8 downto 0);
	signal we				: std_logic_VECTOR(0 downto 0);
	
	signal fifo_out_rea	: std_logic;
	signal fifo_out_dout	: std_logic_VECTOR(31 downto 0);
	signal fifo_out_empty: std_logic;
	
	signal fifo_in_wea	: std_logic;
	signal fifo_in_din	: std_logic_VECTOR(31 downto 0);
	signal fifo_in_full	: std_logic;
	
	--text-out fifo
	signal fifo_text_rea		: std_logic;
	signal fifo_text_dout	: std_logic_VECTOR(1 downto 0);
	signal fifo_text_empty	: std_logic;
	
	--LCD
	signal lcd_state		: std_logic_vector(3 downto 0);
	signal lcd_data		: std_logic_vector(31 downto 0);

begin

	----------------------------------
	-- Components
	----------------------------------

	clock_gen : clock
		port map (
			-- Clock in ports
			CLK_IN1_P	=> SYSCLK_P,
			CLK_IN1_N	=> SYSCLK_N,
			
			-- Clock out ports
			CLK_OUT1		=> clk,
			CLK_OUT2		=> clk100,
			CLK_OUT3		=> clk125,
			
			-- Status and control signals
			RESET			=> fpga_cpu_reset,
			LOCKED		=> locked
		);
			
	lcd : lcd_top 
		port map(
			clk			=> clk100,
			rst			=> res100,
			data			=>	lcd_data,
			lcd_state	=> lcd_state,
			
			-- LCD
			lcd_dat		=> LCD_DB,
			lcd_e			=> LCD_E_LS,
			lcd_rs		=> LCD_RS_LS,
			lcd_rw		=> LCD_RW_LS
		);
		
	fan : fan_control 
		Port map( 
			clk 		=> clk,
         res 		=> res,
			
			fan_sw	=> GPIO_DIP_SW,
			fan_pwm 	=> SM_FAN_PWM,
			fan_tach	=> SM_FAN_TACH
		);
		
  ethernet : ethernet_top 
		port map(
			-- Reference clock for IODELAYs and Control-Module
			REFCLK                   => clk,
			ext_reset					 => ext_reset,
			GPIO_LED						 => GPIO_LED(5 downto 0),

			-- Asynchronous reset
			RESET                    => async_rst,
			res							 => res125,
			
			unit_count					 => conv_std_logic_vector(DOUBLE_UNITS, 16),
					
			fifo_out_rea				 => fifo_out_rea,
			fifo_out_dout				 => fifo_out_dout,
			fifo_out_empty				 => fifo_out_empty,
				
			fifo_in_wea					 => fifo_in_wea,
			fifo_in_din					 => fifo_in_din,
			fifo_in_full				 => fifo_in_full,
			
			--text-out fifo
			fifo_text_rea				=> fifo_text_rea,
			fifo_text_dout				=> fifo_text_dout,
			fifo_text_empty			=> fifo_text_empty,
				
			ctr_out						 => ctr_out,
			ctr_in						 => ctr_in,
			ctr_out_write				 => ctr_out_write,
			ctr_stream					 => ctr_stream,

			-- Client receiver interface
			EMACCLIENTRXDVLD         => open,
			EMACCLIENTRXFRAMEDROP    => open,
			EMACCLIENTRXSTATS        => open,
			EMACCLIENTRXSTATSVLD     => open,
			EMACCLIENTRXSTATSBYTEVLD => open,

			-- Client transmitter interface
			CLIENTEMACTXIFGDELAY     => (others => '0'),
			EMACCLIENTTXSTATS        => open,
			EMACCLIENTTXSTATSVLD     => open,
			EMACCLIENTTXSTATSBYTEVLD => open,

			-- MAC control interface
			CLIENTEMACPAUSEREQ       => '0',
			CLIENTEMACPAUSEVAL       => (others => '0'),

			-- Clock Signal
			GTX_CLK                  => clk125,   

			-- GMII Interface
			GMII_TXD                 => GMII_TXD,
			GMII_TX_EN               => gmii_tx_en,
			GMII_TX_ER               => gmii_tx_er,
			GMII_TX_CLK              => gmii_tx_clk,
			GMII_RXD                 => gmii_rxd,
			GMII_RX_DV               => gmii_rx_dv,
			GMII_RX_ER               => gmii_rx_er,
			GMII_RX_CLK              => gmii_rx_clk
		);
		
	search : search_top
		generic map(
			WIDTH_TEXT 		=> WIDTH_TEXT,
			DOUBLE_UNITS 	=> DOUBLE_UNITS
		)
		Port map( 
			res				=> res,
			clk	 			=> clk,
			text_in 			=> fifo_text_dout,
			
			control 			=> control,
			overflow			=> overflow,
			bus_free			=> bus_free,
			
			unit 				=> unit,
			we					=> we,
			din				=> fifo_out_dout,
			dout				=> fifo_in_din
		);
		
	controlunit : search_control
		 port map( 
			clk 				=> clk,
			clk_eth			=> clk125,
			res 				=> res,
			ext_reset		=> ext_reset,
			lcd_data			=> lcd_data,
			
			control 			=> control,
			overflow			=> overflow,
			bus_free			=> bus_free,
			
			lcd_state		=> lcd_state,
			
			ctr_in			=> ctr_out,
			ctr_in_write	=> ctr_out_write,
			ctr_out			=> ctr_in,
			ctr_stream		=> ctr_stream,
				
			unit 				=> unit,
			we					=> we,
			
			fifo_out_rea	=> fifo_out_rea,
			fifo_out_empty	=> fifo_out_empty,
			fifo_in_din		=> fifo_out_dout,
			fifo_out_din	=> fifo_in_din,
			
			fifo_in_wea		=> fifo_in_wea,
			fifo_in_full	=> fifo_in_full,
			
			fifo_text_rea	=> fifo_text_rea,
			fifo_text_empty=> fifo_text_empty
		 );
			
	----------------------------------
	-- Synchronizing reset
	----------------------------------

	 -- Reset input buffer
   reset_ibuf : IBUF port map (
		I => CPU_RESET,
		O => fpga_cpu_reset
   );
	 
	async_rst    	<= fpga_cpu_reset or (not locked);
	PHY_RESET		<= not async_rst;
	
	process (clk, async_rst)
	begin
		if rising_edge(clk) then
			res_0 <= async_rst;
			res <= res_0;
		end if;
	end process;
	
	process (clk100, async_rst)
	begin
		if rising_edge(clk100) then
			res100_0 <= async_rst;
			res100 <= res100_0;
		end if;
	end process;
	
	process (clk125, async_rst)
	begin
		if rising_edge(clk125) then
			res125_0 <= async_rst;
			res125 <= res125_0;
		end if;
	end process;
	
	----------------------------------
	-- LEDs
	----------------------------------

	GPIO_LED(7) <= locked;
	GPIO_LED(6) <= fpga_cpu_reset;
		
	--GPIO_LED(5 downto 0) <= (others => '0');

end Behavioral;

