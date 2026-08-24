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

package ESP32S3_Registers.APB_SARADC is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype CTRL_SARADC_WORK_MODE_Field is ESP32S3_Registers.UInt2;
   subtype CTRL_SARADC_SAR_CLK_DIV_Field is ESP32S3_Registers.Byte;
   subtype CTRL_SARADC_SAR1_PATT_LEN_Field is ESP32S3_Registers.UInt4;
   subtype CTRL_SARADC_SAR2_PATT_LEN_Field is ESP32S3_Registers.UInt4;
   subtype CTRL_SARADC_XPD_SAR_FORCE_Field is ESP32S3_Registers.UInt2;
   subtype CTRL_SARADC_WAIT_ARB_CYCLE_Field is ESP32S3_Registers.UInt2;

   --  configure apb saradc controller
   type CTRL_Register is record
      --  enable start saradc by sw
      SARADC_START_FORCE       : Boolean := False;
      --  start saradc by sw
      SARADC_START             : Boolean := False;
      --  unspecified
      Reserved_2_2             : ESP32S3_Registers.Bit := 16#0#;
      --  0: single mode, 1: double mode, 2: alternate mode
      SARADC_WORK_MODE         : CTRL_SARADC_WORK_MODE_Field := 16#0#;
      --  0: SAR1, 1: SAR2, only work for single SAR mode
      SARADC_SAR_SEL           : Boolean := False;
      --  enable SAR CLK gate when saradc idle
      SARADC_SAR_CLK_GATED     : Boolean := True;
      --  SAR clock divider
      SARADC_SAR_CLK_DIV       : CTRL_SARADC_SAR_CLK_DIV_Field := 16#4#;
      --  0 ~ 15 means length 1 ~ 16
      SARADC_SAR1_PATT_LEN     : CTRL_SARADC_SAR1_PATT_LEN_Field := 16#F#;
      --  0 ~ 15 means length 1 ~ 16
      SARADC_SAR2_PATT_LEN     : CTRL_SARADC_SAR2_PATT_LEN_Field := 16#F#;
      --  clear the pointer of pattern table for DIG ADC1 CTRL
      SARADC_SAR1_PATT_P_CLEAR : Boolean := False;
      --  clear the pointer of pattern table for DIG ADC2 CTRL
      SARADC_SAR2_PATT_P_CLEAR : Boolean := False;
      --  1: sar_sel will be coded by the MSB of the 16-bit output data, in
      --  this case the resolution should not be larger than 11 bits.
      SARADC_DATA_SAR_SEL      : Boolean := False;
      --  1: I2S input data is from SAR ADC (for DMA), 0: I2S input data is
      --  from GPIO matrix
      SARADC_DATA_TO_I2S       : Boolean := False;
      --  force option to xpd sar blocks
      SARADC_XPD_SAR_FORCE     : CTRL_SARADC_XPD_SAR_FORCE_Field := 16#0#;
      --  unspecified
      Reserved_29_29           : ESP32S3_Registers.Bit := 16#0#;
      --  wait arbit signal stable after sar_done
      SARADC_WAIT_ARB_CYCLE    : CTRL_SARADC_WAIT_ARB_CYCLE_Field := 16#1#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CTRL_Register use
     record
       SARADC_START_FORCE at 0 range 0 .. 0;
       SARADC_START at 0 range 1 .. 1;
       Reserved_2_2 at 0 range 2 .. 2;
       SARADC_WORK_MODE at 0 range 3 .. 4;
       SARADC_SAR_SEL at 0 range 5 .. 5;
       SARADC_SAR_CLK_GATED at 0 range 6 .. 6;
       SARADC_SAR_CLK_DIV at 0 range 7 .. 14;
       SARADC_SAR1_PATT_LEN at 0 range 15 .. 18;
       SARADC_SAR2_PATT_LEN at 0 range 19 .. 22;
       SARADC_SAR1_PATT_P_CLEAR at 0 range 23 .. 23;
       SARADC_SAR2_PATT_P_CLEAR at 0 range 24 .. 24;
       SARADC_DATA_SAR_SEL at 0 range 25 .. 25;
       SARADC_DATA_TO_I2S at 0 range 26 .. 26;
       SARADC_XPD_SAR_FORCE at 0 range 27 .. 28;
       Reserved_29_29 at 0 range 29 .. 29;
       SARADC_WAIT_ARB_CYCLE at 0 range 30 .. 31;
     end record;

   subtype CTRL2_SARADC_MAX_MEAS_NUM_Field is ESP32S3_Registers.Byte;
   subtype CTRL2_SARADC_TIMER_TARGET_Field is ESP32S3_Registers.UInt12;

   --  configure apb saradc controller
   type CTRL2_Register is record
      --  enable apb saradc limit the sample num
      SARADC_MEAS_NUM_LIMIT : Boolean := False;
      --  max conversion number
      SARADC_MAX_MEAS_NUM   : CTRL2_SARADC_MAX_MEAS_NUM_Field := 16#FF#;
      --  1: data to DIG ADC1 CTRL is inverted, otherwise not
      SARADC_SAR1_INV       : Boolean := False;
      --  1: data to DIG ADC2 CTRL is inverted, otherwise not
      SARADC_SAR2_INV       : Boolean := False;
      --  1: select saradc timer 0: i2s_ws trigger
      SARADC_TIMER_SEL      : Boolean := False;
      --  to set saradc timer target
      SARADC_TIMER_TARGET   : CTRL2_SARADC_TIMER_TARGET_Field := 16#A#;
      --  to enable saradc timer trigger
      SARADC_TIMER_EN       : Boolean := False;
      --  unspecified
      Reserved_25_31        : ESP32S3_Registers.UInt7 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CTRL2_Register use
     record
       SARADC_MEAS_NUM_LIMIT at 0 range 0 .. 0;
       SARADC_MAX_MEAS_NUM at 0 range 1 .. 8;
       SARADC_SAR1_INV at 0 range 9 .. 9;
       SARADC_SAR2_INV at 0 range 10 .. 10;
       SARADC_TIMER_SEL at 0 range 11 .. 11;
       SARADC_TIMER_TARGET at 0 range 12 .. 23;
       SARADC_TIMER_EN at 0 range 24 .. 24;
       Reserved_25_31 at 0 range 25 .. 31;
     end record;

   subtype FILTER_CTRL1_FILTER_FACTOR1_Field is ESP32S3_Registers.UInt3;
   subtype FILTER_CTRL1_FILTER_FACTOR0_Field is ESP32S3_Registers.UInt3;

   --  configure saradc filter
   type FILTER_CTRL1_Register is record
      --  unspecified
      Reserved_0_25  : ESP32S3_Registers.UInt26 := 16#0#;
      --  apb saradc factor1
      FILTER_FACTOR1 : FILTER_CTRL1_FILTER_FACTOR1_Field := 16#0#;
      --  apb saradc factor0
      FILTER_FACTOR0 : FILTER_CTRL1_FILTER_FACTOR0_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for FILTER_CTRL1_Register use
     record
       Reserved_0_25 at 0 range 0 .. 25;
       FILTER_FACTOR1 at 0 range 26 .. 28;
       FILTER_FACTOR0 at 0 range 29 .. 31;
     end record;

   subtype FSM_WAIT_SARADC_XPD_WAIT_Field is ESP32S3_Registers.Byte;
   subtype FSM_WAIT_SARADC_RSTB_WAIT_Field is ESP32S3_Registers.Byte;
   subtype FSM_WAIT_SARADC_STANDBY_WAIT_Field is ESP32S3_Registers.Byte;

   --  configure apb saradc fsm
   type FSM_WAIT_Register is record
      --  the cycle which saradc controller in xpd state
      SARADC_XPD_WAIT     : FSM_WAIT_SARADC_XPD_WAIT_Field := 16#8#;
      --  the cycle which saradc controller in rst state
      SARADC_RSTB_WAIT    : FSM_WAIT_SARADC_RSTB_WAIT_Field := 16#8#;
      --  the cycle which saradc controller in standby state
      SARADC_STANDBY_WAIT : FSM_WAIT_SARADC_STANDBY_WAIT_Field := 16#FF#;
      --  unspecified
      Reserved_24_31      : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for FSM_WAIT_Register use
     record
       SARADC_XPD_WAIT at 0 range 0 .. 7;
       SARADC_RSTB_WAIT at 0 range 8 .. 15;
       SARADC_STANDBY_WAIT at 0 range 16 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype SAR1_PATT_TAB1_SARADC_SAR1_PATT_TAB1_Field is
     ESP32S3_Registers.UInt24;

   --  configure apb saradc pattern table
   type SAR1_PATT_TAB1_Register is record
      --  item 0 ~ 3 for pattern table 1 (each item 6bit)
      SARADC_SAR1_PATT_TAB1 : SAR1_PATT_TAB1_SARADC_SAR1_PATT_TAB1_Field :=
        16#0#;
      --  unspecified
      Reserved_24_31        : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR1_PATT_TAB1_Register use
     record
       SARADC_SAR1_PATT_TAB1 at 0 range 0 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype SAR1_PATT_TAB2_SARADC_SAR1_PATT_TAB2_Field is
     ESP32S3_Registers.UInt24;

   --  configure apb saradc pattern table
   type SAR1_PATT_TAB2_Register is record
      --  Item 4 ~ 7 for pattern table 1 (each item 6bit)
      SARADC_SAR1_PATT_TAB2 : SAR1_PATT_TAB2_SARADC_SAR1_PATT_TAB2_Field :=
        16#0#;
      --  unspecified
      Reserved_24_31        : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR1_PATT_TAB2_Register use
     record
       SARADC_SAR1_PATT_TAB2 at 0 range 0 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype SAR1_PATT_TAB3_SARADC_SAR1_PATT_TAB3_Field is
     ESP32S3_Registers.UInt24;

   --  configure apb saradc pattern table
   type SAR1_PATT_TAB3_Register is record
      --  Item 8 ~ 11 for pattern table 1 (each item 6bit)
      SARADC_SAR1_PATT_TAB3 : SAR1_PATT_TAB3_SARADC_SAR1_PATT_TAB3_Field :=
        16#0#;
      --  unspecified
      Reserved_24_31        : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR1_PATT_TAB3_Register use
     record
       SARADC_SAR1_PATT_TAB3 at 0 range 0 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype SAR1_PATT_TAB4_SARADC_SAR1_PATT_TAB4_Field is
     ESP32S3_Registers.UInt24;

   --  configure apb saradc pattern table
   type SAR1_PATT_TAB4_Register is record
      --  Item 12 ~ 15 for pattern table 1 (each item 6bit)
      SARADC_SAR1_PATT_TAB4 : SAR1_PATT_TAB4_SARADC_SAR1_PATT_TAB4_Field :=
        16#0#;
      --  unspecified
      Reserved_24_31        : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR1_PATT_TAB4_Register use
     record
       SARADC_SAR1_PATT_TAB4 at 0 range 0 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype SAR2_PATT_TAB1_SARADC_SAR2_PATT_TAB1_Field is
     ESP32S3_Registers.UInt24;

   --  configure apb saradc pattern table
   type SAR2_PATT_TAB1_Register is record
      --  item 0 ~ 3 for pattern table 2 (each item 6bit)
      SARADC_SAR2_PATT_TAB1 : SAR2_PATT_TAB1_SARADC_SAR2_PATT_TAB1_Field :=
        16#0#;
      --  unspecified
      Reserved_24_31        : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR2_PATT_TAB1_Register use
     record
       SARADC_SAR2_PATT_TAB1 at 0 range 0 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype SAR2_PATT_TAB2_SARADC_SAR2_PATT_TAB2_Field is
     ESP32S3_Registers.UInt24;

   --  configure apb saradc pattern table
   type SAR2_PATT_TAB2_Register is record
      --  Item 4 ~ 7 for pattern table 2 (each item 6bit)
      SARADC_SAR2_PATT_TAB2 : SAR2_PATT_TAB2_SARADC_SAR2_PATT_TAB2_Field :=
        16#0#;
      --  unspecified
      Reserved_24_31        : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR2_PATT_TAB2_Register use
     record
       SARADC_SAR2_PATT_TAB2 at 0 range 0 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype SAR2_PATT_TAB3_SARADC_SAR2_PATT_TAB3_Field is
     ESP32S3_Registers.UInt24;

   --  configure apb saradc pattern table
   type SAR2_PATT_TAB3_Register is record
      --  Item 8 ~ 11 for pattern table 2 (each item 6bit)
      SARADC_SAR2_PATT_TAB3 : SAR2_PATT_TAB3_SARADC_SAR2_PATT_TAB3_Field :=
        16#0#;
      --  unspecified
      Reserved_24_31        : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR2_PATT_TAB3_Register use
     record
       SARADC_SAR2_PATT_TAB3 at 0 range 0 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype SAR2_PATT_TAB4_SARADC_SAR2_PATT_TAB4_Field is
     ESP32S3_Registers.UInt24;

   --  configure apb saradc pattern table
   type SAR2_PATT_TAB4_Register is record
      --  Item 12 ~ 15 for pattern table 2 (each item 6bit)
      SARADC_SAR2_PATT_TAB4 : SAR2_PATT_TAB4_SARADC_SAR2_PATT_TAB4_Field :=
        16#0#;
      --  unspecified
      Reserved_24_31        : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR2_PATT_TAB4_Register use
     record
       SARADC_SAR2_PATT_TAB4 at 0 range 0 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype ARB_CTRL_ADC_ARB_APB_PRIORITY_Field is ESP32S3_Registers.UInt2;
   subtype ARB_CTRL_ADC_ARB_RTC_PRIORITY_Field is ESP32S3_Registers.UInt2;
   subtype ARB_CTRL_ADC_ARB_WIFI_PRIORITY_Field is ESP32S3_Registers.UInt2;

   --  configure apb saradc arbit
   type ARB_CTRL_Register is record
      --  unspecified
      Reserved_0_1          : ESP32S3_Registers.UInt2 := 16#0#;
      --  adc2 arbiter force to enableapb controller
      ADC_ARB_APB_FORCE     : Boolean := False;
      --  adc2 arbiter force to enable rtc controller
      ADC_ARB_RTC_FORCE     : Boolean := False;
      --  adc2 arbiter force to enable wifi controller
      ADC_ARB_WIFI_FORCE    : Boolean := False;
      --  adc2 arbiter force grant
      ADC_ARB_GRANT_FORCE   : Boolean := False;
      --  Set adc2 arbiterapb priority
      ADC_ARB_APB_PRIORITY  : ARB_CTRL_ADC_ARB_APB_PRIORITY_Field := 16#0#;
      --  Set adc2 arbiter rtc priority
      ADC_ARB_RTC_PRIORITY  : ARB_CTRL_ADC_ARB_RTC_PRIORITY_Field := 16#1#;
      --  Set adc2 arbiter wifi priority
      ADC_ARB_WIFI_PRIORITY : ARB_CTRL_ADC_ARB_WIFI_PRIORITY_Field := 16#2#;
      --  adc2 arbiter uses fixed priority
      ADC_ARB_FIX_PRIORITY  : Boolean := False;
      --  unspecified
      Reserved_13_31        : ESP32S3_Registers.UInt19 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ARB_CTRL_Register use
     record
       Reserved_0_1 at 0 range 0 .. 1;
       ADC_ARB_APB_FORCE at 0 range 2 .. 2;
       ADC_ARB_RTC_FORCE at 0 range 3 .. 3;
       ADC_ARB_WIFI_FORCE at 0 range 4 .. 4;
       ADC_ARB_GRANT_FORCE at 0 range 5 .. 5;
       ADC_ARB_APB_PRIORITY at 0 range 6 .. 7;
       ADC_ARB_RTC_PRIORITY at 0 range 8 .. 9;
       ADC_ARB_WIFI_PRIORITY at 0 range 10 .. 11;
       ADC_ARB_FIX_PRIORITY at 0 range 12 .. 12;
       Reserved_13_31 at 0 range 13 .. 31;
     end record;

   subtype FILTER_CTRL0_FILTER_CHANNEL1_Field is ESP32S3_Registers.UInt5;
   subtype FILTER_CTRL0_FILTER_CHANNEL0_Field is ESP32S3_Registers.UInt5;

   --  configure apb saradc arbit
   type FILTER_CTRL0_Register is record
      --  unspecified
      Reserved_0_13   : ESP32S3_Registers.UInt14 := 16#0#;
      --  configure the filter1 channel
      FILTER_CHANNEL1 : FILTER_CTRL0_FILTER_CHANNEL1_Field := 16#D#;
      --  configure the filter0 channel
      FILTER_CHANNEL0 : FILTER_CTRL0_FILTER_CHANNEL0_Field := 16#D#;
      --  unspecified
      Reserved_24_30  : ESP32S3_Registers.UInt7 := 16#0#;
      --  enable apb_adc1_filter
      FILTER_RESET    : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for FILTER_CTRL0_Register use
     record
       Reserved_0_13 at 0 range 0 .. 13;
       FILTER_CHANNEL1 at 0 range 14 .. 18;
       FILTER_CHANNEL0 at 0 range 19 .. 23;
       Reserved_24_30 at 0 range 24 .. 30;
       FILTER_RESET at 0 range 31 .. 31;
     end record;

   subtype APB_SARADC1_DATA_STATUS_APB_SARADC1_DATA_Field is
     ESP32S3_Registers.UInt17;

   --  get apb saradc sample data
   type APB_SARADC1_DATA_STATUS_Register is record
      --  Read-only. apbsaradc sample data
      APB_SARADC1_DATA : APB_SARADC1_DATA_STATUS_APB_SARADC1_DATA_Field;
      --  unspecified
      Reserved_17_31   : ESP32S3_Registers.UInt15;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for APB_SARADC1_DATA_STATUS_Register use
     record
       APB_SARADC1_DATA at 0 range 0 .. 16;
       Reserved_17_31 at 0 range 17 .. 31;
     end record;

   subtype THRES0_CTRL_THRES0_CHANNEL_Field is ESP32S3_Registers.UInt5;
   subtype THRES0_CTRL_THRES0_HIGH_Field is ESP32S3_Registers.UInt13;
   subtype THRES0_CTRL_THRES0_LOW_Field is ESP32S3_Registers.UInt13;

   --  configure apb saradc thres monitor
   type THRES0_CTRL_Register is record
      --  configure which channel thres0 monitor
      THRES0_CHANNEL : THRES0_CTRL_THRES0_CHANNEL_Field := 16#D#;
      --  thres0 monitor high thres
      THRES0_HIGH    : THRES0_CTRL_THRES0_HIGH_Field := 16#1FFF#;
      --  thres0 monitor low thres
      THRES0_LOW     : THRES0_CTRL_THRES0_LOW_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for THRES0_CTRL_Register use
     record
       THRES0_CHANNEL at 0 range 0 .. 4;
       THRES0_HIGH at 0 range 5 .. 17;
       THRES0_LOW at 0 range 18 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   subtype THRES1_CTRL_THRES1_CHANNEL_Field is ESP32S3_Registers.UInt5;
   subtype THRES1_CTRL_THRES1_HIGH_Field is ESP32S3_Registers.UInt13;
   subtype THRES1_CTRL_THRES1_LOW_Field is ESP32S3_Registers.UInt13;

   --  configure apb saradc thres monitor
   type THRES1_CTRL_Register is record
      --  configure which channel thres0 monitor
      THRES1_CHANNEL : THRES1_CTRL_THRES1_CHANNEL_Field := 16#D#;
      --  thres1 monitor high thres
      THRES1_HIGH    : THRES1_CTRL_THRES1_HIGH_Field := 16#1FFF#;
      --  thres1 monitor low thres
      THRES1_LOW     : THRES1_CTRL_THRES1_LOW_Field := 16#0#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for THRES1_CTRL_Register use
     record
       THRES1_CHANNEL at 0 range 0 .. 4;
       THRES1_HIGH at 0 range 5 .. 17;
       THRES1_LOW at 0 range 18 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   --  configure thres monitor enable
   type THRES_CTRL_Register is record
      --  unspecified
      Reserved_0_26 : ESP32S3_Registers.UInt27 := 16#0#;
      --  enable thres0 to monitor all channel
      THRES_ALL_EN  : Boolean := False;
      --  no public
      THRES3_EN     : Boolean := False;
      --  no public
      THRES2_EN     : Boolean := False;
      --  enable thres1
      THRES1_EN     : Boolean := False;
      --  enable thres0
      THRES0_EN     : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for THRES_CTRL_Register use
     record
       Reserved_0_26 at 0 range 0 .. 26;
       THRES_ALL_EN at 0 range 27 .. 27;
       THRES3_EN at 0 range 28 .. 28;
       THRES2_EN at 0 range 29 .. 29;
       THRES1_EN at 0 range 30 .. 30;
       THRES0_EN at 0 range 31 .. 31;
     end record;

   --  enable interrupt
   type INT_ENA_Register is record
      --  unspecified
      Reserved_0_25            : ESP32S3_Registers.UInt26 := 16#0#;
      --  interrupt of thres1 low
      THRES1_LOW_INT_ENA       : Boolean := False;
      --  interrupt of thres0 low
      THRES0_LOW_INT_ENA       : Boolean := False;
      --  interrupt of thres1 high
      THRES1_HIGH_INT_ENA      : Boolean := False;
      --  interrupt of thres0 high
      THRES0_HIGH_INT_ENA      : Boolean := False;
      --  interrupt of sar2 done
      APB_SARADC2_DONE_INT_ENA : Boolean := False;
      --  interrupt of sar1 done
      APB_SARADC1_DONE_INT_ENA : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ENA_Register use
     record
       Reserved_0_25 at 0 range 0 .. 25;
       THRES1_LOW_INT_ENA at 0 range 26 .. 26;
       THRES0_LOW_INT_ENA at 0 range 27 .. 27;
       THRES1_HIGH_INT_ENA at 0 range 28 .. 28;
       THRES0_HIGH_INT_ENA at 0 range 29 .. 29;
       APB_SARADC2_DONE_INT_ENA at 0 range 30 .. 30;
       APB_SARADC1_DONE_INT_ENA at 0 range 31 .. 31;
     end record;

   --  raw of interrupt
   type INT_RAW_Register is record
      --  unspecified
      Reserved_0_25            : ESP32S3_Registers.UInt26;
      --  Read-only. interrupt of thres1 low
      THRES1_LOW_INT_RAW       : Boolean;
      --  Read-only. interrupt of thres0 low
      THRES0_LOW_INT_RAW       : Boolean;
      --  Read-only. interrupt of thres1 high
      THRES1_HIGH_INT_RAW      : Boolean;
      --  Read-only. interrupt of thres0 high
      THRES0_HIGH_INT_RAW      : Boolean;
      --  Read-only. interrupt of sar2 done
      APB_SARADC2_DONE_INT_RAW : Boolean;
      --  Read-only. interrupt of sar1 done
      APB_SARADC1_DONE_INT_RAW : Boolean;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_RAW_Register use
     record
       Reserved_0_25 at 0 range 0 .. 25;
       THRES1_LOW_INT_RAW at 0 range 26 .. 26;
       THRES0_LOW_INT_RAW at 0 range 27 .. 27;
       THRES1_HIGH_INT_RAW at 0 range 28 .. 28;
       THRES0_HIGH_INT_RAW at 0 range 29 .. 29;
       APB_SARADC2_DONE_INT_RAW at 0 range 30 .. 30;
       APB_SARADC1_DONE_INT_RAW at 0 range 31 .. 31;
     end record;

   --  state of interrupt
   type INT_ST_Register is record
      --  unspecified
      Reserved_0_25           : ESP32S3_Registers.UInt26;
      --  Read-only. interrupt of thres1 low
      THRES1_LOW_INT_ST       : Boolean;
      --  Read-only. interrupt of thres0 low
      THRES0_LOW_INT_ST       : Boolean;
      --  Read-only. interrupt of thres1 high
      THRES1_HIGH_INT_ST      : Boolean;
      --  Read-only. interrupt of thres0 high
      THRES0_HIGH_INT_ST      : Boolean;
      --  Read-only. interrupt of sar2 done
      APB_SARADC2_DONE_INT_ST : Boolean;
      --  Read-only. interrupt of sar1 done
      APB_SARADC1_DONE_INT_ST : Boolean;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ST_Register use
     record
       Reserved_0_25 at 0 range 0 .. 25;
       THRES1_LOW_INT_ST at 0 range 26 .. 26;
       THRES0_LOW_INT_ST at 0 range 27 .. 27;
       THRES1_HIGH_INT_ST at 0 range 28 .. 28;
       THRES0_HIGH_INT_ST at 0 range 29 .. 29;
       APB_SARADC2_DONE_INT_ST at 0 range 30 .. 30;
       APB_SARADC1_DONE_INT_ST at 0 range 31 .. 31;
     end record;

   --  clear interrupt
   type INT_CLR_Register is record
      --  unspecified
      Reserved_0_25            : ESP32S3_Registers.UInt26 := 16#0#;
      --  Write-only. interrupt of thres1 low
      THRES1_LOW_INT_CLR       : Boolean := False;
      --  Write-only. interrupt of thres0 low
      THRES0_LOW_INT_CLR       : Boolean := False;
      --  Write-only. interrupt of thres1 high
      THRES1_HIGH_INT_CLR      : Boolean := False;
      --  Write-only. interrupt of thres0 high
      THRES0_HIGH_INT_CLR      : Boolean := False;
      --  Write-only. interrupt of sar2 done
      APB_SARADC2_DONE_INT_CLR : Boolean := False;
      --  Write-only. interrupt of sar1 done
      APB_SARADC1_DONE_INT_CLR : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_CLR_Register use
     record
       Reserved_0_25 at 0 range 0 .. 25;
       THRES1_LOW_INT_CLR at 0 range 26 .. 26;
       THRES0_LOW_INT_CLR at 0 range 27 .. 27;
       THRES1_HIGH_INT_CLR at 0 range 28 .. 28;
       THRES0_HIGH_INT_CLR at 0 range 29 .. 29;
       APB_SARADC2_DONE_INT_CLR at 0 range 30 .. 30;
       APB_SARADC1_DONE_INT_CLR at 0 range 31 .. 31;
     end record;

   subtype DMA_CONF_APB_ADC_EOF_NUM_Field is ESP32S3_Registers.UInt16;

   --  configure apb saradc dma
   type DMA_CONF_Register is record
      --  the dma_in_suc_eof gen when sample cnt = spi_eof_num
      APB_ADC_EOF_NUM   : DMA_CONF_APB_ADC_EOF_NUM_Field := 16#FF#;
      --  unspecified
      Reserved_16_29    : ESP32S3_Registers.UInt14 := 16#0#;
      --  reset_apb_adc_state
      APB_ADC_RESET_FSM : Boolean := False;
      --  enable apb_adc use spi_dma
      APB_ADC_TRANS     : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_CONF_Register use
     record
       APB_ADC_EOF_NUM at 0 range 0 .. 15;
       Reserved_16_29 at 0 range 16 .. 29;
       APB_ADC_RESET_FSM at 0 range 30 .. 30;
       APB_ADC_TRANS at 0 range 31 .. 31;
     end record;

   subtype CLKM_CONF_CLKM_DIV_NUM_Field is ESP32S3_Registers.Byte;
   subtype CLKM_CONF_CLKM_DIV_B_Field is ESP32S3_Registers.UInt6;
   subtype CLKM_CONF_CLKM_DIV_A_Field is ESP32S3_Registers.UInt6;
   subtype CLKM_CONF_CLK_SEL_Field is ESP32S3_Registers.UInt2;

   --  configure apb saradc clock
   type CLKM_CONF_Register is record
      --  Integral clock divider value
      CLKM_DIV_NUM   : CLKM_CONF_CLKM_DIV_NUM_Field := 16#4#;
      --  Fractional clock divider numerator value
      CLKM_DIV_B     : CLKM_CONF_CLKM_DIV_B_Field := 16#0#;
      --  Fractional clock divider denominator value
      CLKM_DIV_A     : CLKM_CONF_CLKM_DIV_A_Field := 16#0#;
      --  no public
      CLK_EN         : Boolean := False;
      --  Set this bit to enable clk_apll
      CLK_SEL        : CLKM_CONF_CLK_SEL_Field := 16#0#;
      --  unspecified
      Reserved_23_31 : ESP32S3_Registers.UInt9 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CLKM_CONF_Register use
     record
       CLKM_DIV_NUM at 0 range 0 .. 7;
       CLKM_DIV_B at 0 range 8 .. 13;
       CLKM_DIV_A at 0 range 14 .. 19;
       CLK_EN at 0 range 20 .. 20;
       CLK_SEL at 0 range 21 .. 22;
       Reserved_23_31 at 0 range 23 .. 31;
     end record;

   subtype APB_SARADC2_DATA_STATUS_APB_SARADC2_DATA_Field is
     ESP32S3_Registers.UInt17;

   --  get apb saradc2 sample data
   type APB_SARADC2_DATA_STATUS_Register is record
      --  Read-only. apb saradc2 sample data
      APB_SARADC2_DATA : APB_SARADC2_DATA_STATUS_APB_SARADC2_DATA_Field;
      --  unspecified
      Reserved_17_31   : ESP32S3_Registers.UInt15;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for APB_SARADC2_DATA_STATUS_Register use
     record
       APB_SARADC2_DATA at 0 range 0 .. 16;
       Reserved_17_31 at 0 range 17 .. 31;
     end record;

   -----------------
   -- Peripherals --
   -----------------

   --  SAR (Successive Approximation Register) Analog-to-Digital Converter
   type APB_SARADC_Peripheral is record
      --  configure apb saradc controller
      CTRL                    : aliased CTRL_Register;
      --  configure apb saradc controller
      CTRL2                   : aliased CTRL2_Register;
      --  configure saradc filter
      FILTER_CTRL1            : aliased FILTER_CTRL1_Register;
      --  configure apb saradc fsm
      FSM_WAIT                : aliased FSM_WAIT_Register;
      --  saradc1 status for debug
      SAR1_STATUS             : aliased ESP32S3_Registers.UInt32;
      --  saradc2 status for debug
      SAR2_STATUS             : aliased ESP32S3_Registers.UInt32;
      --  configure apb saradc pattern table
      SAR1_PATT_TAB1          : aliased SAR1_PATT_TAB1_Register;
      --  configure apb saradc pattern table
      SAR1_PATT_TAB2          : aliased SAR1_PATT_TAB2_Register;
      --  configure apb saradc pattern table
      SAR1_PATT_TAB3          : aliased SAR1_PATT_TAB3_Register;
      --  configure apb saradc pattern table
      SAR1_PATT_TAB4          : aliased SAR1_PATT_TAB4_Register;
      --  configure apb saradc pattern table
      SAR2_PATT_TAB1          : aliased SAR2_PATT_TAB1_Register;
      --  configure apb saradc pattern table
      SAR2_PATT_TAB2          : aliased SAR2_PATT_TAB2_Register;
      --  configure apb saradc pattern table
      SAR2_PATT_TAB3          : aliased SAR2_PATT_TAB3_Register;
      --  configure apb saradc pattern table
      SAR2_PATT_TAB4          : aliased SAR2_PATT_TAB4_Register;
      --  configure apb saradc arbit
      ARB_CTRL                : aliased ARB_CTRL_Register;
      --  configure apb saradc arbit
      FILTER_CTRL0            : aliased FILTER_CTRL0_Register;
      --  get apb saradc sample data
      APB_SARADC1_DATA_STATUS : aliased APB_SARADC1_DATA_STATUS_Register;
      --  configure apb saradc thres monitor
      THRES0_CTRL             : aliased THRES0_CTRL_Register;
      --  configure apb saradc thres monitor
      THRES1_CTRL             : aliased THRES1_CTRL_Register;
      --  configure thres monitor enable
      THRES_CTRL              : aliased THRES_CTRL_Register;
      --  enable interrupt
      INT_ENA                 : aliased INT_ENA_Register;
      --  raw of interrupt
      INT_RAW                 : aliased INT_RAW_Register;
      --  state of interrupt
      INT_ST                  : aliased INT_ST_Register;
      --  clear interrupt
      INT_CLR                 : aliased INT_CLR_Register;
      --  configure apb saradc dma
      DMA_CONF                : aliased DMA_CONF_Register;
      --  configure apb saradc clock
      CLKM_CONF               : aliased CLKM_CONF_Register;
      --  get apb saradc2 sample data
      APB_SARADC2_DATA_STATUS : aliased APB_SARADC2_DATA_STATUS_Register;
      --  version
      APB_CTRL_DATE           : aliased ESP32S3_Registers.UInt32;
   end record
   with Volatile;

   for APB_SARADC_Peripheral use
     record
       CTRL at 16#0# range 0 .. 31;
       CTRL2 at 16#4# range 0 .. 31;
       FILTER_CTRL1 at 16#8# range 0 .. 31;
       FSM_WAIT at 16#C# range 0 .. 31;
       SAR1_STATUS at 16#10# range 0 .. 31;
       SAR2_STATUS at 16#14# range 0 .. 31;
       SAR1_PATT_TAB1 at 16#18# range 0 .. 31;
       SAR1_PATT_TAB2 at 16#1C# range 0 .. 31;
       SAR1_PATT_TAB3 at 16#20# range 0 .. 31;
       SAR1_PATT_TAB4 at 16#24# range 0 .. 31;
       SAR2_PATT_TAB1 at 16#28# range 0 .. 31;
       SAR2_PATT_TAB2 at 16#2C# range 0 .. 31;
       SAR2_PATT_TAB3 at 16#30# range 0 .. 31;
       SAR2_PATT_TAB4 at 16#34# range 0 .. 31;
       ARB_CTRL at 16#38# range 0 .. 31;
       FILTER_CTRL0 at 16#3C# range 0 .. 31;
       APB_SARADC1_DATA_STATUS at 16#40# range 0 .. 31;
       THRES0_CTRL at 16#44# range 0 .. 31;
       THRES1_CTRL at 16#48# range 0 .. 31;
       THRES_CTRL at 16#58# range 0 .. 31;
       INT_ENA at 16#5C# range 0 .. 31;
       INT_RAW at 16#60# range 0 .. 31;
       INT_ST at 16#64# range 0 .. 31;
       INT_CLR at 16#68# range 0 .. 31;
       DMA_CONF at 16#6C# range 0 .. 31;
       CLKM_CONF at 16#70# range 0 .. 31;
       APB_SARADC2_DATA_STATUS at 16#78# range 0 .. 31;
       APB_CTRL_DATE at 16#3FC# range 0 .. 31;
     end record;

   --  SAR (Successive Approximation Register) Analog-to-Digital Converter
   APB_SARADC_Periph : aliased APB_SARADC_Peripheral
   with Import, Address => APB_SARADC_Base, Volatile,
        Async_Readers    => True,
        Async_Writers    => True,
        Effective_Reads  => False,
        Effective_Writes => True;

end ESP32S3_Registers.APB_SARADC;
