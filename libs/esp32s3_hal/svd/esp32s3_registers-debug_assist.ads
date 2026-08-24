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

package ESP32S3_Registers.DEBUG_ASSIST is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  core0 monitor enable configuration register
   type CORE_0_MONTR_ENA_Register is record
      --  Core0 dram0 area0 read monitor enable
      CORE_0_AREA_DRAM0_0_RD_ENA         : Boolean := False;
      --  Core0 dram0 area0 write monitor enable
      CORE_0_AREA_DRAM0_0_WR_ENA         : Boolean := False;
      --  Core0 dram0 area1 read monitor enable
      CORE_0_AREA_DRAM0_1_RD_ENA         : Boolean := False;
      --  Core0 dram0 area1 write monitor enable
      CORE_0_AREA_DRAM0_1_WR_ENA         : Boolean := False;
      --  Core0 PIF area0 read monitor enable
      CORE_0_AREA_PIF_0_RD_ENA           : Boolean := False;
      --  Core0 PIF area0 write monitor enable
      CORE_0_AREA_PIF_0_WR_ENA           : Boolean := False;
      --  Core0 PIF area1 read monitor enable
      CORE_0_AREA_PIF_1_RD_ENA           : Boolean := False;
      --  Core0 PIF area1 write monitor enable
      CORE_0_AREA_PIF_1_WR_ENA           : Boolean := False;
      --  Core0 stackpoint overflow monitor enable
      CORE_0_SP_SPILL_MIN_ENA            : Boolean := False;
      --  Core0 stackpoint underflow monitor enable
      CORE_0_SP_SPILL_MAX_ENA            : Boolean := False;
      --  IBUS busy monitor enable
      CORE_0_IRAM0_EXCEPTION_MONITOR_ENA : Boolean := False;
      --  DBUS busy monitor enbale
      CORE_0_DRAM0_EXCEPTION_MONITOR_ENA : Boolean := False;
      --  unspecified
      Reserved_12_31                     : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_MONTR_ENA_Register use record
      CORE_0_AREA_DRAM0_0_RD_ENA         at 0 range 0 .. 0;
      CORE_0_AREA_DRAM0_0_WR_ENA         at 0 range 1 .. 1;
      CORE_0_AREA_DRAM0_1_RD_ENA         at 0 range 2 .. 2;
      CORE_0_AREA_DRAM0_1_WR_ENA         at 0 range 3 .. 3;
      CORE_0_AREA_PIF_0_RD_ENA           at 0 range 4 .. 4;
      CORE_0_AREA_PIF_0_WR_ENA           at 0 range 5 .. 5;
      CORE_0_AREA_PIF_1_RD_ENA           at 0 range 6 .. 6;
      CORE_0_AREA_PIF_1_WR_ENA           at 0 range 7 .. 7;
      CORE_0_SP_SPILL_MIN_ENA            at 0 range 8 .. 8;
      CORE_0_SP_SPILL_MAX_ENA            at 0 range 9 .. 9;
      CORE_0_IRAM0_EXCEPTION_MONITOR_ENA at 0 range 10 .. 10;
      CORE_0_DRAM0_EXCEPTION_MONITOR_ENA at 0 range 11 .. 11;
      Reserved_12_31                     at 0 range 12 .. 31;
   end record;

   --  core0 monitor interrupt status register
   type CORE_0_INTR_RAW_Register is record
      --  Read-only. Core0 dram0 area0 read monitor interrupt status
      CORE_0_AREA_DRAM0_0_RD_RAW         : Boolean;
      --  Read-only. Core0 dram0 area0 write monitor interrupt status
      CORE_0_AREA_DRAM0_0_WR_RAW         : Boolean;
      --  Read-only. Core0 dram0 area1 read monitor interrupt status
      CORE_0_AREA_DRAM0_1_RD_RAW         : Boolean;
      --  Read-only. Core0 dram0 area1 write monitor interrupt status
      CORE_0_AREA_DRAM0_1_WR_RAW         : Boolean;
      --  Read-only. Core0 PIF area0 read monitor interrupt status
      CORE_0_AREA_PIF_0_RD_RAW           : Boolean;
      --  Read-only. Core0 PIF area0 write monitor interrupt status
      CORE_0_AREA_PIF_0_WR_RAW           : Boolean;
      --  Read-only. Core0 PIF area1 read monitor interrupt status
      CORE_0_AREA_PIF_1_RD_RAW           : Boolean;
      --  Read-only. Core0 PIF area1 write monitor interrupt status
      CORE_0_AREA_PIF_1_WR_RAW           : Boolean;
      --  Read-only. Core0 stackpoint overflow monitor interrupt status
      CORE_0_SP_SPILL_MIN_RAW            : Boolean;
      --  Read-only. Core0 stackpoint underflow monitor interrupt status
      CORE_0_SP_SPILL_MAX_RAW            : Boolean;
      --  Read-only. IBUS busy monitor interrupt status
      CORE_0_IRAM0_EXCEPTION_MONITOR_RAW : Boolean;
      --  Read-only. DBUS busy monitor initerrupt status
      CORE_0_DRAM0_EXCEPTION_MONITOR_RAW : Boolean;
      --  unspecified
      Reserved_12_31                     : ESP32S3_Registers.UInt20;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_INTR_RAW_Register use record
      CORE_0_AREA_DRAM0_0_RD_RAW         at 0 range 0 .. 0;
      CORE_0_AREA_DRAM0_0_WR_RAW         at 0 range 1 .. 1;
      CORE_0_AREA_DRAM0_1_RD_RAW         at 0 range 2 .. 2;
      CORE_0_AREA_DRAM0_1_WR_RAW         at 0 range 3 .. 3;
      CORE_0_AREA_PIF_0_RD_RAW           at 0 range 4 .. 4;
      CORE_0_AREA_PIF_0_WR_RAW           at 0 range 5 .. 5;
      CORE_0_AREA_PIF_1_RD_RAW           at 0 range 6 .. 6;
      CORE_0_AREA_PIF_1_WR_RAW           at 0 range 7 .. 7;
      CORE_0_SP_SPILL_MIN_RAW            at 0 range 8 .. 8;
      CORE_0_SP_SPILL_MAX_RAW            at 0 range 9 .. 9;
      CORE_0_IRAM0_EXCEPTION_MONITOR_RAW at 0 range 10 .. 10;
      CORE_0_DRAM0_EXCEPTION_MONITOR_RAW at 0 range 11 .. 11;
      Reserved_12_31                     at 0 range 12 .. 31;
   end record;

   --  core0 monitor interrupt enable register
   type CORE_0_INTR_ENA_Register is record
      --  Core0 dram0 area0 read monitor interrupt enable
      CORE_0_AREA_DRAM0_0_RD_INTR_ENA         : Boolean := False;
      --  Core0 dram0 area0 write monitor interrupt enable
      CORE_0_AREA_DRAM0_0_WR_INTR_ENA         : Boolean := False;
      --  Core0 dram0 area1 read monitor interrupt enable
      CORE_0_AREA_DRAM0_1_RD_INTR_ENA         : Boolean := False;
      --  Core0 dram0 area1 write monitor interrupt enable
      CORE_0_AREA_DRAM0_1_WR_INTR_ENA         : Boolean := False;
      --  Core0 PIF area0 read monitor interrupt enable
      CORE_0_AREA_PIF_0_RD_INTR_ENA           : Boolean := False;
      --  Core0 PIF area0 write monitor interrupt enable
      CORE_0_AREA_PIF_0_WR_INTR_ENA           : Boolean := False;
      --  Core0 PIF area1 read monitor interrupt enable
      CORE_0_AREA_PIF_1_RD_INTR_ENA           : Boolean := False;
      --  Core0 PIF area1 write monitor interrupt enable
      CORE_0_AREA_PIF_1_WR_INTR_ENA           : Boolean := False;
      --  Core0 stackpoint overflow monitor interrupt enable
      CORE_0_SP_SPILL_MIN_INTR_ENA            : Boolean := False;
      --  Core0 stackpoint underflow monitor interrupt enable
      CORE_0_SP_SPILL_MAX_INTR_ENA            : Boolean := False;
      --  IBUS busy monitor interrupt enable
      CORE_0_IRAM0_EXCEPTION_MONITOR_INTR_ENA : Boolean := False;
      --  DBUS busy monitor interrupt enbale
      CORE_0_DRAM0_EXCEPTION_MONITOR_INTR_ENA : Boolean := False;
      --  unspecified
      Reserved_12_31                          : ESP32S3_Registers.UInt20 :=
                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_INTR_ENA_Register use record
      CORE_0_AREA_DRAM0_0_RD_INTR_ENA         at 0 range 0 .. 0;
      CORE_0_AREA_DRAM0_0_WR_INTR_ENA         at 0 range 1 .. 1;
      CORE_0_AREA_DRAM0_1_RD_INTR_ENA         at 0 range 2 .. 2;
      CORE_0_AREA_DRAM0_1_WR_INTR_ENA         at 0 range 3 .. 3;
      CORE_0_AREA_PIF_0_RD_INTR_ENA           at 0 range 4 .. 4;
      CORE_0_AREA_PIF_0_WR_INTR_ENA           at 0 range 5 .. 5;
      CORE_0_AREA_PIF_1_RD_INTR_ENA           at 0 range 6 .. 6;
      CORE_0_AREA_PIF_1_WR_INTR_ENA           at 0 range 7 .. 7;
      CORE_0_SP_SPILL_MIN_INTR_ENA            at 0 range 8 .. 8;
      CORE_0_SP_SPILL_MAX_INTR_ENA            at 0 range 9 .. 9;
      CORE_0_IRAM0_EXCEPTION_MONITOR_INTR_ENA at 0 range 10 .. 10;
      CORE_0_DRAM0_EXCEPTION_MONITOR_INTR_ENA at 0 range 11 .. 11;
      Reserved_12_31                          at 0 range 12 .. 31;
   end record;

   --  core0 monitor interrupt clr register
   type CORE_0_INTR_CLR_Register is record
      --  Core0 dram0 area0 read monitor interrupt clr
      CORE_0_AREA_DRAM0_0_RD_CLR         : Boolean := False;
      --  Core0 dram0 area0 write monitor interrupt clr
      CORE_0_AREA_DRAM0_0_WR_CLR         : Boolean := False;
      --  Core0 dram0 area1 read monitor interrupt clr
      CORE_0_AREA_DRAM0_1_RD_CLR         : Boolean := False;
      --  Core0 dram0 area1 write monitor interrupt clr
      CORE_0_AREA_DRAM0_1_WR_CLR         : Boolean := False;
      --  Core0 PIF area0 read monitor interrupt clr
      CORE_0_AREA_PIF_0_RD_CLR           : Boolean := False;
      --  Core0 PIF area0 write monitor interrupt clr
      CORE_0_AREA_PIF_0_WR_CLR           : Boolean := False;
      --  Core0 PIF area1 read monitor interrupt clr
      CORE_0_AREA_PIF_1_RD_CLR           : Boolean := False;
      --  Core0 PIF area1 write monitor interrupt clr
      CORE_0_AREA_PIF_1_WR_CLR           : Boolean := False;
      --  Core0 stackpoint overflow monitor interrupt clr
      CORE_0_SP_SPILL_MIN_CLR            : Boolean := False;
      --  Core0 stackpoint underflow monitor interrupt clr
      CORE_0_SP_SPILL_MAX_CLR            : Boolean := False;
      --  IBUS busy monitor interrupt clr
      CORE_0_IRAM0_EXCEPTION_MONITOR_CLR : Boolean := False;
      --  DBUS busy monitor interrupt clr
      CORE_0_DRAM0_EXCEPTION_MONITOR_CLR : Boolean := False;
      --  unspecified
      Reserved_12_31                     : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_INTR_CLR_Register use record
      CORE_0_AREA_DRAM0_0_RD_CLR         at 0 range 0 .. 0;
      CORE_0_AREA_DRAM0_0_WR_CLR         at 0 range 1 .. 1;
      CORE_0_AREA_DRAM0_1_RD_CLR         at 0 range 2 .. 2;
      CORE_0_AREA_DRAM0_1_WR_CLR         at 0 range 3 .. 3;
      CORE_0_AREA_PIF_0_RD_CLR           at 0 range 4 .. 4;
      CORE_0_AREA_PIF_0_WR_CLR           at 0 range 5 .. 5;
      CORE_0_AREA_PIF_1_RD_CLR           at 0 range 6 .. 6;
      CORE_0_AREA_PIF_1_WR_CLR           at 0 range 7 .. 7;
      CORE_0_SP_SPILL_MIN_CLR            at 0 range 8 .. 8;
      CORE_0_SP_SPILL_MAX_CLR            at 0 range 9 .. 9;
      CORE_0_IRAM0_EXCEPTION_MONITOR_CLR at 0 range 10 .. 10;
      CORE_0_DRAM0_EXCEPTION_MONITOR_CLR at 0 range 11 .. 11;
      Reserved_12_31                     at 0 range 12 .. 31;
   end record;

   subtype CORE_0_SP_UNSTABLE_CORE_0_SP_UNSTABLE_Field is
     ESP32S3_Registers.Byte;

   --  core0 sp unstable configuration register
   type CORE_0_SP_UNSTABLE_Register is record
      --  unstable period when window change,during this period no check
      --  stackpointer
      CORE_0_SP_UNSTABLE : CORE_0_SP_UNSTABLE_CORE_0_SP_UNSTABLE_Field :=
                            16#B#;
      --  unspecified
      Reserved_8_31      : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_SP_UNSTABLE_Register use record
      CORE_0_SP_UNSTABLE at 0 range 0 .. 7;
      Reserved_8_31      at 0 range 8 .. 31;
   end record;

   --  core0 pdebug configuration register
   type CORE_0_RCD_PDEBUGENABLE_Register is record
      --  Core0 Pdebugenable,set 1 to open core0 Pdebug interface,then can get
      --  core0 PC
      CORE_0_RCD_PDEBUGENABLE : Boolean := False;
      --  unspecified
      Reserved_1_31           : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_RCD_PDEBUGENABLE_Register use record
      CORE_0_RCD_PDEBUGENABLE at 0 range 0 .. 0;
      Reserved_1_31           at 0 range 1 .. 31;
   end record;

   --  core0 pdebug status register
   type CORE_0_RCD_RECORDING_Register is record
      --  Pdebug record enable,set 1 to record core0 pdebug interface signal
      CORE_0_RCD_RECORDING : Boolean := False;
      --  unspecified
      Reserved_1_31        : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_RCD_RECORDING_Register use record
      CORE_0_RCD_RECORDING at 0 range 0 .. 0;
      Reserved_1_31        at 0 range 1 .. 31;
   end record;

   subtype CORE_0_RCD_PDEBUGSTATUS_CORE_0_RCD_PDEBUGSTATUS_Field is
     ESP32S3_Registers.Byte;

   --  core0 pdebug status register
   type CORE_0_RCD_PDEBUGSTATUS_Register is record
      --  Read-only. core0 pdebugstatus
      CORE_0_RCD_PDEBUGSTATUS : CORE_0_RCD_PDEBUGSTATUS_CORE_0_RCD_PDEBUGSTATUS_Field;
      --  unspecified
      Reserved_8_31           : ESP32S3_Registers.UInt24;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_RCD_PDEBUGSTATUS_Register use record
      CORE_0_RCD_PDEBUGSTATUS at 0 range 0 .. 7;
      Reserved_8_31           at 0 range 8 .. 31;
   end record;

   subtype CORE_0_IRAM0_EXCEPTION_MONITOR_0_CORE_0_IRAM0_RECORDING_ADDR_0_Field is
     ESP32S3_Registers.UInt24;

   --  core0 bus busy status regsiter
   type CORE_0_IRAM0_EXCEPTION_MONITOR_0_Register is record
      --  Read-only. The first iram0's addr[25:2] status when trigger IRAM busy
      --  interrupt
      CORE_0_IRAM0_RECORDING_ADDR_0      : CORE_0_IRAM0_EXCEPTION_MONITOR_0_CORE_0_IRAM0_RECORDING_ADDR_0_Field;
      --  Read-only. The first iram0's wr status when trigger IRAM busy
      --  interrupt
      CORE_0_IRAM0_RECORDING_WR_0        : Boolean;
      --  Read-only. The first iram0's loadstore status when trigger IRAM busy
      --  interrupt
      CORE_0_IRAM0_RECORDING_LOADSTORE_0 : Boolean;
      --  unspecified
      Reserved_26_31                     : ESP32S3_Registers.UInt6;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_IRAM0_EXCEPTION_MONITOR_0_Register use record
      CORE_0_IRAM0_RECORDING_ADDR_0      at 0 range 0 .. 23;
      CORE_0_IRAM0_RECORDING_WR_0        at 0 range 24 .. 24;
      CORE_0_IRAM0_RECORDING_LOADSTORE_0 at 0 range 25 .. 25;
      Reserved_26_31                     at 0 range 26 .. 31;
   end record;

   subtype CORE_0_IRAM0_EXCEPTION_MONITOR_1_CORE_0_IRAM0_RECORDING_ADDR_1_Field is
     ESP32S3_Registers.UInt24;

   --  core0 bus busy status regsiter
   type CORE_0_IRAM0_EXCEPTION_MONITOR_1_Register is record
      --  Read-only. The second iram0's addr[25:2] status when trigger IRAM
      --  busy interrupt
      CORE_0_IRAM0_RECORDING_ADDR_1      : CORE_0_IRAM0_EXCEPTION_MONITOR_1_CORE_0_IRAM0_RECORDING_ADDR_1_Field;
      --  Read-only. The second iram0's wr status when trigger IRAM busy
      --  interrupt
      CORE_0_IRAM0_RECORDING_WR_1        : Boolean;
      --  Read-only. The second iram0's loadstore status when trigger IRAM busy
      --  interrupt
      CORE_0_IRAM0_RECORDING_LOADSTORE_1 : Boolean;
      --  unspecified
      Reserved_26_31                     : ESP32S3_Registers.UInt6;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_IRAM0_EXCEPTION_MONITOR_1_Register use record
      CORE_0_IRAM0_RECORDING_ADDR_1      at 0 range 0 .. 23;
      CORE_0_IRAM0_RECORDING_WR_1        at 0 range 24 .. 24;
      CORE_0_IRAM0_RECORDING_LOADSTORE_1 at 0 range 25 .. 25;
      Reserved_26_31                     at 0 range 26 .. 31;
   end record;

   subtype CORE_0_DRAM0_EXCEPTION_MONITOR_0_CORE_0_DRAM0_RECORDING_ADDR_0_Field is
     ESP32S3_Registers.UInt22;

   --  core0 bus busy status regsiter
   type CORE_0_DRAM0_EXCEPTION_MONITOR_0_Register is record
      --  Read-only. The first dram0's addr[25:4] status when trigger DRAM busy
      --  interrupt
      CORE_0_DRAM0_RECORDING_ADDR_0 : CORE_0_DRAM0_EXCEPTION_MONITOR_0_CORE_0_DRAM0_RECORDING_ADDR_0_Field;
      --  Read-only. The first dram0's wr status when trigger DRAM busy
      --  interrupt
      CORE_0_DRAM0_RECORDING_WR_0   : Boolean;
      --  unspecified
      Reserved_23_31                : ESP32S3_Registers.UInt9;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_DRAM0_EXCEPTION_MONITOR_0_Register use record
      CORE_0_DRAM0_RECORDING_ADDR_0 at 0 range 0 .. 21;
      CORE_0_DRAM0_RECORDING_WR_0   at 0 range 22 .. 22;
      Reserved_23_31                at 0 range 23 .. 31;
   end record;

   subtype CORE_0_DRAM0_EXCEPTION_MONITOR_1_CORE_0_DRAM0_RECORDING_BYTEEN_0_Field is
     ESP32S3_Registers.UInt16;

   --  core0 bus busy status regsiter
   type CORE_0_DRAM0_EXCEPTION_MONITOR_1_Register is record
      --  Read-only. The first dram0's byteen status when trigger DRAM busy
      --  interrupt
      CORE_0_DRAM0_RECORDING_BYTEEN_0 : CORE_0_DRAM0_EXCEPTION_MONITOR_1_CORE_0_DRAM0_RECORDING_BYTEEN_0_Field;
      --  unspecified
      Reserved_16_31                  : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_DRAM0_EXCEPTION_MONITOR_1_Register use record
      CORE_0_DRAM0_RECORDING_BYTEEN_0 at 0 range 0 .. 15;
      Reserved_16_31                  at 0 range 16 .. 31;
   end record;

   subtype CORE_0_DRAM0_EXCEPTION_MONITOR_3_CORE_0_DRAM0_RECORDING_ADDR_1_Field is
     ESP32S3_Registers.UInt22;

   --  core0 bus busy status regsiter
   type CORE_0_DRAM0_EXCEPTION_MONITOR_3_Register is record
      --  Read-only. The second dram0's addr[25:4] status when trigger DRAM
      --  busy interrupt
      CORE_0_DRAM0_RECORDING_ADDR_1 : CORE_0_DRAM0_EXCEPTION_MONITOR_3_CORE_0_DRAM0_RECORDING_ADDR_1_Field;
      --  Read-only. The second dram0's wr status when trigger DRAM busy
      --  interrupt
      CORE_0_DRAM0_RECORDING_WR_1   : Boolean;
      --  unspecified
      Reserved_23_31                : ESP32S3_Registers.UInt9;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_DRAM0_EXCEPTION_MONITOR_3_Register use record
      CORE_0_DRAM0_RECORDING_ADDR_1 at 0 range 0 .. 21;
      CORE_0_DRAM0_RECORDING_WR_1   at 0 range 22 .. 22;
      Reserved_23_31                at 0 range 23 .. 31;
   end record;

   subtype CORE_0_DRAM0_EXCEPTION_MONITOR_4_CORE_0_DRAM0_RECORDING_BYTEEN_1_Field is
     ESP32S3_Registers.UInt16;

   --  core0 bus busy configuration regsiter
   type CORE_0_DRAM0_EXCEPTION_MONITOR_4_Register is record
      --  Read-only. The second dram0's byteen status when trigger DRAM busy
      --  interrupt
      CORE_0_DRAM0_RECORDING_BYTEEN_1 : CORE_0_DRAM0_EXCEPTION_MONITOR_4_CORE_0_DRAM0_RECORDING_BYTEEN_1_Field;
      --  unspecified
      Reserved_16_31                  : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_DRAM0_EXCEPTION_MONITOR_4_Register use record
      CORE_0_DRAM0_RECORDING_BYTEEN_1 at 0 range 0 .. 15;
      Reserved_16_31                  at 0 range 16 .. 31;
   end record;

   --  Core1 monitor enable configuration register
   type CORE_1_MONTR_ENA_Register is record
      --  Core1 dram0 area0 read monitor enable
      CORE_1_AREA_DRAM0_0_RD_ENA         : Boolean := False;
      --  Core1 dram0 area0 write monitor enable
      CORE_1_AREA_DRAM0_0_WR_ENA         : Boolean := False;
      --  Core1 dram0 area1 read monitor enable
      CORE_1_AREA_DRAM0_1_RD_ENA         : Boolean := False;
      --  Core1 dram0 area1 write monitor enable
      CORE_1_AREA_DRAM0_1_WR_ENA         : Boolean := False;
      --  Core1 PIF area0 read monitor enable
      CORE_1_AREA_PIF_0_RD_ENA           : Boolean := False;
      --  Core1 PIF area0 write monitor enable
      CORE_1_AREA_PIF_0_WR_ENA           : Boolean := False;
      --  Core1 PIF area1 read monitor enable
      CORE_1_AREA_PIF_1_RD_ENA           : Boolean := False;
      --  Core1 PIF area1 write monitor enable
      CORE_1_AREA_PIF_1_WR_ENA           : Boolean := False;
      --  Core1 stackpoint overflow monitor enable
      CORE_1_SP_SPILL_MIN_ENA            : Boolean := False;
      --  Core1 stackpoint underflow monitor enable
      CORE_1_SP_SPILL_MAX_ENA            : Boolean := False;
      --  IBUS busy monitor enable
      CORE_1_IRAM0_EXCEPTION_MONITOR_ENA : Boolean := False;
      --  DBUS busy monitor enbale
      CORE_1_DRAM0_EXCEPTION_MONITOR_ENA : Boolean := False;
      --  unspecified
      Reserved_12_31                     : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_MONTR_ENA_Register use record
      CORE_1_AREA_DRAM0_0_RD_ENA         at 0 range 0 .. 0;
      CORE_1_AREA_DRAM0_0_WR_ENA         at 0 range 1 .. 1;
      CORE_1_AREA_DRAM0_1_RD_ENA         at 0 range 2 .. 2;
      CORE_1_AREA_DRAM0_1_WR_ENA         at 0 range 3 .. 3;
      CORE_1_AREA_PIF_0_RD_ENA           at 0 range 4 .. 4;
      CORE_1_AREA_PIF_0_WR_ENA           at 0 range 5 .. 5;
      CORE_1_AREA_PIF_1_RD_ENA           at 0 range 6 .. 6;
      CORE_1_AREA_PIF_1_WR_ENA           at 0 range 7 .. 7;
      CORE_1_SP_SPILL_MIN_ENA            at 0 range 8 .. 8;
      CORE_1_SP_SPILL_MAX_ENA            at 0 range 9 .. 9;
      CORE_1_IRAM0_EXCEPTION_MONITOR_ENA at 0 range 10 .. 10;
      CORE_1_DRAM0_EXCEPTION_MONITOR_ENA at 0 range 11 .. 11;
      Reserved_12_31                     at 0 range 12 .. 31;
   end record;

   --  Core1 monitor interrupt status register
   type CORE_1_INTR_RAW_Register is record
      --  Read-only. Core1 dram0 area0 read monitor interrupt status
      CORE_1_AREA_DRAM0_0_RD_RAW         : Boolean;
      --  Read-only. Core1 dram0 area0 write monitor interrupt status
      CORE_1_AREA_DRAM0_0_WR_RAW         : Boolean;
      --  Read-only. Core1 dram0 area1 read monitor interrupt status
      CORE_1_AREA_DRAM0_1_RD_RAW         : Boolean;
      --  Read-only. Core1 dram0 area1 write monitor interrupt status
      CORE_1_AREA_DRAM0_1_WR_RAW         : Boolean;
      --  Read-only. Core1 PIF area0 read monitor interrupt status
      CORE_1_AREA_PIF_0_RD_RAW           : Boolean;
      --  Read-only. Core1 PIF area0 write monitor interrupt status
      CORE_1_AREA_PIF_0_WR_RAW           : Boolean;
      --  Read-only. Core1 PIF area1 read monitor interrupt status
      CORE_1_AREA_PIF_1_RD_RAW           : Boolean;
      --  Read-only. Core1 PIF area1 write monitor interrupt status
      CORE_1_AREA_PIF_1_WR_RAW           : Boolean;
      --  Read-only. Core1 stackpoint overflow monitor interrupt status
      CORE_1_SP_SPILL_MIN_RAW            : Boolean;
      --  Read-only. Core1 stackpoint underflow monitor interrupt status
      CORE_1_SP_SPILL_MAX_RAW            : Boolean;
      --  Read-only. IBUS busy monitor interrupt status
      CORE_1_IRAM0_EXCEPTION_MONITOR_RAW : Boolean;
      --  Read-only. DBUS busy monitor initerrupt status
      CORE_1_DRAM0_EXCEPTION_MONITOR_RAW : Boolean;
      --  unspecified
      Reserved_12_31                     : ESP32S3_Registers.UInt20;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_INTR_RAW_Register use record
      CORE_1_AREA_DRAM0_0_RD_RAW         at 0 range 0 .. 0;
      CORE_1_AREA_DRAM0_0_WR_RAW         at 0 range 1 .. 1;
      CORE_1_AREA_DRAM0_1_RD_RAW         at 0 range 2 .. 2;
      CORE_1_AREA_DRAM0_1_WR_RAW         at 0 range 3 .. 3;
      CORE_1_AREA_PIF_0_RD_RAW           at 0 range 4 .. 4;
      CORE_1_AREA_PIF_0_WR_RAW           at 0 range 5 .. 5;
      CORE_1_AREA_PIF_1_RD_RAW           at 0 range 6 .. 6;
      CORE_1_AREA_PIF_1_WR_RAW           at 0 range 7 .. 7;
      CORE_1_SP_SPILL_MIN_RAW            at 0 range 8 .. 8;
      CORE_1_SP_SPILL_MAX_RAW            at 0 range 9 .. 9;
      CORE_1_IRAM0_EXCEPTION_MONITOR_RAW at 0 range 10 .. 10;
      CORE_1_DRAM0_EXCEPTION_MONITOR_RAW at 0 range 11 .. 11;
      Reserved_12_31                     at 0 range 12 .. 31;
   end record;

   --  Core1 monitor interrupt enable register
   type CORE_1_INTR_ENA_Register is record
      --  Core1 dram0 area0 read monitor interrupt enable
      CORE_1_AREA_DRAM0_0_RD_INTR_ENA         : Boolean := False;
      --  Core1 dram0 area0 write monitor interrupt enable
      CORE_1_AREA_DRAM0_0_WR_INTR_ENA         : Boolean := False;
      --  Core1 dram0 area1 read monitor interrupt enable
      CORE_1_AREA_DRAM0_1_RD_INTR_ENA         : Boolean := False;
      --  Core1 dram0 area1 write monitor interrupt enable
      CORE_1_AREA_DRAM0_1_WR_INTR_ENA         : Boolean := False;
      --  Core1 PIF area0 read monitor interrupt enable
      CORE_1_AREA_PIF_0_RD_INTR_ENA           : Boolean := False;
      --  Core1 PIF area0 write monitor interrupt enable
      CORE_1_AREA_PIF_0_WR_INTR_ENA           : Boolean := False;
      --  Core1 PIF area1 read monitor interrupt enable
      CORE_1_AREA_PIF_1_RD_INTR_ENA           : Boolean := False;
      --  Core1 PIF area1 write monitor interrupt enable
      CORE_1_AREA_PIF_1_WR_INTR_ENA           : Boolean := False;
      --  Core1 stackpoint overflow monitor interrupt enable
      CORE_1_SP_SPILL_MIN_INTR_ENA            : Boolean := False;
      --  Core1 stackpoint underflow monitor interrupt enable
      CORE_1_SP_SPILL_MAX_INTR_ENA            : Boolean := False;
      --  IBUS busy monitor interrupt enable
      CORE_1_IRAM0_EXCEPTION_MONITOR_INTR_ENA : Boolean := False;
      --  DBUS busy monitor interrupt enbale
      CORE_1_DRAM0_EXCEPTION_MONITOR_INTR_ENA : Boolean := False;
      --  unspecified
      Reserved_12_31                          : ESP32S3_Registers.UInt20 :=
                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_INTR_ENA_Register use record
      CORE_1_AREA_DRAM0_0_RD_INTR_ENA         at 0 range 0 .. 0;
      CORE_1_AREA_DRAM0_0_WR_INTR_ENA         at 0 range 1 .. 1;
      CORE_1_AREA_DRAM0_1_RD_INTR_ENA         at 0 range 2 .. 2;
      CORE_1_AREA_DRAM0_1_WR_INTR_ENA         at 0 range 3 .. 3;
      CORE_1_AREA_PIF_0_RD_INTR_ENA           at 0 range 4 .. 4;
      CORE_1_AREA_PIF_0_WR_INTR_ENA           at 0 range 5 .. 5;
      CORE_1_AREA_PIF_1_RD_INTR_ENA           at 0 range 6 .. 6;
      CORE_1_AREA_PIF_1_WR_INTR_ENA           at 0 range 7 .. 7;
      CORE_1_SP_SPILL_MIN_INTR_ENA            at 0 range 8 .. 8;
      CORE_1_SP_SPILL_MAX_INTR_ENA            at 0 range 9 .. 9;
      CORE_1_IRAM0_EXCEPTION_MONITOR_INTR_ENA at 0 range 10 .. 10;
      CORE_1_DRAM0_EXCEPTION_MONITOR_INTR_ENA at 0 range 11 .. 11;
      Reserved_12_31                          at 0 range 12 .. 31;
   end record;

   --  Core1 monitor interrupt clr register
   type CORE_1_INTR_CLR_Register is record
      --  Core1 dram0 area0 read monitor interrupt clr
      CORE_1_AREA_DRAM0_0_RD_CLR         : Boolean := False;
      --  Core1 dram0 area0 write monitor interrupt clr
      CORE_1_AREA_DRAM0_0_WR_CLR         : Boolean := False;
      --  Core1 dram0 area1 read monitor interrupt clr
      CORE_1_AREA_DRAM0_1_RD_CLR         : Boolean := False;
      --  Core1 dram0 area1 write monitor interrupt clr
      CORE_1_AREA_DRAM0_1_WR_CLR         : Boolean := False;
      --  Core1 PIF area0 read monitor interrupt clr
      CORE_1_AREA_PIF_0_RD_CLR           : Boolean := False;
      --  Core1 PIF area0 write monitor interrupt clr
      CORE_1_AREA_PIF_0_WR_CLR           : Boolean := False;
      --  Core1 PIF area1 read monitor interrupt clr
      CORE_1_AREA_PIF_1_RD_CLR           : Boolean := False;
      --  Core1 PIF area1 write monitor interrupt clr
      CORE_1_AREA_PIF_1_WR_CLR           : Boolean := False;
      --  Core1 stackpoint overflow monitor interrupt clr
      CORE_1_SP_SPILL_MIN_CLR            : Boolean := False;
      --  Core1 stackpoint underflow monitor interrupt clr
      CORE_1_SP_SPILL_MAX_CLR            : Boolean := False;
      --  IBUS busy monitor interrupt clr
      CORE_1_IRAM0_EXCEPTION_MONITOR_CLR : Boolean := False;
      --  DBUS busy monitor interrupt clr
      CORE_1_DRAM0_EXCEPTION_MONITOR_CLR : Boolean := False;
      --  unspecified
      Reserved_12_31                     : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_INTR_CLR_Register use record
      CORE_1_AREA_DRAM0_0_RD_CLR         at 0 range 0 .. 0;
      CORE_1_AREA_DRAM0_0_WR_CLR         at 0 range 1 .. 1;
      CORE_1_AREA_DRAM0_1_RD_CLR         at 0 range 2 .. 2;
      CORE_1_AREA_DRAM0_1_WR_CLR         at 0 range 3 .. 3;
      CORE_1_AREA_PIF_0_RD_CLR           at 0 range 4 .. 4;
      CORE_1_AREA_PIF_0_WR_CLR           at 0 range 5 .. 5;
      CORE_1_AREA_PIF_1_RD_CLR           at 0 range 6 .. 6;
      CORE_1_AREA_PIF_1_WR_CLR           at 0 range 7 .. 7;
      CORE_1_SP_SPILL_MIN_CLR            at 0 range 8 .. 8;
      CORE_1_SP_SPILL_MAX_CLR            at 0 range 9 .. 9;
      CORE_1_IRAM0_EXCEPTION_MONITOR_CLR at 0 range 10 .. 10;
      CORE_1_DRAM0_EXCEPTION_MONITOR_CLR at 0 range 11 .. 11;
      Reserved_12_31                     at 0 range 12 .. 31;
   end record;

   subtype CORE_1_SP_UNSTABLE_CORE_1_SP_UNSTABLE_Field is
     ESP32S3_Registers.Byte;

   --  Core1 sp unstable configuration register
   type CORE_1_SP_UNSTABLE_Register is record
      --  unstable period when window change,during this period no check
      --  stackpointer
      CORE_1_SP_UNSTABLE : CORE_1_SP_UNSTABLE_CORE_1_SP_UNSTABLE_Field :=
                            16#B#;
      --  unspecified
      Reserved_8_31      : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_SP_UNSTABLE_Register use record
      CORE_1_SP_UNSTABLE at 0 range 0 .. 7;
      Reserved_8_31      at 0 range 8 .. 31;
   end record;

   --  Core1 pdebug configuration register
   type CORE_1_RCD_PDEBUGENABLE_Register is record
      --  Core1 Pdebugenable,set 1 to open Core1 Pdebug interface, then can get
      --  Core1 PC
      CORE_1_RCD_PDEBUGENABLE : Boolean := False;
      --  unspecified
      Reserved_1_31           : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_RCD_PDEBUGENABLE_Register use record
      CORE_1_RCD_PDEBUGENABLE at 0 range 0 .. 0;
      Reserved_1_31           at 0 range 1 .. 31;
   end record;

   --  Core1 pdebug status register
   type CORE_1_RCD_RECORDING_Register is record
      --  Pdebug record enable,set 1 to record Core1 pdebug interface signal
      CORE_1_RCD_RECORDING : Boolean := False;
      --  unspecified
      Reserved_1_31        : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_RCD_RECORDING_Register use record
      CORE_1_RCD_RECORDING at 0 range 0 .. 0;
      Reserved_1_31        at 0 range 1 .. 31;
   end record;

   subtype CORE_1_RCD_PDEBUGSTATUS_CORE_1_RCD_PDEBUGSTATUS_Field is
     ESP32S3_Registers.Byte;

   --  Core1 pdebug status register
   type CORE_1_RCD_PDEBUGSTATUS_Register is record
      --  Read-only. Core1 pdebugstatus
      CORE_1_RCD_PDEBUGSTATUS : CORE_1_RCD_PDEBUGSTATUS_CORE_1_RCD_PDEBUGSTATUS_Field;
      --  unspecified
      Reserved_8_31           : ESP32S3_Registers.UInt24;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_RCD_PDEBUGSTATUS_Register use record
      CORE_1_RCD_PDEBUGSTATUS at 0 range 0 .. 7;
      Reserved_8_31           at 0 range 8 .. 31;
   end record;

   subtype CORE_1_IRAM0_EXCEPTION_MONITOR_0_CORE_1_IRAM0_RECORDING_ADDR_0_Field is
     ESP32S3_Registers.UInt24;

   --  Core1 bus busy status regsiter
   type CORE_1_IRAM0_EXCEPTION_MONITOR_0_Register is record
      --  Read-only. The first iram0's addr[25:2] status when trigger IRAM busy
      --  interrupt
      CORE_1_IRAM0_RECORDING_ADDR_0      : CORE_1_IRAM0_EXCEPTION_MONITOR_0_CORE_1_IRAM0_RECORDING_ADDR_0_Field;
      --  Read-only. The first iram0's wr status when trigger IRAM busy
      --  interrupt
      CORE_1_IRAM0_RECORDING_WR_0        : Boolean;
      --  Read-only. The first iram0's loadstore status when trigger IRAM busy
      --  interrupt
      CORE_1_IRAM0_RECORDING_LOADSTORE_0 : Boolean;
      --  unspecified
      Reserved_26_31                     : ESP32S3_Registers.UInt6;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_IRAM0_EXCEPTION_MONITOR_0_Register use record
      CORE_1_IRAM0_RECORDING_ADDR_0      at 0 range 0 .. 23;
      CORE_1_IRAM0_RECORDING_WR_0        at 0 range 24 .. 24;
      CORE_1_IRAM0_RECORDING_LOADSTORE_0 at 0 range 25 .. 25;
      Reserved_26_31                     at 0 range 26 .. 31;
   end record;

   subtype CORE_1_IRAM0_EXCEPTION_MONITOR_1_CORE_1_IRAM0_RECORDING_ADDR_1_Field is
     ESP32S3_Registers.UInt24;

   --  Core1 bus busy status regsiter
   type CORE_1_IRAM0_EXCEPTION_MONITOR_1_Register is record
      --  Read-only. The second iram0's addr[25:2] status when trigger IRAM
      --  busy interrupt
      CORE_1_IRAM0_RECORDING_ADDR_1      : CORE_1_IRAM0_EXCEPTION_MONITOR_1_CORE_1_IRAM0_RECORDING_ADDR_1_Field;
      --  Read-only. The second iram0's wr status when trigger IRAM busy
      --  interrupt
      CORE_1_IRAM0_RECORDING_WR_1        : Boolean;
      --  Read-only. The second iram0's loadstore status when trigger IRAM busy
      --  interrupt
      CORE_1_IRAM0_RECORDING_LOADSTORE_1 : Boolean;
      --  unspecified
      Reserved_26_31                     : ESP32S3_Registers.UInt6;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_IRAM0_EXCEPTION_MONITOR_1_Register use record
      CORE_1_IRAM0_RECORDING_ADDR_1      at 0 range 0 .. 23;
      CORE_1_IRAM0_RECORDING_WR_1        at 0 range 24 .. 24;
      CORE_1_IRAM0_RECORDING_LOADSTORE_1 at 0 range 25 .. 25;
      Reserved_26_31                     at 0 range 26 .. 31;
   end record;

   subtype CORE_1_DRAM0_EXCEPTION_MONITOR_0_CORE_1_DRAM0_RECORDING_ADDR_0_Field is
     ESP32S3_Registers.UInt22;

   --  Core1 bus busy status regsiter
   type CORE_1_DRAM0_EXCEPTION_MONITOR_0_Register is record
      --  Read-only. The first dram0's addr[25:4] status when trigger DRAM busy
      --  interrupt
      CORE_1_DRAM0_RECORDING_ADDR_0 : CORE_1_DRAM0_EXCEPTION_MONITOR_0_CORE_1_DRAM0_RECORDING_ADDR_0_Field;
      --  Read-only. The first dram0's wr status when trigger DRAM busy
      --  interrupt
      CORE_1_DRAM0_RECORDING_WR_0   : Boolean;
      --  unspecified
      Reserved_23_31                : ESP32S3_Registers.UInt9;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_DRAM0_EXCEPTION_MONITOR_0_Register use record
      CORE_1_DRAM0_RECORDING_ADDR_0 at 0 range 0 .. 21;
      CORE_1_DRAM0_RECORDING_WR_0   at 0 range 22 .. 22;
      Reserved_23_31                at 0 range 23 .. 31;
   end record;

   subtype CORE_1_DRAM0_EXCEPTION_MONITOR_1_CORE_1_DRAM0_RECORDING_BYTEEN_0_Field is
     ESP32S3_Registers.UInt16;

   --  Core1 bus busy status regsiter
   type CORE_1_DRAM0_EXCEPTION_MONITOR_1_Register is record
      --  Read-only. The first dram0's byteen status when trigger DRAM busy
      --  interrupt
      CORE_1_DRAM0_RECORDING_BYTEEN_0 : CORE_1_DRAM0_EXCEPTION_MONITOR_1_CORE_1_DRAM0_RECORDING_BYTEEN_0_Field;
      --  unspecified
      Reserved_16_31                  : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_DRAM0_EXCEPTION_MONITOR_1_Register use record
      CORE_1_DRAM0_RECORDING_BYTEEN_0 at 0 range 0 .. 15;
      Reserved_16_31                  at 0 range 16 .. 31;
   end record;

   subtype CORE_1_DRAM0_EXCEPTION_MONITOR_3_CORE_1_DRAM0_RECORDING_ADDR_1_Field is
     ESP32S3_Registers.UInt22;

   --  Core1 bus busy status regsiter
   type CORE_1_DRAM0_EXCEPTION_MONITOR_3_Register is record
      --  Read-only. The second dram0's addr[25:4] status when trigger DRAM
      --  busy interrupt
      CORE_1_DRAM0_RECORDING_ADDR_1 : CORE_1_DRAM0_EXCEPTION_MONITOR_3_CORE_1_DRAM0_RECORDING_ADDR_1_Field;
      --  Read-only. The second dram0's wr status when trigger DRAM busy
      --  interrupt
      CORE_1_DRAM0_RECORDING_WR_1   : Boolean;
      --  unspecified
      Reserved_23_31                : ESP32S3_Registers.UInt9;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_DRAM0_EXCEPTION_MONITOR_3_Register use record
      CORE_1_DRAM0_RECORDING_ADDR_1 at 0 range 0 .. 21;
      CORE_1_DRAM0_RECORDING_WR_1   at 0 range 22 .. 22;
      Reserved_23_31                at 0 range 23 .. 31;
   end record;

   subtype CORE_1_DRAM0_EXCEPTION_MONITOR_4_CORE_1_DRAM0_RECORDING_BYTEEN_1_Field is
     ESP32S3_Registers.UInt16;

   --  Core1 bus busy status regsiter
   type CORE_1_DRAM0_EXCEPTION_MONITOR_4_Register is record
      --  Read-only. The second dram0's byteen status when trigger DRAM busy
      --  interrupt
      CORE_1_DRAM0_RECORDING_BYTEEN_1 : CORE_1_DRAM0_EXCEPTION_MONITOR_4_CORE_1_DRAM0_RECORDING_BYTEEN_1_Field;
      --  unspecified
      Reserved_16_31                  : ESP32S3_Registers.UInt16;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_DRAM0_EXCEPTION_MONITOR_4_Register use record
      CORE_1_DRAM0_RECORDING_BYTEEN_1 at 0 range 0 .. 15;
      Reserved_16_31                  at 0 range 16 .. 31;
   end record;

   subtype CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_0_CORE_X_IRAM0_DRAM0_LIMIT_CYCLE_0_Field is
     ESP32S3_Registers.UInt20;

   --  bus busy configuration register
   type CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_0_Register is record
      --  busy monitor window cycle
      CORE_X_IRAM0_DRAM0_LIMIT_CYCLE_0 : CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_0_CORE_X_IRAM0_DRAM0_LIMIT_CYCLE_0_Field :=
                                          16#FFFFF#;
      --  unspecified
      Reserved_20_31                   : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_0_Register use record
      CORE_X_IRAM0_DRAM0_LIMIT_CYCLE_0 at 0 range 0 .. 19;
      Reserved_20_31                   at 0 range 20 .. 31;
   end record;

   subtype CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_1_CORE_X_IRAM0_DRAM0_LIMIT_CYCLE_1_Field is
     ESP32S3_Registers.UInt20;

   --  bus busy configuration register
   type CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_1_Register is record
      --  non busy cycle,for example: when cycle=100 and cycle=10,it means that
      --  in 100 cycle, if busy access success time less than 10, it will
      --  trigger interrutpt
      CORE_X_IRAM0_DRAM0_LIMIT_CYCLE_1 : CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_1_CORE_X_IRAM0_DRAM0_LIMIT_CYCLE_1_Field :=
                                          16#FFFFF#;
      --  unspecified
      Reserved_20_31                   : ESP32S3_Registers.UInt12 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_1_Register use record
      CORE_X_IRAM0_DRAM0_LIMIT_CYCLE_1 at 0 range 0 .. 19;
      Reserved_20_31                   at 0 range 20 .. 31;
   end record;

   subtype LOG_SETTING_LOG_ENA_Field is ESP32S3_Registers.UInt3;
   subtype LOG_SETTING_LOG_MODE_Field is ESP32S3_Registers.UInt3;

   --  log set register
   type LOG_SETTING_Register is record
      --  bus moniter enable: [0]Core1,[1]core1,[2]dma
      LOG_ENA             : LOG_SETTING_LOG_ENA_Field := 16#0#;
      --  check_mode:0:write,1:word,2:halword,3:byte,4:doubleword,5:4word
      LOG_MODE            : LOG_SETTING_LOG_MODE_Field := 16#0#;
      --  mem_loop enable,1 means that loop write
      LOG_MEM_LOOP_ENABLE : Boolean := True;
      --  unspecified
      Reserved_7_31       : ESP32S3_Registers.UInt25 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LOG_SETTING_Register use record
      LOG_ENA             at 0 range 0 .. 2;
      LOG_MODE            at 0 range 3 .. 5;
      LOG_MEM_LOOP_ENABLE at 0 range 6 .. 6;
      Reserved_7_31       at 0 range 7 .. 31;
   end record;

   subtype LOG_DATA_MASK_LOG_DATA_SIZE_Field is ESP32S3_Registers.UInt16;

   --  log check data mask register
   type LOG_DATA_MASK_Register is record
      --  data mask
      LOG_DATA_SIZE  : LOG_DATA_MASK_LOG_DATA_SIZE_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LOG_DATA_MASK_Register use record
      LOG_DATA_SIZE  at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   --  log mem status register
   type LOG_MEM_FULL_FLAG_Register is record
      --  when it's 1,show that mem write loop morte than one time.
      LOG_MEM_FULL_FLAG : Boolean := False;
      --  unspecified
      Reserved_1_31     : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LOG_MEM_FULL_FLAG_Register use record
      LOG_MEM_FULL_FLAG at 0 range 0 .. 0;
      Reserved_1_31     at 0 range 1 .. 31;
   end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt28;

   --  version register
   type DATE_Register is record
      --  version register
      DATE           : DATE_DATE_Field := 16#2003040#;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DATE_Register use record
      DATE           at 0 range 0 .. 27;
      Reserved_28_31 at 0 range 28 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Debug Assist
   type ASSIST_DEBUG_Peripheral is record
      --  core0 monitor enable configuration register
      CORE_0_MONTR_ENA                       : aliased CORE_0_MONTR_ENA_Register;
      --  core0 monitor interrupt status register
      CORE_0_INTR_RAW                        : aliased CORE_0_INTR_RAW_Register;
      --  core0 monitor interrupt enable register
      CORE_0_INTR_ENA                        : aliased CORE_0_INTR_ENA_Register;
      --  core0 monitor interrupt clr register
      CORE_0_INTR_CLR                        : aliased CORE_0_INTR_CLR_Register;
      --  core0 dram0 region0 addr configuration register
      CORE_0_AREA_DRAM0_0_MIN                : aliased ESP32S3_Registers.UInt32;
      --  core0 dram0 region0 addr configuration register
      CORE_0_AREA_DRAM0_0_MAX                : aliased ESP32S3_Registers.UInt32;
      --  core0 dram0 region1 addr configuration register
      CORE_0_AREA_DRAM0_1_MIN                : aliased ESP32S3_Registers.UInt32;
      --  core0 dram0 region1 addr configuration register
      CORE_0_AREA_DRAM0_1_MAX                : aliased ESP32S3_Registers.UInt32;
      --  core0 PIF region0 addr configuration register
      CORE_0_AREA_PIF_0_MIN                  : aliased ESP32S3_Registers.UInt32;
      --  core0 PIF region0 addr configuration register
      CORE_0_AREA_PIF_0_MAX                  : aliased ESP32S3_Registers.UInt32;
      --  core0 PIF region1 addr configuration register
      CORE_0_AREA_PIF_1_MIN                  : aliased ESP32S3_Registers.UInt32;
      --  core0 PIF region1 addr configuration register
      CORE_0_AREA_PIF_1_MAX                  : aliased ESP32S3_Registers.UInt32;
      --  core0 area sp status register
      CORE_0_AREA_SP                         : aliased ESP32S3_Registers.UInt32;
      --  core0 area pc status register
      CORE_0_AREA_PC                         : aliased ESP32S3_Registers.UInt32;
      --  core0 sp unstable configuration register
      CORE_0_SP_UNSTABLE                     : aliased CORE_0_SP_UNSTABLE_Register;
      --  core0 sp region configuration regsiter
      CORE_0_SP_MIN                          : aliased ESP32S3_Registers.UInt32;
      --  core0 sp region configuration regsiter
      CORE_0_SP_MAX                          : aliased ESP32S3_Registers.UInt32;
      --  core0 sp pc status register
      CORE_0_SP_PC                           : aliased ESP32S3_Registers.UInt32;
      --  core0 pdebug configuration register
      CORE_0_RCD_PDEBUGENABLE                : aliased CORE_0_RCD_PDEBUGENABLE_Register;
      --  core0 pdebug status register
      CORE_0_RCD_RECORDING                   : aliased CORE_0_RCD_RECORDING_Register;
      --  core0 pdebug status register
      CORE_0_RCD_PDEBUGINST                  : aliased ESP32S3_Registers.UInt32;
      --  core0 pdebug status register
      CORE_0_RCD_PDEBUGSTATUS                : aliased CORE_0_RCD_PDEBUGSTATUS_Register;
      --  core0 pdebug status register
      CORE_0_RCD_PDEBUGDATA                  : aliased ESP32S3_Registers.UInt32;
      --  core0 pdebug status register
      CORE_0_RCD_PDEBUGPC                    : aliased ESP32S3_Registers.UInt32;
      --  core0 pdebug status register
      CORE_0_RCD_PDEBUGLS0STAT               : aliased ESP32S3_Registers.UInt32;
      --  core0 pdebug status register
      CORE_0_RCD_PDEBUGLS0ADDR               : aliased ESP32S3_Registers.UInt32;
      --  core0 pdebug status register
      CORE_0_RCD_PDEBUGLS0DATA               : aliased ESP32S3_Registers.UInt32;
      --  core0 pdebug status register
      CORE_0_RCD_SP                          : aliased ESP32S3_Registers.UInt32;
      --  core0 bus busy status regsiter
      CORE_0_IRAM0_EXCEPTION_MONITOR_0       : aliased CORE_0_IRAM0_EXCEPTION_MONITOR_0_Register;
      --  core0 bus busy status regsiter
      CORE_0_IRAM0_EXCEPTION_MONITOR_1       : aliased CORE_0_IRAM0_EXCEPTION_MONITOR_1_Register;
      --  core0 bus busy status regsiter
      CORE_0_DRAM0_EXCEPTION_MONITOR_0       : aliased CORE_0_DRAM0_EXCEPTION_MONITOR_0_Register;
      --  core0 bus busy status regsiter
      CORE_0_DRAM0_EXCEPTION_MONITOR_1       : aliased CORE_0_DRAM0_EXCEPTION_MONITOR_1_Register;
      --  core0 bus busy status regsiter
      CORE_0_DRAM0_EXCEPTION_MONITOR_2       : aliased ESP32S3_Registers.UInt32;
      --  core0 bus busy status regsiter
      CORE_0_DRAM0_EXCEPTION_MONITOR_3       : aliased CORE_0_DRAM0_EXCEPTION_MONITOR_3_Register;
      --  core0 bus busy configuration regsiter
      CORE_0_DRAM0_EXCEPTION_MONITOR_4       : aliased CORE_0_DRAM0_EXCEPTION_MONITOR_4_Register;
      --  core0 bus busy configuration regsiter
      CORE_0_DRAM0_EXCEPTION_MONITOR_5       : aliased ESP32S3_Registers.UInt32;
      --  Core1 monitor enable configuration register
      CORE_1_MONTR_ENA                       : aliased CORE_1_MONTR_ENA_Register;
      --  Core1 monitor interrupt status register
      CORE_1_INTR_RAW                        : aliased CORE_1_INTR_RAW_Register;
      --  Core1 monitor interrupt enable register
      CORE_1_INTR_ENA                        : aliased CORE_1_INTR_ENA_Register;
      --  Core1 monitor interrupt clr register
      CORE_1_INTR_CLR                        : aliased CORE_1_INTR_CLR_Register;
      --  Core1 dram0 region0 addr configuration register
      CORE_1_AREA_DRAM0_0_MIN                : aliased ESP32S3_Registers.UInt32;
      --  Core1 dram0 region0 addr configuration register
      CORE_1_AREA_DRAM0_0_MAX                : aliased ESP32S3_Registers.UInt32;
      --  Core1 dram0 region1 addr configuration register
      CORE_1_AREA_DRAM0_1_MIN                : aliased ESP32S3_Registers.UInt32;
      --  Core1 dram0 region1 addr configuration register
      CORE_1_AREA_DRAM0_1_MAX                : aliased ESP32S3_Registers.UInt32;
      --  Core1 PIF region0 addr configuration register
      CORE_1_AREA_PIF_0_MIN                  : aliased ESP32S3_Registers.UInt32;
      --  Core1 PIF region0 addr configuration register
      CORE_1_AREA_PIF_0_MAX                  : aliased ESP32S3_Registers.UInt32;
      --  Core1 PIF region1 addr configuration register
      CORE_1_AREA_PIF_1_MIN                  : aliased ESP32S3_Registers.UInt32;
      --  Core1 PIF region1 addr configuration register
      CORE_1_AREA_PIF_1_MAX                  : aliased ESP32S3_Registers.UInt32;
      --  Core1 area sp status register
      CORE_1_AREA_PC                         : aliased ESP32S3_Registers.UInt32;
      --  Core1 area pc status register
      CORE_1_AREA_SP                         : aliased ESP32S3_Registers.UInt32;
      --  Core1 sp unstable configuration register
      CORE_1_SP_UNSTABLE                     : aliased CORE_1_SP_UNSTABLE_Register;
      --  Core1 sp region configuration regsiter
      CORE_1_SP_MIN                          : aliased ESP32S3_Registers.UInt32;
      --  Core1 sp region configuration regsiter
      CORE_1_SP_MAX                          : aliased ESP32S3_Registers.UInt32;
      --  Core1 sp pc status register
      CORE_1_SP_PC                           : aliased ESP32S3_Registers.UInt32;
      --  Core1 pdebug configuration register
      CORE_1_RCD_PDEBUGENABLE                : aliased CORE_1_RCD_PDEBUGENABLE_Register;
      --  Core1 pdebug status register
      CORE_1_RCD_RECORDING                   : aliased CORE_1_RCD_RECORDING_Register;
      --  Core1 pdebug status register
      CORE_1_RCD_PDEBUGINST                  : aliased ESP32S3_Registers.UInt32;
      --  Core1 pdebug status register
      CORE_1_RCD_PDEBUGSTATUS                : aliased CORE_1_RCD_PDEBUGSTATUS_Register;
      --  Core1 pdebug status register
      CORE_1_RCD_PDEBUGDATA                  : aliased ESP32S3_Registers.UInt32;
      --  Core1 pdebug status register
      CORE_1_RCD_PDEBUGPC                    : aliased ESP32S3_Registers.UInt32;
      --  Core1 pdebug status register
      CORE_1_RCD_PDEBUGLS0STAT               : aliased ESP32S3_Registers.UInt32;
      --  Core1 pdebug status register
      CORE_1_RCD_PDEBUGLS0ADDR               : aliased ESP32S3_Registers.UInt32;
      --  Core1 pdebug status register
      CORE_1_RCD_PDEBUGLS0DATA               : aliased ESP32S3_Registers.UInt32;
      --  Core1 pdebug status register
      CORE_1_RCD_SP                          : aliased ESP32S3_Registers.UInt32;
      --  Core1 bus busy status regsiter
      CORE_1_IRAM0_EXCEPTION_MONITOR_0       : aliased CORE_1_IRAM0_EXCEPTION_MONITOR_0_Register;
      --  Core1 bus busy status regsiter
      CORE_1_IRAM0_EXCEPTION_MONITOR_1       : aliased CORE_1_IRAM0_EXCEPTION_MONITOR_1_Register;
      --  Core1 bus busy status regsiter
      CORE_1_DRAM0_EXCEPTION_MONITOR_0       : aliased CORE_1_DRAM0_EXCEPTION_MONITOR_0_Register;
      --  Core1 bus busy status regsiter
      CORE_1_DRAM0_EXCEPTION_MONITOR_1       : aliased CORE_1_DRAM0_EXCEPTION_MONITOR_1_Register;
      --  Core1 bus busy status regsiter
      CORE_1_DRAM0_EXCEPTION_MONITOR_2       : aliased ESP32S3_Registers.UInt32;
      --  Core1 bus busy status regsiter
      CORE_1_DRAM0_EXCEPTION_MONITOR_3       : aliased CORE_1_DRAM0_EXCEPTION_MONITOR_3_Register;
      --  Core1 bus busy status regsiter
      CORE_1_DRAM0_EXCEPTION_MONITOR_4       : aliased CORE_1_DRAM0_EXCEPTION_MONITOR_4_Register;
      --  Core1 bus busy status regsiter
      CORE_1_DRAM0_EXCEPTION_MONITOR_5       : aliased ESP32S3_Registers.UInt32;
      --  bus busy configuration register
      CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_0 : aliased CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_0_Register;
      --  bus busy configuration register
      CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_1 : aliased CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_1_Register;
      --  log set register
      LOG_SETTING                            : aliased LOG_SETTING_Register;
      --  log check data register
      LOG_DATA_0                             : aliased ESP32S3_Registers.UInt32;
      --  log check data register
      LOG_DATA_1                             : aliased ESP32S3_Registers.UInt32;
      --  log check data register
      LOG_DATA_2                             : aliased ESP32S3_Registers.UInt32;
      --  log check data register
      LOG_DATA_3                             : aliased ESP32S3_Registers.UInt32;
      --  log check data mask register
      LOG_DATA_MASK                          : aliased LOG_DATA_MASK_Register;
      --  log check region configuration register
      LOG_MIN                                : aliased ESP32S3_Registers.UInt32;
      --  log check region configuration register
      LOG_MAX                                : aliased ESP32S3_Registers.UInt32;
      --  log mem region configuration register
      LOG_MEM_START                          : aliased ESP32S3_Registers.UInt32;
      --  log mem region configuration register
      LOG_MEM_END                            : aliased ESP32S3_Registers.UInt32;
      --  log mem addr status register
      LOG_MEM_WRITING_ADDR                   : aliased ESP32S3_Registers.UInt32;
      --  log mem status register
      LOG_MEM_FULL_FLAG                      : aliased LOG_MEM_FULL_FLAG_Register;
      --  version register
      DATE                                   : aliased DATE_Register;
   end record
     with Volatile;

   for ASSIST_DEBUG_Peripheral use record
      CORE_0_MONTR_ENA                       at 16#0# range 0 .. 31;
      CORE_0_INTR_RAW                        at 16#4# range 0 .. 31;
      CORE_0_INTR_ENA                        at 16#8# range 0 .. 31;
      CORE_0_INTR_CLR                        at 16#C# range 0 .. 31;
      CORE_0_AREA_DRAM0_0_MIN                at 16#10# range 0 .. 31;
      CORE_0_AREA_DRAM0_0_MAX                at 16#14# range 0 .. 31;
      CORE_0_AREA_DRAM0_1_MIN                at 16#18# range 0 .. 31;
      CORE_0_AREA_DRAM0_1_MAX                at 16#1C# range 0 .. 31;
      CORE_0_AREA_PIF_0_MIN                  at 16#20# range 0 .. 31;
      CORE_0_AREA_PIF_0_MAX                  at 16#24# range 0 .. 31;
      CORE_0_AREA_PIF_1_MIN                  at 16#28# range 0 .. 31;
      CORE_0_AREA_PIF_1_MAX                  at 16#2C# range 0 .. 31;
      CORE_0_AREA_SP                         at 16#30# range 0 .. 31;
      CORE_0_AREA_PC                         at 16#34# range 0 .. 31;
      CORE_0_SP_UNSTABLE                     at 16#38# range 0 .. 31;
      CORE_0_SP_MIN                          at 16#3C# range 0 .. 31;
      CORE_0_SP_MAX                          at 16#40# range 0 .. 31;
      CORE_0_SP_PC                           at 16#44# range 0 .. 31;
      CORE_0_RCD_PDEBUGENABLE                at 16#48# range 0 .. 31;
      CORE_0_RCD_RECORDING                   at 16#4C# range 0 .. 31;
      CORE_0_RCD_PDEBUGINST                  at 16#50# range 0 .. 31;
      CORE_0_RCD_PDEBUGSTATUS                at 16#54# range 0 .. 31;
      CORE_0_RCD_PDEBUGDATA                  at 16#58# range 0 .. 31;
      CORE_0_RCD_PDEBUGPC                    at 16#5C# range 0 .. 31;
      CORE_0_RCD_PDEBUGLS0STAT               at 16#60# range 0 .. 31;
      CORE_0_RCD_PDEBUGLS0ADDR               at 16#64# range 0 .. 31;
      CORE_0_RCD_PDEBUGLS0DATA               at 16#68# range 0 .. 31;
      CORE_0_RCD_SP                          at 16#6C# range 0 .. 31;
      CORE_0_IRAM0_EXCEPTION_MONITOR_0       at 16#70# range 0 .. 31;
      CORE_0_IRAM0_EXCEPTION_MONITOR_1       at 16#74# range 0 .. 31;
      CORE_0_DRAM0_EXCEPTION_MONITOR_0       at 16#78# range 0 .. 31;
      CORE_0_DRAM0_EXCEPTION_MONITOR_1       at 16#7C# range 0 .. 31;
      CORE_0_DRAM0_EXCEPTION_MONITOR_2       at 16#80# range 0 .. 31;
      CORE_0_DRAM0_EXCEPTION_MONITOR_3       at 16#84# range 0 .. 31;
      CORE_0_DRAM0_EXCEPTION_MONITOR_4       at 16#88# range 0 .. 31;
      CORE_0_DRAM0_EXCEPTION_MONITOR_5       at 16#8C# range 0 .. 31;
      CORE_1_MONTR_ENA                       at 16#90# range 0 .. 31;
      CORE_1_INTR_RAW                        at 16#94# range 0 .. 31;
      CORE_1_INTR_ENA                        at 16#98# range 0 .. 31;
      CORE_1_INTR_CLR                        at 16#9C# range 0 .. 31;
      CORE_1_AREA_DRAM0_0_MIN                at 16#A0# range 0 .. 31;
      CORE_1_AREA_DRAM0_0_MAX                at 16#A4# range 0 .. 31;
      CORE_1_AREA_DRAM0_1_MIN                at 16#A8# range 0 .. 31;
      CORE_1_AREA_DRAM0_1_MAX                at 16#AC# range 0 .. 31;
      CORE_1_AREA_PIF_0_MIN                  at 16#B0# range 0 .. 31;
      CORE_1_AREA_PIF_0_MAX                  at 16#B4# range 0 .. 31;
      CORE_1_AREA_PIF_1_MIN                  at 16#B8# range 0 .. 31;
      CORE_1_AREA_PIF_1_MAX                  at 16#BC# range 0 .. 31;
      CORE_1_AREA_PC                         at 16#C0# range 0 .. 31;
      CORE_1_AREA_SP                         at 16#C4# range 0 .. 31;
      CORE_1_SP_UNSTABLE                     at 16#C8# range 0 .. 31;
      CORE_1_SP_MIN                          at 16#CC# range 0 .. 31;
      CORE_1_SP_MAX                          at 16#D0# range 0 .. 31;
      CORE_1_SP_PC                           at 16#D4# range 0 .. 31;
      CORE_1_RCD_PDEBUGENABLE                at 16#D8# range 0 .. 31;
      CORE_1_RCD_RECORDING                   at 16#DC# range 0 .. 31;
      CORE_1_RCD_PDEBUGINST                  at 16#E0# range 0 .. 31;
      CORE_1_RCD_PDEBUGSTATUS                at 16#E4# range 0 .. 31;
      CORE_1_RCD_PDEBUGDATA                  at 16#E8# range 0 .. 31;
      CORE_1_RCD_PDEBUGPC                    at 16#EC# range 0 .. 31;
      CORE_1_RCD_PDEBUGLS0STAT               at 16#F0# range 0 .. 31;
      CORE_1_RCD_PDEBUGLS0ADDR               at 16#F4# range 0 .. 31;
      CORE_1_RCD_PDEBUGLS0DATA               at 16#F8# range 0 .. 31;
      CORE_1_RCD_SP                          at 16#FC# range 0 .. 31;
      CORE_1_IRAM0_EXCEPTION_MONITOR_0       at 16#100# range 0 .. 31;
      CORE_1_IRAM0_EXCEPTION_MONITOR_1       at 16#104# range 0 .. 31;
      CORE_1_DRAM0_EXCEPTION_MONITOR_0       at 16#108# range 0 .. 31;
      CORE_1_DRAM0_EXCEPTION_MONITOR_1       at 16#10C# range 0 .. 31;
      CORE_1_DRAM0_EXCEPTION_MONITOR_2       at 16#110# range 0 .. 31;
      CORE_1_DRAM0_EXCEPTION_MONITOR_3       at 16#114# range 0 .. 31;
      CORE_1_DRAM0_EXCEPTION_MONITOR_4       at 16#118# range 0 .. 31;
      CORE_1_DRAM0_EXCEPTION_MONITOR_5       at 16#11C# range 0 .. 31;
      CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_0 at 16#120# range 0 .. 31;
      CORE_X_IRAM0_DRAM0_EXCEPTION_MONITOR_1 at 16#124# range 0 .. 31;
      LOG_SETTING                            at 16#128# range 0 .. 31;
      LOG_DATA_0                             at 16#12C# range 0 .. 31;
      LOG_DATA_1                             at 16#130# range 0 .. 31;
      LOG_DATA_2                             at 16#134# range 0 .. 31;
      LOG_DATA_3                             at 16#138# range 0 .. 31;
      LOG_DATA_MASK                          at 16#13C# range 0 .. 31;
      LOG_MIN                                at 16#140# range 0 .. 31;
      LOG_MAX                                at 16#144# range 0 .. 31;
      LOG_MEM_START                          at 16#148# range 0 .. 31;
      LOG_MEM_END                            at 16#14C# range 0 .. 31;
      LOG_MEM_WRITING_ADDR                   at 16#150# range 0 .. 31;
      LOG_MEM_FULL_FLAG                      at 16#154# range 0 .. 31;
      DATE                                   at 16#1FC# range 0 .. 31;
   end record;

   --  Debug Assist
   ASSIST_DEBUG_Periph : aliased ASSIST_DEBUG_Peripheral
     with Import, Address => ASSIST_DEBUG_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.DEBUG_ASSIST;
