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

package ESP32S3_Registers.RSA is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  Memory M

   --  Memory M
   type M_MEM_Registers is array (0 .. 127) of ESP32S3_Registers.UInt32;

   --  Memory Z

   --  Memory Z
   type Z_MEM_Registers is array (0 .. 127) of ESP32S3_Registers.UInt32;

   --  Memory Y

   --  Memory Y
   type Y_MEM_Registers is array (0 .. 127) of ESP32S3_Registers.UInt32;

   --  Memory X

   --  Memory X
   type X_MEM_Registers is array (0 .. 127) of ESP32S3_Registers.UInt32;

   subtype MODE_MODE_Field is ESP32S3_Registers.UInt7;

   --  RSA length mode register
   type MODE_Register is record
      --  Stores the RSA length mode
      MODE          : MODE_MODE_Field := 16#0#;
      --  unspecified
      Reserved_7_31 : ESP32S3_Registers.UInt25 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MODE_Register use record
      MODE          at 0 range 0 .. 6;
      Reserved_7_31 at 0 range 7 .. 31;
   end record;

   --  RSA clean register
   type CLEAN_Register is record
      --  Read-only. The content of this bit is 1 when memories complete
      --  initialization.
      CLEAN         : Boolean;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLEAN_Register use record
      CLEAN         at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  Modular exponentiation trigger register.
   type MODEXP_START_Register is record
      --  Write-only. Set this bit to 1 to start the modular exponentiation.
      MODEXP_START  : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MODEXP_START_Register use record
      MODEXP_START  at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  Modular multiplication trigger register.
   type MODMULT_START_Register is record
      --  Write-only. Set this bit to 1 to start the modular multiplication
      MODMULT_START : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MODMULT_START_Register use record
      MODMULT_START at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  Normal multiplication trigger register.
   type MULT_START_Register is record
      --  Write-only. Set this bit to 1 to start the multiplicaiton.
      MULT_START    : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MULT_START_Register use record
      MULT_START    at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  RSA idle register
   type IDLE_Register is record
      --  Read-only. The content of this bit is 1 when the RSA accelerator is
      --  idle.
      IDLE          : Boolean;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for IDLE_Register use record
      IDLE          at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  RSA interrupt clear register
   type CLEAR_INTERRUPT_Register is record
      --  Write-only. set this bit to 1 to clear the RSA interrupt.
      CLEAR_INTERRUPT : Boolean := False;
      --  unspecified
      Reserved_1_31   : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLEAR_INTERRUPT_Register use record
      CLEAR_INTERRUPT at 0 range 0 .. 0;
      Reserved_1_31   at 0 range 1 .. 31;
   end record;

   --  CONSTANT_TIME option control register
   type CONSTANT_TIME_Register is record
      --  Controls the CONSTANT_TIME option. 0: acceleration. 1: no
      --  acceleration(by default).
      CONSTANT_TIME : Boolean := True;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CONSTANT_TIME_Register use record
      CONSTANT_TIME at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  SEARCH option enable register
   type SEARCH_ENABLE_Register is record
      --  Controls the SEARCH option. 0: no acceleration(by default). 1:
      --  acceleration.
      SEARCH_ENABLE : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SEARCH_ENABLE_Register use record
      SEARCH_ENABLE at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   subtype SEARCH_POS_SEARCH_POS_Field is ESP32S3_Registers.UInt12;

   --  RSA search position configure register
   type SEARCH_POS_Register is record
      --  This field is used to configure the starting search position when the
      --  acceleration option of SEARCH is used.
      SEARCH_POS     : SEARCH_POS_SEARCH_POS_Field := 16#0#;
      --  unspecified
      Reserved_12_31 : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SEARCH_POS_Register use record
      SEARCH_POS     at 0 range 0 .. 11;
      Reserved_12_31 at 0 range 12 .. 31;
   end record;

   --  RSA interrupt enable register
   type INTERRUPT_ENA_Register is record
      --  Set this bit to 1 to enable the RSA interrupt. This option is enabled
      --  by default.
      INTERRUPT_ENA : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INTERRUPT_ENA_Register use record
      INTERRUPT_ENA at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt30;

   --  RSA version control register
   type DATE_Register is record
      --  rsa version information
      DATE           : DATE_DATE_Field := 16#20191231#;
      --  unspecified
      Reserved_30_31 : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DATE_Register use record
      DATE           at 0 range 0 .. 29;
      Reserved_30_31 at 0 range 30 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  RSA (Rivest Shamir Adleman) Accelerator
   type RSA_Peripheral is record
      --  Memory M
      M_MEM           : aliased M_MEM_Registers;
      --  Memory Z
      Z_MEM           : aliased Z_MEM_Registers;
      --  Memory Y
      Y_MEM           : aliased Y_MEM_Registers;
      --  Memory X
      X_MEM           : aliased X_MEM_Registers;
      --  RSA M' register
      M_PRIME         : aliased ESP32S3_Registers.UInt32;
      --  RSA length mode register
      MODE            : aliased MODE_Register;
      --  RSA clean register
      CLEAN           : aliased CLEAN_Register;
      --  Modular exponentiation trigger register.
      MODEXP_START    : aliased MODEXP_START_Register;
      --  Modular multiplication trigger register.
      MODMULT_START   : aliased MODMULT_START_Register;
      --  Normal multiplication trigger register.
      MULT_START      : aliased MULT_START_Register;
      --  RSA idle register
      IDLE            : aliased IDLE_Register;
      --  RSA interrupt clear register
      CLEAR_INTERRUPT : aliased CLEAR_INTERRUPT_Register;
      --  CONSTANT_TIME option control register
      CONSTANT_TIME   : aliased CONSTANT_TIME_Register;
      --  SEARCH option enable register
      SEARCH_ENABLE   : aliased SEARCH_ENABLE_Register;
      --  RSA search position configure register
      SEARCH_POS      : aliased SEARCH_POS_Register;
      --  RSA interrupt enable register
      INTERRUPT_ENA   : aliased INTERRUPT_ENA_Register;
      --  RSA version control register
      DATE            : aliased DATE_Register;
   end record
     with Volatile;

   for RSA_Peripheral use record
      M_MEM           at 16#0# range 0 .. 4095;
      Z_MEM           at 16#200# range 0 .. 4095;
      Y_MEM           at 16#400# range 0 .. 4095;
      X_MEM           at 16#600# range 0 .. 4095;
      M_PRIME         at 16#800# range 0 .. 31;
      MODE            at 16#804# range 0 .. 31;
      CLEAN           at 16#808# range 0 .. 31;
      MODEXP_START    at 16#80C# range 0 .. 31;
      MODMULT_START   at 16#810# range 0 .. 31;
      MULT_START      at 16#814# range 0 .. 31;
      IDLE            at 16#818# range 0 .. 31;
      CLEAR_INTERRUPT at 16#81C# range 0 .. 31;
      CONSTANT_TIME   at 16#820# range 0 .. 31;
      SEARCH_ENABLE   at 16#824# range 0 .. 31;
      SEARCH_POS      at 16#828# range 0 .. 31;
      INTERRUPT_ENA   at 16#82C# range 0 .. 31;
      DATE            at 16#830# range 0 .. 31;
   end record;

   --  RSA (Rivest Shamir Adleman) Accelerator
   RSA_Periph : aliased RSA_Peripheral
     with Import, Address => RSA_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.RSA;
