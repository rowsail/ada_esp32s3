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

package ESP32S3_Registers.GPIOSD is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype SIGMADELTA_SD_IN_Field is ESP32S3_Registers.Byte;
   subtype SIGMADELTA_SD_PRESCALE_Field is ESP32S3_Registers.Byte;

   --  Duty Cycle Configure Register of SDM%s
   type SIGMADELTA_Register is record
      --  This field is used to configure the duty cycle of sigma delta
      --  modulation output.
      SD_IN          : SIGMADELTA_SD_IN_Field := 16#0#;
      --  This field is used to set a divider value to divide APB clock.
      SD_PRESCALE    : SIGMADELTA_SD_PRESCALE_Field := 16#FF#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SIGMADELTA_Register use record
      SD_IN          at 0 range 0 .. 7;
      SD_PRESCALE    at 0 range 8 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   --  Duty Cycle Configure Register of SDM%s
   type SIGMADELTA_Registers is array (0 .. 7) of SIGMADELTA_Register;

   --  Clock Gating Configure Register
   type SIGMADELTA_CG_Register is record
      --  unspecified
      Reserved_0_30 : ESP32S3_Registers.UInt31 := 16#0#;
      --  Clock enable bit of configuration registers for sigma delta
      --  modulation.
      CLK_EN        : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SIGMADELTA_CG_Register use record
      Reserved_0_30 at 0 range 0 .. 30;
      CLK_EN        at 0 range 31 .. 31;
   end record;

   --  MISC Register
   type SIGMADELTA_MISC_Register is record
      --  unspecified
      Reserved_0_29   : ESP32S3_Registers.UInt30 := 16#0#;
      --  Clock enable bit of sigma delta modulation.
      FUNCTION_CLK_EN : Boolean := False;
      --  Reserved.
      SPI_SWAP        : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SIGMADELTA_MISC_Register use record
      Reserved_0_29   at 0 range 0 .. 29;
      FUNCTION_CLK_EN at 0 range 30 .. 30;
      SPI_SWAP        at 0 range 31 .. 31;
   end record;

   subtype SIGMADELTA_VERSION_GPIO_SD_DATE_Field is ESP32S3_Registers.UInt28;

   --  Version Control Register
   type SIGMADELTA_VERSION_Register is record
      --  Version control register.
      GPIO_SD_DATE   : SIGMADELTA_VERSION_GPIO_SD_DATE_Field := 16#1802260#;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SIGMADELTA_VERSION_Register use record
      GPIO_SD_DATE   at 0 range 0 .. 27;
      Reserved_28_31 at 0 range 28 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Sigma-Delta Modulation
   type GPIO_SD_Peripheral is record
      --  Duty Cycle Configure Register of SDM%s
      SIGMADELTA         : aliased SIGMADELTA_Registers;
      --  Clock Gating Configure Register
      SIGMADELTA_CG      : aliased SIGMADELTA_CG_Register;
      --  MISC Register
      SIGMADELTA_MISC    : aliased SIGMADELTA_MISC_Register;
      --  Version Control Register
      SIGMADELTA_VERSION : aliased SIGMADELTA_VERSION_Register;
   end record
     with Volatile;

   for GPIO_SD_Peripheral use record
      SIGMADELTA         at 16#0# range 0 .. 255;
      SIGMADELTA_CG      at 16#20# range 0 .. 31;
      SIGMADELTA_MISC    at 16#24# range 0 .. 31;
      SIGMADELTA_VERSION at 16#28# range 0 .. 31;
   end record;

   --  Sigma-Delta Modulation
   GPIO_SD_Periph : aliased GPIO_SD_Peripheral
     with Import, Address => GPIO_SD_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.GPIOSD;
