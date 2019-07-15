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
-- Ethernet top-module containing control state machine and
-- the Virtex-6 local link interface
--

library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;

entity ethernet_top is
   port(
		res							: in  std_logic;
		ext_reset					: out std_logic;
		GPIO_LED						: out STD_LOGIC_VECTOR(5 downto 0);
		
		--Control
		unit_count					: in STD_LOGIC_VECTOR(15 downto 0);
		ctr_out						: out std_logic_vector(7 downto 0);
		ctr_in						: in std_logic_vector(2 downto 0);
		ctr_out_write				: out std_logic;
		ctr_stream					: in std_logic;
		
		-- data-out fifo
		fifo_out_rea				: in std_logic;
		fifo_out_dout				: out std_logic_VECTOR(31 downto 0);
		fifo_out_empty				: out std_logic;
			
		-- data-in fifo
		fifo_in_wea					: in std_logic;
		fifo_in_din					: in std_logic_VECTOR(31 downto 0);
		fifo_in_full				: out std_logic;
		
		--text-out fifo
		fifo_text_rea				: in std_logic;
		fifo_text_dout				: out std_logic_VECTOR(1 downto 0);
		fifo_text_empty			: out std_logic;
		--fifo_text_count 		: out std_logic_VECTOR(11 downto 0);

      -- Client receiver interface
      EMACCLIENTRXDVLD        : out std_logic;
      EMACCLIENTRXFRAMEDROP   : out std_logic;
      EMACCLIENTRXSTATS       : out std_logic_vector(6 downto 0);
      EMACCLIENTRXSTATSVLD    : out std_logic;
      EMACCLIENTRXSTATSBYTEVLD: out std_logic;

      -- Client transmitter interface
      CLIENTEMACTXIFGDELAY    : in  std_logic_vector(7 downto 0);
      EMACCLIENTTXSTATS       : out std_logic;
      EMACCLIENTTXSTATSVLD    : out std_logic;
      EMACCLIENTTXSTATSBYTEVLD: out std_logic;

      -- MAC control interface
      CLIENTEMACPAUSEREQ      : in  std_logic;
      CLIENTEMACPAUSEVAL      : in  std_logic_vector(15 downto 0);

      -- Clock Signal
      GTX_CLK                 : in  std_logic;

      -- GMII Interface
      GMII_TXD                : out std_logic_vector(7 downto 0);
      GMII_TX_EN              : out std_logic;
      GMII_TX_ER              : out std_logic;
      GMII_TX_CLK             : out std_logic;
      GMII_RXD                : in  std_logic_vector(7 downto 0);
      GMII_RX_DV              : in  std_logic;
      GMII_RX_ER              : in  std_logic;
      GMII_RX_CLK             : in  std_logic;

      -- Reference clock for IODELAYs
      REFCLK                  : in  std_logic;

      -- Asynchronous reset
      RESET                   : in  std_logic
   );

end ethernet_top;


architecture TOP_LEVEL of ethernet_top is

