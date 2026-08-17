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

package ESP32S3_Registers.RNG is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   -----------------
   -- Peripherals --
   -----------------

   --  Hardware Random Number Generator
   type RNG_Peripheral is record
      --  Random number data
      DATA : aliased ESP32S3_Registers.UInt32;
   end record
   with Volatile;

   for RNG_Peripheral use
     record
       DATA at 16#110# range 0 .. 31;
     end record;

   --  Hardware Random Number Generator
   RNG_Periph : aliased RNG_Peripheral
   with Import, Address => RNG_Base;

end ESP32S3_Registers.RNG;
