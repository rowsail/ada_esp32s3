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

package ESP32S3_Registers.SENSITIVE is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  Cache data array configuration register 0.
   type CACHE_DATAARRAY_CONNECT_0_Register is record
      --  Set 1 to lock cache data array registers.
      CACHE_DATAARRAY_CONNECT_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_DATAARRAY_CONNECT_0_Register use record
      CACHE_DATAARRAY_CONNECT_LOCK at 0 range 0 .. 0;
      Reserved_1_31                at 0 range 1 .. 31;
   end record;

   subtype CACHE_DATAARRAY_CONNECT_1_CACHE_DATAARRAY_CONNECT_FLATTEN_Field is
     ESP32S3_Registers.Byte;

   --  Cache data array configuration register 1.
   type CACHE_DATAARRAY_CONNECT_1_Register is record
      --  Cache data array connection configuration.
      CACHE_DATAARRAY_CONNECT_FLATTEN : CACHE_DATAARRAY_CONNECT_1_CACHE_DATAARRAY_CONNECT_FLATTEN_Field :=
                                         16#FF#;
      --  unspecified
      Reserved_8_31                   : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_DATAARRAY_CONNECT_1_Register use record
      CACHE_DATAARRAY_CONNECT_FLATTEN at 0 range 0 .. 7;
      Reserved_8_31                   at 0 range 8 .. 31;
   end record;

   --  APB peripheral configuration register 0.
   type APB_PERIPHERAL_ACCESS_0_Register is record
      --  Set 1 to lock APB peripheral Configuration Register.
      APB_PERIPHERAL_ACCESS_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31              : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for APB_PERIPHERAL_ACCESS_0_Register use record
      APB_PERIPHERAL_ACCESS_LOCK at 0 range 0 .. 0;
      Reserved_1_31              at 0 range 1 .. 31;
   end record;

   --  APB peripheral configuration register 1.
   type APB_PERIPHERAL_ACCESS_1_Register is record
      --  Set 1 to support split function for AHB access to APB peripherals.
      APB_PERIPHERAL_ACCESS_SPLIT_BURST : Boolean := True;
      --  unspecified
      Reserved_1_31                     : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for APB_PERIPHERAL_ACCESS_1_Register use record
      APB_PERIPHERAL_ACCESS_SPLIT_BURST at 0 range 0 .. 0;
      Reserved_1_31                     at 0 range 1 .. 31;
   end record;

   --  Internal SRAM configuration register 0.
   type INTERNAL_SRAM_USAGE_0_Register is record
      --  Set 1 to lock internal SRAM Configuration Register.
      INTERNAL_SRAM_USAGE_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31            : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INTERNAL_SRAM_USAGE_0_Register use record
      INTERNAL_SRAM_USAGE_LOCK at 0 range 0 .. 0;
      Reserved_1_31            at 0 range 1 .. 31;
   end record;

   subtype INTERNAL_SRAM_USAGE_1_INTERNAL_SRAM_ICACHE_USAGE_Field is
     ESP32S3_Registers.UInt2;
   subtype INTERNAL_SRAM_USAGE_1_INTERNAL_SRAM_DCACHE_USAGE_Field is
     ESP32S3_Registers.UInt2;
   subtype INTERNAL_SRAM_USAGE_1_INTERNAL_SRAM_CPU_USAGE_Field is
     ESP32S3_Registers.UInt7;

   --  Internal SRAM configuration register 1.
   type INTERNAL_SRAM_USAGE_1_Register is record
      --  Set 1 to someone bit means corresponding internal SRAM level can be
      --  accessed by icache.
      INTERNAL_SRAM_ICACHE_USAGE : INTERNAL_SRAM_USAGE_1_INTERNAL_SRAM_ICACHE_USAGE_Field :=
                                    16#3#;
      --  Set 1 to someone bit means corresponding internal SRAM level can be
      --  accessed by dcache.
      INTERNAL_SRAM_DCACHE_USAGE : INTERNAL_SRAM_USAGE_1_INTERNAL_SRAM_DCACHE_USAGE_Field :=
                                    16#3#;
      --  Set 1 to someone bit means corresponding internal SRAM level can be
      --  accessed by cpu.
      INTERNAL_SRAM_CPU_USAGE    : INTERNAL_SRAM_USAGE_1_INTERNAL_SRAM_CPU_USAGE_Field :=
                                    16#7F#;
      --  unspecified
      Reserved_11_31             : ESP32S3_Registers.UInt21 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INTERNAL_SRAM_USAGE_1_Register use record
      INTERNAL_SRAM_ICACHE_USAGE at 0 range 0 .. 1;
      INTERNAL_SRAM_DCACHE_USAGE at 0 range 2 .. 3;
      INTERNAL_SRAM_CPU_USAGE    at 0 range 4 .. 10;
      Reserved_11_31             at 0 range 11 .. 31;
   end record;

   subtype INTERNAL_SRAM_USAGE_2_INTERNAL_SRAM_CORE0_TRACE_USAGE_Field is
     ESP32S3_Registers.UInt7;
   subtype INTERNAL_SRAM_USAGE_2_INTERNAL_SRAM_CORE1_TRACE_USAGE_Field is
     ESP32S3_Registers.UInt7;
   subtype INTERNAL_SRAM_USAGE_2_INTERNAL_SRAM_CORE0_TRACE_ALLOC_Field is
     ESP32S3_Registers.UInt2;
   subtype INTERNAL_SRAM_USAGE_2_INTERNAL_SRAM_CORE1_TRACE_ALLOC_Field is
     ESP32S3_Registers.UInt2;

   --  Internal SRAM configuration register 2.
   type INTERNAL_SRAM_USAGE_2_Register is record
      --  Set 1 to someone bit means corresponding internal SRAM level can be
      --  accessed by core0 trace bus.
      INTERNAL_SRAM_CORE0_TRACE_USAGE : INTERNAL_SRAM_USAGE_2_INTERNAL_SRAM_CORE0_TRACE_USAGE_Field :=
                                         16#0#;
      --  Set 1 to someone bit means corresponding internal SRAM level can be
      --  accessed by core1 trace bus.
      INTERNAL_SRAM_CORE1_TRACE_USAGE : INTERNAL_SRAM_USAGE_2_INTERNAL_SRAM_CORE1_TRACE_USAGE_Field :=
                                         16#0#;
      --  Which internal SRAM bank (16KB) of 64KB can be accessed by core0
      --  trace bus.
      INTERNAL_SRAM_CORE0_TRACE_ALLOC : INTERNAL_SRAM_USAGE_2_INTERNAL_SRAM_CORE0_TRACE_ALLOC_Field :=
                                         16#0#;
      --  Which internal SRAM bank (16KB) of 64KB can be accessed by core1
      --  trace bus.
      INTERNAL_SRAM_CORE1_TRACE_ALLOC : INTERNAL_SRAM_USAGE_2_INTERNAL_SRAM_CORE1_TRACE_ALLOC_Field :=
                                         16#0#;
      --  unspecified
      Reserved_18_31                  : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INTERNAL_SRAM_USAGE_2_Register use record
      INTERNAL_SRAM_CORE0_TRACE_USAGE at 0 range 0 .. 6;
      INTERNAL_SRAM_CORE1_TRACE_USAGE at 0 range 7 .. 13;
      INTERNAL_SRAM_CORE0_TRACE_ALLOC at 0 range 14 .. 15;
      INTERNAL_SRAM_CORE1_TRACE_ALLOC at 0 range 16 .. 17;
      Reserved_18_31                  at 0 range 18 .. 31;
   end record;

   subtype INTERNAL_SRAM_USAGE_3_INTERNAL_SRAM_MAC_DUMP_USAGE_Field is
     ESP32S3_Registers.UInt4;

   --  Internal SRAM configuration register 3.
   type INTERNAL_SRAM_USAGE_3_Register is record
      --  Set 1 to someone bit means corresponding internal SRAM level can be
      --  accessed by mac dump.
      INTERNAL_SRAM_MAC_DUMP_USAGE : INTERNAL_SRAM_USAGE_3_INTERNAL_SRAM_MAC_DUMP_USAGE_Field :=
                                      16#0#;
      --  unspecified
      Reserved_4_31                : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INTERNAL_SRAM_USAGE_3_Register use record
      INTERNAL_SRAM_MAC_DUMP_USAGE at 0 range 0 .. 3;
      Reserved_4_31                at 0 range 4 .. 31;
   end record;

   subtype INTERNAL_SRAM_USAGE_4_INTERNAL_SRAM_LOG_USAGE_Field is
     ESP32S3_Registers.UInt7;

   --  Internal SRAM configuration register 4.
   type INTERNAL_SRAM_USAGE_4_Register is record
      --  Set 1 to someone bit means corresponding internal SRAM level can be
      --  accessed by log bus.
      INTERNAL_SRAM_LOG_USAGE : INTERNAL_SRAM_USAGE_4_INTERNAL_SRAM_LOG_USAGE_Field :=
                                 16#0#;
      --  unspecified
      Reserved_7_31           : ESP32S3_Registers.UInt25 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INTERNAL_SRAM_USAGE_4_Register use record
      INTERNAL_SRAM_LOG_USAGE at 0 range 0 .. 6;
      Reserved_7_31           at 0 range 7 .. 31;
   end record;

   --  Retention configuration register.
   type RETENTION_DISABLE_Register is record
      --  Set 1 to disable retention function and lock disable state.
      RETENTION_DISABLE : Boolean := False;
      --  unspecified
      Reserved_1_31     : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RETENTION_DISABLE_Register use record
      RETENTION_DISABLE at 0 range 0 .. 0;
      Reserved_1_31     at 0 range 1 .. 31;
   end record;

   --  Cache tag configuration register 0.
   type CACHE_TAG_ACCESS_0_Register is record
      --  Set 1 to lock cache tag Configuration Register.
      CACHE_TAG_ACCESS_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31         : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_TAG_ACCESS_0_Register use record
      CACHE_TAG_ACCESS_LOCK at 0 range 0 .. 0;
      Reserved_1_31         at 0 range 1 .. 31;
   end record;

   --  Cache tag configuration register 1.
   type CACHE_TAG_ACCESS_1_Register is record
      --  Set 1 to enable Icache read access tag memory.
      PRO_I_TAG_RD_ACS : Boolean := True;
      --  Set 1 to enable Icache wrtie access tag memory.
      PRO_I_TAG_WR_ACS : Boolean := True;
      --  Set 1 to enable Dcache read access tag memory.
      PRO_D_TAG_RD_ACS : Boolean := True;
      --  Set 1 to enable Dcache wrtie access tag memory.
      PRO_D_TAG_WR_ACS : Boolean := True;
      --  unspecified
      Reserved_4_31    : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_TAG_ACCESS_1_Register use record
      PRO_I_TAG_RD_ACS at 0 range 0 .. 0;
      PRO_I_TAG_WR_ACS at 0 range 1 .. 1;
      PRO_D_TAG_RD_ACS at 0 range 2 .. 2;
      PRO_D_TAG_WR_ACS at 0 range 3 .. 3;
      Reserved_4_31    at 0 range 4 .. 31;
   end record;

   --  Cache MMU configuration register 0.
   type CACHE_MMU_ACCESS_0_Register is record
      --  Set 1 to lock cache MMU registers.
      CACHE_MMU_ACCESS_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31         : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_MMU_ACCESS_0_Register use record
      CACHE_MMU_ACCESS_LOCK at 0 range 0 .. 0;
      Reserved_1_31         at 0 range 1 .. 31;
   end record;

   --  Cache MMU configuration register 1.
   type CACHE_MMU_ACCESS_1_Register is record
      --  Set 1 to enable read access MMU memory.
      PRO_MMU_RD_ACS : Boolean := True;
      --  Set 1 to enable write access MMU memory.
      PRO_MMU_WR_ACS : Boolean := True;
      --  unspecified
      Reserved_2_31  : ESP32S3_Registers.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_MMU_ACCESS_1_Register use record
      PRO_MMU_RD_ACS at 0 range 0 .. 0;
      PRO_MMU_WR_ACS at 0 range 1 .. 1;
      Reserved_2_31  at 0 range 2 .. 31;
   end record;

   --  spi2 dma permission configuration register 0.
   type DMA_APBPERI_SPI2_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock spi2 dma permission Configuration Register.
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_SPI2_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                       at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  spi2 dma permission configuration register 1.
   type DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_Register is record
      --  spi2's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                  16#3#;
      --  spi2's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                  16#3#;
      --  spi2's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                  16#3#;
      --  spi2's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                  16#3#;
      --  spi2's permission(store,load) in dcache data sram block0
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                  16#3#;
      --  spi2's permission(store,load) in dcache data sram block1
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                  16#3#;
      --  unspecified
      Reserved_12_31                                           : ESP32S3_Registers.UInt20 :=
                                                                  16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                           at 0 range 12 .. 31;
   end record;

   --  spi3 dma permission configuration register 0.
   type DMA_APBPERI_SPI3_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock spi3 dma permission Configuration Register.
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_SPI3_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                       at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  spi3 dma permission configuration register 1.
   type DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_Register is record
      --  spi3's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                  16#3#;
      --  spi3's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                  16#3#;
      --  spi3's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                  16#3#;
      --  spi3's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                  16#3#;
      --  spi3's permission(store,load) in dcache data sram block0
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                  16#3#;
      --  spi3's permission(store,load) in dcache data sram block1
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                  16#3#;
      --  unspecified
      Reserved_12_31                                           : ESP32S3_Registers.UInt20 :=
                                                                  16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                           at 0 range 12 .. 31;
   end record;

   --  uhci0 dma permission configuration register 0.
   type DMA_APBPERI_UHCI0_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock uhci0 dma permission Configuration Register.
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                        : ESP32S3_Registers.UInt31 :=
                                              16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_UHCI0_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                        at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  uhci0 dma permission configuration register 1.
   type DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_Register is record
      --  uhci0's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                   16#3#;
      --  uhci0's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                   16#3#;
      --  uhci0's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                   16#3#;
      --  uhci0's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                   16#3#;
      --  uhci0's permission(store,load) in dcache data sram block0
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                   16#3#;
      --  uhci0's permission(store,load) in dcache data sram block1
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                   16#3#;
      --  unspecified
      Reserved_12_31                                            : ESP32S3_Registers.UInt20 :=
                                                                   16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                            at 0 range 12 .. 31;
   end record;

   --  i2s0 dma permission configuration register 0.
   type DMA_APBPERI_I2S0_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock i2s0 dma permission Configuration Register.
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_I2S0_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                       at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  i2s0 dma permission configuration register 1.
   type DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_Register is record
      --  i2s0's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                  16#3#;
      --  i2s0's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                  16#3#;
      --  i2s0's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                  16#3#;
      --  i2s0's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                  16#3#;
      --  i2s0's permission(store,load) in dcache data sram block0
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                  16#3#;
      --  i2s0's permission(store,load) in dcache data sram block1
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                  16#3#;
      --  unspecified
      Reserved_12_31                                           : ESP32S3_Registers.UInt20 :=
                                                                  16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                           at 0 range 12 .. 31;
   end record;

   --  i2s1 dma permission configuration register 0.
   type DMA_APBPERI_I2S1_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock i2s1 dma permission Configuration Register.
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_I2S1_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                       at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  i2s1 dma permission configuration register 1.
   type DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_Register is record
      --  i2s1's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                  16#3#;
      --  i2s1's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                  16#3#;
      --  i2s1's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                  16#3#;
      --  i2s1's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                  16#3#;
      --  i2s1's permission(store,load) in dcache data sram block0
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                  16#3#;
      --  i2s1's permission(store,load) in dcache data sram block1
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                  16#3#;
      --  unspecified
      Reserved_12_31                                           : ESP32S3_Registers.UInt20 :=
                                                                  16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                           at 0 range 12 .. 31;
   end record;

   --  mac dma permission configuration register 0.
   type DMA_APBPERI_MAC_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock mac dma permission Configuration Register.
      DMA_APBPERI_MAC_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_MAC_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_MAC_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                      at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  mac dma permission configuration register 1.
   type DMA_APBPERI_MAC_PMS_CONSTRAIN_1_Register is record
      --  mac's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                 16#3#;
      --  mac's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                 16#3#;
      --  mac's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                 16#3#;
      --  mac's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                 16#3#;
      --  mac's permission(store,load) in dcache data sram block0
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                 16#3#;
      --  mac's permission(store,load) in dcache data sram block1
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_MAC_PMS_CONSTRAIN_1_DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                 16#3#;
      --  unspecified
      Reserved_12_31                                          : ESP32S3_Registers.UInt20 :=
                                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_MAC_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_MAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                          at 0 range 12 .. 31;
   end record;

   --  backup dma permission configuration register 0.
   type DMA_APBPERI_BACKUP_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock backup dma permission Configuration Register.
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                         : ESP32S3_Registers.UInt31 :=
                                               16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_BACKUP_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                         at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  backup dma permission configuration register 1.
   type DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_Register is record
      --  backup's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                    16#3#;
      --  backup's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                    16#3#;
      --  backup's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                    16#3#;
      --  backup's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                    16#3#;
      --  backup's permission(store,load) in dcache data sram block0
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                    16#3#;
      --  backup's permission(store,load) in dcache data sram block1
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                    16#3#;
      --  unspecified
      Reserved_12_31                                             : ESP32S3_Registers.UInt20 :=
                                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                             at 0 range 12 .. 31;
   end record;

   --  aes dma permission configuration register 0.
   type DMA_APBPERI_AES_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock aes dma permission Configuration Register.
      DMA_APBPERI_AES_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_AES_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_AES_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                      at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  aes dma permission configuration register 1.
   type DMA_APBPERI_AES_PMS_CONSTRAIN_1_Register is record
      --  aes's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                 16#3#;
      --  aes's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                 16#3#;
      --  aes's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                 16#3#;
      --  aes's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                 16#3#;
      --  aes's permission(store,load) in dcache data sram block0
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                 16#3#;
      --  aes's permission(store,load) in dcache data sram block1
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_AES_PMS_CONSTRAIN_1_DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                 16#3#;
      --  unspecified
      Reserved_12_31                                          : ESP32S3_Registers.UInt20 :=
                                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_AES_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_AES_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                          at 0 range 12 .. 31;
   end record;

   --  sha dma permission configuration register 0.
   type DMA_APBPERI_SHA_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock sha dma permission Configuration Register.
      DMA_APBPERI_SHA_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_SHA_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_SHA_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                      at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  sha dma permission configuration register 1.
   type DMA_APBPERI_SHA_PMS_CONSTRAIN_1_Register is record
      --  sha's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                 16#3#;
      --  sha's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                 16#3#;
      --  sha's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                 16#3#;
      --  sha's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                 16#3#;
      --  sha's permission(store,load) in dcache data sram block0
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                 16#3#;
      --  sha's permission(store,load) in dcache data sram block1
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_SHA_PMS_CONSTRAIN_1_DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                 16#3#;
      --  unspecified
      Reserved_12_31                                          : ESP32S3_Registers.UInt20 :=
                                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_SHA_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_SHA_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                          at 0 range 12 .. 31;
   end record;

   --  adc_dac dma permission configuration register 0.
   type DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock adc_dac dma permission Configuration Register.
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                          : ESP32S3_Registers.UInt31 :=
                                                16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                          at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  adc_dac dma permission configuration register 1.
   type DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_Register is record
      --  adc_dac's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                     16#3#;
      --  adc_dac's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                     16#3#;
      --  adc_dac's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                     16#3#;
      --  adc_dac's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                     16#3#;
      --  adc_dac's permission(store,load) in dcache data sram block0
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                     16#3#;
      --  adc_dac's permission(store,load) in dcache data sram block1
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                     16#3#;
      --  unspecified
      Reserved_12_31                                              : ESP32S3_Registers.UInt20 :=
                                                                     16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                              at 0 range 12 .. 31;
   end record;

   --  rmt dma permission configuration register 0.
   type DMA_APBPERI_RMT_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock rmt dma permission Configuration Register.
      DMA_APBPERI_RMT_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_RMT_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_RMT_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                      at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  rmt dma permission configuration register 1.
   type DMA_APBPERI_RMT_PMS_CONSTRAIN_1_Register is record
      --  rmt's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                 16#3#;
      --  rmt's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                 16#3#;
      --  rmt's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                 16#3#;
      --  rmt's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                 16#3#;
      --  rmt's permission(store,load) in dcache data sram block0
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                 16#3#;
      --  rmt's permission(store,load) in dcache data sram block1
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_RMT_PMS_CONSTRAIN_1_DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                 16#3#;
      --  unspecified
      Reserved_12_31                                          : ESP32S3_Registers.UInt20 :=
                                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_RMT_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_RMT_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                          at 0 range 12 .. 31;
   end record;

   --  lcd_cam dma permission configuration register 0.
   type DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock lcd_cam dma permission Configuration Register.
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                          : ESP32S3_Registers.UInt31 :=
                                                16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                          at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  lcd_cam dma permission configuration register 1.
   type DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_Register is record
      --  lcd_cam's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                     16#3#;
      --  lcd_cam's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                     16#3#;
      --  lcd_cam's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                     16#3#;
      --  lcd_cam's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                     16#3#;
      --  lcd_cam's permission(store,load) in dcache data sram block0
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                     16#3#;
      --  lcd_cam's permission(store,load) in dcache data sram block1
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                     16#3#;
      --  unspecified
      Reserved_12_31                                              : ESP32S3_Registers.UInt20 :=
                                                                     16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                              at 0 range 12 .. 31;
   end record;

   --  usb dma permission configuration register 0.
   type DMA_APBPERI_USB_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock usb dma permission Configuration Register.
      DMA_APBPERI_USB_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_USB_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_USB_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                      at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  usb dma permission configuration register 1.
   type DMA_APBPERI_USB_PMS_CONSTRAIN_1_Register is record
      --  usb's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                 16#3#;
      --  usb's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                 16#3#;
      --  usb's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                 16#3#;
      --  usb's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                 16#3#;
      --  usb's permission(store,load) in dcache data sram block0
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                 16#3#;
      --  usb's permission(store,load) in dcache data sram block1
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_USB_PMS_CONSTRAIN_1_DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                 16#3#;
      --  unspecified
      Reserved_12_31                                          : ESP32S3_Registers.UInt20 :=
                                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_USB_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_USB_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                          at 0 range 12 .. 31;
   end record;

   --  lc dma permission configuration register 0.
   type DMA_APBPERI_LC_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock lc dma permission Configuration Register.
      DMA_APBPERI_LC_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                     : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_LC_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_LC_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                     at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  lc dma permission configuration register 1.
   type DMA_APBPERI_LC_PMS_CONSTRAIN_1_Register is record
      --  lc's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                16#3#;
      --  lc's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                16#3#;
      --  lc's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                16#3#;
      --  lc's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                16#3#;
      --  lc's permission(store,load) in dcache data sram block0
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                16#3#;
      --  lc's permission(store,load) in dcache data sram block1
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_LC_PMS_CONSTRAIN_1_DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                16#3#;
      --  unspecified
      Reserved_12_31                                         : ESP32S3_Registers.UInt20 :=
                                                                16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_LC_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_LC_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                         at 0 range 12 .. 31;
   end record;

   --  sdio dma permission configuration register 0.
   type DMA_APBPERI_SDIO_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock sdio dma permission Configuration Register.
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_SDIO_PMS_CONSTRAIN_0_Register use record
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                       at 0 range 1 .. 31;
   end record;

   subtype DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;

   --  sdio dma permission configuration register 1.
   type DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_Register is record
      --  sdio's permission(store,load) in data region0 of SRAM
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_0                : DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_0_Field :=
                                                                  16#3#;
      --  sdio's permission(store,load) in data region1 of SRAM
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_1                : DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_1_Field :=
                                                                  16#3#;
      --  sdio's permission(store,load) in data region2 of SRAM
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_2                : DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_2_Field :=
                                                                  16#3#;
      --  sdio's permission(store,load) in data region3 of SRAM
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_3                : DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_3_Field :=
                                                                  16#3#;
      --  sdio's permission(store,load) in dcache data sram block0
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 : DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0_Field :=
                                                                  16#3#;
      --  sdio's permission(store,load) in dcache data sram block1
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 : DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1_Field :=
                                                                  16#3#;
      --  unspecified
      Reserved_12_31                                           : ESP32S3_Registers.UInt20 :=
                                                                  16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_Register use record
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_0                at 0 range 0 .. 1;
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_1                at 0 range 2 .. 3;
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_2                at 0 range 4 .. 5;
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_PMS_3                at 0 range 6 .. 7;
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_SRAM_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      Reserved_12_31                                           at 0 range 12 .. 31;
   end record;

   --  dma permission monitor configuration register 0.
   type DMA_APBPERI_PMS_MONITOR_0_Register is record
      --  Set 1 to lock dma permission monitor Configuration Register.
      DMA_APBPERI_PMS_MONITOR_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_PMS_MONITOR_0_Register use record
      DMA_APBPERI_PMS_MONITOR_LOCK at 0 range 0 .. 0;
      Reserved_1_31                at 0 range 1 .. 31;
   end record;

   --  dma permission monitor configuration register 1.
   type DMA_APBPERI_PMS_MONITOR_1_Register is record
      --  Set 1 to clear dma_pms_monitor_violate interrupt
      DMA_APBPERI_PMS_MONITOR_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable dma pms monitor, if dma access violated permission,
      --  will trigger interrupt.
      DMA_APBPERI_PMS_MONITOR_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                       : ESP32S3_Registers.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_PMS_MONITOR_1_Register use record
      DMA_APBPERI_PMS_MONITOR_VIOLATE_CLR at 0 range 0 .. 0;
      DMA_APBPERI_PMS_MONITOR_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                       at 0 range 2 .. 31;
   end record;

   subtype DMA_APBPERI_PMS_MONITOR_2_DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field is
     ESP32S3_Registers.UInt2;
   subtype DMA_APBPERI_PMS_MONITOR_2_DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field is
     ESP32S3_Registers.UInt22;

   --  dma permission monitor configuration register 2.
   type DMA_APBPERI_PMS_MONITOR_2_Register is record
      --  Read-only. recorded dma's interrupt status when dma access violated
      --  permission
      DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR         : Boolean;
      --  Read-only. recorded dma's world status when dma access violated
      --  permission
      DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_WORLD : DMA_APBPERI_PMS_MONITOR_2_DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field;
      --  Read-only. recorded dma's address bit[25:4] status when dma access
      --  violated permission, real address is 0x3c00_0000+addr*16
      DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_ADDR  : DMA_APBPERI_PMS_MONITOR_2_DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field;
      --  unspecified
      Reserved_25_31                               : ESP32S3_Registers.UInt7;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_PMS_MONITOR_2_Register use record
      DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR         at 0 range 0 .. 0;
      DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_WORLD at 0 range 1 .. 2;
      DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_ADDR  at 0 range 3 .. 24;
      Reserved_25_31                               at 0 range 25 .. 31;
   end record;

   subtype DMA_APBPERI_PMS_MONITOR_3_DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_BYTEEN_Field is
     ESP32S3_Registers.UInt16;

   --  dma permission monitor configuration register 3.
   type DMA_APBPERI_PMS_MONITOR_3_Register is record
      --  Read-only. recorded dma's write status when dma access violated
      --  permission, 1(write), 0(read)
      DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_WR     : Boolean;
      --  Read-only. recorded dma's byte enable status when dma access violated
      --  permission
      DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_BYTEEN : DMA_APBPERI_PMS_MONITOR_3_DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_BYTEEN_Field;
      --  unspecified
      Reserved_17_31                                : ESP32S3_Registers.UInt15;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_APBPERI_PMS_MONITOR_3_Register use record
      DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_WR     at 0 range 0 .. 0;
      DMA_APBPERI_PMS_MONITOR_VIOLATE_STATUS_BYTEEN at 0 range 1 .. 16;
      Reserved_17_31                                at 0 range 17 .. 31;
   end record;

   --  sram split line configuration register 0
   type CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_0_Register is record
      --  Set 1 to lock sram split configuration register
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                                    : ESP32S3_Registers.UInt31 :=
                                                          16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_0_Register use record
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                                    at 0 range 1 .. 31;
   end record;

   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_SPLITADDR_Field is
     ESP32S3_Registers.Byte;

   --  sram split line configuration register 1
   type CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_Register is record
      --  category0 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block0 of SRAM, configured as 0x10, else if the splitaddress below
      --  block0 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block0 of SRAM, configured as 0x00
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_0 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_0_Field :=
                                                16#0#;
      --  category1 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block1 of SRAM, configured as 0x10, else if the splitaddress below
      --  block1 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block1 of SRAM, configured as 0x00
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_1 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_1_Field :=
                                                16#0#;
      --  category2 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block2 of SRAM, configured as 0x10, else if the splitaddress below
      --  block2 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block2 of SRAM, configured as 0x00
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_2 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_2_Field :=
                                                16#0#;
      --  category3 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block3 of SRAM, configured as 0x10, else if the splitaddress below
      --  block3 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block3 of SRAM, configured as 0x00
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_3 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_3_Field :=
                                                16#0#;
      --  category4 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block4 of SRAM, configured as 0x10, else if the splitaddress below
      --  block4 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block4 of SRAM, configured as 0x00
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_4 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_4_Field :=
                                                16#0#;
      --  category5 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block5 of SRAM, configured as 0x10, else if the splitaddress below
      --  block5 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block5 of SRAM, configured as 0x00
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_5 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_5_Field :=
                                                16#0#;
      --  category6 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block6 of SRAM, configured as 0x10, else if the splitaddress below
      --  block6 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block6 of SRAM, configured as 0x00
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_6 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_6_Field :=
                                                16#0#;
      --  splitaddr of core_x_iram0_dram_dma_line, configured as [15:8]bit of
      --  actual address
      CORE_X_IRAM0_DRAM0_DMA_SRAM_SPLITADDR  : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_CORE_X_IRAM0_DRAM0_DMA_SRAM_SPLITADDR_Field :=
                                                16#0#;
      --  unspecified
      Reserved_22_31                         : ESP32S3_Registers.UInt10 :=
                                                16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_Register use record
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_0 at 0 range 0 .. 1;
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_1 at 0 range 2 .. 3;
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_2 at 0 range 4 .. 5;
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_3 at 0 range 6 .. 7;
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_4 at 0 range 8 .. 9;
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_5 at 0 range 10 .. 11;
      CORE_X_IRAM0_DRAM0_DMA_SRAM_CATEGORY_6 at 0 range 12 .. 13;
      CORE_X_IRAM0_DRAM0_DMA_SRAM_SPLITADDR  at 0 range 14 .. 21;
      Reserved_22_31                         at 0 range 22 .. 31;
   end record;

   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_SPLITADDR_Field is
     ESP32S3_Registers.Byte;

   --  sram split line configuration register 1
   type CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_Register is record
      --  category0 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block0 of SRAM, configured as 0x10, else if the splitaddress below
      --  block0 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block0 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_0 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_0_Field :=
                                             16#0#;
      --  category1 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block1 of SRAM, configured as 0x10, else if the splitaddress below
      --  block1 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block1 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_1 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_1_Field :=
                                             16#0#;
      --  category2 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block2 of SRAM, configured as 0x10, else if the splitaddress below
      --  block2 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block2 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_2 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_2_Field :=
                                             16#0#;
      --  category3 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block3 of SRAM, configured as 0x10, else if the splitaddress below
      --  block3 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block3 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_3 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_3_Field :=
                                             16#0#;
      --  category4 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block4 of SRAM, configured as 0x10, else if the splitaddress below
      --  block4 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block4 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_4 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_4_Field :=
                                             16#0#;
      --  category5 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block5 of SRAM, configured as 0x10, else if the splitaddress below
      --  block5 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block5 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_5 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_5_Field :=
                                             16#0#;
      --  category6 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block6 of SRAM, configured as 0x10, else if the splitaddress below
      --  block6 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block6 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_6 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_6_Field :=
                                             16#0#;
      --  splitaddr of core_x_iram0_dram_dma_line, configured as [15:8]bit of
      --  actual address
      CORE_X_IRAM0_SRAM_LINE_0_SPLITADDR  : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_CORE_X_IRAM0_SRAM_LINE_0_SPLITADDR_Field :=
                                             16#0#;
      --  unspecified
      Reserved_22_31                      : ESP32S3_Registers.UInt10 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_Register use record
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_0 at 0 range 0 .. 1;
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_1 at 0 range 2 .. 3;
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_2 at 0 range 4 .. 5;
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_3 at 0 range 6 .. 7;
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_4 at 0 range 8 .. 9;
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_5 at 0 range 10 .. 11;
      CORE_X_IRAM0_SRAM_LINE_0_CATEGORY_6 at 0 range 12 .. 13;
      CORE_X_IRAM0_SRAM_LINE_0_SPLITADDR  at 0 range 14 .. 21;
      Reserved_22_31                      at 0 range 22 .. 31;
   end record;

   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_SPLITADDR_Field is
     ESP32S3_Registers.Byte;

   --  sram split line configuration register 1
   type CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_Register is record
      --  category0 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block0 of SRAM, configured as 0x10, else if the splitaddress below
      --  block0 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block0 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_0 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_0_Field :=
                                             16#0#;
      --  category1 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block1 of SRAM, configured as 0x10, else if the splitaddress below
      --  block1 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block1 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_1 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_1_Field :=
                                             16#0#;
      --  category2 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block2 of SRAM, configured as 0x10, else if the splitaddress below
      --  block2 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block2 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_2 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_2_Field :=
                                             16#0#;
      --  category3 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block3 of SRAM, configured as 0x10, else if the splitaddress below
      --  block3 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block3 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_3 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_3_Field :=
                                             16#0#;
      --  category4 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block4 of SRAM, configured as 0x10, else if the splitaddress below
      --  block4 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block4 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_4 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_4_Field :=
                                             16#0#;
      --  category5 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block5 of SRAM, configured as 0x10, else if the splitaddress below
      --  block5 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block5 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_5 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_5_Field :=
                                             16#0#;
      --  category6 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block6 of SRAM, configured as 0x10, else if the splitaddress below
      --  block6 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block6 of SRAM, configured as 0x00
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_6 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_6_Field :=
                                             16#0#;
      --  splitaddr of core_x_iram0_dram_dma_line, configured as [15:8]bit of
      --  actual address
      CORE_X_IRAM0_SRAM_LINE_1_SPLITADDR  : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_CORE_X_IRAM0_SRAM_LINE_1_SPLITADDR_Field :=
                                             16#0#;
      --  unspecified
      Reserved_22_31                      : ESP32S3_Registers.UInt10 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_Register use record
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_0 at 0 range 0 .. 1;
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_1 at 0 range 2 .. 3;
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_2 at 0 range 4 .. 5;
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_3 at 0 range 6 .. 7;
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_4 at 0 range 8 .. 9;
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_5 at 0 range 10 .. 11;
      CORE_X_IRAM0_SRAM_LINE_1_CATEGORY_6 at 0 range 12 .. 13;
      CORE_X_IRAM0_SRAM_LINE_1_SPLITADDR  at 0 range 14 .. 21;
      Reserved_22_31                      at 0 range 22 .. 31;
   end record;

   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_SPLITADDR_Field is
     ESP32S3_Registers.Byte;

   --  sram split line configuration register 1
   type CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_Register is record
      --  category0 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block0 of SRAM, configured as 0x10, else if the splitaddress below
      --  block0 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block0 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_0 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_0_Field :=
                                                 16#0#;
      --  category1 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block1 of SRAM, configured as 0x10, else if the splitaddress below
      --  block1 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block1 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_1 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_1_Field :=
                                                 16#0#;
      --  category2 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block2 of SRAM, configured as 0x10, else if the splitaddress below
      --  block2 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block2 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_2 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_2_Field :=
                                                 16#0#;
      --  category3 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block3 of SRAM, configured as 0x10, else if the splitaddress below
      --  block3 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block3 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_3 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_3_Field :=
                                                 16#0#;
      --  category4 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block4 of SRAM, configured as 0x10, else if the splitaddress below
      --  block4 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block4 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_4 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_4_Field :=
                                                 16#0#;
      --  category5 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block5 of SRAM, configured as 0x10, else if the splitaddress below
      --  block5 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block5 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_5 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_5_Field :=
                                                 16#0#;
      --  category6 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block6 of SRAM, configured as 0x10, else if the splitaddress below
      --  block6 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block6 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_6 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_6_Field :=
                                                 16#0#;
      --  splitaddr of core_x_iram0_dram_dma_line, configured as [15:8]bit of
      --  actual address
      CORE_X_DRAM0_DMA_SRAM_LINE_0_SPLITADDR  : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_CORE_X_DRAM0_DMA_SRAM_LINE_0_SPLITADDR_Field :=
                                                 16#0#;
      --  unspecified
      Reserved_22_31                          : ESP32S3_Registers.UInt10 :=
                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_Register use record
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_0 at 0 range 0 .. 1;
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_1 at 0 range 2 .. 3;
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_2 at 0 range 4 .. 5;
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_3 at 0 range 6 .. 7;
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_4 at 0 range 8 .. 9;
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_5 at 0 range 10 .. 11;
      CORE_X_DRAM0_DMA_SRAM_LINE_0_CATEGORY_6 at 0 range 12 .. 13;
      CORE_X_DRAM0_DMA_SRAM_LINE_0_SPLITADDR  at 0 range 14 .. 21;
      Reserved_22_31                          at 0 range 22 .. 31;
   end record;

   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_SPLITADDR_Field is
     ESP32S3_Registers.Byte;

   --  sram split line configuration register 1
   type CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_Register is record
      --  category0 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block0 of SRAM, configured as 0x10, else if the splitaddress below
      --  block0 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block0 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_0 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_0_Field :=
                                                 16#0#;
      --  category1 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block1 of SRAM, configured as 0x10, else if the splitaddress below
      --  block1 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block1 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_1 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_1_Field :=
                                                 16#0#;
      --  category2 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block2 of SRAM, configured as 0x10, else if the splitaddress below
      --  block2 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block2 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_2 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_2_Field :=
                                                 16#0#;
      --  category3 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block3 of SRAM, configured as 0x10, else if the splitaddress below
      --  block3 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block3 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_3 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_3_Field :=
                                                 16#0#;
      --  category4 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block4 of SRAM, configured as 0x10, else if the splitaddress below
      --  block4 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block4 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_4 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_4_Field :=
                                                 16#0#;
      --  category5 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block5 of SRAM, configured as 0x10, else if the splitaddress below
      --  block5 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block5 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_5 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_5_Field :=
                                                 16#0#;
      --  category6 of core_x_iram0_dram_dma_line, if the splitaddress in
      --  block6 of SRAM, configured as 0x10, else if the splitaddress below
      --  block6 of SRAM, configured as 0x11, else if splitaddress higher than
      --  block6 of SRAM, configured as 0x00
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_6 : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_6_Field :=
                                                 16#0#;
      --  splitaddr of core_x_iram0_dram_dma_line, configured as [15:8]bit of
      --  actual address
      CORE_X_DRAM0_DMA_SRAM_LINE_1_SPLITADDR  : CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_CORE_X_DRAM0_DMA_SRAM_LINE_1_SPLITADDR_Field :=
                                                 16#0#;
      --  unspecified
      Reserved_22_31                          : ESP32S3_Registers.UInt10 :=
                                                 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_Register use record
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_0 at 0 range 0 .. 1;
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_1 at 0 range 2 .. 3;
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_2 at 0 range 4 .. 5;
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_3 at 0 range 6 .. 7;
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_4 at 0 range 8 .. 9;
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_5 at 0 range 10 .. 11;
      CORE_X_DRAM0_DMA_SRAM_LINE_1_CATEGORY_6 at 0 range 12 .. 13;
      CORE_X_DRAM0_DMA_SRAM_LINE_1_SPLITADDR  at 0 range 14 .. 21;
      Reserved_22_31                          at 0 range 22 .. 31;
   end record;

   --  corex iram0 permission configuration register 0
   type CORE_X_IRAM0_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock corex iram0 permission configuration register
      CORE_X_IRAM0_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                   : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_PMS_CONSTRAIN_0_Register use record
      CORE_X_IRAM0_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                   at 0 range 1 .. 31;
   end record;

   subtype CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_0_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_1_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_2_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_3_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_ROM_WORLD_1_PMS_Field is
     ESP32S3_Registers.UInt3;

   --  corex iram0 permission configuration register 0
   type CORE_X_IRAM0_PMS_CONSTRAIN_1_Register is record
      --  core0/core1's permission of instruction region0 of SRAM in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_0                : CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_0_Field :=
                                                                      16#7#;
      --  core0/core1's permission of instruction region1 of SRAM in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_1                : CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_1_Field :=
                                                                      16#7#;
      --  core0/core1's permission of instruction region2 of SRAM in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_2                : CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_2_Field :=
                                                                      16#7#;
      --  core0/core1's permission of instruction region3 of SRAM in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_3                : CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_3_Field :=
                                                                      16#7#;
      --  core0/core1's permission of icache data sram block0 in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_0 : CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_0_Field :=
                                                                      16#7#;
      --  core0/core1's permission of icache data sram block1 in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_1 : CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_1_Field :=
                                                                      16#7#;
      --  core0/core1's permission of rom in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_ROM_WORLD_1_PMS                   : CORE_X_IRAM0_PMS_CONSTRAIN_1_CORE_X_IRAM0_PMS_CONSTRAIN_ROM_WORLD_1_PMS_Field :=
                                                                      16#7#;
      --  unspecified
      Reserved_21_31                                               : ESP32S3_Registers.UInt11 :=
                                                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_PMS_CONSTRAIN_1_Register use record
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_0                at 0 range 0 .. 2;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_1                at 0 range 3 .. 5;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_2                at 0 range 6 .. 8;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_3                at 0 range 9 .. 11;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_0 at 0 range 12 .. 14;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_1 at 0 range 15 .. 17;
      CORE_X_IRAM0_PMS_CONSTRAIN_ROM_WORLD_1_PMS                   at 0 range 18 .. 20;
      Reserved_21_31                                               at 0 range 21 .. 31;
   end record;

   subtype CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_0_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_1_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_2_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_3_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_ROM_WORLD_0_PMS_Field is
     ESP32S3_Registers.UInt3;

   --  corex iram0 permission configuration register 1
   type CORE_X_IRAM0_PMS_CONSTRAIN_2_Register is record
      --  core0/core1's permission of instruction region0 of SRAM in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_0                : CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_0_Field :=
                                                                      16#7#;
      --  core0/core1's permission of instruction region1 of SRAM in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_1                : CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_1_Field :=
                                                                      16#7#;
      --  core0/core1's permission of instruction region2 of SRAM in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_2                : CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_2_Field :=
                                                                      16#7#;
      --  core0/core1's permission of instruction region3 of SRAM in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_3                : CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_3_Field :=
                                                                      16#7#;
      --  core0/core1's permission of icache data sram block0 in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_0 : CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_0_Field :=
                                                                      16#7#;
      --  core0/core1's permission of icache data sram block1 in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_1 : CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_1_Field :=
                                                                      16#7#;
      --  core0/core1's permission of rom in world1
      CORE_X_IRAM0_PMS_CONSTRAIN_ROM_WORLD_0_PMS                   : CORE_X_IRAM0_PMS_CONSTRAIN_2_CORE_X_IRAM0_PMS_CONSTRAIN_ROM_WORLD_0_PMS_Field :=
                                                                      16#7#;
      --  unspecified
      Reserved_21_31                                               : ESP32S3_Registers.UInt11 :=
                                                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_IRAM0_PMS_CONSTRAIN_2_Register use record
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_0                at 0 range 0 .. 2;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_1                at 0 range 3 .. 5;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_2                at 0 range 6 .. 8;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_3                at 0 range 9 .. 11;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_0 at 0 range 12 .. 14;
      CORE_X_IRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_1 at 0 range 15 .. 17;
      CORE_X_IRAM0_PMS_CONSTRAIN_ROM_WORLD_0_PMS                   at 0 range 18 .. 20;
      Reserved_21_31                                               at 0 range 21 .. 31;
   end record;

   --  core0 iram0 permission monitor configuration register 0
   type CORE_0_IRAM0_PMS_MONITOR_0_Register is record
      --  Set 1 to lock core0 iram0 permission monitor register
      CORE_0_IRAM0_PMS_MONITOR_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_IRAM0_PMS_MONITOR_0_Register use record
      CORE_0_IRAM0_PMS_MONITOR_LOCK at 0 range 0 .. 0;
      Reserved_1_31                 at 0 range 1 .. 31;
   end record;

   --  core0 iram0 permission monitor configuration register 1
   type CORE_0_IRAM0_PMS_MONITOR_1_Register is record
      --  Set 1 to clear core0 iram0 permission violated interrupt
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable core0 iram0 permission monitor, when core0_iram
      --  violated permission, will trigger interrupt
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                        : ESP32S3_Registers.UInt30 :=
                                              16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_IRAM0_PMS_MONITOR_1_Register use record
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_CLR at 0 range 0 .. 0;
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                        at 0 range 2 .. 31;
   end record;

   subtype CORE_0_IRAM0_PMS_MONITOR_2_CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_IRAM0_PMS_MONITOR_2_CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field is
     ESP32S3_Registers.UInt24;

   --  core0 iram0 permission monitor configuration register 2
   type CORE_0_IRAM0_PMS_MONITOR_2_Register is record
      --  Read-only. recorded core0 iram0 pms monitor interrupt status.
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR             : Boolean;
      --  Read-only. recorded core0 iram0 wr status, only if loadstore is 1
      --  have meaning, 1(store), 0(load).
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WR        : Boolean;
      --  Read-only. recorded core0 iram0 loadstore status, indicated the type
      --  of operation, 0(fetch), 1(load/store).
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_LOADSTORE : Boolean;
      --  Read-only. recorded core0 iram0 world status, 0x01 means world0, 0x10
      --  means world1.
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD     : CORE_0_IRAM0_PMS_MONITOR_2_CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field;
      --  Read-only. recorded core0 iram0 address [25:2] status when core0
      --  iram0 violated permission, the real address is 0x40000000+addr*4
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR      : CORE_0_IRAM0_PMS_MONITOR_2_CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field;
      --  unspecified
      Reserved_29_31                                    : ESP32S3_Registers.UInt3;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_IRAM0_PMS_MONITOR_2_Register use record
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR             at 0 range 0 .. 0;
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WR        at 0 range 1 .. 1;
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_LOADSTORE at 0 range 2 .. 2;
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD     at 0 range 3 .. 4;
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR      at 0 range 5 .. 28;
      Reserved_29_31                                    at 0 range 29 .. 31;
   end record;

   --  core1 iram0 permission monitor configuration register 0
   type CORE_1_IRAM0_PMS_MONITOR_0_Register is record
      --  Set 1 to lock core1 iram0 permission monitor register
      CORE_1_IRAM0_PMS_MONITOR_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_IRAM0_PMS_MONITOR_0_Register use record
      CORE_1_IRAM0_PMS_MONITOR_LOCK at 0 range 0 .. 0;
      Reserved_1_31                 at 0 range 1 .. 31;
   end record;

   --  core1 iram0 permission monitor configuration register 1
   type CORE_1_IRAM0_PMS_MONITOR_1_Register is record
      --  Set 1 to clear core1 iram0 permission violated interrupt
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable core1 iram0 permission monitor, when core1_iram
      --  violated permission, will trigger interrupt
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                        : ESP32S3_Registers.UInt30 :=
                                              16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_IRAM0_PMS_MONITOR_1_Register use record
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_CLR at 0 range 0 .. 0;
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                        at 0 range 2 .. 31;
   end record;

   subtype CORE_1_IRAM0_PMS_MONITOR_2_CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_IRAM0_PMS_MONITOR_2_CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field is
     ESP32S3_Registers.UInt24;

   --  core1 iram0 permission monitor configuration register 2
   type CORE_1_IRAM0_PMS_MONITOR_2_Register is record
      --  Read-only. recorded core1 iram0 pms monitor interrupt status.
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR             : Boolean;
      --  Read-only. recorded core1 iram0 wr status, only if loadstore is 1
      --  have meaning, 1(store), 0(load).
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WR        : Boolean;
      --  Read-only. recorded core1 iram0 loadstore status, indicated the type
      --  of operation, 0(fetch), 1(load/store).
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_LOADSTORE : Boolean;
      --  Read-only. recorded core1 iram0 world status, 0x01 means world0, 0x10
      --  means world1.
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD     : CORE_1_IRAM0_PMS_MONITOR_2_CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field;
      --  Read-only. recorded core1 iram0 address [25:2] status when core1
      --  iram0 violated permission, the real address is 0x40000000+addr*4
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR      : CORE_1_IRAM0_PMS_MONITOR_2_CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field;
      --  unspecified
      Reserved_29_31                                    : ESP32S3_Registers.UInt3;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_IRAM0_PMS_MONITOR_2_Register use record
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR             at 0 range 0 .. 0;
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WR        at 0 range 1 .. 1;
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_LOADSTORE at 0 range 2 .. 2;
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD     at 0 range 3 .. 4;
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR      at 0 range 5 .. 28;
      Reserved_29_31                                    at 0 range 29 .. 31;
   end record;

   --  corex dram0 permission configuration register 0
   type CORE_X_DRAM0_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock corex dram0 permission configuration register
      CORE_X_DRAM0_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                   : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_DRAM0_PMS_CONSTRAIN_0_Register use record
      CORE_X_DRAM0_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                   at 0 range 1 .. 31;
   end record;

   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_ROM_WORLD_0_PMS_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_ROM_WORLD_1_PMS_Field is
     ESP32S3_Registers.UInt2;

   --  corex dram0 permission configuration register 1
   type CORE_X_DRAM0_PMS_CONSTRAIN_1_Register is record
      --  core0/core1's permission of data region0 of SRAM in world0.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_0                : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_0_Field :=
                                                                      16#3#;
      --  core0/core1's permission of data region1 of SRAM in world0.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_1                : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_1_Field :=
                                                                      16#3#;
      --  core0/core1's permission of data region2 of SRAM in world0.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_2                : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_2_Field :=
                                                                      16#3#;
      --  core0/core1's permission of data region3 of SRAM in world0.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_3                : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_3_Field :=
                                                                      16#3#;
      --  core0/core1's permission of dcache data sram block0 in world0.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_0 : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_0_Field :=
                                                                      16#3#;
      --  core0/core1's permission of dcache data sram block1 in world0.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_1 : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_1_Field :=
                                                                      16#3#;
      --  core0/core1's permission of data region0 of SRAM in world1.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_0                : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_0_Field :=
                                                                      16#3#;
      --  core0/core1's permission of data region1 of SRAM in world1.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_1                : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_1_Field :=
                                                                      16#3#;
      --  core0/core1's permission of data region2 of SRAM in world1.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_2                : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_2_Field :=
                                                                      16#3#;
      --  core0/core1's permission of data region3 of SRAM in world1.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_3                : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_3_Field :=
                                                                      16#3#;
      --  core0/core1's permission of dcache data sram block0 in world1.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_0 : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_0_Field :=
                                                                      16#3#;
      --  core0/core1's permission of dcache data sram block1 in world1.
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_1 : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_1_Field :=
                                                                      16#3#;
      --  core0/core1's permission(sotre,load) of rom in world0.
      CORE_X_DRAM0_PMS_CONSTRAIN_ROM_WORLD_0_PMS                   : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_ROM_WORLD_0_PMS_Field :=
                                                                      16#3#;
      --  core0/core1's permission(sotre,load) of rom in world1.
      CORE_X_DRAM0_PMS_CONSTRAIN_ROM_WORLD_1_PMS                   : CORE_X_DRAM0_PMS_CONSTRAIN_1_CORE_X_DRAM0_PMS_CONSTRAIN_ROM_WORLD_1_PMS_Field :=
                                                                      16#3#;
      --  unspecified
      Reserved_28_31                                               : ESP32S3_Registers.UInt4 :=
                                                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_X_DRAM0_PMS_CONSTRAIN_1_Register use record
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_0                at 0 range 0 .. 1;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_1                at 0 range 2 .. 3;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_2                at 0 range 4 .. 5;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_PMS_3                at 0 range 6 .. 7;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_0 at 0 range 8 .. 9;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_0_CACHEDATAARRAY_PMS_1 at 0 range 10 .. 11;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_0                at 0 range 12 .. 13;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_1                at 0 range 14 .. 15;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_2                at 0 range 16 .. 17;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_PMS_3                at 0 range 18 .. 19;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_0 at 0 range 20 .. 21;
      CORE_X_DRAM0_PMS_CONSTRAIN_SRAM_WORLD_1_CACHEDATAARRAY_PMS_1 at 0 range 22 .. 23;
      CORE_X_DRAM0_PMS_CONSTRAIN_ROM_WORLD_0_PMS                   at 0 range 24 .. 25;
      CORE_X_DRAM0_PMS_CONSTRAIN_ROM_WORLD_1_PMS                   at 0 range 26 .. 27;
      Reserved_28_31                                               at 0 range 28 .. 31;
   end record;

   --  core0 dram0 permission monitor configuration register 0
   type CORE_0_DRAM0_PMS_MONITOR_0_Register is record
      --  Set 1 to lock core0 dram0 permission monitor configuration register.
      CORE_0_DRAM0_PMS_MONITOR_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_DRAM0_PMS_MONITOR_0_Register use record
      CORE_0_DRAM0_PMS_MONITOR_LOCK at 0 range 0 .. 0;
      Reserved_1_31                 at 0 range 1 .. 31;
   end record;

   --  core0 dram0 permission monitor configuration register 1
   type CORE_0_DRAM0_PMS_MONITOR_1_Register is record
      --  Set 1 to clear core0 dram0 permission monior interrupt.
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable core0 dram0 permission monitor interrupt.
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                        : ESP32S3_Registers.UInt30 :=
                                              16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_DRAM0_PMS_MONITOR_1_Register use record
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_CLR at 0 range 0 .. 0;
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                        at 0 range 2 .. 31;
   end record;

   subtype CORE_0_DRAM0_PMS_MONITOR_2_CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_DRAM0_PMS_MONITOR_2_CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field is
     ESP32S3_Registers.UInt22;

   --  core0 dram0 permission monitor configuration register 2.
   type CORE_0_DRAM0_PMS_MONITOR_2_Register is record
      --  Read-only. recorded core0 dram0 permission monitor interrupt status.
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR         : Boolean;
      --  Read-only. recorded core0 dram0 lock status, 1 means s32c1i access.
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_LOCK  : Boolean;
      --  Read-only. recorded core0 dram0 world status, 0x1 means world0, 0x2
      --  means world1.
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD : CORE_0_DRAM0_PMS_MONITOR_2_CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field;
      --  Read-only. recorded core0 dram0 address[25:4] status when core0 dram0
      --  violated permission,the real address is 0x3c000000+addr*16
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR  : CORE_0_DRAM0_PMS_MONITOR_2_CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field;
      --  unspecified
      Reserved_26_31                                : ESP32S3_Registers.UInt6;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_DRAM0_PMS_MONITOR_2_Register use record
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR         at 0 range 0 .. 0;
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_LOCK  at 0 range 1 .. 1;
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD at 0 range 2 .. 3;
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR  at 0 range 4 .. 25;
      Reserved_26_31                                at 0 range 26 .. 31;
   end record;

   subtype CORE_0_DRAM0_PMS_MONITOR_3_CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_BYTEEN_Field is
     ESP32S3_Registers.UInt16;

   --  core0 dram0 permission monitor configuration register 3.
   type CORE_0_DRAM0_PMS_MONITOR_3_Register is record
      --  Read-only. recorded core0 dram0 wr status, 1 means store, 0 means
      --  load.
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WR     : Boolean;
      --  Read-only. recorded core0 dram0 byteen status.
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_BYTEEN : CORE_0_DRAM0_PMS_MONITOR_3_CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_BYTEEN_Field;
      --  unspecified
      Reserved_17_31                                 : ESP32S3_Registers.UInt15;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_DRAM0_PMS_MONITOR_3_Register use record
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WR     at 0 range 0 .. 0;
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_STATUS_BYTEEN at 0 range 1 .. 16;
      Reserved_17_31                                 at 0 range 17 .. 31;
   end record;

   --  core1 dram0 permission monitor configuration register 0
   type CORE_1_DRAM0_PMS_MONITOR_0_Register is record
      --  Set 1 to lock core1 dram0 permission monitor configuration register.
      CORE_1_DRAM0_PMS_MONITOR_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_DRAM0_PMS_MONITOR_0_Register use record
      CORE_1_DRAM0_PMS_MONITOR_LOCK at 0 range 0 .. 0;
      Reserved_1_31                 at 0 range 1 .. 31;
   end record;

   --  core1 dram0 permission monitor configuration register 1
   type CORE_1_DRAM0_PMS_MONITOR_1_Register is record
      --  Set 1 to clear core1 dram0 permission monior interrupt.
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable core1 dram0 permission monitor interrupt.
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                        : ESP32S3_Registers.UInt30 :=
                                              16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_DRAM0_PMS_MONITOR_1_Register use record
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_CLR at 0 range 0 .. 0;
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                        at 0 range 2 .. 31;
   end record;

   subtype CORE_1_DRAM0_PMS_MONITOR_2_CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_DRAM0_PMS_MONITOR_2_CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field is
     ESP32S3_Registers.UInt22;

   --  core1 dram0 permission monitor configuration register 2.
   type CORE_1_DRAM0_PMS_MONITOR_2_Register is record
      --  Read-only. recorded core1 dram0 permission monitor interrupt status.
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR         : Boolean;
      --  Read-only. recorded core1 dram0 lock status, 1 means s32c1i access.
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_LOCK  : Boolean;
      --  Read-only. recorded core1 dram0 world status, 0x1 means world0, 0x2
      --  means world1.
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD : CORE_1_DRAM0_PMS_MONITOR_2_CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD_Field;
      --  Read-only. recorded core1 dram0 address[25:4] status when core1 dram0
      --  violated permission,the real address is 0x3c000000+addr*16
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR  : CORE_1_DRAM0_PMS_MONITOR_2_CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR_Field;
      --  unspecified
      Reserved_26_31                                : ESP32S3_Registers.UInt6;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_DRAM0_PMS_MONITOR_2_Register use record
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR         at 0 range 0 .. 0;
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_LOCK  at 0 range 1 .. 1;
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WORLD at 0 range 2 .. 3;
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_ADDR  at 0 range 4 .. 25;
      Reserved_26_31                                at 0 range 26 .. 31;
   end record;

   subtype CORE_1_DRAM0_PMS_MONITOR_3_CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_BYTEEN_Field is
     ESP32S3_Registers.UInt16;

   --  core1 dram0 permission monitor configuration register 3.
   type CORE_1_DRAM0_PMS_MONITOR_3_Register is record
      --  Read-only. recorded core1 dram0 wr status, 1 means store, 0 means
      --  load.
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WR     : Boolean;
      --  Read-only. recorded core1 dram0 byteen status.
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_BYTEEN : CORE_1_DRAM0_PMS_MONITOR_3_CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_BYTEEN_Field;
      --  unspecified
      Reserved_17_31                                 : ESP32S3_Registers.UInt15;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_DRAM0_PMS_MONITOR_3_Register use record
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_WR     at 0 range 0 .. 0;
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_STATUS_BYTEEN at 0 range 1 .. 16;
      Reserved_17_31                                 at 0 range 17 .. 31;
   end record;

   --  Core0 access peripherals permission configuration register 0.
   type CORE_0_PIF_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock core0 access peripherals permission Configuration
      --  Register.
      CORE_0_PIF_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_0_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                 at 0 range 1 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_GPIO_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_FE2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_FE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RTC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_IO_MUX_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_HINF_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_MISC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2S0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART1_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 access peripherals permission configuration register 1.
   type CORE_0_PIF_PMS_CONSTRAIN_1_Register is record
      --  Core0 access uart permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART    : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART_Field :=
                                                  16#3#;
      --  Core0 access g0spi_1 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_1 : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_1_Field :=
                                                  16#3#;
      --  Core0 access g0spi_0 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_0 : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_0_Field :=
                                                  16#3#;
      --  Core0 access gpio permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_GPIO    : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_GPIO_Field :=
                                                  16#3#;
      --  Core0 access fe2 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_FE2     : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_FE2_Field :=
                                                  16#3#;
      --  Core0 access fe permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_FE      : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_FE_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_12_13                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core0 access rtc permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RTC     : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RTC_Field :=
                                                  16#3#;
      --  Core0 access io_mux permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_IO_MUX  : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_IO_MUX_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_18_19                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core0 access hinf permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_HINF    : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_HINF_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_22_23                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core0 access misc permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_MISC    : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_MISC_Field :=
                                                  16#3#;
      --  Core0 access i2c permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C     : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_Field :=
                                                  16#3#;
      --  Core0 access i2s0 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2S0    : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2S0_Field :=
                                                  16#3#;
      --  Core0 access uart1 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART1   : CORE_0_PIF_PMS_CONSTRAIN_1_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART1_Field :=
                                                  16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_1_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART    at 0 range 0 .. 1;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_1 at 0 range 2 .. 3;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_0 at 0 range 4 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_GPIO    at 0 range 6 .. 7;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_FE2     at 0 range 8 .. 9;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_FE      at 0 range 10 .. 11;
      Reserved_12_13                           at 0 range 12 .. 13;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RTC     at 0 range 14 .. 15;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_IO_MUX  at 0 range 16 .. 17;
      Reserved_18_19                           at 0 range 18 .. 19;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_HINF    at 0 range 20 .. 21;
      Reserved_22_23                           at 0 range 22 .. 23;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_MISC    at 0 range 24 .. 25;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C     at 0 range 26 .. 27;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2S0    at 0 range 28 .. 29;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART1   at 0 range 30 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UHCI0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SLCHOST_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RMT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PCNT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SLC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_LEDC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BACKUP_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BB_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWM0_Field is
     ESP32S3_Registers.UInt2;
   --  CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP
   --  array element
   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Element is
     ESP32S3_Registers.UInt2;

   --  CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP
   --  array
   type CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field_Array is array (1 .. 2)
     of CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for
   --  CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP
   type CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP as an array
            Arr : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SYSTIMER_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 access peripherals permission configuration register 2.
   type CORE_0_PIF_PMS_CONSTRAIN_2_Register is record
      --  Core0 access bt permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BT         : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BT_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_2_3                                : ESP32S3_Registers.UInt2 :=
                                                     16#0#;
      --  Core0 access i2c_ext0 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT0   : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT0_Field :=
                                                     16#3#;
      --  Core0 access uhci0 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UHCI0      : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UHCI0_Field :=
                                                     16#3#;
      --  Core0 access slchost permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SLCHOST    : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SLCHOST_Field :=
                                                     16#3#;
      --  Core0 access rmt permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RMT        : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RMT_Field :=
                                                     16#3#;
      --  Core0 access pcnt permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PCNT       : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PCNT_Field :=
                                                     16#3#;
      --  Core0 access slc permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SLC        : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SLC_Field :=
                                                     16#3#;
      --  Core0 access ledc permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_LEDC       : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_LEDC_Field :=
                                                     16#3#;
      --  Core0 access backup permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BACKUP     : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BACKUP_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_20_21                              : ESP32S3_Registers.UInt2 :=
                                                     16#0#;
      --  Core0 access bb permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BB         : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BB_Field :=
                                                     16#3#;
      --  Core0 access pwm0 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWM0       : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWM0_Field :=
                                                     16#3#;
      --  Core0 access timergroup permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field :=
                                                     (As_Array => False, Val => 16#3#);
      --  Core0 access systimer permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SYSTIMER   : CORE_0_PIF_PMS_CONSTRAIN_2_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SYSTIMER_Field :=
                                                     16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_2_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BT         at 0 range 0 .. 1;
      Reserved_2_3                                at 0 range 2 .. 3;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT0   at 0 range 4 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UHCI0      at 0 range 6 .. 7;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SLCHOST    at 0 range 8 .. 9;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RMT        at 0 range 10 .. 11;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PCNT       at 0 range 12 .. 13;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SLC        at 0 range 14 .. 15;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_LEDC       at 0 range 16 .. 17;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BACKUP     at 0 range 18 .. 19;
      Reserved_20_21                              at 0 range 20 .. 21;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BB         at 0 range 22 .. 23;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWM0       at 0 range 24 .. 25;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP at 0 range 26 .. 29;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SYSTIMER   at 0 range 30 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SPI_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SPI_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_APB_CTRL_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SDIO_HOST_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CAN_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWM1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2S1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RWBT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_WIFIMAC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWR_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 access peripherals permission configuration register 3.
   type CORE_0_PIF_PMS_CONSTRAIN_3_Register is record
      --  Core0 access spi_2 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SPI_2     : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SPI_2_Field :=
                                                    16#3#;
      --  Core0 access spi_3 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SPI_3     : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SPI_3_Field :=
                                                    16#3#;
      --  Core0 access apb_ctrl permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_APB_CTRL  : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_APB_CTRL_Field :=
                                                    16#3#;
      --  Core0 access i2c_ext1 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT1  : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT1_Field :=
                                                    16#3#;
      --  Core0 access sdio_host permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SDIO_HOST : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SDIO_HOST_Field :=
                                                    16#3#;
      --  Core0 access can permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CAN       : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CAN_Field :=
                                                    16#3#;
      --  Core0 access pwm1 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWM1      : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWM1_Field :=
                                                    16#3#;
      --  Core0 access i2s1 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2S1      : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2S1_Field :=
                                                    16#3#;
      --  Core0 access uart2 permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART2     : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART2_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_18_21                             : ESP32S3_Registers.UInt4 :=
                                                    16#0#;
      --  Core0 access rwbt permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RWBT      : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RWBT_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_24_25                             : ESP32S3_Registers.UInt2 :=
                                                    16#0#;
      --  Core0 access wifimac permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_WIFIMAC   : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_WIFIMAC_Field :=
                                                    16#3#;
      --  Core0 access pwr permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWR       : CORE_0_PIF_PMS_CONSTRAIN_3_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWR_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_30_31                             : ESP32S3_Registers.UInt2 :=
                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_3_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SPI_2     at 0 range 0 .. 1;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SPI_3     at 0 range 2 .. 3;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_APB_CTRL  at 0 range 4 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT1  at 0 range 6 .. 7;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SDIO_HOST at 0 range 8 .. 9;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CAN       at 0 range 10 .. 11;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWM1      at 0 range 12 .. 13;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_I2S1      at 0 range 14 .. 15;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_UART2     at 0 range 16 .. 17;
      Reserved_18_21                             at 0 range 18 .. 21;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_RWBT      at 0 range 22 .. 23;
      Reserved_24_25                             at 0 range 24 .. 25;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_WIFIMAC   at 0 range 26 .. 27;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_PWR       at 0 range 28 .. 29;
      Reserved_30_31                             at 0 range 30 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_DEVICE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_WRAP_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_PERI_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_DMA_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_APB_ADC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_LCD_CAM_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BT_PWR_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SYSTEM_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SENSITIVE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_INTERRUPT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_DMA_COPY_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CACHE_CONFIG_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_AD_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_DIO_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_WORLD_CONTROLLER_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 access peripherals permission configuration register 4.
   type CORE_0_PIF_PMS_CONSTRAIN_4_Register is record
      --  Core0 access usb_device permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_DEVICE       : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_DEVICE_Field :=
                                                           16#3#;
      --  Core0 access usb_wrap permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_WRAP         : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_WRAP_Field :=
                                                           16#3#;
      --  Core0 access crypto_peri permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_PERI      : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_PERI_Field :=
                                                           16#3#;
      --  Core0 access crypto_dma permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_DMA       : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_DMA_Field :=
                                                           16#3#;
      --  Core0 access apb_adc permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_APB_ADC          : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_APB_ADC_Field :=
                                                           16#3#;
      --  Core0 access lcd_cam permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_LCD_CAM          : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_LCD_CAM_Field :=
                                                           16#3#;
      --  Core0 access bt_pwr permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BT_PWR           : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BT_PWR_Field :=
                                                           16#3#;
      --  Core0 access usb permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB              : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_Field :=
                                                           16#3#;
      --  Core0 access system permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SYSTEM           : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SYSTEM_Field :=
                                                           16#3#;
      --  Core0 access sensitive permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SENSITIVE        : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SENSITIVE_Field :=
                                                           16#3#;
      --  Core0 access interrupt permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_INTERRUPT        : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_INTERRUPT_Field :=
                                                           16#3#;
      --  Core0 access dma_copy permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_DMA_COPY         : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_DMA_COPY_Field :=
                                                           16#3#;
      --  Core0 access cache_config permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CACHE_CONFIG     : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CACHE_CONFIG_Field :=
                                                           16#3#;
      --  Core0 access ad permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_AD               : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_AD_Field :=
                                                           16#3#;
      --  Core0 access dio permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_DIO              : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_DIO_Field :=
                                                           16#3#;
      --  Core0 access world_controller permission in world0.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_WORLD_CONTROLLER : CORE_0_PIF_PMS_CONSTRAIN_4_CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_WORLD_CONTROLLER_Field :=
                                                           16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_4_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_DEVICE       at 0 range 0 .. 1;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB_WRAP         at 0 range 2 .. 3;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_PERI      at 0 range 4 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_DMA       at 0 range 6 .. 7;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_APB_ADC          at 0 range 8 .. 9;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_LCD_CAM          at 0 range 10 .. 11;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_BT_PWR           at 0 range 12 .. 13;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_USB              at 0 range 14 .. 15;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SYSTEM           at 0 range 16 .. 17;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_SENSITIVE        at 0 range 18 .. 19;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_INTERRUPT        at 0 range 20 .. 21;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_DMA_COPY         at 0 range 22 .. 23;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_CACHE_CONFIG     at 0 range 24 .. 25;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_AD               at 0 range 26 .. 27;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_DIO              at 0 range 28 .. 29;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_0_WORLD_CONTROLLER at 0 range 30 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_GPIO_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_FE2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_FE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RTC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_IO_MUX_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_HINF_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_MISC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2S0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART1_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 access peripherals permission configuration register 5.
   type CORE_0_PIF_PMS_CONSTRAIN_5_Register is record
      --  Core0 access uart permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART    : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART_Field :=
                                                  16#3#;
      --  Core0 access g0spi_1 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_1 : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_1_Field :=
                                                  16#3#;
      --  Core0 access g0spi_0 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_0 : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_0_Field :=
                                                  16#3#;
      --  Core0 access gpio permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_GPIO    : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_GPIO_Field :=
                                                  16#3#;
      --  Core0 access fe2 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_FE2     : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_FE2_Field :=
                                                  16#3#;
      --  Core0 access fe permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_FE      : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_FE_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_12_13                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core0 access rtc permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RTC     : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RTC_Field :=
                                                  16#3#;
      --  Core0 access io_mux permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_IO_MUX  : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_IO_MUX_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_18_19                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core0 access hinf permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_HINF    : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_HINF_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_22_23                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core0 access misc permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_MISC    : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_MISC_Field :=
                                                  16#3#;
      --  Core0 access i2c permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C     : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_Field :=
                                                  16#3#;
      --  Core0 access i2s0 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2S0    : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2S0_Field :=
                                                  16#3#;
      --  Core0 access uart1 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART1   : CORE_0_PIF_PMS_CONSTRAIN_5_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART1_Field :=
                                                  16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_5_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART    at 0 range 0 .. 1;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_1 at 0 range 2 .. 3;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_0 at 0 range 4 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_GPIO    at 0 range 6 .. 7;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_FE2     at 0 range 8 .. 9;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_FE      at 0 range 10 .. 11;
      Reserved_12_13                           at 0 range 12 .. 13;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RTC     at 0 range 14 .. 15;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_IO_MUX  at 0 range 16 .. 17;
      Reserved_18_19                           at 0 range 18 .. 19;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_HINF    at 0 range 20 .. 21;
      Reserved_22_23                           at 0 range 22 .. 23;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_MISC    at 0 range 24 .. 25;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C     at 0 range 26 .. 27;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2S0    at 0 range 28 .. 29;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART1   at 0 range 30 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UHCI0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SLCHOST_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RMT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PCNT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SLC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_LEDC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BACKUP_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BB_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWM0_Field is
     ESP32S3_Registers.UInt2;
   --  CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP
   --  array element
   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Element is
     ESP32S3_Registers.UInt2;

   --  CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP
   --  array
   type CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field_Array is array (1 .. 2)
     of CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for
   --  CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP
   type CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP as an array
            Arr : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SYSTIMER_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 access peripherals permission configuration register 6.
   type CORE_0_PIF_PMS_CONSTRAIN_6_Register is record
      --  Core0 access bt permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BT         : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BT_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_2_3                                : ESP32S3_Registers.UInt2 :=
                                                     16#0#;
      --  Core0 access i2c_ext0 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT0   : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT0_Field :=
                                                     16#3#;
      --  Core0 access uhci0 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UHCI0      : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UHCI0_Field :=
                                                     16#3#;
      --  Core0 access slchost permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SLCHOST    : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SLCHOST_Field :=
                                                     16#3#;
      --  Core0 access rmt permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RMT        : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RMT_Field :=
                                                     16#3#;
      --  Core0 access pcnt permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PCNT       : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PCNT_Field :=
                                                     16#3#;
      --  Core0 access slc permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SLC        : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SLC_Field :=
                                                     16#3#;
      --  Core0 access ledc permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_LEDC       : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_LEDC_Field :=
                                                     16#3#;
      --  Core0 access backup permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BACKUP     : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BACKUP_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_20_21                              : ESP32S3_Registers.UInt2 :=
                                                     16#0#;
      --  Core0 access bb permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BB         : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BB_Field :=
                                                     16#3#;
      --  Core0 access pwm0 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWM0       : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWM0_Field :=
                                                     16#3#;
      --  Core0 access timergroup permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field :=
                                                     (As_Array => False, Val => 16#3#);
      --  Core0 access systimer permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SYSTIMER   : CORE_0_PIF_PMS_CONSTRAIN_6_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SYSTIMER_Field :=
                                                     16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_6_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BT         at 0 range 0 .. 1;
      Reserved_2_3                                at 0 range 2 .. 3;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT0   at 0 range 4 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UHCI0      at 0 range 6 .. 7;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SLCHOST    at 0 range 8 .. 9;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RMT        at 0 range 10 .. 11;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PCNT       at 0 range 12 .. 13;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SLC        at 0 range 14 .. 15;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_LEDC       at 0 range 16 .. 17;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BACKUP     at 0 range 18 .. 19;
      Reserved_20_21                              at 0 range 20 .. 21;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BB         at 0 range 22 .. 23;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWM0       at 0 range 24 .. 25;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP at 0 range 26 .. 29;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SYSTIMER   at 0 range 30 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SPI_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SPI_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_APB_CTRL_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SDIO_HOST_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CAN_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWM1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2S1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RWBT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_WIFIMAC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWR_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 access peripherals permission configuration register 7.
   type CORE_0_PIF_PMS_CONSTRAIN_7_Register is record
      --  Core0 access spi_2 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SPI_2     : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SPI_2_Field :=
                                                    16#3#;
      --  Core0 access spi_3 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SPI_3     : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SPI_3_Field :=
                                                    16#3#;
      --  Core0 access apb_ctrl permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_APB_CTRL  : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_APB_CTRL_Field :=
                                                    16#3#;
      --  Core0 access i2c_ext1 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT1  : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT1_Field :=
                                                    16#3#;
      --  Core0 access sdio_host permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SDIO_HOST : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SDIO_HOST_Field :=
                                                    16#3#;
      --  Core0 access can permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CAN       : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CAN_Field :=
                                                    16#3#;
      --  Core0 access pwm1 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWM1      : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWM1_Field :=
                                                    16#3#;
      --  Core0 access i2s1 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2S1      : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2S1_Field :=
                                                    16#3#;
      --  Core0 access uart2 permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART2     : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART2_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_18_21                             : ESP32S3_Registers.UInt4 :=
                                                    16#0#;
      --  Core0 access rwbt permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RWBT      : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RWBT_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_24_25                             : ESP32S3_Registers.UInt2 :=
                                                    16#0#;
      --  Core0 access wifimac permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_WIFIMAC   : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_WIFIMAC_Field :=
                                                    16#3#;
      --  Core0 access pwr permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWR       : CORE_0_PIF_PMS_CONSTRAIN_7_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWR_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_30_31                             : ESP32S3_Registers.UInt2 :=
                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_7_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SPI_2     at 0 range 0 .. 1;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SPI_3     at 0 range 2 .. 3;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_APB_CTRL  at 0 range 4 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT1  at 0 range 6 .. 7;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SDIO_HOST at 0 range 8 .. 9;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CAN       at 0 range 10 .. 11;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWM1      at 0 range 12 .. 13;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_I2S1      at 0 range 14 .. 15;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_UART2     at 0 range 16 .. 17;
      Reserved_18_21                             at 0 range 18 .. 21;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_RWBT      at 0 range 22 .. 23;
      Reserved_24_25                             at 0 range 24 .. 25;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_WIFIMAC   at 0 range 26 .. 27;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_PWR       at 0 range 28 .. 29;
      Reserved_30_31                             at 0 range 30 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_DEVICE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_WRAP_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_PERI_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_DMA_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_APB_ADC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_LCD_CAM_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BT_PWR_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SYSTEM_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SENSITIVE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_INTERRUPT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_DMA_COPY_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CACHE_CONFIG_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_AD_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_DIO_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_WORLD_CONTROLLER_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 access peripherals permission configuration register 8.
   type CORE_0_PIF_PMS_CONSTRAIN_8_Register is record
      --  Core0 access usb_device permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_DEVICE       : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_DEVICE_Field :=
                                                           16#3#;
      --  Core0 access usb_wrap permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_WRAP         : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_WRAP_Field :=
                                                           16#3#;
      --  Core0 access crypto_peri permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_PERI      : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_PERI_Field :=
                                                           16#3#;
      --  Core0 access crypto_dma permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_DMA       : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_DMA_Field :=
                                                           16#3#;
      --  Core0 access apb_adc permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_APB_ADC          : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_APB_ADC_Field :=
                                                           16#3#;
      --  Core0 access lcd_cam permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_LCD_CAM          : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_LCD_CAM_Field :=
                                                           16#3#;
      --  Core0 access bt_pwr permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BT_PWR           : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BT_PWR_Field :=
                                                           16#3#;
      --  Core0 access usb permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB              : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_Field :=
                                                           16#3#;
      --  Core0 access system permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SYSTEM           : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SYSTEM_Field :=
                                                           16#3#;
      --  Core0 access sensitive permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SENSITIVE        : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SENSITIVE_Field :=
                                                           16#3#;
      --  Core0 access interrupt permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_INTERRUPT        : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_INTERRUPT_Field :=
                                                           16#3#;
      --  Core0 access dma_copy permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_DMA_COPY         : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_DMA_COPY_Field :=
                                                           16#3#;
      --  Core0 access cache_config permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CACHE_CONFIG     : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CACHE_CONFIG_Field :=
                                                           16#3#;
      --  Core0 access ad permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_AD               : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_AD_Field :=
                                                           16#3#;
      --  Core0 access dio permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_DIO              : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_DIO_Field :=
                                                           16#3#;
      --  Core0 access world_controller permission in world1.
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_WORLD_CONTROLLER : CORE_0_PIF_PMS_CONSTRAIN_8_CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_WORLD_CONTROLLER_Field :=
                                                           16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_8_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_DEVICE       at 0 range 0 .. 1;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB_WRAP         at 0 range 2 .. 3;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_PERI      at 0 range 4 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_DMA       at 0 range 6 .. 7;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_APB_ADC          at 0 range 8 .. 9;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_LCD_CAM          at 0 range 10 .. 11;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_BT_PWR           at 0 range 12 .. 13;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_USB              at 0 range 14 .. 15;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SYSTEM           at 0 range 16 .. 17;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_SENSITIVE        at 0 range 18 .. 19;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_INTERRUPT        at 0 range 20 .. 21;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_DMA_COPY         at 0 range 22 .. 23;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_CACHE_CONFIG     at 0 range 24 .. 25;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_AD               at 0 range 26 .. 27;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_DIO              at 0 range 28 .. 29;
      CORE_0_PIF_PMS_CONSTRAIN_WORLD_1_WORLD_CONTROLLER at 0 range 30 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_9_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_0_Field is
     ESP32S3_Registers.UInt11;
   subtype CORE_0_PIF_PMS_CONSTRAIN_9_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_1_Field is
     ESP32S3_Registers.UInt11;

   --  Core0 access peripherals permission configuration register 9.
   type CORE_0_PIF_PMS_CONSTRAIN_9_Register is record
      --  RTCFast memory split address in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_0 : CORE_0_PIF_PMS_CONSTRAIN_9_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_0_Field :=
                                                           16#7FF#;
      --  RTCFast memory split address in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_1 : CORE_0_PIF_PMS_CONSTRAIN_9_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_1_Field :=
                                                           16#7FF#;
      --  unspecified
      Reserved_22_31                                    : ESP32S3_Registers.UInt10 :=
                                                           16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_9_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_0 at 0 range 0 .. 10;
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_1 at 0 range 11 .. 21;
      Reserved_22_31                                    at 0 range 22 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_10_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_10_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_H_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_10_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_10_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_H_Field is
     ESP32S3_Registers.UInt3;

   --  Core0 access peripherals permission configuration register 10.
   type CORE_0_PIF_PMS_CONSTRAIN_10_Register is record
      --  RTCFast memory low region permission in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_L : CORE_0_PIF_PMS_CONSTRAIN_10_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_L_Field :=
                                                    16#7#;
      --  RTCFast memory high region permission in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_H : CORE_0_PIF_PMS_CONSTRAIN_10_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_H_Field :=
                                                    16#7#;
      --  RTCFast memory low region permission in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_L : CORE_0_PIF_PMS_CONSTRAIN_10_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_L_Field :=
                                                    16#7#;
      --  RTCFast memory high region permission in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_H : CORE_0_PIF_PMS_CONSTRAIN_10_CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_H_Field :=
                                                    16#7#;
      --  unspecified
      Reserved_12_31                             : ESP32S3_Registers.UInt20 :=
                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_10_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_L at 0 range 0 .. 2;
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_H at 0 range 3 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_L at 0 range 6 .. 8;
      CORE_0_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_H at 0 range 9 .. 11;
      Reserved_12_31                             at 0 range 12 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_11_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_0_Field is
     ESP32S3_Registers.UInt11;
   subtype CORE_0_PIF_PMS_CONSTRAIN_11_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_1_Field is
     ESP32S3_Registers.UInt11;

   --  Core0 access peripherals permission configuration register 11.
   type CORE_0_PIF_PMS_CONSTRAIN_11_Register is record
      --  RTCSlow_0 memory split address in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_0 : CORE_0_PIF_PMS_CONSTRAIN_11_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_0_Field :=
                                                             16#7FF#;
      --  RTCSlow_0 memory split address in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_1 : CORE_0_PIF_PMS_CONSTRAIN_11_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_1_Field :=
                                                             16#7FF#;
      --  unspecified
      Reserved_22_31                                      : ESP32S3_Registers.UInt10 :=
                                                             16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_11_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_0 at 0 range 0 .. 10;
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_1 at 0 range 11 .. 21;
      Reserved_22_31                                      at 0 range 22 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_12_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_12_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_H_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_12_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_12_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_H_Field is
     ESP32S3_Registers.UInt3;

   --  Core0 access peripherals permission configuration register 12.
   type CORE_0_PIF_PMS_CONSTRAIN_12_Register is record
      --  RTCSlow_0 memory low region permission in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_L : CORE_0_PIF_PMS_CONSTRAIN_12_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_L_Field :=
                                                      16#7#;
      --  RTCSlow_0 memory high region permission in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_H : CORE_0_PIF_PMS_CONSTRAIN_12_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_H_Field :=
                                                      16#7#;
      --  RTCSlow_0 memory low region permission in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_L : CORE_0_PIF_PMS_CONSTRAIN_12_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_L_Field :=
                                                      16#7#;
      --  RTCSlow_0 memory high region permission in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_H : CORE_0_PIF_PMS_CONSTRAIN_12_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_H_Field :=
                                                      16#7#;
      --  unspecified
      Reserved_12_31                               : ESP32S3_Registers.UInt20 :=
                                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_12_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_L at 0 range 0 .. 2;
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_H at 0 range 3 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_L at 0 range 6 .. 8;
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_H at 0 range 9 .. 11;
      Reserved_12_31                               at 0 range 12 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_13_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_0_Field is
     ESP32S3_Registers.UInt11;
   subtype CORE_0_PIF_PMS_CONSTRAIN_13_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_1_Field is
     ESP32S3_Registers.UInt11;

   --  Core0 access peripherals permission configuration register 13.
   type CORE_0_PIF_PMS_CONSTRAIN_13_Register is record
      --  RTCSlow_1 memory split address in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_0 : CORE_0_PIF_PMS_CONSTRAIN_13_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_0_Field :=
                                                             16#7FF#;
      --  RTCSlow_1 memory split address in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_1 : CORE_0_PIF_PMS_CONSTRAIN_13_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_1_Field :=
                                                             16#7FF#;
      --  unspecified
      Reserved_22_31                                      : ESP32S3_Registers.UInt10 :=
                                                             16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_13_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_0 at 0 range 0 .. 10;
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_1 at 0 range 11 .. 21;
      Reserved_22_31                                      at 0 range 22 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_CONSTRAIN_14_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_14_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_H_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_14_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_CONSTRAIN_14_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_H_Field is
     ESP32S3_Registers.UInt3;

   --  Core0 access peripherals permission configuration register 14.
   type CORE_0_PIF_PMS_CONSTRAIN_14_Register is record
      --  RTCSlow_1 memory low region permission in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_L : CORE_0_PIF_PMS_CONSTRAIN_14_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_L_Field :=
                                                      16#7#;
      --  RTCSlow_1 memory high region permission in world 0 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_H : CORE_0_PIF_PMS_CONSTRAIN_14_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_H_Field :=
                                                      16#7#;
      --  RTCSlow_1 memory low region permission in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_L : CORE_0_PIF_PMS_CONSTRAIN_14_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_L_Field :=
                                                      16#7#;
      --  RTCSlow_1 memory high region permission in world 1 for core0.
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_H : CORE_0_PIF_PMS_CONSTRAIN_14_CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_H_Field :=
                                                      16#7#;
      --  unspecified
      Reserved_12_31                               : ESP32S3_Registers.UInt20 :=
                                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_CONSTRAIN_14_Register use record
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_L at 0 range 0 .. 2;
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_H at 0 range 3 .. 5;
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_L at 0 range 6 .. 8;
      CORE_0_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_H at 0 range 9 .. 11;
      Reserved_12_31                               at 0 range 12 .. 31;
   end record;

   --  Core0 region permission register 0.
   type CORE_0_REGION_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock core0 region permission registers.
      CORE_0_REGION_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                    : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_0_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                    at 0 range 1 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_7_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_8_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_9_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_10_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 region permission register 1.
   type CORE_0_REGION_PMS_CONSTRAIN_1_Register is record
      --  Region 0 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_0  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_0_Field :=
                                                     16#3#;
      --  Region 1 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_1  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_1_Field :=
                                                     16#3#;
      --  Region 2 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_2  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_2_Field :=
                                                     16#3#;
      --  Region 3 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_3  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_3_Field :=
                                                     16#3#;
      --  Region 4 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_4  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_4_Field :=
                                                     16#3#;
      --  Region 5 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_5  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_5_Field :=
                                                     16#3#;
      --  Region 6 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_6  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_6_Field :=
                                                     16#3#;
      --  Region 7 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_7  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_7_Field :=
                                                     16#3#;
      --  Region 8 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_8  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_8_Field :=
                                                     16#3#;
      --  Region 9 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_9  : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_9_Field :=
                                                     16#3#;
      --  Region 10 permission in world 0 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_10 : CORE_0_REGION_PMS_CONSTRAIN_1_CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_10_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_22_31                              : ESP32S3_Registers.UInt10 :=
                                                     16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_1_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_0  at 0 range 0 .. 1;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_1  at 0 range 2 .. 3;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_2  at 0 range 4 .. 5;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_3  at 0 range 6 .. 7;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_4  at 0 range 8 .. 9;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_5  at 0 range 10 .. 11;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_6  at 0 range 12 .. 13;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_7  at 0 range 14 .. 15;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_8  at 0 range 16 .. 17;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_9  at 0 range 18 .. 19;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_0_AREA_10 at 0 range 20 .. 21;
      Reserved_22_31                              at 0 range 22 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_7_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_8_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_9_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_10_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 region permission register 2.
   type CORE_0_REGION_PMS_CONSTRAIN_2_Register is record
      --  Region 0 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_0  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_0_Field :=
                                                     16#3#;
      --  Region 1 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_1  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_1_Field :=
                                                     16#3#;
      --  Region 2 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_2  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_2_Field :=
                                                     16#3#;
      --  Region 3 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_3  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_3_Field :=
                                                     16#3#;
      --  Region 4 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_4  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_4_Field :=
                                                     16#3#;
      --  Region 5 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_5  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_5_Field :=
                                                     16#3#;
      --  Region 6 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_6  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_6_Field :=
                                                     16#3#;
      --  Region 7 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_7  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_7_Field :=
                                                     16#3#;
      --  Region 8 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_8  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_8_Field :=
                                                     16#3#;
      --  Region 9 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_9  : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_9_Field :=
                                                     16#3#;
      --  Region 10 permission in world 1 for core0.
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_10 : CORE_0_REGION_PMS_CONSTRAIN_2_CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_10_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_22_31                              : ESP32S3_Registers.UInt10 :=
                                                     16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_2_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_0  at 0 range 0 .. 1;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_1  at 0 range 2 .. 3;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_2  at 0 range 4 .. 5;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_3  at 0 range 6 .. 7;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_4  at 0 range 8 .. 9;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_5  at 0 range 10 .. 11;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_6  at 0 range 12 .. 13;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_7  at 0 range 14 .. 15;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_8  at 0 range 16 .. 17;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_9  at 0 range 18 .. 19;
      CORE_0_REGION_PMS_CONSTRAIN_WORLD_1_AREA_10 at 0 range 20 .. 21;
      Reserved_22_31                              at 0 range 22 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_3_CORE_0_REGION_PMS_CONSTRAIN_ADDR_0_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 3.
   type CORE_0_REGION_PMS_CONSTRAIN_3_Register is record
      --  Region 0 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_0 : CORE_0_REGION_PMS_CONSTRAIN_3_CORE_0_REGION_PMS_CONSTRAIN_ADDR_0_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_3_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_0 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_4_CORE_0_REGION_PMS_CONSTRAIN_ADDR_1_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 4.
   type CORE_0_REGION_PMS_CONSTRAIN_4_Register is record
      --  Region 0 end address and Region 1 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_1 : CORE_0_REGION_PMS_CONSTRAIN_4_CORE_0_REGION_PMS_CONSTRAIN_ADDR_1_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_4_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_1 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_5_CORE_0_REGION_PMS_CONSTRAIN_ADDR_2_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 5.
   type CORE_0_REGION_PMS_CONSTRAIN_5_Register is record
      --  Region 1 end address and Region 2 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_2 : CORE_0_REGION_PMS_CONSTRAIN_5_CORE_0_REGION_PMS_CONSTRAIN_ADDR_2_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_5_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_2 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_6_CORE_0_REGION_PMS_CONSTRAIN_ADDR_3_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 6.
   type CORE_0_REGION_PMS_CONSTRAIN_6_Register is record
      --  Region 2 end address and Region 3 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_3 : CORE_0_REGION_PMS_CONSTRAIN_6_CORE_0_REGION_PMS_CONSTRAIN_ADDR_3_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_6_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_3 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_7_CORE_0_REGION_PMS_CONSTRAIN_ADDR_4_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 7.
   type CORE_0_REGION_PMS_CONSTRAIN_7_Register is record
      --  Region 3 end address and Region 4 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_4 : CORE_0_REGION_PMS_CONSTRAIN_7_CORE_0_REGION_PMS_CONSTRAIN_ADDR_4_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_7_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_4 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_8_CORE_0_REGION_PMS_CONSTRAIN_ADDR_5_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 8.
   type CORE_0_REGION_PMS_CONSTRAIN_8_Register is record
      --  Region 4 end address and Region 5 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_5 : CORE_0_REGION_PMS_CONSTRAIN_8_CORE_0_REGION_PMS_CONSTRAIN_ADDR_5_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_8_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_5 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_9_CORE_0_REGION_PMS_CONSTRAIN_ADDR_6_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 9.
   type CORE_0_REGION_PMS_CONSTRAIN_9_Register is record
      --  Region 5 end address and Region 6 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_6 : CORE_0_REGION_PMS_CONSTRAIN_9_CORE_0_REGION_PMS_CONSTRAIN_ADDR_6_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_9_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_6 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_10_CORE_0_REGION_PMS_CONSTRAIN_ADDR_7_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 10.
   type CORE_0_REGION_PMS_CONSTRAIN_10_Register is record
      --  Region 6 end address and Region 7 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_7 : CORE_0_REGION_PMS_CONSTRAIN_10_CORE_0_REGION_PMS_CONSTRAIN_ADDR_7_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_10_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_7 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_11_CORE_0_REGION_PMS_CONSTRAIN_ADDR_8_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 11.
   type CORE_0_REGION_PMS_CONSTRAIN_11_Register is record
      --  Region 7 end address and Region 8 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_8 : CORE_0_REGION_PMS_CONSTRAIN_11_CORE_0_REGION_PMS_CONSTRAIN_ADDR_8_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_11_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_8 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_12_CORE_0_REGION_PMS_CONSTRAIN_ADDR_9_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 12.
   type CORE_0_REGION_PMS_CONSTRAIN_12_Register is record
      --  Region 8 end address and Region 9 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_9 : CORE_0_REGION_PMS_CONSTRAIN_12_CORE_0_REGION_PMS_CONSTRAIN_ADDR_9_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_12_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_9 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_13_CORE_0_REGION_PMS_CONSTRAIN_ADDR_10_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 13.
   type CORE_0_REGION_PMS_CONSTRAIN_13_Register is record
      --  Region 9 end address and Region 10 start address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_10 : CORE_0_REGION_PMS_CONSTRAIN_13_CORE_0_REGION_PMS_CONSTRAIN_ADDR_10_Field :=
                                             16#0#;
      --  unspecified
      Reserved_30_31                      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_13_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_10 at 0 range 0 .. 29;
      Reserved_30_31                      at 0 range 30 .. 31;
   end record;

   subtype CORE_0_REGION_PMS_CONSTRAIN_14_CORE_0_REGION_PMS_CONSTRAIN_ADDR_11_Field is
     ESP32S3_Registers.UInt30;

   --  Core0 region permission register 14.
   type CORE_0_REGION_PMS_CONSTRAIN_14_Register is record
      --  Region 10 end address for core0.
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_11 : CORE_0_REGION_PMS_CONSTRAIN_14_CORE_0_REGION_PMS_CONSTRAIN_ADDR_11_Field :=
                                             16#0#;
      --  unspecified
      Reserved_30_31                      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_REGION_PMS_CONSTRAIN_14_Register use record
      CORE_0_REGION_PMS_CONSTRAIN_ADDR_11 at 0 range 0 .. 29;
      Reserved_30_31                      at 0 range 30 .. 31;
   end record;

   --  Core0 permission report register 0.
   type CORE_0_PIF_PMS_MONITOR_0_Register is record
      --  Set 1 to lock core0 permission report registers.
      CORE_0_PIF_PMS_MONITOR_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31               : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_MONITOR_0_Register use record
      CORE_0_PIF_PMS_MONITOR_LOCK at 0 range 0 .. 0;
      Reserved_1_31               at 0 range 1 .. 31;
   end record;

   --  Core0 permission report register 1.
   type CORE_0_PIF_PMS_MONITOR_1_Register is record
      --  Set 1 to clear interrupt that core0 initiate illegal PIF bus access.
      CORE_0_PIF_PMS_MONITOR_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable interrupt that core0 initiate illegal PIF bus access.
      CORE_0_PIF_PMS_MONITOR_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                      : ESP32S3_Registers.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_MONITOR_1_Register use record
      CORE_0_PIF_PMS_MONITOR_VIOLATE_CLR at 0 range 0 .. 0;
      CORE_0_PIF_PMS_MONITOR_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                      at 0 range 2 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_MONITOR_2_CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HSIZE_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_0_PIF_PMS_MONITOR_2_CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HWORLD_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 permission report register 2.
   type CORE_0_PIF_PMS_MONITOR_2_Register is record
      --  Read-only. Record core0 illegal access interrupt state.
      CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR           : Boolean;
      --  Read-only. Record hport information when core0 initiate illegal
      --  access.
      CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HPORT_0 : Boolean;
      --  Read-only. Record access type when core0 initate illegal access.
      CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HSIZE   : CORE_0_PIF_PMS_MONITOR_2_CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HSIZE_Field;
      --  Read-only. Record access direction when core0 initiate illegal
      --  access.
      CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HWRITE  : Boolean;
      --  Read-only. Record world information when core0 initiate illegal
      --  access.
      CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HWORLD  : CORE_0_PIF_PMS_MONITOR_2_CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HWORLD_Field;
      --  unspecified
      Reserved_8_31                                 : ESP32S3_Registers.UInt24;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_MONITOR_2_Register use record
      CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR           at 0 range 0 .. 0;
      CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HPORT_0 at 0 range 1 .. 1;
      CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HSIZE   at 0 range 2 .. 4;
      CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HWRITE  at 0 range 5 .. 5;
      CORE_0_PIF_PMS_MONITOR_VIOLATE_STATUS_HWORLD  at 0 range 6 .. 7;
      Reserved_8_31                                 at 0 range 8 .. 31;
   end record;

   --  Core0 permission report register 4.
   type CORE_0_PIF_PMS_MONITOR_4_Register is record
      --  Set 1 to clear interrupt that core0 initiate unsupported access type.
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable interrupt that core0 initiate unsupported access
      --  type.
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                              : ESP32S3_Registers.UInt30 :=
                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_MONITOR_4_Register use record
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_CLR at 0 range 0 .. 0;
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                              at 0 range 2 .. 31;
   end record;

   subtype CORE_0_PIF_PMS_MONITOR_5_CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HSIZE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_0_PIF_PMS_MONITOR_5_CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HWORLD_Field is
     ESP32S3_Registers.UInt2;

   --  Core0 permission report register 5.
   type CORE_0_PIF_PMS_MONITOR_5_Register is record
      --  Read-only. Record core0 unsupported access type interrupt state.
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_INTR          : Boolean;
      --  Read-only. Record access type when core0 initiate unsupported access
      --  type.
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HSIZE  : CORE_0_PIF_PMS_MONITOR_5_CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HSIZE_Field;
      --  Read-only. Record world information when core0 initiate unsupported
      --  access type.
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HWORLD : CORE_0_PIF_PMS_MONITOR_5_CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HWORLD_Field;
      --  unspecified
      Reserved_5_31                                        : ESP32S3_Registers.UInt27;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_PIF_PMS_MONITOR_5_Register use record
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_INTR          at 0 range 0 .. 0;
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HSIZE  at 0 range 1 .. 2;
      CORE_0_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HWORLD at 0 range 3 .. 4;
      Reserved_5_31                                        at 0 range 5 .. 31;
   end record;

   --  core0 vecbase override configuration register 0
   type CORE_0_VECBASE_OVERRIDE_LOCK_Register is record
      --  Set 1 to lock core0 vecbase configuration register
      CORE_0_VECBASE_OVERRIDE_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_VECBASE_OVERRIDE_LOCK_Register use record
      CORE_0_VECBASE_OVERRIDE_LOCK at 0 range 0 .. 0;
      Reserved_1_31                at 0 range 1 .. 31;
   end record;

   --  core0 vecbase override configuration register 0
   type CORE_0_VECBASE_OVERRIDE_0_Register is record
      --  Set 1 to mask world, then only world0_value will work.
      CORE_0_VECBASE_WORLD_MASK : Boolean := True;
      --  unspecified
      Reserved_1_31             : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_VECBASE_OVERRIDE_0_Register use record
      CORE_0_VECBASE_WORLD_MASK at 0 range 0 .. 0;
      Reserved_1_31             at 0 range 1 .. 31;
   end record;

   subtype CORE_0_VECBASE_OVERRIDE_1_CORE_0_VECBASE_OVERRIDE_WORLD0_VALUE_Field is
     ESP32S3_Registers.UInt22;
   subtype CORE_0_VECBASE_OVERRIDE_1_CORE_0_VECBASE_OVERRIDE_SEL_Field is
     ESP32S3_Registers.UInt2;

   --  core0 vecbase override configuration register 1
   type CORE_0_VECBASE_OVERRIDE_1_Register is record
      --  world0 vecbase_override register, when core0 in world0 use this
      --  register to override vecbase register.
      CORE_0_VECBASE_OVERRIDE_WORLD0_VALUE : CORE_0_VECBASE_OVERRIDE_1_CORE_0_VECBASE_OVERRIDE_WORLD0_VALUE_Field :=
                                              16#0#;
      --  Set 0x3 to sel vecbase_override to override vecbase register.
      CORE_0_VECBASE_OVERRIDE_SEL          : CORE_0_VECBASE_OVERRIDE_1_CORE_0_VECBASE_OVERRIDE_SEL_Field :=
                                              16#0#;
      --  unspecified
      Reserved_24_31                       : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_VECBASE_OVERRIDE_1_Register use record
      CORE_0_VECBASE_OVERRIDE_WORLD0_VALUE at 0 range 0 .. 21;
      CORE_0_VECBASE_OVERRIDE_SEL          at 0 range 22 .. 23;
      Reserved_24_31                       at 0 range 24 .. 31;
   end record;

   subtype CORE_0_VECBASE_OVERRIDE_2_CORE_0_VECBASE_OVERRIDE_WORLD1_VALUE_Field is
     ESP32S3_Registers.UInt22;

   --  core0 vecbase override configuration register 1
   type CORE_0_VECBASE_OVERRIDE_2_Register is record
      --  world1 vecbase_override register, when core0 in world1 use this
      --  register to override vecbase register.
      CORE_0_VECBASE_OVERRIDE_WORLD1_VALUE : CORE_0_VECBASE_OVERRIDE_2_CORE_0_VECBASE_OVERRIDE_WORLD1_VALUE_Field :=
                                              16#0#;
      --  unspecified
      Reserved_22_31                       : ESP32S3_Registers.UInt10 :=
                                              16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_VECBASE_OVERRIDE_2_Register use record
      CORE_0_VECBASE_OVERRIDE_WORLD1_VALUE at 0 range 0 .. 21;
      Reserved_22_31                       at 0 range 22 .. 31;
   end record;

   --  core0 toomanyexception override configuration register 0.
   type CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_0_Register is record
      --  Set 1 to lock core0 toomanyexception override configuration register
      CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                            : ESP32S3_Registers.UInt31 :=
                                                  16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_0_Register use record
      CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_LOCK at 0 range 0 .. 0;
      Reserved_1_31                            at 0 range 1 .. 31;
   end record;

   --  core0 toomanyexception override configuration register 1.
   type CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_1_Register is record
      --  Set 1 to mask toomanyexception.
      CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE : Boolean := True;
      --  unspecified
      Reserved_1_31                       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_1_Register use record
      CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE at 0 range 0 .. 0;
      Reserved_1_31                       at 0 range 1 .. 31;
   end record;

   --  Core1 access peripherals permission configuration register 0.
   type CORE_1_PIF_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock core1 pif permission configuration register.
      CORE_1_PIF_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_0_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                 at 0 range 1 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_GPIO_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_FE2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_FE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RTC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_IO_MUX_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_HINF_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_MISC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2S0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART1_Field is
     ESP32S3_Registers.UInt2;

   --  Core1 access peripherals permission configuration register 1.
   type CORE_1_PIF_PMS_CONSTRAIN_1_Register is record
      --  Core1 access uart permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART    : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART_Field :=
                                                  16#3#;
      --  Core1 access g0spi_1 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_1 : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_1_Field :=
                                                  16#3#;
      --  Core1 access g0spi_0 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_0 : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_0_Field :=
                                                  16#3#;
      --  Core1 access gpio permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_GPIO    : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_GPIO_Field :=
                                                  16#3#;
      --  Core1 access fe2 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_FE2     : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_FE2_Field :=
                                                  16#3#;
      --  Core1 access fe permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_FE      : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_FE_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_12_13                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core1 access rtc permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RTC     : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RTC_Field :=
                                                  16#3#;
      --  Core1 access io_mux permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_IO_MUX  : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_IO_MUX_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_18_19                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core1 access hinf permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_HINF    : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_HINF_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_22_23                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core1 access misc permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_MISC    : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_MISC_Field :=
                                                  16#3#;
      --  Core1 access i2c permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C     : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_Field :=
                                                  16#3#;
      --  Core1 access i2s0 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2S0    : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2S0_Field :=
                                                  16#3#;
      --  Core1 access uart1 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART1   : CORE_1_PIF_PMS_CONSTRAIN_1_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART1_Field :=
                                                  16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_1_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART    at 0 range 0 .. 1;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_1 at 0 range 2 .. 3;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_G0SPI_0 at 0 range 4 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_GPIO    at 0 range 6 .. 7;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_FE2     at 0 range 8 .. 9;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_FE      at 0 range 10 .. 11;
      Reserved_12_13                           at 0 range 12 .. 13;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RTC     at 0 range 14 .. 15;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_IO_MUX  at 0 range 16 .. 17;
      Reserved_18_19                           at 0 range 18 .. 19;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_HINF    at 0 range 20 .. 21;
      Reserved_22_23                           at 0 range 22 .. 23;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_MISC    at 0 range 24 .. 25;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C     at 0 range 26 .. 27;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2S0    at 0 range 28 .. 29;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART1   at 0 range 30 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UHCI0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SLCHOST_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RMT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PCNT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SLC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_LEDC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BACKUP_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BB_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWM0_Field is
     ESP32S3_Registers.UInt2;
   --  CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP
   --  array element
   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Element is
     ESP32S3_Registers.UInt2;

   --  CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP
   --  array
   type CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field_Array is array (1 .. 2)
     of CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for
   --  CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP
   type CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP as an array
            Arr : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SYSTIMER_Field is
     ESP32S3_Registers.UInt2;

   --  Core1 access peripherals permission configuration register 2.
   type CORE_1_PIF_PMS_CONSTRAIN_2_Register is record
      --  Core1 access bt permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BT         : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BT_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_2_3                                : ESP32S3_Registers.UInt2 :=
                                                     16#0#;
      --  Core1 access i2c_ext0 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT0   : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT0_Field :=
                                                     16#3#;
      --  Core1 access uhci0 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UHCI0      : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UHCI0_Field :=
                                                     16#3#;
      --  Core1 access slchost permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SLCHOST    : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SLCHOST_Field :=
                                                     16#3#;
      --  Core1 access rmt permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RMT        : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RMT_Field :=
                                                     16#3#;
      --  Core1 access pcnt permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PCNT       : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PCNT_Field :=
                                                     16#3#;
      --  Core1 access slc permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SLC        : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SLC_Field :=
                                                     16#3#;
      --  Core1 access ledc permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_LEDC       : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_LEDC_Field :=
                                                     16#3#;
      --  Core1 access backup permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BACKUP     : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BACKUP_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_20_21                              : ESP32S3_Registers.UInt2 :=
                                                     16#0#;
      --  Core1 access bb permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BB         : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BB_Field :=
                                                     16#3#;
      --  Core1 access pwm0 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWM0       : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWM0_Field :=
                                                     16#3#;
      --  Core1 access timergroup permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP_Field :=
                                                     (As_Array => False, Val => 16#3#);
      --  Core1 access systimer permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SYSTIMER   : CORE_1_PIF_PMS_CONSTRAIN_2_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SYSTIMER_Field :=
                                                     16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_2_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BT         at 0 range 0 .. 1;
      Reserved_2_3                                at 0 range 2 .. 3;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT0   at 0 range 4 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UHCI0      at 0 range 6 .. 7;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SLCHOST    at 0 range 8 .. 9;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RMT        at 0 range 10 .. 11;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PCNT       at 0 range 12 .. 13;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SLC        at 0 range 14 .. 15;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_LEDC       at 0 range 16 .. 17;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BACKUP     at 0 range 18 .. 19;
      Reserved_20_21                              at 0 range 20 .. 21;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BB         at 0 range 22 .. 23;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWM0       at 0 range 24 .. 25;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_TIMERGROUP at 0 range 26 .. 29;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SYSTIMER   at 0 range 30 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SPI_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SPI_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_APB_CTRL_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SDIO_HOST_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CAN_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWM1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2S1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RWBT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_WIFIMAC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWR_Field is
     ESP32S3_Registers.UInt2;

   --  Core1 access peripherals permission configuration register 3.
   type CORE_1_PIF_PMS_CONSTRAIN_3_Register is record
      --  Core1 access spi_2 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SPI_2     : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SPI_2_Field :=
                                                    16#3#;
      --  Core1 access spi_3 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SPI_3     : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SPI_3_Field :=
                                                    16#3#;
      --  Core1 access apb_ctrl permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_APB_CTRL  : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_APB_CTRL_Field :=
                                                    16#3#;
      --  Core1 access i2c_ext1 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT1  : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT1_Field :=
                                                    16#3#;
      --  Core1 access sdio_host permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SDIO_HOST : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SDIO_HOST_Field :=
                                                    16#3#;
      --  Core1 access can permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CAN       : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CAN_Field :=
                                                    16#3#;
      --  Core1 access pwm1 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWM1      : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWM1_Field :=
                                                    16#3#;
      --  Core1 access i2s1 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2S1      : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2S1_Field :=
                                                    16#3#;
      --  Core1 access uart2 permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART2     : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART2_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_18_21                             : ESP32S3_Registers.UInt4 :=
                                                    16#0#;
      --  Core1 access rwbt permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RWBT      : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RWBT_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_24_25                             : ESP32S3_Registers.UInt2 :=
                                                    16#0#;
      --  Core1 access wifimac permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_WIFIMAC   : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_WIFIMAC_Field :=
                                                    16#3#;
      --  Core1 access pwr permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWR       : CORE_1_PIF_PMS_CONSTRAIN_3_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWR_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_30_31                             : ESP32S3_Registers.UInt2 :=
                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_3_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SPI_2     at 0 range 0 .. 1;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SPI_3     at 0 range 2 .. 3;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_APB_CTRL  at 0 range 4 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2C_EXT1  at 0 range 6 .. 7;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SDIO_HOST at 0 range 8 .. 9;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CAN       at 0 range 10 .. 11;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWM1      at 0 range 12 .. 13;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_I2S1      at 0 range 14 .. 15;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_UART2     at 0 range 16 .. 17;
      Reserved_18_21                             at 0 range 18 .. 21;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_RWBT      at 0 range 22 .. 23;
      Reserved_24_25                             at 0 range 24 .. 25;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_WIFIMAC   at 0 range 26 .. 27;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_PWR       at 0 range 28 .. 29;
      Reserved_30_31                             at 0 range 30 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_DEVICE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_WRAP_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_PERI_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_DMA_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_APB_ADC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_LCD_CAM_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BT_PWR_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SYSTEM_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SENSITIVE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_INTERRUPT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_DMA_COPY_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CACHE_CONFIG_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_AD_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_DIO_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_WORLD_CONTROLLER_Field is
     ESP32S3_Registers.UInt2;

   --  Core1 access peripherals permission configuration register 4.
   type CORE_1_PIF_PMS_CONSTRAIN_4_Register is record
      --  Core1 access usb_device permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_DEVICE       : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_DEVICE_Field :=
                                                           16#3#;
      --  Core1 access usb_wrap permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_WRAP         : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_WRAP_Field :=
                                                           16#3#;
      --  Core1 access crypto_peri permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_PERI      : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_PERI_Field :=
                                                           16#3#;
      --  Core1 access crypto_dma permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_DMA       : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_DMA_Field :=
                                                           16#3#;
      --  Core1 access apb_adc permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_APB_ADC          : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_APB_ADC_Field :=
                                                           16#3#;
      --  Core1 access lcd_cam permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_LCD_CAM          : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_LCD_CAM_Field :=
                                                           16#3#;
      --  Core1 access bt_pwr permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BT_PWR           : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BT_PWR_Field :=
                                                           16#3#;
      --  Core1 access usb permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB              : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_Field :=
                                                           16#3#;
      --  Core1 access system permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SYSTEM           : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SYSTEM_Field :=
                                                           16#3#;
      --  Core1 access sensitive permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SENSITIVE        : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SENSITIVE_Field :=
                                                           16#3#;
      --  Core1 access interrupt permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_INTERRUPT        : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_INTERRUPT_Field :=
                                                           16#3#;
      --  Core1 access dma_copy permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_DMA_COPY         : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_DMA_COPY_Field :=
                                                           16#3#;
      --  Core1 access cache_config permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CACHE_CONFIG     : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CACHE_CONFIG_Field :=
                                                           16#3#;
      --  Core1 access ad permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_AD               : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_AD_Field :=
                                                           16#3#;
      --  Core1 access dio permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_DIO              : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_DIO_Field :=
                                                           16#3#;
      --  Core1 access world_controller permission in world0.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_WORLD_CONTROLLER : CORE_1_PIF_PMS_CONSTRAIN_4_CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_WORLD_CONTROLLER_Field :=
                                                           16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_4_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_DEVICE       at 0 range 0 .. 1;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB_WRAP         at 0 range 2 .. 3;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_PERI      at 0 range 4 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CRYPTO_DMA       at 0 range 6 .. 7;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_APB_ADC          at 0 range 8 .. 9;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_LCD_CAM          at 0 range 10 .. 11;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_BT_PWR           at 0 range 12 .. 13;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_USB              at 0 range 14 .. 15;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SYSTEM           at 0 range 16 .. 17;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_SENSITIVE        at 0 range 18 .. 19;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_INTERRUPT        at 0 range 20 .. 21;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_DMA_COPY         at 0 range 22 .. 23;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_CACHE_CONFIG     at 0 range 24 .. 25;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_AD               at 0 range 26 .. 27;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_DIO              at 0 range 28 .. 29;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_0_WORLD_CONTROLLER at 0 range 30 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_GPIO_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_FE2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_FE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RTC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_IO_MUX_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_HINF_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_MISC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2S0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART1_Field is
     ESP32S3_Registers.UInt2;

   --  Core1 access peripherals permission configuration register 5.
   type CORE_1_PIF_PMS_CONSTRAIN_5_Register is record
      --  Core1 access uart permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART    : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART_Field :=
                                                  16#3#;
      --  Core1 access g0spi_1 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_1 : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_1_Field :=
                                                  16#3#;
      --  Core1 access g0spi_0 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_0 : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_0_Field :=
                                                  16#3#;
      --  Core1 access gpio permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_GPIO    : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_GPIO_Field :=
                                                  16#3#;
      --  Core1 access fe2 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_FE2     : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_FE2_Field :=
                                                  16#3#;
      --  Core1 access fe permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_FE      : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_FE_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_12_13                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core1 access rtc permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RTC     : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RTC_Field :=
                                                  16#3#;
      --  Core1 access io_mux permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_IO_MUX  : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_IO_MUX_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_18_19                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core1 access hinf permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_HINF    : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_HINF_Field :=
                                                  16#3#;
      --  unspecified
      Reserved_22_23                           : ESP32S3_Registers.UInt2 :=
                                                  16#0#;
      --  Core1 access misc permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_MISC    : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_MISC_Field :=
                                                  16#3#;
      --  Core1 access i2c permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C     : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_Field :=
                                                  16#3#;
      --  Core1 access i2s0 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2S0    : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2S0_Field :=
                                                  16#3#;
      --  Core1 access uart1 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART1   : CORE_1_PIF_PMS_CONSTRAIN_5_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART1_Field :=
                                                  16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_5_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART    at 0 range 0 .. 1;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_1 at 0 range 2 .. 3;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_G0SPI_0 at 0 range 4 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_GPIO    at 0 range 6 .. 7;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_FE2     at 0 range 8 .. 9;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_FE      at 0 range 10 .. 11;
      Reserved_12_13                           at 0 range 12 .. 13;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RTC     at 0 range 14 .. 15;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_IO_MUX  at 0 range 16 .. 17;
      Reserved_18_19                           at 0 range 18 .. 19;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_HINF    at 0 range 20 .. 21;
      Reserved_22_23                           at 0 range 22 .. 23;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_MISC    at 0 range 24 .. 25;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C     at 0 range 26 .. 27;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2S0    at 0 range 28 .. 29;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART1   at 0 range 30 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UHCI0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SLCHOST_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RMT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PCNT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SLC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_LEDC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BACKUP_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BB_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWM0_Field is
     ESP32S3_Registers.UInt2;
   --  CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP
   --  array element
   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Element is
     ESP32S3_Registers.UInt2;

   --  CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP
   --  array
   type CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field_Array is array (1 .. 2)
     of CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for
   --  CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP
   type CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP as an array
            Arr : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SYSTIMER_Field is
     ESP32S3_Registers.UInt2;

   --  Core1 access peripherals permission configuration register 6.
   type CORE_1_PIF_PMS_CONSTRAIN_6_Register is record
      --  Core1 access bt permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BT         : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BT_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_2_3                                : ESP32S3_Registers.UInt2 :=
                                                     16#0#;
      --  Core1 access i2c_ext0 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT0   : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT0_Field :=
                                                     16#3#;
      --  Core1 access uhci0 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UHCI0      : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UHCI0_Field :=
                                                     16#3#;
      --  Core1 access slchost permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SLCHOST    : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SLCHOST_Field :=
                                                     16#3#;
      --  Core1 access rmt permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RMT        : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RMT_Field :=
                                                     16#3#;
      --  Core1 access pcnt permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PCNT       : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PCNT_Field :=
                                                     16#3#;
      --  Core1 access slc permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SLC        : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SLC_Field :=
                                                     16#3#;
      --  Core1 access ledc permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_LEDC       : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_LEDC_Field :=
                                                     16#3#;
      --  Core1 access backup permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BACKUP     : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BACKUP_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_20_21                              : ESP32S3_Registers.UInt2 :=
                                                     16#0#;
      --  Core1 access bb permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BB         : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BB_Field :=
                                                     16#3#;
      --  Core1 access pwm0 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWM0       : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWM0_Field :=
                                                     16#3#;
      --  Core1 access timergroup permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP_Field :=
                                                     (As_Array => False, Val => 16#3#);
      --  Core1 access systimer permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SYSTIMER   : CORE_1_PIF_PMS_CONSTRAIN_6_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SYSTIMER_Field :=
                                                     16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_6_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BT         at 0 range 0 .. 1;
      Reserved_2_3                                at 0 range 2 .. 3;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT0   at 0 range 4 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UHCI0      at 0 range 6 .. 7;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SLCHOST    at 0 range 8 .. 9;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RMT        at 0 range 10 .. 11;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PCNT       at 0 range 12 .. 13;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SLC        at 0 range 14 .. 15;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_LEDC       at 0 range 16 .. 17;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BACKUP     at 0 range 18 .. 19;
      Reserved_20_21                              at 0 range 20 .. 21;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BB         at 0 range 22 .. 23;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWM0       at 0 range 24 .. 25;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_TIMERGROUP at 0 range 26 .. 29;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SYSTIMER   at 0 range 30 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SPI_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SPI_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_APB_CTRL_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SDIO_HOST_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CAN_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWM1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2S1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RWBT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_WIFIMAC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWR_Field is
     ESP32S3_Registers.UInt2;

   --  Core1 access peripherals permission configuration register 7.
   type CORE_1_PIF_PMS_CONSTRAIN_7_Register is record
      --  Core1 access spi_2 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SPI_2     : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SPI_2_Field :=
                                                    16#3#;
      --  Core1 access spi_3 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SPI_3     : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SPI_3_Field :=
                                                    16#3#;
      --  Core1 access apb_ctrl permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_APB_CTRL  : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_APB_CTRL_Field :=
                                                    16#3#;
      --  Core1 access i2c_ext1 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT1  : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT1_Field :=
                                                    16#3#;
      --  Core1 access sdio_host permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SDIO_HOST : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SDIO_HOST_Field :=
                                                    16#3#;
      --  Core1 access can permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CAN       : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CAN_Field :=
                                                    16#3#;
      --  Core1 access pwm1 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWM1      : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWM1_Field :=
                                                    16#3#;
      --  Core1 access i2s1 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2S1      : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2S1_Field :=
                                                    16#3#;
      --  Core1 access uart2 permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART2     : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART2_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_18_21                             : ESP32S3_Registers.UInt4 :=
                                                    16#0#;
      --  Core1 access rwbt permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RWBT      : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RWBT_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_24_25                             : ESP32S3_Registers.UInt2 :=
                                                    16#0#;
      --  Core1 access wifimac permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_WIFIMAC   : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_WIFIMAC_Field :=
                                                    16#3#;
      --  Core1 access pwr permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWR       : CORE_1_PIF_PMS_CONSTRAIN_7_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWR_Field :=
                                                    16#3#;
      --  unspecified
      Reserved_30_31                             : ESP32S3_Registers.UInt2 :=
                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_7_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SPI_2     at 0 range 0 .. 1;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SPI_3     at 0 range 2 .. 3;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_APB_CTRL  at 0 range 4 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2C_EXT1  at 0 range 6 .. 7;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SDIO_HOST at 0 range 8 .. 9;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CAN       at 0 range 10 .. 11;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWM1      at 0 range 12 .. 13;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_I2S1      at 0 range 14 .. 15;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_UART2     at 0 range 16 .. 17;
      Reserved_18_21                             at 0 range 18 .. 21;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_RWBT      at 0 range 22 .. 23;
      Reserved_24_25                             at 0 range 24 .. 25;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_WIFIMAC   at 0 range 26 .. 27;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_PWR       at 0 range 28 .. 29;
      Reserved_30_31                             at 0 range 30 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_DEVICE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_WRAP_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_PERI_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_DMA_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_APB_ADC_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_LCD_CAM_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BT_PWR_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SYSTEM_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SENSITIVE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_INTERRUPT_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_DMA_COPY_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CACHE_CONFIG_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_AD_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_DIO_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_WORLD_CONTROLLER_Field is
     ESP32S3_Registers.UInt2;

   --  Core1 access peripherals permission configuration register 8.
   type CORE_1_PIF_PMS_CONSTRAIN_8_Register is record
      --  Core1 access usb_device permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_DEVICE       : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_DEVICE_Field :=
                                                           16#3#;
      --  Core1 access usb_wrap permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_WRAP         : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_WRAP_Field :=
                                                           16#3#;
      --  Core1 access crypto_peri permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_PERI      : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_PERI_Field :=
                                                           16#3#;
      --  Core1 access crypto_dma permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_DMA       : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_DMA_Field :=
                                                           16#3#;
      --  Core1 access apb_adc permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_APB_ADC          : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_APB_ADC_Field :=
                                                           16#3#;
      --  Core1 access lcd_cam permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_LCD_CAM          : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_LCD_CAM_Field :=
                                                           16#3#;
      --  Core1 access bt_pwr permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BT_PWR           : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BT_PWR_Field :=
                                                           16#3#;
      --  Core1 access usb permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB              : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_Field :=
                                                           16#3#;
      --  Core1 access system permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SYSTEM           : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SYSTEM_Field :=
                                                           16#3#;
      --  Core1 access sensitive permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SENSITIVE        : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SENSITIVE_Field :=
                                                           16#3#;
      --  Core1 access interrupt permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_INTERRUPT        : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_INTERRUPT_Field :=
                                                           16#3#;
      --  Core1 access dma_copy permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_DMA_COPY         : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_DMA_COPY_Field :=
                                                           16#3#;
      --  Core1 access cache_config permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CACHE_CONFIG     : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CACHE_CONFIG_Field :=
                                                           16#3#;
      --  Core1 access ad permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_AD               : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_AD_Field :=
                                                           16#3#;
      --  Core1 access dio permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_DIO              : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_DIO_Field :=
                                                           16#3#;
      --  Core1 access world_controller permission in world1.
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_WORLD_CONTROLLER : CORE_1_PIF_PMS_CONSTRAIN_8_CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_WORLD_CONTROLLER_Field :=
                                                           16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_8_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_DEVICE       at 0 range 0 .. 1;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB_WRAP         at 0 range 2 .. 3;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_PERI      at 0 range 4 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CRYPTO_DMA       at 0 range 6 .. 7;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_APB_ADC          at 0 range 8 .. 9;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_LCD_CAM          at 0 range 10 .. 11;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_BT_PWR           at 0 range 12 .. 13;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_USB              at 0 range 14 .. 15;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SYSTEM           at 0 range 16 .. 17;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_SENSITIVE        at 0 range 18 .. 19;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_INTERRUPT        at 0 range 20 .. 21;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_DMA_COPY         at 0 range 22 .. 23;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_CACHE_CONFIG     at 0 range 24 .. 25;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_AD               at 0 range 26 .. 27;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_DIO              at 0 range 28 .. 29;
      CORE_1_PIF_PMS_CONSTRAIN_WORLD_1_WORLD_CONTROLLER at 0 range 30 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_9_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_0_Field is
     ESP32S3_Registers.UInt11;
   subtype CORE_1_PIF_PMS_CONSTRAIN_9_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_1_Field is
     ESP32S3_Registers.UInt11;

   --  Core1 access peripherals permission configuration register 9.
   type CORE_1_PIF_PMS_CONSTRAIN_9_Register is record
      --  RTCFast memory split address in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_0 : CORE_1_PIF_PMS_CONSTRAIN_9_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_0_Field :=
                                                           16#7FF#;
      --  RTCFast memory split address in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_1 : CORE_1_PIF_PMS_CONSTRAIN_9_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_1_Field :=
                                                           16#7FF#;
      --  unspecified
      Reserved_22_31                                    : ESP32S3_Registers.UInt10 :=
                                                           16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_9_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_0 at 0 range 0 .. 10;
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_SPLTADDR_WORLD_1 at 0 range 11 .. 21;
      Reserved_22_31                                    at 0 range 22 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_10_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_10_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_H_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_10_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_10_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_H_Field is
     ESP32S3_Registers.UInt3;

   --  core1 access peripherals permission configuration register 10.
   type CORE_1_PIF_PMS_CONSTRAIN_10_Register is record
      --  RTCFast memory low region permission in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_L : CORE_1_PIF_PMS_CONSTRAIN_10_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_L_Field :=
                                                    16#7#;
      --  RTCFast memory high region permission in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_H : CORE_1_PIF_PMS_CONSTRAIN_10_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_H_Field :=
                                                    16#7#;
      --  RTCFast memory low region permission in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_L : CORE_1_PIF_PMS_CONSTRAIN_10_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_L_Field :=
                                                    16#7#;
      --  RTCFast memory high region permission in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_H : CORE_1_PIF_PMS_CONSTRAIN_10_CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_H_Field :=
                                                    16#7#;
      --  unspecified
      Reserved_12_31                             : ESP32S3_Registers.UInt20 :=
                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_10_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_L at 0 range 0 .. 2;
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_0_H at 0 range 3 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_L at 0 range 6 .. 8;
      CORE_1_PIF_PMS_CONSTRAIN_RTCFAST_WORLD_1_H at 0 range 9 .. 11;
      Reserved_12_31                             at 0 range 12 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_11_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_0_Field is
     ESP32S3_Registers.UInt11;
   subtype CORE_1_PIF_PMS_CONSTRAIN_11_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_1_Field is
     ESP32S3_Registers.UInt11;

   --  core1 access peripherals permission configuration register 11.
   type CORE_1_PIF_PMS_CONSTRAIN_11_Register is record
      --  RTCSlow_0 memory split address in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_0 : CORE_1_PIF_PMS_CONSTRAIN_11_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_0_Field :=
                                                             16#7FF#;
      --  RTCSlow_0 memory split address in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_1 : CORE_1_PIF_PMS_CONSTRAIN_11_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_1_Field :=
                                                             16#7FF#;
      --  unspecified
      Reserved_22_31                                      : ESP32S3_Registers.UInt10 :=
                                                             16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_11_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_0 at 0 range 0 .. 10;
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_SPLTADDR_WORLD_1 at 0 range 11 .. 21;
      Reserved_22_31                                      at 0 range 22 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_12_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_12_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_H_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_12_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_12_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_H_Field is
     ESP32S3_Registers.UInt3;

   --  core1 access peripherals permission configuration register 12.
   type CORE_1_PIF_PMS_CONSTRAIN_12_Register is record
      --  RTCSlow_0 memory low region permission in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_L : CORE_1_PIF_PMS_CONSTRAIN_12_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_L_Field :=
                                                      16#7#;
      --  RTCSlow_0 memory high region permission in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_H : CORE_1_PIF_PMS_CONSTRAIN_12_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_H_Field :=
                                                      16#7#;
      --  RTCSlow_0 memory low region permission in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_L : CORE_1_PIF_PMS_CONSTRAIN_12_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_L_Field :=
                                                      16#7#;
      --  RTCSlow_0 memory high region permission in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_H : CORE_1_PIF_PMS_CONSTRAIN_12_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_H_Field :=
                                                      16#7#;
      --  unspecified
      Reserved_12_31                               : ESP32S3_Registers.UInt20 :=
                                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_12_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_L at 0 range 0 .. 2;
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_0_H at 0 range 3 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_L at 0 range 6 .. 8;
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_0_WORLD_1_H at 0 range 9 .. 11;
      Reserved_12_31                               at 0 range 12 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_13_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_0_Field is
     ESP32S3_Registers.UInt11;
   subtype CORE_1_PIF_PMS_CONSTRAIN_13_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_1_Field is
     ESP32S3_Registers.UInt11;

   --  core1 access peripherals permission configuration register 13.
   type CORE_1_PIF_PMS_CONSTRAIN_13_Register is record
      --  RTCSlow_1 memory split address in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_0 : CORE_1_PIF_PMS_CONSTRAIN_13_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_0_Field :=
                                                             16#7FF#;
      --  RTCSlow_1 memory split address in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_1 : CORE_1_PIF_PMS_CONSTRAIN_13_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_1_Field :=
                                                             16#7FF#;
      --  unspecified
      Reserved_22_31                                      : ESP32S3_Registers.UInt10 :=
                                                             16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_13_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_0 at 0 range 0 .. 10;
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_SPLTADDR_WORLD_1 at 0 range 11 .. 21;
      Reserved_22_31                                      at 0 range 22 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_CONSTRAIN_14_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_14_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_H_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_14_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_L_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_CONSTRAIN_14_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_H_Field is
     ESP32S3_Registers.UInt3;

   --  core1 access peripherals permission configuration register 14.
   type CORE_1_PIF_PMS_CONSTRAIN_14_Register is record
      --  RTCSlow_1 memory low region permission in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_L : CORE_1_PIF_PMS_CONSTRAIN_14_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_L_Field :=
                                                      16#7#;
      --  RTCSlow_1 memory high region permission in world 0 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_H : CORE_1_PIF_PMS_CONSTRAIN_14_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_H_Field :=
                                                      16#7#;
      --  RTCSlow_1 memory low region permission in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_L : CORE_1_PIF_PMS_CONSTRAIN_14_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_L_Field :=
                                                      16#7#;
      --  RTCSlow_1 memory high region permission in world 1 for core1.
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_H : CORE_1_PIF_PMS_CONSTRAIN_14_CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_H_Field :=
                                                      16#7#;
      --  unspecified
      Reserved_12_31                               : ESP32S3_Registers.UInt20 :=
                                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_CONSTRAIN_14_Register use record
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_L at 0 range 0 .. 2;
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_0_H at 0 range 3 .. 5;
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_L at 0 range 6 .. 8;
      CORE_1_PIF_PMS_CONSTRAIN_RTCSLOW_1_WORLD_1_H at 0 range 9 .. 11;
      Reserved_12_31                               at 0 range 12 .. 31;
   end record;

   --  core1 region permission register 0.
   type CORE_1_REGION_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock core1 region permission registers.
      CORE_1_REGION_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                    : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_0_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                    at 0 range 1 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_7_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_8_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_9_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_10_Field is
     ESP32S3_Registers.UInt2;

   --  core1 region permission register 1.
   type CORE_1_REGION_PMS_CONSTRAIN_1_Register is record
      --  Region 0 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_0  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_0_Field :=
                                                     16#3#;
      --  Region 1 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_1  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_1_Field :=
                                                     16#3#;
      --  Region 2 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_2  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_2_Field :=
                                                     16#3#;
      --  Region 3 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_3  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_3_Field :=
                                                     16#3#;
      --  Region 4 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_4  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_4_Field :=
                                                     16#3#;
      --  Region 5 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_5  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_5_Field :=
                                                     16#3#;
      --  Region 6 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_6  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_6_Field :=
                                                     16#3#;
      --  Region 7 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_7  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_7_Field :=
                                                     16#3#;
      --  Region 8 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_8  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_8_Field :=
                                                     16#3#;
      --  Region 9 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_9  : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_9_Field :=
                                                     16#3#;
      --  Region 10 permission in world 0 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_10 : CORE_1_REGION_PMS_CONSTRAIN_1_CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_10_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_22_31                              : ESP32S3_Registers.UInt10 :=
                                                     16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_1_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_0  at 0 range 0 .. 1;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_1  at 0 range 2 .. 3;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_2  at 0 range 4 .. 5;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_3  at 0 range 6 .. 7;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_4  at 0 range 8 .. 9;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_5  at 0 range 10 .. 11;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_6  at 0 range 12 .. 13;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_7  at 0 range 14 .. 15;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_8  at 0 range 16 .. 17;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_9  at 0 range 18 .. 19;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_0_AREA_10 at 0 range 20 .. 21;
      Reserved_22_31                              at 0 range 22 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_0_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_1_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_2_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_3_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_4_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_5_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_6_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_7_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_8_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_9_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_10_Field is
     ESP32S3_Registers.UInt2;

   --  core1 region permission register 2.
   type CORE_1_REGION_PMS_CONSTRAIN_2_Register is record
      --  Region 0 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_0  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_0_Field :=
                                                     16#3#;
      --  Region 1 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_1  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_1_Field :=
                                                     16#3#;
      --  Region 2 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_2  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_2_Field :=
                                                     16#3#;
      --  Region 3 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_3  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_3_Field :=
                                                     16#3#;
      --  Region 4 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_4  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_4_Field :=
                                                     16#3#;
      --  Region 5 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_5  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_5_Field :=
                                                     16#3#;
      --  Region 6 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_6  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_6_Field :=
                                                     16#3#;
      --  Region 7 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_7  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_7_Field :=
                                                     16#3#;
      --  Region 8 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_8  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_8_Field :=
                                                     16#3#;
      --  Region 9 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_9  : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_9_Field :=
                                                     16#3#;
      --  Region 10 permission in world 1 for core1.
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_10 : CORE_1_REGION_PMS_CONSTRAIN_2_CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_10_Field :=
                                                     16#3#;
      --  unspecified
      Reserved_22_31                              : ESP32S3_Registers.UInt10 :=
                                                     16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_2_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_0  at 0 range 0 .. 1;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_1  at 0 range 2 .. 3;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_2  at 0 range 4 .. 5;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_3  at 0 range 6 .. 7;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_4  at 0 range 8 .. 9;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_5  at 0 range 10 .. 11;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_6  at 0 range 12 .. 13;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_7  at 0 range 14 .. 15;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_8  at 0 range 16 .. 17;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_9  at 0 range 18 .. 19;
      CORE_1_REGION_PMS_CONSTRAIN_WORLD_1_AREA_10 at 0 range 20 .. 21;
      Reserved_22_31                              at 0 range 22 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_3_CORE_1_REGION_PMS_CONSTRAIN_ADDR_0_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 3.
   type CORE_1_REGION_PMS_CONSTRAIN_3_Register is record
      --  Region 0 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_0 : CORE_1_REGION_PMS_CONSTRAIN_3_CORE_1_REGION_PMS_CONSTRAIN_ADDR_0_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_3_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_0 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_4_CORE_1_REGION_PMS_CONSTRAIN_ADDR_1_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 4.
   type CORE_1_REGION_PMS_CONSTRAIN_4_Register is record
      --  Region 0 end address and Region 1 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_1 : CORE_1_REGION_PMS_CONSTRAIN_4_CORE_1_REGION_PMS_CONSTRAIN_ADDR_1_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_4_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_1 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_5_CORE_1_REGION_PMS_CONSTRAIN_ADDR_2_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 5.
   type CORE_1_REGION_PMS_CONSTRAIN_5_Register is record
      --  Region 1 end address and Region 2 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_2 : CORE_1_REGION_PMS_CONSTRAIN_5_CORE_1_REGION_PMS_CONSTRAIN_ADDR_2_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_5_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_2 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_6_CORE_1_REGION_PMS_CONSTRAIN_ADDR_3_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 6.
   type CORE_1_REGION_PMS_CONSTRAIN_6_Register is record
      --  Region 2 end address and Region 3 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_3 : CORE_1_REGION_PMS_CONSTRAIN_6_CORE_1_REGION_PMS_CONSTRAIN_ADDR_3_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_6_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_3 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_7_CORE_1_REGION_PMS_CONSTRAIN_ADDR_4_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 7.
   type CORE_1_REGION_PMS_CONSTRAIN_7_Register is record
      --  Region 3 end address and Region 4 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_4 : CORE_1_REGION_PMS_CONSTRAIN_7_CORE_1_REGION_PMS_CONSTRAIN_ADDR_4_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_7_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_4 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_8_CORE_1_REGION_PMS_CONSTRAIN_ADDR_5_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 8.
   type CORE_1_REGION_PMS_CONSTRAIN_8_Register is record
      --  Region 4 end address and Region 5 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_5 : CORE_1_REGION_PMS_CONSTRAIN_8_CORE_1_REGION_PMS_CONSTRAIN_ADDR_5_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_8_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_5 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_9_CORE_1_REGION_PMS_CONSTRAIN_ADDR_6_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 9.
   type CORE_1_REGION_PMS_CONSTRAIN_9_Register is record
      --  Region 5 end address and Region 6 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_6 : CORE_1_REGION_PMS_CONSTRAIN_9_CORE_1_REGION_PMS_CONSTRAIN_ADDR_6_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_9_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_6 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_10_CORE_1_REGION_PMS_CONSTRAIN_ADDR_7_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 10.
   type CORE_1_REGION_PMS_CONSTRAIN_10_Register is record
      --  Region 6 end address and Region 7 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_7 : CORE_1_REGION_PMS_CONSTRAIN_10_CORE_1_REGION_PMS_CONSTRAIN_ADDR_7_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_10_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_7 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_11_CORE_1_REGION_PMS_CONSTRAIN_ADDR_8_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 11.
   type CORE_1_REGION_PMS_CONSTRAIN_11_Register is record
      --  Region 7 end address and Region 8 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_8 : CORE_1_REGION_PMS_CONSTRAIN_11_CORE_1_REGION_PMS_CONSTRAIN_ADDR_8_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_11_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_8 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_12_CORE_1_REGION_PMS_CONSTRAIN_ADDR_9_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 12.
   type CORE_1_REGION_PMS_CONSTRAIN_12_Register is record
      --  Region 8 end address and Region 9 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_9 : CORE_1_REGION_PMS_CONSTRAIN_12_CORE_1_REGION_PMS_CONSTRAIN_ADDR_9_Field :=
                                            16#0#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_12_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_9 at 0 range 0 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_13_CORE_1_REGION_PMS_CONSTRAIN_ADDR_10_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 13.
   type CORE_1_REGION_PMS_CONSTRAIN_13_Register is record
      --  Region 9 end address and Region 10 start address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_10 : CORE_1_REGION_PMS_CONSTRAIN_13_CORE_1_REGION_PMS_CONSTRAIN_ADDR_10_Field :=
                                             16#0#;
      --  unspecified
      Reserved_30_31                      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_13_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_10 at 0 range 0 .. 29;
      Reserved_30_31                      at 0 range 30 .. 31;
   end record;

   subtype CORE_1_REGION_PMS_CONSTRAIN_14_CORE_1_REGION_PMS_CONSTRAIN_ADDR_11_Field is
     ESP32S3_Registers.UInt30;

   --  core1 region permission register 14.
   type CORE_1_REGION_PMS_CONSTRAIN_14_Register is record
      --  Region 10 end address for core1.
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_11 : CORE_1_REGION_PMS_CONSTRAIN_14_CORE_1_REGION_PMS_CONSTRAIN_ADDR_11_Field :=
                                             16#0#;
      --  unspecified
      Reserved_30_31                      : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_REGION_PMS_CONSTRAIN_14_Register use record
      CORE_1_REGION_PMS_CONSTRAIN_ADDR_11 at 0 range 0 .. 29;
      Reserved_30_31                      at 0 range 30 .. 31;
   end record;

   --  core1 permission report register 0.
   type CORE_1_PIF_PMS_MONITOR_0_Register is record
      --  Set 1 to lock core1 permission report registers.
      CORE_1_PIF_PMS_MONITOR_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31               : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_MONITOR_0_Register use record
      CORE_1_PIF_PMS_MONITOR_LOCK at 0 range 0 .. 0;
      Reserved_1_31               at 0 range 1 .. 31;
   end record;

   --  core1 permission report register 1.
   type CORE_1_PIF_PMS_MONITOR_1_Register is record
      --  Set 1 to clear interrupt that core1 initiate illegal PIF bus access.
      CORE_1_PIF_PMS_MONITOR_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable interrupt that core1 initiate illegal PIF bus access.
      CORE_1_PIF_PMS_MONITOR_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                      : ESP32S3_Registers.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_MONITOR_1_Register use record
      CORE_1_PIF_PMS_MONITOR_VIOLATE_CLR at 0 range 0 .. 0;
      CORE_1_PIF_PMS_MONITOR_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                      at 0 range 2 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_MONITOR_2_CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HSIZE_Field is
     ESP32S3_Registers.UInt3;
   subtype CORE_1_PIF_PMS_MONITOR_2_CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HWORLD_Field is
     ESP32S3_Registers.UInt2;

   --  core1 permission report register 2.
   type CORE_1_PIF_PMS_MONITOR_2_Register is record
      --  Read-only. Record core1 illegal access interrupt state.
      CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR           : Boolean;
      --  Read-only. Record hport information when core1 initiate illegal
      --  access.
      CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HPORT_0 : Boolean;
      --  Read-only. Record access type when core1 initate illegal access.
      CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HSIZE   : CORE_1_PIF_PMS_MONITOR_2_CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HSIZE_Field;
      --  Read-only. Record access direction when core1 initiate illegal
      --  access.
      CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HWRITE  : Boolean;
      --  Read-only. Record world information when core1 initiate illegal
      --  access.
      CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HWORLD  : CORE_1_PIF_PMS_MONITOR_2_CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HWORLD_Field;
      --  unspecified
      Reserved_8_31                                 : ESP32S3_Registers.UInt24;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_MONITOR_2_Register use record
      CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR           at 0 range 0 .. 0;
      CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HPORT_0 at 0 range 1 .. 1;
      CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HSIZE   at 0 range 2 .. 4;
      CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HWRITE  at 0 range 5 .. 5;
      CORE_1_PIF_PMS_MONITOR_VIOLATE_STATUS_HWORLD  at 0 range 6 .. 7;
      Reserved_8_31                                 at 0 range 8 .. 31;
   end record;

   --  core1 permission report register 4.
   type CORE_1_PIF_PMS_MONITOR_4_Register is record
      --  Set 1 to clear interrupt that core1 initiate unsupported access type.
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable interrupt that core1 initiate unsupported access
      --  type.
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                              : ESP32S3_Registers.UInt30 :=
                                                    16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_MONITOR_4_Register use record
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_CLR at 0 range 0 .. 0;
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                              at 0 range 2 .. 31;
   end record;

   subtype CORE_1_PIF_PMS_MONITOR_5_CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HSIZE_Field is
     ESP32S3_Registers.UInt2;
   subtype CORE_1_PIF_PMS_MONITOR_5_CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HWORLD_Field is
     ESP32S3_Registers.UInt2;

   --  core1 permission report register 5.
   type CORE_1_PIF_PMS_MONITOR_5_Register is record
      --  Read-only. Record core1 unsupported access type interrupt state.
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_INTR          : Boolean;
      --  Read-only. Record access type when core1 initiate unsupported access
      --  type.
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HSIZE  : CORE_1_PIF_PMS_MONITOR_5_CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HSIZE_Field;
      --  Read-only. Record world information when core1 initiate unsupported
      --  access type.
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HWORLD : CORE_1_PIF_PMS_MONITOR_5_CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HWORLD_Field;
      --  unspecified
      Reserved_5_31                                        : ESP32S3_Registers.UInt27;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_PIF_PMS_MONITOR_5_Register use record
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_INTR          at 0 range 0 .. 0;
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HSIZE  at 0 range 1 .. 2;
      CORE_1_PIF_PMS_MONITOR_NONWORD_VIOLATE_STATUS_HWORLD at 0 range 3 .. 4;
      Reserved_5_31                                        at 0 range 5 .. 31;
   end record;

   --  core1 vecbase override configuration register 0
   type CORE_1_VECBASE_OVERRIDE_LOCK_Register is record
      --  Set 1 to lock core1 vecbase configuration register
      CORE_1_VECBASE_OVERRIDE_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_VECBASE_OVERRIDE_LOCK_Register use record
      CORE_1_VECBASE_OVERRIDE_LOCK at 0 range 0 .. 0;
      Reserved_1_31                at 0 range 1 .. 31;
   end record;

   --  core1 vecbase override configuration register 0
   type CORE_1_VECBASE_OVERRIDE_0_Register is record
      --  Set 1 to mask world, then only world0_value will work.
      CORE_1_VECBASE_WORLD_MASK : Boolean := True;
      --  unspecified
      Reserved_1_31             : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_VECBASE_OVERRIDE_0_Register use record
      CORE_1_VECBASE_WORLD_MASK at 0 range 0 .. 0;
      Reserved_1_31             at 0 range 1 .. 31;
   end record;

   subtype CORE_1_VECBASE_OVERRIDE_1_CORE_1_VECBASE_OVERRIDE_WORLD0_VALUE_Field is
     ESP32S3_Registers.UInt22;
   subtype CORE_1_VECBASE_OVERRIDE_1_CORE_1_VECBASE_OVERRIDE_SEL_Field is
     ESP32S3_Registers.UInt2;

   --  core1 vecbase override configuration register 1
   type CORE_1_VECBASE_OVERRIDE_1_Register is record
      --  world0 vecbase_override register, when core1 in world0 use this
      --  register to override vecbase register.
      CORE_1_VECBASE_OVERRIDE_WORLD0_VALUE : CORE_1_VECBASE_OVERRIDE_1_CORE_1_VECBASE_OVERRIDE_WORLD0_VALUE_Field :=
                                              16#0#;
      --  Set 0x3 to sel vecbase_override to override vecbase register.
      CORE_1_VECBASE_OVERRIDE_SEL          : CORE_1_VECBASE_OVERRIDE_1_CORE_1_VECBASE_OVERRIDE_SEL_Field :=
                                              16#0#;
      --  unspecified
      Reserved_24_31                       : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_VECBASE_OVERRIDE_1_Register use record
      CORE_1_VECBASE_OVERRIDE_WORLD0_VALUE at 0 range 0 .. 21;
      CORE_1_VECBASE_OVERRIDE_SEL          at 0 range 22 .. 23;
      Reserved_24_31                       at 0 range 24 .. 31;
   end record;

   subtype CORE_1_VECBASE_OVERRIDE_2_CORE_1_VECBASE_OVERRIDE_WORLD1_VALUE_Field is
     ESP32S3_Registers.UInt22;

   --  core1 vecbase override configuration register 1
   type CORE_1_VECBASE_OVERRIDE_2_Register is record
      --  world1 vecbase_override register, when core1 in world1 use this
      --  register to override vecbase register.
      CORE_1_VECBASE_OVERRIDE_WORLD1_VALUE : CORE_1_VECBASE_OVERRIDE_2_CORE_1_VECBASE_OVERRIDE_WORLD1_VALUE_Field :=
                                              16#0#;
      --  unspecified
      Reserved_22_31                       : ESP32S3_Registers.UInt10 :=
                                              16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_VECBASE_OVERRIDE_2_Register use record
      CORE_1_VECBASE_OVERRIDE_WORLD1_VALUE at 0 range 0 .. 21;
      Reserved_22_31                       at 0 range 22 .. 31;
   end record;

   --  core1 toomanyexception override configuration register 0.
   type CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_0_Register is record
      --  Set 1 to lock core1 toomanyexception override configuration register
      CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                            : ESP32S3_Registers.UInt31 :=
                                                  16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_0_Register use record
      CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_LOCK at 0 range 0 .. 0;
      Reserved_1_31                            at 0 range 1 .. 31;
   end record;

   --  core1 toomanyexception override configuration register 1.
   type CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_1_Register is record
      --  Set 1 to mask toomanyexception.
      CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE : Boolean := True;
      --  unspecified
      Reserved_1_31                       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_1_Register use record
      CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE at 0 range 0 .. 0;
      Reserved_1_31                       at 0 range 1 .. 31;
   end record;

   --  BackUp access peripherals permission configuration register 0.
   type BACKUP_BUS_PMS_CONSTRAIN_0_Register is record
      --  Set 1 to lock BackUp permission configuration registers.
      BACKUP_BUS_PMS_CONSTRAIN_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31                 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_CONSTRAIN_0_Register use record
      BACKUP_BUS_PMS_CONSTRAIN_LOCK at 0 range 0 .. 0;
      Reserved_1_31                 at 0 range 1 .. 31;
   end record;

   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_UART_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_G0SPI_1_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_G0SPI_0_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_GPIO_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_FE2_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_FE_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_RTC_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_IO_MUX_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_HINF_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_MISC_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_I2C_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_I2S0_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_UART1_Field is
     ESP32S3_Registers.UInt2;

   --  BackUp access peripherals permission configuration register 1.
   type BACKUP_BUS_PMS_CONSTRAIN_1_Register is record
      --  BackUp access uart permission.
      BACKUP_BUS_PMS_CONSTRAIN_UART    : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_UART_Field :=
                                          16#3#;
      --  BackUp access g0spi_1 permission.
      BACKUP_BUS_PMS_CONSTRAIN_G0SPI_1 : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_G0SPI_1_Field :=
                                          16#3#;
      --  BackUp access g0spi_0 permission.
      BACKUP_BUS_PMS_CONSTRAIN_G0SPI_0 : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_G0SPI_0_Field :=
                                          16#3#;
      --  BackUp access gpio permission.
      BACKUP_BUS_PMS_CONSTRAIN_GPIO    : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_GPIO_Field :=
                                          16#3#;
      --  BackUp access fe2 permission.
      BACKUP_BUS_PMS_CONSTRAIN_FE2     : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_FE2_Field :=
                                          16#3#;
      --  BackUp access fe permission.
      BACKUP_BUS_PMS_CONSTRAIN_FE      : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_FE_Field :=
                                          16#3#;
      --  unspecified
      Reserved_12_13                   : ESP32S3_Registers.UInt2 := 16#0#;
      --  BackUp access rtc permission.
      BACKUP_BUS_PMS_CONSTRAIN_RTC     : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_RTC_Field :=
                                          16#3#;
      --  BackUp access io_mux permission.
      BACKUP_BUS_PMS_CONSTRAIN_IO_MUX  : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_IO_MUX_Field :=
                                          16#3#;
      --  unspecified
      Reserved_18_19                   : ESP32S3_Registers.UInt2 := 16#0#;
      --  BackUp access hinf permission.
      BACKUP_BUS_PMS_CONSTRAIN_HINF    : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_HINF_Field :=
                                          16#3#;
      --  unspecified
      Reserved_22_23                   : ESP32S3_Registers.UInt2 := 16#0#;
      --  BackUp access misc permission.
      BACKUP_BUS_PMS_CONSTRAIN_MISC    : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_MISC_Field :=
                                          16#3#;
      --  BackUp access i2c permission.
      BACKUP_BUS_PMS_CONSTRAIN_I2C     : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_I2C_Field :=
                                          16#3#;
      --  BackUp access i2s0 permission.
      BACKUP_BUS_PMS_CONSTRAIN_I2S0    : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_I2S0_Field :=
                                          16#3#;
      --  BackUp access uart1 permission.
      BACKUP_BUS_PMS_CONSTRAIN_UART1   : BACKUP_BUS_PMS_CONSTRAIN_1_BACKUP_BUS_PMS_CONSTRAIN_UART1_Field :=
                                          16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_CONSTRAIN_1_Register use record
      BACKUP_BUS_PMS_CONSTRAIN_UART    at 0 range 0 .. 1;
      BACKUP_BUS_PMS_CONSTRAIN_G0SPI_1 at 0 range 2 .. 3;
      BACKUP_BUS_PMS_CONSTRAIN_G0SPI_0 at 0 range 4 .. 5;
      BACKUP_BUS_PMS_CONSTRAIN_GPIO    at 0 range 6 .. 7;
      BACKUP_BUS_PMS_CONSTRAIN_FE2     at 0 range 8 .. 9;
      BACKUP_BUS_PMS_CONSTRAIN_FE      at 0 range 10 .. 11;
      Reserved_12_13                   at 0 range 12 .. 13;
      BACKUP_BUS_PMS_CONSTRAIN_RTC     at 0 range 14 .. 15;
      BACKUP_BUS_PMS_CONSTRAIN_IO_MUX  at 0 range 16 .. 17;
      Reserved_18_19                   at 0 range 18 .. 19;
      BACKUP_BUS_PMS_CONSTRAIN_HINF    at 0 range 20 .. 21;
      Reserved_22_23                   at 0 range 22 .. 23;
      BACKUP_BUS_PMS_CONSTRAIN_MISC    at 0 range 24 .. 25;
      BACKUP_BUS_PMS_CONSTRAIN_I2C     at 0 range 26 .. 27;
      BACKUP_BUS_PMS_CONSTRAIN_I2S0    at 0 range 28 .. 29;
      BACKUP_BUS_PMS_CONSTRAIN_UART1   at 0 range 30 .. 31;
   end record;

   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_BT_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_I2C_EXT0_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_UHCI0_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_SLCHOST_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_RMT_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_PCNT_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_SLC_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_LEDC_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_BACKUP_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_BB_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_PWM0_Field is
     ESP32S3_Registers.UInt2;
   --  BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP array
   --  element
   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP_Element is
     ESP32S3_Registers.UInt2;

   --  BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP array
   type BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP_Field_Array is array (1 .. 2)
     of BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for
   --  BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP
   type BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP as an array
            Arr : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   subtype BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_SYSTIMER_Field is
     ESP32S3_Registers.UInt2;

   --  BackUp access peripherals permission configuration register 2.
   type BACKUP_BUS_PMS_CONSTRAIN_2_Register is record
      --  BackUp access bt permission.
      BACKUP_BUS_PMS_CONSTRAIN_BT         : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_BT_Field :=
                                             16#3#;
      --  unspecified
      Reserved_2_3                        : ESP32S3_Registers.UInt2 := 16#0#;
      --  BackUp access i2c_ext0 permission.
      BACKUP_BUS_PMS_CONSTRAIN_I2C_EXT0   : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_I2C_EXT0_Field :=
                                             16#3#;
      --  BackUp access uhci0 permission.
      BACKUP_BUS_PMS_CONSTRAIN_UHCI0      : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_UHCI0_Field :=
                                             16#3#;
      --  BackUp access slchost permission.
      BACKUP_BUS_PMS_CONSTRAIN_SLCHOST    : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_SLCHOST_Field :=
                                             16#3#;
      --  BackUp access rmt permission.
      BACKUP_BUS_PMS_CONSTRAIN_RMT        : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_RMT_Field :=
                                             16#3#;
      --  BackUp access pcnt permission.
      BACKUP_BUS_PMS_CONSTRAIN_PCNT       : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_PCNT_Field :=
                                             16#3#;
      --  BackUp access slc permission.
      BACKUP_BUS_PMS_CONSTRAIN_SLC        : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_SLC_Field :=
                                             16#3#;
      --  BackUp access ledc permission.
      BACKUP_BUS_PMS_CONSTRAIN_LEDC       : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_LEDC_Field :=
                                             16#3#;
      --  BackUp access backup permission.
      BACKUP_BUS_PMS_CONSTRAIN_BACKUP     : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_BACKUP_Field :=
                                             16#3#;
      --  unspecified
      Reserved_20_21                      : ESP32S3_Registers.UInt2 := 16#0#;
      --  BackUp access bb permission.
      BACKUP_BUS_PMS_CONSTRAIN_BB         : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_BB_Field :=
                                             16#3#;
      --  BackUp access pwm0 permission.
      BACKUP_BUS_PMS_CONSTRAIN_PWM0       : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_PWM0_Field :=
                                             16#3#;
      --  BackUp access timergroup permission.
      BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP_Field :=
                                             (As_Array => False, Val => 16#3#);
      --  BackUp access systimer permission.
      BACKUP_BUS_PMS_CONSTRAIN_SYSTIMER   : BACKUP_BUS_PMS_CONSTRAIN_2_BACKUP_BUS_PMS_CONSTRAIN_SYSTIMER_Field :=
                                             16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_CONSTRAIN_2_Register use record
      BACKUP_BUS_PMS_CONSTRAIN_BT         at 0 range 0 .. 1;
      Reserved_2_3                        at 0 range 2 .. 3;
      BACKUP_BUS_PMS_CONSTRAIN_I2C_EXT0   at 0 range 4 .. 5;
      BACKUP_BUS_PMS_CONSTRAIN_UHCI0      at 0 range 6 .. 7;
      BACKUP_BUS_PMS_CONSTRAIN_SLCHOST    at 0 range 8 .. 9;
      BACKUP_BUS_PMS_CONSTRAIN_RMT        at 0 range 10 .. 11;
      BACKUP_BUS_PMS_CONSTRAIN_PCNT       at 0 range 12 .. 13;
      BACKUP_BUS_PMS_CONSTRAIN_SLC        at 0 range 14 .. 15;
      BACKUP_BUS_PMS_CONSTRAIN_LEDC       at 0 range 16 .. 17;
      BACKUP_BUS_PMS_CONSTRAIN_BACKUP     at 0 range 18 .. 19;
      Reserved_20_21                      at 0 range 20 .. 21;
      BACKUP_BUS_PMS_CONSTRAIN_BB         at 0 range 22 .. 23;
      BACKUP_BUS_PMS_CONSTRAIN_PWM0       at 0 range 24 .. 25;
      BACKUP_BUS_PMS_CONSTRAIN_TIMERGROUP at 0 range 26 .. 29;
      BACKUP_BUS_PMS_CONSTRAIN_SYSTIMER   at 0 range 30 .. 31;
   end record;

   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_SPI_2_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_SPI_3_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_APB_CTRL_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_I2C_EXT1_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_SDIO_HOST_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_CAN_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_PWM1_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_I2S1_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_UART2_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_RWBT_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_WIFIMAC_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_PWR_Field is
     ESP32S3_Registers.UInt2;

   --  BackUp access peripherals permission configuration register 3.
   type BACKUP_BUS_PMS_CONSTRAIN_3_Register is record
      --  BackUp access spi_2 permission.
      BACKUP_BUS_PMS_CONSTRAIN_SPI_2     : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_SPI_2_Field :=
                                            16#3#;
      --  BackUp access spi_3 permission.
      BACKUP_BUS_PMS_CONSTRAIN_SPI_3     : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_SPI_3_Field :=
                                            16#3#;
      --  BackUp access apb_ctrl permission.
      BACKUP_BUS_PMS_CONSTRAIN_APB_CTRL  : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_APB_CTRL_Field :=
                                            16#3#;
      --  BackUp access i2c_ext1 permission.
      BACKUP_BUS_PMS_CONSTRAIN_I2C_EXT1  : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_I2C_EXT1_Field :=
                                            16#3#;
      --  BackUp access sdio_host permission.
      BACKUP_BUS_PMS_CONSTRAIN_SDIO_HOST : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_SDIO_HOST_Field :=
                                            16#3#;
      --  BackUp access can permission.
      BACKUP_BUS_PMS_CONSTRAIN_CAN       : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_CAN_Field :=
                                            16#3#;
      --  BackUp access pwm1 permission.
      BACKUP_BUS_PMS_CONSTRAIN_PWM1      : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_PWM1_Field :=
                                            16#3#;
      --  BackUp access i2s1 permission.
      BACKUP_BUS_PMS_CONSTRAIN_I2S1      : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_I2S1_Field :=
                                            16#3#;
      --  BackUp access uart2 permission.
      BACKUP_BUS_PMS_CONSTRAIN_UART2     : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_UART2_Field :=
                                            16#3#;
      --  unspecified
      Reserved_18_21                     : ESP32S3_Registers.UInt4 := 16#0#;
      --  BackUp access rwbt permission.
      BACKUP_BUS_PMS_CONSTRAIN_RWBT      : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_RWBT_Field :=
                                            16#3#;
      --  unspecified
      Reserved_24_25                     : ESP32S3_Registers.UInt2 := 16#0#;
      --  BackUp access wifimac permission.
      BACKUP_BUS_PMS_CONSTRAIN_WIFIMAC   : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_WIFIMAC_Field :=
                                            16#3#;
      --  BackUp access pwr permission.
      BACKUP_BUS_PMS_CONSTRAIN_PWR       : BACKUP_BUS_PMS_CONSTRAIN_3_BACKUP_BUS_PMS_CONSTRAIN_PWR_Field :=
                                            16#3#;
      --  unspecified
      Reserved_30_31                     : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_CONSTRAIN_3_Register use record
      BACKUP_BUS_PMS_CONSTRAIN_SPI_2     at 0 range 0 .. 1;
      BACKUP_BUS_PMS_CONSTRAIN_SPI_3     at 0 range 2 .. 3;
      BACKUP_BUS_PMS_CONSTRAIN_APB_CTRL  at 0 range 4 .. 5;
      BACKUP_BUS_PMS_CONSTRAIN_I2C_EXT1  at 0 range 6 .. 7;
      BACKUP_BUS_PMS_CONSTRAIN_SDIO_HOST at 0 range 8 .. 9;
      BACKUP_BUS_PMS_CONSTRAIN_CAN       at 0 range 10 .. 11;
      BACKUP_BUS_PMS_CONSTRAIN_PWM1      at 0 range 12 .. 13;
      BACKUP_BUS_PMS_CONSTRAIN_I2S1      at 0 range 14 .. 15;
      BACKUP_BUS_PMS_CONSTRAIN_UART2     at 0 range 16 .. 17;
      Reserved_18_21                     at 0 range 18 .. 21;
      BACKUP_BUS_PMS_CONSTRAIN_RWBT      at 0 range 22 .. 23;
      Reserved_24_25                     at 0 range 24 .. 25;
      BACKUP_BUS_PMS_CONSTRAIN_WIFIMAC   at 0 range 26 .. 27;
      BACKUP_BUS_PMS_CONSTRAIN_PWR       at 0 range 28 .. 29;
      Reserved_30_31                     at 0 range 30 .. 31;
   end record;

   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_USB_DEVICE_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_USB_WRAP_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_CRYPTO_PERI_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_CRYPTO_DMA_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_APB_ADC_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_LCD_CAM_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_BT_PWR_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_USB_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_SYSTEM_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_SENSITIVE_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_INTERRUPT_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_DMA_COPY_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_CACHE_CONFIG_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_AD_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_DIO_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_WORLD_CONTROLLER_Field is
     ESP32S3_Registers.UInt2;

   --  BackUp access peripherals permission configuration register 4.
   type BACKUP_BUS_PMS_CONSTRAIN_4_Register is record
      --  BackUp access usb_device permission.
      BACKUP_BUS_PMS_CONSTRAIN_USB_DEVICE       : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_USB_DEVICE_Field :=
                                                   16#3#;
      --  BackUp access usb_wrap permission.
      BACKUP_BUS_PMS_CONSTRAIN_USB_WRAP         : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_USB_WRAP_Field :=
                                                   16#3#;
      --  BackUp access crypto_peri permission.
      BACKUP_BUS_PMS_CONSTRAIN_CRYPTO_PERI      : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_CRYPTO_PERI_Field :=
                                                   16#3#;
      --  BackUp access crypto_dma permission.
      BACKUP_BUS_PMS_CONSTRAIN_CRYPTO_DMA       : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_CRYPTO_DMA_Field :=
                                                   16#3#;
      --  BackUp access apb_adc permission.
      BACKUP_BUS_PMS_CONSTRAIN_APB_ADC          : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_APB_ADC_Field :=
                                                   16#3#;
      --  BackUp access lcd_cam permission.
      BACKUP_BUS_PMS_CONSTRAIN_LCD_CAM          : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_LCD_CAM_Field :=
                                                   16#3#;
      --  BackUp access bt_pwr permission.
      BACKUP_BUS_PMS_CONSTRAIN_BT_PWR           : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_BT_PWR_Field :=
                                                   16#3#;
      --  BackUp access usb permission.
      BACKUP_BUS_PMS_CONSTRAIN_USB              : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_USB_Field :=
                                                   16#3#;
      --  BackUp access system permission.
      BACKUP_BUS_PMS_CONSTRAIN_SYSTEM           : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_SYSTEM_Field :=
                                                   16#3#;
      --  BackUp access sensitive permission.
      BACKUP_BUS_PMS_CONSTRAIN_SENSITIVE        : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_SENSITIVE_Field :=
                                                   16#3#;
      --  BackUp access interrupt permission.
      BACKUP_BUS_PMS_CONSTRAIN_INTERRUPT        : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_INTERRUPT_Field :=
                                                   16#3#;
      --  BackUp access dma_copy permission.
      BACKUP_BUS_PMS_CONSTRAIN_DMA_COPY         : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_DMA_COPY_Field :=
                                                   16#3#;
      --  BackUp access cache_config permission.
      BACKUP_BUS_PMS_CONSTRAIN_CACHE_CONFIG     : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_CACHE_CONFIG_Field :=
                                                   16#3#;
      --  BackUp access ad permission.
      BACKUP_BUS_PMS_CONSTRAIN_AD               : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_AD_Field :=
                                                   16#3#;
      --  BackUp access dio permission.
      BACKUP_BUS_PMS_CONSTRAIN_DIO              : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_DIO_Field :=
                                                   16#3#;
      --  BackUp access world_controller permission.
      BACKUP_BUS_PMS_CONSTRAIN_WORLD_CONTROLLER : BACKUP_BUS_PMS_CONSTRAIN_4_BACKUP_BUS_PMS_CONSTRAIN_WORLD_CONTROLLER_Field :=
                                                   16#3#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_CONSTRAIN_4_Register use record
      BACKUP_BUS_PMS_CONSTRAIN_USB_DEVICE       at 0 range 0 .. 1;
      BACKUP_BUS_PMS_CONSTRAIN_USB_WRAP         at 0 range 2 .. 3;
      BACKUP_BUS_PMS_CONSTRAIN_CRYPTO_PERI      at 0 range 4 .. 5;
      BACKUP_BUS_PMS_CONSTRAIN_CRYPTO_DMA       at 0 range 6 .. 7;
      BACKUP_BUS_PMS_CONSTRAIN_APB_ADC          at 0 range 8 .. 9;
      BACKUP_BUS_PMS_CONSTRAIN_LCD_CAM          at 0 range 10 .. 11;
      BACKUP_BUS_PMS_CONSTRAIN_BT_PWR           at 0 range 12 .. 13;
      BACKUP_BUS_PMS_CONSTRAIN_USB              at 0 range 14 .. 15;
      BACKUP_BUS_PMS_CONSTRAIN_SYSTEM           at 0 range 16 .. 17;
      BACKUP_BUS_PMS_CONSTRAIN_SENSITIVE        at 0 range 18 .. 19;
      BACKUP_BUS_PMS_CONSTRAIN_INTERRUPT        at 0 range 20 .. 21;
      BACKUP_BUS_PMS_CONSTRAIN_DMA_COPY         at 0 range 22 .. 23;
      BACKUP_BUS_PMS_CONSTRAIN_CACHE_CONFIG     at 0 range 24 .. 25;
      BACKUP_BUS_PMS_CONSTRAIN_AD               at 0 range 26 .. 27;
      BACKUP_BUS_PMS_CONSTRAIN_DIO              at 0 range 28 .. 29;
      BACKUP_BUS_PMS_CONSTRAIN_WORLD_CONTROLLER at 0 range 30 .. 31;
   end record;

   subtype BACKUP_BUS_PMS_CONSTRAIN_5_BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_SPLTADDR_Field is
     ESP32S3_Registers.UInt11;

   --  BackUp access peripherals permission configuration register 5.
   type BACKUP_BUS_PMS_CONSTRAIN_5_Register is record
      --  BackUp access rtcfast_spltaddr permission.
      BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_SPLTADDR : BACKUP_BUS_PMS_CONSTRAIN_5_BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_SPLTADDR_Field :=
                                                   16#7FF#;
      --  unspecified
      Reserved_11_31                            : ESP32S3_Registers.UInt21 :=
                                                   16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_CONSTRAIN_5_Register use record
      BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_SPLTADDR at 0 range 0 .. 10;
      Reserved_11_31                            at 0 range 11 .. 31;
   end record;

   subtype BACKUP_BUS_PMS_CONSTRAIN_6_BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_L_Field is
     ESP32S3_Registers.UInt3;
   subtype BACKUP_BUS_PMS_CONSTRAIN_6_BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_H_Field is
     ESP32S3_Registers.UInt3;

   --  BackUp access peripherals permission configuration register 6.
   type BACKUP_BUS_PMS_CONSTRAIN_6_Register is record
      --  BackUp access rtcfast_l permission.
      BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_L : BACKUP_BUS_PMS_CONSTRAIN_6_BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_L_Field :=
                                            16#7#;
      --  BackUp access rtcfast_h permission.
      BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_H : BACKUP_BUS_PMS_CONSTRAIN_6_BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_H_Field :=
                                            16#7#;
      --  unspecified
      Reserved_6_31                      : ESP32S3_Registers.UInt26 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_CONSTRAIN_6_Register use record
      BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_L at 0 range 0 .. 2;
      BACKUP_BUS_PMS_CONSTRAIN_RTCFAST_H at 0 range 3 .. 5;
      Reserved_6_31                      at 0 range 6 .. 31;
   end record;

   --  BackUp permission report register 0.
   type BACKUP_BUS_PMS_MONITOR_0_Register is record
      --  Set 1 to lock BackUp permission report registers.
      BACKUP_BUS_PMS_MONITOR_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31               : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_MONITOR_0_Register use record
      BACKUP_BUS_PMS_MONITOR_LOCK at 0 range 0 .. 0;
      Reserved_1_31               at 0 range 1 .. 31;
   end record;

   --  BackUp permission report register 1.
   type BACKUP_BUS_PMS_MONITOR_1_Register is record
      --  Set 1 to clear interrupt that BackUp initiate illegal access.
      BACKUP_BUS_PMS_MONITOR_VIOLATE_CLR : Boolean := True;
      --  Set 1 to enable interrupt that BackUp initiate illegal access.
      BACKUP_BUS_PMS_MONITOR_VIOLATE_EN  : Boolean := True;
      --  unspecified
      Reserved_2_31                      : ESP32S3_Registers.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_MONITOR_1_Register use record
      BACKUP_BUS_PMS_MONITOR_VIOLATE_CLR at 0 range 0 .. 0;
      BACKUP_BUS_PMS_MONITOR_VIOLATE_EN  at 0 range 1 .. 1;
      Reserved_2_31                      at 0 range 2 .. 31;
   end record;

   subtype BACKUP_BUS_PMS_MONITOR_2_BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HTRANS_Field is
     ESP32S3_Registers.UInt2;
   subtype BACKUP_BUS_PMS_MONITOR_2_BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HSIZE_Field is
     ESP32S3_Registers.UInt3;

   --  BackUp permission report register 2.
   type BACKUP_BUS_PMS_MONITOR_2_Register is record
      --  Read-only. Record BackUp illegal access interrupt state.
      BACKUP_BUS_PMS_MONITOR_VIOLATE_INTR          : Boolean;
      --  Read-only. Record htrans when BackUp initate illegal access.
      BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HTRANS : BACKUP_BUS_PMS_MONITOR_2_BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HTRANS_Field;
      --  Read-only. Record access type when BackUp initate illegal access.
      BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HSIZE  : BACKUP_BUS_PMS_MONITOR_2_BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HSIZE_Field;
      --  Read-only. Record access direction when BackUp initiate illegal
      --  access.
      BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HWRITE : Boolean;
      --  unspecified
      Reserved_7_31                                : ESP32S3_Registers.UInt25;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BACKUP_BUS_PMS_MONITOR_2_Register use record
      BACKUP_BUS_PMS_MONITOR_VIOLATE_INTR          at 0 range 0 .. 0;
      BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HTRANS at 0 range 1 .. 2;
      BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HSIZE  at 0 range 3 .. 5;
      BACKUP_BUS_PMS_MONITOR_VIOLATE_STATUS_HWRITE at 0 range 6 .. 6;
      Reserved_7_31                                at 0 range 7 .. 31;
   end record;

   --  EDMA boundary lock register.
   type EDMA_BOUNDARY_LOCK_Register is record
      --  Set 1 to lock EDMA boundary registers.
      EDMA_BOUNDARY_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_BOUNDARY_LOCK_Register use record
      EDMA_BOUNDARY_LOCK at 0 range 0 .. 0;
      Reserved_1_31      at 0 range 1 .. 31;
   end record;

   subtype EDMA_BOUNDARY_0_EDMA_BOUNDARY_0_Field is ESP32S3_Registers.UInt14;

   --  EDMA boundary 0 configuration
   type EDMA_BOUNDARY_0_Register is record
      --  This field is used to configure the boundary 0 of external RAM. The
      --  unit is 4K. For example, set this field to 0x80, then the address
      --  boundary 0 would be 0x3C080000 (0x3C000000 + 0x80 * 4K).
      EDMA_BOUNDARY_0 : EDMA_BOUNDARY_0_EDMA_BOUNDARY_0_Field := 16#0#;
      --  unspecified
      Reserved_14_31  : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_BOUNDARY_0_Register use record
      EDMA_BOUNDARY_0 at 0 range 0 .. 13;
      Reserved_14_31  at 0 range 14 .. 31;
   end record;

   subtype EDMA_BOUNDARY_1_EDMA_BOUNDARY_1_Field is ESP32S3_Registers.UInt14;

   --  EDMA boundary 1 configuration
   type EDMA_BOUNDARY_1_Register is record
      --  This field is used to configure the boundary 1 of external RAM. The
      --  unit is 4K. For example, set this field to 0x80, then the address
      --  boundary 0 would be 0x3C080000 (0x3C000000 + 0x80 * 4K).
      EDMA_BOUNDARY_1 : EDMA_BOUNDARY_1_EDMA_BOUNDARY_1_Field := 16#2000#;
      --  unspecified
      Reserved_14_31  : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_BOUNDARY_1_Register use record
      EDMA_BOUNDARY_1 at 0 range 0 .. 13;
      Reserved_14_31  at 0 range 14 .. 31;
   end record;

   subtype EDMA_BOUNDARY_2_EDMA_BOUNDARY_2_Field is ESP32S3_Registers.UInt14;

   --  EDMA boundary 2 configuration
   type EDMA_BOUNDARY_2_Register is record
      --  This field is used to configure the boundary 2 of external RAM. The
      --  unit is 4K. For example, set this field to 0x80, then the address
      --  boundary 0 would be 0x3C080000 (0x3C000000 + 0x80 * 4K).
      EDMA_BOUNDARY_2 : EDMA_BOUNDARY_2_EDMA_BOUNDARY_2_Field := 16#2000#;
      --  unspecified
      Reserved_14_31  : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_BOUNDARY_2_Register use record
      EDMA_BOUNDARY_2 at 0 range 0 .. 13;
      Reserved_14_31  at 0 range 14 .. 31;
   end record;

   --  EDMA-SPI2 permission lock register.
   type EDMA_PMS_SPI2_LOCK_Register is record
      --  Set 1 to lock EDMA-SPI2 permission control registers.
      EDMA_PMS_SPI2_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_SPI2_LOCK_Register use record
      EDMA_PMS_SPI2_LOCK at 0 range 0 .. 0;
      Reserved_1_31      at 0 range 1 .. 31;
   end record;

   --  EDMA_PMS_SPI_ATTR array element
   subtype EDMA_PMS_SPI_ATTR_Element is ESP32S3_Registers.UInt2;

   --  EDMA_PMS_SPI_ATTR array
   type EDMA_PMS_SPI_ATTR_Field_Array is array (1 .. 2)
     of EDMA_PMS_SPI_ATTR_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for EDMA_PMS_SPI_ATTR
   type EDMA_PMS_SPI_ATTR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ATTR as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  ATTR as an array
            Arr : EDMA_PMS_SPI_ATTR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for EDMA_PMS_SPI_ATTR_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  EDMA-SPI2 permission control register.
   type EDMA_PMS_SPI_Register is record
      --  This field is used to configure the permission of SPI2 accessing
      --  address, which is larger than boundary 0 and less than boundary 1,
      --  through EDMA. Bit 0: set this bit to enable read permission. Bit 1:
      --  set this bit to enable write permission.
      ATTR          : EDMA_PMS_SPI_ATTR_Field :=
                       (As_Array => False, Val => 16#3#);
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_SPI_Register use record
      ATTR          at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   --  EDMA-SPI3 permission lock register.
   type EDMA_PMS_SPI3_LOCK_Register is record
      --  Set 1 to lock EDMA-SPI3 permission control registers.
      EDMA_PMS_SPI3_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_SPI3_LOCK_Register use record
      EDMA_PMS_SPI3_LOCK at 0 range 0 .. 0;
      Reserved_1_31      at 0 range 1 .. 31;
   end record;

   --  EDMA-UHCI0 permission lock register.
   type EDMA_PMS_UHCI0_LOCK_Register is record
      --  Set 1 to lock EDMA-UHCI0 permission control registers.
      EDMA_PMS_UHCI0_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_UHCI0_LOCK_Register use record
      EDMA_PMS_UHCI0_LOCK at 0 range 0 .. 0;
      Reserved_1_31       at 0 range 1 .. 31;
   end record;

   --  EDMA_PMS_UHCI0_ATTR array element
   subtype EDMA_PMS_UHCI0_ATTR_Element is ESP32S3_Registers.UInt2;

   --  EDMA_PMS_UHCI0_ATTR array
   type EDMA_PMS_UHCI0_ATTR_Field_Array is array (1 .. 2)
     of EDMA_PMS_UHCI0_ATTR_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for EDMA_PMS_UHCI0_ATTR
   type EDMA_PMS_UHCI0_ATTR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ATTR as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  ATTR as an array
            Arr : EDMA_PMS_UHCI0_ATTR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for EDMA_PMS_UHCI0_ATTR_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  EDMA-UHCI0 permission control register.
   type EDMA_PMS_UHCI0_Register is record
      --  This field is used to configure the permission of UHCI0 accessing
      --  address, which is larger than boundary 0 and less than boundary 1,
      --  through EDMA. Bit 0: set this bit to enable read permission. Bit 1:
      --  set this bit to enable write permission.
      ATTR          : EDMA_PMS_UHCI0_ATTR_Field :=
                       (As_Array => False, Val => 16#3#);
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_UHCI0_Register use record
      ATTR          at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   --  EDMA-I2S0 permission lock register.
   type EDMA_PMS_I2S0_LOCK_Register is record
      --  Set 1 to lock EDMA-I2S0 permission control registers.
      EDMA_PMS_I2S0_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_I2S0_LOCK_Register use record
      EDMA_PMS_I2S0_LOCK at 0 range 0 .. 0;
      Reserved_1_31      at 0 range 1 .. 31;
   end record;

   --  EDMA_PMS_I2S_ATTR array element
   subtype EDMA_PMS_I2S_ATTR_Element is ESP32S3_Registers.UInt2;

   --  EDMA_PMS_I2S_ATTR array
   type EDMA_PMS_I2S_ATTR_Field_Array is array (1 .. 2)
     of EDMA_PMS_I2S_ATTR_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for EDMA_PMS_I2S_ATTR
   type EDMA_PMS_I2S_ATTR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ATTR as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  ATTR as an array
            Arr : EDMA_PMS_I2S_ATTR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for EDMA_PMS_I2S_ATTR_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  EDMA-I2S0 permission control register.
   type EDMA_PMS_I2S_Register is record
      --  This field is used to configure the permission of I2S0 accessing
      --  address, which is larger than boundary 0 and less than boundary 1,
      --  through EDMA. Bit 0: set this bit to enable read permission. Bit 1:
      --  set this bit to enable write permission.
      ATTR          : EDMA_PMS_I2S_ATTR_Field :=
                       (As_Array => False, Val => 16#3#);
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_I2S_Register use record
      ATTR          at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   --  EDMA-I2S1 permission lock register.
   type EDMA_PMS_I2S1_LOCK_Register is record
      --  Set 1 to lock EDMA-I2S1 permission control registers.
      EDMA_PMS_I2S1_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31      : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_I2S1_LOCK_Register use record
      EDMA_PMS_I2S1_LOCK at 0 range 0 .. 0;
      Reserved_1_31      at 0 range 1 .. 31;
   end record;

   --  EDMA-LCD/CAM permission lock register.
   type EDMA_PMS_LCD_CAM_LOCK_Register is record
      --  Set 1 to lock EDMA-LCD/CAM permission control registers.
      EDMA_PMS_LCD_CAM_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31         : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_LCD_CAM_LOCK_Register use record
      EDMA_PMS_LCD_CAM_LOCK at 0 range 0 .. 0;
      Reserved_1_31         at 0 range 1 .. 31;
   end record;

   --  EDMA_PMS_LCD_CAM_ATTR array element
   subtype EDMA_PMS_LCD_CAM_ATTR_Element is ESP32S3_Registers.UInt2;

   --  EDMA_PMS_LCD_CAM_ATTR array
   type EDMA_PMS_LCD_CAM_ATTR_Field_Array is array (1 .. 2)
     of EDMA_PMS_LCD_CAM_ATTR_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for EDMA_PMS_LCD_CAM_ATTR
   type EDMA_PMS_LCD_CAM_ATTR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ATTR as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  ATTR as an array
            Arr : EDMA_PMS_LCD_CAM_ATTR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for EDMA_PMS_LCD_CAM_ATTR_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  EDMA-LCD/CAM permission control register.
   type EDMA_PMS_LCD_CAM_Register is record
      --  This field is used to configure the permission of LCD/CAM accessing
      --  address, which is larger than boundary 0 and less than boundary 1,
      --  through EDMA. Bit 0: set this bit to enable read permission. Bit 1:
      --  set this bit to enable write permission.
      ATTR          : EDMA_PMS_LCD_CAM_ATTR_Field :=
                       (As_Array => False, Val => 16#3#);
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_LCD_CAM_Register use record
      ATTR          at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   --  EDMA-AES permission lock register.
   type EDMA_PMS_AES_LOCK_Register is record
      --  Set 1 to lock EDMA-AES permission control registers.
      EDMA_PMS_AES_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31     : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_AES_LOCK_Register use record
      EDMA_PMS_AES_LOCK at 0 range 0 .. 0;
      Reserved_1_31     at 0 range 1 .. 31;
   end record;

   --  EDMA_PMS_AES_ATTR array element
   subtype EDMA_PMS_AES_ATTR_Element is ESP32S3_Registers.UInt2;

   --  EDMA_PMS_AES_ATTR array
   type EDMA_PMS_AES_ATTR_Field_Array is array (1 .. 2)
     of EDMA_PMS_AES_ATTR_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for EDMA_PMS_AES_ATTR
   type EDMA_PMS_AES_ATTR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ATTR as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  ATTR as an array
            Arr : EDMA_PMS_AES_ATTR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for EDMA_PMS_AES_ATTR_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  EDMA-AES permission control register.
   type EDMA_PMS_AES_Register is record
      --  This field is used to configure the permission of AES accessing
      --  address, which is larger than boundary 0 and less than boundary 1,
      --  through EDMA. Bit 0: set this bit to enable read permission. Bit 1:
      --  set this bit to enable write permission.
      ATTR          : EDMA_PMS_AES_ATTR_Field :=
                       (As_Array => False, Val => 16#3#);
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_AES_Register use record
      ATTR          at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   --  EDMA-SHA permission lock register.
   type EDMA_PMS_SHA_LOCK_Register is record
      --  Set 1 to lock EDMA-SHA permission control registers.
      EDMA_PMS_SHA_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31     : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_SHA_LOCK_Register use record
      EDMA_PMS_SHA_LOCK at 0 range 0 .. 0;
      Reserved_1_31     at 0 range 1 .. 31;
   end record;

   --  EDMA_PMS_SHA_ATTR array element
   subtype EDMA_PMS_SHA_ATTR_Element is ESP32S3_Registers.UInt2;

   --  EDMA_PMS_SHA_ATTR array
   type EDMA_PMS_SHA_ATTR_Field_Array is array (1 .. 2)
     of EDMA_PMS_SHA_ATTR_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for EDMA_PMS_SHA_ATTR
   type EDMA_PMS_SHA_ATTR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ATTR as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  ATTR as an array
            Arr : EDMA_PMS_SHA_ATTR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for EDMA_PMS_SHA_ATTR_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  EDMA-SHA permission control register.
   type EDMA_PMS_SHA_Register is record
      --  This field is used to configure the permission of SHA accessing
      --  address, which is larger than boundary 0 and less than boundary 1,
      --  through EDMA. Bit 0: set this bit to enable read permission. Bit 1:
      --  set this bit to enable write permission.
      ATTR          : EDMA_PMS_SHA_ATTR_Field :=
                       (As_Array => False, Val => 16#3#);
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_SHA_Register use record
      ATTR          at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   --  EDMA-ADC/DAC permission lock register.
   type EDMA_PMS_ADC_DAC_LOCK_Register is record
      --  Set 1 to lock EDMA-ADC/DAC permission control registers.
      EDMA_PMS_ADC_DAC_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31         : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_ADC_DAC_LOCK_Register use record
      EDMA_PMS_ADC_DAC_LOCK at 0 range 0 .. 0;
      Reserved_1_31         at 0 range 1 .. 31;
   end record;

   --  EDMA_PMS_ADC_DAC_ATTR array element
   subtype EDMA_PMS_ADC_DAC_ATTR_Element is ESP32S3_Registers.UInt2;

   --  EDMA_PMS_ADC_DAC_ATTR array
   type EDMA_PMS_ADC_DAC_ATTR_Field_Array is array (1 .. 2)
     of EDMA_PMS_ADC_DAC_ATTR_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for EDMA_PMS_ADC_DAC_ATTR
   type EDMA_PMS_ADC_DAC_ATTR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ATTR as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  ATTR as an array
            Arr : EDMA_PMS_ADC_DAC_ATTR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for EDMA_PMS_ADC_DAC_ATTR_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  EDMA-ADC/DAC permission control register.
   type EDMA_PMS_ADC_DAC_Register is record
      --  This field is used to configure the permission of ADC/DAC accessing
      --  address, which is larger than boundary 0 and less than boundary 1,
      --  through EDMA. Bit 0: set this bit to enable read permission. Bit 1:
      --  set this bit to enable write permission.
      ATTR          : EDMA_PMS_ADC_DAC_ATTR_Field :=
                       (As_Array => False, Val => 16#3#);
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_ADC_DAC_Register use record
      ATTR          at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   --  EDMA-RMT permission lock register.
   type EDMA_PMS_RMT_LOCK_Register is record
      --  Set 1 to lock EDMA-RMT permission control registers.
      EDMA_PMS_RMT_LOCK : Boolean := False;
      --  unspecified
      Reserved_1_31     : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_RMT_LOCK_Register use record
      EDMA_PMS_RMT_LOCK at 0 range 0 .. 0;
      Reserved_1_31     at 0 range 1 .. 31;
   end record;

   --  EDMA_PMS_RMT_ATTR array element
   subtype EDMA_PMS_RMT_ATTR_Element is ESP32S3_Registers.UInt2;

   --  EDMA_PMS_RMT_ATTR array
   type EDMA_PMS_RMT_ATTR_Field_Array is array (1 .. 2)
     of EDMA_PMS_RMT_ATTR_Element
     with Component_Size => 2, Size => 4;

   --  Type definition for EDMA_PMS_RMT_ATTR
   type EDMA_PMS_RMT_ATTR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ATTR as a value
            Val : ESP32S3_Registers.UInt4;
         when True =>
            --  ATTR as an array
            Arr : EDMA_PMS_RMT_ATTR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 4;

   for EDMA_PMS_RMT_ATTR_Field use record
      Val at 0 range 0 .. 3;
      Arr at 0 range 0 .. 3;
   end record;

   --  EDMA-RMT permission control register.
   type EDMA_PMS_RMT_Register is record
      --  This field is used to configure the permission of RMT accessing
      --  address, which is larger than boundary 0 and less than boundary 1,
      --  through EDMA. Bit 0: set this bit to enable read permission. Bit 1:
      --  set this bit to enable write permission.
      ATTR          : EDMA_PMS_RMT_ATTR_Field :=
                       (As_Array => False, Val => 16#3#);
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EDMA_PMS_RMT_Register use record
      ATTR          at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   --  Sensitive module clock gate configuration register.
   type CLOCK_GATE_Register is record
      --  Set 1 to enable clock gate function.
      REG_CLK_EN    : Boolean := True;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLOCK_GATE_Register use record
      REG_CLK_EN    at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  RTC coprocessor permission register.
   type RTC_PMS_Register is record
      --  Set 1 to disable rtc coprocessor.
      DIS_RTC_CPU   : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RTC_PMS_Register use record
      DIS_RTC_CPU   at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt28;

   --  Sensitive version register.
   type DATE_Register is record
      --  Sensitive Date register.
      DATE           : DATE_DATE_Field := 16#2101280#;
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

   --  SENSITIVE Peripheral
   type SENSITIVE_Peripheral is record
      --  Cache data array configuration register 0.
      CACHE_DATAARRAY_CONNECT_0                     : aliased CACHE_DATAARRAY_CONNECT_0_Register;
      --  Cache data array configuration register 1.
      CACHE_DATAARRAY_CONNECT_1                     : aliased CACHE_DATAARRAY_CONNECT_1_Register;
      --  APB peripheral configuration register 0.
      APB_PERIPHERAL_ACCESS_0                       : aliased APB_PERIPHERAL_ACCESS_0_Register;
      --  APB peripheral configuration register 1.
      APB_PERIPHERAL_ACCESS_1                       : aliased APB_PERIPHERAL_ACCESS_1_Register;
      --  Internal SRAM configuration register 0.
      INTERNAL_SRAM_USAGE_0                         : aliased INTERNAL_SRAM_USAGE_0_Register;
      --  Internal SRAM configuration register 1.
      INTERNAL_SRAM_USAGE_1                         : aliased INTERNAL_SRAM_USAGE_1_Register;
      --  Internal SRAM configuration register 2.
      INTERNAL_SRAM_USAGE_2                         : aliased INTERNAL_SRAM_USAGE_2_Register;
      --  Internal SRAM configuration register 3.
      INTERNAL_SRAM_USAGE_3                         : aliased INTERNAL_SRAM_USAGE_3_Register;
      --  Internal SRAM configuration register 4.
      INTERNAL_SRAM_USAGE_4                         : aliased INTERNAL_SRAM_USAGE_4_Register;
      --  Retention configuration register.
      RETENTION_DISABLE                             : aliased RETENTION_DISABLE_Register;
      --  Cache tag configuration register 0.
      CACHE_TAG_ACCESS_0                            : aliased CACHE_TAG_ACCESS_0_Register;
      --  Cache tag configuration register 1.
      CACHE_TAG_ACCESS_1                            : aliased CACHE_TAG_ACCESS_1_Register;
      --  Cache MMU configuration register 0.
      CACHE_MMU_ACCESS_0                            : aliased CACHE_MMU_ACCESS_0_Register;
      --  Cache MMU configuration register 1.
      CACHE_MMU_ACCESS_1                            : aliased CACHE_MMU_ACCESS_1_Register;
      --  spi2 dma permission configuration register 0.
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_0              : aliased DMA_APBPERI_SPI2_PMS_CONSTRAIN_0_Register;
      --  spi2 dma permission configuration register 1.
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_1              : aliased DMA_APBPERI_SPI2_PMS_CONSTRAIN_1_Register;
      --  spi3 dma permission configuration register 0.
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_0              : aliased DMA_APBPERI_SPI3_PMS_CONSTRAIN_0_Register;
      --  spi3 dma permission configuration register 1.
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_1              : aliased DMA_APBPERI_SPI3_PMS_CONSTRAIN_1_Register;
      --  uhci0 dma permission configuration register 0.
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_0             : aliased DMA_APBPERI_UHCI0_PMS_CONSTRAIN_0_Register;
      --  uhci0 dma permission configuration register 1.
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1             : aliased DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1_Register;
      --  i2s0 dma permission configuration register 0.
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_0              : aliased DMA_APBPERI_I2S0_PMS_CONSTRAIN_0_Register;
      --  i2s0 dma permission configuration register 1.
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_1              : aliased DMA_APBPERI_I2S0_PMS_CONSTRAIN_1_Register;
      --  i2s1 dma permission configuration register 0.
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_0              : aliased DMA_APBPERI_I2S1_PMS_CONSTRAIN_0_Register;
      --  i2s1 dma permission configuration register 1.
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_1              : aliased DMA_APBPERI_I2S1_PMS_CONSTRAIN_1_Register;
      --  mac dma permission configuration register 0.
      DMA_APBPERI_MAC_PMS_CONSTRAIN_0               : aliased DMA_APBPERI_MAC_PMS_CONSTRAIN_0_Register;
      --  mac dma permission configuration register 1.
      DMA_APBPERI_MAC_PMS_CONSTRAIN_1               : aliased DMA_APBPERI_MAC_PMS_CONSTRAIN_1_Register;
      --  backup dma permission configuration register 0.
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_0            : aliased DMA_APBPERI_BACKUP_PMS_CONSTRAIN_0_Register;
      --  backup dma permission configuration register 1.
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1            : aliased DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1_Register;
      --  aes dma permission configuration register 0.
      DMA_APBPERI_AES_PMS_CONSTRAIN_0               : aliased DMA_APBPERI_AES_PMS_CONSTRAIN_0_Register;
      --  aes dma permission configuration register 1.
      DMA_APBPERI_AES_PMS_CONSTRAIN_1               : aliased DMA_APBPERI_AES_PMS_CONSTRAIN_1_Register;
      --  sha dma permission configuration register 0.
      DMA_APBPERI_SHA_PMS_CONSTRAIN_0               : aliased DMA_APBPERI_SHA_PMS_CONSTRAIN_0_Register;
      --  sha dma permission configuration register 1.
      DMA_APBPERI_SHA_PMS_CONSTRAIN_1               : aliased DMA_APBPERI_SHA_PMS_CONSTRAIN_1_Register;
      --  adc_dac dma permission configuration register 0.
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_0           : aliased DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_0_Register;
      --  adc_dac dma permission configuration register 1.
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1           : aliased DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1_Register;
      --  rmt dma permission configuration register 0.
      DMA_APBPERI_RMT_PMS_CONSTRAIN_0               : aliased DMA_APBPERI_RMT_PMS_CONSTRAIN_0_Register;
      --  rmt dma permission configuration register 1.
      DMA_APBPERI_RMT_PMS_CONSTRAIN_1               : aliased DMA_APBPERI_RMT_PMS_CONSTRAIN_1_Register;
      --  lcd_cam dma permission configuration register 0.
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_0           : aliased DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_0_Register;
      --  lcd_cam dma permission configuration register 1.
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1           : aliased DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1_Register;
      --  usb dma permission configuration register 0.
      DMA_APBPERI_USB_PMS_CONSTRAIN_0               : aliased DMA_APBPERI_USB_PMS_CONSTRAIN_0_Register;
      --  usb dma permission configuration register 1.
      DMA_APBPERI_USB_PMS_CONSTRAIN_1               : aliased DMA_APBPERI_USB_PMS_CONSTRAIN_1_Register;
      --  lc dma permission configuration register 0.
      DMA_APBPERI_LC_PMS_CONSTRAIN_0                : aliased DMA_APBPERI_LC_PMS_CONSTRAIN_0_Register;
      --  lc dma permission configuration register 1.
      DMA_APBPERI_LC_PMS_CONSTRAIN_1                : aliased DMA_APBPERI_LC_PMS_CONSTRAIN_1_Register;
      --  sdio dma permission configuration register 0.
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_0              : aliased DMA_APBPERI_SDIO_PMS_CONSTRAIN_0_Register;
      --  sdio dma permission configuration register 1.
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_1              : aliased DMA_APBPERI_SDIO_PMS_CONSTRAIN_1_Register;
      --  dma permission monitor configuration register 0.
      DMA_APBPERI_PMS_MONITOR_0                     : aliased DMA_APBPERI_PMS_MONITOR_0_Register;
      --  dma permission monitor configuration register 1.
      DMA_APBPERI_PMS_MONITOR_1                     : aliased DMA_APBPERI_PMS_MONITOR_1_Register;
      --  dma permission monitor configuration register 2.
      DMA_APBPERI_PMS_MONITOR_2                     : aliased DMA_APBPERI_PMS_MONITOR_2_Register;
      --  dma permission monitor configuration register 3.
      DMA_APBPERI_PMS_MONITOR_3                     : aliased DMA_APBPERI_PMS_MONITOR_3_Register;
      --  sram split line configuration register 0
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_0 : aliased CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_0_Register;
      --  sram split line configuration register 1
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1 : aliased CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1_Register;
      --  sram split line configuration register 1
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2 : aliased CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2_Register;
      --  sram split line configuration register 1
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3 : aliased CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3_Register;
      --  sram split line configuration register 1
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4 : aliased CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4_Register;
      --  sram split line configuration register 1
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5 : aliased CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5_Register;
      --  corex iram0 permission configuration register 0
      CORE_X_IRAM0_PMS_CONSTRAIN_0                  : aliased CORE_X_IRAM0_PMS_CONSTRAIN_0_Register;
      --  corex iram0 permission configuration register 0
      CORE_X_IRAM0_PMS_CONSTRAIN_1                  : aliased CORE_X_IRAM0_PMS_CONSTRAIN_1_Register;
      --  corex iram0 permission configuration register 1
      CORE_X_IRAM0_PMS_CONSTRAIN_2                  : aliased CORE_X_IRAM0_PMS_CONSTRAIN_2_Register;
      --  core0 iram0 permission monitor configuration register 0
      CORE_0_IRAM0_PMS_MONITOR_0                    : aliased CORE_0_IRAM0_PMS_MONITOR_0_Register;
      --  core0 iram0 permission monitor configuration register 1
      CORE_0_IRAM0_PMS_MONITOR_1                    : aliased CORE_0_IRAM0_PMS_MONITOR_1_Register;
      --  core0 iram0 permission monitor configuration register 2
      CORE_0_IRAM0_PMS_MONITOR_2                    : aliased CORE_0_IRAM0_PMS_MONITOR_2_Register;
      --  core1 iram0 permission monitor configuration register 0
      CORE_1_IRAM0_PMS_MONITOR_0                    : aliased CORE_1_IRAM0_PMS_MONITOR_0_Register;
      --  core1 iram0 permission monitor configuration register 1
      CORE_1_IRAM0_PMS_MONITOR_1                    : aliased CORE_1_IRAM0_PMS_MONITOR_1_Register;
      --  core1 iram0 permission monitor configuration register 2
      CORE_1_IRAM0_PMS_MONITOR_2                    : aliased CORE_1_IRAM0_PMS_MONITOR_2_Register;
      --  corex dram0 permission configuration register 0
      CORE_X_DRAM0_PMS_CONSTRAIN_0                  : aliased CORE_X_DRAM0_PMS_CONSTRAIN_0_Register;
      --  corex dram0 permission configuration register 1
      CORE_X_DRAM0_PMS_CONSTRAIN_1                  : aliased CORE_X_DRAM0_PMS_CONSTRAIN_1_Register;
      --  core0 dram0 permission monitor configuration register 0
      CORE_0_DRAM0_PMS_MONITOR_0                    : aliased CORE_0_DRAM0_PMS_MONITOR_0_Register;
      --  core0 dram0 permission monitor configuration register 1
      CORE_0_DRAM0_PMS_MONITOR_1                    : aliased CORE_0_DRAM0_PMS_MONITOR_1_Register;
      --  core0 dram0 permission monitor configuration register 2.
      CORE_0_DRAM0_PMS_MONITOR_2                    : aliased CORE_0_DRAM0_PMS_MONITOR_2_Register;
      --  core0 dram0 permission monitor configuration register 3.
      CORE_0_DRAM0_PMS_MONITOR_3                    : aliased CORE_0_DRAM0_PMS_MONITOR_3_Register;
      --  core1 dram0 permission monitor configuration register 0
      CORE_1_DRAM0_PMS_MONITOR_0                    : aliased CORE_1_DRAM0_PMS_MONITOR_0_Register;
      --  core1 dram0 permission monitor configuration register 1
      CORE_1_DRAM0_PMS_MONITOR_1                    : aliased CORE_1_DRAM0_PMS_MONITOR_1_Register;
      --  core1 dram0 permission monitor configuration register 2.
      CORE_1_DRAM0_PMS_MONITOR_2                    : aliased CORE_1_DRAM0_PMS_MONITOR_2_Register;
      --  core1 dram0 permission monitor configuration register 3.
      CORE_1_DRAM0_PMS_MONITOR_3                    : aliased CORE_1_DRAM0_PMS_MONITOR_3_Register;
      --  Core0 access peripherals permission configuration register 0.
      CORE_0_PIF_PMS_CONSTRAIN_0                    : aliased CORE_0_PIF_PMS_CONSTRAIN_0_Register;
      --  Core0 access peripherals permission configuration register 1.
      CORE_0_PIF_PMS_CONSTRAIN_1                    : aliased CORE_0_PIF_PMS_CONSTRAIN_1_Register;
      --  Core0 access peripherals permission configuration register 2.
      CORE_0_PIF_PMS_CONSTRAIN_2                    : aliased CORE_0_PIF_PMS_CONSTRAIN_2_Register;
      --  Core0 access peripherals permission configuration register 3.
      CORE_0_PIF_PMS_CONSTRAIN_3                    : aliased CORE_0_PIF_PMS_CONSTRAIN_3_Register;
      --  Core0 access peripherals permission configuration register 4.
      CORE_0_PIF_PMS_CONSTRAIN_4                    : aliased CORE_0_PIF_PMS_CONSTRAIN_4_Register;
      --  Core0 access peripherals permission configuration register 5.
      CORE_0_PIF_PMS_CONSTRAIN_5                    : aliased CORE_0_PIF_PMS_CONSTRAIN_5_Register;
      --  Core0 access peripherals permission configuration register 6.
      CORE_0_PIF_PMS_CONSTRAIN_6                    : aliased CORE_0_PIF_PMS_CONSTRAIN_6_Register;
      --  Core0 access peripherals permission configuration register 7.
      CORE_0_PIF_PMS_CONSTRAIN_7                    : aliased CORE_0_PIF_PMS_CONSTRAIN_7_Register;
      --  Core0 access peripherals permission configuration register 8.
      CORE_0_PIF_PMS_CONSTRAIN_8                    : aliased CORE_0_PIF_PMS_CONSTRAIN_8_Register;
      --  Core0 access peripherals permission configuration register 9.
      CORE_0_PIF_PMS_CONSTRAIN_9                    : aliased CORE_0_PIF_PMS_CONSTRAIN_9_Register;
      --  Core0 access peripherals permission configuration register 10.
      CORE_0_PIF_PMS_CONSTRAIN_10                   : aliased CORE_0_PIF_PMS_CONSTRAIN_10_Register;
      --  Core0 access peripherals permission configuration register 11.
      CORE_0_PIF_PMS_CONSTRAIN_11                   : aliased CORE_0_PIF_PMS_CONSTRAIN_11_Register;
      --  Core0 access peripherals permission configuration register 12.
      CORE_0_PIF_PMS_CONSTRAIN_12                   : aliased CORE_0_PIF_PMS_CONSTRAIN_12_Register;
      --  Core0 access peripherals permission configuration register 13.
      CORE_0_PIF_PMS_CONSTRAIN_13                   : aliased CORE_0_PIF_PMS_CONSTRAIN_13_Register;
      --  Core0 access peripherals permission configuration register 14.
      CORE_0_PIF_PMS_CONSTRAIN_14                   : aliased CORE_0_PIF_PMS_CONSTRAIN_14_Register;
      --  Core0 region permission register 0.
      CORE_0_REGION_PMS_CONSTRAIN_0                 : aliased CORE_0_REGION_PMS_CONSTRAIN_0_Register;
      --  Core0 region permission register 1.
      CORE_0_REGION_PMS_CONSTRAIN_1                 : aliased CORE_0_REGION_PMS_CONSTRAIN_1_Register;
      --  Core0 region permission register 2.
      CORE_0_REGION_PMS_CONSTRAIN_2                 : aliased CORE_0_REGION_PMS_CONSTRAIN_2_Register;
      --  Core0 region permission register 3.
      CORE_0_REGION_PMS_CONSTRAIN_3                 : aliased CORE_0_REGION_PMS_CONSTRAIN_3_Register;
      --  Core0 region permission register 4.
      CORE_0_REGION_PMS_CONSTRAIN_4                 : aliased CORE_0_REGION_PMS_CONSTRAIN_4_Register;
      --  Core0 region permission register 5.
      CORE_0_REGION_PMS_CONSTRAIN_5                 : aliased CORE_0_REGION_PMS_CONSTRAIN_5_Register;
      --  Core0 region permission register 6.
      CORE_0_REGION_PMS_CONSTRAIN_6                 : aliased CORE_0_REGION_PMS_CONSTRAIN_6_Register;
      --  Core0 region permission register 7.
      CORE_0_REGION_PMS_CONSTRAIN_7                 : aliased CORE_0_REGION_PMS_CONSTRAIN_7_Register;
      --  Core0 region permission register 8.
      CORE_0_REGION_PMS_CONSTRAIN_8                 : aliased CORE_0_REGION_PMS_CONSTRAIN_8_Register;
      --  Core0 region permission register 9.
      CORE_0_REGION_PMS_CONSTRAIN_9                 : aliased CORE_0_REGION_PMS_CONSTRAIN_9_Register;
      --  Core0 region permission register 10.
      CORE_0_REGION_PMS_CONSTRAIN_10                : aliased CORE_0_REGION_PMS_CONSTRAIN_10_Register;
      --  Core0 region permission register 11.
      CORE_0_REGION_PMS_CONSTRAIN_11                : aliased CORE_0_REGION_PMS_CONSTRAIN_11_Register;
      --  Core0 region permission register 12.
      CORE_0_REGION_PMS_CONSTRAIN_12                : aliased CORE_0_REGION_PMS_CONSTRAIN_12_Register;
      --  Core0 region permission register 13.
      CORE_0_REGION_PMS_CONSTRAIN_13                : aliased CORE_0_REGION_PMS_CONSTRAIN_13_Register;
      --  Core0 region permission register 14.
      CORE_0_REGION_PMS_CONSTRAIN_14                : aliased CORE_0_REGION_PMS_CONSTRAIN_14_Register;
      --  Core0 permission report register 0.
      CORE_0_PIF_PMS_MONITOR_0                      : aliased CORE_0_PIF_PMS_MONITOR_0_Register;
      --  Core0 permission report register 1.
      CORE_0_PIF_PMS_MONITOR_1                      : aliased CORE_0_PIF_PMS_MONITOR_1_Register;
      --  Core0 permission report register 2.
      CORE_0_PIF_PMS_MONITOR_2                      : aliased CORE_0_PIF_PMS_MONITOR_2_Register;
      --  Core0 permission report register 3.
      CORE_0_PIF_PMS_MONITOR_3                      : aliased ESP32S3_Registers.UInt32;
      --  Core0 permission report register 4.
      CORE_0_PIF_PMS_MONITOR_4                      : aliased CORE_0_PIF_PMS_MONITOR_4_Register;
      --  Core0 permission report register 5.
      CORE_0_PIF_PMS_MONITOR_5                      : aliased CORE_0_PIF_PMS_MONITOR_5_Register;
      --  Core0 permission report register 6.
      CORE_0_PIF_PMS_MONITOR_6                      : aliased ESP32S3_Registers.UInt32;
      --  core0 vecbase override configuration register 0
      CORE_0_VECBASE_OVERRIDE_LOCK                  : aliased CORE_0_VECBASE_OVERRIDE_LOCK_Register;
      --  core0 vecbase override configuration register 0
      CORE_0_VECBASE_OVERRIDE_0                     : aliased CORE_0_VECBASE_OVERRIDE_0_Register;
      --  core0 vecbase override configuration register 1
      CORE_0_VECBASE_OVERRIDE_1                     : aliased CORE_0_VECBASE_OVERRIDE_1_Register;
      --  core0 vecbase override configuration register 1
      CORE_0_VECBASE_OVERRIDE_2                     : aliased CORE_0_VECBASE_OVERRIDE_2_Register;
      --  core0 toomanyexception override configuration register 0.
      CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_0         : aliased CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_0_Register;
      --  core0 toomanyexception override configuration register 1.
      CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_1         : aliased CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_1_Register;
      --  Core1 access peripherals permission configuration register 0.
      CORE_1_PIF_PMS_CONSTRAIN_0                    : aliased CORE_1_PIF_PMS_CONSTRAIN_0_Register;
      --  Core1 access peripherals permission configuration register 1.
      CORE_1_PIF_PMS_CONSTRAIN_1                    : aliased CORE_1_PIF_PMS_CONSTRAIN_1_Register;
      --  Core1 access peripherals permission configuration register 2.
      CORE_1_PIF_PMS_CONSTRAIN_2                    : aliased CORE_1_PIF_PMS_CONSTRAIN_2_Register;
      --  Core1 access peripherals permission configuration register 3.
      CORE_1_PIF_PMS_CONSTRAIN_3                    : aliased CORE_1_PIF_PMS_CONSTRAIN_3_Register;
      --  Core1 access peripherals permission configuration register 4.
      CORE_1_PIF_PMS_CONSTRAIN_4                    : aliased CORE_1_PIF_PMS_CONSTRAIN_4_Register;
      --  Core1 access peripherals permission configuration register 5.
      CORE_1_PIF_PMS_CONSTRAIN_5                    : aliased CORE_1_PIF_PMS_CONSTRAIN_5_Register;
      --  Core1 access peripherals permission configuration register 6.
      CORE_1_PIF_PMS_CONSTRAIN_6                    : aliased CORE_1_PIF_PMS_CONSTRAIN_6_Register;
      --  Core1 access peripherals permission configuration register 7.
      CORE_1_PIF_PMS_CONSTRAIN_7                    : aliased CORE_1_PIF_PMS_CONSTRAIN_7_Register;
      --  Core1 access peripherals permission configuration register 8.
      CORE_1_PIF_PMS_CONSTRAIN_8                    : aliased CORE_1_PIF_PMS_CONSTRAIN_8_Register;
      --  Core1 access peripherals permission configuration register 9.
      CORE_1_PIF_PMS_CONSTRAIN_9                    : aliased CORE_1_PIF_PMS_CONSTRAIN_9_Register;
      --  core1 access peripherals permission configuration register 10.
      CORE_1_PIF_PMS_CONSTRAIN_10                   : aliased CORE_1_PIF_PMS_CONSTRAIN_10_Register;
      --  core1 access peripherals permission configuration register 11.
      CORE_1_PIF_PMS_CONSTRAIN_11                   : aliased CORE_1_PIF_PMS_CONSTRAIN_11_Register;
      --  core1 access peripherals permission configuration register 12.
      CORE_1_PIF_PMS_CONSTRAIN_12                   : aliased CORE_1_PIF_PMS_CONSTRAIN_12_Register;
      --  core1 access peripherals permission configuration register 13.
      CORE_1_PIF_PMS_CONSTRAIN_13                   : aliased CORE_1_PIF_PMS_CONSTRAIN_13_Register;
      --  core1 access peripherals permission configuration register 14.
      CORE_1_PIF_PMS_CONSTRAIN_14                   : aliased CORE_1_PIF_PMS_CONSTRAIN_14_Register;
      --  core1 region permission register 0.
      CORE_1_REGION_PMS_CONSTRAIN_0                 : aliased CORE_1_REGION_PMS_CONSTRAIN_0_Register;
      --  core1 region permission register 1.
      CORE_1_REGION_PMS_CONSTRAIN_1                 : aliased CORE_1_REGION_PMS_CONSTRAIN_1_Register;
      --  core1 region permission register 2.
      CORE_1_REGION_PMS_CONSTRAIN_2                 : aliased CORE_1_REGION_PMS_CONSTRAIN_2_Register;
      --  core1 region permission register 3.
      CORE_1_REGION_PMS_CONSTRAIN_3                 : aliased CORE_1_REGION_PMS_CONSTRAIN_3_Register;
      --  core1 region permission register 4.
      CORE_1_REGION_PMS_CONSTRAIN_4                 : aliased CORE_1_REGION_PMS_CONSTRAIN_4_Register;
      --  core1 region permission register 5.
      CORE_1_REGION_PMS_CONSTRAIN_5                 : aliased CORE_1_REGION_PMS_CONSTRAIN_5_Register;
      --  core1 region permission register 6.
      CORE_1_REGION_PMS_CONSTRAIN_6                 : aliased CORE_1_REGION_PMS_CONSTRAIN_6_Register;
      --  core1 region permission register 7.
      CORE_1_REGION_PMS_CONSTRAIN_7                 : aliased CORE_1_REGION_PMS_CONSTRAIN_7_Register;
      --  core1 region permission register 8.
      CORE_1_REGION_PMS_CONSTRAIN_8                 : aliased CORE_1_REGION_PMS_CONSTRAIN_8_Register;
      --  core1 region permission register 9.
      CORE_1_REGION_PMS_CONSTRAIN_9                 : aliased CORE_1_REGION_PMS_CONSTRAIN_9_Register;
      --  core1 region permission register 10.
      CORE_1_REGION_PMS_CONSTRAIN_10                : aliased CORE_1_REGION_PMS_CONSTRAIN_10_Register;
      --  core1 region permission register 11.
      CORE_1_REGION_PMS_CONSTRAIN_11                : aliased CORE_1_REGION_PMS_CONSTRAIN_11_Register;
      --  core1 region permission register 12.
      CORE_1_REGION_PMS_CONSTRAIN_12                : aliased CORE_1_REGION_PMS_CONSTRAIN_12_Register;
      --  core1 region permission register 13.
      CORE_1_REGION_PMS_CONSTRAIN_13                : aliased CORE_1_REGION_PMS_CONSTRAIN_13_Register;
      --  core1 region permission register 14.
      CORE_1_REGION_PMS_CONSTRAIN_14                : aliased CORE_1_REGION_PMS_CONSTRAIN_14_Register;
      --  core1 permission report register 0.
      CORE_1_PIF_PMS_MONITOR_0                      : aliased CORE_1_PIF_PMS_MONITOR_0_Register;
      --  core1 permission report register 1.
      CORE_1_PIF_PMS_MONITOR_1                      : aliased CORE_1_PIF_PMS_MONITOR_1_Register;
      --  core1 permission report register 2.
      CORE_1_PIF_PMS_MONITOR_2                      : aliased CORE_1_PIF_PMS_MONITOR_2_Register;
      --  core1 permission report register 3.
      CORE_1_PIF_PMS_MONITOR_3                      : aliased ESP32S3_Registers.UInt32;
      --  core1 permission report register 4.
      CORE_1_PIF_PMS_MONITOR_4                      : aliased CORE_1_PIF_PMS_MONITOR_4_Register;
      --  core1 permission report register 5.
      CORE_1_PIF_PMS_MONITOR_5                      : aliased CORE_1_PIF_PMS_MONITOR_5_Register;
      --  core1 permission report register 6.
      CORE_1_PIF_PMS_MONITOR_6                      : aliased ESP32S3_Registers.UInt32;
      --  core1 vecbase override configuration register 0
      CORE_1_VECBASE_OVERRIDE_LOCK                  : aliased CORE_1_VECBASE_OVERRIDE_LOCK_Register;
      --  core1 vecbase override configuration register 0
      CORE_1_VECBASE_OVERRIDE_0                     : aliased CORE_1_VECBASE_OVERRIDE_0_Register;
      --  core1 vecbase override configuration register 1
      CORE_1_VECBASE_OVERRIDE_1                     : aliased CORE_1_VECBASE_OVERRIDE_1_Register;
      --  core1 vecbase override configuration register 1
      CORE_1_VECBASE_OVERRIDE_2                     : aliased CORE_1_VECBASE_OVERRIDE_2_Register;
      --  core1 toomanyexception override configuration register 0.
      CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_0         : aliased CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_0_Register;
      --  core1 toomanyexception override configuration register 1.
      CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_1         : aliased CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_1_Register;
      --  BackUp access peripherals permission configuration register 0.
      BACKUP_BUS_PMS_CONSTRAIN_0                    : aliased BACKUP_BUS_PMS_CONSTRAIN_0_Register;
      --  BackUp access peripherals permission configuration register 1.
      BACKUP_BUS_PMS_CONSTRAIN_1                    : aliased BACKUP_BUS_PMS_CONSTRAIN_1_Register;
      --  BackUp access peripherals permission configuration register 2.
      BACKUP_BUS_PMS_CONSTRAIN_2                    : aliased BACKUP_BUS_PMS_CONSTRAIN_2_Register;
      --  BackUp access peripherals permission configuration register 3.
      BACKUP_BUS_PMS_CONSTRAIN_3                    : aliased BACKUP_BUS_PMS_CONSTRAIN_3_Register;
      --  BackUp access peripherals permission configuration register 4.
      BACKUP_BUS_PMS_CONSTRAIN_4                    : aliased BACKUP_BUS_PMS_CONSTRAIN_4_Register;
      --  BackUp access peripherals permission configuration register 5.
      BACKUP_BUS_PMS_CONSTRAIN_5                    : aliased BACKUP_BUS_PMS_CONSTRAIN_5_Register;
      --  BackUp access peripherals permission configuration register 6.
      BACKUP_BUS_PMS_CONSTRAIN_6                    : aliased BACKUP_BUS_PMS_CONSTRAIN_6_Register;
      --  BackUp permission report register 0.
      BACKUP_BUS_PMS_MONITOR_0                      : aliased BACKUP_BUS_PMS_MONITOR_0_Register;
      --  BackUp permission report register 1.
      BACKUP_BUS_PMS_MONITOR_1                      : aliased BACKUP_BUS_PMS_MONITOR_1_Register;
      --  BackUp permission report register 2.
      BACKUP_BUS_PMS_MONITOR_2                      : aliased BACKUP_BUS_PMS_MONITOR_2_Register;
      --  BackUp permission report register 3.
      BACKUP_BUS_PMS_MONITOR_3                      : aliased ESP32S3_Registers.UInt32;
      --  EDMA boundary lock register.
      EDMA_BOUNDARY_LOCK                            : aliased EDMA_BOUNDARY_LOCK_Register;
      --  EDMA boundary 0 configuration
      EDMA_BOUNDARY_0                               : aliased EDMA_BOUNDARY_0_Register;
      --  EDMA boundary 1 configuration
      EDMA_BOUNDARY_1                               : aliased EDMA_BOUNDARY_1_Register;
      --  EDMA boundary 2 configuration
      EDMA_BOUNDARY_2                               : aliased EDMA_BOUNDARY_2_Register;
      --  EDMA-SPI2 permission lock register.
      EDMA_PMS_SPI2_LOCK                            : aliased EDMA_PMS_SPI2_LOCK_Register;
      --  EDMA-SPI2 permission control register.
      EDMA_PMS_SPI2                                 : aliased EDMA_PMS_SPI_Register;
      --  EDMA-SPI3 permission lock register.
      EDMA_PMS_SPI3_LOCK                            : aliased EDMA_PMS_SPI3_LOCK_Register;
      --  EDMA-SPI3 permission control register.
      EDMA_PMS_SPI3                                 : aliased EDMA_PMS_SPI_Register;
      --  EDMA-UHCI0 permission lock register.
      EDMA_PMS_UHCI0_LOCK                           : aliased EDMA_PMS_UHCI0_LOCK_Register;
      --  EDMA-UHCI0 permission control register.
      EDMA_PMS_UHCI0                                : aliased EDMA_PMS_UHCI0_Register;
      --  EDMA-I2S0 permission lock register.
      EDMA_PMS_I2S0_LOCK                            : aliased EDMA_PMS_I2S0_LOCK_Register;
      --  EDMA-I2S0 permission control register.
      EDMA_PMS_I2S0                                 : aliased EDMA_PMS_I2S_Register;
      --  EDMA-I2S1 permission lock register.
      EDMA_PMS_I2S1_LOCK                            : aliased EDMA_PMS_I2S1_LOCK_Register;
      --  EDMA-I2S1 permission control register.
      EDMA_PMS_I2S1                                 : aliased EDMA_PMS_I2S_Register;
      --  EDMA-LCD/CAM permission lock register.
      EDMA_PMS_LCD_CAM_LOCK                         : aliased EDMA_PMS_LCD_CAM_LOCK_Register;
      --  EDMA-LCD/CAM permission control register.
      EDMA_PMS_LCD_CAM                              : aliased EDMA_PMS_LCD_CAM_Register;
      --  EDMA-AES permission lock register.
      EDMA_PMS_AES_LOCK                             : aliased EDMA_PMS_AES_LOCK_Register;
      --  EDMA-AES permission control register.
      EDMA_PMS_AES                                  : aliased EDMA_PMS_AES_Register;
      --  EDMA-SHA permission lock register.
      EDMA_PMS_SHA_LOCK                             : aliased EDMA_PMS_SHA_LOCK_Register;
      --  EDMA-SHA permission control register.
      EDMA_PMS_SHA                                  : aliased EDMA_PMS_SHA_Register;
      --  EDMA-ADC/DAC permission lock register.
      EDMA_PMS_ADC_DAC_LOCK                         : aliased EDMA_PMS_ADC_DAC_LOCK_Register;
      --  EDMA-ADC/DAC permission control register.
      EDMA_PMS_ADC_DAC                              : aliased EDMA_PMS_ADC_DAC_Register;
      --  EDMA-RMT permission lock register.
      EDMA_PMS_RMT_LOCK                             : aliased EDMA_PMS_RMT_LOCK_Register;
      --  EDMA-RMT permission control register.
      EDMA_PMS_RMT                                  : aliased EDMA_PMS_RMT_Register;
      --  Sensitive module clock gate configuration register.
      CLOCK_GATE                                    : aliased CLOCK_GATE_Register;
      --  RTC coprocessor permission register.
      RTC_PMS                                       : aliased RTC_PMS_Register;
      --  Sensitive version register.
      DATE                                          : aliased DATE_Register;
   end record
     with Volatile;

   for SENSITIVE_Peripheral use record
      CACHE_DATAARRAY_CONNECT_0                     at 16#0# range 0 .. 31;
      CACHE_DATAARRAY_CONNECT_1                     at 16#4# range 0 .. 31;
      APB_PERIPHERAL_ACCESS_0                       at 16#8# range 0 .. 31;
      APB_PERIPHERAL_ACCESS_1                       at 16#C# range 0 .. 31;
      INTERNAL_SRAM_USAGE_0                         at 16#10# range 0 .. 31;
      INTERNAL_SRAM_USAGE_1                         at 16#14# range 0 .. 31;
      INTERNAL_SRAM_USAGE_2                         at 16#18# range 0 .. 31;
      INTERNAL_SRAM_USAGE_3                         at 16#1C# range 0 .. 31;
      INTERNAL_SRAM_USAGE_4                         at 16#20# range 0 .. 31;
      RETENTION_DISABLE                             at 16#24# range 0 .. 31;
      CACHE_TAG_ACCESS_0                            at 16#28# range 0 .. 31;
      CACHE_TAG_ACCESS_1                            at 16#2C# range 0 .. 31;
      CACHE_MMU_ACCESS_0                            at 16#30# range 0 .. 31;
      CACHE_MMU_ACCESS_1                            at 16#34# range 0 .. 31;
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_0              at 16#38# range 0 .. 31;
      DMA_APBPERI_SPI2_PMS_CONSTRAIN_1              at 16#3C# range 0 .. 31;
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_0              at 16#40# range 0 .. 31;
      DMA_APBPERI_SPI3_PMS_CONSTRAIN_1              at 16#44# range 0 .. 31;
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_0             at 16#48# range 0 .. 31;
      DMA_APBPERI_UHCI0_PMS_CONSTRAIN_1             at 16#4C# range 0 .. 31;
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_0              at 16#50# range 0 .. 31;
      DMA_APBPERI_I2S0_PMS_CONSTRAIN_1              at 16#54# range 0 .. 31;
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_0              at 16#58# range 0 .. 31;
      DMA_APBPERI_I2S1_PMS_CONSTRAIN_1              at 16#5C# range 0 .. 31;
      DMA_APBPERI_MAC_PMS_CONSTRAIN_0               at 16#60# range 0 .. 31;
      DMA_APBPERI_MAC_PMS_CONSTRAIN_1               at 16#64# range 0 .. 31;
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_0            at 16#68# range 0 .. 31;
      DMA_APBPERI_BACKUP_PMS_CONSTRAIN_1            at 16#6C# range 0 .. 31;
      DMA_APBPERI_AES_PMS_CONSTRAIN_0               at 16#70# range 0 .. 31;
      DMA_APBPERI_AES_PMS_CONSTRAIN_1               at 16#74# range 0 .. 31;
      DMA_APBPERI_SHA_PMS_CONSTRAIN_0               at 16#78# range 0 .. 31;
      DMA_APBPERI_SHA_PMS_CONSTRAIN_1               at 16#7C# range 0 .. 31;
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_0           at 16#80# range 0 .. 31;
      DMA_APBPERI_ADC_DAC_PMS_CONSTRAIN_1           at 16#84# range 0 .. 31;
      DMA_APBPERI_RMT_PMS_CONSTRAIN_0               at 16#88# range 0 .. 31;
      DMA_APBPERI_RMT_PMS_CONSTRAIN_1               at 16#8C# range 0 .. 31;
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_0           at 16#90# range 0 .. 31;
      DMA_APBPERI_LCD_CAM_PMS_CONSTRAIN_1           at 16#94# range 0 .. 31;
      DMA_APBPERI_USB_PMS_CONSTRAIN_0               at 16#98# range 0 .. 31;
      DMA_APBPERI_USB_PMS_CONSTRAIN_1               at 16#9C# range 0 .. 31;
      DMA_APBPERI_LC_PMS_CONSTRAIN_0                at 16#A0# range 0 .. 31;
      DMA_APBPERI_LC_PMS_CONSTRAIN_1                at 16#A4# range 0 .. 31;
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_0              at 16#A8# range 0 .. 31;
      DMA_APBPERI_SDIO_PMS_CONSTRAIN_1              at 16#AC# range 0 .. 31;
      DMA_APBPERI_PMS_MONITOR_0                     at 16#B0# range 0 .. 31;
      DMA_APBPERI_PMS_MONITOR_1                     at 16#B4# range 0 .. 31;
      DMA_APBPERI_PMS_MONITOR_2                     at 16#B8# range 0 .. 31;
      DMA_APBPERI_PMS_MONITOR_3                     at 16#BC# range 0 .. 31;
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_0 at 16#C0# range 0 .. 31;
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_1 at 16#C4# range 0 .. 31;
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_2 at 16#C8# range 0 .. 31;
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_3 at 16#CC# range 0 .. 31;
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_4 at 16#D0# range 0 .. 31;
      CORE_X_IRAM0_DRAM0_DMA_SPLIT_LINE_CONSTRAIN_5 at 16#D4# range 0 .. 31;
      CORE_X_IRAM0_PMS_CONSTRAIN_0                  at 16#D8# range 0 .. 31;
      CORE_X_IRAM0_PMS_CONSTRAIN_1                  at 16#DC# range 0 .. 31;
      CORE_X_IRAM0_PMS_CONSTRAIN_2                  at 16#E0# range 0 .. 31;
      CORE_0_IRAM0_PMS_MONITOR_0                    at 16#E4# range 0 .. 31;
      CORE_0_IRAM0_PMS_MONITOR_1                    at 16#E8# range 0 .. 31;
      CORE_0_IRAM0_PMS_MONITOR_2                    at 16#EC# range 0 .. 31;
      CORE_1_IRAM0_PMS_MONITOR_0                    at 16#F0# range 0 .. 31;
      CORE_1_IRAM0_PMS_MONITOR_1                    at 16#F4# range 0 .. 31;
      CORE_1_IRAM0_PMS_MONITOR_2                    at 16#F8# range 0 .. 31;
      CORE_X_DRAM0_PMS_CONSTRAIN_0                  at 16#FC# range 0 .. 31;
      CORE_X_DRAM0_PMS_CONSTRAIN_1                  at 16#100# range 0 .. 31;
      CORE_0_DRAM0_PMS_MONITOR_0                    at 16#104# range 0 .. 31;
      CORE_0_DRAM0_PMS_MONITOR_1                    at 16#108# range 0 .. 31;
      CORE_0_DRAM0_PMS_MONITOR_2                    at 16#10C# range 0 .. 31;
      CORE_0_DRAM0_PMS_MONITOR_3                    at 16#110# range 0 .. 31;
      CORE_1_DRAM0_PMS_MONITOR_0                    at 16#114# range 0 .. 31;
      CORE_1_DRAM0_PMS_MONITOR_1                    at 16#118# range 0 .. 31;
      CORE_1_DRAM0_PMS_MONITOR_2                    at 16#11C# range 0 .. 31;
      CORE_1_DRAM0_PMS_MONITOR_3                    at 16#120# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_0                    at 16#124# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_1                    at 16#128# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_2                    at 16#12C# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_3                    at 16#130# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_4                    at 16#134# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_5                    at 16#138# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_6                    at 16#13C# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_7                    at 16#140# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_8                    at 16#144# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_9                    at 16#148# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_10                   at 16#14C# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_11                   at 16#150# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_12                   at 16#154# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_13                   at 16#158# range 0 .. 31;
      CORE_0_PIF_PMS_CONSTRAIN_14                   at 16#15C# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_0                 at 16#160# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_1                 at 16#164# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_2                 at 16#168# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_3                 at 16#16C# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_4                 at 16#170# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_5                 at 16#174# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_6                 at 16#178# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_7                 at 16#17C# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_8                 at 16#180# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_9                 at 16#184# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_10                at 16#188# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_11                at 16#18C# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_12                at 16#190# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_13                at 16#194# range 0 .. 31;
      CORE_0_REGION_PMS_CONSTRAIN_14                at 16#198# range 0 .. 31;
      CORE_0_PIF_PMS_MONITOR_0                      at 16#19C# range 0 .. 31;
      CORE_0_PIF_PMS_MONITOR_1                      at 16#1A0# range 0 .. 31;
      CORE_0_PIF_PMS_MONITOR_2                      at 16#1A4# range 0 .. 31;
      CORE_0_PIF_PMS_MONITOR_3                      at 16#1A8# range 0 .. 31;
      CORE_0_PIF_PMS_MONITOR_4                      at 16#1AC# range 0 .. 31;
      CORE_0_PIF_PMS_MONITOR_5                      at 16#1B0# range 0 .. 31;
      CORE_0_PIF_PMS_MONITOR_6                      at 16#1B4# range 0 .. 31;
      CORE_0_VECBASE_OVERRIDE_LOCK                  at 16#1B8# range 0 .. 31;
      CORE_0_VECBASE_OVERRIDE_0                     at 16#1BC# range 0 .. 31;
      CORE_0_VECBASE_OVERRIDE_1                     at 16#1C0# range 0 .. 31;
      CORE_0_VECBASE_OVERRIDE_2                     at 16#1C4# range 0 .. 31;
      CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_0         at 16#1C8# range 0 .. 31;
      CORE_0_TOOMANYEXCEPTIONS_M_OVERRIDE_1         at 16#1CC# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_0                    at 16#1D0# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_1                    at 16#1D4# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_2                    at 16#1D8# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_3                    at 16#1DC# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_4                    at 16#1E0# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_5                    at 16#1E4# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_6                    at 16#1E8# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_7                    at 16#1EC# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_8                    at 16#1F0# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_9                    at 16#1F4# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_10                   at 16#1F8# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_11                   at 16#1FC# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_12                   at 16#200# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_13                   at 16#204# range 0 .. 31;
      CORE_1_PIF_PMS_CONSTRAIN_14                   at 16#208# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_0                 at 16#20C# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_1                 at 16#210# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_2                 at 16#214# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_3                 at 16#218# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_4                 at 16#21C# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_5                 at 16#220# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_6                 at 16#224# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_7                 at 16#228# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_8                 at 16#22C# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_9                 at 16#230# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_10                at 16#234# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_11                at 16#238# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_12                at 16#23C# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_13                at 16#240# range 0 .. 31;
      CORE_1_REGION_PMS_CONSTRAIN_14                at 16#244# range 0 .. 31;
      CORE_1_PIF_PMS_MONITOR_0                      at 16#248# range 0 .. 31;
      CORE_1_PIF_PMS_MONITOR_1                      at 16#24C# range 0 .. 31;
      CORE_1_PIF_PMS_MONITOR_2                      at 16#250# range 0 .. 31;
      CORE_1_PIF_PMS_MONITOR_3                      at 16#254# range 0 .. 31;
      CORE_1_PIF_PMS_MONITOR_4                      at 16#258# range 0 .. 31;
      CORE_1_PIF_PMS_MONITOR_5                      at 16#25C# range 0 .. 31;
      CORE_1_PIF_PMS_MONITOR_6                      at 16#260# range 0 .. 31;
      CORE_1_VECBASE_OVERRIDE_LOCK                  at 16#264# range 0 .. 31;
      CORE_1_VECBASE_OVERRIDE_0                     at 16#268# range 0 .. 31;
      CORE_1_VECBASE_OVERRIDE_1                     at 16#26C# range 0 .. 31;
      CORE_1_VECBASE_OVERRIDE_2                     at 16#270# range 0 .. 31;
      CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_0         at 16#274# range 0 .. 31;
      CORE_1_TOOMANYEXCEPTIONS_M_OVERRIDE_1         at 16#278# range 0 .. 31;
      BACKUP_BUS_PMS_CONSTRAIN_0                    at 16#27C# range 0 .. 31;
      BACKUP_BUS_PMS_CONSTRAIN_1                    at 16#280# range 0 .. 31;
      BACKUP_BUS_PMS_CONSTRAIN_2                    at 16#284# range 0 .. 31;
      BACKUP_BUS_PMS_CONSTRAIN_3                    at 16#288# range 0 .. 31;
      BACKUP_BUS_PMS_CONSTRAIN_4                    at 16#28C# range 0 .. 31;
      BACKUP_BUS_PMS_CONSTRAIN_5                    at 16#290# range 0 .. 31;
      BACKUP_BUS_PMS_CONSTRAIN_6                    at 16#294# range 0 .. 31;
      BACKUP_BUS_PMS_MONITOR_0                      at 16#298# range 0 .. 31;
      BACKUP_BUS_PMS_MONITOR_1                      at 16#29C# range 0 .. 31;
      BACKUP_BUS_PMS_MONITOR_2                      at 16#2A0# range 0 .. 31;
      BACKUP_BUS_PMS_MONITOR_3                      at 16#2A4# range 0 .. 31;
      EDMA_BOUNDARY_LOCK                            at 16#2A8# range 0 .. 31;
      EDMA_BOUNDARY_0                               at 16#2AC# range 0 .. 31;
      EDMA_BOUNDARY_1                               at 16#2B0# range 0 .. 31;
      EDMA_BOUNDARY_2                               at 16#2B4# range 0 .. 31;
      EDMA_PMS_SPI2_LOCK                            at 16#2B8# range 0 .. 31;
      EDMA_PMS_SPI2                                 at 16#2BC# range 0 .. 31;
      EDMA_PMS_SPI3_LOCK                            at 16#2C0# range 0 .. 31;
      EDMA_PMS_SPI3                                 at 16#2C4# range 0 .. 31;
      EDMA_PMS_UHCI0_LOCK                           at 16#2C8# range 0 .. 31;
      EDMA_PMS_UHCI0                                at 16#2CC# range 0 .. 31;
      EDMA_PMS_I2S0_LOCK                            at 16#2D0# range 0 .. 31;
      EDMA_PMS_I2S0                                 at 16#2D4# range 0 .. 31;
      EDMA_PMS_I2S1_LOCK                            at 16#2D8# range 0 .. 31;
      EDMA_PMS_I2S1                                 at 16#2DC# range 0 .. 31;
      EDMA_PMS_LCD_CAM_LOCK                         at 16#2E0# range 0 .. 31;
      EDMA_PMS_LCD_CAM                              at 16#2E4# range 0 .. 31;
      EDMA_PMS_AES_LOCK                             at 16#2E8# range 0 .. 31;
      EDMA_PMS_AES                                  at 16#2EC# range 0 .. 31;
      EDMA_PMS_SHA_LOCK                             at 16#2F0# range 0 .. 31;
      EDMA_PMS_SHA                                  at 16#2F4# range 0 .. 31;
      EDMA_PMS_ADC_DAC_LOCK                         at 16#2F8# range 0 .. 31;
      EDMA_PMS_ADC_DAC                              at 16#2FC# range 0 .. 31;
      EDMA_PMS_RMT_LOCK                             at 16#300# range 0 .. 31;
      EDMA_PMS_RMT                                  at 16#304# range 0 .. 31;
      CLOCK_GATE                                    at 16#308# range 0 .. 31;
      RTC_PMS                                       at 16#30C# range 0 .. 31;
      DATE                                          at 16#FFC# range 0 .. 31;
   end record;

   --  SENSITIVE Peripheral
   SENSITIVE_Periph : aliased SENSITIVE_Peripheral
     with Import, Address => SENSITIVE_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.SENSITIVE;