-------------------------------------------------------------------------------
-- Component declarations for lower hierarchial level entities
-------------------------------------------------------------------------------

  -- Component declaration for the LocalLink-level EMAC wrapper
  component ethernet_locallink is
   port(
      -- TX clock output
      TX_CLK_OUT               : out std_logic;
      -- TX clock input from BUFG
      TX_CLK                   : in  std_logic;

      -- LocalLink receiver interface
      RX_LL_CLOCK              : in  std_logic;
      RX_LL_RESET              : in  std_logic;
      RX_LL_DATA               : out std_logic_vector(7 downto 0);
      RX_LL_SOF_N              : out std_logic;
      RX_LL_EOF_N              : out std_logic;
      RX_LL_SRC_RDY_N          : out std_logic;
      RX_LL_DST_RDY_N          : in  std_logic;
      RX_LL_FIFO_STATUS        : out std_logic_vector(3 downto 0);

      -- LocalLink transmitter interface
      TX_LL_CLOCK              : in  std_logic;
      TX_LL_RESET              : in  std_logic;
      TX_LL_DATA               : in  std_logic_vector(7 downto 0);
      TX_LL_SOF_N              : in  std_logic;
      TX_LL_EOF_N              : in  std_logic;
      TX_LL_SRC_RDY_N          : in  std_logic;
      TX_LL_DST_RDY_N          : out std_logic;

      -- Client receiver interface
      EMACCLIENTRXDVLD         : out std_logic;
      EMACCLIENTRXFRAMEDROP    : out std_logic;
      EMACCLIENTRXSTATS        : out std_logic_vector(6 downto 0);
      EMACCLIENTRXSTATSVLD     : out std_logic;
      EMACCLIENTRXSTATSBYTEVLD : out std_logic;

      -- Client Transmitter Interface
      CLIENTEMACTXIFGDELAY     : in  std_logic_vector(7 downto 0);
      EMACCLIENTTXSTATS        : out std_logic;
      EMACCLIENTTXSTATSVLD     : out std_logic;
      EMACCLIENTTXSTATSBYTEVLD : out std_logic;

      -- MAC control interface
      CLIENTEMACPAUSEREQ       : in  std_logic;
      CLIENTEMACPAUSEVAL       : in  std_logic_vector(15 downto 0);

      -- Receive-side PHY clock on regional buffer, to EMAC
      PHY_RX_CLK               : in  std_logic;

      -- Reference clock
      GTX_CLK                  : in  std_logic;

      -- GMII interface
      GMII_TXD                 : out std_logic_vector(7 downto 0);
      GMII_TX_EN               : out std_logic;
      GMII_TX_ER               : out std_logic;
      GMII_TX_CLK              : out std_logic;
      GMII_RXD                 : in  std_logic_vector(7 downto 0);
      GMII_RX_DV               : in  std_logic;
      GMII_RX_ER               : in  std_logic;
      GMII_RX_CLK              : in  std_logic;

      -- Asynchronous reset
      RESET                    : in  std_logic
   );
  end component;
	
	component eth_control is
		Port (
			clk_eth 					: in  STD_LOGIC;
			clk						: in  STD_LOGIC;
			res 						: in  STD_LOGIC;
			ext_reset				: out std_logic;
			GPIO_LED					: out STD_LOGIC_VECTOR(5 downto 0);
			unit_count				: in STD_LOGIC_VECTOR(15 downto 0);
			
			--Control
			ctr_out					: out std_logic_vector(7 downto 0);
			ctr_in					: in std_logic_vector(2 downto 0);
			ctr_out_write			: out std_logic;
			ctr_stream				: in std_logic;
			
			-- data-out fifo
			fifo_out_rea			: in std_logic;
			fifo_out_dout			: out std_logic_VECTOR(31 downto 0);
			fifo_out_empty			: out std_logic;
			
			-- data-in fifo
			fifo_in_wea				: in std_logic;
			fifo_in_din				: in std_logic_VECTOR(31 downto 0);
			fifo_in_full			: out std_logic;
			
			--text-out fifo
			fifo_text_rea			: in std_logic;
			fifo_text_dout			: out std_logic_VECTOR(1 downto 0);
			fifo_text_empty		: out std_logic;			
			--fifo_text_count 		: out std_logic_VECTOR(11 downto 0);
			
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
	end component;


-----------------------------------------------------------------------
-- Signal declarations
-----------------------------------------------------------------------

    -- Global asynchronous reset
    signal reset_i             : std_logic;

    -- LocalLink interface clocking signal
    signal ll_clk_i            : std_logic;

    -- Address swap transmitter connections
    signal tx_ll_data_i        : std_logic_vector(7 downto 0);
    signal tx_ll_sof_n_i       : std_logic;
    signal tx_ll_eof_n_i       : std_logic;
    signal tx_ll_src_rdy_n_i   : std_logic;
    signal tx_ll_dst_rdy_n_i   : std_logic;

   -- Address swap receiver connections
    signal rx_ll_data_i        : std_logic_vector(7 downto 0);
    signal rx_ll_sof_n_i       : std_logic;
    signal rx_ll_eof_n_i       : std_logic;
    signal rx_ll_src_rdy_n_i   : std_logic;
    signal rx_ll_dst_rdy_n_i   : std_logic;

    -- Synchronous reset registers in the LocalLink clock domain
    signal ll_pre_reset_i     : std_logic_vector(5 downto 0);
    signal ll_reset_i         : std_logic;

    attribute async_reg : string;
    attribute async_reg of ll_pre_reset_i : signal is "true";

    -- Reference clock for IODELAYs
    signal refclk_ibufg_i      : std_logic;
    signal refclk_bufg_i       : std_logic;

    -- GMII input clocks to wrappers
    signal tx_clk              : std_logic;

    attribute keep : boolean;
    attribute keep of tx_clk : signal is true;

    signal rx_clk_i            : std_logic;
    signal gmii_rx_clk_bufio   : std_logic;
    signal gmii_rx_clk_delay   : std_logic;

    -- IDELAY controller
    signal idelayctrl_reset_r  : std_logic_vector(12 downto 0);
    signal idelayctrl_reset_i  : std_logic;

    attribute syn_noprune : boolean;
    attribute syn_noprune of dlyctrl : label is true;

    attribute buffer_type : string;

    -- GTX reference clock
    signal gtx_clk_i		: std_logic;
	

-------------------------------------------------------------------------------
-- Main body of code
-------------------------------------------------------------------------------

begin

	reset_i <= RESET;

    --------------------------------------------------------------------------
    -- Clock skew management: use IDELAY on GMII_RX_CLK to move
    -- the clock into proper alignment with the data
    --------------------------------------------------------------------------

    -- Instantiate IDELAYCTRL for the IDELAY in Fixed Tap Delay Mode
    dlyctrl : IDELAYCTRL port map (
      RDY    => open,
      REFCLK => refclk_bufg_i,
      RST    => idelayctrl_reset_i
    );

    -- Assert the proper reset pulse for the IDELAYCTRL
    delayrstgen :process (refclk_bufg_i, reset_i)
    begin
      if (reset_i = '1') then
        idelayctrl_reset_r(0)           <= '0';
        idelayctrl_reset_r(12 downto 1) <= (others => '1');
      elsif refclk_bufg_i'event and refclk_bufg_i = '1' then
        idelayctrl_reset_r(0)           <= '0';
        idelayctrl_reset_r(12 downto 1) <= idelayctrl_reset_r(11 downto 0);
      end if;
    end process delayrstgen;
    idelayctrl_reset_i <= idelayctrl_reset_r(12);


    -- Globally-buffer the GTX reference clock, used to clock
    -- the transmit-side functions of the EMAC wrappers
    -- (tx_clk can be shared between multiple EMAC instances, including
    --  multiple instantiations of the EMAC wrappers)
    bufg_tx : BUFG port map (
      I => gtx_clk_i,
      O => tx_clk
    );

    -- Use a low-skew BUFIO on the delayed RX_CLK, which will be used in the
    -- GMII phyical interface block to capture incoming data and control.
    bufio_rx : BUFIO port map (
      I => GMII_RX_CLK,
      O => gmii_rx_clk_bufio
    );

    -- Regionally-buffer the receive-side GMII physical interface clock
    -- for use with receive-side functions of the EMAC
    bufr_rx : BUFR generic map (
		SIM_DEVICE => "VIRTEX6"
	 ) port map (
      I   => GMII_RX_CLK,
      O   => rx_clk_i,
      CE  => '1',
      CLR => '0'
    );

    -- Clock the LocalLink interface with the globally-buffered
    -- GTX reference clock
    ll_clk_i <= tx_clk;
	 
	 ---------------------------------------------------------------------
    --  Instatiate the ethernet-control module
    ---------------------------------------------------------------------

	ethernet_control : eth_control 
		 port map (
			clk_eth 					=> GTX_CLK,
			clk 						=> REFCLK,
			res 						=> res,
			ext_reset				=> ext_reset,
			GPIO_LED					=> GPIO_LED,
			unit_count				=> unit_count,
			
			fifo_out_rea			=> fifo_out_rea,
			fifo_out_dout			=> fifo_out_dout,
			fifo_out_empty			=> fifo_out_empty,
			
			fifo_in_wea				=> fifo_in_wea,
			fifo_in_din				=> fifo_in_din,
			fifo_in_full			=> fifo_in_full,
			ctr_out_write			=> ctr_out_write,
			
			fifo_text_rea			=> fifo_text_rea,
			fifo_text_dout			=> fifo_text_dout,
			fifo_text_empty		=> fifo_text_empty,
			
			ctr_out					=> ctr_out,
			ctr_in					=> ctr_in,
			ctr_stream				=> ctr_stream,
			
			--Ethernet-Signals
			rx_ll_data_in       	=> rx_ll_data_i,
			rx_ll_sof_in_n      	=> rx_ll_sof_n_i,
			rx_ll_eof_in_n      	=> rx_ll_eof_n_i,
			rx_ll_src_rdy_in_n  	=> rx_ll_src_rdy_n_i,
			rx_ll_dst_rdy_in_n  	=> rx_ll_dst_rdy_n_i,
			
			rx_ll_data_out      	=> tx_ll_data_i,
			rx_ll_sof_out_n     	=> tx_ll_sof_n_i,
			rx_ll_eof_out_n     	=> tx_ll_eof_n_i,
			rx_ll_src_rdy_out_n 	=> tx_ll_src_rdy_n_i,
			rx_ll_dst_rdy_out_n  => tx_ll_dst_rdy_n_i
		);
		
		


    ------------------------------------------------------------------------
    -- Instantiate the LocalLink-level EMAC Wrapper (eth_locallink.vhd)
    ------------------------------------------------------------------------
    eth_locallink_inst : ethernet_locallink port map (
      -- TX clock output
      TX_CLK_OUT               => open,
      -- TX clock input from BUFG
      TX_CLK                   => tx_clk,

      -- LocalLink receiver interface
      RX_LL_CLOCK              => ll_clk_i,
      RX_LL_RESET              => ll_reset_i,
      RX_LL_DATA               => rx_ll_data_i,
      RX_LL_SOF_N              => rx_ll_sof_n_i,
      RX_LL_EOF_N              => rx_ll_eof_n_i,
      RX_LL_SRC_RDY_N          => rx_ll_src_rdy_n_i,
      RX_LL_DST_RDY_N          => rx_ll_dst_rdy_n_i,
      RX_LL_FIFO_STATUS        => open,

      -- Client receiver signals
      EMACCLIENTRXDVLD         => EMACCLIENTRXDVLD,
      EMACCLIENTRXFRAMEDROP    => EMACCLIENTRXFRAMEDROP,
      EMACCLIENTRXSTATS        => EMACCLIENTRXSTATS,
      EMACCLIENTRXSTATSVLD     => EMACCLIENTRXSTATSVLD,
      EMACCLIENTRXSTATSBYTEVLD => EMACCLIENTRXSTATSBYTEVLD,

      -- LocalLink transmitter interface
      TX_LL_CLOCK              => ll_clk_i,
      TX_LL_RESET              => ll_reset_i,
      TX_LL_DATA               => tx_ll_data_i,
      TX_LL_SOF_N              => tx_ll_sof_n_i,
      TX_LL_EOF_N              => tx_ll_eof_n_i,
      TX_LL_SRC_RDY_N          => tx_ll_src_rdy_n_i,
      TX_LL_DST_RDY_N          => tx_ll_dst_rdy_n_i,

      -- Client transmitter signals
      CLIENTEMACTXIFGDELAY     => CLIENTEMACTXIFGDELAY,
      EMACCLIENTTXSTATS        => EMACCLIENTTXSTATS,
      EMACCLIENTTXSTATSVLD     => EMACCLIENTTXSTATSVLD,
      EMACCLIENTTXSTATSBYTEVLD => EMACCLIENTTXSTATSBYTEVLD,

      -- MAC control interface
      CLIENTEMACPAUSEREQ       => CLIENTEMACPAUSEREQ,
      CLIENTEMACPAUSEVAL       => CLIENTEMACPAUSEVAL,

      -- Receive-side PHY clock on regional buffer, to EMAC
      PHY_RX_CLK               => rx_clk_i,

      -- Reference clock (unused)
      GTX_CLK                  => '0',

      -- GMII interface
      GMII_TXD                 => GMII_TXD,
      GMII_TX_EN               => GMII_TX_EN,
      GMII_TX_ER               => GMII_TX_ER,
      GMII_TX_CLK              => GMII_TX_CLK,
      GMII_RXD                 => GMII_RXD,
      GMII_RX_DV               => GMII_RX_DV,
      GMII_RX_ER               => GMII_RX_ER,
      GMII_RX_CLK              => gmii_rx_clk_bufio,

      -- Asynchronous reset
      RESET                    => reset_i
    );

    -- Create synchronous reset in the transmitter clock domain
    gen_ll_reset : process (ll_clk_i, reset_i)
    begin
      if reset_i = '1' then
        ll_pre_reset_i <= (others => '1');
        ll_reset_i     <= '1';
      elsif ll_clk_i'event and ll_clk_i = '1' then
        ll_pre_reset_i(0)          <= '0';
        ll_pre_reset_i(5 downto 1) <= ll_pre_reset_i(4 downto 0);
        ll_reset_i                 <= ll_pre_reset_i(5);
      end if;
    end process gen_ll_reset;

	 refclk_ibufg_i <= REFCLK;
	 
    refclk_bufg : BUFG port map (
      I => refclk_ibufg_i,
      O => refclk_bufg_i
    );

	gtx_clk_i <= GTX_CLK;

end TOP_LEVEL;
