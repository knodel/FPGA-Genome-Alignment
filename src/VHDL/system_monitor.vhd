-- file: system_monitor.vhd
-- (c) Copyright 2009 - 2010 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
Library UNISIM;
use UNISIM.VCOMPONENTS.ALL;

entity system_monitor is
    port (
          RESET_IN            : in  STD_LOGIC;                         -- Reset signal for the System Monitor control logic
          OT_OUT              : out  STD_LOGIC;                        -- Over-Temperature alarm output
          USER_TEMP_ALARM_OUT : out  STD_LOGIC;                        -- Temperature-sensor alarm output
          VP_IN               : in  STD_LOGIC;                         -- Dedicated Analog Input Pair
          VN_IN               : in  STD_LOGIC
);
end system_monitor;

architecture xilinx of system_monitor is

  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of xilinx : architecture is "sysmon_wiz_v2_0, Coregen 12.1";

  signal FLOAT_VCCAUX_ALARM : std_logic;
  signal FLOAT_VCCINT_ALARM : std_logic;
  signal aux_channel_p : std_logic_vector (15 downto 0);
  signal aux_channel_n : std_logic_vector (15 downto 0);

begin

        aux_channel_p(0) <= '0';
        aux_channel_n(0) <= '0';

        aux_channel_p(1) <= '0';
        aux_channel_n(1) <= '0';

        aux_channel_p(2) <= '0';
        aux_channel_n(2) <= '0';

        aux_channel_p(3) <= '0';
        aux_channel_n(3) <= '0';

        aux_channel_p(4) <= '0';
        aux_channel_n(4) <= '0';

        aux_channel_p(5) <= '0';
        aux_channel_n(5) <= '0';

        aux_channel_p(6) <= '0';
        aux_channel_n(6) <= '0';

        aux_channel_p(7) <= '0';
        aux_channel_n(7) <= '0';

        aux_channel_p(8) <= '0';
        aux_channel_n(8) <= '0';

        aux_channel_p(9) <= '0';
        aux_channel_n(9) <= '0';

        aux_channel_p(10) <= '0';
        aux_channel_n(10) <= '0';

        aux_channel_p(11) <= '0';
        aux_channel_n(11) <= '0';

        aux_channel_p(12) <= '0';
        aux_channel_n(12) <= '0';

        aux_channel_p(13) <= '0';
        aux_channel_n(13) <= '0';

        aux_channel_p(14) <= '0';
        aux_channel_n(14) <= '0';

        aux_channel_p(15) <= '0';
        aux_channel_n(15) <= '0';


 SYSMON_INST : SYSMON
     generic map(
        INIT_40 => X"0000", -- config reg 0
        INIT_41 => X"300c", -- config reg 1
        INIT_42 => X"0a00", -- config reg 2
        INIT_48 => X"0100", -- Sequencer channel selection
        INIT_49 => X"0000", -- Sequencer channel selection
        INIT_4A => X"0000", -- Sequencer Average selection
        INIT_4B => X"0000", -- Sequencer Average selection
        INIT_4C => X"0000", -- Sequencer Bipolar selection
        INIT_4D => X"0000", -- Sequencer Bipolar selection
        INIT_4E => X"0000", -- Sequencer Acq time selection
        INIT_4F => X"0000", -- Sequencer Acq time selection
        INIT_50 => X"a418", -- Temp alarm trigger
        INIT_51 => X"5999", -- Vccint upper alarm limit
        INIT_52 => X"e000", -- Vccaux upper alarm limit
        INIT_53 => X"ca33",  -- Temp alarm OT upper
        INIT_54 => X"9c87", -- Temp alarm reset
        INIT_55 => X"5111", -- Vccint lower alarm limit
        INIT_56 => X"caaa", -- Vccaux lower alarm limit
        INIT_57 => X"a425",  -- Temp alarm OT reset
        SIM_DEVICE => "VIRTEX6",
        SIM_MONITOR_FILE => "design.txt"
        )

port map (
        CONVST              => '0',
        CONVSTCLK           => '0',
        DADDR(6 downto 0)   => "0000000",
        DCLK                => '0',
        DEN                 => '0',
        DI(15 downto 0)     => "0000000000000000",
        DWE                 => '0',
        RESET               => RESET_IN,
        VAUXN(15 downto 0)  => aux_channel_n(15 downto 0),
        VAUXP(15 downto 0)  => aux_channel_p(15 downto 0),
        ALM(2)              => FLOAT_VCCAUX_ALARM,
        ALM(1)              => FLOAT_VCCINT_ALARM,
        ALM(0)              => USER_TEMP_ALARM_OUT,
        BUSY                => open,
        CHANNEL             => open,
        DO                  => open,
        DRDY                => open,
        EOC                 => open,
        EOS                 => open,
        JTAGBUSY            => open,
        JTAGLOCKED          => open,
        JTAGMODIFIED        => open,
        OT                  => OT_OUT,
        VN                  => VN_IN,
        VP                  => VP_IN
         );
end xilinx;

