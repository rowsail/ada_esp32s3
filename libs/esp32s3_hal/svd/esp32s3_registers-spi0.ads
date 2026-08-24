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

package ESP32S3_Registers.SPI0 is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  SPI0 control register.
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
      --  unspecified
      Reserved_10_12 : ESP32S3_Registers.UInt3 := 16#0#;
      --  This bit should be set when SPI_MEM_FREAD_QIO, SPI_MEM_FREAD_DIO,
      --  SPI_MEM_FREAD_QUAD or SPI_MEM_FREAD_DUAL is set.
      FASTRD_MODE    : Boolean := True;
      --  In hardware 0x3B read operation, DIN phase apply 2 signals. 1: enable
      --  0: disable.
      FREAD_DUAL     : Boolean := False;
      --  unspecified
      Reserved_15_17 : ESP32S3_Registers.UInt3 := 16#0#;
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
      --  unspecified
      Reserved_22_22 : ESP32S3_Registers.Bit := 16#0#;
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
      Reserved_10_12 at 0 range 10 .. 12;
      FASTRD_MODE    at 0 range 13 .. 13;
      FREAD_DUAL     at 0 range 14 .. 14;
      Reserved_15_17 at 0 range 15 .. 17;
      Q_POL          at 0 range 18 .. 18;
      D_POL          at 0 range 19 .. 19;
      FREAD_QUAD     at 0 range 20 .. 20;
      WP             at 0 range 21 .. 21;
      Reserved_22_22 at 0 range 22 .. 22;
      FREAD_DIO      at 0 range 23 .. 23;
      FREAD_QIO      at 0 range 24 .. 24;
      Reserved_25_31 at 0 range 25 .. 31;
   end record;

   subtype CTRL1_CLK_MODE_Field is ESP32S3_Registers.UInt2;

   --  SPI0 control 1 register.
   type CTRL1_Register is record
      --  SPI Bus clock (SPI_CLK) mode bits. 0: SPI Bus clock (SPI_CLK) is off
      --  when CS inactive 1: SPI_CLK is delayed one cycle after SPI_CS
      --  inactive 2: SPI_CLK is delayed two cycles after SPI_CS inactive 3:
      --  SPI_CLK is always on.
      CLK_MODE       : CTRL1_CLK_MODE_Field := 16#0#;
      --  unspecified
      Reserved_2_29  : ESP32S3_Registers.UInt28 := 16#0#;
      --  SPI0 RX FIFO reset signal. Set this bit and clear it before SPI0
      --  transfer starts.
      RXFIFO_RST     : Boolean := False;
      --  unspecified
      Reserved_31_31 : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTRL1_Register use record
      CLK_MODE       at 0 range 0 .. 1;
      Reserved_2_29  at 0 range 2 .. 29;
      RXFIFO_RST     at 0 range 30 .. 30;
      Reserved_31_31 at 0 range 31 .. 31;
   end record;

   subtype CTRL2_CS_SETUP_TIME_Field is ESP32S3_Registers.UInt5;
   subtype CTRL2_CS_HOLD_TIME_Field is ESP32S3_Registers.UInt5;
   subtype CTRL2_ECC_CS_HOLD_TIME_Field is ESP32S3_Registers.UInt3;
   subtype CTRL2_CS_HOLD_DELAY_Field is ESP32S3_Registers.UInt6;

   --  SPI0 control 2 register.
   type CTRL2_Register is record
      --  (cycles-1) of PREP phase by SPI_CLK, which is the SPI_CS setup time.
      --  These bits are combined with SPI_MEM_CS_SETUP bit.
      CS_SETUP_TIME        : CTRL2_CS_SETUP_TIME_Field := 16#1#;
      --  SPI Bus CS (SPI_CS) signal is delayed to inactive by SPI Bus clock
      --  (SPI_CLK), which is the SPI_CS hold time in non-ECC mode. These bits
      --  are combined with SPI_MEM_CS_HOLD bit.
      CS_HOLD_TIME         : CTRL2_CS_HOLD_TIME_Field := 16#1#;
      --  SPI_MEM_CS_HOLD_TIME + SPI_MEM_ECC_CS_HOLD_TIME is the SPI_CS hold
      --  cycle in ECC mode when accessed flash.
      ECC_CS_HOLD_TIME     : CTRL2_ECC_CS_HOLD_TIME_Field := 16#3#;
      --  1: MSPI skips page corner when accesses flash. 0: Not skip page
      --  corner when accesses flash.
      ECC_SKIP_PAGE_CORNER : Boolean := True;
      --  Set this bit to enable MSPI ECC 16 bytes data with 2 ECC bytes mode
      --  when accesses flash.
      ECC_16TO18_BYTE_EN   : Boolean := False;
      --  unspecified
      Reserved_15_24       : ESP32S3_Registers.UInt10 := 16#0#;
      --  These bits are used to set the minimum CS high time tSHSL between SPI
      --  burst transfer when accesses to flash. tSHSL is
      --  (SPI_MEM_CS_HOLD_DELAY[5:0] + 1) MSPI core clock cycles.
      CS_HOLD_DELAY        : CTRL2_CS_HOLD_DELAY_Field := 16#0#;
      --  The FSM will be reset.
      SYNC_RESET           : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTRL2_Register use record
      CS_SETUP_TIME        at 0 range 0 .. 4;
      CS_HOLD_TIME         at 0 range 5 .. 9;
      ECC_CS_HOLD_TIME     at 0 range 10 .. 12;
      ECC_SKIP_PAGE_CORNER at 0 range 13 .. 13;
      ECC_16TO18_BYTE_EN   at 0 range 14 .. 14;
      Reserved_15_24       at 0 range 15 .. 24;
      CS_HOLD_DELAY        at 0 range 25 .. 30;
      SYNC_RESET           at 0 range 31 .. 31;
   end record;

   subtype CLOCK_CLKCNT_L_Field is ESP32S3_Registers.Byte;
   subtype CLOCK_CLKCNT_H_Field is ESP32S3_Registers.Byte;
   subtype CLOCK_CLKCNT_N_Field is ESP32S3_Registers.Byte;

   --  SPI_CLK clock division register when SPI0 accesses to flash.
   type CLOCK_Register is record
      --  It must equal to the value of SPI_MEM_CLKCNT_N.
      CLKCNT_L       : CLOCK_CLKCNT_L_Field := 16#3#;
      --  It must be a floor value of ((SPI_MEM_CLKCNT_N+1)/2-1).
      CLKCNT_H       : CLOCK_CLKCNT_H_Field := 16#1#;
      --  When SPI0 accesses flash, f_SPI_CLK =
      --  f_MSPI_CORE_CLK/(SPI_MEM_CLKCNT_N+1)
      CLKCNT_N       : CLOCK_CLKCNT_N_Field := 16#3#;
      --  unspecified
      Reserved_24_30 : ESP32S3_Registers.UInt7 := 16#0#;
      --  When SPI0 accesses flash, set this bit in 1-division mode, f_SPI_CLK
      --  = f_MSPI_CORE_CLK.
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

   --  SPI0 user register.
   type USER_Register is record
      --  unspecified
      Reserved_0_5   : ESP32S3_Registers.UInt6 := 16#0#;
      --  Set this bit to keep SPI_CS low when MSPI is in DONE state.
      CS_HOLD        : Boolean := False;
      --  Set this bit to keep SPI_CS low when MSPI is in PREP state.
      CS_SETUP       : Boolean := False;
      --  unspecified
      Reserved_8_8   : ESP32S3_Registers.Bit := 16#0#;
      --  This bit, combined with SPI_MEM_CK_IDLE_EDGE bit, is used to change
      --  the clock mode 0~3 of SPI_CLK.
      CK_OUT_EDGE    : Boolean := False;
      --  unspecified
      Reserved_10_25 : ESP32S3_Registers.UInt16 := 16#0#;
      --  SPI_CLK is disabled(No clock edges) in DUMMY phase when the bit is
      --  enable.
      USR_DUMMY_IDLE : Boolean := False;
      --  unspecified
      Reserved_27_28 : ESP32S3_Registers.UInt2 := 16#0#;
      --  This bit enable the DUMMY phase of an SPI transfer.
      USR_DUMMY      : Boolean := False;
      --  unspecified
      Reserved_30_31 : ESP32S3_Registers.UInt2 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for USER_Register use record
      Reserved_0_5   at 0 range 0 .. 5;
      CS_HOLD        at 0 range 6 .. 6;
      CS_SETUP       at 0 range 7 .. 7;
      Reserved_8_8   at 0 range 8 .. 8;
      CK_OUT_EDGE    at 0 range 9 .. 9;
      Reserved_10_25 at 0 range 10 .. 25;
      USR_DUMMY_IDLE at 0 range 26 .. 26;
      Reserved_27_28 at 0 range 27 .. 28;
      USR_DUMMY      at 0 range 29 .. 29;
      Reserved_30_31 at 0 range 30 .. 31;
   end record;

   subtype USER1_USR_DUMMY_CYCLELEN_Field is ESP32S3_Registers.UInt6;
   subtype USER1_USR_ADDR_BITLEN_Field is ESP32S3_Registers.UInt6;

   --  SPI0 user1 register.
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

   --  SPI0 user2 register.
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

   subtype RD_STATUS_WB_MODE_Field is ESP32S3_Registers.Byte;

   --  SPI0 read control register.
   type RD_STATUS_Register is record
      --  unspecified
      Reserved_0_15  : ESP32S3_Registers.UInt16 := 16#0#;
      --  Mode bits in the flash fast read mode it is combined with
      --  SPI_MEM_FASTRD_MODE bit.
      WB_MODE        : RD_STATUS_WB_MODE_Field := 16#0#;
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RD_STATUS_Register use record
      Reserved_0_15  at 0 range 0 .. 15;
      WB_MODE        at 0 range 16 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   --  SPI0 misc register
   type MISC_Register is record
      --  unspecified
      Reserved_0_6   : ESP32S3_Registers.UInt7 := 16#0#;
      --  Flash is connected to SPI SUBPIN bus.
      FSUB_PIN       : Boolean := False;
      --  Ext_RAM is connected to SPI SUBPIN bus.
      SSUB_PIN       : Boolean := False;
      --  1: SPI_CLK line is high when idle. 0: SPI_CLK line is low when idle
      CK_IDLE_EDGE   : Boolean := False;
      --  SPI_CS line keep low when the bit is set.
      CS_KEEP_ACTIVE : Boolean := False;
      --  unspecified
      Reserved_11_31 : ESP32S3_Registers.UInt21 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MISC_Register use record
      Reserved_0_6   at 0 range 0 .. 6;
      FSUB_PIN       at 0 range 7 .. 7;
      SSUB_PIN       at 0 range 8 .. 8;
      CK_IDLE_EDGE   at 0 range 9 .. 9;
      CS_KEEP_ACTIVE at 0 range 10 .. 10;
      Reserved_11_31 at 0 range 11 .. 31;
   end record;

   --  SPI0 external RAM bit mode control register.
   type CACHE_FCTRL_Register is record
      --  Set this bit to enable Cache's access and SPI0's transfer.
      CACHE_REQ_EN        : Boolean := False;
      --  Set this bit to enable SPI0 read flash with 32 bits address. The
      --  value of SPI_MEM_USR_ADDR_BITLEN should be 31.
      CACHE_USR_CMD_4BYTE : Boolean := False;
      --  1: The command value of SPI0 reads flash is
      --  SPI_MEM_USR_COMMAND_VALUE. 0: Hardware read command value, controlled
      --  by SPI_MEM_FREAD_QIO, SPI_MEM_FREAD_DIO, SPI_MEM_FREAD_QUAD,
      --  SPI_MEM_FREAD_DUAL and SPI_MEM_FASTRD_MODE bits.
      CACHE_FLASH_USR_CMD : Boolean := False;
      --  When SPI0 accesses to flash, set this bit to enable 2-bm in DIN
      --  phase.
      FDIN_DUAL           : Boolean := False;
      --  When SPI0 accesses to flash, set this bit to enable 2-bm in DOUT
      --  phase.
      FDOUT_DUAL          : Boolean := False;
      --  When SPI0 accesses to flash, set this bit to enable 2-bm in ADDR
      --  phase.
      FADDR_DUAL          : Boolean := False;
      --  When SPI0 accesses to flash, set this bit to enable 4-bm in DIN
      --  phase.
      FDIN_QUAD           : Boolean := False;
      --  When SPI0 accesses to flash, set this bit to enable 4-bm in DOUT
      --  phase.
      FDOUT_QUAD          : Boolean := False;
      --  When SPI0 accesses to flash, set this bit to enable 4-bm in ADDR
      --  phase.
      FADDR_QUAD          : Boolean := False;
      --  unspecified
      Reserved_9_31       : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_FCTRL_Register use record
      CACHE_REQ_EN        at 0 range 0 .. 0;
      CACHE_USR_CMD_4BYTE at 0 range 1 .. 1;
      CACHE_FLASH_USR_CMD at 0 range 2 .. 2;
      FDIN_DUAL           at 0 range 3 .. 3;
      FDOUT_DUAL          at 0 range 4 .. 4;
      FADDR_DUAL          at 0 range 5 .. 5;
      FDIN_QUAD           at 0 range 6 .. 6;
      FDOUT_QUAD          at 0 range 7 .. 7;
      FADDR_QUAD          at 0 range 8 .. 8;
      Reserved_9_31       at 0 range 9 .. 31;
   end record;

   subtype CACHE_SCTRL_SRAM_RDUMMY_CYCLELEN_Field is ESP32S3_Registers.UInt6;
   subtype CACHE_SCTRL_SRAM_ADDR_BITLEN_Field is ESP32S3_Registers.UInt6;
   subtype CACHE_SCTRL_SRAM_WDUMMY_CYCLELEN_Field is ESP32S3_Registers.UInt6;

   --  SPI0 external RAM control register
   type CACHE_SCTRL_Register is record
      --  Set this bit to enable SPI0 read Ext_RAM with 32 bits address. The
      --  value of SPI_MEM_SRAM_ADDR_BITLEN should be 31.
      CACHE_USR_SCMD_4BYTE : Boolean := False;
      --  Set the bit to enable 2-bm in all the phases of SPI0 Ext_RAM
      --  transfer.
      USR_SRAM_DIO         : Boolean := False;
      --  Set the bit to enable QPI mode in all SPI0 Ext_RAM transfer.
      USR_SRAM_QIO         : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable DUMMY phase in
      --  write operations.
      USR_WR_SRAM_DUMMY    : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable DUMMY phase in
      --  read operations.
      USR_RD_SRAM_DUMMY    : Boolean := True;
      --  1: The command value of SPI0 read Ext_RAM is
      --  SPI_MEM_CACHE_SRAM_USR_WR_CMD_VALUE. 0: The value is 0x2.
      CACHE_SRAM_USR_RCMD  : Boolean := True;
      --  When SPI0 accesses to Ext_RAM, it is the SPI_CLK cycles minus 1 of
      --  DUMMY phase in read data transfer.
      SRAM_RDUMMY_CYCLELEN : CACHE_SCTRL_SRAM_RDUMMY_CYCLELEN_Field := 16#1#;
      --  unspecified
      Reserved_12_13       : ESP32S3_Registers.UInt2 := 16#0#;
      --  When SPI0 accesses to Ext_RAM, it is the length in bits of ADDR
      --  phase. The register value shall be (bit_num-1).
      SRAM_ADDR_BITLEN     : CACHE_SCTRL_SRAM_ADDR_BITLEN_Field := 16#17#;
      --  1: The command value of SPI0 write Ext_RAM is
      --  SPI_MEM_CACHE_SRAM_USR_RD_CMD_VALUE. 0: The value is 0x3.
      CACHE_SRAM_USR_WCMD  : Boolean := True;
      --  Set the bit to enable OPI mode in all SPI0 Ext_RAM transfer.
      SRAM_OCT             : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, it is the SPI_CLK cycles minus 1 of
      --  DUMMY phase in write data transfer.
      SRAM_WDUMMY_CYCLELEN : CACHE_SCTRL_SRAM_WDUMMY_CYCLELEN_Field := 16#1#;
      --  unspecified
      Reserved_28_31       : ESP32S3_Registers.UInt4 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CACHE_SCTRL_Register use record
      CACHE_USR_SCMD_4BYTE at 0 range 0 .. 0;
      USR_SRAM_DIO         at 0 range 1 .. 1;
      USR_SRAM_QIO         at 0 range 2 .. 2;
      USR_WR_SRAM_DUMMY    at 0 range 3 .. 3;
      USR_RD_SRAM_DUMMY    at 0 range 4 .. 4;
      CACHE_SRAM_USR_RCMD  at 0 range 5 .. 5;
      SRAM_RDUMMY_CYCLELEN at 0 range 6 .. 11;
      Reserved_12_13       at 0 range 12 .. 13;
      SRAM_ADDR_BITLEN     at 0 range 14 .. 19;
      CACHE_SRAM_USR_WCMD  at 0 range 20 .. 20;
      SRAM_OCT             at 0 range 21 .. 21;
      SRAM_WDUMMY_CYCLELEN at 0 range 22 .. 27;
      Reserved_28_31       at 0 range 28 .. 31;
   end record;

   subtype SRAM_CMD_SCLK_MODE_Field is ESP32S3_Registers.UInt2;
   subtype SRAM_CMD_SWB_MODE_Field is ESP32S3_Registers.Byte;

   --  SPI0 external RAM mode control register
   type SRAM_CMD_Register is record
      --  SPI_CLK mode bits when SPI0 accesses to Ext_RAM. 0: SPI_CLK is off
      --  when CS inactive 1: SPI_CLK is delayed one cycle after CS inactive 2:
      --  SPI_CLK is delayed two cycles after CS inactive 3: SPI_CLK is always
      --  on.
      SCLK_MODE      : SRAM_CMD_SCLK_MODE_Field := 16#0#;
      --  Mode bits when SPI0 accesses to Ext_RAM.
      SWB_MODE       : SRAM_CMD_SWB_MODE_Field := 16#0#;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 2-bm in DIN
      --  phase.
      SDIN_DUAL      : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 2-bm in DOUT
      --  phase.
      SDOUT_DUAL     : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 2-bm in ADDR
      --  phase.
      SADDR_DUAL     : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 2-bm in CMD
      --  phase.
      SCMD_DUAL      : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 4-bm in DIN
      --  phase.
      SDIN_QUAD      : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 4-bm in DOUT
      --  phase.
      SDOUT_QUAD     : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 4-bm in ADDR
      --  phase.
      SADDR_QUAD     : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 4-bm in CMD
      --  phase.
      SCMD_QUAD      : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 8-bm in DIN
      --  phase.
      SDIN_OCT       : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 8-bm in DOUT
      --  phase.
      SDOUT_OCT      : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 8-bm in ADDR
      --  phase.
      SADDR_OCT      : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, set this bit to enable 8-bm in CMD
      --  phase.
      SCMD_OCT       : Boolean := False;
      --  When SPI0 accesses to Ext_RAM, in the DUMMY phase the signal level of
      --  SPI bus is output by the SPI0 controller.
      SDUMMY_OUT     : Boolean := False;
      --  unspecified
      Reserved_23_31 : ESP32S3_Registers.UInt9 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SRAM_CMD_Register use record
      SCLK_MODE      at 0 range 0 .. 1;
      SWB_MODE       at 0 range 2 .. 9;
      SDIN_DUAL      at 0 range 10 .. 10;
      SDOUT_DUAL     at 0 range 11 .. 11;
      SADDR_DUAL     at 0 range 12 .. 12;
      SCMD_DUAL      at 0 range 13 .. 13;
      SDIN_QUAD      at 0 range 14 .. 14;
      SDOUT_QUAD     at 0 range 15 .. 15;
      SADDR_QUAD     at 0 range 16 .. 16;
      SCMD_QUAD      at 0 range 17 .. 17;
      SDIN_OCT       at 0 range 18 .. 18;
      SDOUT_OCT      at 0 range 19 .. 19;
      SADDR_OCT      at 0 range 20 .. 20;
      SCMD_OCT       at 0 range 21 .. 21;
      SDUMMY_OUT     at 0 range 22 .. 22;
      Reserved_23_31 at 0 range 23 .. 31;
   end record;

   subtype SRAM_DRD_CMD_CACHE_SRAM_USR_RD_CMD_VALUE_Field is
     ESP32S3_Registers.UInt16;
   subtype SRAM_DRD_CMD_CACHE_SRAM_USR_RD_CMD_BITLEN_Field is
     ESP32S3_Registers.UInt4;

   --  SPI0 external RAM DDR read command control register
   type SRAM_DRD_CMD_Register is record
      --  When SPI0 reads Ext_RAM, it is the command value of CMD phase.
      CACHE_SRAM_USR_RD_CMD_VALUE  : SRAM_DRD_CMD_CACHE_SRAM_USR_RD_CMD_VALUE_Field :=
                                      16#0#;
      --  unspecified
      Reserved_16_27               : ESP32S3_Registers.UInt12 := 16#0#;
      --  When SPI0 reads Ext_RAM, it is the length in bits of CMD phase. The
      --  register value shall be (bit_num-1).
      CACHE_SRAM_USR_RD_CMD_BITLEN : SRAM_DRD_CMD_CACHE_SRAM_USR_RD_CMD_BITLEN_Field :=
                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SRAM_DRD_CMD_Register use record
      CACHE_SRAM_USR_RD_CMD_VALUE  at 0 range 0 .. 15;
      Reserved_16_27               at 0 range 16 .. 27;
      CACHE_SRAM_USR_RD_CMD_BITLEN at 0 range 28 .. 31;
   end record;

   subtype SRAM_DWR_CMD_CACHE_SRAM_USR_WR_CMD_VALUE_Field is
     ESP32S3_Registers.UInt16;
   subtype SRAM_DWR_CMD_CACHE_SRAM_USR_WR_CMD_BITLEN_Field is
     ESP32S3_Registers.UInt4;

   --  SPI0 external RAM DDR write command control register
   type SRAM_DWR_CMD_Register is record
      --  When SPI0 writes Ext_RAM, it is the command value of CMD phase.
      CACHE_SRAM_USR_WR_CMD_VALUE  : SRAM_DWR_CMD_CACHE_SRAM_USR_WR_CMD_VALUE_Field :=
                                      16#0#;
      --  unspecified
      Reserved_16_27               : ESP32S3_Registers.UInt12 := 16#0#;
      --  When SPI0 writes Ext_RAM, it is the length in bits of CMD phase. The
      --  register value shall be (bit_num-1).
      CACHE_SRAM_USR_WR_CMD_BITLEN : SRAM_DWR_CMD_CACHE_SRAM_USR_WR_CMD_BITLEN_Field :=
                                      16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SRAM_DWR_CMD_Register use record
      CACHE_SRAM_USR_WR_CMD_VALUE  at 0 range 0 .. 15;
      Reserved_16_27               at 0 range 16 .. 27;
      CACHE_SRAM_USR_WR_CMD_BITLEN at 0 range 28 .. 31;
   end record;

   subtype SRAM_CLK_SCLKCNT_L_Field is ESP32S3_Registers.Byte;
   subtype SRAM_CLK_SCLKCNT_H_Field is ESP32S3_Registers.Byte;
   subtype SRAM_CLK_SCLKCNT_N_Field is ESP32S3_Registers.Byte;

   --  SPI_CLK clock division register when SPI0 accesses to Ext_RAM.
   type SRAM_CLK_Register is record
      --  It must equal to the value of SPI_MEM_SCLKCNT_N.
      SCLKCNT_L       : SRAM_CLK_SCLKCNT_L_Field := 16#3#;
      --  It must be a floor value of ((SPI_MEM_SCLKCNT_N+1)/2-1).
      SCLKCNT_H       : SRAM_CLK_SCLKCNT_H_Field := 16#1#;
      --  When SPI0 accesses to Ext_RAM, f_SPI_CLK =
      --  f_MSPI_CORE_CLK/(SPI_MEM_SCLKCNT_N+1)
      SCLKCNT_N       : SRAM_CLK_SCLKCNT_N_Field := 16#3#;
      --  unspecified
      Reserved_24_30  : ESP32S3_Registers.UInt7 := 16#0#;
      --  When SPI0 accesses to Ext_RAM, set this bit in 1-division mode,
      --  f_SPI_CLK = f_MSPI_CORE_CLK.
      SCLK_EQU_SYSCLK : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SRAM_CLK_Register use record
      SCLKCNT_L       at 0 range 0 .. 7;
      SCLKCNT_H       at 0 range 8 .. 15;
      SCLKCNT_N       at 0 range 16 .. 23;
      Reserved_24_30  at 0 range 24 .. 30;
      SCLK_EQU_SYSCLK at 0 range 31 .. 31;
   end record;

   subtype FSM_ST_Field is ESP32S3_Registers.UInt3;

   --  SPI0 state machine(FSM) status register.
   type FSM_Register is record
      --  Read-only. The status of SPI0 state machine. 0: idle state(IDLE), 1:
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

   subtype TIMING_CALI_EXTRA_DUMMY_CYCLELEN_Field is ESP32S3_Registers.UInt3;

   --  SPI0 timing compensation register when accesses to flash.
   type TIMING_CALI_Register is record
      --  Set this bit to power on HCLK. When PLL is powered on, the frequency
      --  of HCLK equals to that of PLL. Otherwise, the frequency equals to
      --  that of XTAL.
      TIMING_CLK_ENA       : Boolean := False;
      --  Set this bit to add extra SPI_CLK cycles in DUMMY phase for all
      --  reading operations.
      TIMING_CALI          : Boolean := False;
      --  Extra SPI_CLK cycles added in DUMMY phase for timing compensation,
      --  when SPI0 accesses to flash. Active when SPI_MEM_TIMING_CALI bit is
      --  set.
      EXTRA_DUMMY_CYCLELEN : TIMING_CALI_EXTRA_DUMMY_CYCLELEN_Field := 16#0#;
      --  unspecified
      Reserved_5_31        : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TIMING_CALI_Register use record
      TIMING_CLK_ENA       at 0 range 0 .. 0;
      TIMING_CALI          at 0 range 1 .. 1;
      EXTRA_DUMMY_CYCLELEN at 0 range 2 .. 4;
      Reserved_5_31        at 0 range 5 .. 31;
   end record;

   subtype DIN_MODE_DIN0_MODE_Field is ESP32S3_Registers.UInt3;
   subtype DIN_MODE_DIN1_MODE_Field is ESP32S3_Registers.UInt3;
   subtype DIN_MODE_DIN2_MODE_Field is ESP32S3_Registers.UInt3;
   subtype DIN_MODE_DIN3_MODE_Field is ESP32S3_Registers.UInt3;
   subtype DIN_MODE_DIN4_MODE_Field is ESP32S3_Registers.UInt3;
   subtype DIN_MODE_DIN5_MODE_Field is ESP32S3_Registers.UInt3;
   subtype DIN_MODE_DIN6_MODE_Field is ESP32S3_Registers.UInt3;
   subtype DIN_MODE_DIN7_MODE_Field is ESP32S3_Registers.UInt3;
   subtype DIN_MODE_DINS_MODE_Field is ESP32S3_Registers.UInt3;

   --  MSPI input timing delay mode control register when accesses to flash.
   type DIN_MODE_Register is record
      --  SPI_D input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DIN0_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DIN0_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DIN0_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DIN0_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DIN0_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DIN0_MODE      : DIN_MODE_DIN0_MODE_Field := 16#0#;
      --  SPI_Q input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DIN3_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DIN3_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DIN3_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DIN3_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DIN3_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DIN1_MODE      : DIN_MODE_DIN1_MODE_Field := 16#0#;
      --  SPI_WP input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DIN6_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DIN6_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DIN6_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DIN6_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DIN6_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DIN2_MODE      : DIN_MODE_DIN2_MODE_Field := 16#0#;
      --  SPI_HD input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DIN9_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DIN9_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DIN9_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DIN9_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DIN9_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DIN3_MODE      : DIN_MODE_DIN3_MODE_Field := 16#0#;
      --  SPI_IO4 input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DIN12_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DIN12_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DIN12_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DIN12_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DIN12_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DIN4_MODE      : DIN_MODE_DIN4_MODE_Field := 16#0#;
      --  SPI_IO5 input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DIN15_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DIN15_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DIN15_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DIN15_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DIN15_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DIN5_MODE      : DIN_MODE_DIN5_MODE_Field := 16#0#;
      --  SPI_IO6 input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DIN18_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DIN18_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DIN18_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DIN18_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DIN18_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DIN6_MODE      : DIN_MODE_DIN6_MODE_Field := 16#0#;
      --  SPI_IO7 input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DIN21_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DIN21_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DIN21_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DIN21_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DIN21_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DIN7_MODE      : DIN_MODE_DIN7_MODE_Field := 16#0#;
      --  SPI_DQS input delay mode. 0: No delay. 1: Delay for
      --  (SPI_MEM_DINS_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_MEM_DINS_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_MEM_DINS_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_MEM_DINS_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_MEM_DINS_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      DINS_MODE      : DIN_MODE_DINS_MODE_Field := 16#0#;
      --  unspecified
      Reserved_27_31 : ESP32S3_Registers.UInt5 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIN_MODE_Register use record
      DIN0_MODE      at 0 range 0 .. 2;
      DIN1_MODE      at 0 range 3 .. 5;
      DIN2_MODE      at 0 range 6 .. 8;
      DIN3_MODE      at 0 range 9 .. 11;
      DIN4_MODE      at 0 range 12 .. 14;
      DIN5_MODE      at 0 range 15 .. 17;
      DIN6_MODE      at 0 range 18 .. 20;
      DIN7_MODE      at 0 range 21 .. 23;
      DINS_MODE      at 0 range 24 .. 26;
      Reserved_27_31 at 0 range 27 .. 31;
   end record;

   subtype DIN_NUM_DIN0_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN1_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN2_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN3_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN4_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN5_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN6_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN7_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DINS_NUM_Field is ESP32S3_Registers.UInt2;

   --  MSPI input timing delay number control register when accesses to flash.
   type DIN_NUM_Register is record
      --  SPI_D input delay number.
      DIN0_NUM       : DIN_NUM_DIN0_NUM_Field := 16#0#;
      --  SPI_Q input delay number.
      DIN1_NUM       : DIN_NUM_DIN1_NUM_Field := 16#0#;
      --  SPI_WP input delay number.
      DIN2_NUM       : DIN_NUM_DIN2_NUM_Field := 16#0#;
      --  SPI_HD input delay number.
      DIN3_NUM       : DIN_NUM_DIN3_NUM_Field := 16#0#;
      --  SPI_IO4 input delay number.
      DIN4_NUM       : DIN_NUM_DIN4_NUM_Field := 16#0#;
      --  SPI_IO5 input delay number.
      DIN5_NUM       : DIN_NUM_DIN5_NUM_Field := 16#0#;
      --  SPI_IO6 input delay number.
      DIN6_NUM       : DIN_NUM_DIN6_NUM_Field := 16#0#;
      --  SPI_IO7 input delay number.
      DIN7_NUM       : DIN_NUM_DIN7_NUM_Field := 16#0#;
      --  SPI_DQS input delay number.
      DINS_NUM       : DIN_NUM_DINS_NUM_Field := 16#0#;
      --  unspecified
      Reserved_18_31 : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIN_NUM_Register use record
      DIN0_NUM       at 0 range 0 .. 1;
      DIN1_NUM       at 0 range 2 .. 3;
      DIN2_NUM       at 0 range 4 .. 5;
      DIN3_NUM       at 0 range 6 .. 7;
      DIN4_NUM       at 0 range 8 .. 9;
      DIN5_NUM       at 0 range 10 .. 11;
      DIN6_NUM       at 0 range 12 .. 13;
      DIN7_NUM       at 0 range 14 .. 15;
      DINS_NUM       at 0 range 16 .. 17;
      Reserved_18_31 at 0 range 18 .. 31;
   end record;

   --  MSPI output timing delay mode control register when accesses to flash.
   type DOUT_MODE_Register is record
      --  SPI_D output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUT0_MODE    : Boolean := False;
      --  SPI_Q output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUT1_MODE    : Boolean := False;
      --  SPI_WP output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUT2_MODE    : Boolean := False;
      --  SPI_HD output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUT3_MODE    : Boolean := False;
      --  SPI_IO4 output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUT4_MODE    : Boolean := False;
      --  SPI_IO5 output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUT5_MODE    : Boolean := False;
      --  SPI_IO6 output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUT6_MODE    : Boolean := False;
      --  SPI_IO7 output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUT7_MODE    : Boolean := False;
      --  SPI_DQS output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      DOUTS_MODE    : Boolean := False;
      --  unspecified
      Reserved_9_31 : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DOUT_MODE_Register use record
      DOUT0_MODE    at 0 range 0 .. 0;
      DOUT1_MODE    at 0 range 1 .. 1;
      DOUT2_MODE    at 0 range 2 .. 2;
      DOUT3_MODE    at 0 range 3 .. 3;
      DOUT4_MODE    at 0 range 4 .. 4;
      DOUT5_MODE    at 0 range 5 .. 5;
      DOUT6_MODE    at 0 range 6 .. 6;
      DOUT7_MODE    at 0 range 7 .. 7;
      DOUTS_MODE    at 0 range 8 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype SPI_SMEM_TIMING_CALI_SPI_SMEM_EXTRA_DUMMY_CYCLELEN_Field is
     ESP32S3_Registers.UInt3;

   --  SPI0 Ext_RAM timing compensation register.
   type SPI_SMEM_TIMING_CALI_Register is record
      --  Set this bit to power on HCLK. When PLL is powered on, the frequency
      --  of HCLK equals to that of PLL. Otherwise, the frequency equals to
      --  that of XTAL.
      SPI_SMEM_TIMING_CLK_ENA       : Boolean := False;
      --  Set this bit to add extra SPI_CLK cycles in DUMMY phase for all
      --  reading operations.
      SPI_SMEM_TIMING_CALI          : Boolean := False;
      --  Extra SPI_CLK cycles added in DUMMY phase for timing compensation,
      --  when SPI0 accesses to Ext_RAM. Active when SPI_SMEM_TIMING_CALI bit
      --  is set.
      SPI_SMEM_EXTRA_DUMMY_CYCLELEN : SPI_SMEM_TIMING_CALI_SPI_SMEM_EXTRA_DUMMY_CYCLELEN_Field :=
                                       16#0#;
      --  unspecified
      Reserved_5_31                 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SPI_SMEM_TIMING_CALI_Register use record
      SPI_SMEM_TIMING_CLK_ENA       at 0 range 0 .. 0;
      SPI_SMEM_TIMING_CALI          at 0 range 1 .. 1;
      SPI_SMEM_EXTRA_DUMMY_CYCLELEN at 0 range 2 .. 4;
      Reserved_5_31                 at 0 range 5 .. 31;
   end record;

   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DIN0_MODE_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DIN1_MODE_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DIN2_MODE_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DIN3_MODE_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DIN4_MODE_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DIN5_MODE_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DIN6_MODE_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DIN7_MODE_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_DIN_MODE_SPI_SMEM_DINS_MODE_Field is
     ESP32S3_Registers.UInt3;

   --  MSPI input timing delay mode control register when accesses to Ext_RAM.
   type SPI_SMEM_DIN_MODE_Register is record
      --  SPI_D input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DIN0_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_SMEM_DIN0_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_SMEM_DIN0_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_SMEM_DIN0_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_SMEM_DIN0_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DIN0_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DIN0_MODE_Field :=
                            16#0#;
      --  SPI_Q input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DIN3_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_SMEM_DIN3_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_SMEM_DIN3_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_SMEM_DIN3_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_SMEM_DIN3_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DIN1_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DIN1_MODE_Field :=
                            16#0#;
      --  SPI_WP input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DIN6_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_SMEM_DIN6_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_SMEM_DIN6_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_SMEM_DIN6_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_SMEM_DIN6_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DIN2_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DIN2_MODE_Field :=
                            16#0#;
      --  SPI_HD input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DIN9_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_SMEM_DIN9_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_SMEM_DIN9_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_SMEM_DIN9_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_SMEM_DIN9_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DIN3_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DIN3_MODE_Field :=
                            16#0#;
      --  SPI_IO4 input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DIN12_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2:
      --  Delay for (SPI_SMEM_DIN12_NUM+1) cycles at HCLK positive edge and one
      --  cycle at MSPI_CORE_CLK positive edge. 3: Delay for
      --  (SPI_SMEM_DIN12_NUM+1) cycles at HCLK positive edge and one cycle at
      --  MSPI_CORE_CLK negative edge. 4: Delay for (SPI_SMEM_DIN12_NUM+1)
      --  cycles at HCLK negative edge and one cycle at MSPI_CORE_CLK positive
      --  edge. 5: Delay for (SPI_SMEM_DIN12_NUM+1) cycles at HCLK negative
      --  edge and one cycle at MSPI_CORE_CLK negative edge.
      SPI_SMEM_DIN4_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DIN4_MODE_Field :=
                            16#0#;
      --  SPI_IO5 input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DIN15_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2:
      --  Delay for (SPI_SMEM_DIN15_NUM+1) cycles at HCLK positive edge and one
      --  cycle at MSPI_CORE_CLK positive edge. 3: Delay for
      --  (SPI_SMEM_DIN15_NUM+1) cycles at HCLK positive edge and one cycle at
      --  MSPI_CORE_CLK negative edge. 4: Delay for (SPI_SMEM_DIN15_NUM+1)
      --  cycles at HCLK negative edge and one cycle at MSPI_CORE_CLK positive
      --  edge. 5: Delay for (SPI_SMEM_DIN15_NUM+1) cycles at HCLK negative
      --  edge and one cycle at MSPI_CORE_CLK negative edge.
      SPI_SMEM_DIN5_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DIN5_MODE_Field :=
                            16#0#;
      --  SPI_IO6 input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DIN18_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2:
      --  Delay for (SPI_SMEM_DIN18_NUM+1) cycles at HCLK positive edge and one
      --  cycle at MSPI_CORE_CLK positive edge. 3: Delay for
      --  (SPI_SMEM_DIN18_NUM+1) cycles at HCLK positive edge and one cycle at
      --  MSPI_CORE_CLK negative edge. 4: Delay for (SPI_SMEM_DIN18_NUM+1)
      --  cycles at HCLK negative edge and one cycle at MSPI_CORE_CLK positive
      --  edge. 5: Delay for (SPI_SMEM_DIN18_NUM+1) cycles at HCLK negative
      --  edge and one cycle at MSPI_CORE_CLK negative edge.
      SPI_SMEM_DIN6_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DIN6_MODE_Field :=
                            16#0#;
      --  SPI_IO7 input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DIN21_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2:
      --  Delay for (SPI_SMEM_DIN21_NUM+1) cycles at HCLK positive edge and one
      --  cycle at MSPI_CORE_CLK positive edge. 3: Delay for
      --  (SPI_SMEM_DIN21_NUM+1) cycles at HCLK positive edge and one cycle at
      --  MSPI_CORE_CLK negative edge. 4: Delay for (SPI_SMEM_DIN21_NUM+1)
      --  cycles at HCLK negative edge and one cycle at MSPI_CORE_CLK positive
      --  edge. 5: Delay for (SPI_SMEM_DIN21_NUM+1) cycles at HCLK negative
      --  edge and one cycle at MSPI_CORE_CLK negative edge.
      SPI_SMEM_DIN7_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DIN7_MODE_Field :=
                            16#0#;
      --  SPI_DQS input delay mode. 0: No delay. 1: Delay for
      --  (SPI_SMEM_DINS_NUM+1) cycles at MSPI_CORE_CLK negative edge. 2: Delay
      --  for (SPI_SMEM_DINS_NUM+1) cycles at HCLK positive edge and one cycle
      --  at MSPI_CORE_CLK positive edge. 3: Delay for (SPI_SMEM_DINS_NUM+1)
      --  cycles at HCLK positive edge and one cycle at MSPI_CORE_CLK negative
      --  edge. 4: Delay for (SPI_SMEM_DINS_NUM+1) cycles at HCLK negative edge
      --  and one cycle at MSPI_CORE_CLK positive edge. 5: Delay for
      --  (SPI_SMEM_DINS_NUM+1) cycles at HCLK negative edge and one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DINS_MODE : SPI_SMEM_DIN_MODE_SPI_SMEM_DINS_MODE_Field :=
                            16#0#;
      --  unspecified
      Reserved_27_31     : ESP32S3_Registers.UInt5 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SPI_SMEM_DIN_MODE_Register use record
      SPI_SMEM_DIN0_MODE at 0 range 0 .. 2;
      SPI_SMEM_DIN1_MODE at 0 range 3 .. 5;
      SPI_SMEM_DIN2_MODE at 0 range 6 .. 8;
      SPI_SMEM_DIN3_MODE at 0 range 9 .. 11;
      SPI_SMEM_DIN4_MODE at 0 range 12 .. 14;
      SPI_SMEM_DIN5_MODE at 0 range 15 .. 17;
      SPI_SMEM_DIN6_MODE at 0 range 18 .. 20;
      SPI_SMEM_DIN7_MODE at 0 range 21 .. 23;
      SPI_SMEM_DINS_MODE at 0 range 24 .. 26;
      Reserved_27_31     at 0 range 27 .. 31;
   end record;

   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DIN0_NUM_Field is ESP32S3_Registers.UInt2;
   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DIN1_NUM_Field is ESP32S3_Registers.UInt2;
   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DIN2_NUM_Field is ESP32S3_Registers.UInt2;
   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DIN3_NUM_Field is ESP32S3_Registers.UInt2;
   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DIN4_NUM_Field is ESP32S3_Registers.UInt2;
   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DIN5_NUM_Field is ESP32S3_Registers.UInt2;
   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DIN6_NUM_Field is ESP32S3_Registers.UInt2;
   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DIN7_NUM_Field is ESP32S3_Registers.UInt2;
   subtype SPI_SMEM_DIN_NUM_SPI_SMEM_DINS_NUM_Field is ESP32S3_Registers.UInt2;

   --  MSPI input timing delay number control register when accesses to
   --  Ext_RAM.
   type SPI_SMEM_DIN_NUM_Register is record
      --  SPI_D input delay number.
      SPI_SMEM_DIN0_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DIN0_NUM_Field := 16#0#;
      --  SPI_Q input delay number.
      SPI_SMEM_DIN1_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DIN1_NUM_Field := 16#0#;
      --  SPI_WP input delay number.
      SPI_SMEM_DIN2_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DIN2_NUM_Field := 16#0#;
      --  SPI_HD input delay number.
      SPI_SMEM_DIN3_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DIN3_NUM_Field := 16#0#;
      --  SPI_IO4 input delay number.
      SPI_SMEM_DIN4_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DIN4_NUM_Field := 16#0#;
      --  SPI_IO5 input delay number.
      SPI_SMEM_DIN5_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DIN5_NUM_Field := 16#0#;
      --  SPI_IO6 input delay number.
      SPI_SMEM_DIN6_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DIN6_NUM_Field := 16#0#;
      --  SPI_IO7 input delay number.
      SPI_SMEM_DIN7_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DIN7_NUM_Field := 16#0#;
      --  SPI_DQS input delay number.
      SPI_SMEM_DINS_NUM : SPI_SMEM_DIN_NUM_SPI_SMEM_DINS_NUM_Field := 16#0#;
      --  unspecified
      Reserved_18_31    : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SPI_SMEM_DIN_NUM_Register use record
      SPI_SMEM_DIN0_NUM at 0 range 0 .. 1;
      SPI_SMEM_DIN1_NUM at 0 range 2 .. 3;
      SPI_SMEM_DIN2_NUM at 0 range 4 .. 5;
      SPI_SMEM_DIN3_NUM at 0 range 6 .. 7;
      SPI_SMEM_DIN4_NUM at 0 range 8 .. 9;
      SPI_SMEM_DIN5_NUM at 0 range 10 .. 11;
      SPI_SMEM_DIN6_NUM at 0 range 12 .. 13;
      SPI_SMEM_DIN7_NUM at 0 range 14 .. 15;
      SPI_SMEM_DINS_NUM at 0 range 16 .. 17;
      Reserved_18_31    at 0 range 18 .. 31;
   end record;

   --  MSPI output timing delay mode control register when accesses to Ext_RAM.
   type SPI_SMEM_DOUT_MODE_Register is record
      --  SPI_D output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUT0_MODE : Boolean := False;
      --  SPI_Q output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUT1_MODE : Boolean := False;
      --  SPI_WP output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUT2_MODE : Boolean := False;
      --  SPI_HD output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUT3_MODE : Boolean := False;
      --  SPI_IO4 output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUT4_MODE : Boolean := False;
      --  SPI_IO5 output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUT5_MODE : Boolean := False;
      --  SPI_IO6 output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUT6_MODE : Boolean := False;
      --  SPI_IO7 output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUT7_MODE : Boolean := False;
      --  SPI_DQS output delay mode. 0: No delay. 1: Delay one cycle at
      --  MSPI_CORE_CLK negative edge.
      SPI_SMEM_DOUTS_MODE : Boolean := False;
      --  unspecified
      Reserved_9_31       : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SPI_SMEM_DOUT_MODE_Register use record
      SPI_SMEM_DOUT0_MODE at 0 range 0 .. 0;
      SPI_SMEM_DOUT1_MODE at 0 range 1 .. 1;
      SPI_SMEM_DOUT2_MODE at 0 range 2 .. 2;
      SPI_SMEM_DOUT3_MODE at 0 range 3 .. 3;
      SPI_SMEM_DOUT4_MODE at 0 range 4 .. 4;
      SPI_SMEM_DOUT5_MODE at 0 range 5 .. 5;
      SPI_SMEM_DOUT6_MODE at 0 range 6 .. 6;
      SPI_SMEM_DOUT7_MODE at 0 range 7 .. 7;
      SPI_SMEM_DOUTS_MODE at 0 range 8 .. 8;
      Reserved_9_31       at 0 range 9 .. 31;
   end record;

   subtype ECC_CTRL_ECC_ERR_INT_NUM_Field is ESP32S3_Registers.Byte;

   --  MSPI ECC control register
   type ECC_CTRL_Register is record
      --  Set the error times of MSPI ECC read to generate MSPI
      --  SPI_MEM_ECC_ERR_INT interrupt.
      ECC_ERR_INT_NUM         : ECC_CTRL_ECC_ERR_INT_NUM_Field := 16#A#;
      --  Set this bit to calculate the error times of MSPI ECC read when
      --  accesses to flash.
      SPI_FMEM_ECC_ERR_INT_EN : Boolean := False;
      --  unspecified
      Reserved_9_31           : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ECC_CTRL_Register use record
      ECC_ERR_INT_NUM         at 0 range 0 .. 7;
      SPI_FMEM_ECC_ERR_INT_EN at 0 range 8 .. 8;
      Reserved_9_31           at 0 range 9 .. 31;
   end record;

   subtype ECC_ERR_BIT_ECC_DATA_ERR_BIT_Field is ESP32S3_Registers.UInt7;
   subtype ECC_ERR_BIT_ECC_CHK_ERR_BIT_Field is ESP32S3_Registers.UInt3;
   subtype ECC_ERR_BIT_ECC_ERR_CNT_Field is ESP32S3_Registers.Byte;

   --  MSPI ECC error bits register
   type ECC_ERR_BIT_Register is record
      --  unspecified
      Reserved_0_5     : ESP32S3_Registers.UInt6;
      --  Read-only. It records the first ECC data error bit number when
      --  SPI_FMEM_ECC_ERR_INT_EN/SPI_SMEM_ECC_ERR_INT_EN is set and accessed
      --  to flash/Ext_RAM. The value ranges from 0~127, corresponding to the
      --  bit number in 16 data bytes. It is cleared by SPI_MEM_ECC_ERR_INT_CLR
      --  bit.
      ECC_DATA_ERR_BIT : ECC_ERR_BIT_ECC_DATA_ERR_BIT_Field;
      --  Read-only. When SPI_MEM_ECC_BYTE_ERR is set, these bits show the
      --  error bit number of ECC byte.
      ECC_CHK_ERR_BIT  : ECC_ERR_BIT_ECC_CHK_ERR_BIT_Field;
      --  Read-only. It records the first ECC byte error when
      --  SPI_FMEM_ECC_ERR_INT_EN/SPI_SMEM_ECC_ERR_INT_EN is set and accessed
      --  to flash/Ext_RAM. It is cleared by SPI_MEM_ECC_ERR_INT_CLR bit.
      ECC_BYTE_ERR     : Boolean;
      --  Read-only. This bits show the error times of MSPI ECC read, including
      --  ECC byte error and data byte error. It is cleared by when
      --  SPI_MEM_ECC_ERR_INT_CLR bit is set.
      ECC_ERR_CNT      : ECC_ERR_BIT_ECC_ERR_CNT_Field;
      --  unspecified
      Reserved_25_31   : ESP32S3_Registers.UInt7;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ECC_ERR_BIT_Register use record
      Reserved_0_5     at 0 range 0 .. 5;
      ECC_DATA_ERR_BIT at 0 range 6 .. 12;
      ECC_CHK_ERR_BIT  at 0 range 13 .. 15;
      ECC_BYTE_ERR     at 0 range 16 .. 16;
      ECC_ERR_CNT      at 0 range 17 .. 24;
      Reserved_25_31   at 0 range 25 .. 31;
   end record;

   subtype SPI_SMEM_AC_SPI_SMEM_CS_SETUP_TIME_Field is ESP32S3_Registers.UInt5;
   subtype SPI_SMEM_AC_SPI_SMEM_CS_HOLD_TIME_Field is ESP32S3_Registers.UInt5;
   subtype SPI_SMEM_AC_SPI_SMEM_ECC_CS_HOLD_TIME_Field is
     ESP32S3_Registers.UInt3;
   subtype SPI_SMEM_AC_SPI_SMEM_CS_HOLD_DELAY_Field is ESP32S3_Registers.UInt6;

   --  MSPI external RAM ECC and SPI CS timing control register
   type SPI_SMEM_AC_Register is record
      --  Set this bit to keep SPI_CS low when MSPI is in PREP state.
      SPI_SMEM_CS_SETUP             : Boolean := False;
      --  Set this bit to keep SPI_CS low when MSPI is in DONE state.
      SPI_SMEM_CS_HOLD              : Boolean := False;
      --  (cycles-1) of PREP phase by SPI_CLK, which is the SPI_CS setup time.
      --  These bits are combined with SPI_MEM_CS_SETUP bit.
      SPI_SMEM_CS_SETUP_TIME        : SPI_SMEM_AC_SPI_SMEM_CS_SETUP_TIME_Field :=
                                       16#1#;
      --  SPI Bus CS (SPI_CS) signal is delayed to inactive by SPI Bus clock
      --  (SPI_CLK), which is the SPI_CS hold time in non-ECC mode. These bits
      --  are combined with SPI_MEM_CS_HOLD bit.
      SPI_SMEM_CS_HOLD_TIME         : SPI_SMEM_AC_SPI_SMEM_CS_HOLD_TIME_Field :=
                                       16#1#;
      --  SPI_SMEM_CS_HOLD_TIME + SPI_SMEM_ECC_CS_HOLD_TIME is the MSPI CS hold
      --  cycles in ECC mode when accesses to external RAM.
      SPI_SMEM_ECC_CS_HOLD_TIME     : SPI_SMEM_AC_SPI_SMEM_ECC_CS_HOLD_TIME_Field :=
                                       16#3#;
      --  1: MSPI skips page corner when accesses to external RAM. 0: Not skip
      --  page corner when accesses to external RAM.
      SPI_SMEM_ECC_SKIP_PAGE_CORNER : Boolean := True;
      --  Set this bit to enable MSPI ECC 16 bytes data with 2 ECC bytes mode
      --  when accesses to external RAM.
      SPI_SMEM_ECC_16TO18_BYTE_EN   : Boolean := False;
      --  unspecified
      Reserved_17_23                : ESP32S3_Registers.UInt7 := 16#0#;
      --  Set this bit to calculate the error times of MSPI ECC read when
      --  accesses to external RAM.
      SPI_SMEM_ECC_ERR_INT_EN       : Boolean := False;
      --  These bits are used to set the minimum CS high time tSHSL between SPI
      --  burst transfer when accesses to external RAM. tSHSL is
      --  (SPI_SMEM_CS_HOLD_DELAY[5:0] + 1) MSPI core clock cycles.
      SPI_SMEM_CS_HOLD_DELAY        : SPI_SMEM_AC_SPI_SMEM_CS_HOLD_DELAY_Field :=
                                       16#0#;
      --  unspecified
      Reserved_31_31                : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SPI_SMEM_AC_Register use record
      SPI_SMEM_CS_SETUP             at 0 range 0 .. 0;
      SPI_SMEM_CS_HOLD              at 0 range 1 .. 1;
      SPI_SMEM_CS_SETUP_TIME        at 0 range 2 .. 6;
      SPI_SMEM_CS_HOLD_TIME         at 0 range 7 .. 11;
      SPI_SMEM_ECC_CS_HOLD_TIME     at 0 range 12 .. 14;
      SPI_SMEM_ECC_SKIP_PAGE_CORNER at 0 range 15 .. 15;
      SPI_SMEM_ECC_16TO18_BYTE_EN   at 0 range 16 .. 16;
      Reserved_17_23                at 0 range 17 .. 23;
      SPI_SMEM_ECC_ERR_INT_EN       at 0 range 24 .. 24;
      SPI_SMEM_CS_HOLD_DELAY        at 0 range 25 .. 30;
      Reserved_31_31                at 0 range 31 .. 31;
   end record;

   subtype DDR_SPI_FMEM_OUTMINBYTELEN_Field is ESP32S3_Registers.UInt7;
   subtype DDR_SPI_FMEM_USR_DDR_DQS_THD_Field is ESP32S3_Registers.UInt7;

   --  SPI0 flash DDR mode control register
   type DDR_Register is record
      --  1: in ddr mode, 0 in sdr mode
      SPI_FMEM_DDR_EN            : Boolean := False;
      --  Set the bit to enable variable dummy cycle in DDR mode.
      SPI_FMEM_VAR_DUMMY         : Boolean := False;
      --  Set the bit to reorder RX data of the word in DDR mode.
      SPI_FMEM_DDR_RDAT_SWP      : Boolean := False;
      --  Set the bit to swap TX data of a word in DDR mode.
      SPI_FMEM_DDR_WDAT_SWP      : Boolean := False;
      --  the bit is used to disable dual edge in CMD phase when ddr mode.
      SPI_FMEM_DDR_CMD_DIS       : Boolean := False;
      --  It is the minimum output data length in the panda device.
      SPI_FMEM_OUTMINBYTELEN     : DDR_SPI_FMEM_OUTMINBYTELEN_Field := 16#1#;
      --  Set this bit to mask the first or the last byte in MSPI ECC DDR write
      --  mode, when accesses to flash.
      SPI_FMEM_TX_DDR_MSK_EN     : Boolean := True;
      --  Set this bit to mask the first or the last byte in MSPI ECC DDR read
      --  mode, when accesses to flash.
      SPI_FMEM_RX_DDR_MSK_EN     : Boolean := True;
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
      --  when SPI0 accesses to flash or SPI1 accesses flash or sram.
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
      SPI_FMEM_TX_DDR_MSK_EN     at 0 range 12 .. 12;
      SPI_FMEM_RX_DDR_MSK_EN     at 0 range 13 .. 13;
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

   subtype SPI_SMEM_DDR_SPI_SMEM_OUTMINBYTELEN_Field is
     ESP32S3_Registers.UInt7;
   subtype SPI_SMEM_DDR_SPI_SMEM_USR_DDR_DQS_THD_Field is
     ESP32S3_Registers.UInt7;

   --  SPI0 external RAM DDR mode control register
   type SPI_SMEM_DDR_Register is record
      --  1: in ddr mode, 0 in sdr mode
      EN                         : Boolean := False;
      --  Set the bit to enable variable dummy cycle in spi ddr mode.
      SPI_SMEM_VAR_DUMMY         : Boolean := False;
      --  Set the bit to reorder rx data of the word in spi ddr mode.
      RDAT_SWP                   : Boolean := False;
      --  Set the bit to reorder tx data of the word in spi ddr mode.
      WDAT_SWP                   : Boolean := False;
      --  the bit is used to disable dual edge in CMD phase when ddr mode.
      CMD_DIS                    : Boolean := False;
      --  It is the minimum output data length in the ddr psram.
      SPI_SMEM_OUTMINBYTELEN     : SPI_SMEM_DDR_SPI_SMEM_OUTMINBYTELEN_Field :=
                                    16#1#;
      --  Set this bit to mask the first or the last byte in MSPI ECC DDR write
      --  mode, when accesses to external RAM.
      SPI_SMEM_TX_DDR_MSK_EN     : Boolean := True;
      --  Set this bit to mask the first or the last byte in MSPI ECC DDR read
      --  mode, when accesses to external RAM.
      SPI_SMEM_RX_DDR_MSK_EN     : Boolean := True;
      --  The delay number of data strobe which from memory based on SPI_CLK.
      SPI_SMEM_USR_DDR_DQS_THD   : SPI_SMEM_DDR_SPI_SMEM_USR_DDR_DQS_THD_Field :=
                                    16#0#;
      --  1: Use internal signal as data strobe, the strobe can not be delayed
      --  by input timing module. 0: Use input SPI_DQS signal from PAD as data
      --  strobe, the strobe can be delayed by input timing module
      DQS_LOOP                   : Boolean := False;
      --  When SPI_SMEM_DDR_DQS_LOOP and SPI_SMEM_DDR_EN are set, 1: Use
      --  internal SPI_CLK as data strobe. 0: Use internal ~SPI_CLK as data
      --  strobe. Otherwise this bit is not active.
      DQS_LOOP_MODE              : Boolean := False;
      --  unspecified
      Reserved_23_23             : ESP32S3_Registers.Bit := 16#0#;
      --  Set this bit to enable the differential SPI_CLK#.
      SPI_SMEM_CLK_DIFF_EN       : Boolean := False;
      --  Set this bit to enable the SPI HyperBus mode.
      SPI_SMEM_HYPERBUS_MODE     : Boolean := False;
      --  Set this bit to enable the input of SPI_DQS signal in SPI phases of
      --  CMD and ADDR.
      SPI_SMEM_DQS_CA_IN         : Boolean := False;
      --  Set this bit to enable the vary dummy function in SPI HyperBus mode,
      --  when SPI0 accesses to flash or SPI1 accesses flash or sram.
      SPI_SMEM_HYPERBUS_DUMMY_2X : Boolean := False;
      --  Set this bit to invert SPI_DIFF when accesses to external RAM. .
      SPI_SMEM_CLK_DIFF_INV      : Boolean := False;
      --  Set this bit to enable octa_ram address out when accesses to external
      --  RAM, which means ADDR_OUT[31:0] = {spi_usr_addr_value[25:4], 6'd0,
      --  spi_usr_addr_value[3:1], 1'b0}.
      SPI_SMEM_OCTA_RAM_ADDR     : Boolean := False;
      --  Set this bit to enable HyperRAM address out when accesses to external
      --  RAM, which means ADDR_OUT[31:0] = {spi_usr_addr_value[19:4], 13'd0,
      --  spi_usr_addr_value[3:1]}.
      SPI_SMEM_HYPERBUS_CA       : Boolean := False;
      --  unspecified
      Reserved_31_31             : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SPI_SMEM_DDR_Register use record
      EN                         at 0 range 0 .. 0;
      SPI_SMEM_VAR_DUMMY         at 0 range 1 .. 1;
      RDAT_SWP                   at 0 range 2 .. 2;
      WDAT_SWP                   at 0 range 3 .. 3;
      CMD_DIS                    at 0 range 4 .. 4;
      SPI_SMEM_OUTMINBYTELEN     at 0 range 5 .. 11;
      SPI_SMEM_TX_DDR_MSK_EN     at 0 range 12 .. 12;
      SPI_SMEM_RX_DDR_MSK_EN     at 0 range 13 .. 13;
      SPI_SMEM_USR_DDR_DQS_THD   at 0 range 14 .. 20;
      DQS_LOOP                   at 0 range 21 .. 21;
      DQS_LOOP_MODE              at 0 range 22 .. 22;
      Reserved_23_23             at 0 range 23 .. 23;
      SPI_SMEM_CLK_DIFF_EN       at 0 range 24 .. 24;
      SPI_SMEM_HYPERBUS_MODE     at 0 range 25 .. 25;
      SPI_SMEM_DQS_CA_IN         at 0 range 26 .. 26;
      SPI_SMEM_HYPERBUS_DUMMY_2X at 0 range 27 .. 27;
      SPI_SMEM_CLK_DIFF_INV      at 0 range 28 .. 28;
      SPI_SMEM_OCTA_RAM_ADDR     at 0 range 29 .. 29;
      SPI_SMEM_HYPERBUS_CA       at 0 range 30 .. 30;
      Reserved_31_31             at 0 range 31 .. 31;
   end record;

   --  SPI0 clk_gate register
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

   subtype CORE_CLK_SEL_CORE_CLK_SEL_Field is ESP32S3_Registers.UInt2;

   --  SPI0 module clock select register
   type CORE_CLK_SEL_Register is record
      --  When the digital system clock selects PLL clock and the frequency of
      --  PLL clock is 480MHz, the value of SPI_MEM_CORE_CLK_SEL: 0: SPI0/1
      --  module clock (MSPI_CORE_CLK) is 80MHz. 1: MSPI_CORE_CLK is 120MHz. 2:
      --  MSPI_CORE_CLK is 160MHz. 3: MSPI_CORE_CLK is 240MHz. When the digital
      --  system clock selects PLL clock and the frequency of PLL clock is
      --  320MHz, the value of SPI_MEM_CORE_CLK_SEL: 0: MSPI_CORE_CLK is 80MHz.
      --  1: MSPI_CORE_CLK is 80MHz. 2: MSPI_CORE_CLK 160MHz. 3: Not used.
      CORE_CLK_SEL  : CORE_CLK_SEL_CORE_CLK_SEL_Field := 16#0#;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CORE_CLK_SEL_Register use record
      CORE_CLK_SEL  at 0 range 0 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   --  SPI1 interrupt enable register
   type INT_ENA_Register is record
      --  unspecified
      Reserved_0_1            : ESP32S3_Registers.UInt2 := 16#0#;
      --  The enable bit for SPI_MEM_TOTAL_TRANS_END_INT interrupt.
      TOTAL_TRANS_END_INT_ENA : Boolean := False;
      --  unspecified
      Reserved_3_3            : ESP32S3_Registers.Bit := 16#0#;
      --  The enable bit for SPI_MEM_ECC_ERR_INT interrupt.
      ECC_ERR_INT_ENA         : Boolean := False;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_Register use record
      Reserved_0_1            at 0 range 0 .. 1;
      TOTAL_TRANS_END_INT_ENA at 0 range 2 .. 2;
      Reserved_3_3            at 0 range 3 .. 3;
      ECC_ERR_INT_ENA         at 0 range 4 .. 4;
      Reserved_5_31           at 0 range 5 .. 31;
   end record;

   --  SPI1 interrupt clear register
   type INT_CLR_Register is record
      --  unspecified
      Reserved_0_1            : ESP32S3_Registers.UInt2 := 16#0#;
      --  Write-only. The clear bit for SPI_MEM_TOTAL_TRANS_END_INT interrupt.
      TOTAL_TRANS_END_INT_CLR : Boolean := False;
      --  unspecified
      Reserved_3_3            : ESP32S3_Registers.Bit := 16#0#;
      --  Write-only. The clear bit for SPI_MEM_ECC_ERR_INT interrupt.
      --  SPI_MEM_ECC_ERR_ADDR and SPI_MEM_ECC_ERR_CNT will be cleared by the
      --  pulse of this bit.
      ECC_ERR_INT_CLR         : Boolean := False;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_Register use record
      Reserved_0_1            at 0 range 0 .. 1;
      TOTAL_TRANS_END_INT_CLR at 0 range 2 .. 2;
      Reserved_3_3            at 0 range 3 .. 3;
      ECC_ERR_INT_CLR         at 0 range 4 .. 4;
      Reserved_5_31           at 0 range 5 .. 31;
   end record;

   --  SPI1 interrupt raw register
   type INT_RAW_Register is record
      --  unspecified
      Reserved_0_1            : ESP32S3_Registers.UInt2 := 16#0#;
      --  The raw bit for SPI_MEM_TOTAL_TRANS_END_INT interrupt. 1: Triggered
      --  when SPI1 transfer is done and flash is already idle. When
      --  WRSR/PP/SE/BE/CE is sent and PES/PER command is sent, this bit is set
      --  when WRSR/PP/SE/BE/CE is success. 0: Others.
      TOTAL_TRANS_END_INT_RAW : Boolean := False;
      --  unspecified
      Reserved_3_3            : ESP32S3_Registers.Bit := 16#0#;
      --  The raw bit for SPI_MEM_ECC_ERR_INT interrupt. When
      --  APB_CTRL_FECC_ERR_INT_EN is set and APB_CTRL_SECC_ERR_INT_EN is
      --  cleared, this bit is triggered when the error times of SPI0/1 ECC
      --  read flash are equal or bigger than APB_CTRL_ECC_ERR_INT_NUM. When
      --  APB_CTRL_FECC_ERR_INT_EN is cleared and APB_CTRL_SECC_ERR_INT_EN is
      --  set, this bit is triggered when the error times of SPI0/1 ECC read
      --  external RAM are equal or bigger than APB_CTRL_ECC_ERR_INT_NUM. When
      --  APB_CTRL_FECC_ERR_INT_EN and APB_CTRL_SECC_ERR_INT_EN are set, this
      --  bit is triggered when the total error times of SPI0/1 ECC read
      --  external RAM and flash are equal or bigger than
      --  APB_CTRL_ECC_ERR_INT_NUM. When APB_CTRL_FECC_ERR_INT_EN and
      --  APB_CTRL_SECC_ERR_INT_EN are cleared, this bit will not be triggered.
      ECC_ERR_INT_RAW         : Boolean := False;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_Register use record
      Reserved_0_1            at 0 range 0 .. 1;
      TOTAL_TRANS_END_INT_RAW at 0 range 2 .. 2;
      Reserved_3_3            at 0 range 3 .. 3;
      ECC_ERR_INT_RAW         at 0 range 4 .. 4;
      Reserved_5_31           at 0 range 5 .. 31;
   end record;

   --  SPI1 interrupt status register
   type INT_ST_Register is record
      --  unspecified
      Reserved_0_1           : ESP32S3_Registers.UInt2;
      --  Read-only. The status bit for SPI_MEM_TOTAL_TRANS_END_INT interrupt.
      TOTAL_TRANS_END_INT_ST : Boolean;
      --  unspecified
      Reserved_3_3           : ESP32S3_Registers.Bit;
      --  Read-only. The status bit for SPI_MEM_ECC_ERR_INT interrupt.
      ECC_ERR_INT_ST         : Boolean;
      --  unspecified
      Reserved_5_31          : ESP32S3_Registers.UInt27;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ST_Register use record
      Reserved_0_1           at 0 range 0 .. 1;
      TOTAL_TRANS_END_INT_ST at 0 range 2 .. 2;
      Reserved_3_3           at 0 range 3 .. 3;
      ECC_ERR_INT_ST         at 0 range 4 .. 4;
      Reserved_5_31          at 0 range 5 .. 31;
   end record;

   subtype DATE_SPI_SMEM_SPICLK_FUN_DRV_Field is ESP32S3_Registers.UInt2;
   subtype DATE_SPI_FMEM_SPICLK_FUN_DRV_Field is ESP32S3_Registers.UInt2;
   subtype DATE_DATE_Field is ESP32S3_Registers.UInt23;

   --  SPI0 version control register
   type DATE_Register is record
      --  The driver of SPI_CLK PAD is controlled by the bits
      --  SPI_SMEM_SPICLK_FUN_DRV[1:0] when the bit SPI_SPICLK_PAD_DRV_CTL_EN
      --  is set and MSPI accesses to external RAM.
      SPI_SMEM_SPICLK_FUN_DRV   : DATE_SPI_SMEM_SPICLK_FUN_DRV_Field := 16#0#;
      --  The driver of SPI_CLK PAD is controlled by the bits
      --  SPI_FMEM_SPICLK_FUN_DRV[1:0] when the bit SPI_SPICLK_PAD_DRV_CTL_EN
      --  is set and MSPI accesses to flash.
      SPI_FMEM_SPICLK_FUN_DRV   : DATE_SPI_FMEM_SPICLK_FUN_DRV_Field := 16#0#;
      --  SPI_CLK PAD driver control signal. 1: The driver of SPI_CLK PAD is
      --  controlled by the bits SPI_FMEM_SPICLK_FUN_DRV[1:0] and
      --  SPI_SMEM_SPICLK_FUN_DRV[1:0]. 0: The driver of SPI_CLK PAD is
      --  controlled by the bits IO_MUX_FUNC_DRV[1:0] of SPICLK PAD.
      SPI_SPICLK_PAD_DRV_CTL_EN : Boolean := False;
      --  SPI register version.
      DATE                      : DATE_DATE_Field := 16#108082#;
      --  unspecified
      Reserved_28_31            : ESP32S3_Registers.UInt4 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DATE_Register use record
      SPI_SMEM_SPICLK_FUN_DRV   at 0 range 0 .. 1;
      SPI_FMEM_SPICLK_FUN_DRV   at 0 range 2 .. 3;
      SPI_SPICLK_PAD_DRV_CTL_EN at 0 range 4 .. 4;
      DATE                      at 0 range 5 .. 27;
      Reserved_28_31            at 0 range 28 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  SPI (Serial Peripheral Interface) Controller 0
   type SPI0_Peripheral is record
      --  SPI0 control register.
      CTRL                 : aliased CTRL_Register;
      --  SPI0 control 1 register.
      CTRL1                : aliased CTRL1_Register;
      --  SPI0 control 2 register.
      CTRL2                : aliased CTRL2_Register;
      --  SPI_CLK clock division register when SPI0 accesses to flash.
      CLOCK                : aliased CLOCK_Register;
      --  SPI0 user register.
      USER                 : aliased USER_Register;
      --  SPI0 user1 register.
      USER1                : aliased USER1_Register;
      --  SPI0 user2 register.
      USER2                : aliased USER2_Register;
      --  SPI0 read control register.
      RD_STATUS            : aliased RD_STATUS_Register;
      --  SPI0 extended address register.
      EXT_ADDR             : aliased ESP32S3_Registers.UInt32;
      --  SPI0 misc register
      MISC                 : aliased MISC_Register;
      --  SPI0 external RAM bit mode control register.
      CACHE_FCTRL          : aliased CACHE_FCTRL_Register;
      --  SPI0 external RAM control register
      CACHE_SCTRL          : aliased CACHE_SCTRL_Register;
      --  SPI0 external RAM mode control register
      SRAM_CMD             : aliased SRAM_CMD_Register;
      --  SPI0 external RAM DDR read command control register
      SRAM_DRD_CMD         : aliased SRAM_DRD_CMD_Register;
      --  SPI0 external RAM DDR write command control register
      SRAM_DWR_CMD         : aliased SRAM_DWR_CMD_Register;
      --  SPI_CLK clock division register when SPI0 accesses to Ext_RAM.
      SRAM_CLK             : aliased SRAM_CLK_Register;
      --  SPI0 state machine(FSM) status register.
      FSM                  : aliased FSM_Register;
      --  SPI0 timing compensation register when accesses to flash.
      TIMING_CALI          : aliased TIMING_CALI_Register;
      --  MSPI input timing delay mode control register when accesses to flash.
      DIN_MODE             : aliased DIN_MODE_Register;
      --  MSPI input timing delay number control register when accesses to
      --  flash.
      DIN_NUM              : aliased DIN_NUM_Register;
      --  MSPI output timing delay mode control register when accesses to
      --  flash.
      DOUT_MODE            : aliased DOUT_MODE_Register;
      --  SPI0 Ext_RAM timing compensation register.
      SPI_SMEM_TIMING_CALI : aliased SPI_SMEM_TIMING_CALI_Register;
      --  MSPI input timing delay mode control register when accesses to
      --  Ext_RAM.
      SPI_SMEM_DIN_MODE    : aliased SPI_SMEM_DIN_MODE_Register;
      --  MSPI input timing delay number control register when accesses to
      --  Ext_RAM.
      SPI_SMEM_DIN_NUM     : aliased SPI_SMEM_DIN_NUM_Register;
      --  MSPI output timing delay mode control register when accesses to
      --  Ext_RAM.
      SPI_SMEM_DOUT_MODE   : aliased SPI_SMEM_DOUT_MODE_Register;
      --  MSPI ECC control register
      ECC_CTRL             : aliased ECC_CTRL_Register;
      --  MSPI ECC error address register
      ECC_ERR_ADDR         : aliased ESP32S3_Registers.UInt32;
      --  MSPI ECC error bits register
      ECC_ERR_BIT          : aliased ECC_ERR_BIT_Register;
      --  MSPI external RAM ECC and SPI CS timing control register
      SPI_SMEM_AC          : aliased SPI_SMEM_AC_Register;
      --  SPI0 flash DDR mode control register
      DDR                  : aliased DDR_Register;
      --  SPI0 external RAM DDR mode control register
      SPI_SMEM_DDR         : aliased SPI_SMEM_DDR_Register;
      --  SPI0 clk_gate register
      CLOCK_GATE           : aliased CLOCK_GATE_Register;
      --  SPI0 module clock select register
      CORE_CLK_SEL         : aliased CORE_CLK_SEL_Register;
      --  SPI1 interrupt enable register
      INT_ENA              : aliased INT_ENA_Register;
      --  SPI1 interrupt clear register
      INT_CLR              : aliased INT_CLR_Register;
      --  SPI1 interrupt raw register
      INT_RAW              : aliased INT_RAW_Register;
      --  SPI1 interrupt status register
      INT_ST               : aliased INT_ST_Register;
      --  SPI0 version control register
      DATE                 : aliased DATE_Register;
   end record
     with Volatile;

   for SPI0_Peripheral use record
      CTRL                 at 16#8# range 0 .. 31;
      CTRL1                at 16#C# range 0 .. 31;
      CTRL2                at 16#10# range 0 .. 31;
      CLOCK                at 16#14# range 0 .. 31;
      USER                 at 16#18# range 0 .. 31;
      USER1                at 16#1C# range 0 .. 31;
      USER2                at 16#20# range 0 .. 31;
      RD_STATUS            at 16#2C# range 0 .. 31;
      EXT_ADDR             at 16#30# range 0 .. 31;
      MISC                 at 16#34# range 0 .. 31;
      CACHE_FCTRL          at 16#3C# range 0 .. 31;
      CACHE_SCTRL          at 16#40# range 0 .. 31;
      SRAM_CMD             at 16#44# range 0 .. 31;
      SRAM_DRD_CMD         at 16#48# range 0 .. 31;
      SRAM_DWR_CMD         at 16#4C# range 0 .. 31;
      SRAM_CLK             at 16#50# range 0 .. 31;
      FSM                  at 16#54# range 0 .. 31;
      TIMING_CALI          at 16#A8# range 0 .. 31;
      DIN_MODE             at 16#AC# range 0 .. 31;
      DIN_NUM              at 16#B0# range 0 .. 31;
      DOUT_MODE            at 16#B4# range 0 .. 31;
      SPI_SMEM_TIMING_CALI at 16#BC# range 0 .. 31;
      SPI_SMEM_DIN_MODE    at 16#C0# range 0 .. 31;
      SPI_SMEM_DIN_NUM     at 16#C4# range 0 .. 31;
      SPI_SMEM_DOUT_MODE   at 16#C8# range 0 .. 31;
      ECC_CTRL             at 16#CC# range 0 .. 31;
      ECC_ERR_ADDR         at 16#D0# range 0 .. 31;
      ECC_ERR_BIT          at 16#D4# range 0 .. 31;
      SPI_SMEM_AC          at 16#DC# range 0 .. 31;
      DDR                  at 16#E0# range 0 .. 31;
      SPI_SMEM_DDR         at 16#E4# range 0 .. 31;
      CLOCK_GATE           at 16#E8# range 0 .. 31;
      CORE_CLK_SEL         at 16#EC# range 0 .. 31;
      INT_ENA              at 16#F0# range 0 .. 31;
      INT_CLR              at 16#F4# range 0 .. 31;
      INT_RAW              at 16#F8# range 0 .. 31;
      INT_ST               at 16#FC# range 0 .. 31;
      DATE                 at 16#3FC# range 0 .. 31;
   end record;

   --  SPI (Serial Peripheral Interface) Controller 0
   SPI0_Periph : aliased SPI0_Peripheral
     with Import, Address => SPI0_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.SPI0;
