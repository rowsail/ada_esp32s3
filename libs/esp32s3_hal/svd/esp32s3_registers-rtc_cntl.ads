pragma Style_Checks (Off);

--  Copyright 2024 Espressif Systems (Shanghai) PTE LTD
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

--  This spec has been automatically generated from esp32s3.svd

pragma Restrictions (No_Elaboration_Code);

with System;

package ESP32S3_Registers.RTC_CNTL is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype OPTIONS0_SW_STALL_APPCPU_C0_Field is ESP32S3_Registers.UInt2;
   subtype OPTIONS0_SW_STALL_PROCPU_C0_Field is ESP32S3_Registers.UInt2;
   subtype OPTIONS0_XTL_EN_WAIT_Field is ESP32S3_Registers.UInt4;

   --  RTC common configure register
   type OPTIONS0_Register is record
      --  {reg_sw_stall_appcpu_c1[5:0], reg_sw_stall_appcpu_c0[1:0]} == 0x86
      --  will stall APP CPU
      SW_STALL_APPCPU_C0  : OPTIONS0_SW_STALL_APPCPU_C0_Field := 16#0#;
      --  {reg_sw_stall_procpu_c1[5:0], reg_sw_stall_procpu_c0[1:0]} == 0x86
      --  will stall PRO CPU
      SW_STALL_PROCPU_C0  : OPTIONS0_SW_STALL_PROCPU_C0_Field := 16#0#;
      --  Write-only. APP CPU SW reset
      SW_APPCPU_RST       : Boolean := False;
      --  Write-only. PRO CPU SW reset
      SW_PROCPU_RST       : Boolean := False;
      --  BB_I2C force power down
      BB_I2C_FORCE_PD     : Boolean := False;
      --  BB_I2C force power up
      BB_I2C_FORCE_PU     : Boolean := False;
      --  BB_PLL _I2C force power down
      BBPLL_I2C_FORCE_PD  : Boolean := False;
      --  BB_PLL_I2C force power up
      BBPLL_I2C_FORCE_PU  : Boolean := False;
      --  BB_PLL force power down
      BBPLL_FORCE_PD      : Boolean := False;
      --  BB_PLL force power up
      BBPLL_FORCE_PU      : Boolean := False;
      --  crystall force power down
      XTL_FORCE_PD        : Boolean := False;
      --  crystall force power up
      XTL_FORCE_PU        : Boolean := True;
      --  wait bias_sleep and current source wakeup
      XTL_EN_WAIT         : OPTIONS0_XTL_EN_WAIT_Field := 16#2#;
      --  unspecified
      Reserved_18_22      : ESP32S3_Registers.UInt5 := 16#0#;
      --  No public
      XTL_FORCE_ISO       : Boolean := False;
      --  No public
      PLL_FORCE_ISO       : Boolean := False;
      --  No public
      ANALOG_FORCE_ISO    : Boolean := False;
      --  No public
      XTL_FORCE_NOISO     : Boolean := True;
      --  No public
      PLL_FORCE_NOISO     : Boolean := True;
      --  No public
      ANALOG_FORCE_NOISO  : Boolean := True;
      --  digital wrap force reset in deep sleep
      DG_WRAP_FORCE_RST   : Boolean := False;
      --  digital core force no reset in deep sleep
      DG_WRAP_FORCE_NORST : Boolean := False;
      --  Write-only. SW system reset
      SW_SYS_RST          : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for OPTIONS0_Register use
     record
       SW_STALL_APPCPU_C0 at 0 range 0 .. 1;
       SW_STALL_PROCPU_C0 at 0 range 2 .. 3;
       SW_APPCPU_RST at 0 range 4 .. 4;
       SW_PROCPU_RST at 0 range 5 .. 5;
       BB_I2C_FORCE_PD at 0 range 6 .. 6;
       BB_I2C_FORCE_PU at 0 range 7 .. 7;
       BBPLL_I2C_FORCE_PD at 0 range 8 .. 8;
       BBPLL_I2C_FORCE_PU at 0 range 9 .. 9;
       BBPLL_FORCE_PD at 0 range 10 .. 10;
       BBPLL_FORCE_PU at 0 range 11 .. 11;
       XTL_FORCE_PD at 0 range 12 .. 12;
       XTL_FORCE_PU at 0 range 13 .. 13;
       XTL_EN_WAIT at 0 range 14 .. 17;
       Reserved_18_22 at 0 range 18 .. 22;
       XTL_FORCE_ISO at 0 range 23 .. 23;
       PLL_FORCE_ISO at 0 range 24 .. 24;
       ANALOG_FORCE_ISO at 0 range 25 .. 25;
       XTL_FORCE_NOISO at 0 range 26 .. 26;
       PLL_FORCE_NOISO at 0 range 27 .. 27;
       ANALOG_FORCE_NOISO at 0 range 28 .. 28;
       DG_WRAP_FORCE_RST at 0 range 29 .. 29;
       DG_WRAP_FORCE_NORST at 0 range 30 .. 30;
       SW_SYS_RST at 0 range 31 .. 31;
     end record;

   subtype SLP_TIMER1_SLP_VAL_HI_Field is ESP32S3_Registers.UInt16;

   --  configure sleep time hi
   type SLP_TIMER1_Register is record
      --  RTC sleep timer high 16 bits
      SLP_VAL_HI          : SLP_TIMER1_SLP_VAL_HI_Field := 16#0#;
      --  Write-only. timer alarm enable bit
      MAIN_TIMER_ALARM_EN : Boolean := False;
      --  unspecified
      Reserved_17_31      : ESP32S3_Registers.UInt15 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SLP_TIMER1_Register use
     record
       SLP_VAL_HI at 0 range 0 .. 15;
       MAIN_TIMER_ALARM_EN at 0 range 16 .. 16;
       Reserved_17_31 at 0 range 17 .. 31;
     end record;

   --  update rtc main timer
   type TIME_UPDATE_Register is record
      --  unspecified
      Reserved_0_26   : ESP32S3_Registers.UInt27 := 16#0#;
      --  Enable to record system stall time
      TIMER_SYS_STALL : Boolean := False;
      --  Enable to record 40M XTAL OFF time
      TIMER_XTL_OFF   : Boolean := False;
      --  enable to record system reset time
      TIMER_SYS_RST   : Boolean := False;
      --  unspecified
      Reserved_30_30  : ESP32S3_Registers.Bit := 16#0#;
      --  Write-only. Set 1: to update register with RTC timer
      TIME_UPDATE     : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIME_UPDATE_Register use
     record
       Reserved_0_26 at 0 range 0 .. 26;
       TIMER_SYS_STALL at 0 range 27 .. 27;
       TIMER_XTL_OFF at 0 range 28 .. 28;
       TIMER_SYS_RST at 0 range 29 .. 29;
       Reserved_30_30 at 0 range 30 .. 30;
       TIME_UPDATE at 0 range 31 .. 31;
     end record;

   subtype TIME_HIGH0_TIMER_VALUE0_HIGH_Field is ESP32S3_Registers.UInt16;

   --  read rtc_main timer high bits
   type TIME_HIGH0_Register is record
      --  Read-only. RTC timer high 16 bits
      TIMER_VALUE0_HIGH : TIME_HIGH0_TIMER_VALUE0_HIGH_Field;
      --  unspecified
      Reserved_16_31    : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIME_HIGH0_Register use
     record
       TIMER_VALUE0_HIGH at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   --  configure chip sleep
   type STATE0_Register is record
      --  Write-only. rtc software interrupt to main cpu
      SW_CPU_INT           : Boolean := False;
      --  Write-only. clear rtc sleep reject cause
      SLP_REJECT_CAUSE_CLR : Boolean := False;
      --  unspecified
      Reserved_2_21        : ESP32S3_Registers.UInt20 := 16#0#;
      --  1: APB to RTC using bridge, 0: APB to RTC using sync
      APB2RTC_BRIDGE_SEL   : Boolean := False;
      --  unspecified
      Reserved_23_27       : ESP32S3_Registers.UInt5 := 16#0#;
      --  Read-only. SDIO active indication
      SDIO_ACTIVE_IND      : Boolean := False;
      --  leep wakeup bit
      SLP_WAKEUP           : Boolean := False;
      --  leep reject bit
      SLP_REJECT           : Boolean := False;
      --  sleep enable bit
      SLEEP_EN             : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for STATE0_Register use
     record
       SW_CPU_INT at 0 range 0 .. 0;
       SLP_REJECT_CAUSE_CLR at 0 range 1 .. 1;
       Reserved_2_21 at 0 range 2 .. 21;
       APB2RTC_BRIDGE_SEL at 0 range 22 .. 22;
       Reserved_23_27 at 0 range 23 .. 27;
       SDIO_ACTIVE_IND at 0 range 28 .. 28;
       SLP_WAKEUP at 0 range 29 .. 29;
       SLP_REJECT at 0 range 30 .. 30;
       SLEEP_EN at 0 range 31 .. 31;
     end record;

   subtype TIMER1_CPU_STALL_WAIT_Field is ESP32S3_Registers.UInt5;
   subtype TIMER1_CK8M_WAIT_Field is ESP32S3_Registers.Byte;
   subtype TIMER1_XTL_BUF_WAIT_Field is ESP32S3_Registers.UInt10;
   subtype TIMER1_PLL_BUF_WAIT_Field is ESP32S3_Registers.Byte;

   --  rtc state wait time
   type TIMER1_Register is record
      --  CPU stall enable bit
      CPU_STALL_EN   : Boolean := True;
      --  CPU stall wait cycles in fast_clk_rtc
      CPU_STALL_WAIT : TIMER1_CPU_STALL_WAIT_Field := 16#1#;
      --  CK8M wait cycles in slow_clk_rtc
      CK8M_WAIT      : TIMER1_CK8M_WAIT_Field := 16#10#;
      --  XTAL wait cycles in slow_clk_rtc
      XTL_BUF_WAIT   : TIMER1_XTL_BUF_WAIT_Field := 16#50#;
      --  PLL wait cycles in slow_clk_rtc
      PLL_BUF_WAIT   : TIMER1_PLL_BUF_WAIT_Field := 16#28#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIMER1_Register use
     record
       CPU_STALL_EN at 0 range 0 .. 0;
       CPU_STALL_WAIT at 0 range 1 .. 5;
       CK8M_WAIT at 0 range 6 .. 13;
       XTL_BUF_WAIT at 0 range 14 .. 23;
       PLL_BUF_WAIT at 0 range 24 .. 31;
     end record;

   subtype TIMER2_ULPCP_TOUCH_START_WAIT_Field is ESP32S3_Registers.UInt9;
   subtype TIMER2_MIN_TIME_CK8M_OFF_Field is ESP32S3_Registers.Byte;

   --  rtc monitor state delay time
   type TIMER2_Register is record
      --  unspecified
      Reserved_0_14          : ESP32S3_Registers.UInt15 := 16#0#;
      --  wait cycles in slow_clk_rtc before ULP-coprocessor / touch controller
      --  start to work
      ULPCP_TOUCH_START_WAIT : TIMER2_ULPCP_TOUCH_START_WAIT_Field := 16#10#;
      --  minimal cycles in slow_clk_rtc for CK8M in power down state
      MIN_TIME_CK8M_OFF      : TIMER2_MIN_TIME_CK8M_OFF_Field := 16#1#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIMER2_Register use
     record
       Reserved_0_14 at 0 range 0 .. 14;
       ULPCP_TOUCH_START_WAIT at 0 range 15 .. 23;
       MIN_TIME_CK8M_OFF at 0 range 24 .. 31;
     end record;

   subtype TIMER3_WIFI_WAIT_TIMER_Field is ESP32S3_Registers.UInt9;
   subtype TIMER3_WIFI_POWERUP_TIMER_Field is ESP32S3_Registers.UInt7;
   subtype TIMER3_BT_WAIT_TIMER_Field is ESP32S3_Registers.UInt9;
   subtype TIMER3_BT_POWERUP_TIMER_Field is ESP32S3_Registers.UInt7;

   --  No public
   type TIMER3_Register is record
      --  No public
      WIFI_WAIT_TIMER    : TIMER3_WIFI_WAIT_TIMER_Field := 16#8#;
      --  No public
      WIFI_POWERUP_TIMER : TIMER3_WIFI_POWERUP_TIMER_Field := 16#5#;
      --  No public
      BT_WAIT_TIMER      : TIMER3_BT_WAIT_TIMER_Field := 16#16#;
      --  No public
      BT_POWERUP_TIMER   : TIMER3_BT_POWERUP_TIMER_Field := 16#A#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIMER3_Register use
     record
       WIFI_WAIT_TIMER at 0 range 0 .. 8;
       WIFI_POWERUP_TIMER at 0 range 9 .. 15;
       BT_WAIT_TIMER at 0 range 16 .. 24;
       BT_POWERUP_TIMER at 0 range 25 .. 31;
     end record;

   subtype TIMER4_WAIT_TIMER_Field is ESP32S3_Registers.UInt9;
   subtype TIMER4_POWERUP_TIMER_Field is ESP32S3_Registers.UInt7;
   subtype TIMER4_DG_WRAP_WAIT_TIMER_Field is ESP32S3_Registers.UInt9;
   subtype TIMER4_DG_WRAP_POWERUP_TIMER_Field is ESP32S3_Registers.UInt7;

   --  No public
   type TIMER4_Register is record
      --  No public
      WAIT_TIMER            : TIMER4_WAIT_TIMER_Field := 16#8#;
      --  No public
      POWERUP_TIMER         : TIMER4_POWERUP_TIMER_Field := 16#5#;
      --  No public
      DG_WRAP_WAIT_TIMER    : TIMER4_DG_WRAP_WAIT_TIMER_Field := 16#20#;
      --  No public
      DG_WRAP_POWERUP_TIMER : TIMER4_DG_WRAP_POWERUP_TIMER_Field := 16#8#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIMER4_Register use
     record
       WAIT_TIMER at 0 range 0 .. 8;
       POWERUP_TIMER at 0 range 9 .. 15;
       DG_WRAP_WAIT_TIMER at 0 range 16 .. 24;
       DG_WRAP_POWERUP_TIMER at 0 range 25 .. 31;
     end record;

   subtype TIMER5_MIN_SLP_VAL_Field is ESP32S3_Registers.Byte;

   --  configure min sleep time
   type TIMER5_Register is record
      --  unspecified
      Reserved_0_7   : ESP32S3_Registers.Byte := 16#0#;
      --  minimal sleep cycles in slow_clk_rtc
      MIN_SLP_VAL    : TIMER5_MIN_SLP_VAL_Field := 16#80#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIMER5_Register use
     record
       Reserved_0_7 at 0 range 0 .. 7;
       MIN_SLP_VAL at 0 range 8 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype TIMER6_CPU_TOP_WAIT_TIMER_Field is ESP32S3_Registers.UInt9;
   subtype TIMER6_CPU_TOP_POWERUP_TIMER_Field is ESP32S3_Registers.UInt7;
   subtype TIMER6_DG_PERI_WAIT_TIMER_Field is ESP32S3_Registers.UInt9;
   subtype TIMER6_DG_PERI_POWERUP_TIMER_Field is ESP32S3_Registers.UInt7;

   --  No public
   type TIMER6_Register is record
      --  No public
      CPU_TOP_WAIT_TIMER    : TIMER6_CPU_TOP_WAIT_TIMER_Field := 16#8#;
      --  No public
      CPU_TOP_POWERUP_TIMER : TIMER6_CPU_TOP_POWERUP_TIMER_Field := 16#5#;
      --  No public
      DG_PERI_WAIT_TIMER    : TIMER6_DG_PERI_WAIT_TIMER_Field := 16#20#;
      --  No public
      DG_PERI_POWERUP_TIMER : TIMER6_DG_PERI_POWERUP_TIMER_Field := 16#8#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIMER6_Register use
     record
       CPU_TOP_WAIT_TIMER at 0 range 0 .. 8;
       CPU_TOP_POWERUP_TIMER at 0 range 9 .. 15;
       DG_PERI_WAIT_TIMER at 0 range 16 .. 24;
       DG_PERI_POWERUP_TIMER at 0 range 25 .. 31;
     end record;

   --  analog configure register
   type ANA_CONF_Register is record
      --  unspecified
      Reserved_0_17          : ESP32S3_Registers.UInt18 := 16#0#;
      --  force down I2C_RESET_POR
      I2C_RESET_POR_FORCE_PD : Boolean := True;
      --  force on I2C_RESET_POR
      I2C_RESET_POR_FORCE_PU : Boolean := False;
      --  enable clk glitch
      GLITCH_RST_EN          : Boolean := False;
      --  unspecified
      Reserved_21_21         : ESP32S3_Registers.Bit := 16#0#;
      --  PLLA force power up
      SAR_I2C_PU             : Boolean := True;
      --  PLLA force power down
      ANALOG_TOP_ISO_SLEEP   : Boolean := False;
      --  PLLA force power up
      ANALOG_TOP_ISO_MONITOR : Boolean := False;
      --  start BBPLL calibration during sleep
      BBPLL_CAL_SLP_START    : Boolean := False;
      --  1: PVTMON power up, otherwise power down
      PVTMON_PU              : Boolean := False;
      --  1: TXRF_I2C power up, otherwise power down
      TXRF_I2C_PU            : Boolean := False;
      --  1: RFRX_PBUS power up, otherwise power down
      RFRX_PBUS_PU           : Boolean := False;
      --  unspecified
      Reserved_29_29         : ESP32S3_Registers.Bit := 16#0#;
      --  1: CKGEN_I2C power up, otherwise power down
      CKGEN_I2C_PU           : Boolean := False;
      --  power on pll i2c
      PLL_I2C_PU             : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ANA_CONF_Register use
     record
       Reserved_0_17 at 0 range 0 .. 17;
       I2C_RESET_POR_FORCE_PD at 0 range 18 .. 18;
       I2C_RESET_POR_FORCE_PU at 0 range 19 .. 19;
       GLITCH_RST_EN at 0 range 20 .. 20;
       Reserved_21_21 at 0 range 21 .. 21;
       SAR_I2C_PU at 0 range 22 .. 22;
       ANALOG_TOP_ISO_SLEEP at 0 range 23 .. 23;
       ANALOG_TOP_ISO_MONITOR at 0 range 24 .. 24;
       BBPLL_CAL_SLP_START at 0 range 25 .. 25;
       PVTMON_PU at 0 range 26 .. 26;
       TXRF_I2C_PU at 0 range 27 .. 27;
       RFRX_PBUS_PU at 0 range 28 .. 28;
       Reserved_29_29 at 0 range 29 .. 29;
       CKGEN_I2C_PU at 0 range 30 .. 30;
       PLL_I2C_PU at 0 range 31 .. 31;
     end record;

   subtype RESET_STATE_RESET_CAUSE_PROCPU_Field is ESP32S3_Registers.UInt6;
   subtype RESET_STATE_RESET_CAUSE_APPCPU_Field is ESP32S3_Registers.UInt6;

   --  get reset state
   type RESET_STATE_Register is record
      --  Read-only. reset cause of PRO CPU
      RESET_CAUSE_PROCPU         : RESET_STATE_RESET_CAUSE_PROCPU_Field :=
        16#0#;
      --  Read-only. reset cause of APP CPU
      RESET_CAUSE_APPCPU         : RESET_STATE_RESET_CAUSE_APPCPU_Field :=
        16#0#;
      --  APP CPU state vector sel
      APPCPU_STAT_VECTOR_SEL     : Boolean := True;
      --  PRO CPU state vector sel
      PROCPU_STAT_VECTOR_SEL     : Boolean := True;
      --  Read-only. PRO CPU reset_flag
      RESET_FLAG_PROCPU          : Boolean := False;
      --  Read-only. APP CPU reset flag
      RESET_FLAG_APPCPU          : Boolean := False;
      --  Write-only. clear PRO CPU reset_flag
      RESET_FLAG_PROCPU_CLR      : Boolean := False;
      --  Write-only. clear APP CPU reset flag
      RESET_FLAG_APPCPU_CLR      : Boolean := False;
      --  APPCPU OcdHaltOnReset
      APPCPU_OCD_HALT_ON_RESET   : Boolean := False;
      --  PROCPU OcdHaltOnReset
      PROCPU_OCD_HALT_ON_RESET   : Boolean := False;
      --  Read-only. jtag reset flag
      RESET_FLAG_JTAG_PROCPU     : Boolean := False;
      --  Read-only. jtag reset flag
      RESET_FLAG_JTAG_APPCPU     : Boolean := False;
      --  Write-only. clear jtag reset flag
      RESET_FLAG_JTAG_PROCPU_CLR : Boolean := False;
      --  Write-only. clear jtag reset flag
      RESET_FLAG_JTAG_APPCPU_CLR : Boolean := False;
      --  bypass cpu1 dreset
      APP_DRESET_MASK            : Boolean := False;
      --  bypass cpu0 dreset
      PRO_DRESET_MASK            : Boolean := False;
      --  unspecified
      Reserved_26_31             : ESP32S3_Registers.UInt6 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RESET_STATE_Register use
     record
       RESET_CAUSE_PROCPU at 0 range 0 .. 5;
       RESET_CAUSE_APPCPU at 0 range 6 .. 11;
       APPCPU_STAT_VECTOR_SEL at 0 range 12 .. 12;
       PROCPU_STAT_VECTOR_SEL at 0 range 13 .. 13;
       RESET_FLAG_PROCPU at 0 range 14 .. 14;
       RESET_FLAG_APPCPU at 0 range 15 .. 15;
       RESET_FLAG_PROCPU_CLR at 0 range 16 .. 16;
       RESET_FLAG_APPCPU_CLR at 0 range 17 .. 17;
       APPCPU_OCD_HALT_ON_RESET at 0 range 18 .. 18;
       PROCPU_OCD_HALT_ON_RESET at 0 range 19 .. 19;
       RESET_FLAG_JTAG_PROCPU at 0 range 20 .. 20;
       RESET_FLAG_JTAG_APPCPU at 0 range 21 .. 21;
       RESET_FLAG_JTAG_PROCPU_CLR at 0 range 22 .. 22;
       RESET_FLAG_JTAG_APPCPU_CLR at 0 range 23 .. 23;
       APP_DRESET_MASK at 0 range 24 .. 24;
       PRO_DRESET_MASK at 0 range 25 .. 25;
       Reserved_26_31 at 0 range 26 .. 31;
     end record;

   subtype WAKEUP_STATE_WAKEUP_ENA_Field is ESP32S3_Registers.UInt17;

   --  configure wakeup state
   type WAKEUP_STATE_Register is record
      --  unspecified
      Reserved_0_14 : ESP32S3_Registers.UInt15 := 16#0#;
      --  wakeup enable bitmap
      WAKEUP_ENA    : WAKEUP_STATE_WAKEUP_ENA_Field := 16#C#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for WAKEUP_STATE_Register use
     record
       Reserved_0_14 at 0 range 0 .. 14;
       WAKEUP_ENA at 0 range 15 .. 31;
     end record;

   --  configure rtc interrupt register
   type INT_ENA_RTC_Register is record
      --  enable sleep wakeup interrupt
      SLP_WAKEUP_INT_ENA               : Boolean := False;
      --  enable sleep reject interrupt
      SLP_REJECT_INT_ENA               : Boolean := False;
      --  enable SDIO idle interrupt
      SDIO_IDLE_INT_ENA                : Boolean := False;
      --  enable RTC WDT interrupt
      WDT_INT_ENA                      : Boolean := False;
      --  enable touch scan done interrupt
      TOUCH_SCAN_DONE_INT_ENA          : Boolean := False;
      --  enable ULP-coprocessor interrupt
      ULP_CP_INT_ENA                   : Boolean := False;
      --  enable touch done interrupt
      TOUCH_DONE_INT_ENA               : Boolean := False;
      --  enable touch active interrupt
      TOUCH_ACTIVE_INT_ENA             : Boolean := False;
      --  enable touch inactive interrupt
      TOUCH_INACTIVE_INT_ENA           : Boolean := False;
      --  enable brown out interrupt
      BROWN_OUT_INT_ENA                : Boolean := False;
      --  enable RTC main timer interrupt
      MAIN_TIMER_INT_ENA               : Boolean := False;
      --  enable saradc1 interrupt
      SARADC1_INT_ENA                  : Boolean := False;
      --  enable tsens interrupt
      TSENS_INT_ENA                    : Boolean := False;
      --  enable riscV cocpu interrupt
      COCPU_INT_ENA                    : Boolean := False;
      --  enable saradc2 interrupt
      SARADC2_INT_ENA                  : Boolean := False;
      --  enable super watch dog interrupt
      SWD_INT_ENA                      : Boolean := False;
      --  enable xtal32k_dead interrupt
      XTAL32K_DEAD_INT_ENA             : Boolean := False;
      --  enable cocpu trap interrupt
      COCPU_TRAP_INT_ENA               : Boolean := False;
      --  enable touch timeout interrupt
      TOUCH_TIMEOUT_INT_ENA            : Boolean := False;
      --  enbale gitch det interrupt
      GLITCH_DET_INT_ENA               : Boolean := False;
      --  touch approach mode loop interrupt
      TOUCH_APPROACH_LOOP_DONE_INT_ENA : Boolean := False;
      --  unspecified
      Reserved_21_31                   : ESP32S3_Registers.UInt11 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ENA_RTC_Register use
     record
       SLP_WAKEUP_INT_ENA at 0 range 0 .. 0;
       SLP_REJECT_INT_ENA at 0 range 1 .. 1;
       SDIO_IDLE_INT_ENA at 0 range 2 .. 2;
       WDT_INT_ENA at 0 range 3 .. 3;
       TOUCH_SCAN_DONE_INT_ENA at 0 range 4 .. 4;
       ULP_CP_INT_ENA at 0 range 5 .. 5;
       TOUCH_DONE_INT_ENA at 0 range 6 .. 6;
       TOUCH_ACTIVE_INT_ENA at 0 range 7 .. 7;
       TOUCH_INACTIVE_INT_ENA at 0 range 8 .. 8;
       BROWN_OUT_INT_ENA at 0 range 9 .. 9;
       MAIN_TIMER_INT_ENA at 0 range 10 .. 10;
       SARADC1_INT_ENA at 0 range 11 .. 11;
       TSENS_INT_ENA at 0 range 12 .. 12;
       COCPU_INT_ENA at 0 range 13 .. 13;
       SARADC2_INT_ENA at 0 range 14 .. 14;
       SWD_INT_ENA at 0 range 15 .. 15;
       XTAL32K_DEAD_INT_ENA at 0 range 16 .. 16;
       COCPU_TRAP_INT_ENA at 0 range 17 .. 17;
       TOUCH_TIMEOUT_INT_ENA at 0 range 18 .. 18;
       GLITCH_DET_INT_ENA at 0 range 19 .. 19;
       TOUCH_APPROACH_LOOP_DONE_INT_ENA at 0 range 20 .. 20;
       Reserved_21_31 at 0 range 21 .. 31;
     end record;

   --  rtc interrupt register
   type INT_RAW_RTC_Register is record
      --  Read-only. sleep wakeup interrupt raw
      SLP_WAKEUP_INT_RAW               : Boolean := False;
      --  Read-only. sleep reject interrupt raw
      SLP_REJECT_INT_RAW               : Boolean := False;
      --  Read-only. SDIO idle interrupt raw
      SDIO_IDLE_INT_RAW                : Boolean := False;
      --  Read-only. RTC WDT interrupt raw
      WDT_INT_RAW                      : Boolean := False;
      --  Read-only. enable touch scan done interrupt raw
      TOUCH_SCAN_DONE_INT_RAW          : Boolean := False;
      --  Read-only. ULP-coprocessor interrupt raw
      ULP_CP_INT_RAW                   : Boolean := False;
      --  Read-only. touch interrupt raw
      TOUCH_DONE_INT_RAW               : Boolean := False;
      --  Read-only. touch active interrupt raw
      TOUCH_ACTIVE_INT_RAW             : Boolean := False;
      --  Read-only. touch inactive interrupt raw
      TOUCH_INACTIVE_INT_RAW           : Boolean := False;
      --  Read-only. brown out interrupt raw
      BROWN_OUT_INT_RAW                : Boolean := False;
      --  Read-only. RTC main timer interrupt raw
      MAIN_TIMER_INT_RAW               : Boolean := False;
      --  Read-only. saradc1 interrupt raw
      SARADC1_INT_RAW                  : Boolean := False;
      --  Read-only. tsens interrupt raw
      TSENS_INT_RAW                    : Boolean := False;
      --  Read-only. riscV cocpu interrupt raw
      COCPU_INT_RAW                    : Boolean := False;
      --  Read-only. saradc2 interrupt raw
      SARADC2_INT_RAW                  : Boolean := False;
      --  Read-only. super watch dog interrupt raw
      SWD_INT_RAW                      : Boolean := False;
      --  Read-only. xtal32k dead detection interrupt raw
      XTAL32K_DEAD_INT_RAW             : Boolean := False;
      --  Read-only. cocpu trap interrupt raw
      COCPU_TRAP_INT_RAW               : Boolean := False;
      --  Read-only. touch timeout interrupt raw
      TOUCH_TIMEOUT_INT_RAW            : Boolean := False;
      --  Read-only. glitch_det_interrupt_raw
      GLITCH_DET_INT_RAW               : Boolean := False;
      --  touch approach mode loop interrupt raw
      TOUCH_APPROACH_LOOP_DONE_INT_RAW : Boolean := False;
      --  unspecified
      Reserved_21_31                   : ESP32S3_Registers.UInt11 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_RAW_RTC_Register use
     record
       SLP_WAKEUP_INT_RAW at 0 range 0 .. 0;
       SLP_REJECT_INT_RAW at 0 range 1 .. 1;
       SDIO_IDLE_INT_RAW at 0 range 2 .. 2;
       WDT_INT_RAW at 0 range 3 .. 3;
       TOUCH_SCAN_DONE_INT_RAW at 0 range 4 .. 4;
       ULP_CP_INT_RAW at 0 range 5 .. 5;
       TOUCH_DONE_INT_RAW at 0 range 6 .. 6;
       TOUCH_ACTIVE_INT_RAW at 0 range 7 .. 7;
       TOUCH_INACTIVE_INT_RAW at 0 range 8 .. 8;
       BROWN_OUT_INT_RAW at 0 range 9 .. 9;
       MAIN_TIMER_INT_RAW at 0 range 10 .. 10;
       SARADC1_INT_RAW at 0 range 11 .. 11;
       TSENS_INT_RAW at 0 range 12 .. 12;
       COCPU_INT_RAW at 0 range 13 .. 13;
       SARADC2_INT_RAW at 0 range 14 .. 14;
       SWD_INT_RAW at 0 range 15 .. 15;
       XTAL32K_DEAD_INT_RAW at 0 range 16 .. 16;
       COCPU_TRAP_INT_RAW at 0 range 17 .. 17;
       TOUCH_TIMEOUT_INT_RAW at 0 range 18 .. 18;
       GLITCH_DET_INT_RAW at 0 range 19 .. 19;
       TOUCH_APPROACH_LOOP_DONE_INT_RAW at 0 range 20 .. 20;
       Reserved_21_31 at 0 range 21 .. 31;
     end record;

   --  rtc interrupt register
   type INT_ST_RTC_Register is record
      --  Read-only. sleep wakeup interrupt state
      SLP_WAKEUP_INT_ST               : Boolean;
      --  Read-only. sleep reject interrupt state
      SLP_REJECT_INT_ST               : Boolean;
      --  Read-only. SDIO idle interrupt state
      SDIO_IDLE_INT_ST                : Boolean;
      --  Read-only. RTC WDT interrupt state
      WDT_INT_ST                      : Boolean;
      --  Read-only. enable touch scan done interrupt raw
      TOUCH_SCAN_DONE_INT_ST          : Boolean;
      --  Read-only. ULP-coprocessor interrupt state
      ULP_CP_INT_ST                   : Boolean;
      --  Read-only. touch done interrupt state
      TOUCH_DONE_INT_ST               : Boolean;
      --  Read-only. touch active interrupt state
      TOUCH_ACTIVE_INT_ST             : Boolean;
      --  Read-only. touch inactive interrupt state
      TOUCH_INACTIVE_INT_ST           : Boolean;
      --  Read-only. brown out interrupt state
      BROWN_OUT_INT_ST                : Boolean;
      --  Read-only. RTC main timer interrupt state
      MAIN_TIMER_INT_ST               : Boolean;
      --  Read-only. saradc1 interrupt state
      SARADC1_INT_ST                  : Boolean;
      --  Read-only. tsens interrupt state
      TSENS_INT_ST                    : Boolean;
      --  Read-only. riscV cocpu interrupt state
      COCPU_INT_ST                    : Boolean;
      --  Read-only. saradc2 interrupt state
      SARADC2_INT_ST                  : Boolean;
      --  Read-only. super watch dog interrupt state
      SWD_INT_ST                      : Boolean;
      --  Read-only. xtal32k dead detection interrupt state
      XTAL32K_DEAD_INT_ST             : Boolean;
      --  Read-only. cocpu trap interrupt state
      COCPU_TRAP_INT_ST               : Boolean;
      --  Read-only. Touch timeout interrupt state
      TOUCH_TIMEOUT_INT_ST            : Boolean;
      --  Read-only. glitch_det_interrupt state
      GLITCH_DET_INT_ST               : Boolean;
      --  Read-only. touch approach mode loop interrupt state
      TOUCH_APPROACH_LOOP_DONE_INT_ST : Boolean;
      --  unspecified
      Reserved_21_31                  : ESP32S3_Registers.UInt11;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ST_RTC_Register use
     record
       SLP_WAKEUP_INT_ST at 0 range 0 .. 0;
       SLP_REJECT_INT_ST at 0 range 1 .. 1;
       SDIO_IDLE_INT_ST at 0 range 2 .. 2;
       WDT_INT_ST at 0 range 3 .. 3;
       TOUCH_SCAN_DONE_INT_ST at 0 range 4 .. 4;
       ULP_CP_INT_ST at 0 range 5 .. 5;
       TOUCH_DONE_INT_ST at 0 range 6 .. 6;
       TOUCH_ACTIVE_INT_ST at 0 range 7 .. 7;
       TOUCH_INACTIVE_INT_ST at 0 range 8 .. 8;
       BROWN_OUT_INT_ST at 0 range 9 .. 9;
       MAIN_TIMER_INT_ST at 0 range 10 .. 10;
       SARADC1_INT_ST at 0 range 11 .. 11;
       TSENS_INT_ST at 0 range 12 .. 12;
       COCPU_INT_ST at 0 range 13 .. 13;
       SARADC2_INT_ST at 0 range 14 .. 14;
       SWD_INT_ST at 0 range 15 .. 15;
       XTAL32K_DEAD_INT_ST at 0 range 16 .. 16;
       COCPU_TRAP_INT_ST at 0 range 17 .. 17;
       TOUCH_TIMEOUT_INT_ST at 0 range 18 .. 18;
       GLITCH_DET_INT_ST at 0 range 19 .. 19;
       TOUCH_APPROACH_LOOP_DONE_INT_ST at 0 range 20 .. 20;
       Reserved_21_31 at 0 range 21 .. 31;
     end record;

   --  rtc interrupt register
   type INT_CLR_RTC_Register is record
      --  Write-only. Clear sleep wakeup interrupt state
      SLP_WAKEUP_INT_CLR               : Boolean := False;
      --  Write-only. Clear sleep reject interrupt state
      SLP_REJECT_INT_CLR               : Boolean := False;
      --  Write-only. Clear SDIO idle interrupt state
      SDIO_IDLE_INT_CLR                : Boolean := False;
      --  Write-only. Clear RTC WDT interrupt state
      WDT_INT_CLR                      : Boolean := False;
      --  Write-only. clear touch scan done interrupt raw
      TOUCH_SCAN_DONE_INT_CLR          : Boolean := False;
      --  Write-only. Clear ULP-coprocessor interrupt state
      ULP_CP_INT_CLR                   : Boolean := False;
      --  Write-only. Clear touch done interrupt state
      TOUCH_DONE_INT_CLR               : Boolean := False;
      --  Write-only. Clear touch active interrupt state
      TOUCH_ACTIVE_INT_CLR             : Boolean := False;
      --  Write-only. Clear touch inactive interrupt state
      TOUCH_INACTIVE_INT_CLR           : Boolean := False;
      --  Write-only. Clear brown out interrupt state
      BROWN_OUT_INT_CLR                : Boolean := False;
      --  Write-only. Clear RTC main timer interrupt state
      MAIN_TIMER_INT_CLR               : Boolean := False;
      --  Write-only. Clear saradc1 interrupt state
      SARADC1_INT_CLR                  : Boolean := False;
      --  Write-only. Clear tsens interrupt state
      TSENS_INT_CLR                    : Boolean := False;
      --  Write-only. Clear riscV cocpu interrupt state
      COCPU_INT_CLR                    : Boolean := False;
      --  Write-only. Clear saradc2 interrupt state
      SARADC2_INT_CLR                  : Boolean := False;
      --  Write-only. Clear super watch dog interrupt state
      SWD_INT_CLR                      : Boolean := False;
      --  Write-only. Clear RTC WDT interrupt state
      XTAL32K_DEAD_INT_CLR             : Boolean := False;
      --  Write-only. Clear cocpu trap interrupt state
      COCPU_TRAP_INT_CLR               : Boolean := False;
      --  Write-only. Clear touch timeout interrupt state
      TOUCH_TIMEOUT_INT_CLR            : Boolean := False;
      --  Write-only. Clear glitch det interrupt state
      GLITCH_DET_INT_CLR               : Boolean := False;
      --  Write-only. cleartouch approach mode loop interrupt state
      TOUCH_APPROACH_LOOP_DONE_INT_CLR : Boolean := False;
      --  unspecified
      Reserved_21_31                   : ESP32S3_Registers.UInt11 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_CLR_RTC_Register use
     record
       SLP_WAKEUP_INT_CLR at 0 range 0 .. 0;
       SLP_REJECT_INT_CLR at 0 range 1 .. 1;
       SDIO_IDLE_INT_CLR at 0 range 2 .. 2;
       WDT_INT_CLR at 0 range 3 .. 3;
       TOUCH_SCAN_DONE_INT_CLR at 0 range 4 .. 4;
       ULP_CP_INT_CLR at 0 range 5 .. 5;
       TOUCH_DONE_INT_CLR at 0 range 6 .. 6;
       TOUCH_ACTIVE_INT_CLR at 0 range 7 .. 7;
       TOUCH_INACTIVE_INT_CLR at 0 range 8 .. 8;
       BROWN_OUT_INT_CLR at 0 range 9 .. 9;
       MAIN_TIMER_INT_CLR at 0 range 10 .. 10;
       SARADC1_INT_CLR at 0 range 11 .. 11;
       TSENS_INT_CLR at 0 range 12 .. 12;
       COCPU_INT_CLR at 0 range 13 .. 13;
       SARADC2_INT_CLR at 0 range 14 .. 14;
       SWD_INT_CLR at 0 range 15 .. 15;
       XTAL32K_DEAD_INT_CLR at 0 range 16 .. 16;
       COCPU_TRAP_INT_CLR at 0 range 17 .. 17;
       TOUCH_TIMEOUT_INT_CLR at 0 range 18 .. 18;
       GLITCH_DET_INT_CLR at 0 range 19 .. 19;
       TOUCH_APPROACH_LOOP_DONE_INT_CLR at 0 range 20 .. 20;
       Reserved_21_31 at 0 range 21 .. 31;
     end record;

   subtype EXT_XTL_CONF_DGM_XTAL_32K_Field is ESP32S3_Registers.UInt3;
   subtype EXT_XTL_CONF_DRES_XTAL_32K_Field is ESP32S3_Registers.UInt3;
   subtype EXT_XTL_CONF_DAC_XTAL_32K_Field is ESP32S3_Registers.UInt3;
   subtype EXT_XTL_CONF_WDT_STATE_Field is ESP32S3_Registers.UInt3;

   --  Reserved register
   type EXT_XTL_CONF_Register is record
      --  xtal 32k watch dog enable
      XTAL32K_WDT_EN       : Boolean := False;
      --  xtal 32k watch dog clock force on
      XTAL32K_WDT_CLK_FO   : Boolean := False;
      --  xtal 32k watch dog sw reset
      XTAL32K_WDT_RESET    : Boolean := False;
      --  xtal 32k external xtal clock force on
      XTAL32K_EXT_CLK_FO   : Boolean := False;
      --  xtal 32k switch to back up clock when xtal is dead
      XTAL32K_AUTO_BACKUP  : Boolean := False;
      --  xtal 32k restart xtal when xtal is dead
      XTAL32K_AUTO_RESTART : Boolean := False;
      --  xtal 32k switch back xtal when xtal is restarted
      XTAL32K_AUTO_RETURN  : Boolean := False;
      --  Xtal 32k xpd control by sw or fsm
      XTAL32K_XPD_FORCE    : Boolean := True;
      --  apply an internal clock to help xtal 32k to start
      ENCKINIT_XTAL_32K    : Boolean := False;
      --  0: single-end buffer 1: differential buffer
      DBUF_XTAL_32K        : Boolean := False;
      --  xtal_32k gm control
      DGM_XTAL_32K         : EXT_XTL_CONF_DGM_XTAL_32K_Field := 16#3#;
      --  DRES_XTAL_32K
      DRES_XTAL_32K        : EXT_XTL_CONF_DRES_XTAL_32K_Field := 16#3#;
      --  XPD_XTAL_32K
      XPD_XTAL_32K         : Boolean := False;
      --  DAC_XTAL_32K
      DAC_XTAL_32K         : EXT_XTL_CONF_DAC_XTAL_32K_Field := 16#3#;
      --  Read-only. state of 32k_wdt
      WDT_STATE            : EXT_XTL_CONF_WDT_STATE_Field := 16#0#;
      --  XTAL_32K sel. 0: external XTAL_32K, 1: CLK from RTC pad X32P_C
      XTAL32K_GPIO_SEL     : Boolean := False;
      --  unspecified
      Reserved_24_29       : ESP32S3_Registers.UInt6 := 16#0#;
      --  0: power down XTAL at high level, 1: power down XTAL at low level
      XTL_EXT_CTR_LV       : Boolean := False;
      --  Reserved register
      XTL_EXT_CTR_EN       : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for EXT_XTL_CONF_Register use
     record
       XTAL32K_WDT_EN at 0 range 0 .. 0;
       XTAL32K_WDT_CLK_FO at 0 range 1 .. 1;
       XTAL32K_WDT_RESET at 0 range 2 .. 2;
       XTAL32K_EXT_CLK_FO at 0 range 3 .. 3;
       XTAL32K_AUTO_BACKUP at 0 range 4 .. 4;
       XTAL32K_AUTO_RESTART at 0 range 5 .. 5;
       XTAL32K_AUTO_RETURN at 0 range 6 .. 6;
       XTAL32K_XPD_FORCE at 0 range 7 .. 7;
       ENCKINIT_XTAL_32K at 0 range 8 .. 8;
       DBUF_XTAL_32K at 0 range 9 .. 9;
       DGM_XTAL_32K at 0 range 10 .. 12;
       DRES_XTAL_32K at 0 range 13 .. 15;
       XPD_XTAL_32K at 0 range 16 .. 16;
       DAC_XTAL_32K at 0 range 17 .. 19;
       WDT_STATE at 0 range 20 .. 22;
       XTAL32K_GPIO_SEL at 0 range 23 .. 23;
       Reserved_24_29 at 0 range 24 .. 29;
       XTL_EXT_CTR_LV at 0 range 30 .. 30;
       XTL_EXT_CTR_EN at 0 range 31 .. 31;
     end record;

   --  ext wakeup configure
   type EXT_WAKEUP_CONF_Register is record
      --  unspecified
      Reserved_0_28      : ESP32S3_Registers.UInt29 := 16#0#;
      --  enable filter for gpio wakeup event
      GPIO_WAKEUP_FILTER : Boolean := False;
      --  0: external wakeup at low level, 1: external wakeup at high level
      EXT_WAKEUP0_LV     : Boolean := False;
      --  0: external wakeup at low level, 1: external wakeup at high level
      EXT_WAKEUP1_LV     : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for EXT_WAKEUP_CONF_Register use
     record
       Reserved_0_28 at 0 range 0 .. 28;
       GPIO_WAKEUP_FILTER at 0 range 29 .. 29;
       EXT_WAKEUP0_LV at 0 range 30 .. 30;
       EXT_WAKEUP1_LV at 0 range 31 .. 31;
     end record;

   subtype SLP_REJECT_CONF_SLEEP_REJECT_ENA_Field is ESP32S3_Registers.UInt18;

   --  reject sleep register
   type SLP_REJECT_CONF_Register is record
      --  unspecified
      Reserved_0_11       : ESP32S3_Registers.UInt12 := 16#0#;
      --  sleep reject enable
      SLEEP_REJECT_ENA    : SLP_REJECT_CONF_SLEEP_REJECT_ENA_Field := 16#0#;
      --  enable reject for light sleep
      LIGHT_SLP_REJECT_EN : Boolean := False;
      --  enable reject for deep sleep
      DEEP_SLP_REJECT_EN  : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SLP_REJECT_CONF_Register use
     record
       Reserved_0_11 at 0 range 0 .. 11;
       SLEEP_REJECT_ENA at 0 range 12 .. 29;
       LIGHT_SLP_REJECT_EN at 0 range 30 .. 30;
       DEEP_SLP_REJECT_EN at 0 range 31 .. 31;
     end record;

   subtype CPU_PERIOD_CONF_CPUPERIOD_SEL_Field is ESP32S3_Registers.UInt2;

   --  conigure cpu freq
   type CPU_PERIOD_CONF_Register is record
      --  unspecified
      Reserved_0_28 : ESP32S3_Registers.UInt29 := 16#0#;
      --  CPU sel option
      CPUSEL_CONF   : Boolean := False;
      --  conigure cpu freq
      CPUPERIOD_SEL : CPU_PERIOD_CONF_CPUPERIOD_SEL_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CPU_PERIOD_CONF_Register use
     record
       Reserved_0_28 at 0 range 0 .. 28;
       CPUSEL_CONF at 0 range 29 .. 29;
       CPUPERIOD_SEL at 0 range 30 .. 31;
     end record;

   subtype SDIO_ACT_CONF_SDIO_ACT_DNUM_Field is ESP32S3_Registers.UInt10;

   --  No public
   type SDIO_ACT_CONF_Register is record
      --  unspecified
      Reserved_0_21 : ESP32S3_Registers.UInt22 := 16#0#;
      --  No public
      SDIO_ACT_DNUM : SDIO_ACT_CONF_SDIO_ACT_DNUM_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SDIO_ACT_CONF_Register use
     record
       Reserved_0_21 at 0 range 0 .. 21;
       SDIO_ACT_DNUM at 0 range 22 .. 31;
     end record;

   subtype CLK_CONF_CK8M_DIV_Field is ESP32S3_Registers.UInt2;
   subtype CLK_CONF_CK8M_DIV_SEL_Field is ESP32S3_Registers.UInt3;
   subtype CLK_CONF_CK8M_DFREQ_Field is ESP32S3_Registers.Byte;
   subtype CLK_CONF_ANA_CLK_RTC_SEL_Field is ESP32S3_Registers.UInt2;

   --  configure clock register
   type CLK_CONF_Register is record
      --  unspecified
      Reserved_0_0               : ESP32S3_Registers.Bit := 16#0#;
      --  force efuse clk gating
      EFUSE_CLK_FORCE_GATING     : Boolean := False;
      --  force efuse clk nogating
      EFUSE_CLK_FORCE_NOGATING   : Boolean := True;
      --  used to sync reg_ck8m_div_sel bus. Clear vld before set
      --  reg_ck8m_div_sel, then set vld to actually switch the clk
      CK8M_DIV_SEL_VLD           : Boolean := True;
      --  CK8M_D256_OUT divider. 00: div128, 01: div256, 10: div512, 11:
      --  div1024.
      CK8M_DIV                   : CLK_CONF_CK8M_DIV_Field := 16#1#;
      --  disable CK8M and CK8M_D256_OUT
      ENB_CK8M                   : Boolean := False;
      --  1: CK8M_D256_OUT is actually CK8M, 0: CK8M_D256_OUT is CK8M divided
      --  by 256
      ENB_CK8M_DIV               : Boolean := False;
      --  enable CK_XTAL_32K for digital core (no relationship with RTC core)
      DIG_XTAL32K_EN             : Boolean := False;
      --  enable CK8M_D256_OUT for digital core (no relationship with RTC core)
      DIG_CLK8M_D256_EN          : Boolean := True;
      --  enable CK8M for digital core (no relationship with RTC core)
      DIG_CLK8M_EN               : Boolean := False;
      --  unspecified
      Reserved_11_11             : ESP32S3_Registers.Bit := 16#0#;
      --  divider = reg_ck8m_div_sel + 1
      CK8M_DIV_SEL               : CLK_CONF_CK8M_DIV_SEL_Field := 16#3#;
      --  XTAL force no gating during sleep
      XTAL_FORCE_NOGATING        : Boolean := False;
      --  CK8M force no gating during sleep
      CK8M_FORCE_NOGATING        : Boolean := False;
      --  CK8M_DFREQ
      CK8M_DFREQ                 : CLK_CONF_CK8M_DFREQ_Field := 16#AC#;
      --  CK8M force power down
      CK8M_FORCE_PD              : Boolean := False;
      --  CK8M force power up
      CK8M_FORCE_PU              : Boolean := False;
      --  force global xtal gating
      XTAL_GLOBAL_FORCE_GATING   : Boolean := False;
      --  force global xtal no gating
      XTAL_GLOBAL_FORCE_NOGATING : Boolean := True;
      --  fast_clk_rtc sel. 0: XTAL div 4, 1: CK8M
      FAST_CLK_RTC_SEL           : Boolean := False;
      --  select slow clock
      ANA_CLK_RTC_SEL            : CLK_CONF_ANA_CLK_RTC_SEL_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CLK_CONF_Register use
     record
       Reserved_0_0 at 0 range 0 .. 0;
       EFUSE_CLK_FORCE_GATING at 0 range 1 .. 1;
       EFUSE_CLK_FORCE_NOGATING at 0 range 2 .. 2;
       CK8M_DIV_SEL_VLD at 0 range 3 .. 3;
       CK8M_DIV at 0 range 4 .. 5;
       ENB_CK8M at 0 range 6 .. 6;
       ENB_CK8M_DIV at 0 range 7 .. 7;
       DIG_XTAL32K_EN at 0 range 8 .. 8;
       DIG_CLK8M_D256_EN at 0 range 9 .. 9;
       DIG_CLK8M_EN at 0 range 10 .. 10;
       Reserved_11_11 at 0 range 11 .. 11;
       CK8M_DIV_SEL at 0 range 12 .. 14;
       XTAL_FORCE_NOGATING at 0 range 15 .. 15;
       CK8M_FORCE_NOGATING at 0 range 16 .. 16;
       CK8M_DFREQ at 0 range 17 .. 24;
       CK8M_FORCE_PD at 0 range 25 .. 25;
       CK8M_FORCE_PU at 0 range 26 .. 26;
       XTAL_GLOBAL_FORCE_GATING at 0 range 27 .. 27;
       XTAL_GLOBAL_FORCE_NOGATING at 0 range 28 .. 28;
       FAST_CLK_RTC_SEL at 0 range 29 .. 29;
       ANA_CLK_RTC_SEL at 0 range 30 .. 31;
     end record;

   subtype SLOW_CLK_CONF_ANA_CLK_DIV_Field is ESP32S3_Registers.Byte;

   --  configure slow clk
   type SLOW_CLK_CONF_Register is record
      --  unspecified
      Reserved_0_21      : ESP32S3_Registers.UInt22 := 16#0#;
      --  used to sync div bus. clear vld before set reg_rtc_ana_clk_div, then
      --  set vld to actually switch the clk
      ANA_CLK_DIV_VLD    : Boolean := True;
      --  rtc clk div
      ANA_CLK_DIV        : SLOW_CLK_CONF_ANA_CLK_DIV_Field := 16#0#;
      --  No public
      SLOW_CLK_NEXT_EDGE : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SLOW_CLK_CONF_Register use
     record
       Reserved_0_21 at 0 range 0 .. 21;
       ANA_CLK_DIV_VLD at 0 range 22 .. 22;
       ANA_CLK_DIV at 0 range 23 .. 30;
       SLOW_CLK_NEXT_EDGE at 0 range 31 .. 31;
     end record;

   subtype SDIO_CONF_SDIO_TIMER_TARGET_Field is ESP32S3_Registers.Byte;
   subtype SDIO_CONF_SDIO_DTHDRV_Field is ESP32S3_Registers.UInt2;
   subtype SDIO_CONF_SDIO_DCAP_Field is ESP32S3_Registers.UInt2;
   subtype SDIO_CONF_SDIO_INITI_Field is ESP32S3_Registers.UInt2;
   subtype SDIO_CONF_SDIO_DCURLIM_Field is ESP32S3_Registers.UInt3;
   subtype SDIO_CONF_DREFL_SDIO_Field is ESP32S3_Registers.UInt2;
   subtype SDIO_CONF_DREFM_SDIO_Field is ESP32S3_Registers.UInt2;
   subtype SDIO_CONF_DREFH_SDIO_Field is ESP32S3_Registers.UInt2;

   --  configure flash power
   type SDIO_CONF_Register is record
      --  timer count to apply reg_sdio_dcap after sdio power on
      SDIO_TIMER_TARGET : SDIO_CONF_SDIO_TIMER_TARGET_Field := 16#A#;
      --  unspecified
      Reserved_8_8      : ESP32S3_Registers.Bit := 16#0#;
      --  Tieh = 1 mode drive ability. Initially set to 0 to limit charge
      --  current, set to 3 after several us.
      SDIO_DTHDRV       : SDIO_CONF_SDIO_DTHDRV_Field := 16#3#;
      --  ability to prevent LDO from overshoot
      SDIO_DCAP         : SDIO_CONF_SDIO_DCAP_Field := 16#3#;
      --  add resistor from ldo output to ground. 0: no res, 1: 6k,2:4k,3:2k
      SDIO_INITI        : SDIO_CONF_SDIO_INITI_Field := 16#1#;
      --  0 to set init[1:0]=0
      SDIO_EN_INITI     : Boolean := True;
      --  tune current limit threshold when tieh = 0. About 800mA/(8+d)
      SDIO_DCURLIM      : SDIO_CONF_SDIO_DCURLIM_Field := 16#0#;
      --  select current limit mode
      SDIO_MODECURLIM   : Boolean := False;
      --  enable current limit
      SDIO_ENCURLIM     : Boolean := True;
      --  power down SDIO_REG in sleep. Only active when reg_sdio_force = 0
      SDIO_REG_PD_EN    : Boolean := True;
      --  1: use SW option to control SDIO_REG, 0: use state machine
      SDIO_FORCE        : Boolean := False;
      --  SW option for SDIO_TIEH. Only active when reg_sdio_force = 1
      SDIO_TIEH         : Boolean := True;
      --  Read-only. read only register for REG1P8_READY
      REG1P8_READY      : Boolean := False;
      --  SW option for DREFL_SDIO. Only active when reg_sdio_force = 1
      DREFL_SDIO        : SDIO_CONF_DREFL_SDIO_Field := 16#1#;
      --  SW option for DREFM_SDIO. Only active when reg_sdio_force = 1
      DREFM_SDIO        : SDIO_CONF_DREFM_SDIO_Field := 16#1#;
      --  SW option for DREFH_SDIO. Only active when reg_sdio_force = 1
      DREFH_SDIO        : SDIO_CONF_DREFH_SDIO_Field := 16#0#;
      --  power on flash regulator
      XPD_SDIO          : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SDIO_CONF_Register use
     record
       SDIO_TIMER_TARGET at 0 range 0 .. 7;
       Reserved_8_8 at 0 range 8 .. 8;
       SDIO_DTHDRV at 0 range 9 .. 10;
       SDIO_DCAP at 0 range 11 .. 12;
       SDIO_INITI at 0 range 13 .. 14;
       SDIO_EN_INITI at 0 range 15 .. 15;
       SDIO_DCURLIM at 0 range 16 .. 18;
       SDIO_MODECURLIM at 0 range 19 .. 19;
       SDIO_ENCURLIM at 0 range 20 .. 20;
       SDIO_REG_PD_EN at 0 range 21 .. 21;
       SDIO_FORCE at 0 range 22 .. 22;
       SDIO_TIEH at 0 range 23 .. 23;
       REG1P8_READY at 0 range 24 .. 24;
       DREFL_SDIO at 0 range 25 .. 26;
       DREFM_SDIO at 0 range 27 .. 28;
       DREFH_SDIO at 0 range 29 .. 30;
       XPD_SDIO at 0 range 31 .. 31;
     end record;

   subtype BIAS_CONF_DBG_ATTEN_DEEP_SLP_Field is ESP32S3_Registers.UInt4;
   subtype BIAS_CONF_DBG_ATTEN_MONITOR_Field is ESP32S3_Registers.UInt4;
   subtype BIAS_CONF_DBG_ATTEN_WAKEUP_Field is ESP32S3_Registers.UInt4;

   --  No public
   type BIAS_CONF_Register is record
      --  unspecified
      Reserved_0_9        : ESP32S3_Registers.UInt10 := 16#0#;
      --  No public
      BIAS_BUF_IDLE       : Boolean := False;
      --  No public
      BIAS_BUF_WAKE       : Boolean := True;
      --  No public
      BIAS_BUF_DEEP_SLP   : Boolean := False;
      --  No public
      BIAS_BUF_MONITOR    : Boolean := False;
      --  xpd cur when rtc in sleep_state
      PD_CUR_DEEP_SLP     : Boolean := False;
      --  xpd cur when rtc in monitor state
      PD_CUR_MONITOR      : Boolean := False;
      --  bias_sleep when rtc in sleep_state
      BIAS_SLEEP_DEEP_SLP : Boolean := True;
      --  bias_sleep when rtc in monitor state
      BIAS_SLEEP_MONITOR  : Boolean := False;
      --  DBG_ATTEN when rtc in sleep state
      DBG_ATTEN_DEEP_SLP  : BIAS_CONF_DBG_ATTEN_DEEP_SLP_Field := 16#0#;
      --  DBG_ATTEN when rtc in monitor state
      DBG_ATTEN_MONITOR   : BIAS_CONF_DBG_ATTEN_MONITOR_Field := 16#0#;
      --  No public
      DBG_ATTEN_WAKEUP    : BIAS_CONF_DBG_ATTEN_WAKEUP_Field := 16#0#;
      --  unspecified
      Reserved_30_31      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for BIAS_CONF_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       BIAS_BUF_IDLE at 0 range 10 .. 10;
       BIAS_BUF_WAKE at 0 range 11 .. 11;
       BIAS_BUF_DEEP_SLP at 0 range 12 .. 12;
       BIAS_BUF_MONITOR at 0 range 13 .. 13;
       PD_CUR_DEEP_SLP at 0 range 14 .. 14;
       PD_CUR_MONITOR at 0 range 15 .. 15;
       BIAS_SLEEP_DEEP_SLP at 0 range 16 .. 16;
       BIAS_SLEEP_MONITOR at 0 range 17 .. 17;
       DBG_ATTEN_DEEP_SLP at 0 range 18 .. 21;
       DBG_ATTEN_MONITOR at 0 range 22 .. 25;
       DBG_ATTEN_WAKEUP at 0 range 26 .. 29;
       Reserved_30_31 at 0 range 30 .. 31;
     end record;

   subtype RTC_SCK_DCAP_Field is ESP32S3_Registers.Byte;

   --  configure rtc regulator
   type RTC_Register is record
      --  unspecified
      Reserved_0_6       : ESP32S3_Registers.UInt7 := 16#0#;
      --  enable dig regulator cali
      DIG_REG_CAL_EN     : Boolean := False;
      --  unspecified
      Reserved_8_13      : ESP32S3_Registers.UInt6 := 16#0#;
      --  SCK_DCAP
      SCK_DCAP           : RTC_SCK_DCAP_Field := 16#0#;
      --  unspecified
      Reserved_22_27     : ESP32S3_Registers.UInt6 := 16#0#;
      --  RTC_DBOOST force power down
      DBOOST_FORCE_PD    : Boolean := False;
      --  RTC_DBOOST force power up
      DBOOST_FORCE_PU    : Boolean := True;
      --  RTC_REG force power down (for RTC_REG power down means decrease the
      --  voltage to 0.8v or lower )
      REGULATOR_FORCE_PD : Boolean := False;
      --  RTC_REG force power on (for RTC_REG power down means decrease the
      --  voltage to 0.8v or lower )
      REGULATOR_FORCE_PU : Boolean := True;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_Register use
     record
       Reserved_0_6 at 0 range 0 .. 6;
       DIG_REG_CAL_EN at 0 range 7 .. 7;
       Reserved_8_13 at 0 range 8 .. 13;
       SCK_DCAP at 0 range 14 .. 21;
       Reserved_22_27 at 0 range 22 .. 27;
       DBOOST_FORCE_PD at 0 range 28 .. 28;
       DBOOST_FORCE_PU at 0 range 29 .. 29;
       REGULATOR_FORCE_PD at 0 range 30 .. 30;
       REGULATOR_FORCE_PU at 0 range 31 .. 31;
     end record;

   --  configure rtc power
   type PWC_Register is record
      --  Fast RTC memory force no ISO
      FASTMEM_FORCE_NOISO : Boolean := True;
      --  Fast RTC memory force ISO
      FASTMEM_FORCE_ISO   : Boolean := False;
      --  RTC memory force no ISO
      SLOWMEM_FORCE_NOISO : Boolean := True;
      --  RTC memory force ISO
      SLOWMEM_FORCE_ISO   : Boolean := False;
      --  rtc_peri force ISO
      FORCE_ISO           : Boolean := False;
      --  rtc_peri force no ISO
      FORCE_NOISO         : Boolean := True;
      --  1: Fast RTC memory PD following CPU, 0: fast RTC memory PD following
      --  RTC state machine
      FASTMEM_FOLW_CPU    : Boolean := False;
      --  Fast RTC memory force PD
      FASTMEM_FORCE_LPD   : Boolean := False;
      --  Fast RTC memory force no PD
      FASTMEM_FORCE_LPU   : Boolean := True;
      --  1: RTC memory PD following CPU, 0: RTC memory PD following RTC state
      --  machine
      SLOWMEM_FOLW_CPU    : Boolean := False;
      --  RTC memory force PD
      SLOWMEM_FORCE_LPD   : Boolean := False;
      --  RTC memory force no PD
      SLOWMEM_FORCE_LPU   : Boolean := True;
      --  unspecified
      Reserved_12_17      : ESP32S3_Registers.UInt6 := 16#0#;
      --  rtc_peri force power down
      FORCE_PD            : Boolean := False;
      --  rtc_peri force power up
      FORCE_PU            : Boolean := False;
      --  enable power down rtc_peri in sleep
      PD_EN               : Boolean := False;
      --  rtc pad force hold
      PAD_FORCE_HOLD      : Boolean := False;
      --  unspecified
      Reserved_22_31      : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PWC_Register use
     record
       FASTMEM_FORCE_NOISO at 0 range 0 .. 0;
       FASTMEM_FORCE_ISO at 0 range 1 .. 1;
       SLOWMEM_FORCE_NOISO at 0 range 2 .. 2;
       SLOWMEM_FORCE_ISO at 0 range 3 .. 3;
       FORCE_ISO at 0 range 4 .. 4;
       FORCE_NOISO at 0 range 5 .. 5;
       FASTMEM_FOLW_CPU at 0 range 6 .. 6;
       FASTMEM_FORCE_LPD at 0 range 7 .. 7;
       FASTMEM_FORCE_LPU at 0 range 8 .. 8;
       SLOWMEM_FOLW_CPU at 0 range 9 .. 9;
       SLOWMEM_FORCE_LPD at 0 range 10 .. 10;
       SLOWMEM_FORCE_LPU at 0 range 11 .. 11;
       Reserved_12_17 at 0 range 12 .. 17;
       FORCE_PD at 0 range 18 .. 18;
       FORCE_PU at 0 range 19 .. 19;
       PD_EN at 0 range 20 .. 20;
       PAD_FORCE_HOLD at 0 range 21 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype REGULATOR_DRV_CTRL_REGULATOR_DRV_B_MONITOR_Field is
     ESP32S3_Registers.UInt6;
   subtype REGULATOR_DRV_CTRL_REGULATOR_DRV_B_SLP_Field is
     ESP32S3_Registers.UInt6;
   subtype REGULATOR_DRV_CTRL_DG_VDD_DRV_B_SLP_Field is ESP32S3_Registers.Byte;
   subtype REGULATOR_DRV_CTRL_DG_VDD_DRV_B_MONITOR_Field is
     ESP32S3_Registers.Byte;

   --  No public
   type REGULATOR_DRV_CTRL_Register is record
      --  No public
      REGULATOR_DRV_B_MONITOR :
        REGULATOR_DRV_CTRL_REGULATOR_DRV_B_MONITOR_Field := 16#0#;
      --  No public
      REGULATOR_DRV_B_SLP     : REGULATOR_DRV_CTRL_REGULATOR_DRV_B_SLP_Field :=
        16#0#;
      --  No public
      DG_VDD_DRV_B_SLP        : REGULATOR_DRV_CTRL_DG_VDD_DRV_B_SLP_Field :=
        16#0#;
      --  No public
      DG_VDD_DRV_B_MONITOR    :
        REGULATOR_DRV_CTRL_DG_VDD_DRV_B_MONITOR_Field := 16#0#;
      --  unspecified
      Reserved_28_31          : ESP32S3_Registers.UInt4 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for REGULATOR_DRV_CTRL_Register use
     record
       REGULATOR_DRV_B_MONITOR at 0 range 0 .. 5;
       REGULATOR_DRV_B_SLP at 0 range 6 .. 11;
       DG_VDD_DRV_B_SLP at 0 range 12 .. 19;
       DG_VDD_DRV_B_MONITOR at 0 range 20 .. 27;
       Reserved_28_31 at 0 range 28 .. 31;
     end record;

   --  configure digital power
   type DIG_PWC_Register is record
      --  unspecified
      Reserved_0_2      : ESP32S3_Registers.UInt3 := 16#0#;
      --  memories in digital core force PD in sleep
      LSLP_MEM_FORCE_PD : Boolean := False;
      --  memories in digital core force no PD in sleep
      LSLP_MEM_FORCE_PU : Boolean := True;
      --  unspecified
      Reserved_5_10     : ESP32S3_Registers.UInt6 := 16#0#;
      --  internal SRAM 2 force power down
      BT_FORCE_PD       : Boolean := False;
      --  internal SRAM 2 force power up
      BT_FORCE_PU       : Boolean := True;
      --  internal SRAM 3 force power down
      DG_PERI_FORCE_PD  : Boolean := False;
      --  internal SRAM 3 force power up
      DG_PERI_FORCE_PU  : Boolean := True;
      --  unspecified
      Reserved_15_16    : ESP32S3_Registers.UInt2 := 16#0#;
      --  wifi force power down
      WIFI_FORCE_PD     : Boolean := False;
      --  wifi force power up
      WIFI_FORCE_PU     : Boolean := True;
      --  digital core force power down
      DG_WRAP_FORCE_PD  : Boolean := False;
      --  digital core force power up
      DG_WRAP_FORCE_PU  : Boolean := True;
      --  digital dcdc force power down
      CPU_TOP_FORCE_PD  : Boolean := False;
      --  digital dcdc force power up
      CPU_TOP_FORCE_PU  : Boolean := True;
      --  unspecified
      Reserved_23_26    : ESP32S3_Registers.UInt4 := 16#0#;
      --  enable power down internal SRAM 2 in sleep
      BT_PD_EN          : Boolean := False;
      --  enable power down internal SRAM 3 in sleep
      DG_PERI_PD_EN     : Boolean := False;
      --  enable power down internal SRAM 4 in sleep
      CPU_TOP_PD_EN     : Boolean := False;
      --  enable power down wifi in sleep
      WIFI_PD_EN        : Boolean := False;
      --  enable power down all digital logic
      DG_WRAP_PD_EN     : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DIG_PWC_Register use
     record
       Reserved_0_2 at 0 range 0 .. 2;
       LSLP_MEM_FORCE_PD at 0 range 3 .. 3;
       LSLP_MEM_FORCE_PU at 0 range 4 .. 4;
       Reserved_5_10 at 0 range 5 .. 10;
       BT_FORCE_PD at 0 range 11 .. 11;
       BT_FORCE_PU at 0 range 12 .. 12;
       DG_PERI_FORCE_PD at 0 range 13 .. 13;
       DG_PERI_FORCE_PU at 0 range 14 .. 14;
       Reserved_15_16 at 0 range 15 .. 16;
       WIFI_FORCE_PD at 0 range 17 .. 17;
       WIFI_FORCE_PU at 0 range 18 .. 18;
       DG_WRAP_FORCE_PD at 0 range 19 .. 19;
       DG_WRAP_FORCE_PU at 0 range 20 .. 20;
       CPU_TOP_FORCE_PD at 0 range 21 .. 21;
       CPU_TOP_FORCE_PU at 0 range 22 .. 22;
       Reserved_23_26 at 0 range 23 .. 26;
       BT_PD_EN at 0 range 27 .. 27;
       DG_PERI_PD_EN at 0 range 28 .. 28;
       CPU_TOP_PD_EN at 0 range 29 .. 29;
       WIFI_PD_EN at 0 range 30 .. 30;
       DG_WRAP_PD_EN at 0 range 31 .. 31;
     end record;

   --  congigure digital power isolation
   type DIG_ISO_Register is record
      --  unspecified
      Reserved_0_6        : ESP32S3_Registers.UInt7 := 16#0#;
      --  No public
      FORCE_OFF           : Boolean := True;
      --  No public
      FORCE_ON            : Boolean := False;
      --  Read-only. read only register to indicate digital pad auto-hold
      --  status
      DG_PAD_AUTOHOLD     : Boolean := False;
      --  Write-only. wtite only register to clear digital pad auto-hold
      CLR_DG_PAD_AUTOHOLD : Boolean := False;
      --  digital pad enable auto-hold
      DG_PAD_AUTOHOLD_EN  : Boolean := False;
      --  digital pad force no ISO
      DG_PAD_FORCE_NOISO  : Boolean := True;
      --  digital pad force ISO
      DG_PAD_FORCE_ISO    : Boolean := False;
      --  digital pad force un-hold
      DG_PAD_FORCE_UNHOLD : Boolean := True;
      --  digital pad force hold
      DG_PAD_FORCE_HOLD   : Boolean := False;
      --  unspecified
      Reserved_16_21      : ESP32S3_Registers.UInt6 := 16#0#;
      --  internal SRAM 2 force ISO
      BT_FORCE_ISO        : Boolean := False;
      --  internal SRAM 2 force no ISO
      BT_FORCE_NOISO      : Boolean := True;
      --  internal SRAM 3 force ISO
      DG_PERI_FORCE_ISO   : Boolean := False;
      --  internal SRAM 3 force no ISO
      DG_PERI_FORCE_NOISO : Boolean := True;
      --  internal SRAM 4 force ISO
      CPU_TOP_FORCE_ISO   : Boolean := False;
      --  internal SRAM 4 force no ISO
      CPU_TOP_FORCE_NOISO : Boolean := True;
      --  wifi force ISO
      WIFI_FORCE_ISO      : Boolean := False;
      --  wifi force no ISO
      WIFI_FORCE_NOISO    : Boolean := True;
      --  digital core force ISO
      DG_WRAP_FORCE_ISO   : Boolean := False;
      --  digita core force no ISO
      DG_WRAP_FORCE_NOISO : Boolean := True;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DIG_ISO_Register use
     record
       Reserved_0_6 at 0 range 0 .. 6;
       FORCE_OFF at 0 range 7 .. 7;
       FORCE_ON at 0 range 8 .. 8;
       DG_PAD_AUTOHOLD at 0 range 9 .. 9;
       CLR_DG_PAD_AUTOHOLD at 0 range 10 .. 10;
       DG_PAD_AUTOHOLD_EN at 0 range 11 .. 11;
       DG_PAD_FORCE_NOISO at 0 range 12 .. 12;
       DG_PAD_FORCE_ISO at 0 range 13 .. 13;
       DG_PAD_FORCE_UNHOLD at 0 range 14 .. 14;
       DG_PAD_FORCE_HOLD at 0 range 15 .. 15;
       Reserved_16_21 at 0 range 16 .. 21;
       BT_FORCE_ISO at 0 range 22 .. 22;
       BT_FORCE_NOISO at 0 range 23 .. 23;
       DG_PERI_FORCE_ISO at 0 range 24 .. 24;
       DG_PERI_FORCE_NOISO at 0 range 25 .. 25;
       CPU_TOP_FORCE_ISO at 0 range 26 .. 26;
       CPU_TOP_FORCE_NOISO at 0 range 27 .. 27;
       WIFI_FORCE_ISO at 0 range 28 .. 28;
       WIFI_FORCE_NOISO at 0 range 29 .. 29;
       DG_WRAP_FORCE_ISO at 0 range 30 .. 30;
       DG_WRAP_FORCE_NOISO at 0 range 31 .. 31;
     end record;

   subtype WDTCONFIG0_WDT_CHIP_RESET_WIDTH_Field is ESP32S3_Registers.Byte;
   subtype WDTCONFIG0_WDT_SYS_RESET_LENGTH_Field is ESP32S3_Registers.UInt3;
   subtype WDTCONFIG0_WDT_CPU_RESET_LENGTH_Field is ESP32S3_Registers.UInt3;
   subtype WDTCONFIG0_WDT_STG3_Field is ESP32S3_Registers.UInt3;
   subtype WDTCONFIG0_WDT_STG2_Field is ESP32S3_Registers.UInt3;
   subtype WDTCONFIG0_WDT_STG1_Field is ESP32S3_Registers.UInt3;
   subtype WDTCONFIG0_WDT_STG0_Field is ESP32S3_Registers.UInt3;

   --  configure rtc watch dog
   type WDTCONFIG0_Register is record
      --  chip reset siginal pulse width
      WDT_CHIP_RESET_WIDTH : WDTCONFIG0_WDT_CHIP_RESET_WIDTH_Field := 16#14#;
      --  wdt reset whole chip enable
      WDT_CHIP_RESET_EN    : Boolean := False;
      --  pause WDT in sleep
      WDT_PAUSE_IN_SLP     : Boolean := True;
      --  enable WDT reset APP CPU
      WDT_APPCPU_RESET_EN  : Boolean := False;
      --  enable WDT reset PRO CPU
      WDT_PROCPU_RESET_EN  : Boolean := False;
      --  enable WDT in flash boot
      WDT_FLASHBOOT_MOD_EN : Boolean := True;
      --  system reset counter length
      WDT_SYS_RESET_LENGTH : WDTCONFIG0_WDT_SYS_RESET_LENGTH_Field := 16#1#;
      --  CPU reset counter length
      WDT_CPU_RESET_LENGTH : WDTCONFIG0_WDT_CPU_RESET_LENGTH_Field := 16#1#;
      --  1: interrupt stage en 2: CPU reset stage en 3: system reset stage en
      --  4: RTC reset stage en
      WDT_STG3             : WDTCONFIG0_WDT_STG3_Field := 16#0#;
      --  1: interrupt stage en 2: CPU reset stage en 3: system reset stage en
      --  4: RTC reset stage en
      WDT_STG2             : WDTCONFIG0_WDT_STG2_Field := 16#0#;
      --  1: interrupt stage en 2: CPU reset stage en 3: system reset stage en
      --  4: RTC reset stage en
      WDT_STG1             : WDTCONFIG0_WDT_STG1_Field := 16#0#;
      --  1: interrupt stage en 2: CPU reset stage en 3: system reset stage en
      --  4: RTC reset stage en
      WDT_STG0             : WDTCONFIG0_WDT_STG0_Field := 16#0#;
      --  enable rtc watch dog
      WDT_EN               : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for WDTCONFIG0_Register use
     record
       WDT_CHIP_RESET_WIDTH at 0 range 0 .. 7;
       WDT_CHIP_RESET_EN at 0 range 8 .. 8;
       WDT_PAUSE_IN_SLP at 0 range 9 .. 9;
       WDT_APPCPU_RESET_EN at 0 range 10 .. 10;
       WDT_PROCPU_RESET_EN at 0 range 11 .. 11;
       WDT_FLASHBOOT_MOD_EN at 0 range 12 .. 12;
       WDT_SYS_RESET_LENGTH at 0 range 13 .. 15;
       WDT_CPU_RESET_LENGTH at 0 range 16 .. 18;
       WDT_STG3 at 0 range 19 .. 21;
       WDT_STG2 at 0 range 22 .. 24;
       WDT_STG1 at 0 range 25 .. 27;
       WDT_STG0 at 0 range 28 .. 30;
       WDT_EN at 0 range 31 .. 31;
     end record;

   --  rtc wdt feed
   type WDTFEED_Register is record
      --  unspecified
      Reserved_0_30 : ESP32S3_Registers.UInt31 := 16#0#;
      --  Write-only. rtc wdt feed
      WDT_FEED      : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for WDTFEED_Register use
     record
       Reserved_0_30 at 0 range 0 .. 30;
       WDT_FEED at 0 range 31 .. 31;
     end record;

   subtype SWD_CONF_SWD_SIGNAL_WIDTH_Field is ESP32S3_Registers.UInt10;

   --  congfigure super watch dog
   type SWD_CONF_Register is record
      --  Read-only. swd reset flag
      SWD_RESET_FLAG   : Boolean := False;
      --  Read-only. swd interrupt for feeding
      SWD_FEED_INT     : Boolean := False;
      --  unspecified
      Reserved_2_16    : ESP32S3_Registers.UInt15 := 16#0#;
      --  bypass super watch dog reset
      SWD_BYPASS_RST   : Boolean := False;
      --  adjust signal width send to swd
      SWD_SIGNAL_WIDTH : SWD_CONF_SWD_SIGNAL_WIDTH_Field := 16#12C#;
      --  Write-only. reset swd reset flag
      SWD_RST_FLAG_CLR : Boolean := False;
      --  Write-only. Sw feed swd
      SWD_FEED         : Boolean := False;
      --  disabel SWD
      SWD_DISABLE      : Boolean := False;
      --  automatically feed swd when int comes
      SWD_AUTO_FEED_EN : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SWD_CONF_Register use
     record
       SWD_RESET_FLAG at 0 range 0 .. 0;
       SWD_FEED_INT at 0 range 1 .. 1;
       Reserved_2_16 at 0 range 2 .. 16;
       SWD_BYPASS_RST at 0 range 17 .. 17;
       SWD_SIGNAL_WIDTH at 0 range 18 .. 27;
       SWD_RST_FLAG_CLR at 0 range 28 .. 28;
       SWD_FEED at 0 range 29 .. 29;
       SWD_DISABLE at 0 range 30 .. 30;
       SWD_AUTO_FEED_EN at 0 range 31 .. 31;
     end record;

   subtype SW_CPU_STALL_SW_STALL_APPCPU_C1_Field is ESP32S3_Registers.UInt6;
   subtype SW_CPU_STALL_SW_STALL_PROCPU_C1_Field is ESP32S3_Registers.UInt6;

   --  configure cpu stall by sw
   type SW_CPU_STALL_Register is record
      --  unspecified
      Reserved_0_19      : ESP32S3_Registers.UInt20 := 16#0#;
      --  {reg_sw_stall_appcpu_c1[5:0], reg_sw_stall_appcpu_c0[1:0]} == 0x86
      --  will stall APP CPU
      SW_STALL_APPCPU_C1 : SW_CPU_STALL_SW_STALL_APPCPU_C1_Field := 16#0#;
      --  {reg_sw_stall_appcpu_c1[5:0], reg_sw_stall_appcpu_c0[1:0]} == 0x86
      --  will stall APP CPU
      SW_STALL_PROCPU_C1 : SW_CPU_STALL_SW_STALL_PROCPU_C1_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SW_CPU_STALL_Register use
     record
       Reserved_0_19 at 0 range 0 .. 19;
       SW_STALL_APPCPU_C1 at 0 range 20 .. 25;
       SW_STALL_PROCPU_C1 at 0 range 26 .. 31;
     end record;

   subtype LOW_POWER_ST_MAIN_STATE_Field is ESP32S3_Registers.UInt4;

   --  reserved register
   type LOW_POWER_ST_Register is record
      --  Read-only. rom0 power down
      XPD_ROM0               : Boolean;
      --  unspecified
      Reserved_1_1           : ESP32S3_Registers.Bit;
      --  Read-only. External DCDC power down
      XPD_DIG_DCDC           : Boolean;
      --  Read-only. rtc peripheral iso
      PERI_ISO               : Boolean;
      --  Read-only. rtc peripheral power down
      XPD_RTC_PERI           : Boolean;
      --  Read-only. wifi iso
      WIFI_ISO               : Boolean;
      --  Read-only. wifi wrap power down
      XPD_WIFI               : Boolean;
      --  Read-only. digital wrap iso
      DIG_ISO                : Boolean;
      --  Read-only. digital wrap power down
      XPD_DIG                : Boolean;
      --  Read-only. touch should start to work
      TOUCH_STATE_START      : Boolean;
      --  Read-only. touch is about to working. Switch rtc main state
      TOUCH_STATE_SWITCH     : Boolean;
      --  Read-only. touch is in sleep state
      TOUCH_STATE_SLP        : Boolean;
      --  Read-only. touch is done
      TOUCH_STATE_DONE       : Boolean;
      --  Read-only. ulp/cocpu should start to work
      COCPU_STATE_START      : Boolean;
      --  Read-only. ulp/cocpu is about to working. Switch rtc main state
      COCPU_STATE_SWITCH     : Boolean;
      --  Read-only. ulp/cocpu is in sleep state
      COCPU_STATE_SLP        : Boolean;
      --  Read-only. ulp/cocpu is done
      COCPU_STATE_DONE       : Boolean;
      --  Read-only. no use any more
      MAIN_STATE_XTAL_ISO    : Boolean;
      --  Read-only. rtc main state machine is in states that pll should be
      --  running
      MAIN_STATE_PLL_ON      : Boolean;
      --  Read-only. rtc is ready to receive wake up trigger from wake up
      --  source
      RDY_FOR_WAKEUP         : Boolean;
      --  Read-only. rtc main state machine has been waited for some cycles
      MAIN_STATE_WAIT_END    : Boolean;
      --  Read-only. rtc main state machine is in the states of wakeup process
      IN_WAKEUP_STATE        : Boolean;
      --  Read-only. rtc main state machine is in the states of low power
      IN_LOW_POWER_STATE     : Boolean;
      --  Read-only. rtc main state machine is in wait 8m state
      MAIN_STATE_IN_WAIT_8M  : Boolean;
      --  Read-only. rtc main state machine is in wait pll state
      MAIN_STATE_IN_WAIT_PLL : Boolean;
      --  Read-only. rtc main state machine is in wait xtal state
      MAIN_STATE_IN_WAIT_XTL : Boolean;
      --  Read-only. rtc main state machine is in sleep state
      MAIN_STATE_IN_SLP      : Boolean;
      --  Read-only. rtc main state machine is in idle state
      MAIN_STATE_IN_IDLE     : Boolean;
      --  Read-only. rtc main state machine status
      MAIN_STATE             : LOW_POWER_ST_MAIN_STATE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for LOW_POWER_ST_Register use
     record
       XPD_ROM0 at 0 range 0 .. 0;
       Reserved_1_1 at 0 range 1 .. 1;
       XPD_DIG_DCDC at 0 range 2 .. 2;
       PERI_ISO at 0 range 3 .. 3;
       XPD_RTC_PERI at 0 range 4 .. 4;
       WIFI_ISO at 0 range 5 .. 5;
       XPD_WIFI at 0 range 6 .. 6;
       DIG_ISO at 0 range 7 .. 7;
       XPD_DIG at 0 range 8 .. 8;
       TOUCH_STATE_START at 0 range 9 .. 9;
       TOUCH_STATE_SWITCH at 0 range 10 .. 10;
       TOUCH_STATE_SLP at 0 range 11 .. 11;
       TOUCH_STATE_DONE at 0 range 12 .. 12;
       COCPU_STATE_START at 0 range 13 .. 13;
       COCPU_STATE_SWITCH at 0 range 14 .. 14;
       COCPU_STATE_SLP at 0 range 15 .. 15;
       COCPU_STATE_DONE at 0 range 16 .. 16;
       MAIN_STATE_XTAL_ISO at 0 range 17 .. 17;
       MAIN_STATE_PLL_ON at 0 range 18 .. 18;
       RDY_FOR_WAKEUP at 0 range 19 .. 19;
       MAIN_STATE_WAIT_END at 0 range 20 .. 20;
       IN_WAKEUP_STATE at 0 range 21 .. 21;
       IN_LOW_POWER_STATE at 0 range 22 .. 22;
       MAIN_STATE_IN_WAIT_8M at 0 range 23 .. 23;
       MAIN_STATE_IN_WAIT_PLL at 0 range 24 .. 24;
       MAIN_STATE_IN_WAIT_XTL at 0 range 25 .. 25;
       MAIN_STATE_IN_SLP at 0 range 26 .. 26;
       MAIN_STATE_IN_IDLE at 0 range 27 .. 27;
       MAIN_STATE at 0 range 28 .. 31;
     end record;

   --  rtc pad hold configure
   type PAD_HOLD_Register is record
      --  hold rtc pad0
      TOUCH_PAD0_HOLD  : Boolean := False;
      --  hold rtc pad-1
      TOUCH_PAD1_HOLD  : Boolean := False;
      --  hold rtc pad-2
      TOUCH_PAD2_HOLD  : Boolean := False;
      --  hold rtc pad-3
      TOUCH_PAD3_HOLD  : Boolean := False;
      --  hold rtc pad-4
      TOUCH_PAD4_HOLD  : Boolean := False;
      --  hold rtc pad-5
      TOUCH_PAD5_HOLD  : Boolean := False;
      --  hold rtc pad-6
      TOUCH_PAD6_HOLD  : Boolean := False;
      --  hold rtc pad-7
      TOUCH_PAD7_HOLD  : Boolean := False;
      --  hold rtc pad-8
      TOUCH_PAD8_HOLD  : Boolean := False;
      --  hold rtc pad-9
      TOUCH_PAD9_HOLD  : Boolean := False;
      --  hold rtc pad-10
      TOUCH_PAD10_HOLD : Boolean := False;
      --  hold rtc pad-11
      TOUCH_PAD11_HOLD : Boolean := False;
      --  hold rtc pad-12
      TOUCH_PAD12_HOLD : Boolean := False;
      --  hold rtc pad-13
      TOUCH_PAD13_HOLD : Boolean := False;
      --  hold rtc pad-14
      TOUCH_PAD14_HOLD : Boolean := False;
      --  hold rtc pad-15
      X32P_HOLD        : Boolean := False;
      --  hold rtc pad-16
      X32N_HOLD        : Boolean := False;
      --  hold rtc pad-17
      PDAC1_HOLD       : Boolean := False;
      --  hold rtc pad-18
      PDAC2_HOLD       : Boolean := False;
      --  hold rtc pad-19
      PAD19_HOLD       : Boolean := False;
      --  hold rtc pad-20
      PAD20_HOLD       : Boolean := False;
      --  hold rtc pad-21
      PAD21_HOLD       : Boolean := False;
      --  unspecified
      Reserved_22_31   : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PAD_HOLD_Register use
     record
       TOUCH_PAD0_HOLD at 0 range 0 .. 0;
       TOUCH_PAD1_HOLD at 0 range 1 .. 1;
       TOUCH_PAD2_HOLD at 0 range 2 .. 2;
       TOUCH_PAD3_HOLD at 0 range 3 .. 3;
       TOUCH_PAD4_HOLD at 0 range 4 .. 4;
       TOUCH_PAD5_HOLD at 0 range 5 .. 5;
       TOUCH_PAD6_HOLD at 0 range 6 .. 6;
       TOUCH_PAD7_HOLD at 0 range 7 .. 7;
       TOUCH_PAD8_HOLD at 0 range 8 .. 8;
       TOUCH_PAD9_HOLD at 0 range 9 .. 9;
       TOUCH_PAD10_HOLD at 0 range 10 .. 10;
       TOUCH_PAD11_HOLD at 0 range 11 .. 11;
       TOUCH_PAD12_HOLD at 0 range 12 .. 12;
       TOUCH_PAD13_HOLD at 0 range 13 .. 13;
       TOUCH_PAD14_HOLD at 0 range 14 .. 14;
       X32P_HOLD at 0 range 15 .. 15;
       X32N_HOLD at 0 range 16 .. 16;
       PDAC1_HOLD at 0 range 17 .. 17;
       PDAC2_HOLD at 0 range 18 .. 18;
       PAD19_HOLD at 0 range 19 .. 19;
       PAD20_HOLD at 0 range 20 .. 20;
       PAD21_HOLD at 0 range 21 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype EXT_WAKEUP1_EXT_WAKEUP1_SEL_Field is ESP32S3_Registers.UInt22;

   --  configure ext1 wakeup
   type EXT_WAKEUP1_Register is record
      --  Bitmap to select RTC pads for ext wakeup1
      EXT_WAKEUP1_SEL        : EXT_WAKEUP1_EXT_WAKEUP1_SEL_Field := 16#0#;
      --  Write-only. clear ext wakeup1 status
      EXT_WAKEUP1_STATUS_CLR : Boolean := False;
      --  unspecified
      Reserved_23_31         : ESP32S3_Registers.UInt9 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for EXT_WAKEUP1_Register use
     record
       EXT_WAKEUP1_SEL at 0 range 0 .. 21;
       EXT_WAKEUP1_STATUS_CLR at 0 range 22 .. 22;
       Reserved_23_31 at 0 range 23 .. 31;
     end record;

   subtype EXT_WAKEUP1_STATUS_EXT_WAKEUP1_STATUS_Field is
     ESP32S3_Registers.UInt22;

   --  check ext wakeup1 status
   type EXT_WAKEUP1_STATUS_Register is record
      --  Read-only. ext wakeup1 status
      EXT_WAKEUP1_STATUS : EXT_WAKEUP1_STATUS_EXT_WAKEUP1_STATUS_Field;
      --  unspecified
      Reserved_22_31     : ESP32S3_Registers.UInt10;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for EXT_WAKEUP1_STATUS_Register use
     record
       EXT_WAKEUP1_STATUS at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype BROWN_OUT_BROWN_OUT_INT_WAIT_Field is ESP32S3_Registers.UInt10;
   subtype BROWN_OUT_BROWN_OUT_RST_WAIT_Field is ESP32S3_Registers.UInt10;

   --  congfigure brownout
   type BROWN_OUT_Register is record
      --  unspecified
      Reserved_0_3              : ESP32S3_Registers.UInt4 := 16#0#;
      --  brown out interrupt wait cycles
      BROWN_OUT_INT_WAIT        : BROWN_OUT_BROWN_OUT_INT_WAIT_Field := 16#1#;
      --  enable close flash when brown out happens
      BROWN_OUT_CLOSE_FLASH_ENA : Boolean := False;
      --  enable power down RF when brown out happens
      BROWN_OUT_PD_RF_ENA       : Boolean := False;
      --  brown out reset wait cycles
      BROWN_OUT_RST_WAIT        : BROWN_OUT_BROWN_OUT_RST_WAIT_Field :=
        16#3FF#;
      --  enable brown out reset
      BROWN_OUT_RST_ENA         : Boolean := False;
      --  1: 4-pos reset, 0: sys_reset
      BROWN_OUT_RST_SEL         : Boolean := False;
      --  enable brown out reset en
      BROWN_OUT_ANA_RST_EN      : Boolean := False;
      --  Write-only. clear brown out counter
      BROWN_OUT_CNT_CLR         : Boolean := False;
      --  enable brown out
      BROWN_OUT_ENA             : Boolean := True;
      --  Read-only. get brown out detect
      DET                       : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for BROWN_OUT_Register use
     record
       Reserved_0_3 at 0 range 0 .. 3;
       BROWN_OUT_INT_WAIT at 0 range 4 .. 13;
       BROWN_OUT_CLOSE_FLASH_ENA at 0 range 14 .. 14;
       BROWN_OUT_PD_RF_ENA at 0 range 15 .. 15;
       BROWN_OUT_RST_WAIT at 0 range 16 .. 25;
       BROWN_OUT_RST_ENA at 0 range 26 .. 26;
       BROWN_OUT_RST_SEL at 0 range 27 .. 27;
       BROWN_OUT_ANA_RST_EN at 0 range 28 .. 28;
       BROWN_OUT_CNT_CLR at 0 range 29 .. 29;
       BROWN_OUT_ENA at 0 range 30 .. 30;
       DET at 0 range 31 .. 31;
     end record;

   subtype TIME_HIGH1_TIMER_VALUE1_HIGH_Field is ESP32S3_Registers.UInt16;

   --  RTC timer high 16 bits
   type TIME_HIGH1_Register is record
      --  Read-only. RTC timer high 16 bits
      TIMER_VALUE1_HIGH : TIME_HIGH1_TIMER_VALUE1_HIGH_Field;
      --  unspecified
      Reserved_16_31    : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIME_HIGH1_Register use
     record
       TIMER_VALUE1_HIGH at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype XTAL32K_CONF_XTAL32K_RETURN_WAIT_Field is ESP32S3_Registers.UInt4;
   subtype XTAL32K_CONF_XTAL32K_RESTART_WAIT_Field is ESP32S3_Registers.UInt16;
   subtype XTAL32K_CONF_XTAL32K_WDT_TIMEOUT_Field is ESP32S3_Registers.Byte;
   subtype XTAL32K_CONF_XTAL32K_STABLE_THRES_Field is ESP32S3_Registers.UInt4;

   --  configure xtal32k
   type XTAL32K_CONF_Register is record
      --  cycles to wait to return noral xtal 32k
      XTAL32K_RETURN_WAIT  : XTAL32K_CONF_XTAL32K_RETURN_WAIT_Field := 16#0#;
      --  cycles to wait to repower on xtal 32k
      XTAL32K_RESTART_WAIT : XTAL32K_CONF_XTAL32K_RESTART_WAIT_Field := 16#0#;
      --  If no clock detected for this amount of time 32k is regarded as dead
      XTAL32K_WDT_TIMEOUT  : XTAL32K_CONF_XTAL32K_WDT_TIMEOUT_Field := 16#FF#;
      --  if restarted xtal32k period is smaller than this, it is regarded as
      --  stable
      XTAL32K_STABLE_THRES : XTAL32K_CONF_XTAL32K_STABLE_THRES_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for XTAL32K_CONF_Register use
     record
       XTAL32K_RETURN_WAIT at 0 range 0 .. 3;
       XTAL32K_RESTART_WAIT at 0 range 4 .. 19;
       XTAL32K_WDT_TIMEOUT at 0 range 20 .. 27;
       XTAL32K_STABLE_THRES at 0 range 28 .. 31;
     end record;

   subtype ULP_CP_TIMER_ULP_CP_PC_INIT_Field is ESP32S3_Registers.UInt11;

   --  configure ulp
   type ULP_CP_TIMER_Register is record
      --  ULP-coprocessor PC initial address
      ULP_CP_PC_INIT         : ULP_CP_TIMER_ULP_CP_PC_INIT_Field := 16#0#;
      --  unspecified
      Reserved_11_28         : ESP32S3_Registers.UInt18 := 16#0#;
      --  ULP-coprocessor wakeup by GPIO enable
      ULP_CP_GPIO_WAKEUP_ENA : Boolean := False;
      --  Write-only. ULP-coprocessor wakeup by GPIO state clear
      ULP_CP_GPIO_WAKEUP_CLR : Boolean := False;
      --  ULP-coprocessor timer enable bit
      ULP_CP_SLP_TIMER_EN    : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ULP_CP_TIMER_Register use
     record
       ULP_CP_PC_INIT at 0 range 0 .. 10;
       Reserved_11_28 at 0 range 11 .. 28;
       ULP_CP_GPIO_WAKEUP_ENA at 0 range 29 .. 29;
       ULP_CP_GPIO_WAKEUP_CLR at 0 range 30 .. 30;
       ULP_CP_SLP_TIMER_EN at 0 range 31 .. 31;
     end record;

   subtype ULP_CP_CTRL_ULP_CP_MEM_ADDR_INIT_Field is ESP32S3_Registers.UInt11;
   subtype ULP_CP_CTRL_ULP_CP_MEM_ADDR_SIZE_Field is ESP32S3_Registers.UInt11;

   --  configure ulp
   type ULP_CP_CTRL_Register is record
      --  No public
      ULP_CP_MEM_ADDR_INIT   : ULP_CP_CTRL_ULP_CP_MEM_ADDR_INIT_Field :=
        16#200#;
      --  No public
      ULP_CP_MEM_ADDR_SIZE   : ULP_CP_CTRL_ULP_CP_MEM_ADDR_SIZE_Field :=
        16#200#;
      --  Write-only. No public
      ULP_CP_MEM_OFFST_CLR   : Boolean := False;
      --  unspecified
      Reserved_23_27         : ESP32S3_Registers.UInt5 := 16#0#;
      --  ulp coprocessor clk force on
      ULP_CP_CLK_FO          : Boolean := False;
      --  ulp coprocessor clk software reset
      ULP_CP_RESET           : Boolean := False;
      --  1: ULP-coprocessor is started by SW
      ULP_CP_FORCE_START_TOP : Boolean := False;
      --  Write 1 to start ULP-coprocessor
      ULP_CP_START_TOP       : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ULP_CP_CTRL_Register use
     record
       ULP_CP_MEM_ADDR_INIT at 0 range 0 .. 10;
       ULP_CP_MEM_ADDR_SIZE at 0 range 11 .. 21;
       ULP_CP_MEM_OFFST_CLR at 0 range 22 .. 22;
       Reserved_23_27 at 0 range 23 .. 27;
       ULP_CP_CLK_FO at 0 range 28 .. 28;
       ULP_CP_RESET at 0 range 29 .. 29;
       ULP_CP_FORCE_START_TOP at 0 range 30 .. 30;
       ULP_CP_START_TOP at 0 range 31 .. 31;
     end record;

   subtype COCPU_CTRL_COCPU_START_2_RESET_DIS_Field is ESP32S3_Registers.UInt6;
   subtype COCPU_CTRL_COCPU_START_2_INTR_EN_Field is ESP32S3_Registers.UInt6;
   subtype COCPU_CTRL_COCPU_SHUT_2_CLK_DIS_Field is ESP32S3_Registers.Byte;

   --  configure ulp-riscv
   type COCPU_CTRL_Register is record
      --  cocpu clk force on
      COCPU_CLK_FO            : Boolean := False;
      --  time from start cocpu to pull down reset
      COCPU_START_2_RESET_DIS : COCPU_CTRL_COCPU_START_2_RESET_DIS_Field :=
        16#8#;
      --  time from start cocpu to give start interrupt
      COCPU_START_2_INTR_EN   : COCPU_CTRL_COCPU_START_2_INTR_EN_Field :=
        16#10#;
      --  to shut cocpu
      COCPU_SHUT              : Boolean := False;
      --  time from shut cocpu to disable clk
      COCPU_SHUT_2_CLK_DIS    : COCPU_CTRL_COCPU_SHUT_2_CLK_DIS_Field :=
        16#28#;
      --  to reset cocpu
      COCPU_SHUT_RESET_EN     : Boolean := False;
      --  1: old ULP 0: new riscV
      COCPU_SEL               : Boolean := True;
      --  1: select riscv done 0: select ulp done
      COCPU_DONE_FORCE        : Boolean := False;
      --  done signal used by riscv to control timer.
      COCPU_DONE              : Boolean := False;
      --  Write-only. trigger cocpu register interrupt
      COCPU_SW_INT_TRIGGER    : Boolean := False;
      --  open ulp-riscv clk gate
      COCPU_CLKGATE_EN        : Boolean := False;
      --  unspecified
      Reserved_28_31          : ESP32S3_Registers.UInt4 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for COCPU_CTRL_Register use
     record
       COCPU_CLK_FO at 0 range 0 .. 0;
       COCPU_START_2_RESET_DIS at 0 range 1 .. 6;
       COCPU_START_2_INTR_EN at 0 range 7 .. 12;
       COCPU_SHUT at 0 range 13 .. 13;
       COCPU_SHUT_2_CLK_DIS at 0 range 14 .. 21;
       COCPU_SHUT_RESET_EN at 0 range 22 .. 22;
       COCPU_SEL at 0 range 23 .. 23;
       COCPU_DONE_FORCE at 0 range 24 .. 24;
       COCPU_DONE at 0 range 25 .. 25;
       COCPU_SW_INT_TRIGGER at 0 range 26 .. 26;
       COCPU_CLKGATE_EN at 0 range 27 .. 27;
       Reserved_28_31 at 0 range 28 .. 31;
     end record;

   subtype TOUCH_CTRL1_TOUCH_SLEEP_CYCLES_Field is ESP32S3_Registers.UInt16;
   subtype TOUCH_CTRL1_TOUCH_MEAS_NUM_Field is ESP32S3_Registers.UInt16;

   --  configure touch controller
   type TOUCH_CTRL1_Register is record
      --  sleep cycles for timer
      TOUCH_SLEEP_CYCLES : TOUCH_CTRL1_TOUCH_SLEEP_CYCLES_Field := 16#100#;
      --  the meas length (in 8MHz)
      TOUCH_MEAS_NUM     : TOUCH_CTRL1_TOUCH_MEAS_NUM_Field := 16#1000#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_CTRL1_Register use
     record
       TOUCH_SLEEP_CYCLES at 0 range 0 .. 15;
       TOUCH_MEAS_NUM at 0 range 16 .. 31;
     end record;

   subtype TOUCH_CTRL2_TOUCH_DRANGE_Field is ESP32S3_Registers.UInt2;
   subtype TOUCH_CTRL2_TOUCH_DREFL_Field is ESP32S3_Registers.UInt2;
   subtype TOUCH_CTRL2_TOUCH_DREFH_Field is ESP32S3_Registers.UInt2;
   subtype TOUCH_CTRL2_TOUCH_REFC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_CTRL2_TOUCH_XPD_WAIT_Field is ESP32S3_Registers.Byte;
   subtype TOUCH_CTRL2_TOUCH_SLP_CYC_DIV_Field is ESP32S3_Registers.UInt2;
   subtype TOUCH_CTRL2_TOUCH_TIMER_FORCE_DONE_Field is ESP32S3_Registers.UInt2;

   --  configure touch controller
   type TOUCH_CTRL2_Register is record
      --  unspecified
      Reserved_0_1           : ESP32S3_Registers.UInt2 := 16#0#;
      --  TOUCH_DRANGE
      TOUCH_DRANGE           : TOUCH_CTRL2_TOUCH_DRANGE_Field := 16#3#;
      --  TOUCH_DREFL
      TOUCH_DREFL            : TOUCH_CTRL2_TOUCH_DREFL_Field := 16#0#;
      --  TOUCH_DREFH
      TOUCH_DREFH            : TOUCH_CTRL2_TOUCH_DREFH_Field := 16#3#;
      --  TOUCH_XPD_BIAS
      TOUCH_XPD_BIAS         : Boolean := False;
      --  TOUCH pad0 reference cap
      TOUCH_REFC             : TOUCH_CTRL2_TOUCH_REFC_Field := 16#0#;
      --  1:use self bias 0:use bandgap bias
      TOUCH_DBIAS            : Boolean := False;
      --  touch timer enable bit
      TOUCH_SLP_TIMER_EN     : Boolean := False;
      --  1: TOUCH_START & TOUCH_XPD is controlled by touch fsm
      TOUCH_START_FSM_EN     : Boolean := True;
      --  1: start touch fsm
      TOUCH_START_EN         : Boolean := False;
      --  1: to start touch fsm by SW
      TOUCH_START_FORCE      : Boolean := False;
      --  the waiting cycles (in 8MHz) between TOUCH_START and TOUCH_XPD
      TOUCH_XPD_WAIT         : TOUCH_CTRL2_TOUCH_XPD_WAIT_Field := 16#4#;
      --  when a touch pad is active sleep cycle could be divided by this
      --  number
      TOUCH_SLP_CYC_DIV      : TOUCH_CTRL2_TOUCH_SLP_CYC_DIV_Field := 16#0#;
      --  force touch timer done
      TOUCH_TIMER_FORCE_DONE : TOUCH_CTRL2_TOUCH_TIMER_FORCE_DONE_Field :=
        16#0#;
      --  reset upgrade touch
      TOUCH_RESET            : Boolean := False;
      --  touch clock force on
      TOUCH_CLK_FO           : Boolean := False;
      --  touch clock enable
      TOUCH_CLKGATE_EN       : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_CTRL2_Register use
     record
       Reserved_0_1 at 0 range 0 .. 1;
       TOUCH_DRANGE at 0 range 2 .. 3;
       TOUCH_DREFL at 0 range 4 .. 5;
       TOUCH_DREFH at 0 range 6 .. 7;
       TOUCH_XPD_BIAS at 0 range 8 .. 8;
       TOUCH_REFC at 0 range 9 .. 11;
       TOUCH_DBIAS at 0 range 12 .. 12;
       TOUCH_SLP_TIMER_EN at 0 range 13 .. 13;
       TOUCH_START_FSM_EN at 0 range 14 .. 14;
       TOUCH_START_EN at 0 range 15 .. 15;
       TOUCH_START_FORCE at 0 range 16 .. 16;
       TOUCH_XPD_WAIT at 0 range 17 .. 24;
       TOUCH_SLP_CYC_DIV at 0 range 25 .. 26;
       TOUCH_TIMER_FORCE_DONE at 0 range 27 .. 28;
       TOUCH_RESET at 0 range 29 .. 29;
       TOUCH_CLK_FO at 0 range 30 .. 30;
       TOUCH_CLKGATE_EN at 0 range 31 .. 31;
     end record;

   subtype TOUCH_SCAN_CTRL_TOUCH_DENOISE_RES_Field is ESP32S3_Registers.UInt2;
   subtype TOUCH_SCAN_CTRL_TOUCH_SCAN_PAD_MAP_Field is
     ESP32S3_Registers.UInt15;
   subtype TOUCH_SCAN_CTRL_TOUCH_BUFDRV_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_SCAN_CTRL_TOUCH_OUT_RING_Field is ESP32S3_Registers.UInt4;

   --  configure touch controller
   type TOUCH_SCAN_CTRL_Register is record
      --  De-noise resolution: 12/10/8/4 bit
      TOUCH_DENOISE_RES         : TOUCH_SCAN_CTRL_TOUCH_DENOISE_RES_Field :=
        16#2#;
      --  touch pad0 will be used to de-noise
      TOUCH_DENOISE_EN          : Boolean := False;
      --  unspecified
      Reserved_3_7              : ESP32S3_Registers.UInt5 := 16#0#;
      --  inactive touch pads connect to 1: gnd 0: HighZ
      TOUCH_INACTIVE_CONNECTION : Boolean := True;
      --  touch pad14 will be used as shield
      TOUCH_SHIELD_PAD_EN       : Boolean := False;
      --  touch scan mode pad enable map
      TOUCH_SCAN_PAD_MAP        : TOUCH_SCAN_CTRL_TOUCH_SCAN_PAD_MAP_Field :=
        16#0#;
      --  touch7 buffer driver strength
      TOUCH_BUFDRV              : TOUCH_SCAN_CTRL_TOUCH_BUFDRV_Field := 16#0#;
      --  select out ring pad
      TOUCH_OUT_RING            : TOUCH_SCAN_CTRL_TOUCH_OUT_RING_Field :=
        16#F#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_SCAN_CTRL_Register use
     record
       TOUCH_DENOISE_RES at 0 range 0 .. 1;
       TOUCH_DENOISE_EN at 0 range 2 .. 2;
       Reserved_3_7 at 0 range 3 .. 7;
       TOUCH_INACTIVE_CONNECTION at 0 range 8 .. 8;
       TOUCH_SHIELD_PAD_EN at 0 range 9 .. 9;
       TOUCH_SCAN_PAD_MAP at 0 range 10 .. 24;
       TOUCH_BUFDRV at 0 range 25 .. 27;
       TOUCH_OUT_RING at 0 range 28 .. 31;
     end record;

   subtype TOUCH_SLP_THRES_TOUCH_SLP_TH_Field is ESP32S3_Registers.UInt22;
   subtype TOUCH_SLP_THRES_TOUCH_SLP_PAD_Field is ESP32S3_Registers.UInt5;

   --  configure touch controller
   type TOUCH_SLP_THRES_Register is record
      --  the threshold for sleep touch pad
      TOUCH_SLP_TH          : TOUCH_SLP_THRES_TOUCH_SLP_TH_Field := 16#0#;
      --  unspecified
      Reserved_22_25        : ESP32S3_Registers.UInt4 := 16#0#;
      --  sleep pad approach function enable
      TOUCH_SLP_APPROACH_EN : Boolean := False;
      --  configure which pad as slp pad
      TOUCH_SLP_PAD         : TOUCH_SLP_THRES_TOUCH_SLP_PAD_Field := 16#F#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_SLP_THRES_Register use
     record
       TOUCH_SLP_TH at 0 range 0 .. 21;
       Reserved_22_25 at 0 range 22 .. 25;
       TOUCH_SLP_APPROACH_EN at 0 range 26 .. 26;
       TOUCH_SLP_PAD at 0 range 27 .. 31;
     end record;

   subtype TOUCH_APPROACH_TOUCH_APPROACH_MEAS_TIME_Field is
     ESP32S3_Registers.Byte;

   --  configure touch controller
   type TOUCH_APPROACH_Register is record
      --  unspecified
      Reserved_0_22            : ESP32S3_Registers.UInt23 := 16#0#;
      --  Write-only. clear touch slp channel
      TOUCH_SLP_CHANNEL_CLR    : Boolean := False;
      --  approach pads total meas times
      TOUCH_APPROACH_MEAS_TIME :
        TOUCH_APPROACH_TOUCH_APPROACH_MEAS_TIME_Field := 16#50#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_APPROACH_Register use
     record
       Reserved_0_22 at 0 range 0 .. 22;
       TOUCH_SLP_CHANNEL_CLR at 0 range 23 .. 23;
       TOUCH_APPROACH_MEAS_TIME at 0 range 24 .. 31;
     end record;

   subtype TOUCH_FILTER_CTRL_TOUCH_SMOOTH_LVL_Field is ESP32S3_Registers.UInt2;
   subtype TOUCH_FILTER_CTRL_TOUCH_JITTER_STEP_Field is
     ESP32S3_Registers.UInt4;
   subtype TOUCH_FILTER_CTRL_TOUCH_NEG_NOISE_LIMIT_Field is
     ESP32S3_Registers.UInt4;
   subtype TOUCH_FILTER_CTRL_TOUCH_NEG_NOISE_THRES_Field is
     ESP32S3_Registers.UInt2;
   subtype TOUCH_FILTER_CTRL_TOUCH_NOISE_THRES_Field is
     ESP32S3_Registers.UInt2;
   subtype TOUCH_FILTER_CTRL_TOUCH_HYSTERESIS_Field is ESP32S3_Registers.UInt2;
   subtype TOUCH_FILTER_CTRL_TOUCH_DEBOUNCE_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_FILTER_CTRL_TOUCH_FILTER_MODE_Field is
     ESP32S3_Registers.UInt3;

   --  configure touch controller
   type TOUCH_FILTER_CTRL_Register is record
      --  unspecified
      Reserved_0_6                 : ESP32S3_Registers.UInt7 := 16#0#;
      --  bypass neg noise thres
      TOUCH_BYPASS_NEG_NOISE_THRES : Boolean := False;
      --  bypaas noise thres
      TOUCH_BYPASS_NOISE_THRES     : Boolean := False;
      --  smooth filter factor
      TOUCH_SMOOTH_LVL             :
        TOUCH_FILTER_CTRL_TOUCH_SMOOTH_LVL_Field := 16#0#;
      --  touch jitter step
      TOUCH_JITTER_STEP            :
        TOUCH_FILTER_CTRL_TOUCH_JITTER_STEP_Field := 16#1#;
      --  negative threshold counter limit
      TOUCH_NEG_NOISE_LIMIT        :
        TOUCH_FILTER_CTRL_TOUCH_NEG_NOISE_LIMIT_Field := 16#5#;
      --  neg noise thres
      TOUCH_NEG_NOISE_THRES        :
        TOUCH_FILTER_CTRL_TOUCH_NEG_NOISE_THRES_Field := 16#1#;
      --  noise thres
      TOUCH_NOISE_THRES            :
        TOUCH_FILTER_CTRL_TOUCH_NOISE_THRES_Field := 16#1#;
      --  hysteresis
      TOUCH_HYSTERESIS             :
        TOUCH_FILTER_CTRL_TOUCH_HYSTERESIS_Field := 16#1#;
      --  debounce counter
      TOUCH_DEBOUNCE               : TOUCH_FILTER_CTRL_TOUCH_DEBOUNCE_Field :=
        16#3#;
      --  0: IIR ? 1: IIR ? 2: IIR 1/8 3: Jitter
      TOUCH_FILTER_MODE            :
        TOUCH_FILTER_CTRL_TOUCH_FILTER_MODE_Field := 16#1#;
      --  touch filter enable
      TOUCH_FILTER_EN              : Boolean := True;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_FILTER_CTRL_Register use
     record
       Reserved_0_6 at 0 range 0 .. 6;
       TOUCH_BYPASS_NEG_NOISE_THRES at 0 range 7 .. 7;
       TOUCH_BYPASS_NOISE_THRES at 0 range 8 .. 8;
       TOUCH_SMOOTH_LVL at 0 range 9 .. 10;
       TOUCH_JITTER_STEP at 0 range 11 .. 14;
       TOUCH_NEG_NOISE_LIMIT at 0 range 15 .. 18;
       TOUCH_NEG_NOISE_THRES at 0 range 19 .. 20;
       TOUCH_NOISE_THRES at 0 range 21 .. 22;
       TOUCH_HYSTERESIS at 0 range 23 .. 24;
       TOUCH_DEBOUNCE at 0 range 25 .. 27;
       TOUCH_FILTER_MODE at 0 range 28 .. 30;
       TOUCH_FILTER_EN at 0 range 31 .. 31;
     end record;

   subtype USB_CONF_USB_VREFH_Field is ESP32S3_Registers.UInt2;
   subtype USB_CONF_USB_VREFL_Field is ESP32S3_Registers.UInt2;

   --  usb configure
   type USB_CONF_Register is record
      --  reg_usb_vrefh
      USB_VREFH               : USB_CONF_USB_VREFH_Field := 16#0#;
      --  reg_usb_vrefl
      USB_VREFL               : USB_CONF_USB_VREFL_Field := 16#0#;
      --  reg_usb_vref_override
      USB_VREF_OVERRIDE       : Boolean := False;
      --  reg_usb_pad_pull_override
      USB_PAD_PULL_OVERRIDE   : Boolean := False;
      --  reg_usb_dp_pullup
      USB_DP_PULLUP           : Boolean := False;
      --  reg_usb_dp_pulldown
      USB_DP_PULLDOWN         : Boolean := False;
      --  reg_usb_dm_pullup
      USB_DM_PULLUP           : Boolean := False;
      --  reg_usb_dm_pulldown
      USB_DM_PULLDOWN         : Boolean := False;
      --  reg_usb_pullup_value
      USB_PULLUP_VALUE        : Boolean := False;
      --  reg_usb_pad_enable_override
      USB_PAD_ENABLE_OVERRIDE : Boolean := False;
      --  reg_usb_pad_enable
      USB_PAD_ENABLE          : Boolean := False;
      --  reg_usb_txm
      USB_TXM                 : Boolean := False;
      --  reg_usb_txp
      USB_TXP                 : Boolean := False;
      --  reg_usb_tx_en
      USB_TX_EN               : Boolean := False;
      --  reg_usb_tx_en_override
      USB_TX_EN_OVERRIDE      : Boolean := False;
      --  reg_usb_reset_disable
      USB_RESET_DISABLE       : Boolean := False;
      --  reg_io_mux_reset_disable
      IO_MUX_RESET_DISABLE    : Boolean := False;
      --  reg_sw_usb_phy_sel
      SW_USB_PHY_SEL          : Boolean := False;
      --  reg_sw_hw_usb_phy_sel
      SW_HW_USB_PHY_SEL       : Boolean := False;
      --  unspecified
      Reserved_21_31          : ESP32S3_Registers.UInt11 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for USB_CONF_Register use
     record
       USB_VREFH at 0 range 0 .. 1;
       USB_VREFL at 0 range 2 .. 3;
       USB_VREF_OVERRIDE at 0 range 4 .. 4;
       USB_PAD_PULL_OVERRIDE at 0 range 5 .. 5;
       USB_DP_PULLUP at 0 range 6 .. 6;
       USB_DP_PULLDOWN at 0 range 7 .. 7;
       USB_DM_PULLUP at 0 range 8 .. 8;
       USB_DM_PULLDOWN at 0 range 9 .. 9;
       USB_PULLUP_VALUE at 0 range 10 .. 10;
       USB_PAD_ENABLE_OVERRIDE at 0 range 11 .. 11;
       USB_PAD_ENABLE at 0 range 12 .. 12;
       USB_TXM at 0 range 13 .. 13;
       USB_TXP at 0 range 14 .. 14;
       USB_TX_EN at 0 range 15 .. 15;
       USB_TX_EN_OVERRIDE at 0 range 16 .. 16;
       USB_RESET_DISABLE at 0 range 17 .. 17;
       IO_MUX_RESET_DISABLE at 0 range 18 .. 18;
       SW_USB_PHY_SEL at 0 range 19 .. 19;
       SW_HW_USB_PHY_SEL at 0 range 20 .. 20;
       Reserved_21_31 at 0 range 21 .. 31;
     end record;

   subtype TOUCH_TIMEOUT_CTRL_TOUCH_TIMEOUT_NUM_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch controller
   type TOUCH_TIMEOUT_CTRL_Register is record
      --  configure touch timerout time
      TOUCH_TIMEOUT_NUM : TOUCH_TIMEOUT_CTRL_TOUCH_TIMEOUT_NUM_Field :=
        16#3FFFFF#;
      --  enable touch timerout
      TOUCH_TIMEOUT_EN  : Boolean := True;
      --  unspecified
      Reserved_23_31    : ESP32S3_Registers.UInt9 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_TIMEOUT_CTRL_Register use
     record
       TOUCH_TIMEOUT_NUM at 0 range 0 .. 21;
       TOUCH_TIMEOUT_EN at 0 range 22 .. 22;
       Reserved_23_31 at 0 range 23 .. 31;
     end record;

   subtype SLP_REJECT_CAUSE_REJECT_CAUSE_Field is ESP32S3_Registers.UInt18;

   --  get reject casue
   type SLP_REJECT_CAUSE_Register is record
      --  Read-only. sleep reject cause
      REJECT_CAUSE   : SLP_REJECT_CAUSE_REJECT_CAUSE_Field;
      --  unspecified
      Reserved_18_31 : ESP32S3_Registers.UInt14;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SLP_REJECT_CAUSE_Register use
     record
       REJECT_CAUSE at 0 range 0 .. 17;
       Reserved_18_31 at 0 range 18 .. 31;
     end record;

   --  rtc common configure
   type OPTION1_Register is record
      --  force chip entry download boot by sw
      FORCE_DOWNLOAD_BOOT : Boolean := False;
      --  unspecified
      Reserved_1_31       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for OPTION1_Register use
     record
       FORCE_DOWNLOAD_BOOT at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   subtype SLP_WAKEUP_CAUSE_WAKEUP_CAUSE_Field is ESP32S3_Registers.UInt17;

   --  get wakeup cause
   type SLP_WAKEUP_CAUSE_Register is record
      --  Read-only. sleep wakeup cause
      WAKEUP_CAUSE   : SLP_WAKEUP_CAUSE_WAKEUP_CAUSE_Field;
      --  unspecified
      Reserved_17_31 : ESP32S3_Registers.UInt15;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SLP_WAKEUP_CAUSE_Register use
     record
       WAKEUP_CAUSE at 0 range 0 .. 16;
       Reserved_17_31 at 0 range 17 .. 31;
     end record;

   subtype ULP_CP_TIMER_1_ULP_CP_TIMER_SLP_CYCLE_Field is
     ESP32S3_Registers.UInt24;

   --  configure ulp sleep time
   type ULP_CP_TIMER_1_Register is record
      --  unspecified
      Reserved_0_7           : ESP32S3_Registers.Byte := 16#0#;
      --  sleep cycles for ULP-coprocessor timer
      ULP_CP_TIMER_SLP_CYCLE : ULP_CP_TIMER_1_ULP_CP_TIMER_SLP_CYCLE_Field :=
        16#C8#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ULP_CP_TIMER_1_Register use
     record
       Reserved_0_7 at 0 range 0 .. 7;
       ULP_CP_TIMER_SLP_CYCLE at 0 range 8 .. 31;
     end record;

   --  oneset rtc interrupt
   type INT_ENA_RTC_W1TS_Register is record
      --  Write-only. enable sleep wakeup interrupt
      SLP_WAKEUP_INT_ENA_W1TS               : Boolean := False;
      --  Write-only. enable sleep reject interrupt
      SLP_REJECT_INT_ENA_W1TS               : Boolean := False;
      --  Write-only. enable SDIO idle interrupt
      SDIO_IDLE_INT_ENA_W1TS                : Boolean := False;
      --  Write-only. enable RTC WDT interrupt
      WDT_INT_ENA_W1TS                      : Boolean := False;
      --  Write-only. enable touch scan done interrupt
      TOUCH_SCAN_DONE_INT_ENA_W1TS          : Boolean := False;
      --  Write-only. enable ULP-coprocessor interrupt
      ULP_CP_INT_ENA_W1TS                   : Boolean := False;
      --  Write-only. enable touch done interrupt
      TOUCH_DONE_INT_ENA_W1TS               : Boolean := False;
      --  Write-only. enable touch active interrupt
      TOUCH_ACTIVE_INT_ENA_W1TS             : Boolean := False;
      --  Write-only. enable touch inactive interrupt
      TOUCH_INACTIVE_INT_ENA_W1TS           : Boolean := False;
      --  Write-only. enable brown out interrupt
      BROWN_OUT_INT_ENA_W1TS                : Boolean := False;
      --  Write-only. enable RTC main timer interrupt
      MAIN_TIMER_INT_ENA_W1TS               : Boolean := False;
      --  Write-only. enable saradc1 interrupt
      SARADC1_INT_ENA_W1TS                  : Boolean := False;
      --  Write-only. enable tsens interrupt
      TSENS_INT_ENA_W1TS                    : Boolean := False;
      --  Write-only. enable riscV cocpu interrupt
      COCPU_INT_ENA_W1TS                    : Boolean := False;
      --  Write-only. enable saradc2 interrupt
      SARADC2_INT_ENA_W1TS                  : Boolean := False;
      --  Write-only. enable super watch dog interrupt
      SWD_INT_ENA_W1TS                      : Boolean := False;
      --  Write-only. enable xtal32k_dead interrupt
      XTAL32K_DEAD_INT_ENA_W1TS             : Boolean := False;
      --  Write-only. enable cocpu trap interrupt
      COCPU_TRAP_INT_ENA_W1TS               : Boolean := False;
      --  Write-only. enable touch timeout interrupt
      TOUCH_TIMEOUT_INT_ENA_W1TS            : Boolean := False;
      --  Write-only. enbale gitch det interrupt
      GLITCH_DET_INT_ENA_W1TS               : Boolean := False;
      --  Write-only. enbale touch approach_loop done interrupt
      TOUCH_APPROACH_LOOP_DONE_INT_ENA_W1TS : Boolean := False;
      --  unspecified
      Reserved_21_31                        : ESP32S3_Registers.UInt11 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ENA_RTC_W1TS_Register use
     record
       SLP_WAKEUP_INT_ENA_W1TS at 0 range 0 .. 0;
       SLP_REJECT_INT_ENA_W1TS at 0 range 1 .. 1;
       SDIO_IDLE_INT_ENA_W1TS at 0 range 2 .. 2;
       WDT_INT_ENA_W1TS at 0 range 3 .. 3;
       TOUCH_SCAN_DONE_INT_ENA_W1TS at 0 range 4 .. 4;
       ULP_CP_INT_ENA_W1TS at 0 range 5 .. 5;
       TOUCH_DONE_INT_ENA_W1TS at 0 range 6 .. 6;
       TOUCH_ACTIVE_INT_ENA_W1TS at 0 range 7 .. 7;
       TOUCH_INACTIVE_INT_ENA_W1TS at 0 range 8 .. 8;
       BROWN_OUT_INT_ENA_W1TS at 0 range 9 .. 9;
       MAIN_TIMER_INT_ENA_W1TS at 0 range 10 .. 10;
       SARADC1_INT_ENA_W1TS at 0 range 11 .. 11;
       TSENS_INT_ENA_W1TS at 0 range 12 .. 12;
       COCPU_INT_ENA_W1TS at 0 range 13 .. 13;
       SARADC2_INT_ENA_W1TS at 0 range 14 .. 14;
       SWD_INT_ENA_W1TS at 0 range 15 .. 15;
       XTAL32K_DEAD_INT_ENA_W1TS at 0 range 16 .. 16;
       COCPU_TRAP_INT_ENA_W1TS at 0 range 17 .. 17;
       TOUCH_TIMEOUT_INT_ENA_W1TS at 0 range 18 .. 18;
       GLITCH_DET_INT_ENA_W1TS at 0 range 19 .. 19;
       TOUCH_APPROACH_LOOP_DONE_INT_ENA_W1TS at 0 range 20 .. 20;
       Reserved_21_31 at 0 range 21 .. 31;
     end record;

   --  oneset clr rtc interrupt enable
   type INT_ENA_RTC_W1TC_Register is record
      --  Write-only. enable sleep wakeup interrupt
      SLP_WAKEUP_INT_ENA_W1TC               : Boolean := False;
      --  Write-only. enable sleep reject interrupt
      SLP_REJECT_INT_ENA_W1TC               : Boolean := False;
      --  Write-only. enable SDIO idle interrupt
      SDIO_IDLE_INT_ENA_W1TC                : Boolean := False;
      --  Write-only. enable RTC WDT interrupt
      WDT_INT_ENA_W1TC                      : Boolean := False;
      --  Write-only. enable touch scan done interrupt
      TOUCH_SCAN_DONE_INT_ENA_W1TC          : Boolean := False;
      --  Write-only. enable ULP-coprocessor interrupt
      ULP_CP_INT_ENA_W1TC                   : Boolean := False;
      --  Write-only. enable touch done interrupt
      TOUCH_DONE_INT_ENA_W1TC               : Boolean := False;
      --  Write-only. enable touch active interrupt
      TOUCH_ACTIVE_INT_ENA_W1TC             : Boolean := False;
      --  Write-only. enable touch inactive interrupt
      TOUCH_INACTIVE_INT_ENA_W1TC           : Boolean := False;
      --  Write-only. enable brown out interrupt
      BROWN_OUT_INT_ENA_W1TC                : Boolean := False;
      --  Write-only. enable RTC main timer interrupt
      MAIN_TIMER_INT_ENA_W1TC               : Boolean := False;
      --  Write-only. enable saradc1 interrupt
      SARADC1_INT_ENA_W1TC                  : Boolean := False;
      --  Write-only. enable tsens interrupt
      TSENS_INT_ENA_W1TC                    : Boolean := False;
      --  Write-only. enable riscV cocpu interrupt
      COCPU_INT_ENA_W1TC                    : Boolean := False;
      --  Write-only. enable saradc2 interrupt
      SARADC2_INT_ENA_W1TC                  : Boolean := False;
      --  Write-only. enable super watch dog interrupt
      SWD_INT_ENA_W1TC                      : Boolean := False;
      --  Write-only. enable xtal32k_dead interrupt
      XTAL32K_DEAD_INT_ENA_W1TC             : Boolean := False;
      --  Write-only. enable cocpu trap interrupt
      COCPU_TRAP_INT_ENA_W1TC               : Boolean := False;
      --  Write-only. enable touch timeout interrupt
      TOUCH_TIMEOUT_INT_ENA_W1TC            : Boolean := False;
      --  Write-only. enbale gitch det interrupt
      GLITCH_DET_INT_ENA_W1TC               : Boolean := False;
      --  Write-only. enbale touch approach_loop done interrupt
      TOUCH_APPROACH_LOOP_DONE_INT_ENA_W1TC : Boolean := False;
      --  unspecified
      Reserved_21_31                        : ESP32S3_Registers.UInt11 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ENA_RTC_W1TC_Register use
     record
       SLP_WAKEUP_INT_ENA_W1TC at 0 range 0 .. 0;
       SLP_REJECT_INT_ENA_W1TC at 0 range 1 .. 1;
       SDIO_IDLE_INT_ENA_W1TC at 0 range 2 .. 2;
       WDT_INT_ENA_W1TC at 0 range 3 .. 3;
       TOUCH_SCAN_DONE_INT_ENA_W1TC at 0 range 4 .. 4;
       ULP_CP_INT_ENA_W1TC at 0 range 5 .. 5;
       TOUCH_DONE_INT_ENA_W1TC at 0 range 6 .. 6;
       TOUCH_ACTIVE_INT_ENA_W1TC at 0 range 7 .. 7;
       TOUCH_INACTIVE_INT_ENA_W1TC at 0 range 8 .. 8;
       BROWN_OUT_INT_ENA_W1TC at 0 range 9 .. 9;
       MAIN_TIMER_INT_ENA_W1TC at 0 range 10 .. 10;
       SARADC1_INT_ENA_W1TC at 0 range 11 .. 11;
       TSENS_INT_ENA_W1TC at 0 range 12 .. 12;
       COCPU_INT_ENA_W1TC at 0 range 13 .. 13;
       SARADC2_INT_ENA_W1TC at 0 range 14 .. 14;
       SWD_INT_ENA_W1TC at 0 range 15 .. 15;
       XTAL32K_DEAD_INT_ENA_W1TC at 0 range 16 .. 16;
       COCPU_TRAP_INT_ENA_W1TC at 0 range 17 .. 17;
       TOUCH_TIMEOUT_INT_ENA_W1TC at 0 range 18 .. 18;
       GLITCH_DET_INT_ENA_W1TC at 0 range 19 .. 19;
       TOUCH_APPROACH_LOOP_DONE_INT_ENA_W1TC at 0 range 20 .. 20;
       Reserved_21_31 at 0 range 21 .. 31;
     end record;

   subtype RETENTION_CTRL_RETENTION_TAG_MODE_Field is ESP32S3_Registers.UInt4;
   subtype RETENTION_CTRL_RETENTION_TARGET_Field is ESP32S3_Registers.UInt2;
   subtype RETENTION_CTRL_RETENTION_DONE_WAIT_Field is ESP32S3_Registers.UInt3;
   subtype RETENTION_CTRL_RETENTION_CLKOFF_WAIT_Field is
     ESP32S3_Registers.UInt4;
   subtype RETENTION_CTRL_RETENTION_WAIT_Field is ESP32S3_Registers.UInt7;

   --  configure retention
   type RETENTION_CTRL_Register is record
      --  unspecified
      Reserved_0_9          : ESP32S3_Registers.UInt10 := 16#0#;
      --  No public
      RETENTION_TAG_MODE    : RETENTION_CTRL_RETENTION_TAG_MODE_Field := 16#0#;
      --  congfigure retention target cpu and/or tag
      RETENTION_TARGET      : RETENTION_CTRL_RETENTION_TARGET_Field := 16#0#;
      --  No public
      RETENTION_CLK_SEL     : Boolean := False;
      --  wait retention done cycle
      RETENTION_DONE_WAIT   : RETENTION_CTRL_RETENTION_DONE_WAIT_Field :=
        16#2#;
      --  wait clk off cycle
      RETENTION_CLKOFF_WAIT : RETENTION_CTRL_RETENTION_CLKOFF_WAIT_Field :=
        16#3#;
      --  enable retention
      RETENTION_EN          : Boolean := False;
      --  wait cycles for rention operation
      RETENTION_WAIT        : RETENTION_CTRL_RETENTION_WAIT_Field := 16#14#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RETENTION_CTRL_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       RETENTION_TAG_MODE at 0 range 10 .. 13;
       RETENTION_TARGET at 0 range 14 .. 15;
       RETENTION_CLK_SEL at 0 range 16 .. 16;
       RETENTION_DONE_WAIT at 0 range 17 .. 19;
       RETENTION_CLKOFF_WAIT at 0 range 20 .. 23;
       RETENTION_EN at 0 range 24 .. 24;
       RETENTION_WAIT at 0 range 25 .. 31;
     end record;

   subtype PG_CTRL_POWER_GLITCH_DSENSE_Field is ESP32S3_Registers.UInt2;

   --  configure power glitch
   type PG_CTRL_Register is record
      --  unspecified
      Reserved_0_25          : ESP32S3_Registers.UInt26 := 16#0#;
      --  GLITCH_DSENSE
      POWER_GLITCH_DSENSE    : PG_CTRL_POWER_GLITCH_DSENSE_Field := 16#0#;
      --  force power glitch disable
      POWER_GLITCH_FORCE_PD  : Boolean := False;
      --  force power glitch enable
      POWER_GLITCH_FORCE_PU  : Boolean := False;
      --  select use analog fib signal
      POWER_GLITCH_EFUSE_SEL : Boolean := False;
      --  enable power glitch
      POWER_GLITCH_EN        : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PG_CTRL_Register use
     record
       Reserved_0_25 at 0 range 0 .. 25;
       POWER_GLITCH_DSENSE at 0 range 26 .. 27;
       POWER_GLITCH_FORCE_PD at 0 range 28 .. 28;
       POWER_GLITCH_FORCE_PU at 0 range 29 .. 29;
       POWER_GLITCH_EFUSE_SEL at 0 range 30 .. 30;
       POWER_GLITCH_EN at 0 range 31 .. 31;
     end record;

   subtype FIB_SEL_FIB_SEL_Field is ESP32S3_Registers.UInt3;

   --  No public
   type FIB_SEL_Register is record
      --  No public
      FIB_SEL       : FIB_SEL_FIB_SEL_Field := 16#7#;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for FIB_SEL_Register use
     record
       FIB_SEL at 0 range 0 .. 2;
       Reserved_3_31 at 0 range 3 .. 31;
     end record;

   subtype TOUCH_DAC_TOUCH_PAD9_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD8_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD7_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD6_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD5_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD4_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD3_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD2_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD1_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC_TOUCH_PAD0_DAC_Field is ESP32S3_Registers.UInt3;

   --  configure touch dac
   type TOUCH_DAC_Register is record
      --  unspecified
      Reserved_0_1   : ESP32S3_Registers.UInt2 := 16#0#;
      --  configure touch pad dac9
      TOUCH_PAD9_DAC : TOUCH_DAC_TOUCH_PAD9_DAC_Field := 16#0#;
      --  configure touch pad dac8
      TOUCH_PAD8_DAC : TOUCH_DAC_TOUCH_PAD8_DAC_Field := 16#0#;
      --  configure touch pad dac7
      TOUCH_PAD7_DAC : TOUCH_DAC_TOUCH_PAD7_DAC_Field := 16#0#;
      --  configure touch pad dac6
      TOUCH_PAD6_DAC : TOUCH_DAC_TOUCH_PAD6_DAC_Field := 16#0#;
      --  configure touch pad dac5
      TOUCH_PAD5_DAC : TOUCH_DAC_TOUCH_PAD5_DAC_Field := 16#0#;
      --  configure touch pad dac4
      TOUCH_PAD4_DAC : TOUCH_DAC_TOUCH_PAD4_DAC_Field := 16#0#;
      --  configure touch pad dac3
      TOUCH_PAD3_DAC : TOUCH_DAC_TOUCH_PAD3_DAC_Field := 16#0#;
      --  configure touch pad dac2
      TOUCH_PAD2_DAC : TOUCH_DAC_TOUCH_PAD2_DAC_Field := 16#0#;
      --  configure touch pad dac1
      TOUCH_PAD1_DAC : TOUCH_DAC_TOUCH_PAD1_DAC_Field := 16#0#;
      --  configure touch pad dac0
      TOUCH_PAD0_DAC : TOUCH_DAC_TOUCH_PAD0_DAC_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_DAC_Register use
     record
       Reserved_0_1 at 0 range 0 .. 1;
       TOUCH_PAD9_DAC at 0 range 2 .. 4;
       TOUCH_PAD8_DAC at 0 range 5 .. 7;
       TOUCH_PAD7_DAC at 0 range 8 .. 10;
       TOUCH_PAD6_DAC at 0 range 11 .. 13;
       TOUCH_PAD5_DAC at 0 range 14 .. 16;
       TOUCH_PAD4_DAC at 0 range 17 .. 19;
       TOUCH_PAD3_DAC at 0 range 20 .. 22;
       TOUCH_PAD2_DAC at 0 range 23 .. 25;
       TOUCH_PAD1_DAC at 0 range 26 .. 28;
       TOUCH_PAD0_DAC at 0 range 29 .. 31;
     end record;

   subtype TOUCH_DAC1_TOUCH_PAD14_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC1_TOUCH_PAD13_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC1_TOUCH_PAD12_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC1_TOUCH_PAD11_DAC_Field is ESP32S3_Registers.UInt3;
   subtype TOUCH_DAC1_TOUCH_PAD10_DAC_Field is ESP32S3_Registers.UInt3;

   --  configure touch dac
   type TOUCH_DAC1_Register is record
      --  unspecified
      Reserved_0_16   : ESP32S3_Registers.UInt17 := 16#0#;
      --  configure touch pad dac14
      TOUCH_PAD14_DAC : TOUCH_DAC1_TOUCH_PAD14_DAC_Field := 16#0#;
      --  configure touch pad dac13
      TOUCH_PAD13_DAC : TOUCH_DAC1_TOUCH_PAD13_DAC_Field := 16#0#;
      --  configure touch pad dac12
      TOUCH_PAD12_DAC : TOUCH_DAC1_TOUCH_PAD12_DAC_Field := 16#0#;
      --  configure touch pad dac11
      TOUCH_PAD11_DAC : TOUCH_DAC1_TOUCH_PAD11_DAC_Field := 16#0#;
      --  configure touch pad dac10
      TOUCH_PAD10_DAC : TOUCH_DAC1_TOUCH_PAD10_DAC_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_DAC1_Register use
     record
       Reserved_0_16 at 0 range 0 .. 16;
       TOUCH_PAD14_DAC at 0 range 17 .. 19;
       TOUCH_PAD13_DAC at 0 range 20 .. 22;
       TOUCH_PAD12_DAC at 0 range 23 .. 25;
       TOUCH_PAD11_DAC at 0 range 26 .. 28;
       TOUCH_PAD10_DAC at 0 range 29 .. 31;
     end record;

   --  configure ulp diable
   type COCPU_DISABLE_Register is record
      --  unspecified
      Reserved_0_30   : ESP32S3_Registers.UInt31 := 16#0#;
      --  configure ulp diable
      DISABLE_RTC_CPU : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for COCPU_DISABLE_Register use
     record
       Reserved_0_30 at 0 range 0 .. 30;
       DISABLE_RTC_CPU at 0 range 31 .. 31;
     end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt28;

   --  version register
   type DATE_Register is record
      --  version register
      DATE           : DATE_DATE_Field := 16#2101271#;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DATE_Register use
     record
       DATE at 0 range 0 .. 27;
       Reserved_28_31 at 0 range 28 .. 31;
     end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Real-Time Clock Control
   type RTC_CNTL_Peripheral is record
      --  RTC common configure register
      OPTIONS0           : aliased OPTIONS0_Register;
      --  configure min sleep time
      SLP_TIMER0         : aliased ESP32S3_Registers.UInt32;
      --  configure sleep time hi
      SLP_TIMER1         : aliased SLP_TIMER1_Register;
      --  update rtc main timer
      TIME_UPDATE        : aliased TIME_UPDATE_Register;
      --  read rtc_main timer low bits
      TIME_LOW0          : aliased ESP32S3_Registers.UInt32;
      --  read rtc_main timer high bits
      TIME_HIGH0         : aliased TIME_HIGH0_Register;
      --  configure chip sleep
      STATE0             : aliased STATE0_Register;
      --  rtc state wait time
      TIMER1             : aliased TIMER1_Register;
      --  rtc monitor state delay time
      TIMER2             : aliased TIMER2_Register;
      --  No public
      TIMER3             : aliased TIMER3_Register;
      --  No public
      TIMER4             : aliased TIMER4_Register;
      --  configure min sleep time
      TIMER5             : aliased TIMER5_Register;
      --  No public
      TIMER6             : aliased TIMER6_Register;
      --  analog configure register
      ANA_CONF           : aliased ANA_CONF_Register;
      --  get reset state
      RESET_STATE        : aliased RESET_STATE_Register;
      --  configure wakeup state
      WAKEUP_STATE       : aliased WAKEUP_STATE_Register;
      --  configure rtc interrupt register
      INT_ENA_RTC        : aliased INT_ENA_RTC_Register;
      --  rtc interrupt register
      INT_RAW_RTC        : aliased INT_RAW_RTC_Register;
      --  rtc interrupt register
      INT_ST_RTC         : aliased INT_ST_RTC_Register;
      --  rtc interrupt register
      INT_CLR_RTC        : aliased INT_CLR_RTC_Register;
      --  Reserved register
      STORE0             : aliased ESP32S3_Registers.UInt32;
      --  Reserved register
      STORE1             : aliased ESP32S3_Registers.UInt32;
      --  Reserved register
      STORE2             : aliased ESP32S3_Registers.UInt32;
      --  Reserved register
      STORE3             : aliased ESP32S3_Registers.UInt32;
      --  Reserved register
      EXT_XTL_CONF       : aliased EXT_XTL_CONF_Register;
      --  ext wakeup configure
      EXT_WAKEUP_CONF    : aliased EXT_WAKEUP_CONF_Register;
      --  reject sleep register
      SLP_REJECT_CONF    : aliased SLP_REJECT_CONF_Register;
      --  conigure cpu freq
      CPU_PERIOD_CONF    : aliased CPU_PERIOD_CONF_Register;
      --  No public
      SDIO_ACT_CONF      : aliased SDIO_ACT_CONF_Register;
      --  configure clock register
      CLK_CONF           : aliased CLK_CONF_Register;
      --  configure slow clk
      SLOW_CLK_CONF      : aliased SLOW_CLK_CONF_Register;
      --  configure flash power
      SDIO_CONF          : aliased SDIO_CONF_Register;
      --  No public
      BIAS_CONF          : aliased BIAS_CONF_Register;
      --  configure rtc regulator
      RTC                : aliased RTC_Register;
      --  configure rtc power
      PWC                : aliased PWC_Register;
      --  No public
      REGULATOR_DRV_CTRL : aliased REGULATOR_DRV_CTRL_Register;
      --  configure digital power
      DIG_PWC            : aliased DIG_PWC_Register;
      --  congigure digital power isolation
      DIG_ISO            : aliased DIG_ISO_Register;
      --  configure rtc watch dog
      WDTCONFIG0         : aliased WDTCONFIG0_Register;
      --  stage0 hold time
      WDTCONFIG1         : aliased ESP32S3_Registers.UInt32;
      --  stage1 hold time
      WDTCONFIG2         : aliased ESP32S3_Registers.UInt32;
      --  stage2 hold time
      WDTCONFIG3         : aliased ESP32S3_Registers.UInt32;
      --  stage3 hold time
      WDTCONFIG4         : aliased ESP32S3_Registers.UInt32;
      --  rtc wdt feed
      WDTFEED            : aliased WDTFEED_Register;
      --  configure rtc watch dog
      WDTWPROTECT        : aliased ESP32S3_Registers.UInt32;
      --  congfigure super watch dog
      SWD_CONF           : aliased SWD_CONF_Register;
      --  super watch dog key
      SWD_WPROTECT       : aliased ESP32S3_Registers.UInt32;
      --  configure cpu stall by sw
      SW_CPU_STALL       : aliased SW_CPU_STALL_Register;
      --  reserved register
      STORE4             : aliased ESP32S3_Registers.UInt32;
      --  reserved register
      STORE5             : aliased ESP32S3_Registers.UInt32;
      --  reserved register
      STORE6             : aliased ESP32S3_Registers.UInt32;
      --  reserved register
      STORE7             : aliased ESP32S3_Registers.UInt32;
      --  reserved register
      LOW_POWER_ST       : aliased LOW_POWER_ST_Register;
      --  No public
      DIAG0              : aliased ESP32S3_Registers.UInt32;
      --  rtc pad hold configure
      PAD_HOLD           : aliased PAD_HOLD_Register;
      --  configure digtal pad hold
      DIG_PAD_HOLD       : aliased ESP32S3_Registers.UInt32;
      --  configure ext1 wakeup
      EXT_WAKEUP1        : aliased EXT_WAKEUP1_Register;
      --  check ext wakeup1 status
      EXT_WAKEUP1_STATUS : aliased EXT_WAKEUP1_STATUS_Register;
      --  congfigure brownout
      BROWN_OUT          : aliased BROWN_OUT_Register;
      --  RTC timer low 32 bits
      TIME_LOW1          : aliased ESP32S3_Registers.UInt32;
      --  RTC timer high 16 bits
      TIME_HIGH1         : aliased TIME_HIGH1_Register;
      --  xtal 32k watch dog backup clock factor
      XTAL32K_CLK_FACTOR : aliased ESP32S3_Registers.UInt32;
      --  configure xtal32k
      XTAL32K_CONF       : aliased XTAL32K_CONF_Register;
      --  configure ulp
      ULP_CP_TIMER       : aliased ULP_CP_TIMER_Register;
      --  configure ulp
      ULP_CP_CTRL        : aliased ULP_CP_CTRL_Register;
      --  configure ulp-riscv
      COCPU_CTRL         : aliased COCPU_CTRL_Register;
      --  configure touch controller
      TOUCH_CTRL1        : aliased TOUCH_CTRL1_Register;
      --  configure touch controller
      TOUCH_CTRL2        : aliased TOUCH_CTRL2_Register;
      --  configure touch controller
      TOUCH_SCAN_CTRL    : aliased TOUCH_SCAN_CTRL_Register;
      --  configure touch controller
      TOUCH_SLP_THRES    : aliased TOUCH_SLP_THRES_Register;
      --  configure touch controller
      TOUCH_APPROACH     : aliased TOUCH_APPROACH_Register;
      --  configure touch controller
      TOUCH_FILTER_CTRL  : aliased TOUCH_FILTER_CTRL_Register;
      --  usb configure
      USB_CONF           : aliased USB_CONF_Register;
      --  configure touch controller
      TOUCH_TIMEOUT_CTRL : aliased TOUCH_TIMEOUT_CTRL_Register;
      --  get reject casue
      SLP_REJECT_CAUSE   : aliased SLP_REJECT_CAUSE_Register;
      --  rtc common configure
      OPTION1            : aliased OPTION1_Register;
      --  get wakeup cause
      SLP_WAKEUP_CAUSE   : aliased SLP_WAKEUP_CAUSE_Register;
      --  configure ulp sleep time
      ULP_CP_TIMER_1     : aliased ULP_CP_TIMER_1_Register;
      --  oneset rtc interrupt
      INT_ENA_RTC_W1TS   : aliased INT_ENA_RTC_W1TS_Register;
      --  oneset clr rtc interrupt enable
      INT_ENA_RTC_W1TC   : aliased INT_ENA_RTC_W1TC_Register;
      --  configure retention
      RETENTION_CTRL     : aliased RETENTION_CTRL_Register;
      --  configure power glitch
      PG_CTRL            : aliased PG_CTRL_Register;
      --  No public
      FIB_SEL            : aliased FIB_SEL_Register;
      --  configure touch dac
      TOUCH_DAC          : aliased TOUCH_DAC_Register;
      --  configure touch dac
      TOUCH_DAC1         : aliased TOUCH_DAC1_Register;
      --  configure ulp diable
      COCPU_DISABLE      : aliased COCPU_DISABLE_Register;
      --  version register
      DATE               : aliased DATE_Register;
   end record
   with Volatile;

   for RTC_CNTL_Peripheral use
     record
       OPTIONS0 at 16#0# range 0 .. 31;
       SLP_TIMER0 at 16#4# range 0 .. 31;
       SLP_TIMER1 at 16#8# range 0 .. 31;
       TIME_UPDATE at 16#C# range 0 .. 31;
       TIME_LOW0 at 16#10# range 0 .. 31;
       TIME_HIGH0 at 16#14# range 0 .. 31;
       STATE0 at 16#18# range 0 .. 31;
       TIMER1 at 16#1C# range 0 .. 31;
       TIMER2 at 16#20# range 0 .. 31;
       TIMER3 at 16#24# range 0 .. 31;
       TIMER4 at 16#28# range 0 .. 31;
       TIMER5 at 16#2C# range 0 .. 31;
       TIMER6 at 16#30# range 0 .. 31;
       ANA_CONF at 16#34# range 0 .. 31;
       RESET_STATE at 16#38# range 0 .. 31;
       WAKEUP_STATE at 16#3C# range 0 .. 31;
       INT_ENA_RTC at 16#40# range 0 .. 31;
       INT_RAW_RTC at 16#44# range 0 .. 31;
       INT_ST_RTC at 16#48# range 0 .. 31;
       INT_CLR_RTC at 16#4C# range 0 .. 31;
       STORE0 at 16#50# range 0 .. 31;
       STORE1 at 16#54# range 0 .. 31;
       STORE2 at 16#58# range 0 .. 31;
       STORE3 at 16#5C# range 0 .. 31;
       EXT_XTL_CONF at 16#60# range 0 .. 31;
       EXT_WAKEUP_CONF at 16#64# range 0 .. 31;
       SLP_REJECT_CONF at 16#68# range 0 .. 31;
       CPU_PERIOD_CONF at 16#6C# range 0 .. 31;
       SDIO_ACT_CONF at 16#70# range 0 .. 31;
       CLK_CONF at 16#74# range 0 .. 31;
       SLOW_CLK_CONF at 16#78# range 0 .. 31;
       SDIO_CONF at 16#7C# range 0 .. 31;
       BIAS_CONF at 16#80# range 0 .. 31;
       RTC at 16#84# range 0 .. 31;
       PWC at 16#88# range 0 .. 31;
       REGULATOR_DRV_CTRL at 16#8C# range 0 .. 31;
       DIG_PWC at 16#90# range 0 .. 31;
       DIG_ISO at 16#94# range 0 .. 31;
       WDTCONFIG0 at 16#98# range 0 .. 31;
       WDTCONFIG1 at 16#9C# range 0 .. 31;
       WDTCONFIG2 at 16#A0# range 0 .. 31;
       WDTCONFIG3 at 16#A4# range 0 .. 31;
       WDTCONFIG4 at 16#A8# range 0 .. 31;
       WDTFEED at 16#AC# range 0 .. 31;
       WDTWPROTECT at 16#B0# range 0 .. 31;
       SWD_CONF at 16#B4# range 0 .. 31;
       SWD_WPROTECT at 16#B8# range 0 .. 31;
       SW_CPU_STALL at 16#BC# range 0 .. 31;
       STORE4 at 16#C0# range 0 .. 31;
       STORE5 at 16#C4# range 0 .. 31;
       STORE6 at 16#C8# range 0 .. 31;
       STORE7 at 16#CC# range 0 .. 31;
       LOW_POWER_ST at 16#D0# range 0 .. 31;
       DIAG0 at 16#D4# range 0 .. 31;
       PAD_HOLD at 16#D8# range 0 .. 31;
       DIG_PAD_HOLD at 16#DC# range 0 .. 31;
       EXT_WAKEUP1 at 16#E0# range 0 .. 31;
       EXT_WAKEUP1_STATUS at 16#E4# range 0 .. 31;
       BROWN_OUT at 16#E8# range 0 .. 31;
       TIME_LOW1 at 16#EC# range 0 .. 31;
       TIME_HIGH1 at 16#F0# range 0 .. 31;
       XTAL32K_CLK_FACTOR at 16#F4# range 0 .. 31;
       XTAL32K_CONF at 16#F8# range 0 .. 31;
       ULP_CP_TIMER at 16#FC# range 0 .. 31;
       ULP_CP_CTRL at 16#100# range 0 .. 31;
       COCPU_CTRL at 16#104# range 0 .. 31;
       TOUCH_CTRL1 at 16#108# range 0 .. 31;
       TOUCH_CTRL2 at 16#10C# range 0 .. 31;
       TOUCH_SCAN_CTRL at 16#110# range 0 .. 31;
       TOUCH_SLP_THRES at 16#114# range 0 .. 31;
       TOUCH_APPROACH at 16#118# range 0 .. 31;
       TOUCH_FILTER_CTRL at 16#11C# range 0 .. 31;
       USB_CONF at 16#120# range 0 .. 31;
       TOUCH_TIMEOUT_CTRL at 16#124# range 0 .. 31;
       SLP_REJECT_CAUSE at 16#128# range 0 .. 31;
       OPTION1 at 16#12C# range 0 .. 31;
       SLP_WAKEUP_CAUSE at 16#130# range 0 .. 31;
       ULP_CP_TIMER_1 at 16#134# range 0 .. 31;
       INT_ENA_RTC_W1TS at 16#138# range 0 .. 31;
       INT_ENA_RTC_W1TC at 16#13C# range 0 .. 31;
       RETENTION_CTRL at 16#140# range 0 .. 31;
       PG_CTRL at 16#144# range 0 .. 31;
       FIB_SEL at 16#148# range 0 .. 31;
       TOUCH_DAC at 16#14C# range 0 .. 31;
       TOUCH_DAC1 at 16#150# range 0 .. 31;
       COCPU_DISABLE at 16#154# range 0 .. 31;
       DATE at 16#1FC# range 0 .. 31;
     end record;

   --  Real-Time Clock Control
   RTC_CNTL_Periph : aliased RTC_CNTL_Peripheral
   with Import, Address => RTC_CNTL_Base, Volatile,
        Async_Readers    => True,
        Async_Writers    => True,
        Effective_Reads  => False,
        Effective_Writes => True;

end ESP32S3_Registers.RTC_CNTL;
