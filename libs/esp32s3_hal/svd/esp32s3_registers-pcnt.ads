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

package ESP32S3_Registers.PCNT is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype U_CONF_FILTER_THRES_Field is ESP32S3_Registers.UInt10;
   subtype U_CONF_CH0_NEG_MODE_Field is ESP32S3_Registers.UInt2;
   subtype U_CONF_CH0_POS_MODE_Field is ESP32S3_Registers.UInt2;
   subtype U_CONF_CH0_HCTRL_MODE_Field is ESP32S3_Registers.UInt2;
   subtype U_CONF_CH0_LCTRL_MODE_Field is ESP32S3_Registers.UInt2;
   subtype U_CONF_CH1_NEG_MODE_Field is ESP32S3_Registers.UInt2;
   subtype U_CONF_CH1_POS_MODE_Field is ESP32S3_Registers.UInt2;
   subtype U_CONF_CH1_HCTRL_MODE_Field is ESP32S3_Registers.UInt2;
   subtype U_CONF_CH1_LCTRL_MODE_Field is ESP32S3_Registers.UInt2;

   --  Configuration register 0 for unit %s
   type U_CONF_Register is record
      --  This sets the maximum threshold, in APB_CLK cycles, for the filter.
      --  Any pulses with width less than this will be ignored when the filter
      --  is enabled.
      FILTER_THRES   : U_CONF_FILTER_THRES_Field := 16#10#;
      --  This is the enable bit for unit %s's input filter.
      FILTER_EN      : Boolean := True;
      --  This is the enable bit for unit %s's zero comparator.
      THR_ZERO_EN    : Boolean := True;
      --  This is the enable bit for unit %s's thr_h_lim comparator.
      THR_H_LIM_EN   : Boolean := True;
      --  This is the enable bit for unit %s's thr_l_lim comparator.
      THR_L_LIM_EN   : Boolean := True;
      --  This is the enable bit for unit %s's thres0 comparator.
      THR_THRES0_EN  : Boolean := False;
      --  This is the enable bit for unit %s's thres1 comparator.
      THR_THRES1_EN  : Boolean := False;
      --  This register sets the behavior when the signal input of channel 0
      --  detects a negative edge. 1: Increase the counter;2: Decrease the
      --  counter;0, 3: No effect on counter
      CH0_NEG_MODE   : U_CONF_CH0_NEG_MODE_Field := 16#0#;
      --  This register sets the behavior when the signal input of channel 0
      --  detects a positive edge. 1: Increase the counter;2: Decrease the
      --  counter;0, 3: No effect on counter
      CH0_POS_MODE   : U_CONF_CH0_POS_MODE_Field := 16#0#;
      --  This register configures how the CH%s_POS_MODE/CH%s_NEG_MODE settings
      --  will be modified when the control signal is high. 0: No
      --  modification;1: Invert behavior (increase -> decrease, decrease ->
      --  increase);2, 3: Inhibit counter modification
      CH0_HCTRL_MODE : U_CONF_CH0_HCTRL_MODE_Field := 16#0#;
      --  This register configures how the CH%s_POS_MODE/CH%s_NEG_MODE settings
      --  will be modified when the control signal is low. 0: No
      --  modification;1: Invert behavior (increase -> decrease, decrease ->
      --  increase);2, 3: Inhibit counter modification
      CH0_LCTRL_MODE : U_CONF_CH0_LCTRL_MODE_Field := 16#0#;
      --  This register sets the behavior when the signal input of channel 1
      --  detects a negative edge. 1: Increment the counter;2: Decrement the
      --  counter;0, 3: No effect on counter
      CH1_NEG_MODE   : U_CONF_CH1_NEG_MODE_Field := 16#0#;
      --  This register sets the behavior when the signal input of channel 1
      --  detects a positive edge. 1: Increment the counter;2: Decrement the
      --  counter;0, 3: No effect on counter
      CH1_POS_MODE   : U_CONF_CH1_POS_MODE_Field := 16#0#;
      --  This register configures how the CH%s_POS_MODE/CH%s_NEG_MODE settings
      --  will be modified when the control signal is high. 0: No
      --  modification;1: Invert behavior (increase -> decrease, decrease ->
      --  increase);2, 3: Inhibit counter modification
      CH1_HCTRL_MODE : U_CONF_CH1_HCTRL_MODE_Field := 16#0#;
      --  This register configures how the CH%s_POS_MODE/CH%s_NEG_MODE settings
      --  will be modified when the control signal is low. 0: No
      --  modification;1: Invert behavior (increase -> decrease, decrease ->
      --  increase);2, 3: Inhibit counter modification
      CH1_LCTRL_MODE : U_CONF_CH1_LCTRL_MODE_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for U_CONF_Register use record
      FILTER_THRES   at 0 range 0 .. 9;
      FILTER_EN      at 0 range 10 .. 10;
      THR_ZERO_EN    at 0 range 11 .. 11;
      THR_H_LIM_EN   at 0 range 12 .. 12;
      THR_L_LIM_EN   at 0 range 13 .. 13;
      THR_THRES0_EN  at 0 range 14 .. 14;
      THR_THRES1_EN  at 0 range 15 .. 15;
      CH0_NEG_MODE   at 0 range 16 .. 17;
      CH0_POS_MODE   at 0 range 18 .. 19;
      CH0_HCTRL_MODE at 0 range 20 .. 21;
      CH0_LCTRL_MODE at 0 range 22 .. 23;
      CH1_NEG_MODE   at 0 range 24 .. 25;
      CH1_POS_MODE   at 0 range 26 .. 27;
      CH1_HCTRL_MODE at 0 range 28 .. 29;
      CH1_LCTRL_MODE at 0 range 30 .. 31;
   end record;

   --  U_CONF_CNT_THRES array element
   subtype U_CONF_CNT_THRES_Element is ESP32S3_Registers.UInt16;

   --  U_CONF_CNT_THRES array
   type U_CONF_CNT_THRES_Field_Array is array (0 .. 1)
     of U_CONF_CNT_THRES_Element
     with Component_Size => 16, Size => 32;

   --  Configuration register 1 for unit %s
   type U_CONF_Register_1
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CNT_THRES as a value
            Val : ESP32S3_Registers.UInt32;
         when True =>
            --  CNT_THRES as an array
            Arr : U_CONF_CNT_THRES_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 32, Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for U_CONF_Register_1 use record
      Val at 0 range 0 .. 31;
      Arr at 0 range 0 .. 31;
   end record;

   subtype U_CONF_CNT_H_LIM_Field is ESP32S3_Registers.UInt16;
   subtype U_CONF_CNT_L_LIM_Field is ESP32S3_Registers.UInt16;

   --  Configuration register 2 for unit %s
   type U_CONF_Register_2 is record
      --  This register is used to configure the thr_h_lim value for unit %s.
      CNT_H_LIM : U_CONF_CNT_H_LIM_Field := 16#0#;
      --  This register is used to configure the thr_l_lim value for unit %s.
      CNT_L_LIM : U_CONF_CNT_L_LIM_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for U_CONF_Register_2 use record
      CNT_H_LIM at 0 range 0 .. 15;
      CNT_L_LIM at 0 range 16 .. 31;
   end record;

   subtype U_CNT_CNT_Field is ESP32S3_Registers.UInt16;

   --  Counter value for unit %s
   type U_CNT_Register is record
      --  Read-only. This register stores the current pulse count value for
      --  unit %s.
      CNT            : U_CNT_CNT_Field;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for U_CNT_Register use record
      CNT            at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   --  Counter value for unit %s
   type U_CNT_Registers is array (0 .. 3) of U_CNT_Register;

   --  INT_RAW_CNT_THR_EVENT_U array
   type INT_RAW_CNT_THR_EVENT_U_Field_Array is array (0 .. 3) of Boolean
     with Component_Size => 1, Size => 4;

   --  Type definition for INT_RAW_CNT_THR_EVENT_U
   type INT_RAW_CNT_THR_EVENT_U_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CNT_THR_EVENT_U as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  CNT_THR_EVENT_U as an array
            Arr : INT_RAW_CNT_THR_EVENT_U_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for INT_RAW_CNT_THR_EVENT_U_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Interrupt raw status register
   type INT_RAW_Register is record
      --  Read-only. The raw interrupt status bit for the
      --  PCNT_CNT_THR_EVENT_U0_INT interrupt.
      CNT_THR_EVENT_U : INT_RAW_CNT_THR_EVENT_U_Field;
      --  unspecified
      Reserved_4_31   : ESP32S3_Registers.UInt28;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_Register use record
      CNT_THR_EVENT_U at 0 range 0 .. 3;
      Reserved_4_31   at 0 range 4 .. 31;
   end record;

   --  INT_ST_CNT_THR_EVENT_U array
   type INT_ST_CNT_THR_EVENT_U_Field_Array is array (0 .. 3) of Boolean
     with Component_Size => 1, Size => 4;

   --  Type definition for INT_ST_CNT_THR_EVENT_U
   type INT_ST_CNT_THR_EVENT_U_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CNT_THR_EVENT_U as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  CNT_THR_EVENT_U as an array
            Arr : INT_ST_CNT_THR_EVENT_U_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for INT_ST_CNT_THR_EVENT_U_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Interrupt status register
   type INT_ST_Register is record
      --  Read-only. The masked interrupt status bit for the
      --  PCNT_CNT_THR_EVENT_U0_INT interrupt.
      CNT_THR_EVENT_U : INT_ST_CNT_THR_EVENT_U_Field;
      --  unspecified
      Reserved_4_31   : ESP32S3_Registers.UInt28;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ST_Register use record
      CNT_THR_EVENT_U at 0 range 0 .. 3;
      Reserved_4_31   at 0 range 4 .. 31;
   end record;

   --  INT_ENA_CNT_THR_EVENT_U array
   type INT_ENA_CNT_THR_EVENT_U_Field_Array is array (0 .. 3) of Boolean
     with Component_Size => 1, Size => 4;

   --  Type definition for INT_ENA_CNT_THR_EVENT_U
   type INT_ENA_CNT_THR_EVENT_U_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CNT_THR_EVENT_U as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  CNT_THR_EVENT_U as an array
            Arr : INT_ENA_CNT_THR_EVENT_U_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for INT_ENA_CNT_THR_EVENT_U_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Interrupt enable register
   type INT_ENA_Register is record
      --  The interrupt enable bit for the PCNT_CNT_THR_EVENT_U0_INT interrupt.
      CNT_THR_EVENT_U : INT_ENA_CNT_THR_EVENT_U_Field :=
                         (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_4_31   : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_Register use record
      CNT_THR_EVENT_U at 0 range 0 .. 3;
      Reserved_4_31   at 0 range 4 .. 31;
   end record;

   --  INT_CLR_CNT_THR_EVENT_U array
   type INT_CLR_CNT_THR_EVENT_U_Field_Array is array (0 .. 3) of Boolean
     with Component_Size => 1, Size => 4;

   --  Type definition for INT_CLR_CNT_THR_EVENT_U
   type INT_CLR_CNT_THR_EVENT_U_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CNT_THR_EVENT_U as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  CNT_THR_EVENT_U as an array
            Arr : INT_CLR_CNT_THR_EVENT_U_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for INT_CLR_CNT_THR_EVENT_U_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  Interrupt clear register
   type INT_CLR_Register is record
      --  Write-only. Set this bit to clear the PCNT_CNT_THR_EVENT_U0_INT
      --  interrupt.
      CNT_THR_EVENT_U : INT_CLR_CNT_THR_EVENT_U_Field :=
                         (As_Array => False, Val => 16#0#);
      --  unspecified
      Reserved_4_31   : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_Register use record
      CNT_THR_EVENT_U at 0 range 0 .. 3;
      Reserved_4_31   at 0 range 4 .. 31;
   end record;

   subtype U_STATUS_ZERO_MODE_Field is ESP32S3_Registers.UInt2;

   --  PNCT UNIT%s status register
   type U_STATUS_Register is record
      --  Read-only. The pulse counter status of PCNT_U%s corresponding to 0.
      --  0: pulse counter decreases from positive to 0. 1: pulse counter
      --  increases from negative to 0. 2: pulse counter is negative. 3: pulse
      --  counter is positive.
      ZERO_MODE     : U_STATUS_ZERO_MODE_Field;
      --  Read-only. The latched value of thres1 event of PCNT_U%s when
      --  threshold event interrupt is valid. 1: the current pulse counter
      --  equals to thres1 and thres1 event is valid. 0: others
      THRES1        : Boolean;
      --  Read-only. The latched value of thres0 event of PCNT_U%s when
      --  threshold event interrupt is valid. 1: the current pulse counter
      --  equals to thres0 and thres0 event is valid. 0: others
      THRES0        : Boolean;
      --  Read-only. The latched value of low limit event of PCNT_U%s when
      --  threshold event interrupt is valid. 1: the current pulse counter
      --  equals to thr_l_lim and low limit event is valid. 0: others
      L_LIM         : Boolean;
      --  Read-only. The latched value of high limit event of PCNT_U%s when
      --  threshold event interrupt is valid. 1: the current pulse counter
      --  equals to thr_h_lim and high limit event is valid. 0: others
      H_LIM         : Boolean;
      --  Read-only. The latched value of zero threshold event of PCNT_U%s when
      --  threshold event interrupt is valid. 1: the current pulse counter
      --  equals to 0 and zero threshold event is valid. 0: others
      ZERO          : Boolean;
      --  unspecified
      Reserved_7_31 : ESP32S3_Registers.UInt25;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for U_STATUS_Register use record
      ZERO_MODE     at 0 range 0 .. 1;
      THRES1        at 0 range 2 .. 2;
      THRES0        at 0 range 3 .. 3;
      L_LIM         at 0 range 4 .. 4;
      H_LIM         at 0 range 5 .. 5;
      ZERO          at 0 range 6 .. 6;
      Reserved_7_31 at 0 range 7 .. 31;
   end record;

   --  PNCT UNIT%s status register
   type U_STATUS_Registers is array (0 .. 3) of U_STATUS_Register;

   --  Control register for all counters
   type CTRL_Register is record
      --  Set this bit to clear unit 0's counter.
      CNT_RST_U0     : Boolean := True;
      --  Set this bit to freeze unit 0's counter.
      CNT_PAUSE_U0   : Boolean := False;
      --  Set this bit to clear unit 1's counter.
      CNT_RST_U1     : Boolean := False;
      --  Set this bit to freeze unit 1's counter.
      CNT_PAUSE_U1   : Boolean := False;
      --  Set this bit to clear unit 2's counter.
      CNT_RST_U2     : Boolean := False;
      --  Set this bit to freeze unit 2's counter.
      CNT_PAUSE_U2   : Boolean := False;
      --  Set this bit to clear unit 3's counter.
      CNT_RST_U3     : Boolean := False;
      --  Set this bit to freeze unit 3's counter.
      CNT_PAUSE_U3   : Boolean := False;
      --  unspecified
      Reserved_8_15  : ESP32S3_Registers.Byte := 16#0#;
      --  The registers clock gate enable signal of PCNT module. 1: the
      --  registers can be read and written by application. 0: the registers
      --  can not be read or written by application
      CLK_EN         : Boolean := False;
      --  unspecified
      Reserved_17_31 : ESP32S3_Registers.UInt15 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTRL_Register use record
      CNT_RST_U0     at 0 range 0 .. 0;
      CNT_PAUSE_U0   at 0 range 1 .. 1;
      CNT_RST_U1     at 0 range 2 .. 2;
      CNT_PAUSE_U1   at 0 range 3 .. 3;
      CNT_RST_U2     at 0 range 4 .. 4;
      CNT_PAUSE_U2   at 0 range 5 .. 5;
      CNT_RST_U3     at 0 range 6 .. 6;
      CNT_PAUSE_U3   at 0 range 7 .. 7;
      Reserved_8_15  at 0 range 8 .. 15;
      CLK_EN         at 0 range 16 .. 16;
      Reserved_17_31 at 0 range 17 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Pulse Count Controller
   type PCNT_Peripheral is record
      --  Configuration register 0 for unit %s
      U_CONF00 : aliased U_CONF_Register;
      --  Configuration register 1 for unit %s
      U_CONF10 : aliased U_CONF_Register_1;
      --  Configuration register 2 for unit %s
      U_CONF20 : aliased U_CONF_Register_2;
      --  Configuration register 0 for unit %s
      U_CONF01 : aliased U_CONF_Register;
      --  Configuration register 1 for unit %s
      U_CONF11 : aliased U_CONF_Register_1;
      --  Configuration register 2 for unit %s
      U_CONF21 : aliased U_CONF_Register_2;
      --  Configuration register 0 for unit %s
      U_CONF02 : aliased U_CONF_Register;
      --  Configuration register 1 for unit %s
      U_CONF12 : aliased U_CONF_Register_1;
      --  Configuration register 2 for unit %s
      U_CONF22 : aliased U_CONF_Register_2;
      --  Configuration register 0 for unit %s
      U_CONF03 : aliased U_CONF_Register;
      --  Configuration register 1 for unit %s
      U_CONF13 : aliased U_CONF_Register_1;
      --  Configuration register 2 for unit %s
      U_CONF23 : aliased U_CONF_Register_2;
      --  Counter value for unit %s
      U_CNT    : aliased U_CNT_Registers;
      --  Interrupt raw status register
      INT_RAW  : aliased INT_RAW_Register;
      --  Interrupt status register
      INT_ST   : aliased INT_ST_Register;
      --  Interrupt enable register
      INT_ENA  : aliased INT_ENA_Register;
      --  Interrupt clear register
      INT_CLR  : aliased INT_CLR_Register;
      --  PNCT UNIT%s status register
      U_STATUS : aliased U_STATUS_Registers;
      --  Control register for all counters
      CTRL     : aliased CTRL_Register;
      --  PCNT version control register
      DATE     : aliased ESP32S3_Registers.UInt32;
   end record
     with Volatile;

   for PCNT_Peripheral use record
      U_CONF00 at 16#0# range 0 .. 31;
      U_CONF10 at 16#4# range 0 .. 31;
      U_CONF20 at 16#8# range 0 .. 31;
      U_CONF01 at 16#C# range 0 .. 31;
      U_CONF11 at 16#10# range 0 .. 31;
      U_CONF21 at 16#14# range 0 .. 31;
      U_CONF02 at 16#18# range 0 .. 31;
      U_CONF12 at 16#1C# range 0 .. 31;
      U_CONF22 at 16#20# range 0 .. 31;
      U_CONF03 at 16#24# range 0 .. 31;
      U_CONF13 at 16#28# range 0 .. 31;
      U_CONF23 at 16#2C# range 0 .. 31;
      U_CNT    at 16#30# range 0 .. 127;
      INT_RAW  at 16#40# range 0 .. 31;
      INT_ST   at 16#44# range 0 .. 31;
      INT_ENA  at 16#48# range 0 .. 31;
      INT_CLR  at 16#4C# range 0 .. 31;
      U_STATUS at 16#50# range 0 .. 127;
      CTRL     at 16#60# range 0 .. 31;
      DATE     at 16#FC# range 0 .. 31;
   end record;

   --  Pulse Count Controller
   PCNT_Periph : aliased PCNT_Peripheral
     with Import, Address => PCNT_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.PCNT;
