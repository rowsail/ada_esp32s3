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

package ESP32S3_Registers.SYSTIMER is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  Configure system timer clock
   type CONF_Register is record
      --  systimer clock force on
      SYSTIMER_CLK_FO            : Boolean := False;
      --  unspecified
      Reserved_1_21              : ESP32S3_Registers.UInt21 := 16#0#;
      --  target2 work enable
      TARGET2_WORK_EN            : Boolean := False;
      --  target1 work enable
      TARGET1_WORK_EN            : Boolean := False;
      --  target0 work enable
      TARGET0_WORK_EN            : Boolean := False;
      --  If timer unit1 is stalled when core1 stalled
      TIMER_UNIT1_CORE1_STALL_EN : Boolean := True;
      --  If timer unit1 is stalled when core0 stalled
      TIMER_UNIT1_CORE0_STALL_EN : Boolean := True;
      --  If timer unit0 is stalled when core1 stalled
      TIMER_UNIT0_CORE1_STALL_EN : Boolean := False;
      --  If timer unit0 is stalled when core0 stalled
      TIMER_UNIT0_CORE0_STALL_EN : Boolean := False;
      --  timer unit1 work enable
      TIMER_UNIT1_WORK_EN        : Boolean := False;
      --  timer unit0 work enable
      TIMER_UNIT0_WORK_EN        : Boolean := True;
      --  register file clk gating
      CLK_EN                     : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CONF_Register use record
      SYSTIMER_CLK_FO            at 0 range 0 .. 0;
      Reserved_1_21              at 0 range 1 .. 21;
      TARGET2_WORK_EN            at 0 range 22 .. 22;
      TARGET1_WORK_EN            at 0 range 23 .. 23;
      TARGET0_WORK_EN            at 0 range 24 .. 24;
      TIMER_UNIT1_CORE1_STALL_EN at 0 range 25 .. 25;
      TIMER_UNIT1_CORE0_STALL_EN at 0 range 26 .. 26;
      TIMER_UNIT0_CORE1_STALL_EN at 0 range 27 .. 27;
      TIMER_UNIT0_CORE0_STALL_EN at 0 range 28 .. 28;
      TIMER_UNIT1_WORK_EN        at 0 range 29 .. 29;
      TIMER_UNIT0_WORK_EN        at 0 range 30 .. 30;
      CLK_EN                     at 0 range 31 .. 31;
   end record;

   --  system timer unit0 value update register
   type UNIT0_OP_Register is record
      --  unspecified
      Reserved_0_28           : ESP32S3_Registers.UInt29 := 16#0#;
      --  Read-only. timer value is sync and valid
      TIMER_UNIT0_VALUE_VALID : Boolean := False;
      --  Write-only. update timer_unit0
      TIMER_UNIT0_UPDATE      : Boolean := False;
      --  unspecified
      Reserved_31_31          : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UNIT0_OP_Register use record
      Reserved_0_28           at 0 range 0 .. 28;
      TIMER_UNIT0_VALUE_VALID at 0 range 29 .. 29;
      TIMER_UNIT0_UPDATE      at 0 range 30 .. 30;
      Reserved_31_31          at 0 range 31 .. 31;
   end record;

   --  system timer unit1 value update register
   type UNIT1_OP_Register is record
      --  unspecified
      Reserved_0_28           : ESP32S3_Registers.UInt29 := 16#0#;
      --  Read-only. timer value is sync and valid
      TIMER_UNIT1_VALUE_VALID : Boolean := False;
      --  Write-only. update timer unit1
      TIMER_UNIT1_UPDATE      : Boolean := False;
      --  unspecified
      Reserved_31_31          : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UNIT1_OP_Register use record
      Reserved_0_28           at 0 range 0 .. 28;
      TIMER_UNIT1_VALUE_VALID at 0 range 29 .. 29;
      TIMER_UNIT1_UPDATE      at 0 range 30 .. 30;
      Reserved_31_31          at 0 range 31 .. 31;
   end record;

   subtype UNIT0_LOAD_HI_TIMER_UNIT0_LOAD_HI_Field is ESP32S3_Registers.UInt20;

   --  system timer unit0 value high load register
   type UNIT0_LOAD_HI_Register is record
      --  timer unit0 load high 20 bits
      TIMER_UNIT0_LOAD_HI : UNIT0_LOAD_HI_TIMER_UNIT0_LOAD_HI_Field := 16#0#;
      --  unspecified
      Reserved_20_31      : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UNIT0_LOAD_HI_Register use record
      TIMER_UNIT0_LOAD_HI at 0 range 0 .. 19;
      Reserved_20_31      at 0 range 20 .. 31;
   end record;

   subtype UNIT1_LOAD_HI_TIMER_UNIT1_LOAD_HI_Field is ESP32S3_Registers.UInt20;

   --  system timer unit1 value high load register
   type UNIT1_LOAD_HI_Register is record
      --  timer unit1 load high 20 bits
      TIMER_UNIT1_LOAD_HI : UNIT1_LOAD_HI_TIMER_UNIT1_LOAD_HI_Field := 16#0#;
      --  unspecified
      Reserved_20_31      : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UNIT1_LOAD_HI_Register use record
      TIMER_UNIT1_LOAD_HI at 0 range 0 .. 19;
      Reserved_20_31      at 0 range 20 .. 31;
   end record;

   subtype TARGET0_HI_TIMER_TARGET0_HI_Field is ESP32S3_Registers.UInt20;

   --  system timer comp0 value high register
   type TARGET0_HI_Register is record
      --  timer taget0 high 20 bits
      TIMER_TARGET0_HI : TARGET0_HI_TIMER_TARGET0_HI_Field := 16#0#;
      --  unspecified
      Reserved_20_31   : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TARGET0_HI_Register use record
      TIMER_TARGET0_HI at 0 range 0 .. 19;
      Reserved_20_31   at 0 range 20 .. 31;
   end record;

   subtype TARGET1_HI_TIMER_TARGET1_HI_Field is ESP32S3_Registers.UInt20;

   --  system timer comp1 value high register
   type TARGET1_HI_Register is record
      --  timer taget1 high 20 bits
      TIMER_TARGET1_HI : TARGET1_HI_TIMER_TARGET1_HI_Field := 16#0#;
      --  unspecified
      Reserved_20_31   : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TARGET1_HI_Register use record
      TIMER_TARGET1_HI at 0 range 0 .. 19;
      Reserved_20_31   at 0 range 20 .. 31;
   end record;

   subtype TARGET2_HI_TIMER_TARGET2_HI_Field is ESP32S3_Registers.UInt20;

   --  system timer comp2 value high register
   type TARGET2_HI_Register is record
      --  timer taget2 high 20 bits
      TIMER_TARGET2_HI : TARGET2_HI_TIMER_TARGET2_HI_Field := 16#0#;
      --  unspecified
      Reserved_20_31   : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TARGET2_HI_Register use record
      TIMER_TARGET2_HI at 0 range 0 .. 19;
      Reserved_20_31   at 0 range 20 .. 31;
   end record;

   subtype TARGET0_CONF_TARGET0_PERIOD_Field is ESP32S3_Registers.UInt26;

   --  system timer comp0 target mode register
   type TARGET0_CONF_Register is record
      --  target0 period
      TARGET0_PERIOD         : TARGET0_CONF_TARGET0_PERIOD_Field := 16#0#;
      --  unspecified
      Reserved_26_29         : ESP32S3_Registers.UInt4 := 16#0#;
      --  Set target0 to period mode
      TARGET0_PERIOD_MODE    : Boolean := False;
      --  select which unit to compare
      TARGET0_TIMER_UNIT_SEL : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TARGET0_CONF_Register use record
      TARGET0_PERIOD         at 0 range 0 .. 25;
      Reserved_26_29         at 0 range 26 .. 29;
      TARGET0_PERIOD_MODE    at 0 range 30 .. 30;
      TARGET0_TIMER_UNIT_SEL at 0 range 31 .. 31;
   end record;

   subtype TARGET1_CONF_TARGET1_PERIOD_Field is ESP32S3_Registers.UInt26;

   --  system timer comp1 target mode register
   type TARGET1_CONF_Register is record
      --  target1 period
      TARGET1_PERIOD         : TARGET1_CONF_TARGET1_PERIOD_Field := 16#0#;
      --  unspecified
      Reserved_26_29         : ESP32S3_Registers.UInt4 := 16#0#;
      --  Set target1 to period mode
      TARGET1_PERIOD_MODE    : Boolean := False;
      --  select which unit to compare
      TARGET1_TIMER_UNIT_SEL : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TARGET1_CONF_Register use record
      TARGET1_PERIOD         at 0 range 0 .. 25;
      Reserved_26_29         at 0 range 26 .. 29;
      TARGET1_PERIOD_MODE    at 0 range 30 .. 30;
      TARGET1_TIMER_UNIT_SEL at 0 range 31 .. 31;
   end record;

   subtype TARGET2_CONF_TARGET2_PERIOD_Field is ESP32S3_Registers.UInt26;

   --  system timer comp2 target mode register
   type TARGET2_CONF_Register is record
      --  target2 period
      TARGET2_PERIOD         : TARGET2_CONF_TARGET2_PERIOD_Field := 16#0#;
      --  unspecified
      Reserved_26_29         : ESP32S3_Registers.UInt4 := 16#0#;
      --  Set target2 to period mode
      TARGET2_PERIOD_MODE    : Boolean := False;
      --  select which unit to compare
      TARGET2_TIMER_UNIT_SEL : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TARGET2_CONF_Register use record
      TARGET2_PERIOD         at 0 range 0 .. 25;
      Reserved_26_29         at 0 range 26 .. 29;
      TARGET2_PERIOD_MODE    at 0 range 30 .. 30;
      TARGET2_TIMER_UNIT_SEL at 0 range 31 .. 31;
   end record;

   subtype UNIT0_VALUE_HI_TIMER_UNIT0_VALUE_HI_Field is
     ESP32S3_Registers.UInt20;

   --  system timer unit0 value high register
   type UNIT0_VALUE_HI_Register is record
      --  Read-only. timer read value high 20bits
      TIMER_UNIT0_VALUE_HI : UNIT0_VALUE_HI_TIMER_UNIT0_VALUE_HI_Field;
      --  unspecified
      Reserved_20_31       : ESP32S3_Registers.UInt12;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UNIT0_VALUE_HI_Register use record
      TIMER_UNIT0_VALUE_HI at 0 range 0 .. 19;
      Reserved_20_31       at 0 range 20 .. 31;
   end record;

   subtype UNIT1_VALUE_HI_TIMER_UNIT1_VALUE_HI_Field is
     ESP32S3_Registers.UInt20;

   --  system timer unit1 value high register
   type UNIT1_VALUE_HI_Register is record
      --  Read-only. timer read value high 20bits
      TIMER_UNIT1_VALUE_HI : UNIT1_VALUE_HI_TIMER_UNIT1_VALUE_HI_Field;
      --  unspecified
      Reserved_20_31       : ESP32S3_Registers.UInt12;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UNIT1_VALUE_HI_Register use record
      TIMER_UNIT1_VALUE_HI at 0 range 0 .. 19;
      Reserved_20_31       at 0 range 20 .. 31;
   end record;

   --  system timer comp0 conf sync register
   type COMP0_LOAD_Register is record
      --  Write-only. timer comp0 sync enable signal
      TIMER_COMP0_LOAD : Boolean := False;
      --  unspecified
      Reserved_1_31    : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for COMP0_LOAD_Register use record
      TIMER_COMP0_LOAD at 0 range 0 .. 0;
      Reserved_1_31    at 0 range 1 .. 31;
   end record;

   --  system timer comp1 conf sync register
   type COMP1_LOAD_Register is record
      --  Write-only. timer comp1 sync enable signal
      TIMER_COMP1_LOAD : Boolean := False;
      --  unspecified
      Reserved_1_31    : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for COMP1_LOAD_Register use record
      TIMER_COMP1_LOAD at 0 range 0 .. 0;
      Reserved_1_31    at 0 range 1 .. 31;
   end record;

   --  system timer comp2 conf sync register
   type COMP2_LOAD_Register is record
      --  Write-only. timer comp2 sync enable signal
      TIMER_COMP2_LOAD : Boolean := False;
      --  unspecified
      Reserved_1_31    : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for COMP2_LOAD_Register use record
      TIMER_COMP2_LOAD at 0 range 0 .. 0;
      Reserved_1_31    at 0 range 1 .. 31;
   end record;

   --  system timer unit0 conf sync register
   type UNIT0_LOAD_Register is record
      --  Write-only. timer unit0 sync enable signal
      TIMER_UNIT0_LOAD : Boolean := False;
      --  unspecified
      Reserved_1_31    : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UNIT0_LOAD_Register use record
      TIMER_UNIT0_LOAD at 0 range 0 .. 0;
      Reserved_1_31    at 0 range 1 .. 31;
   end record;

   --  system timer unit1 conf sync register
   type UNIT1_LOAD_Register is record
      --  Write-only. timer unit1 sync enable signal
      TIMER_UNIT1_LOAD : Boolean := False;
      --  unspecified
      Reserved_1_31    : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UNIT1_LOAD_Register use record
      TIMER_UNIT1_LOAD at 0 range 0 .. 0;
      Reserved_1_31    at 0 range 1 .. 31;
   end record;

   --  systimer interrupt enable register
   type INT_ENA_Register is record
      --  interupt0 enable
      TARGET0_INT_ENA : Boolean := False;
      --  interupt1 enable
      TARGET1_INT_ENA : Boolean := False;
      --  interupt2 enable
      TARGET2_INT_ENA : Boolean := False;
      --  unspecified
      Reserved_3_31   : ESP32S3_Registers.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_Register use record
      TARGET0_INT_ENA at 0 range 0 .. 0;
      TARGET1_INT_ENA at 0 range 1 .. 1;
      TARGET2_INT_ENA at 0 range 2 .. 2;
      Reserved_3_31   at 0 range 3 .. 31;
   end record;

   --  systimer interrupt raw register
   type INT_RAW_Register is record
      --  interupt0 raw
      TARGET0_INT_RAW : Boolean := False;
      --  interupt1 raw
      TARGET1_INT_RAW : Boolean := False;
      --  interupt2 raw
      TARGET2_INT_RAW : Boolean := False;
      --  unspecified
      Reserved_3_31   : ESP32S3_Registers.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_Register use record
      TARGET0_INT_RAW at 0 range 0 .. 0;
      TARGET1_INT_RAW at 0 range 1 .. 1;
      TARGET2_INT_RAW at 0 range 2 .. 2;
      Reserved_3_31   at 0 range 3 .. 31;
   end record;

   --  systimer interrupt clear register
   type INT_CLR_Register is record
      --  Write-only. interupt0 clear
      TARGET0_INT_CLR : Boolean := False;
      --  Write-only. interupt1 clear
      TARGET1_INT_CLR : Boolean := False;
      --  Write-only. interupt2 clear
      TARGET2_INT_CLR : Boolean := False;
      --  unspecified
      Reserved_3_31   : ESP32S3_Registers.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_Register use record
      TARGET0_INT_CLR at 0 range 0 .. 0;
      TARGET1_INT_CLR at 0 range 1 .. 1;
      TARGET2_INT_CLR at 0 range 2 .. 2;
      Reserved_3_31   at 0 range 3 .. 31;
   end record;

   --  systimer interrupt status register
   type INT_ST_Register is record
      --  Read-only. interupt0 status
      TARGET0_INT_ST : Boolean;
      --  Read-only. interupt1 status
      TARGET1_INT_ST : Boolean;
      --  Read-only. interupt2 status
      TARGET2_INT_ST : Boolean;
      --  unspecified
      Reserved_3_31  : ESP32S3_Registers.UInt29;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ST_Register use record
      TARGET0_INT_ST at 0 range 0 .. 0;
      TARGET1_INT_ST at 0 range 1 .. 1;
      TARGET2_INT_ST at 0 range 2 .. 2;
      Reserved_3_31  at 0 range 3 .. 31;
   end record;

   subtype REAL_TARGET0_HI_TARGET0_HI_RO_Field is ESP32S3_Registers.UInt20;

   --  system timer comp0 actual target value high register
   type REAL_TARGET0_HI_Register is record
      --  Read-only. actual target value value high 20bits
      TARGET0_HI_RO  : REAL_TARGET0_HI_TARGET0_HI_RO_Field;
      --  unspecified
      Reserved_20_31 : ESP32S3_Registers.UInt12;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for REAL_TARGET0_HI_Register use record
      TARGET0_HI_RO  at 0 range 0 .. 19;
      Reserved_20_31 at 0 range 20 .. 31;
   end record;

   subtype REAL_TARGET1_HI_TARGET1_HI_RO_Field is ESP32S3_Registers.UInt20;

   --  system timer comp1 actual target value high register
   type REAL_TARGET1_HI_Register is record
      --  Read-only. actual target value value high 20bits
      TARGET1_HI_RO  : REAL_TARGET1_HI_TARGET1_HI_RO_Field;
      --  unspecified
      Reserved_20_31 : ESP32S3_Registers.UInt12;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for REAL_TARGET1_HI_Register use record
      TARGET1_HI_RO  at 0 range 0 .. 19;
      Reserved_20_31 at 0 range 20 .. 31;
   end record;

   subtype REAL_TARGET2_HI_TARGET2_HI_RO_Field is ESP32S3_Registers.UInt20;

   --  system timer comp2 actual target value high register
   type REAL_TARGET2_HI_Register is record
      --  Read-only. actual target value value high 20bits
      TARGET2_HI_RO  : REAL_TARGET2_HI_TARGET2_HI_RO_Field;
      --  unspecified
      Reserved_20_31 : ESP32S3_Registers.UInt12;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for REAL_TARGET2_HI_Register use record
      TARGET2_HI_RO  at 0 range 0 .. 19;
      Reserved_20_31 at 0 range 20 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  System Timer
   type SYSTIMER_Peripheral is record
      --  Configure system timer clock
      CONF            : aliased CONF_Register;
      --  system timer unit0 value update register
      UNIT0_OP        : aliased UNIT0_OP_Register;
      --  system timer unit1 value update register
      UNIT1_OP        : aliased UNIT1_OP_Register;
      --  system timer unit0 value high load register
      UNIT0_LOAD_HI   : aliased UNIT0_LOAD_HI_Register;
      --  system timer unit0 value low load register
      UNIT0_LOAD_LO   : aliased ESP32S3_Registers.UInt32;
      --  system timer unit1 value high load register
      UNIT1_LOAD_HI   : aliased UNIT1_LOAD_HI_Register;
      --  system timer unit1 value low load register
      UNIT1_LOAD_LO   : aliased ESP32S3_Registers.UInt32;
      --  system timer comp0 value high register
      TARGET0_HI      : aliased TARGET0_HI_Register;
      --  system timer comp0 value low register
      TARGET0_LO      : aliased ESP32S3_Registers.UInt32;
      --  system timer comp1 value high register
      TARGET1_HI      : aliased TARGET1_HI_Register;
      --  system timer comp1 value low register
      TARGET1_LO      : aliased ESP32S3_Registers.UInt32;
      --  system timer comp2 value high register
      TARGET2_HI      : aliased TARGET2_HI_Register;
      --  system timer comp2 value low register
      TARGET2_LO      : aliased ESP32S3_Registers.UInt32;
      --  system timer comp0 target mode register
      TARGET0_CONF    : aliased TARGET0_CONF_Register;
      --  system timer comp1 target mode register
      TARGET1_CONF    : aliased TARGET1_CONF_Register;
      --  system timer comp2 target mode register
      TARGET2_CONF    : aliased TARGET2_CONF_Register;
      --  system timer unit0 value high register
      UNIT0_VALUE_HI  : aliased UNIT0_VALUE_HI_Register;
      --  system timer unit0 value low register
      UNIT0_VALUE_LO  : aliased ESP32S3_Registers.UInt32;
      --  system timer unit1 value high register
      UNIT1_VALUE_HI  : aliased UNIT1_VALUE_HI_Register;
      --  system timer unit1 value low register
      UNIT1_VALUE_LO  : aliased ESP32S3_Registers.UInt32;
      --  system timer comp0 conf sync register
      COMP0_LOAD      : aliased COMP0_LOAD_Register;
      --  system timer comp1 conf sync register
      COMP1_LOAD      : aliased COMP1_LOAD_Register;
      --  system timer comp2 conf sync register
      COMP2_LOAD      : aliased COMP2_LOAD_Register;
      --  system timer unit0 conf sync register
      UNIT0_LOAD      : aliased UNIT0_LOAD_Register;
      --  system timer unit1 conf sync register
      UNIT1_LOAD      : aliased UNIT1_LOAD_Register;
      --  systimer interrupt enable register
      INT_ENA         : aliased INT_ENA_Register;
      --  systimer interrupt raw register
      INT_RAW         : aliased INT_RAW_Register;
      --  systimer interrupt clear register
      INT_CLR         : aliased INT_CLR_Register;
      --  systimer interrupt status register
      INT_ST          : aliased INT_ST_Register;
      --  system timer comp0 actual target value low register
      REAL_TARGET0_LO : aliased ESP32S3_Registers.UInt32;
      --  system timer comp0 actual target value high register
      REAL_TARGET0_HI : aliased REAL_TARGET0_HI_Register;
      --  system timer comp1 actual target value low register
      REAL_TARGET1_LO : aliased ESP32S3_Registers.UInt32;
      --  system timer comp1 actual target value high register
      REAL_TARGET1_HI : aliased REAL_TARGET1_HI_Register;
      --  system timer comp2 actual target value low register
      REAL_TARGET2_LO : aliased ESP32S3_Registers.UInt32;
      --  system timer comp2 actual target value high register
      REAL_TARGET2_HI : aliased REAL_TARGET2_HI_Register;
      --  system timer version control register
      DATE            : aliased ESP32S3_Registers.UInt32;
   end record
     with Volatile;

   for SYSTIMER_Peripheral use record
      CONF            at 16#0# range 0 .. 31;
      UNIT0_OP        at 16#4# range 0 .. 31;
      UNIT1_OP        at 16#8# range 0 .. 31;
      UNIT0_LOAD_HI   at 16#C# range 0 .. 31;
      UNIT0_LOAD_LO   at 16#10# range 0 .. 31;
      UNIT1_LOAD_HI   at 16#14# range 0 .. 31;
      UNIT1_LOAD_LO   at 16#18# range 0 .. 31;
      TARGET0_HI      at 16#1C# range 0 .. 31;
      TARGET0_LO      at 16#20# range 0 .. 31;
      TARGET1_HI      at 16#24# range 0 .. 31;
      TARGET1_LO      at 16#28# range 0 .. 31;
      TARGET2_HI      at 16#2C# range 0 .. 31;
      TARGET2_LO      at 16#30# range 0 .. 31;
      TARGET0_CONF    at 16#34# range 0 .. 31;
      TARGET1_CONF    at 16#38# range 0 .. 31;
      TARGET2_CONF    at 16#3C# range 0 .. 31;
      UNIT0_VALUE_HI  at 16#40# range 0 .. 31;
      UNIT0_VALUE_LO  at 16#44# range 0 .. 31;
      UNIT1_VALUE_HI  at 16#48# range 0 .. 31;
      UNIT1_VALUE_LO  at 16#4C# range 0 .. 31;
      COMP0_LOAD      at 16#50# range 0 .. 31;
      COMP1_LOAD      at 16#54# range 0 .. 31;
      COMP2_LOAD      at 16#58# range 0 .. 31;
      UNIT0_LOAD      at 16#5C# range 0 .. 31;
      UNIT1_LOAD      at 16#60# range 0 .. 31;
      INT_ENA         at 16#64# range 0 .. 31;
      INT_RAW         at 16#68# range 0 .. 31;
      INT_CLR         at 16#6C# range 0 .. 31;
      INT_ST          at 16#70# range 0 .. 31;
      REAL_TARGET0_LO at 16#74# range 0 .. 31;
      REAL_TARGET0_HI at 16#78# range 0 .. 31;
      REAL_TARGET1_LO at 16#7C# range 0 .. 31;
      REAL_TARGET1_HI at 16#80# range 0 .. 31;
      REAL_TARGET2_LO at 16#84# range 0 .. 31;
      REAL_TARGET2_HI at 16#88# range 0 .. 31;
      DATE            at 16#FC# range 0 .. 31;
   end record;

   --  System Timer
   SYSTIMER_Periph : aliased SYSTIMER_Peripheral
     with Import, Address => SYSTIMER_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.SYSTIMER;
