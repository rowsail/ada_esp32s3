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

package ESP32S3_Registers.XTS_AES is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  Plaintext register %s

   --  Plaintext register %s
   type PLAIN_Registers is array (0 .. 15) of ESP32S3_Registers.UInt32;

   --  XTS-AES line-size register
   type LINESIZE_Register is record
      --  Configures the data size of one encryption.
      LINESIZE      : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LINESIZE_Register use record
      LINESIZE      at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  XTS-AES destination register
   type DESTINATION_Register is record
      --  Configures the type of the external memory. Currently, it must be set
      --  to 0, as the Manual Encryption block only supports flash encryption.
      --  Errors may occurs if users write 1. 0:flash. 1: external RAM.
      DESTINATION   : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DESTINATION_Register use record
      DESTINATION   at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   subtype PHYSICAL_ADDRESS_PHYSICAL_ADDRESS_Field is ESP32S3_Registers.UInt30;

   --  physical address
   type PHYSICAL_ADDRESS_Register is record
      --  Those bits stores the physical address. If linesize is 16-byte, the
      --  physical address should be aligned of 16 bytes. If linesize is
      --  32-byte, the physical address should be aligned of 32 bytes. If
      --  linesize is 64-byte, the physical address should be aligned of 64
      --  bytes.
      PHYSICAL_ADDRESS : PHYSICAL_ADDRESS_PHYSICAL_ADDRESS_Field := 16#0#;
      --  unspecified
      Reserved_30_31   : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for PHYSICAL_ADDRESS_Register use record
      PHYSICAL_ADDRESS at 0 range 0 .. 29;
      Reserved_30_31   at 0 range 30 .. 31;
   end record;

   --  XTS-AES trigger register
   type TRIGGER_Register is record
      --  Write-only. Write 1 to activate manual encryption.
      TRIGGER       : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TRIGGER_Register use record
      TRIGGER       at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  XTS-AES release control register
   type RELEASE_Register is record
      --  Write-only. Write 1 to grant SPI1 access to encrypted result.
      RELEASE       : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RELEASE_Register use record
      RELEASE       at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  XTS-AES destroy control register
   type DESTROY_Register is record
      --  Write-only. Write 1 to destroy encrypted result.
      DESTROY       : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DESTROY_Register use record
      DESTROY       at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   subtype STATE_STATE_Field is ESP32S3_Registers.UInt2;

   --  XTS-AES status register
   type STATE_Register is record
      --  Read-only. Those bits indicates the status of the Manual Encryption
      --  block. 0X0 (XTS_AES_IDLE): idle. 0X1 (XTS_AES_BUSY): busy with
      --  encryption. 0X2 (XTS_AES_DONE): encryption is completed, but the
      --  encrypted result is not accessible to SPI. 0X3 (XTS_AES_AVAILABLE)
      --  encrypted result is accessible and available to SPI.
      STATE         : STATE_STATE_Field;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for STATE_Register use record
      STATE         at 0 range 0 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt30;

   --  XTS-AES version control register
   type DATE_Register is record
      --  Manual Encryption block version information.
      DATE           : DATE_DATE_Field := 16#20200111#;
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

   --  XTS-AES-128 Flash Encryption
   type XTS_AES_Peripheral is record
      --  Plaintext register %s
      PLAIN            : aliased PLAIN_Registers;
      --  XTS-AES line-size register
      LINESIZE         : aliased LINESIZE_Register;
      --  XTS-AES destination register
      DESTINATION      : aliased DESTINATION_Register;
      --  physical address
      PHYSICAL_ADDRESS : aliased PHYSICAL_ADDRESS_Register;
      --  XTS-AES trigger register
      TRIGGER          : aliased TRIGGER_Register;
      --  XTS-AES release control register
      RELEASE          : aliased RELEASE_Register;
      --  XTS-AES destroy control register
      DESTROY          : aliased DESTROY_Register;
      --  XTS-AES status register
      STATE            : aliased STATE_Register;
      --  XTS-AES version control register
      DATE             : aliased DATE_Register;
   end record
     with Volatile;

   for XTS_AES_Peripheral use record
      PLAIN            at 16#0# range 0 .. 511;
      LINESIZE         at 16#40# range 0 .. 31;
      DESTINATION      at 16#44# range 0 .. 31;
      PHYSICAL_ADDRESS at 16#48# range 0 .. 31;
      TRIGGER          at 16#4C# range 0 .. 31;
      RELEASE          at 16#50# range 0 .. 31;
      DESTROY          at 16#54# range 0 .. 31;
      STATE            at 16#58# range 0 .. 31;
      DATE             at 16#5C# range 0 .. 31;
   end record;

   --  XTS-AES-128 Flash Encryption
   XTS_AES_Periph : aliased XTS_AES_Peripheral
     with Import, Address => XTS_AES_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.XTS_AES;
