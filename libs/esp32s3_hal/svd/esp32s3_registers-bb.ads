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

package ESP32S3_Registers.BB is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  Baseband control register
   type BBPD_CTRL_Register is record
      DC_EST_FORCE_PD : Boolean := False;
      DC_EST_FORCE_PU : Boolean := False;
      FFT_FORCE_PD    : Boolean := False;
      FFT_FORCE_PU    : Boolean := False;
      --  unspecified
      Reserved_4_31   : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BBPD_CTRL_Register use record
      DC_EST_FORCE_PD at 0 range 0 .. 0;
      DC_EST_FORCE_PU at 0 range 1 .. 1;
      FFT_FORCE_PD    at 0 range 2 .. 2;
      FFT_FORCE_PU    at 0 range 3 .. 3;
      Reserved_4_31   at 0 range 4 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  BB Peripheral
   type BB_Peripheral is record
      --  Baseband control register
      BBPD_CTRL : aliased BBPD_CTRL_Register;
   end record
     with Volatile;

   for BB_Peripheral use record
      BBPD_CTRL at 16#54# range 0 .. 31;
   end record;

   --  BB Peripheral
   BB_Periph : aliased BB_Peripheral
     with Import, Address => BB_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.BB;
