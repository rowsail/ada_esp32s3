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

package ESP32S3_Registers.LEDC is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype CH_CONF_TIMER_SEL_Field is ESP32S3_Registers.UInt2;
   subtype CH_CONF_OVF_NUM_Field is ESP32S3_Registers.UInt10;

   --  Configuration register 0 for channel %s
   type CH_CONF_Register is record
      --  This field is used to select one of timers for channel %s. 0: select
      --  timer0 1: select timer1 2: select timer2 3: select timer3
      TIMER_SEL        : CH_CONF_TIMER_SEL_Field := 16#0#;
      --  Set this bit to enable signal output on channel %s.
      SIG_OUT_EN       : Boolean := False;
      --  This bit is used to control the output value when channel %s is
      --  inactive (when LEDC_SIG_OUT_EN_CH%s is 0).
      IDLE_LV          : Boolean := False;
      --  Write-only. This bit is used to update LEDC_HPOINT_CH%s,
      --  LEDC_DUTY_START_CH%s, LEDC_SIG_OUT_EN_CH%s, LEDC_TIMER_SEL_CH%s,
      --  LEDC_DUTY_NUM_CH%s, LEDC_DUTY_CYCLE_CH%s, LEDC_DUTY_SCALE_CH%s,
      --  LEDC_DUTY_INC_CH%s, and LEDC_OVF_CNT_EN_CH%s fields for channel %s,
      --  and will be automatically cleared by hardware.
      PARA_UP          : Boolean := False;
      --  This register is used to configure the maximum times of overflow
      --  minus 1. The LEDC_OVF_CNT_CH%s_INT interrupt will be triggered when
      --  channel %s overflows for (LEDC_OVF_NUM_CH%s + 1) times.
      OVF_NUM          : CH_CONF_OVF_NUM_Field := 16#0#;
      --  This bit is used to enable the ovf_cnt of channel %s.
      OVF_CNT_EN       : Boolean := False;
      --  Write-only. Set this bit to reset the ovf_cnt of channel %s.
      OVF_CNT_RESET    : Boolean := False;
      --  This is the status bit of LEDC_OVF_CNT_RESET_CH%s.
      OVF_CNT_RESET_ST : Boolean := False;
      --  unspecified
      Reserved_18_31   : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CH_CONF_Register use record
      TIMER_SEL        at 0 range 0 .. 1;
      SIG_OUT_EN       at 0 range 2 .. 2;
      IDLE_LV          at 0 range 3 .. 3;
      PARA_UP          at 0 range 4 .. 4;
      OVF_NUM          at 0 range 5 .. 14;
      OVF_CNT_EN       at 0 range 15 .. 15;
      OVF_CNT_RESET    at 0 range 16 .. 16;
      OVF_CNT_RESET_ST at 0 range 17 .. 17;
      Reserved_18_31   at 0 range 18 .. 31;
   end record;

   subtype CH_HPOINT_HPOINT_Field is ESP32S3_Registers.UInt14;

   --  High point register for channel %s
   type CH_HPOINT_Register is record
      --  The output value changes to high when the selected timers has reached
      --  the value specified by this register.
      HPOINT         : CH_HPOINT_HPOINT_Field := 16#0#;
      --  unspecified
      Reserved_14_31 : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CH_HPOINT_Register use record
      HPOINT         at 0 range 0 .. 13;
      Reserved_14_31 at 0 range 14 .. 31;
   end record;

   subtype CH_DUTY_DUTY_Field is ESP32S3_Registers.UInt19;

   --  Initial duty cycle for channel %s
   type CH_DUTY_Register is record
      --  This register is used to change the output duty by controlling the
      --  Lpoint. The output value turns to low when the selected timers has
      --  reached the Lpoint.
      DUTY           : CH_DUTY_DUTY_Field := 16#0#;
      --  unspecified
      Reserved_19_31 : ESP32S3_Registers.UInt13 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CH_DUTY_Register use record
      DUTY           at 0 range 0 .. 18;
      Reserved_19_31 at 0 range 19 .. 31;
   end record;

   subtype CH_CONF_DUTY_SCALE_Field is ESP32S3_Registers.UInt10;
   subtype CH_CONF_DUTY_CYCLE_Field is ESP32S3_Registers.UInt10;
   subtype CH_CONF_DUTY_NUM_Field is ESP32S3_Registers.UInt10;

   --  Configuration register 1 for channel %s
   type CH_CONF_Register_1 is record
      --  This register is used to configure the changing step scale of duty on
      --  channel %s.
      DUTY_SCALE : CH_CONF_DUTY_SCALE_Field := 16#0#;
      --  The duty will change every LEDC_DUTY_CYCLE_CH%s on channel %s.
      DUTY_CYCLE : CH_CONF_DUTY_CYCLE_Field := 16#0#;
      --  This register is used to control the number of times the duty cycle
      --  will be changed.
      DUTY_NUM   : CH_CONF_DUTY_NUM_Field := 16#0#;
      --  This register is used to increase or decrease the duty of output
      --  signal on channel %s. 1: Increase; 0: Decrease.
      DUTY_INC   : Boolean := True;
      --  Other configured fields in LEDC_CH%s_CONF1_REG will start to take
      --  effect when this bit is set to 1.
      DUTY_START : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CH_CONF_Register_1 use record
      DUTY_SCALE at 0 range 0 .. 9;
      DUTY_CYCLE at 0 range 10 .. 19;
      DUTY_NUM   at 0 range 20 .. 29;
      DUTY_INC   at 0 range 30 .. 30;
      DUTY_START at 0 range 31 .. 31;
   end record;

   subtype CH_DUTY_R_DUTY_R_Field is ESP32S3_Registers.UInt19;

   --  Current duty cycle for channel %s
   type CH_DUTY_R_Register is record
      --  Read-only. This register stores the current duty of output signal on
      --  channel %s.
      DUTY_R         : CH_DUTY_R_DUTY_R_Field;
      --  unspecified
      Reserved_19_31 : ESP32S3_Registers.UInt13;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CH_DUTY_R_Register use record
      DUTY_R         at 0 range 0 .. 18;
      Reserved_19_31 at 0 range 19 .. 31;
   end record;

   subtype TIMER_CONF_DUTY_RES_Field is ESP32S3_Registers.UInt4;
   subtype TIMER_CONF_CLK_DIV_Field is ESP32S3_Registers.UInt18;

   --  Timer %s configuration
   type TIMER_CONF_Register is record
      --  This register is used to control the range of the counter in timer
      --  %s.
      DUTY_RES       : TIMER_CONF_DUTY_RES_Field := 16#0#;
      --  This register is used to configure the divisor for the divider in
      --  timer %s. The least significant eight bits represent the fractional
      --  part.
      CLK_DIV        : TIMER_CONF_CLK_DIV_Field := 16#0#;
      --  This bit is used to suspend the counter in timer %s.
      PAUSE          : Boolean := False;
      --  This bit is used to reset timer %s. The counter will show 0 after
      --  reset.
      RST            : Boolean := True;
      --  This bit is used to select clock for timer %s. When this bit is set
      --  to 1 LEDC_APB_CLK_SEL[1:0] should be 1, otherwise the timer clock may
      --  be not accurate. 1'h0: SLOW_CLK 1'h1: REF_TICK
      TICK_SEL       : Boolean := False;
      --  Write-only. Set this bit to update LEDC_CLK_DIV_TIMER%s and
      --  LEDC_TIMER%s_DUTY_RES.
      PARA_UP        : Boolean := False;
      --  unspecified
      Reserved_26_31 : ESP32S3_Registers.UInt6 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER_CONF_Register use record
      DUTY_RES       at 0 range 0 .. 3;
      CLK_DIV        at 0 range 4 .. 21;
      PAUSE          at 0 range 22 .. 22;
      RST            at 0 range 23 .. 23;
      TICK_SEL       at 0 range 24 .. 24;
      PARA_UP        at 0 range 25 .. 25;
      Reserved_26_31 at 0 range 26 .. 31;
   end record;

   subtype TIMER_VALUE_CNT_Field is ESP32S3_Registers.UInt14;

   --  Timer %s current counter value
   type TIMER_VALUE_Register is record
      --  Read-only. This register stores the current counter value of timer
      --  %s.
      CNT            : TIMER_VALUE_CNT_Field;
      --  unspecified
      Reserved_14_31 : ESP32S3_Registers.UInt18;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMER_VALUE_Register use record
      CNT            at 0 range 0 .. 13;
      Reserved_14_31 at 0 range 14 .. 31;
   end record;

   --  Raw interrupt status
   type INT_RAW_Register is record
      --  Triggered when the timer0 has reached its maximum counter value.
      TIMER0_OVF_INT_RAW        : Boolean := False;
      --  Triggered when the timer1 has reached its maximum counter value.
      TIMER1_OVF_INT_RAW        : Boolean := False;
      --  Triggered when the timer2 has reached its maximum counter value.
      TIMER2_OVF_INT_RAW        : Boolean := False;
      --  Triggered when the timer3 has reached its maximum counter value.
      TIMER3_OVF_INT_RAW        : Boolean := False;
      --  Interrupt raw bit for channel 0. Triggered when the gradual change of
      --  duty has finished.
      DUTY_CHNG_END_CH0_INT_RAW : Boolean := False;
      --  Interrupt raw bit for channel 1. Triggered when the gradual change of
      --  duty has finished.
      DUTY_CHNG_END_CH1_INT_RAW : Boolean := False;
      --  Interrupt raw bit for channel 2. Triggered when the gradual change of
      --  duty has finished.
      DUTY_CHNG_END_CH2_INT_RAW : Boolean := False;
      --  Interrupt raw bit for channel 3. Triggered when the gradual change of
      --  duty has finished.
      DUTY_CHNG_END_CH3_INT_RAW : Boolean := False;
      --  Interrupt raw bit for channel 4. Triggered when the gradual change of
      --  duty has finished.
      DUTY_CHNG_END_CH4_INT_RAW : Boolean := False;
      --  Interrupt raw bit for channel 5. Triggered when the gradual change of
      --  duty has finished.
      DUTY_CHNG_END_CH5_INT_RAW : Boolean := False;
      --  Interrupt raw bit for channel 6. Triggered when the gradual change of
      --  duty has finished.
      DUTY_CHNG_END_CH6_INT_RAW : Boolean := False;
      --  Interrupt raw bit for channel 7. Triggered when the gradual change of
      --  duty has finished.
      DUTY_CHNG_END_CH7_INT_RAW : Boolean := False;
      --  Interrupt raw bit for channel 0. Triggered when the ovf_cnt has
      --  reached the value specified by LEDC_OVF_NUM_CH0.
      OVF_CNT_CH0_INT_RAW       : Boolean := False;
      --  Interrupt raw bit for channel 1. Triggered when the ovf_cnt has
      --  reached the value specified by LEDC_OVF_NUM_CH1.
      OVF_CNT_CH1_INT_RAW       : Boolean := False;
      --  Interrupt raw bit for channel 2. Triggered when the ovf_cnt has
      --  reached the value specified by LEDC_OVF_NUM_CH2.
      OVF_CNT_CH2_INT_RAW       : Boolean := False;
      --  Interrupt raw bit for channel 3. Triggered when the ovf_cnt has
      --  reached the value specified by LEDC_OVF_NUM_CH3.
      OVF_CNT_CH3_INT_RAW       : Boolean := False;
      --  Interrupt raw bit for channel 4. Triggered when the ovf_cnt has
      --  reached the value specified by LEDC_OVF_NUM_CH4.
      OVF_CNT_CH4_INT_RAW       : Boolean := False;
      --  Interrupt raw bit for channel 5. Triggered when the ovf_cnt has
      --  reached the value specified by LEDC_OVF_NUM_CH5.
      OVF_CNT_CH5_INT_RAW       : Boolean := False;
      --  Interrupt raw bit for channel 6. Triggered when the ovf_cnt has
      --  reached the value specified by LEDC_OVF_NUM_CH6.
      OVF_CNT_CH6_INT_RAW       : Boolean := False;
      --  Interrupt raw bit for channel 7. Triggered when the ovf_cnt has
      --  reached the value specified by LEDC_OVF_NUM_CH7.
      OVF_CNT_CH7_INT_RAW       : Boolean := False;
      --  unspecified
      Reserved_20_31            : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_Register use record
      TIMER0_OVF_INT_RAW        at 0 range 0 .. 0;
      TIMER1_OVF_INT_RAW        at 0 range 1 .. 1;
      TIMER2_OVF_INT_RAW        at 0 range 2 .. 2;
      TIMER3_OVF_INT_RAW        at 0 range 3 .. 3;
      DUTY_CHNG_END_CH0_INT_RAW at 0 range 4 .. 4;
      DUTY_CHNG_END_CH1_INT_RAW at 0 range 5 .. 5;
      DUTY_CHNG_END_CH2_INT_RAW at 0 range 6 .. 6;
      DUTY_CHNG_END_CH3_INT_RAW at 0 range 7 .. 7;
      DUTY_CHNG_END_CH4_INT_RAW at 0 range 8 .. 8;
      DUTY_CHNG_END_CH5_INT_RAW at 0 range 9 .. 9;
      DUTY_CHNG_END_CH6_INT_RAW at 0 range 10 .. 10;
      DUTY_CHNG_END_CH7_INT_RAW at 0 range 11 .. 11;
      OVF_CNT_CH0_INT_RAW       at 0 range 12 .. 12;
      OVF_CNT_CH1_INT_RAW       at 0 range 13 .. 13;
      OVF_CNT_CH2_INT_RAW       at 0 range 14 .. 14;
      OVF_CNT_CH3_INT_RAW       at 0 range 15 .. 15;
      OVF_CNT_CH4_INT_RAW       at 0 range 16 .. 16;
      OVF_CNT_CH5_INT_RAW       at 0 range 17 .. 17;
      OVF_CNT_CH6_INT_RAW       at 0 range 18 .. 18;
      OVF_CNT_CH7_INT_RAW       at 0 range 19 .. 19;
      Reserved_20_31            at 0 range 20 .. 31;
   end record;

   --  Masked interrupt status
   type INT_ST_Register is record
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_TIMER0_OVF_INT interrupt when LEDC_TIMER0_OVF_INT_ENA is set to
      --  1.
      TIMER0_OVF_INT_ST        : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_TIMER1_OVF_INT interrupt when LEDC_TIMER1_OVF_INT_ENA is set to
      --  1.
      TIMER1_OVF_INT_ST        : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_TIMER2_OVF_INT interrupt when LEDC_TIMER2_OVF_INT_ENA is set to
      --  1.
      TIMER2_OVF_INT_ST        : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_TIMER3_OVF_INT interrupt when LEDC_TIMER3_OVF_INT_ENA is set to
      --  1.
      TIMER3_OVF_INT_ST        : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_DUTY_CHNG_END_CH0_INT interrupt when
      --  LEDC_DUTY_CHNG_END_CH0_INT_ENAIS set to 1.
      DUTY_CHNG_END_CH0_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_DUTY_CHNG_END_CH1_INT interrupt when
      --  LEDC_DUTY_CHNG_END_CH1_INT_ENAIS set to 1.
      DUTY_CHNG_END_CH1_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_DUTY_CHNG_END_CH2_INT interrupt when
      --  LEDC_DUTY_CHNG_END_CH2_INT_ENAIS set to 1.
      DUTY_CHNG_END_CH2_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_DUTY_CHNG_END_CH3_INT interrupt when
      --  LEDC_DUTY_CHNG_END_CH3_INT_ENAIS set to 1.
      DUTY_CHNG_END_CH3_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_DUTY_CHNG_END_CH4_INT interrupt when
      --  LEDC_DUTY_CHNG_END_CH4_INT_ENAIS set to 1.
      DUTY_CHNG_END_CH4_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_DUTY_CHNG_END_CH5_INT interrupt when
      --  LEDC_DUTY_CHNG_END_CH5_INT_ENAIS set to 1.
      DUTY_CHNG_END_CH5_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_DUTY_CHNG_END_CH6_INT interrupt when
      --  LEDC_DUTY_CHNG_END_CH6_INT_ENAIS set to 1.
      DUTY_CHNG_END_CH6_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_DUTY_CHNG_END_CH7_INT interrupt when
      --  LEDC_DUTY_CHNG_END_CH7_INT_ENAIS set to 1.
      DUTY_CHNG_END_CH7_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_OVF_CNT_CH0_INT interrupt when LEDC_OVF_CNT_CH0_INT_ENA is set
      --  to 1.
      OVF_CNT_CH0_INT_ST       : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_OVF_CNT_CH1_INT interrupt when LEDC_OVF_CNT_CH1_INT_ENA is set
      --  to 1.
      OVF_CNT_CH1_INT_ST       : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_OVF_CNT_CH2_INT interrupt when LEDC_OVF_CNT_CH2_INT_ENA is set
      --  to 1.
      OVF_CNT_CH2_INT_ST       : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_OVF_CNT_CH3_INT interrupt when LEDC_OVF_CNT_CH3_INT_ENA is set
      --  to 1.
      OVF_CNT_CH3_INT_ST       : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_OVF_CNT_CH4_INT interrupt when LEDC_OVF_CNT_CH4_INT_ENA is set
      --  to 1.
      OVF_CNT_CH4_INT_ST       : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_OVF_CNT_CH5_INT interrupt when LEDC_OVF_CNT_CH5_INT_ENA is set
      --  to 1.
      OVF_CNT_CH5_INT_ST       : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_OVF_CNT_CH6_INT interrupt when LEDC_OVF_CNT_CH6_INT_ENA is set
      --  to 1.
      OVF_CNT_CH6_INT_ST       : Boolean;
      --  Read-only. This is the masked interrupt status bit for the
      --  LEDC_OVF_CNT_CH7_INT interrupt when LEDC_OVF_CNT_CH7_INT_ENA is set
      --  to 1.
      OVF_CNT_CH7_INT_ST       : Boolean;
      --  unspecified
      Reserved_20_31           : ESP32S3_Registers.UInt12;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ST_Register use record
      TIMER0_OVF_INT_ST        at 0 range 0 .. 0;
      TIMER1_OVF_INT_ST        at 0 range 1 .. 1;
      TIMER2_OVF_INT_ST        at 0 range 2 .. 2;
      TIMER3_OVF_INT_ST        at 0 range 3 .. 3;
      DUTY_CHNG_END_CH0_INT_ST at 0 range 4 .. 4;
      DUTY_CHNG_END_CH1_INT_ST at 0 range 5 .. 5;
      DUTY_CHNG_END_CH2_INT_ST at 0 range 6 .. 6;
      DUTY_CHNG_END_CH3_INT_ST at 0 range 7 .. 7;
      DUTY_CHNG_END_CH4_INT_ST at 0 range 8 .. 8;
      DUTY_CHNG_END_CH5_INT_ST at 0 range 9 .. 9;
      DUTY_CHNG_END_CH6_INT_ST at 0 range 10 .. 10;
      DUTY_CHNG_END_CH7_INT_ST at 0 range 11 .. 11;
      OVF_CNT_CH0_INT_ST       at 0 range 12 .. 12;
      OVF_CNT_CH1_INT_ST       at 0 range 13 .. 13;
      OVF_CNT_CH2_INT_ST       at 0 range 14 .. 14;
      OVF_CNT_CH3_INT_ST       at 0 range 15 .. 15;
      OVF_CNT_CH4_INT_ST       at 0 range 16 .. 16;
      OVF_CNT_CH5_INT_ST       at 0 range 17 .. 17;
      OVF_CNT_CH6_INT_ST       at 0 range 18 .. 18;
      OVF_CNT_CH7_INT_ST       at 0 range 19 .. 19;
      Reserved_20_31           at 0 range 20 .. 31;
   end record;

   --  Interrupt enable bits
   type INT_ENA_Register is record
      --  The interrupt enable bit for the LEDC_TIMER0_OVF_INT interrupt.
      TIMER0_OVF_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for the LEDC_TIMER1_OVF_INT interrupt.
      TIMER1_OVF_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for the LEDC_TIMER2_OVF_INT interrupt.
      TIMER2_OVF_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for the LEDC_TIMER3_OVF_INT interrupt.
      TIMER3_OVF_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for the LEDC_DUTY_CHNG_END_CH0_INT
      --  interrupt.
      DUTY_CHNG_END_CH0_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the LEDC_DUTY_CHNG_END_CH1_INT
      --  interrupt.
      DUTY_CHNG_END_CH1_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the LEDC_DUTY_CHNG_END_CH2_INT
      --  interrupt.
      DUTY_CHNG_END_CH2_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the LEDC_DUTY_CHNG_END_CH3_INT
      --  interrupt.
      DUTY_CHNG_END_CH3_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the LEDC_DUTY_CHNG_END_CH4_INT
      --  interrupt.
      DUTY_CHNG_END_CH4_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the LEDC_DUTY_CHNG_END_CH5_INT
      --  interrupt.
      DUTY_CHNG_END_CH5_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the LEDC_DUTY_CHNG_END_CH6_INT
      --  interrupt.
      DUTY_CHNG_END_CH6_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the LEDC_DUTY_CHNG_END_CH7_INT
      --  interrupt.
      DUTY_CHNG_END_CH7_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the LEDC_OVF_CNT_CH0_INT interrupt.
      OVF_CNT_CH0_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the LEDC_OVF_CNT_CH1_INT interrupt.
      OVF_CNT_CH1_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the LEDC_OVF_CNT_CH2_INT interrupt.
      OVF_CNT_CH2_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the LEDC_OVF_CNT_CH3_INT interrupt.
      OVF_CNT_CH3_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the LEDC_OVF_CNT_CH4_INT interrupt.
      OVF_CNT_CH4_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the LEDC_OVF_CNT_CH5_INT interrupt.
      OVF_CNT_CH5_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the LEDC_OVF_CNT_CH6_INT interrupt.
      OVF_CNT_CH6_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the LEDC_OVF_CNT_CH7_INT interrupt.
      OVF_CNT_CH7_INT_ENA       : Boolean := False;
      --  unspecified
      Reserved_20_31            : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_Register use record
      TIMER0_OVF_INT_ENA        at 0 range 0 .. 0;
      TIMER1_OVF_INT_ENA        at 0 range 1 .. 1;
      TIMER2_OVF_INT_ENA        at 0 range 2 .. 2;
      TIMER3_OVF_INT_ENA        at 0 range 3 .. 3;
      DUTY_CHNG_END_CH0_INT_ENA at 0 range 4 .. 4;
      DUTY_CHNG_END_CH1_INT_ENA at 0 range 5 .. 5;
      DUTY_CHNG_END_CH2_INT_ENA at 0 range 6 .. 6;
      DUTY_CHNG_END_CH3_INT_ENA at 0 range 7 .. 7;
      DUTY_CHNG_END_CH4_INT_ENA at 0 range 8 .. 8;
      DUTY_CHNG_END_CH5_INT_ENA at 0 range 9 .. 9;
      DUTY_CHNG_END_CH6_INT_ENA at 0 range 10 .. 10;
      DUTY_CHNG_END_CH7_INT_ENA at 0 range 11 .. 11;
      OVF_CNT_CH0_INT_ENA       at 0 range 12 .. 12;
      OVF_CNT_CH1_INT_ENA       at 0 range 13 .. 13;
      OVF_CNT_CH2_INT_ENA       at 0 range 14 .. 14;
      OVF_CNT_CH3_INT_ENA       at 0 range 15 .. 15;
      OVF_CNT_CH4_INT_ENA       at 0 range 16 .. 16;
      OVF_CNT_CH5_INT_ENA       at 0 range 17 .. 17;
      OVF_CNT_CH6_INT_ENA       at 0 range 18 .. 18;
      OVF_CNT_CH7_INT_ENA       at 0 range 19 .. 19;
      Reserved_20_31            at 0 range 20 .. 31;
   end record;

   --  Interrupt clear bits
   type INT_CLR_Register is record
      --  Write-only. Set this bit to clear the LEDC_TIMER0_OVF_INT interrupt.
      TIMER0_OVF_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_TIMER1_OVF_INT interrupt.
      TIMER1_OVF_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_TIMER2_OVF_INT interrupt.
      TIMER2_OVF_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_TIMER3_OVF_INT interrupt.
      TIMER3_OVF_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_DUTY_CHNG_END_CH0_INT
      --  interrupt.
      DUTY_CHNG_END_CH0_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_DUTY_CHNG_END_CH1_INT
      --  interrupt.
      DUTY_CHNG_END_CH1_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_DUTY_CHNG_END_CH2_INT
      --  interrupt.
      DUTY_CHNG_END_CH2_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_DUTY_CHNG_END_CH3_INT
      --  interrupt.
      DUTY_CHNG_END_CH3_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_DUTY_CHNG_END_CH4_INT
      --  interrupt.
      DUTY_CHNG_END_CH4_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_DUTY_CHNG_END_CH5_INT
      --  interrupt.
      DUTY_CHNG_END_CH5_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_DUTY_CHNG_END_CH6_INT
      --  interrupt.
      DUTY_CHNG_END_CH6_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_DUTY_CHNG_END_CH7_INT
      --  interrupt.
      DUTY_CHNG_END_CH7_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_OVF_CNT_CH0_INT interrupt.
      OVF_CNT_CH0_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_OVF_CNT_CH1_INT interrupt.
      OVF_CNT_CH1_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_OVF_CNT_CH2_INT interrupt.
      OVF_CNT_CH2_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_OVF_CNT_CH3_INT interrupt.
      OVF_CNT_CH3_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_OVF_CNT_CH4_INT interrupt.
      OVF_CNT_CH4_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_OVF_CNT_CH5_INT interrupt.
      OVF_CNT_CH5_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_OVF_CNT_CH6_INT interrupt.
      OVF_CNT_CH6_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the LEDC_OVF_CNT_CH7_INT interrupt.
      OVF_CNT_CH7_INT_CLR       : Boolean := False;
      --  unspecified
      Reserved_20_31            : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_Register use record
      TIMER0_OVF_INT_CLR        at 0 range 0 .. 0;
      TIMER1_OVF_INT_CLR        at 0 range 1 .. 1;
      TIMER2_OVF_INT_CLR        at 0 range 2 .. 2;
      TIMER3_OVF_INT_CLR        at 0 range 3 .. 3;
      DUTY_CHNG_END_CH0_INT_CLR at 0 range 4 .. 4;
      DUTY_CHNG_END_CH1_INT_CLR at 0 range 5 .. 5;
      DUTY_CHNG_END_CH2_INT_CLR at 0 range 6 .. 6;
      DUTY_CHNG_END_CH3_INT_CLR at 0 range 7 .. 7;
      DUTY_CHNG_END_CH4_INT_CLR at 0 range 8 .. 8;
      DUTY_CHNG_END_CH5_INT_CLR at 0 range 9 .. 9;
      DUTY_CHNG_END_CH6_INT_CLR at 0 range 10 .. 10;
      DUTY_CHNG_END_CH7_INT_CLR at 0 range 11 .. 11;
      OVF_CNT_CH0_INT_CLR       at 0 range 12 .. 12;
      OVF_CNT_CH1_INT_CLR       at 0 range 13 .. 13;
      OVF_CNT_CH2_INT_CLR       at 0 range 14 .. 14;
      OVF_CNT_CH3_INT_CLR       at 0 range 15 .. 15;
      OVF_CNT_CH4_INT_CLR       at 0 range 16 .. 16;
      OVF_CNT_CH5_INT_CLR       at 0 range 17 .. 17;
      OVF_CNT_CH6_INT_CLR       at 0 range 18 .. 18;
      OVF_CNT_CH7_INT_CLR       at 0 range 19 .. 19;
      Reserved_20_31            at 0 range 20 .. 31;
   end record;

   subtype CONF_APB_CLK_SEL_Field is ESP32S3_Registers.UInt2;

   --  Global ledc configuration register
   type CONF_Register is record
      --  This bit is used to select clock source for the 4 timers . 2'd1:
      --  APB_CLK 2'd2: RTC8M_CLK 2'd3: XTAL_CLK
      APB_CLK_SEL   : CONF_APB_CLK_SEL_Field := 16#0#;
      --  unspecified
      Reserved_2_30 : ESP32S3_Registers.UInt29 := 16#0#;
      --  This bit is used to control clock. 1'b1: Force clock on for register.
      --  1'h0: Support clock only when application writes registers.
      CLK_EN        : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CONF_Register use record
      APB_CLK_SEL   at 0 range 0 .. 1;
      Reserved_2_30 at 0 range 2 .. 30;
      CLK_EN        at 0 range 31 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  LED Control PWM (Pulse Width Modulation)
   type LEDC_Peripheral is record
      --  Configuration register 0 for channel %s
      CH_CONF00    : aliased CH_CONF_Register;
      --  High point register for channel %s
      CH_HPOINT0   : aliased CH_HPOINT_Register;
      --  Initial duty cycle for channel %s
      CH_DUTY0     : aliased CH_DUTY_Register;
      --  Configuration register 1 for channel %s
      CH_CONF10    : aliased CH_CONF_Register_1;
      --  Current duty cycle for channel %s
      CH_DUTY_R0   : aliased CH_DUTY_R_Register;
      --  Configuration register 0 for channel %s
      CH_CONF01    : aliased CH_CONF_Register;
      --  High point register for channel %s
      CH_HPOINT1   : aliased CH_HPOINT_Register;
      --  Initial duty cycle for channel %s
      CH_DUTY1     : aliased CH_DUTY_Register;
      --  Configuration register 1 for channel %s
      CH_CONF11    : aliased CH_CONF_Register_1;
      --  Current duty cycle for channel %s
      CH_DUTY_R1   : aliased CH_DUTY_R_Register;
      --  Configuration register 0 for channel %s
      CH_CONF02    : aliased CH_CONF_Register;
      --  High point register for channel %s
      CH_HPOINT2   : aliased CH_HPOINT_Register;
      --  Initial duty cycle for channel %s
      CH_DUTY2     : aliased CH_DUTY_Register;
      --  Configuration register 1 for channel %s
      CH_CONF12    : aliased CH_CONF_Register_1;
      --  Current duty cycle for channel %s
      CH_DUTY_R2   : aliased CH_DUTY_R_Register;
      --  Configuration register 0 for channel %s
      CH_CONF03    : aliased CH_CONF_Register;
      --  High point register for channel %s
      CH_HPOINT3   : aliased CH_HPOINT_Register;
      --  Initial duty cycle for channel %s
      CH_DUTY3     : aliased CH_DUTY_Register;
      --  Configuration register 1 for channel %s
      CH_CONF13    : aliased CH_CONF_Register_1;
      --  Current duty cycle for channel %s
      CH_DUTY_R3   : aliased CH_DUTY_R_Register;
      --  Configuration register 0 for channel %s
      CH_CONF04    : aliased CH_CONF_Register;
      --  High point register for channel %s
      CH_HPOINT4   : aliased CH_HPOINT_Register;
      --  Initial duty cycle for channel %s
      CH_DUTY4     : aliased CH_DUTY_Register;
      --  Configuration register 1 for channel %s
      CH_CONF14    : aliased CH_CONF_Register_1;
      --  Current duty cycle for channel %s
      CH_DUTY_R4   : aliased CH_DUTY_R_Register;
      --  Configuration register 0 for channel %s
      CH_CONF05    : aliased CH_CONF_Register;
      --  High point register for channel %s
      CH_HPOINT5   : aliased CH_HPOINT_Register;
      --  Initial duty cycle for channel %s
      CH_DUTY5     : aliased CH_DUTY_Register;
      --  Configuration register 1 for channel %s
      CH_CONF15    : aliased CH_CONF_Register_1;
      --  Current duty cycle for channel %s
      CH_DUTY_R5   : aliased CH_DUTY_R_Register;
      --  Configuration register 0 for channel %s
      CH_CONF06    : aliased CH_CONF_Register;
      --  High point register for channel %s
      CH_HPOINT6   : aliased CH_HPOINT_Register;
      --  Initial duty cycle for channel %s
      CH_DUTY6     : aliased CH_DUTY_Register;
      --  Configuration register 1 for channel %s
      CH_CONF16    : aliased CH_CONF_Register_1;
      --  Current duty cycle for channel %s
      CH_DUTY_R6   : aliased CH_DUTY_R_Register;
      --  Configuration register 0 for channel %s
      CH_CONF07    : aliased CH_CONF_Register;
      --  High point register for channel %s
      CH_HPOINT7   : aliased CH_HPOINT_Register;
      --  Initial duty cycle for channel %s
      CH_DUTY7     : aliased CH_DUTY_Register;
      --  Configuration register 1 for channel %s
      CH_CONF17    : aliased CH_CONF_Register_1;
      --  Current duty cycle for channel %s
      CH_DUTY_R7   : aliased CH_DUTY_R_Register;
      --  Timer %s configuration
      TIMER_CONF0  : aliased TIMER_CONF_Register;
      --  Timer %s current counter value
      TIMER_VALUE0 : aliased TIMER_VALUE_Register;
      --  Timer %s configuration
      TIMER_CONF1  : aliased TIMER_CONF_Register;
      --  Timer %s current counter value
      TIMER_VALUE1 : aliased TIMER_VALUE_Register;
      --  Timer %s configuration
      TIMER_CONF2  : aliased TIMER_CONF_Register;
      --  Timer %s current counter value
      TIMER_VALUE2 : aliased TIMER_VALUE_Register;
      --  Timer %s configuration
      TIMER_CONF3  : aliased TIMER_CONF_Register;
      --  Timer %s current counter value
      TIMER_VALUE3 : aliased TIMER_VALUE_Register;
      --  Raw interrupt status
      INT_RAW      : aliased INT_RAW_Register;
      --  Masked interrupt status
      INT_ST       : aliased INT_ST_Register;
      --  Interrupt enable bits
      INT_ENA      : aliased INT_ENA_Register;
      --  Interrupt clear bits
      INT_CLR      : aliased INT_CLR_Register;
      --  Global ledc configuration register
      CONF         : aliased CONF_Register;
      --  Version control register
      DATE         : aliased ESP32S3_Registers.UInt32;
   end record
     with Volatile;

   for LEDC_Peripheral use record
      CH_CONF00    at 16#0# range 0 .. 31;
      CH_HPOINT0   at 16#4# range 0 .. 31;
      CH_DUTY0     at 16#8# range 0 .. 31;
      CH_CONF10    at 16#C# range 0 .. 31;
      CH_DUTY_R0   at 16#10# range 0 .. 31;
      CH_CONF01    at 16#14# range 0 .. 31;
      CH_HPOINT1   at 16#18# range 0 .. 31;
      CH_DUTY1     at 16#1C# range 0 .. 31;
      CH_CONF11    at 16#20# range 0 .. 31;
      CH_DUTY_R1   at 16#24# range 0 .. 31;
      CH_CONF02    at 16#28# range 0 .. 31;
      CH_HPOINT2   at 16#2C# range 0 .. 31;
      CH_DUTY2     at 16#30# range 0 .. 31;
      CH_CONF12    at 16#34# range 0 .. 31;
      CH_DUTY_R2   at 16#38# range 0 .. 31;
      CH_CONF03    at 16#3C# range 0 .. 31;
      CH_HPOINT3   at 16#40# range 0 .. 31;
      CH_DUTY3     at 16#44# range 0 .. 31;
      CH_CONF13    at 16#48# range 0 .. 31;
      CH_DUTY_R3   at 16#4C# range 0 .. 31;
      CH_CONF04    at 16#50# range 0 .. 31;
      CH_HPOINT4   at 16#54# range 0 .. 31;
      CH_DUTY4     at 16#58# range 0 .. 31;
      CH_CONF14    at 16#5C# range 0 .. 31;
      CH_DUTY_R4   at 16#60# range 0 .. 31;
      CH_CONF05    at 16#64# range 0 .. 31;
      CH_HPOINT5   at 16#68# range 0 .. 31;
      CH_DUTY5     at 16#6C# range 0 .. 31;
      CH_CONF15    at 16#70# range 0 .. 31;
      CH_DUTY_R5   at 16#74# range 0 .. 31;
      CH_CONF06    at 16#78# range 0 .. 31;
      CH_HPOINT6   at 16#7C# range 0 .. 31;
      CH_DUTY6     at 16#80# range 0 .. 31;
      CH_CONF16    at 16#84# range 0 .. 31;
      CH_DUTY_R6   at 16#88# range 0 .. 31;
      CH_CONF07    at 16#8C# range 0 .. 31;
      CH_HPOINT7   at 16#90# range 0 .. 31;
      CH_DUTY7     at 16#94# range 0 .. 31;
      CH_CONF17    at 16#98# range 0 .. 31;
      CH_DUTY_R7   at 16#9C# range 0 .. 31;
      TIMER_CONF0  at 16#A0# range 0 .. 31;
      TIMER_VALUE0 at 16#A4# range 0 .. 31;
      TIMER_CONF1  at 16#A8# range 0 .. 31;
      TIMER_VALUE1 at 16#AC# range 0 .. 31;
      TIMER_CONF2  at 16#B0# range 0 .. 31;
      TIMER_VALUE2 at 16#B4# range 0 .. 31;
      TIMER_CONF3  at 16#B8# range 0 .. 31;
      TIMER_VALUE3 at 16#BC# range 0 .. 31;
      INT_RAW      at 16#C0# range 0 .. 31;
      INT_ST       at 16#C4# range 0 .. 31;
      INT_ENA      at 16#C8# range 0 .. 31;
      INT_CLR      at 16#CC# range 0 .. 31;
      CONF         at 16#D0# range 0 .. 31;
      DATE         at 16#FC# range 0 .. 31;
   end record;

   --  LED Control PWM (Pulse Width Modulation)
   LEDC_Periph : aliased LEDC_Peripheral
     with Import, Address => LEDC_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.LEDC;
