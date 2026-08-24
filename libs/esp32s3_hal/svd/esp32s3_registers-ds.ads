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

package ESP32S3_Registers.DS is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  Memory C

   --  Memory C
   type C_MEM_Registers is array (0 .. 395) of ESP32S3_Registers.UInt32;

   --  IV block data

   --  IV block data
   type IV_Registers is array (0 .. 3) of ESP32S3_Registers.UInt32;

   --  Memory X

   --  Memory X
   type X_MEM_Registers is array (0 .. 127) of ESP32S3_Registers.UInt32;

   --  Memory Z

   --  Memory Z
   type Z_MEM_Registers is array (0 .. 127) of ESP32S3_Registers.UInt32;

   --  Activates the DS peripheral
   type SET_START_Register is record
      --  Write-only. Write 1 to this register to active the DS peripheral
      SET_START     : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SET_START_Register use record
      SET_START     at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  Starts DS operation
   type SET_ME_Register is record
      --  Write-only. Write 1 to this register to start DS operation.
      SET_ME        : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SET_ME_Register use record
      SET_ME        at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  Ends DS operation
   type SET_FINISH_Register is record
      --  Write-only. Write 1 to this register to end DS operation.
      SET_FINISH    : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SET_FINISH_Register use record
      SET_FINISH    at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  Status of the DS perihperal
   type QUERY_BUSY_Register is record
      --  Read-only. Stores the status of the DS peripheral. 1: The DS
      --  peripheral is busy. 0: The DS peripheral is idle.
      QUERY_BUSY    : Boolean;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for QUERY_BUSY_Register use record
      QUERY_BUSY    at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   subtype QUERY_KEY_WRONG_QUERY_KEY_WRONG_Field is ESP32S3_Registers.UInt4;

   --  Checks the reason why DS_KEY is not ready
   type QUERY_KEY_WRONG_Register is record
      --  Read-only. 1-15: HMAC was activated, but the DS peripheral did not
      --  successfully receive the DS_KEY from the HMAC peripheral. (The
      --  biggest value is 15). 0: HMAC is not activated.
      QUERY_KEY_WRONG : QUERY_KEY_WRONG_QUERY_KEY_WRONG_Field;
      --  unspecified
      Reserved_4_31   : ESP32S3_Registers.UInt28;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for QUERY_KEY_WRONG_Register use record
      QUERY_KEY_WRONG at 0 range 0 .. 3;
      Reserved_4_31   at 0 range 4 .. 31;
   end record;

   --  Queries DS check result
   type QUERY_CHECK_Register is record
      --  Read-only. MD checkout result. 1: The MD check fails. 0: The MD check
      --  passes.
      MD_ERROR      : Boolean;
      --  Read-only. padding checkout result. 1: The padding check fails. 0:
      --  The padding check passes.
      PADDING_BAD   : Boolean;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for QUERY_CHECK_Register use record
      MD_ERROR      at 0 range 0 .. 0;
      PADDING_BAD   at 0 range 1 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt30;

   --  DS version control register
   type DATE_Register is record
      --  ds version information
      DATE           : DATE_DATE_Field := 16#20191217#;
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

   --  Digital Signature
   type DS_Peripheral is record
      --  Memory C
      C_MEM           : aliased C_MEM_Registers;
      --  IV block data
      IV              : aliased IV_Registers;
      --  Memory X
      X_MEM           : aliased X_MEM_Registers;
      --  Memory Z
      Z_MEM           : aliased Z_MEM_Registers;
      --  Activates the DS peripheral
      SET_START       : aliased SET_START_Register;
      --  Starts DS operation
      SET_ME          : aliased SET_ME_Register;
      --  Ends DS operation
      SET_FINISH      : aliased SET_FINISH_Register;
      --  Status of the DS perihperal
      QUERY_BUSY      : aliased QUERY_BUSY_Register;
      --  Checks the reason why DS_KEY is not ready
      QUERY_KEY_WRONG : aliased QUERY_KEY_WRONG_Register;
      --  Queries DS check result
      QUERY_CHECK     : aliased QUERY_CHECK_Register;
      --  DS version control register
      DATE            : aliased DATE_Register;
   end record
     with Volatile;

   for DS_Peripheral use record
      C_MEM           at 16#0# range 0 .. 12671;
      IV              at 16#630# range 0 .. 127;
      X_MEM           at 16#800# range 0 .. 4095;
      Z_MEM           at 16#A00# range 0 .. 4095;
      SET_START       at 16#E00# range 0 .. 31;
      SET_ME          at 16#E04# range 0 .. 31;
      SET_FINISH      at 16#E08# range 0 .. 31;
      QUERY_BUSY      at 16#E0C# range 0 .. 31;
      QUERY_KEY_WRONG at 16#E10# range 0 .. 31;
      QUERY_CHECK     at 16#E14# range 0 .. 31;
      DATE            at 16#E20# range 0 .. 31;
   end record;

   --  Digital Signature
   DS_Periph : aliased DS_Peripheral
     with Import, Address => DS_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.DS;
