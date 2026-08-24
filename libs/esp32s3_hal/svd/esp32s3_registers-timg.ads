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

package ESP32S3_Registers.TIMG is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype TCONFIG_DIVIDER_Field is ESP32S3_Registers.UInt16;

   --  Timer %s configuration register
   type TCONFIG_Register is record
      --  unspecified
      Reserved_0_8   : ESP32S3_Registers.UInt9 := 16#0#;
      --  1: Use XTAL_CLK as the source clock of timer group. 0: Use APB_CLK as
      --  the source clock of timer group.
      USE_XTAL       : Boolean := False;
      --  When set, the alarm is enabled. This bit is automatically cleared
      --  once an alarm occurs.
      ALARM_EN       : Boolean := False;
      --  unspecified
      Reserved_11_12 : ESP32S3_Registers.UInt2 := 16#0#;
      --  Timer %s clock (T%s_clk) prescaler value.
      DIVIDER        : TCONFIG_DIVIDER_Field := 16#1#;
      --  When set, timer %s auto-reload at alarm is enabled.
      AUTORELOAD     : Boolean := True;
      --  When set, the timer %s time-base counter will increment every clock
      --  tick. When cleared, the timer %s time-base counter will decrement.
      INCREASE       : Boolean := True;
      --  When set, the timer %s time-base counter is enabled.
      EN             : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TCONFIG_Register use record
      Reserved_0_8   at 0 range 0 .. 8;
      USE_XTAL       at 0 range 9 .. 9;
      ALARM_EN       at 0 range 10 .. 10;
      Reserved_11_12 at 0 range 11 .. 12;
      DIVIDER        at 0 range 13 .. 28;
      AUTORELOAD     at 0 range 29 .. 29;
      INCREASE       at 0 range 30 .. 30;
      EN             at 0 range 31 .. 31;
   end record;

   subtype THI_HI_Field is ESP32S3_Registers.UInt22;

   --  Timer %s current value, high 22 bits
   type THI_Register is record
      --  Read-only. After writing to TIMG_T%sUPDATE_REG, the high 22 bits of
      --  the time-base counter of timer %s can be read here.
      HI             : THI_HI_Field;
      --  unspecified
      Reserved_22_31 : ESP32S3_Registers.UInt10;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for THI_Register use record
      HI             at 0 range 0 .. 21;
      Reserved_22_31 at 0 range 22 .. 31;
   end record;

   --  Write to copy current timer value to TIMGn_T%s_(LO/HI)_REG
   type TUPDATE_Register is record
      --  unspecified
      Reserved_0_30 : ESP32S3_Registers.UInt31 := 16#0#;
      --  After writing 0 or 1 to TIMG_T%sUPDATE_REG, the counter value is
      --  latched.
      UPDATE        : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TUPDATE_Register use record
      Reserved_0_30 at 0 range 0 .. 30;
      UPDATE        at 0 range 31 .. 31;
   end record;

   subtype TALARMHI_ALARM_HI_Field is ESP32S3_Registers.UInt22;

   --  Timer %s alarm value, high bits
   type TALARMHI_Register is record
      --  Timer %s alarm trigger time-base counter value, high 22 bits.
      ALARM_HI       : TALARMHI_ALARM_HI_Field := 16#0#;
      --  unspecified
      Reserved_22_31 : ESP32S3_Registers.UInt10 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TALARMHI_Register use record
      ALARM_HI       at 0 range 0 .. 21;
      Reserved_22_31 at 0 range 22 .. 31;
   end record;

   subtype TLOADHI_LOAD_HI_Field is ESP32S3_Registers.UInt22;

   --  Timer %s reload value, high 22 bits
   type TLOADHI_Register is record
      --  High 22 bits of the value that a reload will load onto timer %s
      --  time-base counter.
      LOAD_HI        : TLOADHI_LOAD_HI_Field := 16#0#;
      --  unspecified
      Reserved_22_31 : ESP32S3_Registers.UInt10 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TLOADHI_Register use record
      LOAD_HI        at 0 range 0 .. 21;
      Reserved_22_31 at 0 range 22 .. 31;
   end record;

   subtype WDTCONFIG0_WDT_SYS_RESET_LENGTH_Field is ESP32S3_Registers.UInt3;
   subtype WDTCONFIG0_WDT_CPU_RESET_LENGTH_Field is ESP32S3_Registers.UInt3;
   subtype WDTCONFIG0_WDT_STG3_Field is ESP32S3_Registers.UInt2;
   subtype WDTCONFIG0_WDT_STG2_Field is ESP32S3_Registers.UInt2;
   subtype WDTCONFIG0_WDT_STG1_Field is ESP32S3_Registers.UInt2;
   subtype WDTCONFIG0_WDT_STG0_Field is ESP32S3_Registers.UInt2;

   --  Watchdog timer configuration register
   type WDTCONFIG0_Register is record
      --  unspecified
      Reserved_0_11        : ESP32S3_Registers.UInt12 := 16#0#;
      --  Reserved
      WDT_APPCPU_RESET_EN  : Boolean := False;
      --  WDT reset CPU enable.
      WDT_PROCPU_RESET_EN  : Boolean := False;
      --  When set, Flash boot protection is enabled.
      WDT_FLASHBOOT_MOD_EN : Boolean := True;
      --  System reset signal length selection. 0: 100 ns, 1: 200 ns, 2: 300
      --  ns, 3: 400 ns, 4: 500 ns, 5: 800 ns, 6: 1.6 us, 7: 3.2 us.
      WDT_SYS_RESET_LENGTH : WDTCONFIG0_WDT_SYS_RESET_LENGTH_Field := 16#1#;
      --  CPU reset signal length selection. 0: 100 ns, 1: 200 ns, 2: 300 ns,
      --  3: 400 ns, 4: 500 ns, 5: 800 ns, 6: 1.6 us, 7: 3.2 us.
      WDT_CPU_RESET_LENGTH : WDTCONFIG0_WDT_CPU_RESET_LENGTH_Field := 16#1#;
      --  unspecified
      Reserved_21_22       : ESP32S3_Registers.UInt2 := 16#0#;
      --  Stage 3 configuration. 0: off, 1: interrupt, 2: reset CPU, 3: reset
      --  system.
      WDT_STG3             : WDTCONFIG0_WDT_STG3_Field := 16#0#;
      --  Stage 2 configuration. 0: off, 1: interrupt, 2: reset CPU, 3: reset
      --  system.
      WDT_STG2             : WDTCONFIG0_WDT_STG2_Field := 16#0#;
      --  Stage 1 configuration. 0: off, 1: interrupt, 2: reset CPU, 3: reset
      --  system.
      WDT_STG1             : WDTCONFIG0_WDT_STG1_Field := 16#0#;
      --  Stage 0 configuration. 0: off, 1: interrupt, 2: reset CPU, 3: reset
      --  system.
      WDT_STG0             : WDTCONFIG0_WDT_STG0_Field := 16#0#;
      --  When set, MWDT is enabled.
      WDT_EN               : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for WDTCONFIG0_Register use record
      Reserved_0_11        at 0 range 0 .. 11;
      WDT_APPCPU_RESET_EN  at 0 range 12 .. 12;
      WDT_PROCPU_RESET_EN  at 0 range 13 .. 13;
      WDT_FLASHBOOT_MOD_EN at 0 range 14 .. 14;
      WDT_SYS_RESET_LENGTH at 0 range 15 .. 17;
      WDT_CPU_RESET_LENGTH at 0 range 18 .. 20;
      Reserved_21_22       at 0 range 21 .. 22;
      WDT_STG3             at 0 range 23 .. 24;
      WDT_STG2             at 0 range 25 .. 26;
      WDT_STG1             at 0 range 27 .. 28;
      WDT_STG0             at 0 range 29 .. 30;
      WDT_EN               at 0 range 31 .. 31;
   end record;

   subtype WDTCONFIG1_WDT_CLK_PRESCALE_Field is ESP32S3_Registers.UInt16;

   --  Watchdog timer prescaler register
   type WDTCONFIG1_Register is record
      --  unspecified
      Reserved_0_15    : ESP32S3_Registers.UInt16 := 16#0#;
      --  MWDT clock prescaler value. MWDT clock period = 12.5 ns *
      --  TIMG_WDT_CLK_PRESCALE.
      WDT_CLK_PRESCALE : WDTCONFIG1_WDT_CLK_PRESCALE_Field := 16#1#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for WDTCONFIG1_Register use record
      Reserved_0_15    at 0 range 0 .. 15;
      WDT_CLK_PRESCALE at 0 range 16 .. 31;
   end record;

   subtype RTCCALICFG_RTC_CALI_CLK_SEL_Field is ESP32S3_Registers.UInt2;
   subtype RTCCALICFG_RTC_CALI_MAX_Field is ESP32S3_Registers.UInt15;

   --  RTC calibration configure register
   type RTCCALICFG_Register is record
      --  unspecified
      Reserved_0_11          : ESP32S3_Registers.UInt12 := 16#0#;
      --  Reserved
      RTC_CALI_START_CYCLING : Boolean := True;
      --  0:rtc slow clock. 1:clk_80m. 2:xtal_32k.
      RTC_CALI_CLK_SEL       : RTCCALICFG_RTC_CALI_CLK_SEL_Field := 16#1#;
      --  Read-only. Reserved
      RTC_CALI_RDY           : Boolean := False;
      --  Reserved
      RTC_CALI_MAX           : RTCCALICFG_RTC_CALI_MAX_Field := 16#1#;
      --  Reserved
      RTC_CALI_START         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RTCCALICFG_Register use record
      Reserved_0_11          at 0 range 0 .. 11;
      RTC_CALI_START_CYCLING at 0 range 12 .. 12;
      RTC_CALI_CLK_SEL       at 0 range 13 .. 14;
      RTC_CALI_RDY           at 0 range 15 .. 15;
      RTC_CALI_MAX           at 0 range 16 .. 30;
      RTC_CALI_START         at 0 range 31 .. 31;
   end record;

   subtype RTCCALICFG1_RTC_CALI_VALUE_Field is ESP32S3_Registers.UInt25;

   --  RTC calibration configure1 register
   type RTCCALICFG1_Register is record
      --  Read-only. Reserved
      RTC_CALI_CYCLING_DATA_VLD : Boolean;
      --  unspecified
      Reserved_1_6              : ESP32S3_Registers.UInt6;
      --  Read-only. Reserved
      RTC_CALI_VALUE            : RTCCALICFG1_RTC_CALI_VALUE_Field;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RTCCALICFG1_Register use record
      RTC_CALI_CYCLING_DATA_VLD at 0 range 0 .. 0;
      Reserved_1_6              at 0 range 1 .. 6;
      RTC_CALI_VALUE            at 0 range 7 .. 31;
   end record;

   --  Interrupt enable bits
   type INT_ENA_TIMERS_Register is record
      --  The interrupt enable bit for the TIMG_T0_INT interrupt.
      T0_INT_ENA    : Boolean := False;
      --  The interrupt enable bit for the TIMG_T1_INT interrupt.
      T1_INT_ENA    : Boolean := False;
      --  The interrupt enable bit for the TIMG_WDT_INT interrupt.
      WDT_INT_ENA   : Boolean := False;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_TIMERS_Register use record
      T0_INT_ENA    at 0 range 0 .. 0;
      T1_INT_ENA    at 0 range 1 .. 1;
      WDT_INT_ENA   at 0 range 2 .. 2;
      Reserved_3_31 at 0 range 3 .. 31;
   end record;

   --  Raw interrupt status
   type INT_RAW_TIMERS_Register is record
      --  The raw interrupt status bit for the TIMG_T0_INT interrupt.
      T0_INT_RAW    : Boolean := False;
      --  The raw interrupt status bit for the TIMG_T1_INT interrupt.
      T1_INT_RAW    : Boolean := False;
      --  The raw interrupt status bit for the TIMG_WDT_INT interrupt.
      WDT_INT_RAW   : Boolean := False;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_TIMERS_Register use record
      T0_INT_RAW    at 0 range 0 .. 0;
      T1_INT_RAW    at 0 range 1 .. 1;
      WDT_INT_RAW   at 0 range 2 .. 2;
      Reserved_3_31 at 0 range 3 .. 31;
   end record;

   --  Masked interrupt status
   type INT_ST_TIMERS_Register is record
      --  Read-only. The masked interrupt status bit for the TIMG_T0_INT
      --  interrupt.
      T0_INT_ST     : Boolean;
      --  Read-only. The masked interrupt status bit for the TIMG_T1_INT
      --  interrupt.
      T1_INT_ST     : Boolean;
      --  Read-only. The masked interrupt status bit for the TIMG_WDT_INT
      --  interrupt.
      WDT_INT_ST    : Boolean;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ST_TIMERS_Register use record
      T0_INT_ST     at 0 range 0 .. 0;
      T1_INT_ST     at 0 range 1 .. 1;
      WDT_INT_ST    at 0 range 2 .. 2;
      Reserved_3_31 at 0 range 3 .. 31;
   end record;

   --  Interrupt clear bits
   type INT_CLR_TIMERS_Register is record
      --  Write-only. Set this bit to clear the TIMG_T0_INT interrupt.
      T0_INT_CLR    : Boolean := False;
      --  Write-only. Set this bit to clear the TIMG_T1_INT interrupt.
      T1_INT_CLR    : Boolean := False;
      --  Write-only. Set this bit to clear the TIMG_WDT_INT interrupt.
      WDT_INT_CLR   : Boolean := False;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_TIMERS_Register use record
      T0_INT_CLR    at 0 range 0 .. 0;
      T1_INT_CLR    at 0 range 1 .. 1;
      WDT_INT_CLR   at 0 range 2 .. 2;
      Reserved_3_31 at 0 range 3 .. 31;
   end record;

   subtype RTCCALICFG2_RTC_CALI_TIMEOUT_RST_CNT_Field is
     ESP32S3_Registers.UInt4;
   subtype RTCCALICFG2_RTC_CALI_TIMEOUT_THRES_Field is
     ESP32S3_Registers.UInt25;

   --  Timer group calibration register
   type RTCCALICFG2_Register is record
      --  Read-only. RTC calibration timeout indicator
      RTC_CALI_TIMEOUT         : Boolean := False;
      --  unspecified
      Reserved_1_2             : ESP32S3_Registers.UInt2 := 16#0#;
      --  Cycles that release calibration timeout reset
      RTC_CALI_TIMEOUT_RST_CNT : RTCCALICFG2_RTC_CALI_TIMEOUT_RST_CNT_Field :=
                                  16#3#;
      --  Threshold value for the RTC calibration timer. If the calibration
      --  timer's value exceeds this threshold, a timeout is triggered.
      RTC_CALI_TIMEOUT_THRES   : RTCCALICFG2_RTC_CALI_TIMEOUT_THRES_Field :=
                                  16#1FFFFFF#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RTCCALICFG2_Register use record
      RTC_CALI_TIMEOUT         at 0 range 0 .. 0;
      Reserved_1_2             at 0 range 1 .. 2;
      RTC_CALI_TIMEOUT_RST_CNT at 0 range 3 .. 6;
      RTC_CALI_TIMEOUT_THRES   at 0 range 7 .. 31;
   end record;

   subtype NTIMERS_DATE_NTIMERS_DATE_Field is ESP32S3_Registers.UInt28;

   --  Timer version control register
   type NTIMERS_DATE_Register is record
      --  Timer version control register
      NTIMERS_DATE   : NTIMERS_DATE_NTIMERS_DATE_Field := 16#2003071#;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for NTIMERS_DATE_Register use record
      NTIMERS_DATE   at 0 range 0 .. 27;
      Reserved_28_31 at 0 range 28 .. 31;
   end record;

   --  Timer group clock gate register
   type REGCLK_Register is record
      --  unspecified
      Reserved_0_30 : ESP32S3_Registers.UInt31 := 16#0#;
      --  Register clock gate signal. 1: The clock for software to read and
      --  write registers is always on. 0: The clock for software to read and
      --  write registers only exits when the operation happens.
      CLK_EN        : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for REGCLK_Register use record
      Reserved_0_30 at 0 range 0 .. 30;
      CLK_EN        at 0 range 31 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Timer Group 0
   type TIMG_Peripheral is record
      --  Timer %s configuration register
      TCONFIG0       : aliased TCONFIG_Register;
      --  Timer %s current value, low 32 bits
      TLO0           : aliased ESP32S3_Registers.UInt32;
      --  Timer %s current value, high 22 bits
      THI0           : aliased THI_Register;
      --  Write to copy current timer value to TIMGn_T%s_(LO/HI)_REG
      TUPDATE0       : aliased TUPDATE_Register;
      --  Timer %s alarm value, low 32 bits
      TALARMLO0      : aliased ESP32S3_Registers.UInt32;
      --  Timer %s alarm value, high bits
      TALARMHI0      : aliased TALARMHI_Register;
      --  Timer %s reload value, low 32 bits
      TLOADLO0       : aliased ESP32S3_Registers.UInt32;
      --  Timer %s reload value, high 22 bits
      TLOADHI0       : aliased TLOADHI_Register;
      --  Write to reload timer from TIMG_T%s_(LOADLOLOADHI)_REG
      TLOAD0         : aliased ESP32S3_Registers.UInt32;
      --  Timer %s configuration register
      TCONFIG1       : aliased TCONFIG_Register;
      --  Timer %s current value, low 32 bits
      TLO1           : aliased ESP32S3_Registers.UInt32;
      --  Timer %s current value, high 22 bits
      THI1           : aliased THI_Register;
      --  Write to copy current timer value to TIMGn_T%s_(LO/HI)_REG
      TUPDATE1       : aliased TUPDATE_Register;
      --  Timer %s alarm value, low 32 bits
      TALARMLO1      : aliased ESP32S3_Registers.UInt32;
      --  Timer %s alarm value, high bits
      TALARMHI1      : aliased TALARMHI_Register;
      --  Timer %s reload value, low 32 bits
      TLOADLO1       : aliased ESP32S3_Registers.UInt32;
      --  Timer %s reload value, high 22 bits
      TLOADHI1       : aliased TLOADHI_Register;
      --  Write to reload timer from TIMG_T%s_(LOADLOLOADHI)_REG
      TLOAD1         : aliased ESP32S3_Registers.UInt32;
      --  Watchdog timer configuration register
      WDTCONFIG0     : aliased WDTCONFIG0_Register;
      --  Watchdog timer prescaler register
      WDTCONFIG1     : aliased WDTCONFIG1_Register;
      --  Watchdog timer stage 0 timeout value
      WDTCONFIG2     : aliased ESP32S3_Registers.UInt32;
      --  Watchdog timer stage 1 timeout value
      WDTCONFIG3     : aliased ESP32S3_Registers.UInt32;
      --  Watchdog timer stage 2 timeout value
      WDTCONFIG4     : aliased ESP32S3_Registers.UInt32;
      --  Watchdog timer stage 3 timeout value
      WDTCONFIG5     : aliased ESP32S3_Registers.UInt32;
      --  Write to feed the watchdog timer
      WDTFEED        : aliased ESP32S3_Registers.UInt32;
      --  Watchdog write protect register
      WDTWPROTECT    : aliased ESP32S3_Registers.UInt32;
      --  RTC calibration configure register
      RTCCALICFG     : aliased RTCCALICFG_Register;
      --  RTC calibration configure1 register
      RTCCALICFG1    : aliased RTCCALICFG1_Register;
      --  Interrupt enable bits
      INT_ENA_TIMERS : aliased INT_ENA_TIMERS_Register;
      --  Raw interrupt status
      INT_RAW_TIMERS : aliased INT_RAW_TIMERS_Register;
      --  Masked interrupt status
      INT_ST_TIMERS  : aliased INT_ST_TIMERS_Register;
      --  Interrupt clear bits
      INT_CLR_TIMERS : aliased INT_CLR_TIMERS_Register;
      --  Timer group calibration register
      RTCCALICFG2    : aliased RTCCALICFG2_Register;
      --  Timer version control register
      NTIMERS_DATE   : aliased NTIMERS_DATE_Register;
      --  Timer group clock gate register
      REGCLK         : aliased REGCLK_Register;
   end record
     with Volatile;

   for TIMG_Peripheral use record
      TCONFIG0       at 16#0# range 0 .. 31;
      TLO0           at 16#4# range 0 .. 31;
      THI0           at 16#8# range 0 .. 31;
      TUPDATE0       at 16#C# range 0 .. 31;
      TALARMLO0      at 16#10# range 0 .. 31;
      TALARMHI0      at 16#14# range 0 .. 31;
      TLOADLO0       at 16#18# range 0 .. 31;
      TLOADHI0       at 16#1C# range 0 .. 31;
      TLOAD0         at 16#20# range 0 .. 31;
      TCONFIG1       at 16#24# range 0 .. 31;
      TLO1           at 16#28# range 0 .. 31;
      THI1           at 16#2C# range 0 .. 31;
      TUPDATE1       at 16#30# range 0 .. 31;
      TALARMLO1      at 16#34# range 0 .. 31;
      TALARMHI1      at 16#38# range 0 .. 31;
      TLOADLO1       at 16#3C# range 0 .. 31;
      TLOADHI1       at 16#40# range 0 .. 31;
      TLOAD1         at 16#44# range 0 .. 31;
      WDTCONFIG0     at 16#48# range 0 .. 31;
      WDTCONFIG1     at 16#4C# range 0 .. 31;
      WDTCONFIG2     at 16#50# range 0 .. 31;
      WDTCONFIG3     at 16#54# range 0 .. 31;
      WDTCONFIG4     at 16#58# range 0 .. 31;
      WDTCONFIG5     at 16#5C# range 0 .. 31;
      WDTFEED        at 16#60# range 0 .. 31;
      WDTWPROTECT    at 16#64# range 0 .. 31;
      RTCCALICFG     at 16#68# range 0 .. 31;
      RTCCALICFG1    at 16#6C# range 0 .. 31;
      INT_ENA_TIMERS at 16#70# range 0 .. 31;
      INT_RAW_TIMERS at 16#74# range 0 .. 31;
      INT_ST_TIMERS  at 16#78# range 0 .. 31;
      INT_CLR_TIMERS at 16#7C# range 0 .. 31;
      RTCCALICFG2    at 16#80# range 0 .. 31;
      NTIMERS_DATE   at 16#F8# range 0 .. 31;
      REGCLK         at 16#FC# range 0 .. 31;
   end record;

   --  Timer Group 0
   TIMG0_Periph : aliased TIMG_Peripheral
     with Import, Address => TIMG0_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

   --  Timer Group 1
   TIMG1_Periph : aliased TIMG_Peripheral
     with Import, Address => TIMG1_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.TIMG;
