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

package ESP32S3_Registers.RTC_IO is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype RTC_GPIO_OUT_DATA_Field is ESP32S3_Registers.UInt22;

   --  RTC GPIO 0 ~ 21 output data register
   type RTC_GPIO_OUT_Register is record
      --  unspecified
      Reserved_0_9 : ESP32S3_Registers.UInt10 := 16#0#;
      --  RTC GPIO 0 ~ 21 output data
      DATA         : RTC_GPIO_OUT_DATA_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_OUT_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       DATA at 0 range 10 .. 31;
     end record;

   subtype RTC_GPIO_OUT_W1TS_RTC_GPIO_OUT_DATA_W1TS_Field is
     ESP32S3_Registers.UInt22;

   --  one set RTC GPIO output data
   type RTC_GPIO_OUT_W1TS_Register is record
      --  unspecified
      Reserved_0_9           : ESP32S3_Registers.UInt10 := 16#0#;
      --  Write-only. RTC GPIO 0 ~ 21 output data write 1 to set
      RTC_GPIO_OUT_DATA_W1TS :
        RTC_GPIO_OUT_W1TS_RTC_GPIO_OUT_DATA_W1TS_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_OUT_W1TS_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       RTC_GPIO_OUT_DATA_W1TS at 0 range 10 .. 31;
     end record;

   subtype RTC_GPIO_OUT_W1TC_RTC_GPIO_OUT_DATA_W1TC_Field is
     ESP32S3_Registers.UInt22;

   --  one clear RTC GPIO output data
   type RTC_GPIO_OUT_W1TC_Register is record
      --  unspecified
      Reserved_0_9           : ESP32S3_Registers.UInt10 := 16#0#;
      --  Write-only. RTC GPIO 0 ~ 21 output data write 1 to clear
      RTC_GPIO_OUT_DATA_W1TC :
        RTC_GPIO_OUT_W1TC_RTC_GPIO_OUT_DATA_W1TC_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_OUT_W1TC_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       RTC_GPIO_OUT_DATA_W1TC at 0 range 10 .. 31;
     end record;

   subtype RTC_GPIO_ENABLE_RTC_GPIO_ENABLE_Field is ESP32S3_Registers.UInt22;

   --  Configure RTC GPIO output enable
   type RTC_GPIO_ENABLE_Register is record
      --  unspecified
      Reserved_0_9    : ESP32S3_Registers.UInt10 := 16#0#;
      --  RTC GPIO 0 ~ 21 enable
      RTC_GPIO_ENABLE : RTC_GPIO_ENABLE_RTC_GPIO_ENABLE_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_ENABLE_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       RTC_GPIO_ENABLE at 0 range 10 .. 31;
     end record;

   subtype RTC_GPIO_ENABLE_W1TS_RTC_GPIO_ENABLE_W1TS_Field is
     ESP32S3_Registers.UInt22;

   --  one set RTC GPIO output enable
   type RTC_GPIO_ENABLE_W1TS_Register is record
      --  unspecified
      Reserved_0_9         : ESP32S3_Registers.UInt10 := 16#0#;
      --  Write-only. RTC GPIO 0 ~ 21 enable write 1 to set
      RTC_GPIO_ENABLE_W1TS : RTC_GPIO_ENABLE_W1TS_RTC_GPIO_ENABLE_W1TS_Field :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_ENABLE_W1TS_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       RTC_GPIO_ENABLE_W1TS at 0 range 10 .. 31;
     end record;

   subtype ENABLE_W1TC_ENABLE_W1TC_Field is ESP32S3_Registers.UInt22;

   --  one clear RTC GPIO output enable
   type ENABLE_W1TC_Register is record
      --  unspecified
      Reserved_0_9 : ESP32S3_Registers.UInt10 := 16#0#;
      --  Write-only. RTC GPIO 0 ~ 21 enable write 1 to clear
      ENABLE_W1TC  : ENABLE_W1TC_ENABLE_W1TC_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ENABLE_W1TC_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       ENABLE_W1TC at 0 range 10 .. 31;
     end record;

   subtype RTC_GPIO_STATUS_INT_Field is ESP32S3_Registers.UInt22;

   --  RTC GPIO 0 ~ 21 interrupt status
   type RTC_GPIO_STATUS_Register is record
      --  unspecified
      Reserved_0_9 : ESP32S3_Registers.UInt10 := 16#0#;
      --  RTC GPIO 0 ~ 21 interrupt status
      INT          : RTC_GPIO_STATUS_INT_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_STATUS_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       INT at 0 range 10 .. 31;
     end record;

   subtype RTC_GPIO_STATUS_W1TS_RTC_GPIO_STATUS_INT_W1TS_Field is
     ESP32S3_Registers.UInt22;

   --  One set RTC GPIO 0 ~ 21 interrupt status
   type RTC_GPIO_STATUS_W1TS_Register is record
      --  unspecified
      Reserved_0_9             : ESP32S3_Registers.UInt10 := 16#0#;
      --  Write-only. RTC GPIO 0 ~ 21 interrupt status write 1 to set
      RTC_GPIO_STATUS_INT_W1TS :
        RTC_GPIO_STATUS_W1TS_RTC_GPIO_STATUS_INT_W1TS_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_STATUS_W1TS_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       RTC_GPIO_STATUS_INT_W1TS at 0 range 10 .. 31;
     end record;

   subtype RTC_GPIO_STATUS_W1TC_RTC_GPIO_STATUS_INT_W1TC_Field is
     ESP32S3_Registers.UInt22;

   --  One clear RTC GPIO 0 ~ 21 interrupt status
   type RTC_GPIO_STATUS_W1TC_Register is record
      --  unspecified
      Reserved_0_9             : ESP32S3_Registers.UInt10 := 16#0#;
      --  Write-only. RTC GPIO 0 ~ 21 interrupt status write 1 to clear
      RTC_GPIO_STATUS_INT_W1TC :
        RTC_GPIO_STATUS_W1TC_RTC_GPIO_STATUS_INT_W1TC_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_STATUS_W1TC_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       RTC_GPIO_STATUS_INT_W1TC at 0 range 10 .. 31;
     end record;

   subtype RTC_GPIO_IN_NEXT_Field is ESP32S3_Registers.UInt22;

   --  RTC GPIO input data
   type RTC_GPIO_IN_Register is record
      --  unspecified
      Reserved_0_9 : ESP32S3_Registers.UInt10;
      --  Read-only. RTC GPIO input data
      NEXT         : RTC_GPIO_IN_NEXT_Field;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_GPIO_IN_Register use
     record
       Reserved_0_9 at 0 range 0 .. 9;
       NEXT at 0 range 10 .. 31;
     end record;

   subtype PIN_INT_TYPE_Field is ESP32S3_Registers.UInt3;

   --  configure RTC GPIO%s
   type PIN_Register is record
      --  unspecified
      Reserved_0_1   : ESP32S3_Registers.UInt2 := 16#0#;
      --  if set to 0: normal output, if set to 1: open drain
      PAD_DRIVER     : Boolean := False;
      --  unspecified
      Reserved_3_6   : ESP32S3_Registers.UInt4 := 16#0#;
      --  if set to 0: GPIO interrupt disable, if set to 1: rising edge
      --  trigger, if set to 2: falling edge trigger, if set to 3: any edge
      --  trigger, if set to 4: low level trigger, if set to 5: high level
      --  trigger
      INT_TYPE       : PIN_INT_TYPE_Field := 16#0#;
      --  RTC GPIO wakeup enable bit
      WAKEUP_ENABLE  : Boolean := False;
      --  unspecified
      Reserved_11_31 : ESP32S3_Registers.UInt21 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PIN_Register use
     record
       Reserved_0_1 at 0 range 0 .. 1;
       PAD_DRIVER at 0 range 2 .. 2;
       Reserved_3_6 at 0 range 3 .. 6;
       INT_TYPE at 0 range 7 .. 9;
       WAKEUP_ENABLE at 0 range 10 .. 10;
       Reserved_11_31 at 0 range 11 .. 31;
     end record;

   --  configure RTC GPIO%s
   type PIN_Registers is array (0 .. 21) of PIN_Register;

   --  RTC_DEBUG_SEL array element
   subtype RTC_DEBUG_SEL_Element is ESP32S3_Registers.UInt5;

   --  RTC_DEBUG_SEL array
   type RTC_DEBUG_SEL_Field_Array is array (0 .. 4) of RTC_DEBUG_SEL_Element
   with Component_Size => 5, Size => 25;

   --  Type definition for RTC_DEBUG_SEL
   type RTC_DEBUG_SEL_Field (As_Array : Boolean := False) is record
      case As_Array is
         when False =>
            --  RTC_DEBUG_SEL as a value
            Val : ESP32S3_Registers.UInt25;

         when True =>
            --  RTC_DEBUG_SEL as an array
            Arr : RTC_DEBUG_SEL_Field_Array;
      end case;
   end record
   with Unchecked_Union, Size => 25;

   for RTC_DEBUG_SEL_Field use
     record
       Val at 0 range 0 .. 24;
       Arr at 0 range 0 .. 24;
     end record;

   --  configure rtc debug
   type RTC_DEBUG_SEL_Register is record
      --  configure rtc debug
      RTC_DEBUG_SEL           : RTC_DEBUG_SEL_Field :=
        (As_Array => False, Val => 16#0#);
      --  configure rtc debug
      RTC_DEBUG_12M_NO_GATING : Boolean := False;
      --  unspecified
      Reserved_26_31          : ESP32S3_Registers.UInt6 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_DEBUG_SEL_Register use
     record
       RTC_DEBUG_SEL at 0 range 0 .. 24;
       RTC_DEBUG_12M_NO_GATING at 0 range 25 .. 25;
       Reserved_26_31 at 0 range 26 .. 31;
     end record;

   subtype TOUCH_PAD_FUN_SEL_Field is ESP32S3_Registers.UInt2;
   subtype TOUCH_PAD_DRV_Field is ESP32S3_Registers.UInt2;

   --  configure RTC PAD0
   type TOUCH_PAD_Register is record
      --  unspecified
      Reserved_0_12  : ESP32S3_Registers.UInt13 := 16#0#;
      --  input enable in work mode
      FUN_IE         : Boolean := False;
      --  output enable in sleep mode
      SLP_OE         : Boolean := False;
      --  input enable in sleep mode
      SLP_IE         : Boolean := False;
      --  1: enable sleep mode during sleep,0: no sleep mode
      SLP_SEL        : Boolean := False;
      --  function sel
      FUN_SEL        : TOUCH_PAD_FUN_SEL_Field := 16#0#;
      --  1: use RTC GPIO,0: use digital GPIO
      MUX_SEL        : Boolean := False;
      --  TOUCH_XPD
      XPD            : Boolean := False;
      --  TOUCH_TIE_OPT
      TIE_OPT        : Boolean := False;
      --  TOUCH_START
      START          : Boolean := False;
      --  unspecified
      Reserved_23_26 : ESP32S3_Registers.UInt4 := 16#0#;
      --  RUE
      RUE            : Boolean := False;
      --  RDE
      RDE            : Boolean := True;
      --  DRV
      DRV            : TOUCH_PAD_DRV_Field := 16#2#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_PAD_Register use
     record
       Reserved_0_12 at 0 range 0 .. 12;
       FUN_IE at 0 range 13 .. 13;
       SLP_OE at 0 range 14 .. 14;
       SLP_IE at 0 range 15 .. 15;
       SLP_SEL at 0 range 16 .. 16;
       FUN_SEL at 0 range 17 .. 18;
       MUX_SEL at 0 range 19 .. 19;
       XPD at 0 range 20 .. 20;
       TIE_OPT at 0 range 21 .. 21;
       START at 0 range 22 .. 22;
       Reserved_23_26 at 0 range 23 .. 26;
       RUE at 0 range 27 .. 27;
       RDE at 0 range 28 .. 28;
       DRV at 0 range 29 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   subtype XTAL_32P_PAD_X32P_FUN_SEL_Field is ESP32S3_Registers.UInt2;
   subtype XTAL_32P_PAD_X32P_DRV_Field is ESP32S3_Registers.UInt2;

   --  configure RTC PAD15
   type XTAL_32P_PAD_Register is record
      --  unspecified
      Reserved_0_12  : ESP32S3_Registers.UInt13 := 16#0#;
      --  input enable in work mode
      X32P_FUN_IE    : Boolean := False;
      --  output enable in sleep mode
      X32P_SLP_OE    : Boolean := False;
      --  input enable in sleep mode
      X32P_SLP_IE    : Boolean := False;
      --  1: enable sleep mode during sleep,0: no sleep mode
      X32P_SLP_SEL   : Boolean := False;
      --  function sel
      X32P_FUN_SEL   : XTAL_32P_PAD_X32P_FUN_SEL_Field := 16#0#;
      --  1: use RTC GPIO,0: use digital GPIO
      X32P_MUX_SEL   : Boolean := False;
      --  unspecified
      Reserved_20_26 : ESP32S3_Registers.UInt7 := 16#0#;
      --  RUE
      X32P_RUE       : Boolean := False;
      --  RDE
      X32P_RDE       : Boolean := False;
      --  DRV
      X32P_DRV       : XTAL_32P_PAD_X32P_DRV_Field := 16#2#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for XTAL_32P_PAD_Register use
     record
       Reserved_0_12 at 0 range 0 .. 12;
       X32P_FUN_IE at 0 range 13 .. 13;
       X32P_SLP_OE at 0 range 14 .. 14;
       X32P_SLP_IE at 0 range 15 .. 15;
       X32P_SLP_SEL at 0 range 16 .. 16;
       X32P_FUN_SEL at 0 range 17 .. 18;
       X32P_MUX_SEL at 0 range 19 .. 19;
       Reserved_20_26 at 0 range 20 .. 26;
       X32P_RUE at 0 range 27 .. 27;
       X32P_RDE at 0 range 28 .. 28;
       X32P_DRV at 0 range 29 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   subtype XTAL_32N_PAD_X32N_FUN_SEL_Field is ESP32S3_Registers.UInt2;
   subtype XTAL_32N_PAD_X32N_DRV_Field is ESP32S3_Registers.UInt2;

   --  configure RTC PAD16
   type XTAL_32N_PAD_Register is record
      --  unspecified
      Reserved_0_12  : ESP32S3_Registers.UInt13 := 16#0#;
      --  input enable in work mode
      X32N_FUN_IE    : Boolean := False;
      --  output enable in sleep mode
      X32N_SLP_OE    : Boolean := False;
      --  input enable in sleep mode
      X32N_SLP_IE    : Boolean := False;
      --  1: enable sleep mode during sleep,0: no sleep mode
      X32N_SLP_SEL   : Boolean := False;
      --  function sel
      X32N_FUN_SEL   : XTAL_32N_PAD_X32N_FUN_SEL_Field := 16#0#;
      --  1: use RTC GPIO,0: use digital GPIO
      X32N_MUX_SEL   : Boolean := False;
      --  unspecified
      Reserved_20_26 : ESP32S3_Registers.UInt7 := 16#0#;
      --  RUE
      X32N_RUE       : Boolean := False;
      --  RDE
      X32N_RDE       : Boolean := False;
      --  DRV
      X32N_DRV       : XTAL_32N_PAD_X32N_DRV_Field := 16#2#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for XTAL_32N_PAD_Register use
     record
       Reserved_0_12 at 0 range 0 .. 12;
       X32N_FUN_IE at 0 range 13 .. 13;
       X32N_SLP_OE at 0 range 14 .. 14;
       X32N_SLP_IE at 0 range 15 .. 15;
       X32N_SLP_SEL at 0 range 16 .. 16;
       X32N_FUN_SEL at 0 range 17 .. 18;
       X32N_MUX_SEL at 0 range 19 .. 19;
       Reserved_20_26 at 0 range 20 .. 26;
       X32N_RUE at 0 range 27 .. 27;
       X32N_RDE at 0 range 28 .. 28;
       X32N_DRV at 0 range 29 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   subtype PAD_DAC1_PDAC1_DAC_Field is ESP32S3_Registers.Byte;
   subtype PAD_DAC1_PDAC1_FUN_SEL_Field is ESP32S3_Registers.UInt2;
   subtype PAD_DAC1_PDAC1_DRV_Field is ESP32S3_Registers.UInt2;

   --  configure RTC PAD17
   type PAD_DAC1_Register is record
      --  unspecified
      Reserved_0_2        : ESP32S3_Registers.UInt3 := 16#0#;
      --  PDAC1_DAC
      PDAC1_DAC           : PAD_DAC1_PDAC1_DAC_Field := 16#0#;
      --  PDAC1_XPD_DAC
      PDAC1_XPD_DAC       : Boolean := False;
      --  1: use reg_pdac1_xpd_dac to control PDAC1_XPD_DAC,0: use SAR ADC FSM
      --  to control PDAC1_XPD_DAC
      PDAC1_DAC_XPD_FORCE : Boolean := False;
      --  input enable in work mode
      PDAC1_FUN_IE        : Boolean := False;
      --  output enable in sleep mode
      PDAC1_SLP_OE        : Boolean := False;
      --  input enable in sleep mode
      PDAC1_SLP_IE        : Boolean := False;
      --  1: enable sleep mode during sleep,0: no sleep mode
      PDAC1_SLP_SEL       : Boolean := False;
      --  PDAC1 function sel
      PDAC1_FUN_SEL       : PAD_DAC1_PDAC1_FUN_SEL_Field := 16#0#;
      --  1: use RTC GPIO,0: use digital GPIO
      PDAC1_MUX_SEL       : Boolean := False;
      --  unspecified
      Reserved_20_26      : ESP32S3_Registers.UInt7 := 16#0#;
      --  PDAC1_RUE
      PDAC1_RUE           : Boolean := False;
      --  PDAC1_RDE
      PDAC1_RDE           : Boolean := False;
      --  PDAC1_DRV
      PDAC1_DRV           : PAD_DAC1_PDAC1_DRV_Field := 16#2#;
      --  unspecified
      Reserved_31_31      : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PAD_DAC1_Register use
     record
       Reserved_0_2 at 0 range 0 .. 2;
       PDAC1_DAC at 0 range 3 .. 10;
       PDAC1_XPD_DAC at 0 range 11 .. 11;
       PDAC1_DAC_XPD_FORCE at 0 range 12 .. 12;
       PDAC1_FUN_IE at 0 range 13 .. 13;
       PDAC1_SLP_OE at 0 range 14 .. 14;
       PDAC1_SLP_IE at 0 range 15 .. 15;
       PDAC1_SLP_SEL at 0 range 16 .. 16;
       PDAC1_FUN_SEL at 0 range 17 .. 18;
       PDAC1_MUX_SEL at 0 range 19 .. 19;
       Reserved_20_26 at 0 range 20 .. 26;
       PDAC1_RUE at 0 range 27 .. 27;
       PDAC1_RDE at 0 range 28 .. 28;
       PDAC1_DRV at 0 range 29 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   subtype PAD_DAC2_PDAC2_DAC_Field is ESP32S3_Registers.Byte;
   subtype PAD_DAC2_PDAC2_FUN_SEL_Field is ESP32S3_Registers.UInt2;
   subtype PAD_DAC2_PDAC2_DRV_Field is ESP32S3_Registers.UInt2;

   --  configure RTC PAD18
   type PAD_DAC2_Register is record
      --  unspecified
      Reserved_0_2        : ESP32S3_Registers.UInt3 := 16#0#;
      --  PDAC2_DAC
      PDAC2_DAC           : PAD_DAC2_PDAC2_DAC_Field := 16#0#;
      --  PDAC2_XPD_DAC
      PDAC2_XPD_DAC       : Boolean := False;
      --  1: use reg_pdac2_xpd_dac to control PDAC2_XPD_DAC,0: use SAR ADC FSM
      --  to control PDAC2_XPD_DAC
      PDAC2_DAC_XPD_FORCE : Boolean := False;
      --  input enable in work mode
      PDAC2_FUN_IE        : Boolean := False;
      --  output enable in sleep mode
      PDAC2_SLP_OE        : Boolean := False;
      --  input enable in sleep mode
      PDAC2_SLP_IE        : Boolean := False;
      --  1: enable sleep mode during sleep,0: no sleep mode
      PDAC2_SLP_SEL       : Boolean := False;
      --  PDAC1 function sel
      PDAC2_FUN_SEL       : PAD_DAC2_PDAC2_FUN_SEL_Field := 16#0#;
      --  1: use RTC GPIO,0: use digital GPIO
      PDAC2_MUX_SEL       : Boolean := False;
      --  unspecified
      Reserved_20_26      : ESP32S3_Registers.UInt7 := 16#0#;
      --  PDAC2_RUE
      PDAC2_RUE           : Boolean := False;
      --  PDAC2_RDE
      PDAC2_RDE           : Boolean := False;
      --  PDAC2_DRV
      PDAC2_DRV           : PAD_DAC2_PDAC2_DRV_Field := 16#2#;
      --  unspecified
      Reserved_31_31      : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PAD_DAC2_Register use
     record
       Reserved_0_2 at 0 range 0 .. 2;
       PDAC2_DAC at 0 range 3 .. 10;
       PDAC2_XPD_DAC at 0 range 11 .. 11;
       PDAC2_DAC_XPD_FORCE at 0 range 12 .. 12;
       PDAC2_FUN_IE at 0 range 13 .. 13;
       PDAC2_SLP_OE at 0 range 14 .. 14;
       PDAC2_SLP_IE at 0 range 15 .. 15;
       PDAC2_SLP_SEL at 0 range 16 .. 16;
       PDAC2_FUN_SEL at 0 range 17 .. 18;
       PDAC2_MUX_SEL at 0 range 19 .. 19;
       Reserved_20_26 at 0 range 20 .. 26;
       PDAC2_RUE at 0 range 27 .. 27;
       PDAC2_RDE at 0 range 28 .. 28;
       PDAC2_DRV at 0 range 29 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   subtype RTC_PAD_FUN_SEL_Field is ESP32S3_Registers.UInt2;
   subtype RTC_PAD_DRV_Field is ESP32S3_Registers.UInt2;

   --  configure RTC PAD19
   type RTC_PAD_Register is record
      --  unspecified
      Reserved_0_12  : ESP32S3_Registers.UInt13 := 16#0#;
      --  input enable in work mode
      FUN_IE         : Boolean := False;
      --  output enable in sleep mode
      SLP_OE         : Boolean := False;
      --  input enable in sleep mode
      SLP_IE         : Boolean := False;
      --  1: enable sleep mode during sleep,0: no sleep mode
      SLP_SEL        : Boolean := False;
      --  function sel
      FUN_SEL        : RTC_PAD_FUN_SEL_Field := 16#0#;
      --  1: use RTC GPIO,0: use digital GPIO
      MUX_SEL        : Boolean := False;
      --  unspecified
      Reserved_20_26 : ESP32S3_Registers.UInt7 := 16#0#;
      --  RUE
      RUE            : Boolean := False;
      --  RDE
      RDE            : Boolean := True;
      --  DRV
      DRV            : RTC_PAD_DRV_Field := 16#2#;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_PAD_Register use
     record
       Reserved_0_12 at 0 range 0 .. 12;
       FUN_IE at 0 range 13 .. 13;
       SLP_OE at 0 range 14 .. 14;
       SLP_IE at 0 range 15 .. 15;
       SLP_SEL at 0 range 16 .. 16;
       FUN_SEL at 0 range 17 .. 18;
       MUX_SEL at 0 range 19 .. 19;
       Reserved_20_26 at 0 range 20 .. 26;
       RUE at 0 range 27 .. 27;
       RDE at 0 range 28 .. 28;
       DRV at 0 range 29 .. 30;
       Reserved_31_31 at 0 range 31 .. 31;
     end record;

   subtype EXT_WAKEUP0_SEL_Field is ESP32S3_Registers.UInt5;

   --  configure EXT0 wakeup
   type EXT_WAKEUP0_Register is record
      --  unspecified
      Reserved_0_26 : ESP32S3_Registers.UInt27 := 16#0#;
      --  ******* Description configure***
      SEL           : EXT_WAKEUP0_SEL_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for EXT_WAKEUP0_Register use
     record
       Reserved_0_26 at 0 range 0 .. 26;
       SEL at 0 range 27 .. 31;
     end record;

   subtype XTL_EXT_CTR_SEL_Field is ESP32S3_Registers.UInt5;

   --  configure gpio pd XTAL
   type XTL_EXT_CTR_Register is record
      --  unspecified
      Reserved_0_26 : ESP32S3_Registers.UInt27 := 16#0#;
      --  select RTC GPIO 0 ~ 17 to control XTAL
      SEL           : XTL_EXT_CTR_SEL_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for XTL_EXT_CTR_Register use
     record
       Reserved_0_26 at 0 range 0 .. 26;
       SEL at 0 range 27 .. 31;
     end record;

   subtype SAR_I2C_IO_SAR_DEBUG_BIT_SEL_Field is ESP32S3_Registers.UInt5;
   subtype SAR_I2C_IO_SAR_I2C_SCL_SEL_Field is ESP32S3_Registers.UInt2;
   subtype SAR_I2C_IO_SAR_I2C_SDA_SEL_Field is ESP32S3_Registers.UInt2;

   --  configure rtc i2c mux
   type SAR_I2C_IO_Register is record
      --  unspecified
      Reserved_0_22     : ESP32S3_Registers.UInt23 := 16#0#;
      --  ******* Description configure***
      SAR_DEBUG_BIT_SEL : SAR_I2C_IO_SAR_DEBUG_BIT_SEL_Field := 16#0#;
      --  ******* Description configure***
      SAR_I2C_SCL_SEL   : SAR_I2C_IO_SAR_I2C_SCL_SEL_Field := 16#0#;
      --  ******* Description configure***
      SAR_I2C_SDA_SEL   : SAR_I2C_IO_SAR_I2C_SDA_SEL_Field := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SAR_I2C_IO_Register use
     record
       Reserved_0_22 at 0 range 0 .. 22;
       SAR_DEBUG_BIT_SEL at 0 range 23 .. 27;
       SAR_I2C_SCL_SEL at 0 range 28 .. 29;
       SAR_I2C_SDA_SEL at 0 range 30 .. 31;
     end record;

   subtype TOUCH_CTRL_IO_TOUCH_BUFSEL_Field is ESP32S3_Registers.UInt4;

   --  configure touch pad bufmode
   type TOUCH_CTRL_Register is record
      --  BUF_SEL when touch work without fsm
      IO_TOUCH_BUFSEL  : TOUCH_CTRL_IO_TOUCH_BUFSEL_Field := 16#0#;
      --  BUF_MODE when touch work without fsm
      IO_TOUCH_BUFMODE : Boolean := False;
      --  unspecified
      Reserved_5_31    : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TOUCH_CTRL_Register use
     record
       IO_TOUCH_BUFSEL at 0 range 0 .. 3;
       IO_TOUCH_BUFMODE at 0 range 4 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt28;

   --  version
   type DATE_Register is record
      --  version
      DATE           : DATE_DATE_Field := 16#2101180#;
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

   --  Low-power Input/Output
   type RTC_IO_Peripheral is record
      --  RTC GPIO 0 ~ 21 output data register
      RTC_GPIO_OUT         : aliased RTC_GPIO_OUT_Register;
      --  one set RTC GPIO output data
      RTC_GPIO_OUT_W1TS    : aliased RTC_GPIO_OUT_W1TS_Register;
      --  one clear RTC GPIO output data
      RTC_GPIO_OUT_W1TC    : aliased RTC_GPIO_OUT_W1TC_Register;
      --  Configure RTC GPIO output enable
      RTC_GPIO_ENABLE      : aliased RTC_GPIO_ENABLE_Register;
      --  one set RTC GPIO output enable
      RTC_GPIO_ENABLE_W1TS : aliased RTC_GPIO_ENABLE_W1TS_Register;
      --  one clear RTC GPIO output enable
      ENABLE_W1TC          : aliased ENABLE_W1TC_Register;
      --  RTC GPIO 0 ~ 21 interrupt status
      RTC_GPIO_STATUS      : aliased RTC_GPIO_STATUS_Register;
      --  One set RTC GPIO 0 ~ 21 interrupt status
      RTC_GPIO_STATUS_W1TS : aliased RTC_GPIO_STATUS_W1TS_Register;
      --  One clear RTC GPIO 0 ~ 21 interrupt status
      RTC_GPIO_STATUS_W1TC : aliased RTC_GPIO_STATUS_W1TC_Register;
      --  RTC GPIO input data
      RTC_GPIO_IN          : aliased RTC_GPIO_IN_Register;
      --  configure RTC GPIO%s
      PIN                  : aliased PIN_Registers;
      --  configure rtc debug
      RTC_DEBUG_SEL        : aliased RTC_DEBUG_SEL_Register;
      --  configure RTC PAD0
      TOUCH_PAD0           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD1
      TOUCH_PAD1           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD2
      TOUCH_PAD2           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD3
      TOUCH_PAD3           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD4
      TOUCH_PAD4           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD5
      TOUCH_PAD5           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD6
      TOUCH_PAD6           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD7
      TOUCH_PAD7           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD8
      TOUCH_PAD8           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD9
      TOUCH_PAD9           : aliased TOUCH_PAD_Register;
      --  configure RTC PAD10
      TOUCH_PAD10          : aliased TOUCH_PAD_Register;
      --  configure RTC PAD11
      TOUCH_PAD11          : aliased TOUCH_PAD_Register;
      --  configure RTC PAD12
      TOUCH_PAD12          : aliased TOUCH_PAD_Register;
      --  configure RTC PAD13
      TOUCH_PAD13          : aliased TOUCH_PAD_Register;
      --  configure RTC PAD14
      TOUCH_PAD14          : aliased TOUCH_PAD_Register;
      --  configure RTC PAD15
      XTAL_32P_PAD         : aliased XTAL_32P_PAD_Register;
      --  configure RTC PAD16
      XTAL_32N_PAD         : aliased XTAL_32N_PAD_Register;
      --  configure RTC PAD17
      PAD_DAC1             : aliased PAD_DAC1_Register;
      --  configure RTC PAD18
      PAD_DAC2             : aliased PAD_DAC2_Register;
      --  configure RTC PAD19
      RTC_PAD19            : aliased RTC_PAD_Register;
      --  configure RTC PAD20
      RTC_PAD20            : aliased RTC_PAD_Register;
      --  configure RTC PAD21
      RTC_PAD21            : aliased RTC_PAD_Register;
      --  configure EXT0 wakeup
      EXT_WAKEUP0          : aliased EXT_WAKEUP0_Register;
      --  configure gpio pd XTAL
      XTL_EXT_CTR          : aliased XTL_EXT_CTR_Register;
      --  configure rtc i2c mux
      SAR_I2C_IO           : aliased SAR_I2C_IO_Register;
      --  configure touch pad bufmode
      TOUCH_CTRL           : aliased TOUCH_CTRL_Register;
      --  version
      DATE                 : aliased DATE_Register;
   end record
   with Volatile;

   for RTC_IO_Peripheral use
     record
       RTC_GPIO_OUT at 16#0# range 0 .. 31;
       RTC_GPIO_OUT_W1TS at 16#4# range 0 .. 31;
       RTC_GPIO_OUT_W1TC at 16#8# range 0 .. 31;
       RTC_GPIO_ENABLE at 16#C# range 0 .. 31;
       RTC_GPIO_ENABLE_W1TS at 16#10# range 0 .. 31;
       ENABLE_W1TC at 16#14# range 0 .. 31;
       RTC_GPIO_STATUS at 16#18# range 0 .. 31;
       RTC_GPIO_STATUS_W1TS at 16#1C# range 0 .. 31;
       RTC_GPIO_STATUS_W1TC at 16#20# range 0 .. 31;
       RTC_GPIO_IN at 16#24# range 0 .. 31;
       PIN at 16#28# range 0 .. 703;
       RTC_DEBUG_SEL at 16#80# range 0 .. 31;
       TOUCH_PAD0 at 16#84# range 0 .. 31;
       TOUCH_PAD1 at 16#88# range 0 .. 31;
       TOUCH_PAD2 at 16#8C# range 0 .. 31;
       TOUCH_PAD3 at 16#90# range 0 .. 31;
       TOUCH_PAD4 at 16#94# range 0 .. 31;
       TOUCH_PAD5 at 16#98# range 0 .. 31;
       TOUCH_PAD6 at 16#9C# range 0 .. 31;
       TOUCH_PAD7 at 16#A0# range 0 .. 31;
       TOUCH_PAD8 at 16#A4# range 0 .. 31;
       TOUCH_PAD9 at 16#A8# range 0 .. 31;
       TOUCH_PAD10 at 16#AC# range 0 .. 31;
       TOUCH_PAD11 at 16#B0# range 0 .. 31;
       TOUCH_PAD12 at 16#B4# range 0 .. 31;
       TOUCH_PAD13 at 16#B8# range 0 .. 31;
       TOUCH_PAD14 at 16#BC# range 0 .. 31;
       XTAL_32P_PAD at 16#C0# range 0 .. 31;
       XTAL_32N_PAD at 16#C4# range 0 .. 31;
       PAD_DAC1 at 16#C8# range 0 .. 31;
       PAD_DAC2 at 16#CC# range 0 .. 31;
       RTC_PAD19 at 16#D0# range 0 .. 31;
       RTC_PAD20 at 16#D4# range 0 .. 31;
       RTC_PAD21 at 16#D8# range 0 .. 31;
       EXT_WAKEUP0 at 16#DC# range 0 .. 31;
       XTL_EXT_CTR at 16#E0# range 0 .. 31;
       SAR_I2C_IO at 16#E4# range 0 .. 31;
       TOUCH_CTRL at 16#E8# range 0 .. 31;
       DATE at 16#1FC# range 0 .. 31;
     end record;

   --  Low-power Input/Output
   RTC_IO_Periph : aliased RTC_IO_Peripheral
   with Import, Address => RTC_IO_Base, Volatile,
        Async_Readers    => True,
        Async_Writers    => True,
        Effective_Reads  => False,
        Effective_Writes => True;

end ESP32S3_Registers.RTC_IO;
