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

package ESP32S3_Registers.AES is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  AES key register %s

   --  AES key register %s
   type KEY_Registers is array (0 .. 7) of ESP32S3_Registers.UInt32;

   --  Source data register %s

   --  Source data register %s
   type TEXT_IN_Registers is array (0 .. 3) of ESP32S3_Registers.UInt32;

   --  Result data register %s

   --  Result data register %s
   type TEXT_OUT_Registers is array (0 .. 3) of ESP32S3_Registers.UInt32;

   subtype MODE_MODE_Field is ESP32S3_Registers.UInt3;

   --  AES Mode register
   type MODE_Register is record
      --  Defines the key length and the encryption/decryption of the AES
      --  accelerator.
      MODE          : MODE_MODE_Field := 16#0#;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for MODE_Register use
     record
       MODE at 0 range 0 .. 2;
       Reserved_3_31 at 0 range 3 .. 31;
     end record;

   --  AES trigger register
   type TRIGGER_Register is record
      --  Write-only. Set this bit to 1 to start AES calculation.
      TRIGGER       : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TRIGGER_Register use
     record
       TRIGGER at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   subtype STATE_STATE_Field is ESP32S3_Registers.UInt2;

   --  AES state register
   type STATE_Register is record
      --  Read-only. Stores the working status of the AES accelerator. For
      --  typical AES, 0: idle, 1: busy. For DMA-AES, 0: idle, 1: busy, 2:
      --  calculation_done.
      STATE         : STATE_STATE_Field;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for STATE_Register use
     record
       STATE at 0 range 0 .. 1;
       Reserved_2_31 at 0 range 2 .. 31;
     end record;

   --  The memory that stores initialization vector

   --  The memory that stores initialization vector
   type IV_MEM_Registers is array (0 .. 3) of ESP32S3_Registers.UInt32;

   --  The memory that stores GCM hash subkey

   --  The memory that stores GCM hash subkey
   type H_MEM_Registers is array (0 .. 3) of ESP32S3_Registers.UInt32;

   --  The memory that stores J0

   --  The memory that stores J0
   type J0_MEM_Registers is array (0 .. 3) of ESP32S3_Registers.UInt32;

   --  The memory that stores T0

   --  The memory that stores T0
   type T0_MEM_Registers is array (0 .. 3) of ESP32S3_Registers.UInt32;

   --  AES accelerator working mode register
   type DMA_ENABLE_Register is record
      --  Defines the working mode of the AES accelerator. 1'b0: typical AES
      --  working mode, 1'b1: DMA-AES working mode.
      DMA_ENABLE    : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_ENABLE_Register use
     record
       DMA_ENABLE at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   subtype BLOCK_MODE_BLOCK_MODE_Field is ESP32S3_Registers.UInt3;

   --  AES cipher block mode register
   type BLOCK_MODE_Register is record
      --  Defines the block cipher mode of the AES accelerator operating under
      --  the DMA-AES working mode. 0x0: ECB, 0x1: CBC, 0x2: OFB, 0x3: CTR,
      --  0x4: CFB-8, 0x5: CFB-128, 0x6: reserved, 0x7: reserved.
      BLOCK_MODE    : BLOCK_MODE_BLOCK_MODE_Field := 16#0#;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for BLOCK_MODE_Register use
     record
       BLOCK_MODE at 0 range 0 .. 2;
       Reserved_3_31 at 0 range 3 .. 31;
     end record;

   --  Standard incrementing function configure register
   type INC_SEL_Register is record
      --  Defines the Standard Incrementing Function for CTR block operation.
      --  Set this bit to 0 or 1 to choose INC32 or INC128.
      INC_SEL       : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INC_SEL_Register use
     record
       INC_SEL at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   subtype REMAINDER_BIT_NUM_REMAINDER_BIT_NUM_Field is
     ESP32S3_Registers.UInt7;

   --  AES remainder bit number register
   type REMAINDER_BIT_NUM_Register is record
      --  Those bits stores the number of remainder bit.
      REMAINDER_BIT_NUM : REMAINDER_BIT_NUM_REMAINDER_BIT_NUM_Field := 16#0#;
      --  unspecified
      Reserved_7_31     : ESP32S3_Registers.UInt25 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for REMAINDER_BIT_NUM_Register use
     record
       REMAINDER_BIT_NUM at 0 range 0 .. 6;
       Reserved_7_31 at 0 range 7 .. 31;
     end record;

   --  AES continue register
   type CONTINUE_Register is record
      --  Write-only. Set this bit to 1 to continue GCM operation.
      CONTINUE      : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CONTINUE_Register use
     record
       CONTINUE at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   --  AES Interrupt clear register
   type INT_CLR_Register is record
      --  Write-only. Set this bit to 1 to clear AES interrupt.
      INT_CLEAR     : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_CLR_Register use
     record
       INT_CLEAR at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   --  DMA-AES Interrupt enable register
   type INT_ENA_Register is record
      --  Set this bit to 1 to enable AES interrupt and 0 to disable interrupt.
      --  This field is only effective for DMA-AES operation.
      INT_ENA       : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ENA_Register use
     record
       INT_ENA at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt30;

   --  AES version control register
   type DATE_Register is record
      --  This bits stores the version information of AES.
      DATE           : DATE_DATE_Field := 16#20191210#;
      --  unspecified
      Reserved_30_31 : ESP32S3_Registers.UInt2 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DATE_Register use
     record
       DATE at 0 range 0 .. 29;
       Reserved_30_31 at 0 range 30 .. 31;
     end record;

   --  AES-DMA exit config
   type DMA_EXIT_Register is record
      --  Write-only. Set this bit to 1 to exit AES operation. This field is
      --  only effective for DMA-AES operation.
      DMA_EXIT      : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_EXIT_Register use
     record
       DMA_EXIT at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   -----------------
   -- Peripherals --
   -----------------

   --  AES (Advanced Encryption Standard) Accelerator
   type AES_Peripheral is record
      --  AES key register %s
      KEY               : aliased KEY_Registers;
      --  Source data register %s
      TEXT_IN           : aliased TEXT_IN_Registers;
      --  Result data register %s
      TEXT_OUT          : aliased TEXT_OUT_Registers;
      --  AES Mode register
      MODE              : aliased MODE_Register;
      --  AES trigger register
      TRIGGER           : aliased TRIGGER_Register;
      --  AES state register
      STATE             : aliased STATE_Register;
      --  The memory that stores initialization vector
      IV_MEM            : aliased IV_MEM_Registers;
      --  The memory that stores GCM hash subkey
      H_MEM             : aliased H_MEM_Registers;
      --  The memory that stores J0
      J0_MEM            : aliased J0_MEM_Registers;
      --  The memory that stores T0
      T0_MEM            : aliased T0_MEM_Registers;
      --  AES accelerator working mode register
      DMA_ENABLE        : aliased DMA_ENABLE_Register;
      --  AES cipher block mode register
      BLOCK_MODE        : aliased BLOCK_MODE_Register;
      --  AES block number register
      BLOCK_NUM         : aliased ESP32S3_Registers.UInt32;
      --  Standard incrementing function configure register
      INC_SEL           : aliased INC_SEL_Register;
      --  Additional Authential Data block number register
      AAD_BLOCK_NUM     : aliased ESP32S3_Registers.UInt32;
      --  AES remainder bit number register
      REMAINDER_BIT_NUM : aliased REMAINDER_BIT_NUM_Register;
      --  AES continue register
      CONTINUE          : aliased CONTINUE_Register;
      --  AES Interrupt clear register
      INT_CLR           : aliased INT_CLR_Register;
      --  DMA-AES Interrupt enable register
      INT_ENA           : aliased INT_ENA_Register;
      --  AES version control register
      DATE              : aliased DATE_Register;
      --  AES-DMA exit config
      DMA_EXIT          : aliased DMA_EXIT_Register;
   end record
   with Volatile;

   for AES_Peripheral use
     record
       KEY at 16#0# range 0 .. 255;
       TEXT_IN at 16#20# range 0 .. 127;
       TEXT_OUT at 16#30# range 0 .. 127;
       MODE at 16#40# range 0 .. 31;
       TRIGGER at 16#48# range 0 .. 31;
       STATE at 16#4C# range 0 .. 31;
       IV_MEM at 16#50# range 0 .. 127;
       H_MEM at 16#60# range 0 .. 127;
       J0_MEM at 16#70# range 0 .. 127;
       T0_MEM at 16#80# range 0 .. 127;
       DMA_ENABLE at 16#90# range 0 .. 31;
       BLOCK_MODE at 16#94# range 0 .. 31;
       BLOCK_NUM at 16#98# range 0 .. 31;
       INC_SEL at 16#9C# range 0 .. 31;
       AAD_BLOCK_NUM at 16#A0# range 0 .. 31;
       REMAINDER_BIT_NUM at 16#A4# range 0 .. 31;
       CONTINUE at 16#A8# range 0 .. 31;
       INT_CLR at 16#AC# range 0 .. 31;
       INT_ENA at 16#B0# range 0 .. 31;
       DATE at 16#B4# range 0 .. 31;
       DMA_EXIT at 16#B8# range 0 .. 31;
     end record;

   --  AES (Advanced Encryption Standard) Accelerator
   AES_Periph : aliased AES_Peripheral
   with Import, Address => AES_Base;

end ESP32S3_Registers.AES;
