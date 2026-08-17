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

package ESP32S3_Registers.SENS is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype SAR_READER1_CTRL_SAR_SAR1_CLK_DIV_Field is ESP32S3_Registers.Byte;
   subtype SAR_READER1_CTRL_SAR_SAR1_SAMPLE_NUM_Field is
     ESP32S3_Registers.Byte;

   --  configure saradc1 reader
   type SAR_READER1_CTRL_Register is record
      --  clock divider
      SAR_SAR1_CLK_DIV    : SAR_READER1_CTRL_SAR_SAR1_CLK_DIV_Field := 16#2#;
      --  unspecified
      Reserved_8_17       : ESP32S3_Registers.UInt10 := 16#0#;
      --  no public
      SAR_SAR1_CLK_GATED  : Boolean := True;
      --  no public
      SAR_SAR1_SAMPLE_NUM : SAR_READER1_CTRL_SAR_SAR1_SAMPLE_NUM_Field :=
        16#0#;
      --  unspecified
      Reserved_27_27      : ESP32S3_Registers.Bit := 16#0#;
      --  Invert SAR ADC1 data
      SAR_SAR1_DATA_INV   : Boolean := False;
      --  enable saradc1 to send out interrupt
      SAR_SAR1_INT_EN     : Boolean := True;
      --  unspecified
      Reserved_30_31      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_READER1_CTRL_Register use
     record
       SAR_SAR1_CLK_DIV at 0 range 0 .. 7;
       Reserved_8_17 at 0 range 8 .. 17;
       SAR_SAR1_CLK_GATED at 0 range 18 .. 18;
       SAR_SAR1_SAMPLE_NUM at 0 range 19 .. 26;
       Reserved_27_27 at 0 range 27 .. 27;
       SAR_SAR1_DATA_INV at 0 range 28 .. 28;
       SAR_SAR1_INT_EN at 0 range 29 .. 29;
       Reserved_30_31 at 0 range 30 .. 31;
     end record;

   subtype SAR_MEAS1_CTRL1_FORCE_XPD_AMP_Field is ESP32S3_Registers.UInt2;
   subtype SAR_MEAS1_CTRL1_AMP_RST_FB_FORCE_Field is ESP32S3_Registers.UInt2;
   subtype SAR_MEAS1_CTRL1_AMP_SHORT_REF_FORCE_Field is
     ESP32S3_Registers.UInt2;
   subtype SAR_MEAS1_CTRL1_AMP_SHORT_REF_GND_FORCE_Field is
     ESP32S3_Registers.UInt2;

   --  no public
   type SAR_MEAS1_CTRL1_Register is record
      --  unspecified
      Reserved_0_23           : ESP32S3_Registers.UInt24 := 16#0#;
      --  no public
      FORCE_XPD_AMP           : SAR_MEAS1_CTRL1_FORCE_XPD_AMP_Field := 16#0#;
      --  no public
      AMP_RST_FB_FORCE        : SAR_MEAS1_CTRL1_AMP_RST_FB_FORCE_Field :=
        16#0#;
      --  no public
      AMP_SHORT_REF_FORCE     : SAR_MEAS1_CTRL1_AMP_SHORT_REF_FORCE_Field :=
        16#0#;
      --  no public
      AMP_SHORT_REF_GND_FORCE :
        SAR_MEAS1_CTRL1_AMP_SHORT_REF_GND_FORCE_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_MEAS1_CTRL1_Register use
     record
       Reserved_0_23 at 0 range 0 .. 23;
       FORCE_XPD_AMP at 0 range 24 .. 25;
       AMP_RST_FB_FORCE at 0 range 26 .. 27;
       AMP_SHORT_REF_FORCE at 0 range 28 .. 29;
       AMP_SHORT_REF_GND_FORCE at 0 range 30 .. 31;
     end record;

   subtype SAR_MEAS1_CTRL2_MEAS1_DATA_SAR_Field is ESP32S3_Registers.UInt16;
   subtype SAR_MEAS1_CTRL2_SAR1_EN_PAD_Field is ESP32S3_Registers.UInt12;

   --  configure saradc1 controller
   type SAR_MEAS1_CTRL2_Register is record
      --  Read-only. SAR ADC1 data
      MEAS1_DATA_SAR    : SAR_MEAS1_CTRL2_MEAS1_DATA_SAR_Field := 16#0#;
      --  Read-only. SAR ADC1 conversion done indication
      MEAS1_DONE_SAR    : Boolean := False;
      --  SAR ADC1 controller (in RTC) starts conversion
      MEAS1_START_SAR   : Boolean := False;
      --  1: SAR ADC1 controller (in RTC) is started by SW
      MEAS1_START_FORCE : Boolean := False;
      --  SAR ADC1 pad enable bitmap
      SAR1_EN_PAD       : SAR_MEAS1_CTRL2_SAR1_EN_PAD_Field := 16#0#;
      --  1: SAR ADC1 pad enable bitmap is controlled by SW
      SAR1_EN_PAD_FORCE : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_MEAS1_CTRL2_Register use
     record
       MEAS1_DATA_SAR at 0 range 0 .. 15;
       MEAS1_DONE_SAR at 0 range 16 .. 16;
       MEAS1_START_SAR at 0 range 17 .. 17;
       MEAS1_START_FORCE at 0 range 18 .. 18;
       SAR1_EN_PAD at 0 range 19 .. 30;
       SAR1_EN_PAD_FORCE at 0 range 31 .. 31;
     end record;

   --  configure saradc1 controller
   type SAR_MEAS1_MUX_Register is record
      --  unspecified
      Reserved_0_30  : ESP32S3_Registers.UInt31 := 16#0#;
      --  1: SAR ADC1 controlled by DIG ADC1 CTRL
      SAR1_DIG_FORCE : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_MEAS1_MUX_Register use
     record
       Reserved_0_30 at 0 range 0 .. 30;
       SAR1_DIG_FORCE at 0 range 31 .. 31;
     end record;

   --  SAR_AMP_CTRL1_SAR_AMP_WAIT array element
   subtype SAR_AMP_CTRL1_SAR_AMP_WAIT_Element is ESP32S3_Registers.UInt16;

   --  SAR_AMP_CTRL1_SAR_AMP_WAIT array
   type SAR_AMP_CTRL1_SAR_AMP_WAIT_Field_Array is
     array (1 .. 2) of SAR_AMP_CTRL1_SAR_AMP_WAIT_Element
   with Component_Size => 16, Size => 32;

   --  no public
   type SAR_AMP_CTRL1_Register (As_Array : Boolean := False) is record
      case As_Array is
         when False =>
            --  SAR_AMP_WAIT as a value
            Val : ESP32S3_Registers.UInt32;

         when True =>
            --  SAR_AMP_WAIT as an array
            Arr : SAR_AMP_CTRL1_SAR_AMP_WAIT_Field_Array;
      end case;
   end record
   with
     Unchecked_Union,
     Size        => 32,
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_AMP_CTRL1_Register use
     record
       Val at 0 range 0 .. 31;
       Arr at 0 range 0 .. 31;
     end record;

   subtype SAR_AMP_CTRL2_SAR_AMP_WAIT3_Field is ESP32S3_Registers.UInt16;

   --  no public
   type SAR_AMP_CTRL2_Register is record
      --  no public
      SAR_SAR1_DAC_XPD_FSM_IDLE      : Boolean := False;
      --  no public
      SAR_XPD_SAR_AMP_FSM_IDLE       : Boolean := False;
      --  no public
      SAR_AMP_RST_FB_FSM_IDLE        : Boolean := False;
      --  no public
      SAR_AMP_SHORT_REF_FSM_IDLE     : Boolean := False;
      --  no public
      SAR_AMP_SHORT_REF_GND_FSM_IDLE : Boolean := False;
      --  no public
      SAR_XPD_SAR_FSM_IDLE           : Boolean := False;
      --  no public
      SAR_RSTB_FSM_IDLE              : Boolean := False;
      --  unspecified
      Reserved_7_15                  : ESP32S3_Registers.UInt9 := 16#0#;
      --  no public
      SAR_AMP_WAIT3                  : SAR_AMP_CTRL2_SAR_AMP_WAIT3_Field :=
        16#A#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_AMP_CTRL2_Register use
     record
       SAR_SAR1_DAC_XPD_FSM_IDLE at 0 range 0 .. 0;
       SAR_XPD_SAR_AMP_FSM_IDLE at 0 range 1 .. 1;
       SAR_AMP_RST_FB_FSM_IDLE at 0 range 2 .. 2;
       SAR_AMP_SHORT_REF_FSM_IDLE at 0 range 3 .. 3;
       SAR_AMP_SHORT_REF_GND_FSM_IDLE at 0 range 4 .. 4;
       SAR_XPD_SAR_FSM_IDLE at 0 range 5 .. 5;
       SAR_RSTB_FSM_IDLE at 0 range 6 .. 6;
       Reserved_7_15 at 0 range 7 .. 15;
       SAR_AMP_WAIT3 at 0 range 16 .. 31;
     end record;

   subtype SAR_AMP_CTRL3_SAR1_DAC_XPD_FSM_Field is ESP32S3_Registers.UInt4;
   subtype SAR_AMP_CTRL3_XPD_SAR_AMP_FSM_Field is ESP32S3_Registers.UInt4;
   subtype SAR_AMP_CTRL3_AMP_RST_FB_FSM_Field is ESP32S3_Registers.UInt4;
   subtype SAR_AMP_CTRL3_AMP_SHORT_REF_FSM_Field is ESP32S3_Registers.UInt4;
   subtype SAR_AMP_CTRL3_AMP_SHORT_REF_GND_FSM_Field is
     ESP32S3_Registers.UInt4;
   subtype SAR_AMP_CTRL3_XPD_SAR_FSM_Field is ESP32S3_Registers.UInt4;
   subtype SAR_AMP_CTRL3_RSTB_FSM_Field is ESP32S3_Registers.UInt4;

   --  no public
   type SAR_AMP_CTRL3_Register is record
      --  no public
      SAR1_DAC_XPD_FSM      : SAR_AMP_CTRL3_SAR1_DAC_XPD_FSM_Field := 16#3#;
      --  no public
      XPD_SAR_AMP_FSM       : SAR_AMP_CTRL3_XPD_SAR_AMP_FSM_Field := 16#F#;
      --  no public
      AMP_RST_FB_FSM        : SAR_AMP_CTRL3_AMP_RST_FB_FSM_Field := 16#8#;
      --  no public
      AMP_SHORT_REF_FSM     : SAR_AMP_CTRL3_AMP_SHORT_REF_FSM_Field := 16#3#;
      --  no public
      AMP_SHORT_REF_GND_FSM : SAR_AMP_CTRL3_AMP_SHORT_REF_GND_FSM_Field :=
        16#3#;
      --  no public
      XPD_SAR_FSM           : SAR_AMP_CTRL3_XPD_SAR_FSM_Field := 16#7#;
      --  no public
      RSTB_FSM              : SAR_AMP_CTRL3_RSTB_FSM_Field := 16#0#;
      --  unspecified
      Reserved_28_31        : ESP32S3_Registers.UInt4 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_AMP_CTRL3_Register use
     record
       SAR1_DAC_XPD_FSM at 0 range 0 .. 3;
       XPD_SAR_AMP_FSM at 0 range 4 .. 7;
       AMP_RST_FB_FSM at 0 range 8 .. 11;
       AMP_SHORT_REF_FSM at 0 range 12 .. 15;
       AMP_SHORT_REF_GND_FSM at 0 range 16 .. 19;
       XPD_SAR_FSM at 0 range 20 .. 23;
       RSTB_FSM at 0 range 24 .. 27;
       Reserved_28_31 at 0 range 28 .. 31;
     end record;

   subtype SAR_READER2_CTRL_SAR_SAR2_CLK_DIV_Field is ESP32S3_Registers.Byte;
   subtype SAR_READER2_CTRL_SAR_SAR2_WAIT_ARB_CYCLE_Field is
     ESP32S3_Registers.UInt2;
   subtype SAR_READER2_CTRL_SAR_SAR2_SAMPLE_NUM_Field is
     ESP32S3_Registers.Byte;

   --  configure saradc2 reader
   type SAR_READER2_CTRL_Register is record
      --  clock divider
      SAR_SAR2_CLK_DIV        : SAR_READER2_CTRL_SAR_SAR2_CLK_DIV_Field :=
        16#2#;
      --  unspecified
      Reserved_8_15           : ESP32S3_Registers.Byte := 16#0#;
      --  wait arbit stable after sar_done
      SAR_SAR2_WAIT_ARB_CYCLE :
        SAR_READER2_CTRL_SAR_SAR2_WAIT_ARB_CYCLE_Field := 16#1#;
      --  ******* Description ***********
      SAR_SAR2_CLK_GATED      : Boolean := True;
      --  ******* Description ***********
      SAR_SAR2_SAMPLE_NUM     : SAR_READER2_CTRL_SAR_SAR2_SAMPLE_NUM_Field :=
        16#0#;
      --  unspecified
      Reserved_27_28          : ESP32S3_Registers.UInt2 := 16#0#;
      --  Invert SAR ADC2 data
      SAR_SAR2_DATA_INV       : Boolean := False;
      --  enable saradc2 to send out interrupt
      SAR_SAR2_INT_EN         : Boolean := True;
      --  unspecified
      Reserved_31_31          : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_READER2_CTRL_Register use
     record
       SAR_SAR2_CLK_DIV at 0 range 0 .. 7;
       Reserved_8_15 at 0 range 8 .. 15;
       SAR_SAR2_WAIT_ARB_CYCLE at 0 range 16 .. 17;
       SAR_SAR2_CLK_GATED at 0 range 18 .. 18;
       SAR_SAR2_SAMPLE_NUM at 0 range 19 .. 26;
       Reserved_27_28 at 0 range 27 .. 28;
       SAR_SAR2_DATA_INV at 0 range 29 .. 29;
       SAR_SAR2_INT_EN at 0 range 30 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   subtype SAR_MEAS2_CTRL1_SAR_SAR2_CNTL_STATE_Field is
     ESP32S3_Registers.UInt3;
   subtype SAR_MEAS2_CTRL1_SAR_SAR2_RSTB_FORCE_Field is
     ESP32S3_Registers.UInt2;
   subtype SAR_MEAS2_CTRL1_SAR_SAR2_STANDBY_WAIT_Field is
     ESP32S3_Registers.Byte;
   subtype SAR_MEAS2_CTRL1_SAR_SAR2_RSTB_WAIT_Field is ESP32S3_Registers.Byte;
   subtype SAR_MEAS2_CTRL1_SAR_SAR2_XPD_WAIT_Field is ESP32S3_Registers.Byte;

   --  configure saradc2 controller
   type SAR_MEAS2_CTRL1_Register is record
      --  Read-only. saradc2_cntl_fsm
      SAR_SAR2_CNTL_STATE   : SAR_MEAS2_CTRL1_SAR_SAR2_CNTL_STATE_Field :=
        16#0#;
      --  rtc control pwdet enable
      SAR_SAR2_PWDET_CAL_EN : Boolean := False;
      --  rtc control pkdet enable
      SAR_SAR2_PKDET_CAL_EN : Boolean := False;
      --  SAR2_EN_TEST
      SAR_SAR2_EN_TEST      : Boolean := False;
      --  no public
      SAR_SAR2_RSTB_FORCE   : SAR_MEAS2_CTRL1_SAR_SAR2_RSTB_FORCE_Field :=
        16#0#;
      --  no public
      SAR_SAR2_STANDBY_WAIT : SAR_MEAS2_CTRL1_SAR_SAR2_STANDBY_WAIT_Field :=
        16#2#;
      --  no public
      SAR_SAR2_RSTB_WAIT    : SAR_MEAS2_CTRL1_SAR_SAR2_RSTB_WAIT_Field :=
        16#2#;
      --  no public
      SAR_SAR2_XPD_WAIT     : SAR_MEAS2_CTRL1_SAR_SAR2_XPD_WAIT_Field := 16#7#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_MEAS2_CTRL1_Register use
     record
       SAR_SAR2_CNTL_STATE at 0 range 0 .. 2;
       SAR_SAR2_PWDET_CAL_EN at 0 range 3 .. 3;
       SAR_SAR2_PKDET_CAL_EN at 0 range 4 .. 4;
       SAR_SAR2_EN_TEST at 0 range 5 .. 5;
       SAR_SAR2_RSTB_FORCE at 0 range 6 .. 7;
       SAR_SAR2_STANDBY_WAIT at 0 range 8 .. 15;
       SAR_SAR2_RSTB_WAIT at 0 range 16 .. 23;
       SAR_SAR2_XPD_WAIT at 0 range 24 .. 31;
     end record;

   subtype SAR_MEAS2_CTRL2_MEAS2_DATA_SAR_Field is ESP32S3_Registers.UInt16;
   subtype SAR_MEAS2_CTRL2_SAR2_EN_PAD_Field is ESP32S3_Registers.UInt12;

   --  configure saradc2 controller
   type SAR_MEAS2_CTRL2_Register is record
      --  Read-only. SAR ADC2 data
      MEAS2_DATA_SAR    : SAR_MEAS2_CTRL2_MEAS2_DATA_SAR_Field := 16#0#;
      --  Read-only. SAR ADC2 conversion done indication
      MEAS2_DONE_SAR    : Boolean := False;
      --  SAR ADC2 controller (in RTC) starts conversion
      MEAS2_START_SAR   : Boolean := False;
      --  1: SAR ADC2 controller (in RTC) is started by SW
      MEAS2_START_FORCE : Boolean := False;
      --  SAR ADC2 pad enable bitmap
      SAR2_EN_PAD       : SAR_MEAS2_CTRL2_SAR2_EN_PAD_Field := 16#0#;
      --  1: SAR ADC2 pad enable bitmap is controlled by SW
      SAR2_EN_PAD_FORCE : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_MEAS2_CTRL2_Register use
     record
       MEAS2_DATA_SAR at 0 range 0 .. 15;
       MEAS2_DONE_SAR at 0 range 16 .. 16;
       MEAS2_START_SAR at 0 range 17 .. 17;
       MEAS2_START_FORCE at 0 range 18 .. 18;
       SAR2_EN_PAD at 0 range 19 .. 30;
       SAR2_EN_PAD_FORCE at 0 range 31 .. 31;
     end record;

   subtype SAR_MEAS2_MUX_SAR2_PWDET_CCT_Field is ESP32S3_Registers.UInt3;

   --  configure saradc2 controller
   type SAR_MEAS2_MUX_Register is record
      --  unspecified
      Reserved_0_27  : ESP32S3_Registers.UInt28 := 16#0#;
      --  SAR2_PWDET_CCT
      SAR2_PWDET_CCT : SAR_MEAS2_MUX_SAR2_PWDET_CCT_Field := 16#0#;
      --  in sleep, force to use rtc to control ADC
      SAR2_RTC_FORCE : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_MEAS2_MUX_Register use
     record
       Reserved_0_27 at 0 range 0 .. 27;
       SAR2_PWDET_CCT at 0 range 28 .. 30;
       SAR2_RTC_FORCE at 0 range 31 .. 31;
     end record;

   subtype SAR_POWER_XPD_SAR_FORCE_XPD_SAR_Field is ESP32S3_Registers.UInt2;

   --  configure power of saradc
   type SAR_POWER_XPD_SAR_Register is record
      --  unspecified
      Reserved_0_28 : ESP32S3_Registers.UInt29 := 16#0#;
      --  force power on/off saradc
      FORCE_XPD_SAR : SAR_POWER_XPD_SAR_FORCE_XPD_SAR_Field := 16#0#;
      --  no public
      SARCLK_EN     : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_POWER_XPD_SAR_Register use
     record
       Reserved_0_28 at 0 range 0 .. 28;
       FORCE_XPD_SAR at 0 range 29 .. 30;
       SARCLK_EN at 0 range 31 .. 31;
     end record;

   subtype SAR_SLAVE_ADDR1_SAR_I2C_SLAVE_ADDR1_Field is
     ESP32S3_Registers.UInt11;
   subtype SAR_SLAVE_ADDR1_SAR_I2C_SLAVE_ADDR0_Field is
     ESP32S3_Registers.UInt11;
   subtype SAR_SLAVE_ADDR1_SAR_SARADC_MEAS_STATUS_Field is
     ESP32S3_Registers.Byte;

   --  configure i2c slave address
   type SAR_SLAVE_ADDR1_Register is record
      --  configure i2c slave address1
      SAR_I2C_SLAVE_ADDR1    : SAR_SLAVE_ADDR1_SAR_I2C_SLAVE_ADDR1_Field :=
        16#0#;
      --  configure i2c slave address0
      SAR_I2C_SLAVE_ADDR0    : SAR_SLAVE_ADDR1_SAR_I2C_SLAVE_ADDR0_Field :=
        16#0#;
      --  Read-only. no public
      SAR_SARADC_MEAS_STATUS : SAR_SLAVE_ADDR1_SAR_SARADC_MEAS_STATUS_Field :=
        16#0#;
      --  unspecified
      Reserved_30_31         : ESP32S3_Registers.UInt2 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_SLAVE_ADDR1_Register use
     record
       SAR_I2C_SLAVE_ADDR1 at 0 range 0 .. 10;
       SAR_I2C_SLAVE_ADDR0 at 0 range 11 .. 21;
       SAR_SARADC_MEAS_STATUS at 0 range 22 .. 29;
       Reserved_30_31 at 0 range 30 .. 31;
     end record;

   subtype SAR_SLAVE_ADDR2_SAR_I2C_SLAVE_ADDR3_Field is
     ESP32S3_Registers.UInt11;
   subtype SAR_SLAVE_ADDR2_SAR_I2C_SLAVE_ADDR2_Field is
     ESP32S3_Registers.UInt11;

   --  configure i2c slave address
   type SAR_SLAVE_ADDR2_Register is record
      --  configure i2c slave address3
      SAR_I2C_SLAVE_ADDR3 : SAR_SLAVE_ADDR2_SAR_I2C_SLAVE_ADDR3_Field := 16#0#;
      --  configure i2c slave address2
      SAR_I2C_SLAVE_ADDR2 : SAR_SLAVE_ADDR2_SAR_I2C_SLAVE_ADDR2_Field := 16#0#;
      --  unspecified
      Reserved_22_31      : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_SLAVE_ADDR2_Register use
     record
       SAR_I2C_SLAVE_ADDR3 at 0 range 0 .. 10;
       SAR_I2C_SLAVE_ADDR2 at 0 range 11 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_SLAVE_ADDR3_SAR_I2C_SLAVE_ADDR5_Field is
     ESP32S3_Registers.UInt11;
   subtype SAR_SLAVE_ADDR3_SAR_I2C_SLAVE_ADDR4_Field is
     ESP32S3_Registers.UInt11;

   --  configure i2c slave address
   type SAR_SLAVE_ADDR3_Register is record
      --  configure i2c slave address5
      SAR_I2C_SLAVE_ADDR5 : SAR_SLAVE_ADDR3_SAR_I2C_SLAVE_ADDR5_Field := 16#0#;
      --  configure i2c slave address4
      SAR_I2C_SLAVE_ADDR4 : SAR_SLAVE_ADDR3_SAR_I2C_SLAVE_ADDR4_Field := 16#0#;
      --  unspecified
      Reserved_22_31      : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_SLAVE_ADDR3_Register use
     record
       SAR_I2C_SLAVE_ADDR5 at 0 range 0 .. 10;
       SAR_I2C_SLAVE_ADDR4 at 0 range 11 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_SLAVE_ADDR4_SAR_I2C_SLAVE_ADDR7_Field is
     ESP32S3_Registers.UInt11;
   subtype SAR_SLAVE_ADDR4_SAR_I2C_SLAVE_ADDR6_Field is
     ESP32S3_Registers.UInt11;

   --  configure i2c slave address
   type SAR_SLAVE_ADDR4_Register is record
      --  configure i2c slave address7
      SAR_I2C_SLAVE_ADDR7 : SAR_SLAVE_ADDR4_SAR_I2C_SLAVE_ADDR7_Field := 16#0#;
      --  configure i2c slave address6
      SAR_I2C_SLAVE_ADDR6 : SAR_SLAVE_ADDR4_SAR_I2C_SLAVE_ADDR6_Field := 16#0#;
      --  unspecified
      Reserved_22_31      : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_SLAVE_ADDR4_Register use
     record
       SAR_I2C_SLAVE_ADDR7 at 0 range 0 .. 10;
       SAR_I2C_SLAVE_ADDR6 at 0 range 11 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TSENS_CTRL_SAR_TSENS_OUT_Field is ESP32S3_Registers.Byte;
   subtype SAR_TSENS_CTRL_SAR_TSENS_CLK_DIV_Field is ESP32S3_Registers.Byte;

   --  configure tsens controller
   type SAR_TSENS_CTRL_Register is record
      --  Read-only. temperature sensor data out
      SAR_TSENS_OUT            : SAR_TSENS_CTRL_SAR_TSENS_OUT_Field := 16#0#;
      --  Read-only. indicate temperature sensor out ready
      SAR_TSENS_READY          : Boolean := False;
      --  unspecified
      Reserved_9_11            : ESP32S3_Registers.UInt3 := 16#0#;
      --  enable temperature sensor to send out interrupt
      SAR_TSENS_INT_EN         : Boolean := True;
      --  invert temperature sensor data
      SAR_TSENS_IN_INV         : Boolean := False;
      --  temperature sensor clock divider
      SAR_TSENS_CLK_DIV        : SAR_TSENS_CTRL_SAR_TSENS_CLK_DIV_Field :=
        16#6#;
      --  temperature sensor power up
      SAR_TSENS_POWER_UP       : Boolean := False;
      --  1: dump out & power up controlled by SW 0: by FSM
      SAR_TSENS_POWER_UP_FORCE : Boolean := False;
      --  temperature sensor dump out only active when reg_tsens_power_up_force
      --  = 1
      SAR_TSENS_DUMP_OUT       : Boolean := False;
      --  unspecified
      Reserved_25_31           : ESP32S3_Registers.UInt7 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TSENS_CTRL_Register use
     record
       SAR_TSENS_OUT at 0 range 0 .. 7;
       SAR_TSENS_READY at 0 range 8 .. 8;
       Reserved_9_11 at 0 range 9 .. 11;
       SAR_TSENS_INT_EN at 0 range 12 .. 12;
       SAR_TSENS_IN_INV at 0 range 13 .. 13;
       SAR_TSENS_CLK_DIV at 0 range 14 .. 21;
       SAR_TSENS_POWER_UP at 0 range 22 .. 22;
       SAR_TSENS_POWER_UP_FORCE at 0 range 23 .. 23;
       SAR_TSENS_DUMP_OUT at 0 range 24 .. 24;
       Reserved_25_31 at 0 range 25 .. 31;
     end record;

   subtype SAR_TSENS_CTRL2_SAR_TSENS_XPD_WAIT_Field is
     ESP32S3_Registers.UInt12;
   subtype SAR_TSENS_CTRL2_SAR_TSENS_XPD_FORCE_Field is
     ESP32S3_Registers.UInt2;

   --  configure tsens controller
   type SAR_TSENS_CTRL2_Register is record
      --  no public
      SAR_TSENS_XPD_WAIT  : SAR_TSENS_CTRL2_SAR_TSENS_XPD_WAIT_Field := 16#2#;
      --  no public
      SAR_TSENS_XPD_FORCE : SAR_TSENS_CTRL2_SAR_TSENS_XPD_FORCE_Field := 16#0#;
      --  no public
      SAR_TSENS_CLK_INV   : Boolean := True;
      --  unspecified
      Reserved_15_31      : ESP32S3_Registers.UInt17 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TSENS_CTRL2_Register use
     record
       SAR_TSENS_XPD_WAIT at 0 range 0 .. 11;
       SAR_TSENS_XPD_FORCE at 0 range 12 .. 13;
       SAR_TSENS_CLK_INV at 0 range 14 .. 14;
       Reserved_15_31 at 0 range 15 .. 31;
     end record;

   subtype SAR_I2C_CTRL_SAR_I2C_CTRL_Field is ESP32S3_Registers.UInt28;

   --  configure rtc i2c controller by sw
   type SAR_I2C_CTRL_Register is record
      --  I2C control data only active when reg_sar_i2c_start_force = 1
      SAR_I2C_CTRL        : SAR_I2C_CTRL_SAR_I2C_CTRL_Field := 16#0#;
      --  start I2C only active when reg_sar_i2c_start_force = 1
      SAR_I2C_START       : Boolean := False;
      --  1: I2C started by SW 0: I2C started by FSM
      SAR_I2C_START_FORCE : Boolean := False;
      --  unspecified
      Reserved_30_31      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_I2C_CTRL_Register use
     record
       SAR_I2C_CTRL at 0 range 0 .. 27;
       SAR_I2C_START at 0 range 28 .. 28;
       SAR_I2C_START_FORCE at 0 range 29 .. 29;
       Reserved_30_31 at 0 range 30 .. 31;
     end record;

   subtype SAR_TOUCH_CONF_SAR_TOUCH_OUTEN_Field is ESP32S3_Registers.UInt15;
   subtype SAR_TOUCH_CONF_SAR_TOUCH_DATA_SEL_Field is ESP32S3_Registers.UInt2;
   subtype SAR_TOUCH_CONF_SAR_TOUCH_APPROACH_PAD2_Field is
     ESP32S3_Registers.UInt4;
   subtype SAR_TOUCH_CONF_SAR_TOUCH_APPROACH_PAD1_Field is
     ESP32S3_Registers.UInt4;
   subtype SAR_TOUCH_CONF_SAR_TOUCH_APPROACH_PAD0_Field is
     ESP32S3_Registers.UInt4;

   --  configure touch controller
   type SAR_TOUCH_CONF_Register is record
      --  touch controller output enable
      SAR_TOUCH_OUTEN         : SAR_TOUCH_CONF_SAR_TOUCH_OUTEN_Field :=
        16#7FFF#;
      --  Write-only. clear all touch active status
      SAR_TOUCH_STATUS_CLR    : Boolean := False;
      --  3: smooth data 2: baseline 1,0: raw_data
      SAR_TOUCH_DATA_SEL      : SAR_TOUCH_CONF_SAR_TOUCH_DATA_SEL_Field :=
        16#0#;
      --  Read-only. touch_denoise_done
      SAR_TOUCH_DENOISE_END   : Boolean := False;
      --  Read-only. touch_unit_done
      SAR_TOUCH_UNIT_END      : Boolean := False;
      --  indicate which pad is approach pad2
      SAR_TOUCH_APPROACH_PAD2 : SAR_TOUCH_CONF_SAR_TOUCH_APPROACH_PAD2_Field :=
        16#F#;
      --  indicate which pad is approach pad1
      SAR_TOUCH_APPROACH_PAD1 : SAR_TOUCH_CONF_SAR_TOUCH_APPROACH_PAD1_Field :=
        16#F#;
      --  indicate which pad is approach pad0
      SAR_TOUCH_APPROACH_PAD0 : SAR_TOUCH_CONF_SAR_TOUCH_APPROACH_PAD0_Field :=
        16#F#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_CONF_Register use
     record
       SAR_TOUCH_OUTEN at 0 range 0 .. 14;
       SAR_TOUCH_STATUS_CLR at 0 range 15 .. 15;
       SAR_TOUCH_DATA_SEL at 0 range 16 .. 17;
       SAR_TOUCH_DENOISE_END at 0 range 18 .. 18;
       SAR_TOUCH_UNIT_END at 0 range 19 .. 19;
       SAR_TOUCH_APPROACH_PAD2 at 0 range 20 .. 23;
       SAR_TOUCH_APPROACH_PAD1 at 0 range 24 .. 27;
       SAR_TOUCH_APPROACH_PAD0 at 0 range 28 .. 31;
     end record;

   subtype SAR_TOUCH_DENOISE_DATA_Field is ESP32S3_Registers.UInt22;

   --  configure touch controller
   type SAR_TOUCH_DENOISE_Register is record
      --  Read-only. configure touch controller
      DATA           : SAR_TOUCH_DENOISE_DATA_Field;
      --  unspecified
      Reserved_22_31 : ESP32S3_Registers.UInt10;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_DENOISE_Register use
     record
       DATA at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES1_SAR_TOUCH_OUT_TH1_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES1_Register is record
      --  Finger threshold for touch pad 1
      SAR_TOUCH_OUT_TH1 : SAR_TOUCH_THRES1_SAR_TOUCH_OUT_TH1_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES1_Register use
     record
       SAR_TOUCH_OUT_TH1 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES2_SAR_TOUCH_OUT_TH2_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES2_Register is record
      --  Finger threshold for touch pad 2
      SAR_TOUCH_OUT_TH2 : SAR_TOUCH_THRES2_SAR_TOUCH_OUT_TH2_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES2_Register use
     record
       SAR_TOUCH_OUT_TH2 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES3_SAR_TOUCH_OUT_TH3_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES3_Register is record
      --  Finger threshold for touch pad 3
      SAR_TOUCH_OUT_TH3 : SAR_TOUCH_THRES3_SAR_TOUCH_OUT_TH3_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES3_Register use
     record
       SAR_TOUCH_OUT_TH3 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES4_SAR_TOUCH_OUT_TH4_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES4_Register is record
      --  Finger threshold for touch pad 4
      SAR_TOUCH_OUT_TH4 : SAR_TOUCH_THRES4_SAR_TOUCH_OUT_TH4_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES4_Register use
     record
       SAR_TOUCH_OUT_TH4 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES5_SAR_TOUCH_OUT_TH5_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES5_Register is record
      --  Finger threshold for touch pad 5
      SAR_TOUCH_OUT_TH5 : SAR_TOUCH_THRES5_SAR_TOUCH_OUT_TH5_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES5_Register use
     record
       SAR_TOUCH_OUT_TH5 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES6_SAR_TOUCH_OUT_TH6_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES6_Register is record
      --  Finger threshold for touch pad 6
      SAR_TOUCH_OUT_TH6 : SAR_TOUCH_THRES6_SAR_TOUCH_OUT_TH6_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES6_Register use
     record
       SAR_TOUCH_OUT_TH6 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES7_SAR_TOUCH_OUT_TH7_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES7_Register is record
      --  Finger threshold for touch pad 7
      SAR_TOUCH_OUT_TH7 : SAR_TOUCH_THRES7_SAR_TOUCH_OUT_TH7_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES7_Register use
     record
       SAR_TOUCH_OUT_TH7 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES8_SAR_TOUCH_OUT_TH8_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES8_Register is record
      --  Finger threshold for touch pad 8
      SAR_TOUCH_OUT_TH8 : SAR_TOUCH_THRES8_SAR_TOUCH_OUT_TH8_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES8_Register use
     record
       SAR_TOUCH_OUT_TH8 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES9_SAR_TOUCH_OUT_TH9_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES9_Register is record
      --  Finger threshold for touch pad 9
      SAR_TOUCH_OUT_TH9 : SAR_TOUCH_THRES9_SAR_TOUCH_OUT_TH9_Field := 16#0#;
      --  unspecified
      Reserved_22_31    : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES9_Register use
     record
       SAR_TOUCH_OUT_TH9 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES10_SAR_TOUCH_OUT_TH10_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES10_Register is record
      --  Finger threshold for touch pad 10
      SAR_TOUCH_OUT_TH10 : SAR_TOUCH_THRES10_SAR_TOUCH_OUT_TH10_Field := 16#0#;
      --  unspecified
      Reserved_22_31     : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES10_Register use
     record
       SAR_TOUCH_OUT_TH10 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES11_SAR_TOUCH_OUT_TH11_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES11_Register is record
      --  Finger threshold for touch pad 11
      SAR_TOUCH_OUT_TH11 : SAR_TOUCH_THRES11_SAR_TOUCH_OUT_TH11_Field := 16#0#;
      --  unspecified
      Reserved_22_31     : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES11_Register use
     record
       SAR_TOUCH_OUT_TH11 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES12_SAR_TOUCH_OUT_TH12_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES12_Register is record
      --  Finger threshold for touch pad 12
      SAR_TOUCH_OUT_TH12 : SAR_TOUCH_THRES12_SAR_TOUCH_OUT_TH12_Field := 16#0#;
      --  unspecified
      Reserved_22_31     : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES12_Register use
     record
       SAR_TOUCH_OUT_TH12 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES13_SAR_TOUCH_OUT_TH13_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES13_Register is record
      --  Finger threshold for touch pad 13
      SAR_TOUCH_OUT_TH13 : SAR_TOUCH_THRES13_SAR_TOUCH_OUT_TH13_Field := 16#0#;
      --  unspecified
      Reserved_22_31     : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES13_Register use
     record
       SAR_TOUCH_OUT_TH13 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_THRES14_SAR_TOUCH_OUT_TH14_Field is
     ESP32S3_Registers.UInt22;

   --  configure touch thres of touch pad
   type SAR_TOUCH_THRES14_Register is record
      --  Finger threshold for touch pad 14
      SAR_TOUCH_OUT_TH14 : SAR_TOUCH_THRES14_SAR_TOUCH_OUT_TH14_Field := 16#0#;
      --  unspecified
      Reserved_22_31     : ESP32S3_Registers.UInt10 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_THRES14_Register use
     record
       SAR_TOUCH_OUT_TH14 at 0 range 0 .. 21;
       Reserved_22_31 at 0 range 22 .. 31;
     end record;

   subtype SAR_TOUCH_CHN_ST_SAR_TOUCH_PAD_ACTIVE_Field is
     ESP32S3_Registers.UInt15;
   subtype SAR_TOUCH_CHN_ST_SAR_TOUCH_CHANNEL_CLR_Field is
     ESP32S3_Registers.UInt15;

   --  Get touch channel status
   type SAR_TOUCH_CHN_ST_Register is record
      --  Read-only. touch active status
      SAR_TOUCH_PAD_ACTIVE  : SAR_TOUCH_CHN_ST_SAR_TOUCH_PAD_ACTIVE_Field :=
        16#0#;
      --  Write-only. Clear touch channel
      SAR_TOUCH_CHANNEL_CLR : SAR_TOUCH_CHN_ST_SAR_TOUCH_CHANNEL_CLR_Field :=
        16#0#;
      --  unspecified
      Reserved_30_30        : ESP32S3_Registers.Bit := 16#0#;
      --  Read-only. get touch meas done
      SAR_TOUCH_MEAS_DONE   : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_CHN_ST_Register use
     record
       SAR_TOUCH_PAD_ACTIVE at 0 range 0 .. 14;
       SAR_TOUCH_CHANNEL_CLR at 0 range 15 .. 29;
       Reserved_30_30 at 0 range 30 .. 30;
       SAR_TOUCH_MEAS_DONE at 0 range 31 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS0_SAR_TOUCH_SCAN_CURR_Field is
     ESP32S3_Registers.UInt4;

   --  get touch scan status
   type SAR_TOUCH_STATUS0_Register is record
      --  unspecified
      Reserved_0_21       : ESP32S3_Registers.UInt22;
      --  Read-only. current sample channel
      SAR_TOUCH_SCAN_CURR : SAR_TOUCH_STATUS0_SAR_TOUCH_SCAN_CURR_Field;
      --  unspecified
      Reserved_26_31      : ESP32S3_Registers.UInt6;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS0_Register use
     record
       Reserved_0_21 at 0 range 0 .. 21;
       SAR_TOUCH_SCAN_CURR at 0 range 22 .. 25;
       Reserved_26_31 at 0 range 26 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS1_SAR_TOUCH_PAD1_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS1_SAR_TOUCH_PAD1_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 1
   type SAR_TOUCH_STATUS1_Register is record
      --  Read-only. touch data debounce of touch pad 1
      SAR_TOUCH_PAD1_DATA     : SAR_TOUCH_STATUS1_SAR_TOUCH_PAD1_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 1
      SAR_TOUCH_PAD1_DEBOUNCE :
        SAR_TOUCH_STATUS1_SAR_TOUCH_PAD1_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS1_Register use
     record
       SAR_TOUCH_PAD1_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD1_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS2_SAR_TOUCH_PAD2_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS2_SAR_TOUCH_PAD2_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 2
   type SAR_TOUCH_STATUS2_Register is record
      --  Read-only. touch data debounce of touch pad 2
      SAR_TOUCH_PAD2_DATA     : SAR_TOUCH_STATUS2_SAR_TOUCH_PAD2_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 2
      SAR_TOUCH_PAD2_DEBOUNCE :
        SAR_TOUCH_STATUS2_SAR_TOUCH_PAD2_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS2_Register use
     record
       SAR_TOUCH_PAD2_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD2_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS3_SAR_TOUCH_PAD3_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS3_SAR_TOUCH_PAD3_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 3
   type SAR_TOUCH_STATUS3_Register is record
      --  Read-only. touch data debounce of touch pad 3
      SAR_TOUCH_PAD3_DATA     : SAR_TOUCH_STATUS3_SAR_TOUCH_PAD3_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 3
      SAR_TOUCH_PAD3_DEBOUNCE :
        SAR_TOUCH_STATUS3_SAR_TOUCH_PAD3_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS3_Register use
     record
       SAR_TOUCH_PAD3_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD3_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS4_SAR_TOUCH_PAD4_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS4_SAR_TOUCH_PAD4_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 4
   type SAR_TOUCH_STATUS4_Register is record
      --  Read-only. touch data debounce of touch pad 4
      SAR_TOUCH_PAD4_DATA     : SAR_TOUCH_STATUS4_SAR_TOUCH_PAD4_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 4
      SAR_TOUCH_PAD4_DEBOUNCE :
        SAR_TOUCH_STATUS4_SAR_TOUCH_PAD4_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS4_Register use
     record
       SAR_TOUCH_PAD4_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD4_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS5_SAR_TOUCH_PAD5_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS5_SAR_TOUCH_PAD5_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 5
   type SAR_TOUCH_STATUS5_Register is record
      --  Read-only. touch data debounce of touch pad 5
      SAR_TOUCH_PAD5_DATA     : SAR_TOUCH_STATUS5_SAR_TOUCH_PAD5_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 5
      SAR_TOUCH_PAD5_DEBOUNCE :
        SAR_TOUCH_STATUS5_SAR_TOUCH_PAD5_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS5_Register use
     record
       SAR_TOUCH_PAD5_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD5_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS6_SAR_TOUCH_PAD6_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS6_SAR_TOUCH_PAD6_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 6
   type SAR_TOUCH_STATUS6_Register is record
      --  Read-only. touch data debounce of touch pad 6
      SAR_TOUCH_PAD6_DATA     : SAR_TOUCH_STATUS6_SAR_TOUCH_PAD6_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 6
      SAR_TOUCH_PAD6_DEBOUNCE :
        SAR_TOUCH_STATUS6_SAR_TOUCH_PAD6_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS6_Register use
     record
       SAR_TOUCH_PAD6_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD6_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS7_SAR_TOUCH_PAD7_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS7_SAR_TOUCH_PAD7_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 7
   type SAR_TOUCH_STATUS7_Register is record
      --  Read-only. touch data debounce of touch pad 7
      SAR_TOUCH_PAD7_DATA     : SAR_TOUCH_STATUS7_SAR_TOUCH_PAD7_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 7
      SAR_TOUCH_PAD7_DEBOUNCE :
        SAR_TOUCH_STATUS7_SAR_TOUCH_PAD7_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS7_Register use
     record
       SAR_TOUCH_PAD7_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD7_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS8_SAR_TOUCH_PAD8_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS8_SAR_TOUCH_PAD8_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 8
   type SAR_TOUCH_STATUS8_Register is record
      --  Read-only. touch data debounce of touch pad 8
      SAR_TOUCH_PAD8_DATA     : SAR_TOUCH_STATUS8_SAR_TOUCH_PAD8_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 8
      SAR_TOUCH_PAD8_DEBOUNCE :
        SAR_TOUCH_STATUS8_SAR_TOUCH_PAD8_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS8_Register use
     record
       SAR_TOUCH_PAD8_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD8_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS9_SAR_TOUCH_PAD9_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS9_SAR_TOUCH_PAD9_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 9
   type SAR_TOUCH_STATUS9_Register is record
      --  Read-only. touch data debounce of touch pad 9
      SAR_TOUCH_PAD9_DATA     : SAR_TOUCH_STATUS9_SAR_TOUCH_PAD9_DATA_Field;
      --  unspecified
      Reserved_22_28          : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 9
      SAR_TOUCH_PAD9_DEBOUNCE :
        SAR_TOUCH_STATUS9_SAR_TOUCH_PAD9_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS9_Register use
     record
       SAR_TOUCH_PAD9_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD9_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS10_SAR_TOUCH_PAD10_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS10_SAR_TOUCH_PAD10_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 10
   type SAR_TOUCH_STATUS10_Register is record
      --  Read-only. touch data debounce of touch pad 10
      SAR_TOUCH_PAD10_DATA     : SAR_TOUCH_STATUS10_SAR_TOUCH_PAD10_DATA_Field;
      --  unspecified
      Reserved_22_28           : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 10
      SAR_TOUCH_PAD10_DEBOUNCE :
        SAR_TOUCH_STATUS10_SAR_TOUCH_PAD10_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS10_Register use
     record
       SAR_TOUCH_PAD10_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD10_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS11_SAR_TOUCH_PAD11_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS11_SAR_TOUCH_PAD11_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 11
   type SAR_TOUCH_STATUS11_Register is record
      --  Read-only. touch data debounce of touch pad 11
      SAR_TOUCH_PAD11_DATA     : SAR_TOUCH_STATUS11_SAR_TOUCH_PAD11_DATA_Field;
      --  unspecified
      Reserved_22_28           : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 11
      SAR_TOUCH_PAD11_DEBOUNCE :
        SAR_TOUCH_STATUS11_SAR_TOUCH_PAD11_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS11_Register use
     record
       SAR_TOUCH_PAD11_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD11_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS12_SAR_TOUCH_PAD12_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS12_SAR_TOUCH_PAD12_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 12
   type SAR_TOUCH_STATUS12_Register is record
      --  Read-only. touch data debounce of touch pad 12
      SAR_TOUCH_PAD12_DATA     : SAR_TOUCH_STATUS12_SAR_TOUCH_PAD12_DATA_Field;
      --  unspecified
      Reserved_22_28           : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 12
      SAR_TOUCH_PAD12_DEBOUNCE :
        SAR_TOUCH_STATUS12_SAR_TOUCH_PAD12_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS12_Register use
     record
       SAR_TOUCH_PAD12_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD12_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS13_SAR_TOUCH_PAD13_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS13_SAR_TOUCH_PAD13_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 13
   type SAR_TOUCH_STATUS13_Register is record
      --  Read-only. touch data debounce of touch pad 13
      SAR_TOUCH_PAD13_DATA     : SAR_TOUCH_STATUS13_SAR_TOUCH_PAD13_DATA_Field;
      --  unspecified
      Reserved_22_28           : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 13
      SAR_TOUCH_PAD13_DEBOUNCE :
        SAR_TOUCH_STATUS13_SAR_TOUCH_PAD13_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS13_Register use
     record
       SAR_TOUCH_PAD13_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD13_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS14_SAR_TOUCH_PAD14_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS14_SAR_TOUCH_PAD14_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of touch pad 14
   type SAR_TOUCH_STATUS14_Register is record
      --  Read-only. touch data debounce of touch pad 14
      SAR_TOUCH_PAD14_DATA     : SAR_TOUCH_STATUS14_SAR_TOUCH_PAD14_DATA_Field;
      --  unspecified
      Reserved_22_28           : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of touch pad 14
      SAR_TOUCH_PAD14_DEBOUNCE :
        SAR_TOUCH_STATUS14_SAR_TOUCH_PAD14_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS14_Register use
     record
       SAR_TOUCH_PAD14_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_PAD14_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS15_SAR_TOUCH_SLP_DATA_Field is
     ESP32S3_Registers.UInt22;
   subtype SAR_TOUCH_STATUS15_SAR_TOUCH_SLP_DEBOUNCE_Field is
     ESP32S3_Registers.UInt3;

   --  touch channel status of sleep pad
   type SAR_TOUCH_STATUS15_Register is record
      --  Read-only. touch data debounce of sleep pad
      SAR_TOUCH_SLP_DATA     : SAR_TOUCH_STATUS15_SAR_TOUCH_SLP_DATA_Field;
      --  unspecified
      Reserved_22_28         : ESP32S3_Registers.UInt7;
      --  Read-only. touch current debounce of sleep pad
      SAR_TOUCH_SLP_DEBOUNCE : SAR_TOUCH_STATUS15_SAR_TOUCH_SLP_DEBOUNCE_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS15_Register use
     record
       SAR_TOUCH_SLP_DATA at 0 range 0 .. 21;
       Reserved_22_28 at 0 range 22 .. 28;
       SAR_TOUCH_SLP_DEBOUNCE at 0 range 29 .. 31;
     end record;

   subtype SAR_TOUCH_STATUS16_SAR_TOUCH_APPROACH_PAD2_CNT_Field is
     ESP32S3_Registers.Byte;
   subtype SAR_TOUCH_STATUS16_SAR_TOUCH_APPROACH_PAD1_CNT_Field is
     ESP32S3_Registers.Byte;
   subtype SAR_TOUCH_STATUS16_SAR_TOUCH_APPROACH_PAD0_CNT_Field is
     ESP32S3_Registers.Byte;
   subtype SAR_TOUCH_STATUS16_SAR_TOUCH_SLP_APPROACH_CNT_Field is
     ESP32S3_Registers.Byte;

   --  touch channel status of approach mode
   type SAR_TOUCH_STATUS16_Register is record
      --  Read-only. touch current approach count of approach pad2
      SAR_TOUCH_APPROACH_PAD2_CNT :
        SAR_TOUCH_STATUS16_SAR_TOUCH_APPROACH_PAD2_CNT_Field;
      --  Read-only. touch current approach count of approach pad1
      SAR_TOUCH_APPROACH_PAD1_CNT :
        SAR_TOUCH_STATUS16_SAR_TOUCH_APPROACH_PAD1_CNT_Field;
      --  Read-only. touch current approach count of approach pad0
      SAR_TOUCH_APPROACH_PAD0_CNT :
        SAR_TOUCH_STATUS16_SAR_TOUCH_APPROACH_PAD0_CNT_Field;
      --  Read-only. touch current approach count of slp pad
      SAR_TOUCH_SLP_APPROACH_CNT  :
        SAR_TOUCH_STATUS16_SAR_TOUCH_SLP_APPROACH_CNT_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_TOUCH_STATUS16_Register use
     record
       SAR_TOUCH_APPROACH_PAD2_CNT at 0 range 0 .. 7;
       SAR_TOUCH_APPROACH_PAD1_CNT at 0 range 8 .. 15;
       SAR_TOUCH_APPROACH_PAD0_CNT at 0 range 16 .. 23;
       SAR_TOUCH_SLP_APPROACH_CNT at 0 range 24 .. 31;
     end record;

   --  get cocpu status
   type SAR_COCPU_STATE_Register is record
      --  unspecified
      Reserved_0_24         : ESP32S3_Registers.UInt25 := 16#0#;
      --  Write-only. trigger cocpu debug registers
      SAR_COCPU_DBG_TRIGGER : Boolean := False;
      --  Read-only. check cocpu whether clk on
      SAR_COCPU_CLK_EN_ST   : Boolean := False;
      --  Read-only. check cocpu whether in reset state
      SAR_COCPU_RESET_N     : Boolean := False;
      --  Read-only. check cocpu whether in interrupt state
      SAR_COCPU_EOI         : Boolean := False;
      --  Read-only. check cocpu whether in trap state
      SAR_COCPU_TRAP        : Boolean := False;
      --  Read-only. check cocpu whether in ebreak
      SAR_COCPU_EBREAK      : Boolean := False;
      --  unspecified
      Reserved_31_31        : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_COCPU_STATE_Register use
     record
       Reserved_0_24 at 0 range 0 .. 24;
       SAR_COCPU_DBG_TRIGGER at 0 range 25 .. 25;
       SAR_COCPU_CLK_EN_ST at 0 range 26 .. 26;
       SAR_COCPU_RESET_N at 0 range 27 .. 27;
       SAR_COCPU_EOI at 0 range 28 .. 28;
       SAR_COCPU_TRAP at 0 range 29 .. 29;
       SAR_COCPU_EBREAK at 0 range 30 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   --  the interrupt raw of ulp
   type SAR_COCPU_INT_RAW_Register is record
      --  Read-only. int from touch done
      SAR_COCPU_TOUCH_DONE_INT_RAW               : Boolean;
      --  Read-only. int from touch inactive
      SAR_COCPU_TOUCH_INACTIVE_INT_RAW           : Boolean;
      --  Read-only. int from touch active
      SAR_COCPU_TOUCH_ACTIVE_INT_RAW             : Boolean;
      --  Read-only. int from saradc1
      SAR_COCPU_SARADC1_INT_RAW                  : Boolean;
      --  Read-only. int from saradc2
      SAR_COCPU_SARADC2_INT_RAW                  : Boolean;
      --  Read-only. int from tsens
      SAR_COCPU_TSENS_INT_RAW                    : Boolean;
      --  Read-only. int from start
      SAR_COCPU_START_INT_RAW                    : Boolean;
      --  Read-only. int from software
      SAR_COCPU_SW_INT_RAW                       : Boolean;
      --  Read-only. int from super watch dog
      SAR_COCPU_SWD_INT_RAW                      : Boolean;
      --  Read-only. int from timeout done
      SAR_COCPU_TOUCH_TIMEOUT_INT_RAW            : Boolean;
      --  Read-only. int from approach loop done
      SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_RAW : Boolean;
      --  Read-only. int from touch scan done
      SAR_COCPU_TOUCH_SCAN_DONE_INT_RAW          : Boolean;
      --  unspecified
      Reserved_12_31                             : ESP32S3_Registers.UInt20;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_COCPU_INT_RAW_Register use
     record
       SAR_COCPU_TOUCH_DONE_INT_RAW at 0 range 0 .. 0;
       SAR_COCPU_TOUCH_INACTIVE_INT_RAW at 0 range 1 .. 1;
       SAR_COCPU_TOUCH_ACTIVE_INT_RAW at 0 range 2 .. 2;
       SAR_COCPU_SARADC1_INT_RAW at 0 range 3 .. 3;
       SAR_COCPU_SARADC2_INT_RAW at 0 range 4 .. 4;
       SAR_COCPU_TSENS_INT_RAW at 0 range 5 .. 5;
       SAR_COCPU_START_INT_RAW at 0 range 6 .. 6;
       SAR_COCPU_SW_INT_RAW at 0 range 7 .. 7;
       SAR_COCPU_SWD_INT_RAW at 0 range 8 .. 8;
       SAR_COCPU_TOUCH_TIMEOUT_INT_RAW at 0 range 9 .. 9;
       SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_RAW at 0 range 10 .. 10;
       SAR_COCPU_TOUCH_SCAN_DONE_INT_RAW at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   --  the interrupt enable of ulp
   type SAR_COCPU_INT_ENA_Register is record
      --  int enable of touch done
      SAR_COCPU_TOUCH_DONE_INT_ENA               : Boolean := False;
      --  int enable of from touch inactive
      SAR_COCPU_TOUCH_INACTIVE_INT_ENA           : Boolean := False;
      --  int enable of touch active
      SAR_COCPU_TOUCH_ACTIVE_INT_ENA             : Boolean := False;
      --  int enable of from saradc1
      SAR_COCPU_SARADC1_INT_ENA                  : Boolean := False;
      --  int enable of from saradc2
      SAR_COCPU_SARADC2_INT_ENA                  : Boolean := False;
      --  int enable of tsens
      SAR_COCPU_TSENS_INT_ENA                    : Boolean := False;
      --  int enable of start
      SAR_COCPU_START_INT_ENA                    : Boolean := False;
      --  int enable of software
      SAR_COCPU_SW_INT_ENA                       : Boolean := False;
      --  int enable of super watch dog
      SAR_COCPU_SWD_INT_ENA                      : Boolean := False;
      --  int enable of timeout done
      SAR_COCPU_TOUCH_TIMEOUT_INT_ENA            : Boolean := False;
      --  int enable of approach loop done
      SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_ENA : Boolean := False;
      --  int enable of touch scan done
      SAR_COCPU_TOUCH_SCAN_DONE_INT_ENA          : Boolean := False;
      --  unspecified
      Reserved_12_31                             : ESP32S3_Registers.UInt20 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_COCPU_INT_ENA_Register use
     record
       SAR_COCPU_TOUCH_DONE_INT_ENA at 0 range 0 .. 0;
       SAR_COCPU_TOUCH_INACTIVE_INT_ENA at 0 range 1 .. 1;
       SAR_COCPU_TOUCH_ACTIVE_INT_ENA at 0 range 2 .. 2;
       SAR_COCPU_SARADC1_INT_ENA at 0 range 3 .. 3;
       SAR_COCPU_SARADC2_INT_ENA at 0 range 4 .. 4;
       SAR_COCPU_TSENS_INT_ENA at 0 range 5 .. 5;
       SAR_COCPU_START_INT_ENA at 0 range 6 .. 6;
       SAR_COCPU_SW_INT_ENA at 0 range 7 .. 7;
       SAR_COCPU_SWD_INT_ENA at 0 range 8 .. 8;
       SAR_COCPU_TOUCH_TIMEOUT_INT_ENA at 0 range 9 .. 9;
       SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_ENA at 0 range 10 .. 10;
       SAR_COCPU_TOUCH_SCAN_DONE_INT_ENA at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   --  the interrupt state of ulp
   type SAR_COCPU_INT_ST_Register is record
      --  Read-only. int state of touch done
      SAR_COCPU_TOUCH_DONE_INT_ST               : Boolean;
      --  Read-only. int state of from touch inactive
      SAR_COCPU_TOUCH_INACTIVE_INT_ST           : Boolean;
      --  Read-only. int state of touch active
      SAR_COCPU_TOUCH_ACTIVE_INT_ST             : Boolean;
      --  Read-only. int state of from saradc1
      SAR_COCPU_SARADC1_INT_ST                  : Boolean;
      --  Read-only. int state of from saradc2
      SAR_COCPU_SARADC2_INT_ST                  : Boolean;
      --  Read-only. int state of tsens
      SAR_COCPU_TSENS_INT_ST                    : Boolean;
      --  Read-only. int state of start
      SAR_COCPU_START_INT_ST                    : Boolean;
      --  Read-only. int state of software
      SAR_COCPU_SW_INT_ST                       : Boolean;
      --  Read-only. int state of super watch dog
      SAR_COCPU_SWD_INT_ST                      : Boolean;
      --  Read-only. int state of timeout done
      SAR_COCPU_TOUCH_TIMEOUT_INT_ST            : Boolean;
      --  Read-only. int state of approach loop done
      SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_ST : Boolean;
      --  Read-only. int state of touch scan done
      SAR_COCPU_TOUCH_SCAN_DONE_INT_ST          : Boolean;
      --  unspecified
      Reserved_12_31                            : ESP32S3_Registers.UInt20;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_COCPU_INT_ST_Register use
     record
       SAR_COCPU_TOUCH_DONE_INT_ST at 0 range 0 .. 0;
       SAR_COCPU_TOUCH_INACTIVE_INT_ST at 0 range 1 .. 1;
       SAR_COCPU_TOUCH_ACTIVE_INT_ST at 0 range 2 .. 2;
       SAR_COCPU_SARADC1_INT_ST at 0 range 3 .. 3;
       SAR_COCPU_SARADC2_INT_ST at 0 range 4 .. 4;
       SAR_COCPU_TSENS_INT_ST at 0 range 5 .. 5;
       SAR_COCPU_START_INT_ST at 0 range 6 .. 6;
       SAR_COCPU_SW_INT_ST at 0 range 7 .. 7;
       SAR_COCPU_SWD_INT_ST at 0 range 8 .. 8;
       SAR_COCPU_TOUCH_TIMEOUT_INT_ST at 0 range 9 .. 9;
       SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_ST at 0 range 10 .. 10;
       SAR_COCPU_TOUCH_SCAN_DONE_INT_ST at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   --  the interrupt clear of ulp
   type SAR_COCPU_INT_CLR_Register is record
      --  Write-only. int clear of touch done
      SAR_COCPU_TOUCH_DONE_INT_CLR               : Boolean := False;
      --  Write-only. int clear of from touch inactive
      SAR_COCPU_TOUCH_INACTIVE_INT_CLR           : Boolean := False;
      --  Write-only. int clear of touch active
      SAR_COCPU_TOUCH_ACTIVE_INT_CLR             : Boolean := False;
      --  Write-only. int clear of from saradc1
      SAR_COCPU_SARADC1_INT_CLR                  : Boolean := False;
      --  Write-only. int clear of from saradc2
      SAR_COCPU_SARADC2_INT_CLR                  : Boolean := False;
      --  Write-only. int clear of tsens
      SAR_COCPU_TSENS_INT_CLR                    : Boolean := False;
      --  Write-only. int clear of start
      SAR_COCPU_START_INT_CLR                    : Boolean := False;
      --  Write-only. int clear of software
      SAR_COCPU_SW_INT_CLR                       : Boolean := False;
      --  Write-only. int clear of super watch dog
      SAR_COCPU_SWD_INT_CLR                      : Boolean := False;
      --  Write-only. int clear of timeout done
      SAR_COCPU_TOUCH_TIMEOUT_INT_CLR            : Boolean := False;
      --  Write-only. int clear of approach loop done
      SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_CLR : Boolean := False;
      --  Write-only. int clear of touch scan done
      SAR_COCPU_TOUCH_SCAN_DONE_INT_CLR          : Boolean := False;
      --  unspecified
      Reserved_12_31                             : ESP32S3_Registers.UInt20 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_COCPU_INT_CLR_Register use
     record
       SAR_COCPU_TOUCH_DONE_INT_CLR at 0 range 0 .. 0;
       SAR_COCPU_TOUCH_INACTIVE_INT_CLR at 0 range 1 .. 1;
       SAR_COCPU_TOUCH_ACTIVE_INT_CLR at 0 range 2 .. 2;
       SAR_COCPU_SARADC1_INT_CLR at 0 range 3 .. 3;
       SAR_COCPU_SARADC2_INT_CLR at 0 range 4 .. 4;
       SAR_COCPU_TSENS_INT_CLR at 0 range 5 .. 5;
       SAR_COCPU_START_INT_CLR at 0 range 6 .. 6;
       SAR_COCPU_SW_INT_CLR at 0 range 7 .. 7;
       SAR_COCPU_SWD_INT_CLR at 0 range 8 .. 8;
       SAR_COCPU_TOUCH_TIMEOUT_INT_CLR at 0 range 9 .. 9;
       SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_CLR at 0 range 10 .. 10;
       SAR_COCPU_TOUCH_SCAN_DONE_INT_CLR at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   subtype SAR_COCPU_DEBUG_SAR_COCPU_PC_Field is ESP32S3_Registers.UInt13;
   subtype SAR_COCPU_DEBUG_SAR_COCPU_MEM_WEN_Field is ESP32S3_Registers.UInt4;
   subtype SAR_COCPU_DEBUG_SAR_COCPU_MEM_ADDR_Field is
     ESP32S3_Registers.UInt13;

   --  Ulp-riscv debug signal
   type SAR_COCPU_DEBUG_Register is record
      --  Read-only. cocpu Program counter
      SAR_COCPU_PC       : SAR_COCPU_DEBUG_SAR_COCPU_PC_Field;
      --  Read-only. cocpu mem valid output
      SAR_COCPU_MEM_VLD  : Boolean;
      --  Read-only. cocpu mem ready input
      SAR_COCPU_MEM_RDY  : Boolean;
      --  Read-only. cocpu mem write enable output
      SAR_COCPU_MEM_WEN  : SAR_COCPU_DEBUG_SAR_COCPU_MEM_WEN_Field;
      --  Read-only. cocpu mem address output
      SAR_COCPU_MEM_ADDR : SAR_COCPU_DEBUG_SAR_COCPU_MEM_ADDR_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_COCPU_DEBUG_Register use
     record
       SAR_COCPU_PC at 0 range 0 .. 12;
       SAR_COCPU_MEM_VLD at 0 range 13 .. 13;
       SAR_COCPU_MEM_RDY at 0 range 14 .. 14;
       SAR_COCPU_MEM_WEN at 0 range 15 .. 18;
       SAR_COCPU_MEM_ADDR at 0 range 19 .. 31;
     end record;

   --  no public
   type SAR_HALL_CTRL_Register is record
      --  unspecified
      Reserved_0_27    : ESP32S3_Registers.UInt28 := 16#0#;
      --  Power on hall sensor and connect to VP and VN
      XPD_HALL         : Boolean := False;
      --  1: XPD HALL is controlled by SW. 0: XPD HALL is controlled by FSM in
      --  ULP-coprocessor
      XPD_HALL_FORCE   : Boolean := True;
      --  Reverse phase of hall sensor
      HALL_PHASE       : Boolean := False;
      --  1: HALL PHASE is controlled by SW 0: HALL PHASE is controlled by FSM
      --  in ULP-coprocessor
      HALL_PHASE_FORCE : Boolean := True;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_HALL_CTRL_Register use
     record
       Reserved_0_27 at 0 range 0 .. 27;
       XPD_HALL at 0 range 28 .. 28;
       XPD_HALL_FORCE at 0 range 29 .. 29;
       HALL_PHASE at 0 range 30 .. 30;
       HALL_PHASE_FORCE at 0 range 31 .. 31;
     end record;

   --  the peri clock gate of rtc peri
   type SAR_PERI_CLK_GATE_CONF_Register is record
      --  unspecified
      Reserved_0_26  : ESP32S3_Registers.UInt27 := 16#0#;
      --  enable rtc i2c clock
      RTC_I2C_CLK_EN : Boolean := False;
      --  unspecified
      Reserved_28_28 : ESP32S3_Registers.Bit := 16#0#;
      --  enable tsens clock
      TSENS_CLK_EN   : Boolean := False;
      --  enbale saradc clock
      SARADC_CLK_EN  : Boolean := False;
      --  enable io_mux clock
      IOMUX_CLK_EN   : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_PERI_CLK_GATE_CONF_Register use
     record
       Reserved_0_26 at 0 range 0 .. 26;
       RTC_I2C_CLK_EN at 0 range 27 .. 27;
       Reserved_28_28 at 0 range 28 .. 28;
       TSENS_CLK_EN at 0 range 29 .. 29;
       SARADC_CLK_EN at 0 range 30 .. 30;
       IOMUX_CLK_EN at 0 range 31 .. 31;
     end record;

   --  the peri reset of rtc peri
   type SAR_PERI_RESET_CONF_Register is record
      --  unspecified
      Reserved_0_24     : ESP32S3_Registers.UInt25 := 16#0#;
      --  enable ulp-riscv reset
      SAR_COCPU_RESET   : Boolean := False;
      --  unspecified
      Reserved_26_26    : ESP32S3_Registers.Bit := 16#0#;
      --  Reserved.
      SAR_RTC_I2C_RESET : Boolean := False;
      --  unspecified
      Reserved_28_28    : ESP32S3_Registers.Bit := 16#0#;
      --  enbale saradc reset
      SAR_TSENS_RESET   : Boolean := False;
      --  enable io_mux reset
      SAR_SARADC_RESET  : Boolean := False;
      --  unspecified
      Reserved_31_31    : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_PERI_RESET_CONF_Register use
     record
       Reserved_0_24 at 0 range 0 .. 24;
       SAR_COCPU_RESET at 0 range 25 .. 25;
       Reserved_26_26 at 0 range 26 .. 26;
       SAR_RTC_I2C_RESET at 0 range 27 .. 27;
       Reserved_28_28 at 0 range 28 .. 28;
       SAR_TSENS_RESET at 0 range 29 .. 29;
       SAR_SARADC_RESET at 0 range 30 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   --  the interrupt enable of ulp
   type SAR_COCPU_INT_ENA_W1TS_Register is record
      --  Write-only. int enable of touch done
      SAR_COCPU_TOUCH_DONE_INT_ENA_W1TS               : Boolean := False;
      --  Write-only. int enable of from touch inactive
      SAR_COCPU_TOUCH_INACTIVE_INT_ENA_W1TS           : Boolean := False;
      --  Write-only. int enable of touch active
      SAR_COCPU_TOUCH_ACTIVE_INT_ENA_W1TS             : Boolean := False;
      --  Write-only. int enable of from saradc1
      SAR_COCPU_SARADC1_INT_ENA_W1TS                  : Boolean := False;
      --  Write-only. int enable of from saradc2
      SAR_COCPU_SARADC2_INT_ENA_W1TS                  : Boolean := False;
      --  Write-only. int enable of tsens
      SAR_COCPU_TSENS_INT_ENA_W1TS                    : Boolean := False;
      --  Write-only. int enable of start
      SAR_COCPU_START_INT_ENA_W1TS                    : Boolean := False;
      --  Write-only. int enable of software
      SAR_COCPU_SW_INT_ENA_W1TS                       : Boolean := False;
      --  Write-only. int enable of super watch dog
      SAR_COCPU_SWD_INT_ENA_W1TS                      : Boolean := False;
      --  Write-only. int enable of timeout done
      SAR_COCPU_TOUCH_TIMEOUT_INT_ENA_W1TS            : Boolean := False;
      --  Write-only. int enable of approach loop done
      SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_ENA_W1TS : Boolean := False;
      --  Write-only. int enable of touch scan done
      SAR_COCPU_TOUCH_SCAN_DONE_INT_ENA_W1TS          : Boolean := False;
      --  unspecified
      Reserved_12_31                                  :
        ESP32S3_Registers.UInt20 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_COCPU_INT_ENA_W1TS_Register use
     record
       SAR_COCPU_TOUCH_DONE_INT_ENA_W1TS at 0 range 0 .. 0;
       SAR_COCPU_TOUCH_INACTIVE_INT_ENA_W1TS at 0 range 1 .. 1;
       SAR_COCPU_TOUCH_ACTIVE_INT_ENA_W1TS at 0 range 2 .. 2;
       SAR_COCPU_SARADC1_INT_ENA_W1TS at 0 range 3 .. 3;
       SAR_COCPU_SARADC2_INT_ENA_W1TS at 0 range 4 .. 4;
       SAR_COCPU_TSENS_INT_ENA_W1TS at 0 range 5 .. 5;
       SAR_COCPU_START_INT_ENA_W1TS at 0 range 6 .. 6;
       SAR_COCPU_SW_INT_ENA_W1TS at 0 range 7 .. 7;
       SAR_COCPU_SWD_INT_ENA_W1TS at 0 range 8 .. 8;
       SAR_COCPU_TOUCH_TIMEOUT_INT_ENA_W1TS at 0 range 9 .. 9;
       SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_ENA_W1TS at 0 range 10 .. 10;
       SAR_COCPU_TOUCH_SCAN_DONE_INT_ENA_W1TS at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   --  the interrupt enable clear of ulp
   type SAR_COCPU_INT_ENA_W1TC_Register is record
      --  Write-only. Clear int enable of touch done
      SAR_COCPU_TOUCH_DONE_INT_ENA_W1TC               : Boolean := False;
      --  Write-only. Clear int enable of from touch inactive
      SAR_COCPU_TOUCH_INACTIVE_INT_ENA_W1TC           : Boolean := False;
      --  Write-only. Clear int enable of touch active
      SAR_COCPU_TOUCH_ACTIVE_INT_ENA_W1TC             : Boolean := False;
      --  Write-only. Clear int enable of from saradc1
      SAR_COCPU_SARADC1_INT_ENA_W1TC                  : Boolean := False;
      --  Write-only. Clear int enable of from saradc2
      SAR_COCPU_SARADC2_INT_ENA_W1TC                  : Boolean := False;
      --  Write-only. Clear int enable of tsens
      SAR_COCPU_TSENS_INT_ENA_W1TC                    : Boolean := False;
      --  Write-only. Clear int enable of start
      SAR_COCPU_START_INT_ENA_W1TC                    : Boolean := False;
      --  Write-only. Clear int enable of software
      SAR_COCPU_SW_INT_ENA_W1TC                       : Boolean := False;
      --  Write-only. Clear int enable of super watch dog
      SAR_COCPU_SWD_INT_ENA_W1TC                      : Boolean := False;
      --  Write-only. Clear int enable of timeout done
      SAR_COCPU_TOUCH_TIMEOUT_INT_ENA_W1TC            : Boolean := False;
      --  Write-only. Clear int enable of approach loop done
      SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_ENA_W1TC : Boolean := False;
      --  Write-only. Clear int enable of touch scan done
      SAR_COCPU_TOUCH_SCAN_DONE_INT_ENA_W1TC          : Boolean := False;
      --  unspecified
      Reserved_12_31                                  :
        ESP32S3_Registers.UInt20 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_COCPU_INT_ENA_W1TC_Register use
     record
       SAR_COCPU_TOUCH_DONE_INT_ENA_W1TC at 0 range 0 .. 0;
       SAR_COCPU_TOUCH_INACTIVE_INT_ENA_W1TC at 0 range 1 .. 1;
       SAR_COCPU_TOUCH_ACTIVE_INT_ENA_W1TC at 0 range 2 .. 2;
       SAR_COCPU_SARADC1_INT_ENA_W1TC at 0 range 3 .. 3;
       SAR_COCPU_SARADC2_INT_ENA_W1TC at 0 range 4 .. 4;
       SAR_COCPU_TSENS_INT_ENA_W1TC at 0 range 5 .. 5;
       SAR_COCPU_START_INT_ENA_W1TC at 0 range 6 .. 6;
       SAR_COCPU_SW_INT_ENA_W1TC at 0 range 7 .. 7;
       SAR_COCPU_SWD_INT_ENA_W1TC at 0 range 8 .. 8;
       SAR_COCPU_TOUCH_TIMEOUT_INT_ENA_W1TC at 0 range 9 .. 9;
       SAR_COCPU_TOUCH_APPROACH_LOOP_DONE_INT_ENA_W1TC at 0 range 10 .. 10;
       SAR_COCPU_TOUCH_SCAN_DONE_INT_ENA_W1TC at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   subtype SAR_DEBUG_CONF_SAR_DEBUG_BIT_SEL_Field is ESP32S3_Registers.UInt5;

   --  rtc peri debug configure
   type SAR_DEBUG_CONF_Register is record
      --  no public
      SAR_DEBUG_BIT_SEL : SAR_DEBUG_CONF_SAR_DEBUG_BIT_SEL_Field := 16#0#;
      --  unspecified
      Reserved_5_31     : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_DEBUG_CONF_Register use
     record
       SAR_DEBUG_BIT_SEL at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SAR_SARDATE_SAR_DATE_Field is ESP32S3_Registers.UInt28;

   --  version
   type SAR_SARDATE_Register is record
      --  version
      SAR_DATE       : SAR_SARDATE_SAR_DATE_Field := 16#2101180#;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_SARDATE_Register use
     record
       SAR_DATE at 0 range 0 .. 27;
       Reserved_28_31 at 0 range 28 .. 31;
     end record;

   -----------------
   -- Peripherals --
   -----------------

   --  SENS Peripheral
   type SENS_Peripheral is record
      --  configure saradc1 reader
      SAR_READER1_CTRL       : aliased SAR_READER1_CTRL_Register;
      --  get saradc1 reader controller status
      SAR_READER1_STATUS     : aliased ESP32S3_Registers.UInt32;
      --  no public
      SAR_MEAS1_CTRL1        : aliased SAR_MEAS1_CTRL1_Register;
      --  configure saradc1 controller
      SAR_MEAS1_CTRL2        : aliased SAR_MEAS1_CTRL2_Register;
      --  configure saradc1 controller
      SAR_MEAS1_MUX          : aliased SAR_MEAS1_MUX_Register;
      --  configure saradc1 controller
      SAR_ATTEN1             : aliased ESP32S3_Registers.UInt32;
      --  no public
      SAR_AMP_CTRL1          : aliased SAR_AMP_CTRL1_Register;
      --  no public
      SAR_AMP_CTRL2          : aliased SAR_AMP_CTRL2_Register;
      --  no public
      SAR_AMP_CTRL3          : aliased SAR_AMP_CTRL3_Register;
      --  configure saradc2 reader
      SAR_READER2_CTRL       : aliased SAR_READER2_CTRL_Register;
      --  get saradc1 reader controller status
      SAR_READER2_STATUS     : aliased ESP32S3_Registers.UInt32;
      --  configure saradc2 controller
      SAR_MEAS2_CTRL1        : aliased SAR_MEAS2_CTRL1_Register;
      --  configure saradc2 controller
      SAR_MEAS2_CTRL2        : aliased SAR_MEAS2_CTRL2_Register;
      --  configure saradc2 controller
      SAR_MEAS2_MUX          : aliased SAR_MEAS2_MUX_Register;
      --  configure saradc2 controller
      SAR_ATTEN2             : aliased ESP32S3_Registers.UInt32;
      --  configure power of saradc
      SAR_POWER_XPD_SAR      : aliased SAR_POWER_XPD_SAR_Register;
      --  configure i2c slave address
      SAR_SLAVE_ADDR1        : aliased SAR_SLAVE_ADDR1_Register;
      --  configure i2c slave address
      SAR_SLAVE_ADDR2        : aliased SAR_SLAVE_ADDR2_Register;
      --  configure i2c slave address
      SAR_SLAVE_ADDR3        : aliased SAR_SLAVE_ADDR3_Register;
      --  configure i2c slave address
      SAR_SLAVE_ADDR4        : aliased SAR_SLAVE_ADDR4_Register;
      --  configure tsens controller
      SAR_TSENS_CTRL         : aliased SAR_TSENS_CTRL_Register;
      --  configure tsens controller
      SAR_TSENS_CTRL2        : aliased SAR_TSENS_CTRL2_Register;
      --  configure rtc i2c controller by sw
      SAR_I2C_CTRL           : aliased SAR_I2C_CTRL_Register;
      --  configure touch controller
      SAR_TOUCH_CONF         : aliased SAR_TOUCH_CONF_Register;
      --  configure touch controller
      SAR_TOUCH_DENOISE      : aliased SAR_TOUCH_DENOISE_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES1       : aliased SAR_TOUCH_THRES1_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES2       : aliased SAR_TOUCH_THRES2_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES3       : aliased SAR_TOUCH_THRES3_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES4       : aliased SAR_TOUCH_THRES4_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES5       : aliased SAR_TOUCH_THRES5_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES6       : aliased SAR_TOUCH_THRES6_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES7       : aliased SAR_TOUCH_THRES7_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES8       : aliased SAR_TOUCH_THRES8_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES9       : aliased SAR_TOUCH_THRES9_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES10      : aliased SAR_TOUCH_THRES10_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES11      : aliased SAR_TOUCH_THRES11_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES12      : aliased SAR_TOUCH_THRES12_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES13      : aliased SAR_TOUCH_THRES13_Register;
      --  configure touch thres of touch pad
      SAR_TOUCH_THRES14      : aliased SAR_TOUCH_THRES14_Register;
      --  Get touch channel status
      SAR_TOUCH_CHN_ST       : aliased SAR_TOUCH_CHN_ST_Register;
      --  get touch scan status
      SAR_TOUCH_STATUS0      : aliased SAR_TOUCH_STATUS0_Register;
      --  touch channel status of touch pad 1
      SAR_TOUCH_STATUS1      : aliased SAR_TOUCH_STATUS1_Register;
      --  touch channel status of touch pad 2
      SAR_TOUCH_STATUS2      : aliased SAR_TOUCH_STATUS2_Register;
      --  touch channel status of touch pad 3
      SAR_TOUCH_STATUS3      : aliased SAR_TOUCH_STATUS3_Register;
      --  touch channel status of touch pad 4
      SAR_TOUCH_STATUS4      : aliased SAR_TOUCH_STATUS4_Register;
      --  touch channel status of touch pad 5
      SAR_TOUCH_STATUS5      : aliased SAR_TOUCH_STATUS5_Register;
      --  touch channel status of touch pad 6
      SAR_TOUCH_STATUS6      : aliased SAR_TOUCH_STATUS6_Register;
      --  touch channel status of touch pad 7
      SAR_TOUCH_STATUS7      : aliased SAR_TOUCH_STATUS7_Register;
      --  touch channel status of touch pad 8
      SAR_TOUCH_STATUS8      : aliased SAR_TOUCH_STATUS8_Register;
      --  touch channel status of touch pad 9
      SAR_TOUCH_STATUS9      : aliased SAR_TOUCH_STATUS9_Register;
      --  touch channel status of touch pad 10
      SAR_TOUCH_STATUS10     : aliased SAR_TOUCH_STATUS10_Register;
      --  touch channel status of touch pad 11
      SAR_TOUCH_STATUS11     : aliased SAR_TOUCH_STATUS11_Register;
      --  touch channel status of touch pad 12
      SAR_TOUCH_STATUS12     : aliased SAR_TOUCH_STATUS12_Register;
      --  touch channel status of touch pad 13
      SAR_TOUCH_STATUS13     : aliased SAR_TOUCH_STATUS13_Register;
      --  touch channel status of touch pad 14
      SAR_TOUCH_STATUS14     : aliased SAR_TOUCH_STATUS14_Register;
      --  touch channel status of sleep pad
      SAR_TOUCH_STATUS15     : aliased SAR_TOUCH_STATUS15_Register;
      --  touch channel status of approach mode
      SAR_TOUCH_STATUS16     : aliased SAR_TOUCH_STATUS16_Register;
      --  get cocpu status
      SAR_COCPU_STATE        : aliased SAR_COCPU_STATE_Register;
      --  the interrupt raw of ulp
      SAR_COCPU_INT_RAW      : aliased SAR_COCPU_INT_RAW_Register;
      --  the interrupt enable of ulp
      SAR_COCPU_INT_ENA      : aliased SAR_COCPU_INT_ENA_Register;
      --  the interrupt state of ulp
      SAR_COCPU_INT_ST       : aliased SAR_COCPU_INT_ST_Register;
      --  the interrupt clear of ulp
      SAR_COCPU_INT_CLR      : aliased SAR_COCPU_INT_CLR_Register;
      --  Ulp-riscv debug signal
      SAR_COCPU_DEBUG        : aliased SAR_COCPU_DEBUG_Register;
      --  no public
      SAR_HALL_CTRL          : aliased SAR_HALL_CTRL_Register;
      --  no public
      SAR_NOUSE              : aliased ESP32S3_Registers.UInt32;
      --  the peri clock gate of rtc peri
      SAR_PERI_CLK_GATE_CONF : aliased SAR_PERI_CLK_GATE_CONF_Register;
      --  the peri reset of rtc peri
      SAR_PERI_RESET_CONF    : aliased SAR_PERI_RESET_CONF_Register;
      --  the interrupt enable of ulp
      SAR_COCPU_INT_ENA_W1TS : aliased SAR_COCPU_INT_ENA_W1TS_Register;
      --  the interrupt enable clear of ulp
      SAR_COCPU_INT_ENA_W1TC : aliased SAR_COCPU_INT_ENA_W1TC_Register;
      --  rtc peri debug configure
      SAR_DEBUG_CONF         : aliased SAR_DEBUG_CONF_Register;
      --  version
      SAR_SARDATE            : aliased SAR_SARDATE_Register;
   end record
   with Volatile;

   for SENS_Peripheral use
     record
       SAR_READER1_CTRL at 16#0# range 0 .. 31;
       SAR_READER1_STATUS at 16#4# range 0 .. 31;
       SAR_MEAS1_CTRL1 at 16#8# range 0 .. 31;
       SAR_MEAS1_CTRL2 at 16#C# range 0 .. 31;
       SAR_MEAS1_MUX at 16#10# range 0 .. 31;
       SAR_ATTEN1 at 16#14# range 0 .. 31;
       SAR_AMP_CTRL1 at 16#18# range 0 .. 31;
       SAR_AMP_CTRL2 at 16#1C# range 0 .. 31;
       SAR_AMP_CTRL3 at 16#20# range 0 .. 31;
       SAR_READER2_CTRL at 16#24# range 0 .. 31;
       SAR_READER2_STATUS at 16#28# range 0 .. 31;
       SAR_MEAS2_CTRL1 at 16#2C# range 0 .. 31;
       SAR_MEAS2_CTRL2 at 16#30# range 0 .. 31;
       SAR_MEAS2_MUX at 16#34# range 0 .. 31;
       SAR_ATTEN2 at 16#38# range 0 .. 31;
       SAR_POWER_XPD_SAR at 16#3C# range 0 .. 31;
       SAR_SLAVE_ADDR1 at 16#40# range 0 .. 31;
       SAR_SLAVE_ADDR2 at 16#44# range 0 .. 31;
       SAR_SLAVE_ADDR3 at 16#48# range 0 .. 31;
       SAR_SLAVE_ADDR4 at 16#4C# range 0 .. 31;
       SAR_TSENS_CTRL at 16#50# range 0 .. 31;
       SAR_TSENS_CTRL2 at 16#54# range 0 .. 31;
       SAR_I2C_CTRL at 16#58# range 0 .. 31;
       SAR_TOUCH_CONF at 16#5C# range 0 .. 31;
       SAR_TOUCH_DENOISE at 16#60# range 0 .. 31;
       SAR_TOUCH_THRES1 at 16#64# range 0 .. 31;
       SAR_TOUCH_THRES2 at 16#68# range 0 .. 31;
       SAR_TOUCH_THRES3 at 16#6C# range 0 .. 31;
       SAR_TOUCH_THRES4 at 16#70# range 0 .. 31;
       SAR_TOUCH_THRES5 at 16#74# range 0 .. 31;
       SAR_TOUCH_THRES6 at 16#78# range 0 .. 31;
       SAR_TOUCH_THRES7 at 16#7C# range 0 .. 31;
       SAR_TOUCH_THRES8 at 16#80# range 0 .. 31;
       SAR_TOUCH_THRES9 at 16#84# range 0 .. 31;
       SAR_TOUCH_THRES10 at 16#88# range 0 .. 31;
       SAR_TOUCH_THRES11 at 16#8C# range 0 .. 31;
       SAR_TOUCH_THRES12 at 16#90# range 0 .. 31;
       SAR_TOUCH_THRES13 at 16#94# range 0 .. 31;
       SAR_TOUCH_THRES14 at 16#98# range 0 .. 31;
       SAR_TOUCH_CHN_ST at 16#9C# range 0 .. 31;
       SAR_TOUCH_STATUS0 at 16#A0# range 0 .. 31;
       SAR_TOUCH_STATUS1 at 16#A4# range 0 .. 31;
       SAR_TOUCH_STATUS2 at 16#A8# range 0 .. 31;
       SAR_TOUCH_STATUS3 at 16#AC# range 0 .. 31;
       SAR_TOUCH_STATUS4 at 16#B0# range 0 .. 31;
       SAR_TOUCH_STATUS5 at 16#B4# range 0 .. 31;
       SAR_TOUCH_STATUS6 at 16#B8# range 0 .. 31;
       SAR_TOUCH_STATUS7 at 16#BC# range 0 .. 31;
       SAR_TOUCH_STATUS8 at 16#C0# range 0 .. 31;
       SAR_TOUCH_STATUS9 at 16#C4# range 0 .. 31;
       SAR_TOUCH_STATUS10 at 16#C8# range 0 .. 31;
       SAR_TOUCH_STATUS11 at 16#CC# range 0 .. 31;
       SAR_TOUCH_STATUS12 at 16#D0# range 0 .. 31;
       SAR_TOUCH_STATUS13 at 16#D4# range 0 .. 31;
       SAR_TOUCH_STATUS14 at 16#D8# range 0 .. 31;
       SAR_TOUCH_STATUS15 at 16#DC# range 0 .. 31;
       SAR_TOUCH_STATUS16 at 16#E0# range 0 .. 31;
       SAR_COCPU_STATE at 16#E4# range 0 .. 31;
       SAR_COCPU_INT_RAW at 16#E8# range 0 .. 31;
       SAR_COCPU_INT_ENA at 16#EC# range 0 .. 31;
       SAR_COCPU_INT_ST at 16#F0# range 0 .. 31;
       SAR_COCPU_INT_CLR at 16#F4# range 0 .. 31;
       SAR_COCPU_DEBUG at 16#F8# range 0 .. 31;
       SAR_HALL_CTRL at 16#FC# range 0 .. 31;
       SAR_NOUSE at 16#100# range 0 .. 31;
       SAR_PERI_CLK_GATE_CONF at 16#104# range 0 .. 31;
       SAR_PERI_RESET_CONF at 16#108# range 0 .. 31;
       SAR_COCPU_INT_ENA_W1TS at 16#10C# range 0 .. 31;
       SAR_COCPU_INT_ENA_W1TC at 16#110# range 0 .. 31;
       SAR_DEBUG_CONF at 16#114# range 0 .. 31;
       SAR_SARDATE at 16#1FC# range 0 .. 31;
     end record;

   --  SENS Peripheral
   SENS_Periph : aliased SENS_Peripheral
   with Import, Address => SENS_Base;

end ESP32S3_Registers.SENS;
