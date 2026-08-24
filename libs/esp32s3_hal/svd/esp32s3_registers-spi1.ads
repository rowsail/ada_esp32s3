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

package ESP32S3_Registers.SPI1 is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  SPI1 memory command register
   type CMD_Register is record
      --  unspecified
      Reserved_0_16 : ESP32S3_Registers.UInt17 := 16#0#;
      --  In user mode, it is set to indicate that program/erase operation will
      --  be triggered. The bit is combined with SPI_MEM_USR bit. The bit will
      --  be cleared once the operation done.1: enable 0: disable.
      FLASH_PE      : Boolean := False;
      --  User define command enable. An operation will be triggered when the
      --  bit is set. The bit will be cleared once the operation done.1: enable
      --  0: disable.
      USR           : Boolean := False;
      --  Drive Flash into high performance mode. The bit will be cleared once
      --  the operation done.1: enable 0: disable.
      FLASH_HPM     : Boolean := False;
      --  This bit combined with SPI_MEM_RESANDRES bit releases Flash from the
      --  power-down state or high performance mode and obtains the devices ID.
      --  The bit will be cleared once the operation done.1: enable 0: disable.
      FLASH_RES     : Boolean := False;
      --  Drive Flash into power down. An operation will be triggered when the
      --  bit is set. The bit will be cleared once the operation done.1: enable
      --  0: disable.
      FLASH_DP      : Boolean := False;
      --  Chip erase enable. Chip erase operation will be triggered when the
      --  bit is set. The bit will be cleared once the operation done.1: enable
      --  0: disable.
      FLASH_CE      : Boolean := False;
      --  Block erase enable(32KB) . Block erase operation will be triggered
      --  when the bit is set. The bit will be cleared once the operation
      --  done.1: enable 0: disable.
      FLASH_BE      : Boolean := False;
      --  Sector erase enable(4KB). Sector erase operation will be triggered
      --  when the bit is set. The bit will be cleared once the operation
      --  done.1: enable 0: disable.
      FLASH_SE      : Boolean := False;
      --  Page program enable(1 byte ~64 bytes data to be programmed). Page
      --  program operation will be triggered when the bit is set. The bit will
      --  be cleared once the operation done .1: enable 0: disable.
      FLASH_PP      : Boolean := False;
      --  Write status register enable. Write status operation will be
      --  triggered when the bit is set. The bit will be cleared once the
      --  operation done.1: enable 0: disable.
      FLASH_WRSR    : Boolean := False;
      --  Read status register-1. Read status operation will be triggered when
      --  the bit is set. The bit will be cleared once the operation done.1:
      --  enable 0: disable.
      FLASH_RDSR    : Boolean := False;
      --  Read JEDEC ID . Read ID command will be sent when the bit is set. The
      --  bit will be cleared once the operation done. 1: enable 0: disable.
      FLASH_RDID    : Boolean := False;
      --  Write flash disable. Write disable command will be sent when the bit
      --  is set. The bit will be cleared once the operation done. 1: enable 0:
      --  disable.
      FLASH_WRDI    : Boolean := False;
      --  Write flash enable. Write enable command will be sent when the bit is
      --  set. The bit will be cleared once the operation done. 1: enable 0:
      --  disable.
      FLASH_WREN    : Boolean := False;
      --  Read flash enable. Read flash operation will be triggered when the
      --  bit is set. The bit will be cleared once the operation done. 1:
      --  enable 0: disable.
      FLASH_READ    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMD_Register use record
      Reserved_0_16 at 0 range 0 .. 16;
      FLASH_PE      at 0 range 17 .. 17;
      USR           at 0 range 18 .. 18;
      FLASH_HPM     at 0 range 19 .. 19;
      FLASH_RES     at 0 range 20 .. 20;
      FLASH_DP      at 0 range 21 .. 21;
      FLASH_CE      at 0 range 22 .. 22;
      FLASH_BE      at 0 range 23 .. 23;
      FLASH_SE      at 0 range 24 .. 24;
      FLASH_PP      at 0 range 25 .. 25;
      FLASH_WRSR    at 0 range 26 .. 26;
      FLASH_RDSR    at 0 range 27 .. 27;
      FLASH_RDID    at 0 range 28 .. 28;
      FLASH_WRDI    at 0 range 29 .. 29;
      FLASH_WREN    at 0 range 30 .. 30;
      FLASH_READ    at 0 range 31 .. 31;
   end record;

   --  SPI1 control register
   type CTRL_Register is record
      --  unspecified
      Reserved_0_2   : ESP32S3_Registers.UInt3 := 16#0#;
      --  In the DUMMY phase the signal level of SPI bus is output by the SPI0
      --  controller.
      FDUMMY_OUT     : Boolean := False;
      --  Set this bit to enable 8-bit-mode(8-bm) in DOUT phase.
      FDOUT_OCT      : Boolean := False;
      --  Set this bit to enable 8-bit-mode(8-bm) in DIN phase.
      FDIN_OCT       : Boolean := False;
      --  Set this bit to enable 8-bit-mode(8-bm) in ADDR phase.
      FADDR_OCT      : Boolean := False;
      --  Set this bit to enable 2-bit-mode(2-bm) in CMD phase.
      FCMD_DUAL      : Boolean := False;
      --  Set this bit to enable 4-bit-mode(4-bm) in CMD phase.
      FCMD_QUAD      : Boolean := False;
      --  Set this bit to enable 8-bit-mode(8-bm) in CMD phase.
      FCMD_OCT       : Boolean := False;
      --  For SPI1, initialize crc32 module before writing encrypted data to
      --  flash. Active low.
      FCS_CRC_EN     : Boolean := False;
      --  For SPI1, enable crc32 when writing encrypted data to flash. 1:
      --  enable 0:disable
      TX_CRC_EN      : Boolean := False;
      --  unspecified
      Reserved_12_12 : ESP32S3_Registers.Bit := 16#0#;
      --  This bit should be set when SPI_MEM_FREAD_QIO, SPI_MEM_FREAD_DIO,
      --  SPI_MEM_FREAD_QUAD or SPI_MEM_FREAD_DUAL is set.
      FASTRD_MODE    : Boolean := True;
      --  In hardware 0x3B read operation, DIN phase apply 2 signals. 1: enable
      --  0: disable.
      FREAD_DUAL     : Boolean := False;
      --  The Device ID is read out to SPI_MEM_RD_STATUS register, this bit
      --  combine with spi_mem_flash_res bit. 1: enable 0: disable.
      RESANDRES      : Boolean := True;
      --  unspecified
      Reserved_16_17 : ESP32S3_Registers.UInt2 := 16#0#;
      --  The bit is used to set MISO line polarity, 1: high 0, low
      Q_POL          : Boolean := True;
      --  The bit is used to set MOSI line polarity, 1: high 0, low
      D_POL          : Boolean := True;
      --  In hardware 0x6B read operation, DIN phase apply 4
      --  signals(4-bit-mode). 1: enable 0: disable.
      FREAD_QUAD     : Boolean := False;
      --  Write protect signal output when SPI is idle. 1: output high, 0:
      --  output low.
      WP             : Boolean := True;
      --  Two bytes data will be written to status register when it is set. 1:
      --  enable 0: disable.
      WRSR_2B        : Boolean := False;
      --  In hardware 0xBB read operation, ADDR phase and DIN phase apply 2
      --  signals(2-bit-mode). 1: enable 0: disable.
      FREAD_DIO      : Boolean := False;
      --  In hardware 0xEB read operation, ADDR phase and DIN phase apply 4
      --  signals(4-bit-mode). 1: enable 0: disable.
      FREAD_QIO      : Boolean := False;
      --  unspecified
      Reserved_25_31 : ESP32S3_Registers.UInt7 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTRL_Register use record
      Reserved_0_2   at 0 range 0 .. 2;
      FDUMMY_OUT     at 0 range 3 .. 3;
      FDOUT_OCT      at 0 range 4 .. 4;
      FDIN_OCT       at 0 range 5 .. 5;
      FADDR_OCT      at 0 range 6 .. 6;
      FCMD_DUAL      at 0 range 7 .. 7;
      FCMD_QUAD      at 0 range 8 .. 8;
      FCMD_OCT       at 0 range 9 .. 9;
      FCS_CRC_EN     at 0 range 10 .. 10;
      TX_CRC_EN      at 0 range 11 .. 11;
      Reserved_12_12 at 0 range 12 .. 12;
      FASTRD_MODE    at 0 range 13 .. 13;
      FREAD_DUAL     at 0 range 14 .. 14;
      RESANDRES      at 0 range 15 .. 15;
      Reserved_16_17 at 0 range 16 .. 17;
      Q_POL          at 0 range 18 .. 18;
      D_POL          at 0 range 19 .. 19;
      FREAD_QUAD     at 0 range 20 .. 20;
      WP             at 0 range 21 .. 21;
      WRSR_2B        at 0 range 22 .. 22;
      FREAD_DIO      at 0 range 23 .. 23;
      FREAD_QIO      at 0 range 24 .. 24;
      Reserved_25_31 at 0 range 25 .. 31;
   end record;

   subtype CTRL1_CLK_MODE_Field is ESP32S3_Registers.UInt2;
   subtype CTRL1_CS_HOLD_DLY_RES_Field is ESP32S3_Registers.UInt10;

   --  SPI1 control1 register
   type CTRL1_Register is record
      --  SPI Bus clock (SPI_CLK) mode bits. 0: SPI Bus clock (SPI_CLK) is off
      --  when CS inactive 1: SPI_CLK is delayed one cycle after SPI_CS
      --  inactive 2: SPI_CLK is delayed two cycles after SPI_CS inactive 3:
      --  SPI_CLK is always on.
      CLK_MODE        : CTRL1_CLK_MODE_Field := 16#0#;
      --  After RES/DP/HPM/PES/PER command is sent, SPI1 may waits
      --  (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 4 or * 256) SPI_CLK cycles.
      CS_HOLD_DLY_RES : CTRL1_CS_HOLD_DLY_RES_Field := 16#3FF#;
      --  unspecified
      Reserved_12_31  : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTRL1_Register use record
      CLK_MODE        at 0 range 0 .. 1;
      CS_HOLD_DLY_RES at 0 range 2 .. 11;
      Reserved_12_31  at 0 range 12 .. 31;
   end record;

   --  SPI1 control2 register
   type CTRL2_Register is record
      --  unspecified
      Reserved_0_30 : ESP32S3_Registers.UInt31 := 16#0#;
      --  The FSM will be reset.
      SYNC_RESET    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTRL2_Register use record
      Reserved_0_30 at 0 range 0 .. 30;
      SYNC_RESET    at 0 range 31 .. 31;
   end record;

   subtype CLOCK_CLKCNT_L_Field is ESP32S3_Registers.Byte;
   subtype CLOCK_CLKCNT_H_Field is ESP32S3_Registers.Byte;
   subtype CLOCK_CLKCNT_N_Field is ESP32S3_Registers.Byte;

   --  SPI_CLK clock division register when SPI1 accesses to flash or Ext_RAM.
   type CLOCK_Register is record
      --  It must equal to the value of SPI_MEM_CLKCNT_N.
      CLKCNT_L       : CLOCK_CLKCNT_L_Field := 16#3#;
      --  It must be a floor value of ((SPI_MEM_CLKCNT_N+1)/2-1).
      CLKCNT_H       : CLOCK_CLKCNT_H_Field := 16#1#;
      --  When SPI1 accesses to flash or Ext_RAM, f_SPI_CLK =
      --  f_MSPI_CORE_CLK/(SPI_MEM_CLKCNT_N+1)
      CLKCNT_N       : CLOCK_CLKCNT_N_Field := 16#3#;
      --  unspecified
      Reserved_24_30 : ESP32S3_Registers.UInt7 := 16#0#;
      --  When SPI1 access to flash or Ext_RAM, set this bit in 1-division
      --  mode, f_SPI_CLK = f_MSPI_CORE_CLK.
      CLK_EQU_SYSCLK : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLOCK_Register use record
      CLKCNT_L       at 0 range 0 .. 7;
      CLKCNT_H       at 0 range 8 .. 15;
      CLKCNT_N       at 0 range 16 .. 23;
      Reserved_24_30 at 0 range 24 .. 30;
      CLK_EQU_SYSCLK at 0 range 31 .. 31;
   end record;

   --  SPI1 user register.
   type USER_Register is record
      --  unspecified
      Reserved_0_8      : ESP32S3_Registers.UInt9 := 16#0#;
      --  This bit, combined with SPI_MEM_CK_IDLE_EDGE bit, is used to change
      --  the clock mode 0~3 of SPI_CLK.
      CK_OUT_EDGE       : Boolean := False;
      --  unspecified
      Reserved_10_11    : ESP32S3_Registers.UInt2 := 16#0#;
      --  Set this bit to enable 2-bm in DOUT phase in SPI1 write operation.
      FWRITE_DUAL       : Boolean := False;
      --  Set this bit to enable 4-bm in DOUT phase in SPI1 write operation.
      FWRITE_QUAD       : Boolean := False;
      --  Set this bit to enable 2-bm in ADDR and DOUT phase in SPI1 write
      --  operation.
      FWRITE_DIO        : Boolean := False;
      --  Set this bit to enable 4-bit-mode(4-bm) in ADDR and DOUT phase in
      --  SPI1 write operation.
      FWRITE_QIO        : Boolean := False;
      --  unspecified
      Reserved_16_23    : ESP32S3_Registers.Byte := 16#0#;
      --  DIN phase only access to high-part of the buffer
      --  SPI_MEM_W8_REG~SPI_MEM_W15_REG. 1: enable 0: disable.
      USR_MISO_HIGHPART : Boolean := False;
      --  DOUT phase only access to high-part of the buffer
      --  SPI_MEM_W8_REG~SPI_MEM_W15_REG. 1: enable 0: disable.
      USR_MOSI_HIGHPART : Boolean := False;
      --  SPI_CLK is disabled(No clock edges) in DUMMY phase when the bit is
      --  enable.
      USR_DUMMY_IDLE    : Boolean := False;
      --  Set this bit to enable the DOUT phase of an write-data operation.
      USR_MOSI          : Boolean := False;
      --  Set this bit to enable enable the DIN phase of a read-data operation.
      USR_MISO          : Boolean := False;
      --  Set this bit to enable enable the DUMMY phase of an operation.
      USR_DUMMY         : Boolean := False;
      --  Set this bit to enable enable the ADDR phase of an operation.
      USR_ADDR          : Boolean := False;
      --  Set this bit to enable enable the CMD phase of an operation.
      USR_COMMAND       : Boolean := True;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for USER_Register use record
      Reserved_0_8      at 0 range 0 .. 8;
      CK_OUT_EDGE       at 0 range 9 .. 9;
      Reserved_10_11    at 0 range 10 .. 11;
      FWRITE_DUAL       at 0 range 12 .. 12;
      FWRITE_QUAD       at 0 range 13 .. 13;
      FWRITE_DIO        at 0 range 14 .. 14;
      FWRITE_QIO        at 0 range 15 .. 15;
      Reserved_16_23    at 0 range 16 .. 23;
      USR_MISO_HIGHPART at 0 range 24 .. 24;
      USR_MOSI_HIGHPART at 0 range 25 .. 25;
      USR_DUMMY_IDLE    at 0 range 26 .. 26;
      USR_MOSI          at 0 range 27 .. 27;
      USR_MISO          at 0 range 28 .. 28;
      USR_DUMMY         at 0 range 29 .. 29;
      USR_ADDR          at 0 range 30 .. 30;
      USR_COMMAND       at 0 range 31 .. 31;
   end record;

   subtype USER1_USR_DUMMY_CYCLELEN_Field is ESP32S3_Registers.UInt6;
   subtype USER1_USR_ADDR_BITLEN_Field is ESP32S3_Registers.UInt6;

   --  SPI1 user1 register.
   type USER1_Register is record
      --  The SPI_CLK cycle length minus 1 of DUMMY phase.
      USR_DUMMY_CYCLELEN : USER1_USR_DUMMY_CYCLELEN_Field := 16#7#;
      --  unspecified
      Reserved_6_25      : ESP32S3_Registers.UInt20 := 16#0#;
      --  The length in bits of ADDR phase. The register value shall be
      --  (bit_num-1).
      USR_ADDR_BITLEN    : USER1_USR_ADDR_BITLEN_Field := 16#17#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for USER1_Register use record
      USR_DUMMY_CYCLELEN at 0 range 0 .. 5;
      Reserved_6_25      at 0 range 6 .. 25;
      USR_ADDR_BITLEN    at 0 range 26 .. 31;
   end record;

   subtype USER2_USR_COMMAND_VALUE_Field is ESP32S3_Registers.UInt16;
   subtype USER2_USR_COMMAND_BITLEN_Field is ESP32S3_Registers.UInt4;

   --  SPI1 user2 register.
   type USER2_Register is record
      --  The value of user defined(USR) command.
      USR_COMMAND_VALUE  : USER2_USR_COMMAND_VALUE_Field := 16#0#;
      --  unspecified
      Reserved_16_27     : ESP32S3_Registers.UInt12 := 16#0#;
      --  The length in bits of CMD phase. The register value shall be
      --  (bit_num-1)
      USR_COMMAND_BITLEN : USER2_USR_COMMAND_BITLEN_Field := 16#7#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for USER2_Register use record
      USR_COMMAND_VALUE  at 0 range 0 .. 15;
      Reserved_16_27     at 0 range 16 .. 27;
      USR_COMMAND_BITLEN at 0 range 28 .. 31;
   end record;

   subtype MOSI_DLEN_USR_MOSI_DBITLEN_Field is ESP32S3_Registers.UInt10;

   --  SPI1 write-data bit length register.
   type MOSI_DLEN_Register is record
      --  The length in bits of DOUT phase. The register value shall be
      --  (bit_num-1).
      USR_MOSI_DBITLEN : MOSI_DLEN_USR_MOSI_DBITLEN_Field := 16#0#;
      --  unspecified
      Reserved_10_31   : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MOSI_DLEN_Register use record
      USR_MOSI_DBITLEN at 0 range 0 .. 9;
      Reserved_10_31   at 0 range 10 .. 31;
   end record;

   subtype MISO_DLEN_USR_MISO_DBITLEN_Field is ESP32S3_Registers.UInt10;

   --  SPI1 read-data bit length register.
   type MISO_DLEN_Register is record
      --  The length in bits of DIN phase. The register value shall be
      --  (bit_num-1).
      USR_MISO_DBITLEN : MISO_DLEN_USR_MISO_DBITLEN_Field := 16#0#;
      --  unspecified
      Reserved_10_31   : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MISO_DLEN_Register use record
      USR_MISO_DBITLEN at 0 range 0 .. 9;
      Reserved_10_31   at 0 range 10 .. 31;
   end record;

   subtype RD_STATUS_STATUS_Field is ESP32S3_Registers.UInt16;
   subtype RD_STATUS_WB_MODE_Field is ESP32S3_Registers.Byte;

   --  SPI1 read control register.
   type RD_STATUS_Register is record
      --  The value is stored when set SPI_MEM_FLASH_RDSR bit and
      --  SPI_MEM_FLASH_RES bit.
      STATUS         : RD_STATUS_STATUS_Field := 16#0#;
      --  Mode bits in the flash fast read mode it is combined with
      --  SPI_MEM_FASTRD_MODE bit.
      WB_MODE        : RD_STATUS_WB_MODE_Field := 16#0#;
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RD_STATUS_Register use record
      STATUS         at 0 range 0 .. 15;
      WB_MODE        at 0 range 16 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   --  SPI1 misc register.
   type MISC_Register is record
      --  Set this bit to raise high SPI_CS pin, which means that the SPI
      --  device(flash) connected to SPI_CS is in low level when SPI1 transfer
      --  starts.
      CS0_DIS        : Boolean := False;
      --  Set this bit to raise high SPI_CS1 pin, which means that the SPI
      --  device(Ext_RAM) connected to SPI_CS1 is in low level when SPI1
      --  transfer starts.
      CS1_DIS        : Boolean := True;
      --  unspecified
      Reserved_2_8   : ESP32S3_Registers.UInt7 := 16#0#;
      --  1: SPI_CLK line is high when MSPI is idle. 0: SPI_CLK line is low
      --  when MSPI is idle.
      CK_IDLE_EDGE   : Boolean := False;
      --  SPI_CS line keep low when the bit is set.
      CS_KEEP_ACTIVE : Boolean := False;
      --  Set this bit to enable auto PER function. Hardware will sent out PER
      --  command if PES command is sent.
      AUTO_PER       : Boolean := False;
      --  unspecified
      Reserved_12_31 : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MISC_Register use record
      CS0_DIS        at 0 range 0 .. 0;
      CS1_DIS        at 0 range 1 .. 1;
      Reserved_2_8   at 0 range 2 .. 8;
      CK_IDLE_EDGE   at 0 range 9 .. 9;
      CS_KEEP_ACTIVE at 0 range 10 .. 10;
      AUTO_PER       at 0 range 11 .. 11;
      Reserved_12_31 at 0 range 12 .. 31;
   end record;

   --  SPI1 bit mode control register.
   type CACHE_FCTRL_Register is record
      --  unspecified
      Reserved_0_0        : ESP32S3_Registers.Bit := 16#0#;
      --  Set this bit to enable SPI1 transfer with 32 bits address. The value
      --  of SPI_MEM_USR_ADDR_BITLEN should be 31.
      CACHE_USR_CMD_4BYTE : Boolean := False;
      --  unspecified
      Reserved_2_2        : ESP32S3_Registers.Bit := 16#0#;
      --  When SPI1 accesses to flash or Ext_RAM, set this bit to enable 2-bm
      --  in DIN phase.
      FDIN_DUAL           : Boolean := False;
      --  When SPI1 accesses to flash or Ext_RAM, set this bit to enable 2-bm
      --  in DOUT phase.
      FDOUT_DUAL          : Boolean := False;
      --  When SPI1 accesses to flash or Ext_RAM, set this bit to enable 2-bm
      --  in ADDR phase.
      FADDR_DUAL          : Boolean := False;
      --  When SPI1 accesses to flash or Ext_RAM, set this bit to enable 4-bm
      --  in DIN phase.
      FDIN_QUAD           : Boolean := False;
      --  When SPI1 accesses to flash or Ext_RAM, set this bit to enable 4-bm
      --  in DOUT phase.
      FDOUT_QUAD          : Boolean := False;
      --  When SPI1 accesses to flash or Ext_RAM, set this bit to enable 4-bm
      --  in ADDR phase.
      FADDR_QUAD          : Boolean := False;
      --  unspecified
      Reserved_9_31       : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_FCTRL_Register use record
      Reserved_0_0        at 0 range 0 .. 0;
      CACHE_USR_CMD_4BYTE at 0 range 1 .. 1;
      Reserved_2_2        at 0 range 2 .. 2;
      FDIN_DUAL           at 0 range 3 .. 3;
      FDOUT_DUAL          at 0 range 4 .. 4;
      FADDR_DUAL          at 0 range 5 .. 5;
      FDIN_QUAD           at 0 range 6 .. 6;
      FDOUT_QUAD          at 0 range 7 .. 7;
      FADDR_QUAD          at 0 range 8 .. 8;
      Reserved_9_31       at 0 range 9 .. 31;
   end record;

   subtype FSM_ST_Field is ESP32S3_Registers.UInt3;

   --  SPI1 state machine(FSM) status register.
   type FSM_Register is record
      --  Read-only. The status of SPI1 state machine. 0: idle state(IDLE), 1:
      --  preparation state(PREP), 2: send command state(CMD), 3: send address
      --  state(ADDR), 4: red data state(DIN), 5:write data state(DOUT), 6:
      --  wait state(DUMMY), 7: done state(DONE).
      ST            : FSM_ST_Field;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FSM_Register use record
      ST            at 0 range 0 .. 2;
      Reserved_3_31 at 0 range 3 .. 31;
   end record;

   subtype FLASH_WAITI_CTRL_WAITI_CMD_Field is ESP32S3_Registers.Byte;
   subtype FLASH_WAITI_CTRL_WAITI_DUMMY_CYCLELEN_Field is
     ESP32S3_Registers.UInt6;

   --  SPI1 wait idle control register
   type FLASH_WAITI_CTRL_Register is record
      --  Set this bit to enable auto-waiting flash idle operation when
      --  PP/SE/BE/CE/WRSR/PES command is sent.
      WAITI_EN             : Boolean := False;
      --  Set this bit to enable DUMMY phase in auto wait flash idle
      --  transfer(RDSR).
      WAITI_DUMMY          : Boolean := False;
      --  The command value of auto wait flash idle transfer(RDSR).
      WAITI_CMD            : FLASH_WAITI_CTRL_WAITI_CMD_Field := 16#5#;
      --  The dummy cycle length when wait flash idle(RDSR).
      WAITI_DUMMY_CYCLELEN : FLASH_WAITI_CTRL_WAITI_DUMMY_CYCLELEN_Field :=
                              16#0#;
      --  unspecified
      Reserved_16_31       : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FLASH_WAITI_CTRL_Register use record
      WAITI_EN             at 0 range 0 .. 0;
      WAITI_DUMMY          at 0 range 1 .. 1;
      WAITI_CMD            at 0 range 2 .. 9;
      WAITI_DUMMY_CYCLELEN at 0 range 10 .. 15;
      Reserved_16_31       at 0 range 16 .. 31;
   end record;

   --  SPI1 flash suspend control register
   type FLASH_SUS_CMD_Register is record
      --  program erase resume bit, program erase suspend operation will be
      --  triggered when the bit is set. The bit will be cleared once the
      --  operation done.1: enable 0: disable.
      FLASH_PER         : Boolean := False;
      --  program erase suspend bit, program erase suspend operation will be
      --  triggered when the bit is set. The bit will be cleared once the
      --  operation done.1: enable 0: disable.
      FLASH_PES         : Boolean := False;
      --  Set this bit to add delay time after program erase resume(PER) is
      --  sent.
      FLASH_PER_WAIT_EN : Boolean := False;
      --  Set this bit to add delay time after program erase suspend(PES)
      --  command is sent.
      FLASH_PES_WAIT_EN : Boolean := False;
      --  Set this bit to enable PES transfer trigger PES transfer option.
      PES_PER_EN        : Boolean := False;
      --  1: Separate PER flash wait idle and PES flash wait idle. 0: Not
      --  separate.
      PESR_IDLE_EN      : Boolean := False;
      --  unspecified
      Reserved_6_31     : ESP32S3_Registers.UInt26 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FLASH_SUS_CMD_Register use record
      FLASH_PER         at 0 range 0 .. 0;
      FLASH_PES         at 0 range 1 .. 1;
      FLASH_PER_WAIT_EN at 0 range 2 .. 2;
      FLASH_PES_WAIT_EN at 0 range 3 .. 3;
      PES_PER_EN        at 0 range 4 .. 4;
      PESR_IDLE_EN      at 0 range 5 .. 5;
      Reserved_6_31     at 0 range 6 .. 31;
   end record;

   subtype FLASH_SUS_CTRL_FLASH_PER_COMMAND_Field is ESP32S3_Registers.Byte;
   subtype FLASH_SUS_CTRL_FLASH_PES_COMMAND_Field is ESP32S3_Registers.Byte;

   --  SPI1 flash suspend command register
   type FLASH_SUS_CTRL_Register is record
      --  Set this bit to enable auto-suspend function.
      FLASH_PES_EN      : Boolean := False;
      --  Program/Erase resume command value.
      FLASH_PER_COMMAND : FLASH_SUS_CTRL_FLASH_PER_COMMAND_Field := 16#7A#;
      --  Program/Erase suspend command value.
      FLASH_PES_COMMAND : FLASH_SUS_CTRL_FLASH_PES_COMMAND_Field := 16#75#;
      --  unspecified
      Reserved_17_31    : ESP32S3_Registers.UInt15 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FLASH_SUS_CTRL_Register use record
      FLASH_PES_EN      at 0 range 0 .. 0;
      FLASH_PER_COMMAND at 0 range 1 .. 8;
      FLASH_PES_COMMAND at 0 range 9 .. 16;
      Reserved_17_31    at 0 range 17 .. 31;
   end record;

   --  SPI1 flash suspend status register
   type SUS_STATUS_Register is record
      --  The status of flash suspend. This bit is set when PES command is
      --  sent, and cleared when PER is sent. Only used in SPI1.
      FLASH_SUS         : Boolean := False;
      --  unspecified
      Reserved_1_1      : ESP32S3_Registers.Bit := 16#0#;
      --  1: SPI1 waits (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 256) SPI_CLK cycles
      --  after HPM command is sent. 0: SPI1 waits
      --  (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 4) SPI_CLK cycles after HPM command
      --  is sent.
      FLASH_HPM_DLY_256 : Boolean := False;
      --  1: SPI1 waits (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 256) SPI_CLK cycles
      --  after RES command is sent. 0: SPI1 waits
      --  (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 4) SPI_CLK cycles after RES command
      --  is sent.
      FLASH_RES_DLY_256 : Boolean := False;
      --  1: SPI1 waits (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 256) SPI_CLK cycles
      --  after DP command is sent. 0: SPI1 waits
      --  (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 4) SPI_CLK cycles after DP command
      --  is sent.
      FLASH_DP_DLY_256  : Boolean := False;
      --  Valid when SPI_MEM_FLASH_PER_WAIT_EN is 1. 1: SPI1 waits
      --  (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 256) SPI_CLK cycles after PER
      --  command is sent. 0: SPI1 waits (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 4)
      --  SPI_CLK cycles after PER command is sent.
      FLASH_PER_DLY_256 : Boolean := False;
      --  Valid when SPI_MEM_FLASH_PES_WAIT_EN is 1. 1: SPI1 waits
      --  (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 256) SPI_CLK cycles after PES
      --  command is sent. 0: SPI1 waits (SPI_MEM_CS_HOLD_DELAY_RES[9:0] * 4)
      --  SPI_CLK cycles after PES command is sent.
      FLASH_PES_DLY_256 : Boolean := False;
      --  unspecified
      Reserved_7_31     : ESP32S3_Registers.UInt25 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SUS_STATUS_Register use record
      FLASH_SUS         at 0 range 0 .. 0;
      Reserved_1_1      at 0 range 1 .. 1;
      FLASH_HPM_DLY_256 at 0 range 2 .. 2;
      FLASH_RES_DLY_256 at 0 range 3 .. 3;
      FLASH_DP_DLY_256  at 0 range 4 .. 4;
      FLASH_PER_DLY_256 at 0 range 5 .. 5;
      FLASH_PES_DLY_256 at 0 range 6 .. 6;
      Reserved_7_31     at 0 range 7 .. 31;
   end record;

   subtype TIMING_CALI_EXTRA_DUMMY_CYCLELEN_Field is ESP32S3_Registers.UInt3;

   --  SPI1 timing compensation register when accesses to flash or Ext_RAM.
   type TIMING_CALI_Register is record
      --  unspecified
      Reserved_0_0         : ESP32S3_Registers.Bit := 16#0#;
      --  Set this bit to add extra SPI_CLK cycles in DUMMY phase for all
      --  reading operations.
      TIMING_CALI          : Boolean := False;
      --  Extra SPI_CLK cycles added in DUMMY phase for timing compensation.
      --  Active when SPI_MEM_TIMING_CALI bit is set.
      EXTRA_DUMMY_CYCLELEN : TIMING_CALI_EXTRA_DUMMY_CYCLELEN_Field := 16#0#;
      --  unspecified
      Reserved_5_31        : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMING_CALI_Register use record
      Reserved_0_0         at 0 range 0 .. 0;
      TIMING_CALI          at 0 range 1 .. 1;
      EXTRA_DUMMY_CYCLELEN at 0 range 2 .. 4;
      Reserved_5_31        at 0 range 5 .. 31;
   end record;

   subtype DDR_SPI_FMEM_OUTMINBYTELEN_Field is ESP32S3_Registers.UInt7;
   subtype DDR_SPI_FMEM_USR_DDR_DQS_THD_Field is ESP32S3_Registers.UInt7;

   --  SPI1 DDR control register
   type DDR_Register is record
      --  1: in DDR mode, 0: in SDR mode.
      SPI_FMEM_DDR_EN            : Boolean := False;
      --  Set the bit to enable variable dummy cycle in DDRmode.
      SPI_FMEM_VAR_DUMMY         : Boolean := False;
      --  Set the bit to reorder RX data of the word in DDR mode.
      SPI_FMEM_DDR_RDAT_SWP      : Boolean := False;
      --  Set the bit to reorder TX data of the word in DDR mode.
      SPI_FMEM_DDR_WDAT_SWP      : Boolean := False;
      --  the bit is used to disable dual edge in command phase when DDR mode.
      SPI_FMEM_DDR_CMD_DIS       : Boolean := False;
      --  It is the minimum output data length in the panda device.
      SPI_FMEM_OUTMINBYTELEN     : DDR_SPI_FMEM_OUTMINBYTELEN_Field := 16#1#;
      --  unspecified
      Reserved_12_13             : ESP32S3_Registers.UInt2 := 16#0#;
      --  The delay number of data strobe which from memory based on SPI_CLK.
      SPI_FMEM_USR_DDR_DQS_THD   : DDR_SPI_FMEM_USR_DDR_DQS_THD_Field :=
                                    16#0#;
      --  1: Use internal signal as data strobe, the strobe can not be delayed
      --  by input timing module. 0: Use input SPI_DQS signal from PAD as data
      --  strobe, the strobe can be delayed by input timing module
      SPI_FMEM_DDR_DQS_LOOP      : Boolean := False;
      --  When SPI_FMEM_DDR_DQS_LOOP and SPI_FMEM_DDR_EN are set, 1: Use
      --  internal SPI_CLK as data strobe. 0: Use internal ~SPI_CLK as data
      --  strobe. Otherwise this bit is not active.
      SPI_FMEM_DDR_DQS_LOOP_MODE : Boolean := False;
      --  unspecified
      Reserved_23_23             : ESP32S3_Registers.Bit := 16#0#;
      --  Set this bit to enable the differential SPI_CLK#.
      SPI_FMEM_CLK_DIFF_EN       : Boolean := False;
      --  Set this bit to enable the SPI HyperBus mode.
      SPI_FMEM_HYPERBUS_MODE     : Boolean := False;
      --  Set this bit to enable the input of SPI_DQS signal in SPI phases of
      --  CMD and ADDR.
      SPI_FMEM_DQS_CA_IN         : Boolean := False;
      --  Set this bit to enable the vary dummy function in SPI HyperBus mode,
      --  when SPI0 accesses flash or SPI1 accesses flash or sram.
      SPI_FMEM_HYPERBUS_DUMMY_2X : Boolean := False;
      --  Set this bit to invert SPI_DIFF when accesses to flash. .
      SPI_FMEM_CLK_DIFF_INV      : Boolean := False;
      --  Set this bit to enable octa_ram address out when accesses to flash,
      --  which means ADDR_OUT[31:0] = {spi_usr_addr_value[25:4], 6'd0,
      --  spi_usr_addr_value[3:1], 1'b0}.
      SPI_FMEM_OCTA_RAM_ADDR     : Boolean := False;
      --  Set this bit to enable HyperRAM address out when accesses to flash,
      --  which means ADDR_OUT[31:0] = {spi_usr_addr_value[19:4], 13'd0,
      --  spi_usr_addr_value[3:1]}.
      SPI_FMEM_HYPERBUS_CA       : Boolean := False;
      --  unspecified
      Reserved_31_31             : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DDR_Register use record
      SPI_FMEM_DDR_EN            at 0 range 0 .. 0;
      SPI_FMEM_VAR_DUMMY         at 0 range 1 .. 1;
      SPI_FMEM_DDR_RDAT_SWP      at 0 range 2 .. 2;
      SPI_FMEM_DDR_WDAT_SWP      at 0 range 3 .. 3;
      SPI_FMEM_DDR_CMD_DIS       at 0 range 4 .. 4;
      SPI_FMEM_OUTMINBYTELEN     at 0 range 5 .. 11;
      Reserved_12_13             at 0 range 12 .. 13;
      SPI_FMEM_USR_DDR_DQS_THD   at 0 range 14 .. 20;
      SPI_FMEM_DDR_DQS_LOOP      at 0 range 21 .. 21;
      SPI_FMEM_DDR_DQS_LOOP_MODE at 0 range 22 .. 22;
      Reserved_23_23             at 0 range 23 .. 23;
      SPI_FMEM_CLK_DIFF_EN       at 0 range 24 .. 24;
      SPI_FMEM_HYPERBUS_MODE     at 0 range 25 .. 25;
      SPI_FMEM_DQS_CA_IN         at 0 range 26 .. 26;
      SPI_FMEM_HYPERBUS_DUMMY_2X at 0 range 27 .. 27;
      SPI_FMEM_CLK_DIFF_INV      at 0 range 28 .. 28;
      SPI_FMEM_OCTA_RAM_ADDR     at 0 range 29 .. 29;
      SPI_FMEM_HYPERBUS_CA       at 0 range 30 .. 30;
      Reserved_31_31             at 0 range 31 .. 31;
   end record;

   --  SPI1 clk_gate register
   type CLOCK_GATE_Register is record
      --  Register clock gate enable signal. 1: Enable. 0: Disable.
      CLK_EN        : Boolean := True;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLOCK_GATE_Register use record
      CLK_EN        at 0 range 0 .. 0;
      Reserved_1_31 at 0 range 1 .. 31;
   end record;

   --  SPI1 interrupt enable register
   type INT_ENA_Register is record
      --  The enable bit for SPI_MEM_PER_END_INT interrupt.
      PER_END_INT_ENA         : Boolean := False;
      --  The enable bit for SPI_MEM_PES_END_INT interrupt.
      PES_END_INT_ENA         : Boolean := False;
      --  The enable bit for SPI_MEM_TOTAL_TRANS_END_INT interrupt.
      TOTAL_TRANS_END_INT_ENA : Boolean := False;
      --  The enable bit for SPI_MEM_BROWN_OUT_INT interrupt.
      BROWN_OUT_INT_ENA       : Boolean := False;
      --  unspecified
      Reserved_4_31           : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_Register use record
      PER_END_INT_ENA         at 0 range 0 .. 0;
      PES_END_INT_ENA         at 0 range 1 .. 1;
      TOTAL_TRANS_END_INT_ENA at 0 range 2 .. 2;
      BROWN_OUT_INT_ENA       at 0 range 3 .. 3;
      Reserved_4_31           at 0 range 4 .. 31;
   end record;

   --  SPI1 interrupt clear register
   type INT_CLR_Register is record
      --  Write-only. The clear bit for SPI_MEM_PER_END_INT interrupt.
      PER_END_INT_CLR         : Boolean := False;
      --  Write-only. The clear bit for SPI_MEM_PES_END_INT interrupt.
      PES_END_INT_CLR         : Boolean := False;
      --  Write-only. The clear bit for SPI_MEM_TOTAL_TRANS_END_INT interrupt.
      TOTAL_TRANS_END_INT_CLR : Boolean := False;
      --  Write-only. The status bit for SPI_MEM_BROWN_OUT_INT interrupt.
      BROWN_OUT_INT_CLR       : Boolean := False;
      --  unspecified
      Reserved_4_31           : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_Register use record
      PER_END_INT_CLR         at 0 range 0 .. 0;
      PES_END_INT_CLR         at 0 range 1 .. 1;
      TOTAL_TRANS_END_INT_CLR at 0 range 2 .. 2;
      BROWN_OUT_INT_CLR       at 0 range 3 .. 3;
      Reserved_4_31           at 0 range 4 .. 31;
   end record;

   --  SPI1 interrupt raw register
   type INT_RAW_Register is record
      --  The raw bit for SPI_MEM_PER_END_INT interrupt. 1: Triggered when Auto
      --  Resume command (0x7A) is sent and flash is resumed successfully. 0:
      --  Others.
      PER_END_INT_RAW         : Boolean := False;
      --  The raw bit for SPI_MEM_PES_END_INT interrupt.1: Triggered when Auto
      --  Suspend command (0x75) is sent and flash is suspended successfully.
      --  0: Others.
      PES_END_INT_RAW         : Boolean := False;
      --  The raw bit for SPI_MEM_TOTAL_TRANS_END_INT interrupt. 1: Triggered
      --  when SPI1 transfer is done and flash is already idle. When
      --  WRSR/PP/SE/BE/CE is sent and PES/PER command is sent, this bit is set
      --  when WRSR/PP/SE/BE/CE is success. 0: Others.
      TOTAL_TRANS_END_INT_RAW : Boolean := False;
      --  The raw bit for SPI_MEM_BROWN_OUT_INT interrupt. 1: Triggered
      --  condition is that chip is loosing power and RTC module sends out
      --  brown out close flash request to SPI1. After SPI1 sends out suspend
      --  command to flash, this interrupt is triggered and MSPI returns to
      --  idle state. 0: Others.
      BROWN_OUT_INT_RAW       : Boolean := False;
      --  unspecified
      Reserved_4_31           : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_Register use record
      PER_END_INT_RAW         at 0 range 0 .. 0;
      PES_END_INT_RAW         at 0 range 1 .. 1;
      TOTAL_TRANS_END_INT_RAW at 0 range 2 .. 2;
      BROWN_OUT_INT_RAW       at 0 range 3 .. 3;
      Reserved_4_31           at 0 range 4 .. 31;
   end record;

   --  SPI1 interrupt status register
   type INT_ST_Register is record
      --  Read-only. The status bit for SPI_MEM_PER_END_INT interrupt.
      PER_END_INT_ST         : Boolean;
      --  Read-only. The status bit for SPI_MEM_PES_END_INT interrupt.
      PES_END_INT_ST         : Boolean;
      --  Read-only. The status bit for SPI_MEM_TOTAL_TRANS_END_INT interrupt.
      TOTAL_TRANS_END_INT_ST : Boolean;
      --  Read-only. The status bit for SPI_MEM_BROWN_OUT_INT interrupt.
      BROWN_OUT_INT_ST       : Boolean;
      --  unspecified
      Reserved_4_31          : ESP32S3_Registers.UInt28;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ST_Register use record
      PER_END_INT_ST         at 0 range 0 .. 0;
      PES_END_INT_ST         at 0 range 1 .. 1;
      TOTAL_TRANS_END_INT_ST at 0 range 2 .. 2;
      BROWN_OUT_INT_ST       at 0 range 3 .. 3;
      Reserved_4_31          at 0 range 4 .. 31;
   end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt28;

   --  SPI0 version control register
   type DATE_Register is record
      --  SPI register version.
      DATE           : DATE_DATE_Field := 16#2101040#;
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

   --  SPI (Serial Peripheral Interface) Controller 1
   type SPI1_Peripheral is record
      --  SPI1 memory command register
      CMD              : aliased CMD_Register;
      --  SPI1 address register
      ADDR             : aliased ESP32S3_Registers.UInt32;
      --  SPI1 control register
      CTRL             : aliased CTRL_Register;
      --  SPI1 control1 register
      CTRL1            : aliased CTRL1_Register;
      --  SPI1 control2 register
      CTRL2            : aliased CTRL2_Register;
      --  SPI_CLK clock division register when SPI1 accesses to flash or
      --  Ext_RAM.
      CLOCK            : aliased CLOCK_Register;
      --  SPI1 user register.
      USER             : aliased USER_Register;
      --  SPI1 user1 register.
      USER1            : aliased USER1_Register;
      --  SPI1 user2 register.
      USER2            : aliased USER2_Register;
      --  SPI1 write-data bit length register.
      MOSI_DLEN        : aliased MOSI_DLEN_Register;
      --  SPI1 read-data bit length register.
      MISO_DLEN        : aliased MISO_DLEN_Register;
      --  SPI1 read control register.
      RD_STATUS        : aliased RD_STATUS_Register;
      --  SPI1 extended address register.
      EXT_ADDR         : aliased ESP32S3_Registers.UInt32;
      --  SPI1 misc register.
      MISC             : aliased MISC_Register;
      --  SPI1 CRC data register.
      TX_CRC           : aliased ESP32S3_Registers.UInt32;
      --  SPI1 bit mode control register.
      CACHE_FCTRL      : aliased CACHE_FCTRL_Register;
      --  SPI1 state machine(FSM) status register.
      FSM              : aliased FSM_Register;
      --  SPI1 memory data buffer0
      W0               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer1
      W1               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer2
      W2               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer3
      W3               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer4
      W4               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer5
      W5               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer6
      W6               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer7
      W7               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer8
      W8               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer9
      W9               : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer10
      W10              : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer11
      W11              : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer12
      W12              : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer13
      W13              : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer14
      W14              : aliased ESP32S3_Registers.UInt32;
      --  SPI1 memory data buffer15
      W15              : aliased ESP32S3_Registers.UInt32;
      --  SPI1 wait idle control register
      FLASH_WAITI_CTRL : aliased FLASH_WAITI_CTRL_Register;
      --  SPI1 flash suspend control register
      FLASH_SUS_CMD    : aliased FLASH_SUS_CMD_Register;
      --  SPI1 flash suspend command register
      FLASH_SUS_CTRL   : aliased FLASH_SUS_CTRL_Register;
      --  SPI1 flash suspend status register
      SUS_STATUS       : aliased SUS_STATUS_Register;
      --  SPI1 timing compensation register when accesses to flash or Ext_RAM.
      TIMING_CALI      : aliased TIMING_CALI_Register;
      --  SPI1 DDR control register
      DDR              : aliased DDR_Register;
      --  SPI1 clk_gate register
      CLOCK_GATE       : aliased CLOCK_GATE_Register;
      --  SPI1 interrupt enable register
      INT_ENA          : aliased INT_ENA_Register;
      --  SPI1 interrupt clear register
      INT_CLR          : aliased INT_CLR_Register;
      --  SPI1 interrupt raw register
      INT_RAW          : aliased INT_RAW_Register;
      --  SPI1 interrupt status register
      INT_ST           : aliased INT_ST_Register;
      --  SPI0 version control register
      DATE             : aliased DATE_Register;
   end record
     with Volatile;

   for SPI1_Peripheral use record
      CMD              at 16#0# range 0 .. 31;
      ADDR             at 16#4# range 0 .. 31;
      CTRL             at 16#8# range 0 .. 31;
      CTRL1            at 16#C# range 0 .. 31;
      CTRL2            at 16#10# range 0 .. 31;
      CLOCK            at 16#14# range 0 .. 31;
      USER             at 16#18# range 0 .. 31;
      USER1            at 16#1C# range 0 .. 31;
      USER2            at 16#20# range 0 .. 31;
      MOSI_DLEN        at 16#24# range 0 .. 31;
      MISO_DLEN        at 16#28# range 0 .. 31;
      RD_STATUS        at 16#2C# range 0 .. 31;
      EXT_ADDR         at 16#30# range 0 .. 31;
      MISC             at 16#34# range 0 .. 31;
      TX_CRC           at 16#38# range 0 .. 31;
      CACHE_FCTRL      at 16#3C# range 0 .. 31;
      FSM              at 16#54# range 0 .. 31;
      W0               at 16#58# range 0 .. 31;
      W1               at 16#5C# range 0 .. 31;
      W2               at 16#60# range 0 .. 31;
      W3               at 16#64# range 0 .. 31;
      W4               at 16#68# range 0 .. 31;
      W5               at 16#6C# range 0 .. 31;
      W6               at 16#70# range 0 .. 31;
      W7               at 16#74# range 0 .. 31;
      W8               at 16#78# range 0 .. 31;
      W9               at 16#7C# range 0 .. 31;
      W10              at 16#80# range 0 .. 31;
      W11              at 16#84# range 0 .. 31;
      W12              at 16#88# range 0 .. 31;
      W13              at 16#8C# range 0 .. 31;
      W14              at 16#90# range 0 .. 31;
      W15              at 16#94# range 0 .. 31;
      FLASH_WAITI_CTRL at 16#98# range 0 .. 31;
      FLASH_SUS_CMD    at 16#9C# range 0 .. 31;
      FLASH_SUS_CTRL   at 16#A0# range 0 .. 31;
      SUS_STATUS       at 16#A4# range 0 .. 31;
      TIMING_CALI      at 16#A8# range 0 .. 31;
      DDR              at 16#E0# range 0 .. 31;
      CLOCK_GATE       at 16#E8# range 0 .. 31;
      INT_ENA          at 16#F0# range 0 .. 31;
      INT_CLR          at 16#F4# range 0 .. 31;
      INT_RAW          at 16#F8# range 0 .. 31;
      INT_ST           at 16#FC# range 0 .. 31;
      DATE             at 16#3FC# range 0 .. 31;
   end record;

   --  SPI (Serial Peripheral Interface) Controller 1
   SPI1_Periph : aliased SPI1_Peripheral
     with Import, Address => SPI1_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.SPI1;
