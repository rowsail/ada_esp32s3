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

package ESP32S3_Registers.SPI2 is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype CMD_CONF_BITLEN_Field is ESP32S3_Registers.UInt18;

   --  Command control register
   type CMD_Register is record
      --  Define the APB cycles of SPI_CONF state. Can be configured in CONF
      --  state.
      CONF_BITLEN    : CMD_CONF_BITLEN_Field := 16#0#;
      --  unspecified
      Reserved_18_22 : ESP32S3_Registers.UInt5 := 16#0#;
      --  Set this bit to synchronize SPI registers from APB clock domain into
      --  SPI module clock domain, which is only used in SPI master mode.
      UPDATE         : Boolean := False;
      --  User define command enable. An operation will be triggered when the
      --  bit is set. The bit will be cleared once the operation done.1: enable
      --  0: disable. Can not be changed by CONF_buf.
      USR            : Boolean := False;
      --  unspecified
      Reserved_25_31 : ESP32S3_Registers.UInt7 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMD_Register use record
      CONF_BITLEN    at 0 range 0 .. 17;
      Reserved_18_22 at 0 range 18 .. 22;
      UPDATE         at 0 range 23 .. 23;
      USR            at 0 range 24 .. 24;
      Reserved_25_31 at 0 range 25 .. 31;
   end record;

   subtype CTRL_RD_BIT_ORDER_Field is ESP32S3_Registers.UInt2;
   subtype CTRL_WR_BIT_ORDER_Field is ESP32S3_Registers.UInt2;

   --  SPI control register
   type CTRL_Register is record
      --  unspecified
      Reserved_0_2   : ESP32S3_Registers.UInt3 := 16#0#;
      --  0: In the dummy phase, the FSPI bus signals are not output. 1: In the
      --  dummy phase, the FSPI bus signals are output. Can be configured in
      --  CONF state.
      DUMMY_OUT      : Boolean := False;
      --  unspecified
      Reserved_4_4   : ESP32S3_Registers.Bit := 16#0#;
      --  Apply 2 signals during addr phase 1:enable 0: disable. Can be
      --  configured in CONF state.
      FADDR_DUAL     : Boolean := False;
      --  Apply 4 signals during addr phase 1:enable 0: disable. Can be
      --  configured in CONF state.
      FADDR_QUAD     : Boolean := False;
      --  Apply 8 signals during addr phase 1:enable 0: disable. Can be
      --  configured in CONF state.
      FADDR_OCT      : Boolean := False;
      --  Apply 2 signals during command phase 1:enable 0: disable. Can be
      --  configured in CONF state.
      FCMD_DUAL      : Boolean := False;
      --  Apply 4 signals during command phase 1:enable 0: disable. Can be
      --  configured in CONF state.
      FCMD_QUAD      : Boolean := False;
      --  Apply 8 signals during command phase 1:enable 0: disable. Can be
      --  configured in CONF state.
      FCMD_OCT       : Boolean := False;
      --  unspecified
      Reserved_11_13 : ESP32S3_Registers.UInt3 := 16#0#;
      --  In the read operations, read-data phase apply 2 signals. 1: enable 0:
      --  disable. Can be configured in CONF state.
      FREAD_DUAL     : Boolean := False;
      --  In the read operations read-data phase apply 4 signals. 1: enable 0:
      --  disable. Can be configured in CONF state.
      FREAD_QUAD     : Boolean := False;
      --  In the read operations read-data phase apply 8 signals. 1: enable 0:
      --  disable. Can be configured in CONF state.
      FREAD_OCT      : Boolean := False;
      --  unspecified
      Reserved_17_17 : ESP32S3_Registers.Bit := 16#0#;
      --  The bit is used to set MISO line polarity, 1: high 0, low. Can be
      --  configured in CONF state.
      Q_POL          : Boolean := True;
      --  The bit is used to set MOSI line polarity, 1: high 0, low. Can be
      --  configured in CONF state.
      D_POL          : Boolean := True;
      --  SPI_HOLD output value when SPI is idle. 1: output high, 0: output
      --  low. Can be configured in CONF state.
      HOLD_POL       : Boolean := True;
      --  Write protect signal output when SPI is idle. 1: output high, 0:
      --  output low. Can be configured in CONF state.
      WP_POL         : Boolean := True;
      --  unspecified
      Reserved_22_22 : ESP32S3_Registers.Bit := 16#0#;
      --  In read-data (MISO) phase 1: LSB first 0: MSB first. Can be
      --  configured in CONF state.
      RD_BIT_ORDER   : CTRL_RD_BIT_ORDER_Field := 16#0#;
      --  In command address write-data (MOSI) phases 1: LSB firs 0: MSB first.
      --  Can be configured in CONF state.
      WR_BIT_ORDER   : CTRL_WR_BIT_ORDER_Field := 16#0#;
      --  unspecified
      Reserved_27_31 : ESP32S3_Registers.UInt5 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTRL_Register use record
      Reserved_0_2   at 0 range 0 .. 2;
      DUMMY_OUT      at 0 range 3 .. 3;
      Reserved_4_4   at 0 range 4 .. 4;
      FADDR_DUAL     at 0 range 5 .. 5;
      FADDR_QUAD     at 0 range 6 .. 6;
      FADDR_OCT      at 0 range 7 .. 7;
      FCMD_DUAL      at 0 range 8 .. 8;
      FCMD_QUAD      at 0 range 9 .. 9;
      FCMD_OCT       at 0 range 10 .. 10;
      Reserved_11_13 at 0 range 11 .. 13;
      FREAD_DUAL     at 0 range 14 .. 14;
      FREAD_QUAD     at 0 range 15 .. 15;
      FREAD_OCT      at 0 range 16 .. 16;
      Reserved_17_17 at 0 range 17 .. 17;
      Q_POL          at 0 range 18 .. 18;
      D_POL          at 0 range 19 .. 19;
      HOLD_POL       at 0 range 20 .. 20;
      WP_POL         at 0 range 21 .. 21;
      Reserved_22_22 at 0 range 22 .. 22;
      RD_BIT_ORDER   at 0 range 23 .. 24;
      WR_BIT_ORDER   at 0 range 25 .. 26;
      Reserved_27_31 at 0 range 27 .. 31;
   end record;

   subtype CLOCK_CLKCNT_L_Field is ESP32S3_Registers.UInt6;
   subtype CLOCK_CLKCNT_H_Field is ESP32S3_Registers.UInt6;
   subtype CLOCK_CLKCNT_N_Field is ESP32S3_Registers.UInt6;
   subtype CLOCK_CLKDIV_PRE_Field is ESP32S3_Registers.UInt4;

   --  SPI clock control register
   type CLOCK_Register is record
      --  In the master mode it must be equal to spi_clkcnt_N. In the slave
      --  mode it must be 0. Can be configured in CONF state.
      CLKCNT_L       : CLOCK_CLKCNT_L_Field := 16#3#;
      --  In the master mode it must be floor((spi_clkcnt_N+1)/2-1). In the
      --  slave mode it must be 0. Can be configured in CONF state.
      CLKCNT_H       : CLOCK_CLKCNT_H_Field := 16#1#;
      --  In the master mode it is the divider of spi_clk. So spi_clk frequency
      --  is system/(spi_clkdiv_pre+1)/(spi_clkcnt_N+1). Can be configured in
      --  CONF state.
      CLKCNT_N       : CLOCK_CLKCNT_N_Field := 16#3#;
      --  In the master mode it is pre-divider of spi_clk. Can be configured in
      --  CONF state.
      CLKDIV_PRE     : CLOCK_CLKDIV_PRE_Field := 16#0#;
      --  unspecified
      Reserved_22_30 : ESP32S3_Registers.UInt9 := 16#0#;
      --  In the master mode 1: spi_clk is eqaul to system 0: spi_clk is
      --  divided from system clock. Can be configured in CONF state.
      CLK_EQU_SYSCLK : Boolean := True;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLOCK_Register use record
      CLKCNT_L       at 0 range 0 .. 5;
      CLKCNT_H       at 0 range 6 .. 11;
      CLKCNT_N       at 0 range 12 .. 17;
      CLKDIV_PRE     at 0 range 18 .. 21;
      Reserved_22_30 at 0 range 22 .. 30;
      CLK_EQU_SYSCLK at 0 range 31 .. 31;
   end record;

   --  SPI USER control register
   type USER_Register is record
      --  Set the bit to enable full duplex communication. 1: enable 0:
      --  disable. Can be configured in CONF state.
      DOUTDIN           : Boolean := False;
      --  unspecified
      Reserved_1_2      : ESP32S3_Registers.UInt2 := 16#0#;
      --  Both for master mode and slave mode. 1: spi controller is in QPI
      --  mode. 0: others. Can be configured in CONF state.
      QPI_MODE          : Boolean := False;
      --  Just for master mode. 1: spi controller is in OPI mode (all in
      --  8-b-m). 0: others. Can be configured in CONF state.
      OPI_MODE          : Boolean := False;
      --  In the slave mode, this bit can be used to change the polarity of
      --  tsck. 0: tsck = spi_ck_i. 1:tsck = !spi_ck_i.
      TSCK_I_EDGE       : Boolean := False;
      --  spi cs keep low when spi is in done phase. 1: enable 0: disable. Can
      --  be configured in CONF state.
      CS_HOLD           : Boolean := True;
      --  spi cs is enable when spi is in prepare phase. 1: enable 0: disable.
      --  Can be configured in CONF state.
      CS_SETUP          : Boolean := True;
      --  In the slave mode, this bit can be used to change the polarity of
      --  rsck. 0: rsck = !spi_ck_i. 1:rsck = spi_ck_i.
      RSCK_I_EDGE       : Boolean := False;
      --  the bit combined with spi_mosi_delay_mode bits to set mosi signal
      --  delay mode. Can be configured in CONF state.
      CK_OUT_EDGE       : Boolean := False;
      --  unspecified
      Reserved_10_11    : ESP32S3_Registers.UInt2 := 16#0#;
      --  In the write operations read-data phase apply 2 signals. Can be
      --  configured in CONF state.
      FWRITE_DUAL       : Boolean := False;
      --  In the write operations read-data phase apply 4 signals. Can be
      --  configured in CONF state.
      FWRITE_QUAD       : Boolean := False;
      --  In the write operations read-data phase apply 8 signals. Can be
      --  configured in CONF state.
      FWRITE_OCT        : Boolean := False;
      --  1: Enable the DMA CONF phase of next seg-trans operation, which means
      --  seg-trans will continue. 0: The seg-trans will end after the current
      --  SPI seg-trans or this is not seg-trans mode. Can be configured in
      --  CONF state.
      USR_CONF_NXT      : Boolean := False;
      --  unspecified
      Reserved_16_16    : ESP32S3_Registers.Bit := 16#0#;
      --  Set the bit to enable 3-line half duplex communication mosi and miso
      --  signals share the same pin. 1: enable 0: disable. Can be configured
      --  in CONF state.
      SIO               : Boolean := False;
      --  unspecified
      Reserved_18_23    : ESP32S3_Registers.UInt6 := 16#0#;
      --  read-data phase only access to high-part of the buffer
      --  spi_w8~spi_w15. 1: enable 0: disable. Can be configured in CONF
      --  state.
      USR_MISO_HIGHPART : Boolean := False;
      --  write-data phase only access to high-part of the buffer
      --  spi_w8~spi_w15. 1: enable 0: disable. Can be configured in CONF
      --  state.
      USR_MOSI_HIGHPART : Boolean := False;
      --  spi clock is disable in dummy phase when the bit is enable. Can be
      --  configured in CONF state.
      USR_DUMMY_IDLE    : Boolean := False;
      --  This bit enable the write-data phase of an operation. Can be
      --  configured in CONF state.
      USR_MOSI          : Boolean := False;
      --  This bit enable the read-data phase of an operation. Can be
      --  configured in CONF state.
      USR_MISO          : Boolean := False;
      --  This bit enable the dummy phase of an operation. Can be configured in
      --  CONF state.
      USR_DUMMY         : Boolean := False;
      --  This bit enable the address phase of an operation. Can be configured
      --  in CONF state.
      USR_ADDR          : Boolean := False;
      --  This bit enable the command phase of an operation. Can be configured
      --  in CONF state.
      USR_COMMAND       : Boolean := True;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for USER_Register use record
      DOUTDIN           at 0 range 0 .. 0;
      Reserved_1_2      at 0 range 1 .. 2;
      QPI_MODE          at 0 range 3 .. 3;
      OPI_MODE          at 0 range 4 .. 4;
      TSCK_I_EDGE       at 0 range 5 .. 5;
      CS_HOLD           at 0 range 6 .. 6;
      CS_SETUP          at 0 range 7 .. 7;
      RSCK_I_EDGE       at 0 range 8 .. 8;
      CK_OUT_EDGE       at 0 range 9 .. 9;
      Reserved_10_11    at 0 range 10 .. 11;
      FWRITE_DUAL       at 0 range 12 .. 12;
      FWRITE_QUAD       at 0 range 13 .. 13;
      FWRITE_OCT        at 0 range 14 .. 14;
      USR_CONF_NXT      at 0 range 15 .. 15;
      Reserved_16_16    at 0 range 16 .. 16;
      SIO               at 0 range 17 .. 17;
      Reserved_18_23    at 0 range 18 .. 23;
      USR_MISO_HIGHPART at 0 range 24 .. 24;
      USR_MOSI_HIGHPART at 0 range 25 .. 25;
      USR_DUMMY_IDLE    at 0 range 26 .. 26;
      USR_MOSI          at 0 range 27 .. 27;
      USR_MISO          at 0 range 28 .. 28;
      USR_DUMMY         at 0 range 29 .. 29;
      USR_ADDR          at 0 range 30 .. 30;
      USR_COMMAND       at 0 range 31 .. 31;
   end record;

   subtype USER1_USR_DUMMY_CYCLELEN_Field is ESP32S3_Registers.Byte;
   subtype USER1_CS_SETUP_TIME_Field is ESP32S3_Registers.UInt5;
   subtype USER1_CS_HOLD_TIME_Field is ESP32S3_Registers.UInt5;
   subtype USER1_USR_ADDR_BITLEN_Field is ESP32S3_Registers.UInt5;

   --  SPI USER control register 1
   type USER1_Register is record
      --  The length in spi_clk cycles of dummy phase. The register value shall
      --  be (cycle_num-1). Can be configured in CONF state.
      USR_DUMMY_CYCLELEN   : USER1_USR_DUMMY_CYCLELEN_Field := 16#7#;
      --  unspecified
      Reserved_8_15        : ESP32S3_Registers.Byte := 16#0#;
      --  1: SPI transfer is ended when SPI RX AFIFO wfull error is valid in
      --  GP-SPI master FD/HD-mode. 0: SPI transfer is not ended when SPI RX
      --  AFIFO wfull error is valid in GP-SPI master FD/HD-mode.
      MST_WFULL_ERR_END_EN : Boolean := True;
      --  (cycles+1) of prepare phase by spi clock this bits are combined with
      --  spi_cs_setup bit. Can be configured in CONF state.
      CS_SETUP_TIME        : USER1_CS_SETUP_TIME_Field := 16#0#;
      --  delay cycles of cs pin by spi clock this bits are combined with
      --  spi_cs_hold bit. Can be configured in CONF state.
      CS_HOLD_TIME         : USER1_CS_HOLD_TIME_Field := 16#1#;
      --  The length in bits of address phase. The register value shall be
      --  (bit_num-1). Can be configured in CONF state.
      USR_ADDR_BITLEN      : USER1_USR_ADDR_BITLEN_Field := 16#17#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for USER1_Register use record
      USR_DUMMY_CYCLELEN   at 0 range 0 .. 7;
      Reserved_8_15        at 0 range 8 .. 15;
      MST_WFULL_ERR_END_EN at 0 range 16 .. 16;
      CS_SETUP_TIME        at 0 range 17 .. 21;
      CS_HOLD_TIME         at 0 range 22 .. 26;
      USR_ADDR_BITLEN      at 0 range 27 .. 31;
   end record;

   subtype USER2_USR_COMMAND_VALUE_Field is ESP32S3_Registers.UInt16;
   subtype USER2_USR_COMMAND_BITLEN_Field is ESP32S3_Registers.UInt4;

   --  SPI USER control register 2
   type USER2_Register is record
      --  The value of command. Can be configured in CONF state.
      USR_COMMAND_VALUE     : USER2_USR_COMMAND_VALUE_Field := 16#0#;
      --  unspecified
      Reserved_16_26        : ESP32S3_Registers.UInt11 := 16#0#;
      --  1: SPI transfer is ended when SPI TX AFIFO read empty error is valid
      --  in GP-SPI master FD/HD-mode. 0: SPI transfer is not ended when SPI TX
      --  AFIFO read empty error is valid in GP-SPI master FD/HD-mode.
      MST_REMPTY_ERR_END_EN : Boolean := True;
      --  The length in bits of command phase. The register value shall be
      --  (bit_num-1). Can be configured in CONF state.
      USR_COMMAND_BITLEN    : USER2_USR_COMMAND_BITLEN_Field := 16#7#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for USER2_Register use record
      USR_COMMAND_VALUE     at 0 range 0 .. 15;
      Reserved_16_26        at 0 range 16 .. 26;
      MST_REMPTY_ERR_END_EN at 0 range 27 .. 27;
      USR_COMMAND_BITLEN    at 0 range 28 .. 31;
   end record;

   subtype MS_DLEN_MS_DATA_BITLEN_Field is ESP32S3_Registers.UInt18;

   --  SPI data bit length control register
   type MS_DLEN_Register is record
      --  The value of these bits is the configured SPI transmission data bit
      --  length in master mode DMA controlled transfer or CPU controlled
      --  transfer. The value is also the configured bit length in slave mode
      --  DMA RX controlled transfer. The register value shall be (bit_num-1).
      --  Can be configured in CONF state.
      MS_DATA_BITLEN : MS_DLEN_MS_DATA_BITLEN_Field := 16#0#;
      --  unspecified
      Reserved_18_31 : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MS_DLEN_Register use record
      MS_DATA_BITLEN at 0 range 0 .. 17;
      Reserved_18_31 at 0 range 18 .. 31;
   end record;

   subtype MISC_MASTER_CS_POL_Field is ESP32S3_Registers.UInt6;

   --  SPI misc register
   type MISC_Register is record
      --  SPI CS0 pin enable, 1: disable CS0, 0: spi_cs0 signal is from/to CS0
      --  pin. Can be configured in CONF state.
      CS0_DIS           : Boolean := False;
      --  SPI CS1 pin enable, 1: disable CS1, 0: spi_cs1 signal is from/to CS1
      --  pin. Can be configured in CONF state.
      CS1_DIS           : Boolean := True;
      --  SPI CS2 pin enable, 1: disable CS2, 0: spi_cs2 signal is from/to CS2
      --  pin. Can be configured in CONF state.
      CS2_DIS           : Boolean := True;
      --  SPI CS3 pin enable, 1: disable CS3, 0: spi_cs3 signal is from/to CS3
      --  pin. Can be configured in CONF state.
      CS3_DIS           : Boolean := True;
      --  SPI CS4 pin enable, 1: disable CS4, 0: spi_cs4 signal is from/to CS4
      --  pin. Can be configured in CONF state.
      CS4_DIS           : Boolean := True;
      --  SPI CS5 pin enable, 1: disable CS5, 0: spi_cs5 signal is from/to CS5
      --  pin. Can be configured in CONF state.
      CS5_DIS           : Boolean := True;
      --  1: spi clk out disable, 0: spi clk out enable. Can be configured in
      --  CONF state.
      CK_DIS            : Boolean := False;
      --  In the master mode the bits are the polarity of spi cs line, the
      --  value is equivalent to spi_cs ^ spi_master_cs_pol. Can be configured
      --  in CONF state.
      MASTER_CS_POL     : MISC_MASTER_CS_POL_Field := 16#0#;
      --  unspecified
      Reserved_13_15    : ESP32S3_Registers.UInt3 := 16#0#;
      --  1: SPI master DTR mode is applied to SPI clk, data and spi_dqs. 0:
      --  SPI master DTR mode is only applied to spi_dqs. This bit should be
      --  used with bit 17/18/19.
      CLK_DATA_DTR_EN   : Boolean := False;
      --  1: SPI clk and data of SPI_DOUT and SPI_DIN state are in DTR mode,
      --  including master 1/2/4/8-bm. 0: SPI clk and data of SPI_DOUT and
      --  SPI_DIN state are in STR mode. Can be configured in CONF state.
      DATA_DTR_EN       : Boolean := False;
      --  1: SPI clk and data of SPI_SEND_ADDR state are in DTR mode, including
      --  master 1/2/4/8-bm. 0: SPI clk and data of SPI_SEND_ADDR state are in
      --  STR mode. Can be configured in CONF state.
      ADDR_DTR_EN       : Boolean := False;
      --  1: SPI clk and data of SPI_SEND_CMD state are in DTR mode, including
      --  master 1/2/4/8-bm. 0: SPI clk and data of SPI_SEND_CMD state are in
      --  STR mode. Can be configured in CONF state.
      CMD_DTR_EN        : Boolean := False;
      --  unspecified
      Reserved_20_22    : ESP32S3_Registers.UInt3 := 16#0#;
      --  spi slave input cs polarity select. 1: inv 0: not change. Can be
      --  configured in CONF state.
      SLAVE_CS_POL      : Boolean := False;
      --  The default value of spi_dqs. Can be configured in CONF state.
      DQS_IDLE_EDGE     : Boolean := False;
      --  unspecified
      Reserved_25_28    : ESP32S3_Registers.UInt4 := 16#0#;
      --  1: spi clk line is high when idle 0: spi clk line is low when idle.
      --  Can be configured in CONF state.
      CK_IDLE_EDGE      : Boolean := False;
      --  spi cs line keep low when the bit is set. Can be configured in CONF
      --  state.
      CS_KEEP_ACTIVE    : Boolean := False;
      --  1: SPI quad input swap enable, swap FSPID with FSPIQ, swap FSPIWP
      --  with FSPIHD. 0: spi quad input swap disable. Can be configured in
      --  CONF state.
      QUAD_DIN_PIN_SWAP : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MISC_Register use record
      CS0_DIS           at 0 range 0 .. 0;
      CS1_DIS           at 0 range 1 .. 1;
      CS2_DIS           at 0 range 2 .. 2;
      CS3_DIS           at 0 range 3 .. 3;
      CS4_DIS           at 0 range 4 .. 4;
      CS5_DIS           at 0 range 5 .. 5;
      CK_DIS            at 0 range 6 .. 6;
      MASTER_CS_POL     at 0 range 7 .. 12;
      Reserved_13_15    at 0 range 13 .. 15;
      CLK_DATA_DTR_EN   at 0 range 16 .. 16;
      DATA_DTR_EN       at 0 range 17 .. 17;
      ADDR_DTR_EN       at 0 range 18 .. 18;
      CMD_DTR_EN        at 0 range 19 .. 19;
      Reserved_20_22    at 0 range 20 .. 22;
      SLAVE_CS_POL      at 0 range 23 .. 23;
      DQS_IDLE_EDGE     at 0 range 24 .. 24;
      Reserved_25_28    at 0 range 25 .. 28;
      CK_IDLE_EDGE      at 0 range 29 .. 29;
      CS_KEEP_ACTIVE    at 0 range 30 .. 30;
      QUAD_DIN_PIN_SWAP at 0 range 31 .. 31;
   end record;

   subtype DIN_MODE_DIN0_MODE_Field is ESP32S3_Registers.UInt2;
   subtype DIN_MODE_DIN1_MODE_Field is ESP32S3_Registers.UInt2;
   subtype DIN_MODE_DIN2_MODE_Field is ESP32S3_Registers.UInt2;
   subtype DIN_MODE_DIN3_MODE_Field is ESP32S3_Registers.UInt2;
   subtype DIN_MODE_DIN4_MODE_Field is ESP32S3_Registers.UInt2;
   subtype DIN_MODE_DIN5_MODE_Field is ESP32S3_Registers.UInt2;
   subtype DIN_MODE_DIN6_MODE_Field is ESP32S3_Registers.UInt2;
   subtype DIN_MODE_DIN7_MODE_Field is ESP32S3_Registers.UInt2;

   --  SPI input delay mode configuration
   type DIN_MODE_Register is record
      --  the input signals are delayed by SPI module clock cycles, 0: input
      --  without delayed, 1: input with the posedge of clk_apb,2 input with
      --  the negedge of clk_apb, 3: input with the spi_clk. Can be configured
      --  in CONF state.
      DIN0_MODE          : DIN_MODE_DIN0_MODE_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: input
      --  without delayed, 1: input with the posedge of clk_apb,2 input with
      --  the negedge of clk_apb, 3: input with the spi_clk. Can be configured
      --  in CONF state.
      DIN1_MODE          : DIN_MODE_DIN1_MODE_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: input
      --  without delayed, 1: input with the posedge of clk_apb,2 input with
      --  the negedge of clk_apb, 3: input with the spi_clk. Can be configured
      --  in CONF state.
      DIN2_MODE          : DIN_MODE_DIN2_MODE_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: input
      --  without delayed, 1: input with the posedge of clk_apb,2 input with
      --  the negedge of clk_apb, 3: input with the spi_clk. Can be configured
      --  in CONF state.
      DIN3_MODE          : DIN_MODE_DIN3_MODE_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: input
      --  without delayed, 1: input with the posedge of clk_apb,2 input with
      --  the negedge of clk_apb, 3: input with the spi_clk. Can be configured
      --  in CONF state.
      DIN4_MODE          : DIN_MODE_DIN4_MODE_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: input
      --  without delayed, 1: input with the posedge of clk_apb,2 input with
      --  the negedge of clk_apb, 3: input with the spi_clk. Can be configured
      --  in CONF state.
      DIN5_MODE          : DIN_MODE_DIN5_MODE_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: input
      --  without delayed, 1: input with the posedge of clk_apb,2 input with
      --  the negedge of clk_apb, 3: input with the spi_clk. Can be configured
      --  in CONF state.
      DIN6_MODE          : DIN_MODE_DIN6_MODE_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: input
      --  without delayed, 1: input with the posedge of clk_apb,2 input with
      --  the negedge of clk_apb, 3: input with the spi_clk. Can be configured
      --  in CONF state.
      DIN7_MODE          : DIN_MODE_DIN7_MODE_Field := 16#0#;
      --  1:enable hclk in SPI input timing module. 0: disable it. Can be
      --  configured in CONF state.
      TIMING_HCLK_ACTIVE : Boolean := False;
      --  unspecified
      Reserved_17_31     : ESP32S3_Registers.UInt15 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DIN_MODE_Register use record
      DIN0_MODE          at 0 range 0 .. 1;
      DIN1_MODE          at 0 range 2 .. 3;
      DIN2_MODE          at 0 range 4 .. 5;
      DIN3_MODE          at 0 range 6 .. 7;
      DIN4_MODE          at 0 range 8 .. 9;
      DIN5_MODE          at 0 range 10 .. 11;
      DIN6_MODE          at 0 range 12 .. 13;
      DIN7_MODE          at 0 range 14 .. 15;
      TIMING_HCLK_ACTIVE at 0 range 16 .. 16;
      Reserved_17_31     at 0 range 17 .. 31;
   end record;

   subtype DIN_NUM_DIN0_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN1_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN2_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN3_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN4_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN5_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN6_NUM_Field is ESP32S3_Registers.UInt2;
   subtype DIN_NUM_DIN7_NUM_Field is ESP32S3_Registers.UInt2;

   --  SPI input delay number configuration
   type DIN_NUM_Register is record
      --  the input signals are delayed by SPI module clock cycles, 0: delayed
      --  by 1 cycle, 1: delayed by 2 cycles,... Can be configured in CONF
      --  state.
      DIN0_NUM       : DIN_NUM_DIN0_NUM_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: delayed
      --  by 1 cycle, 1: delayed by 2 cycles,... Can be configured in CONF
      --  state.
      DIN1_NUM       : DIN_NUM_DIN1_NUM_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: delayed
      --  by 1 cycle, 1: delayed by 2 cycles,... Can be configured in CONF
      --  state.
      DIN2_NUM       : DIN_NUM_DIN2_NUM_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: delayed
      --  by 1 cycle, 1: delayed by 2 cycles,... Can be configured in CONF
      --  state.
      DIN3_NUM       : DIN_NUM_DIN3_NUM_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: delayed
      --  by 1 cycle, 1: delayed by 2 cycles,... Can be configured in CONF
      --  state.
      DIN4_NUM       : DIN_NUM_DIN4_NUM_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: delayed
      --  by 1 cycle, 1: delayed by 2 cycles,... Can be configured in CONF
      --  state.
      DIN5_NUM       : DIN_NUM_DIN5_NUM_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: delayed
      --  by 1 cycle, 1: delayed by 2 cycles,... Can be configured in CONF
      --  state.
      DIN6_NUM       : DIN_NUM_DIN6_NUM_Field := 16#0#;
      --  the input signals are delayed by SPI module clock cycles, 0: delayed
      --  by 1 cycle, 1: delayed by 2 cycles,... Can be configured in CONF
      --  state.
      DIN7_NUM       : DIN_NUM_DIN7_NUM_Field := 16#0#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
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
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   --  SPI output delay mode configuration
   type DOUT_MODE_Register is record
      --  The output signal 0 is delayed by the SPI module clock, 0: output
      --  without delayed, 1: output delay for a SPI module clock cycle at its
      --  negative edge. Can be configured in CONF state.
      DOUT0_MODE    : Boolean := False;
      --  The output signal 1 is delayed by the SPI module clock, 0: output
      --  without delayed, 1: output delay for a SPI module clock cycle at its
      --  negative edge. Can be configured in CONF state.
      DOUT1_MODE    : Boolean := False;
      --  The output signal 2 is delayed by the SPI module clock, 0: output
      --  without delayed, 1: output delay for a SPI module clock cycle at its
      --  negative edge. Can be configured in CONF state.
      DOUT2_MODE    : Boolean := False;
      --  The output signal 3 is delayed by the SPI module clock, 0: output
      --  without delayed, 1: output delay for a SPI module clock cycle at its
      --  negative edge. Can be configured in CONF state.
      DOUT3_MODE    : Boolean := False;
      --  The output signal 4 is delayed by the SPI module clock, 0: output
      --  without delayed, 1: output delay for a SPI module clock cycle at its
      --  negative edge. Can be configured in CONF state.
      DOUT4_MODE    : Boolean := False;
      --  The output signal 5 is delayed by the SPI module clock, 0: output
      --  without delayed, 1: output delay for a SPI module clock cycle at its
      --  negative edge. Can be configured in CONF state.
      DOUT5_MODE    : Boolean := False;
      --  The output signal 6 is delayed by the SPI module clock, 0: output
      --  without delayed, 1: output delay for a SPI module clock cycle at its
      --  negative edge. Can be configured in CONF state.
      DOUT6_MODE    : Boolean := False;
      --  The output signal 7 is delayed by the SPI module clock, 0: output
      --  without delayed, 1: output delay for a SPI module clock cycle at its
      --  negative edge. Can be configured in CONF state.
      DOUT7_MODE    : Boolean := False;
      --  The output signal SPI_DQS is delayed by the SPI module clock, 0:
      --  output without delayed, 1: output delay for a SPI module clock cycle
      --  at its negative edge. Can be configured in CONF state.
      D_DQS_MODE    : Boolean := False;
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
      D_DQS_MODE    at 0 range 8 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   --  SPI DMA control register
   type DMA_CONF_Register is record
      --  Read-only. Records the status of DMA TX FIFO. 1: DMA TX FIFO is not
      --  ready for sending data. 0: DMA TX FIFO is ready for sending data.
      DMA_OUTFIFO_EMPTY       : Boolean := True;
      --  Read-only. Records the status of DMA RX FIFO. 1: DMA RX FIFO is not
      --  ready for receiving data. 0: DMA RX FIFO is ready for receiving data.
      DMA_INFIFO_FULL         : Boolean := True;
      --  unspecified
      Reserved_2_17           : ESP32S3_Registers.UInt16 := 16#0#;
      --  Enable dma segment transfer in spi dma half slave mode. 1: enable. 0:
      --  disable.
      DMA_SLV_SEG_TRANS_EN    : Boolean := False;
      --  1: spi_dma_infifo_full_vld is cleared by spi slave cmd 5. 0:
      --  spi_dma_infifo_full_vld is cleared by spi_trans_done.
      SLV_RX_SEG_TRANS_CLR_EN : Boolean := False;
      --  1: spi_dma_outfifo_empty_vld is cleared by spi slave cmd 6. 0:
      --  spi_dma_outfifo_empty_vld is cleared by spi_trans_done.
      SLV_TX_SEG_TRANS_CLR_EN : Boolean := False;
      --  1: spi_dma_inlink_eof is set when the number of dma pushed data bytes
      --  is equal to the value of spi_slv/mst_dma_rd_bytelen[19:0] in spi dma
      --  transition. 0: spi_dma_inlink_eof is set by spi_trans_done in
      --  non-seg-trans or spi_dma_seg_trans_done in seg-trans.
      RX_EOF_EN               : Boolean := False;
      --  unspecified
      Reserved_22_26          : ESP32S3_Registers.UInt5 := 16#0#;
      --  Set this bit to enable SPI DMA controlled receive data mode.
      DMA_RX_ENA              : Boolean := False;
      --  Set this bit to enable SPI DMA controlled send data mode.
      DMA_TX_ENA              : Boolean := False;
      --  Write-only. Set this bit to reset RX AFIFO, which is used to receive
      --  data in SPI master and slave mode transfer.
      RX_AFIFO_RST            : Boolean := False;
      --  Write-only. Set this bit to reset BUF TX AFIFO, which is used send
      --  data out in SPI slave CPU controlled mode transfer and master mode
      --  transfer.
      BUF_AFIFO_RST           : Boolean := False;
      --  Write-only. Set this bit to reset DMA TX AFIFO, which is used to send
      --  data out in SPI slave DMA controlled mode transfer.
      DMA_AFIFO_RST           : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_CONF_Register use record
      DMA_OUTFIFO_EMPTY       at 0 range 0 .. 0;
      DMA_INFIFO_FULL         at 0 range 1 .. 1;
      Reserved_2_17           at 0 range 2 .. 17;
      DMA_SLV_SEG_TRANS_EN    at 0 range 18 .. 18;
      SLV_RX_SEG_TRANS_CLR_EN at 0 range 19 .. 19;
      SLV_TX_SEG_TRANS_CLR_EN at 0 range 20 .. 20;
      RX_EOF_EN               at 0 range 21 .. 21;
      Reserved_22_26          at 0 range 22 .. 26;
      DMA_RX_ENA              at 0 range 27 .. 27;
      DMA_TX_ENA              at 0 range 28 .. 28;
      RX_AFIFO_RST            at 0 range 29 .. 29;
      BUF_AFIFO_RST           at 0 range 30 .. 30;
      DMA_AFIFO_RST           at 0 range 31 .. 31;
   end record;

   --  SPI interrupt enable register
   type DMA_INT_ENA_Register is record
      --  The enable bit for SPI_DMA_INFIFO_FULL_ERR_INT interrupt.
      DMA_INFIFO_FULL_ERR_INT_ENA     : Boolean := False;
      --  The enable bit for SPI_DMA_OUTFIFO_EMPTY_ERR_INT interrupt.
      DMA_OUTFIFO_EMPTY_ERR_INT_ENA   : Boolean := False;
      --  The enable bit for SPI slave Ex_QPI interrupt.
      SLV_EX_QPI_INT_ENA              : Boolean := False;
      --  The enable bit for SPI slave En_QPI interrupt.
      SLV_EN_QPI_INT_ENA              : Boolean := False;
      --  The enable bit for SPI slave CMD7 interrupt.
      SLV_CMD7_INT_ENA                : Boolean := False;
      --  The enable bit for SPI slave CMD8 interrupt.
      SLV_CMD8_INT_ENA                : Boolean := False;
      --  The enable bit for SPI slave CMD9 interrupt.
      SLV_CMD9_INT_ENA                : Boolean := False;
      --  The enable bit for SPI slave CMDA interrupt.
      SLV_CMDA_INT_ENA                : Boolean := False;
      --  The enable bit for SPI_SLV_RD_DMA_DONE_INT interrupt.
      SLV_RD_DMA_DONE_INT_ENA         : Boolean := False;
      --  The enable bit for SPI_SLV_WR_DMA_DONE_INT interrupt.
      SLV_WR_DMA_DONE_INT_ENA         : Boolean := False;
      --  The enable bit for SPI_SLV_RD_BUF_DONE_INT interrupt.
      SLV_RD_BUF_DONE_INT_ENA         : Boolean := False;
      --  The enable bit for SPI_SLV_WR_BUF_DONE_INT interrupt.
      SLV_WR_BUF_DONE_INT_ENA         : Boolean := False;
      --  The enable bit for SPI_TRANS_DONE_INT interrupt.
      TRANS_DONE_INT_ENA              : Boolean := False;
      --  The enable bit for SPI_DMA_SEG_TRANS_DONE_INT interrupt.
      DMA_SEG_TRANS_DONE_INT_ENA      : Boolean := False;
      --  The enable bit for SPI_SEG_MAGIC_ERR_INT interrupt.
      SEG_MAGIC_ERR_INT_ENA           : Boolean := False;
      --  The enable bit for SPI_SLV_BUF_ADDR_ERR_INT interrupt.
      SLV_BUF_ADDR_ERR_INT_ENA        : Boolean := False;
      --  The enable bit for SPI_SLV_CMD_ERR_INT interrupt.
      SLV_CMD_ERR_INT_ENA             : Boolean := False;
      --  The enable bit for SPI_MST_RX_AFIFO_WFULL_ERR_INT interrupt.
      MST_RX_AFIFO_WFULL_ERR_INT_ENA  : Boolean := False;
      --  The enable bit for SPI_MST_TX_AFIFO_REMPTY_ERR_INT interrupt.
      MST_TX_AFIFO_REMPTY_ERR_INT_ENA : Boolean := False;
      --  The enable bit for SPI_APP2_INT interrupt.
      APP2_INT_ENA                    : Boolean := False;
      --  The enable bit for SPI_APP1_INT interrupt.
      APP1_INT_ENA                    : Boolean := False;
      --  unspecified
      Reserved_21_31                  : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_INT_ENA_Register use record
      DMA_INFIFO_FULL_ERR_INT_ENA     at 0 range 0 .. 0;
      DMA_OUTFIFO_EMPTY_ERR_INT_ENA   at 0 range 1 .. 1;
      SLV_EX_QPI_INT_ENA              at 0 range 2 .. 2;
      SLV_EN_QPI_INT_ENA              at 0 range 3 .. 3;
      SLV_CMD7_INT_ENA                at 0 range 4 .. 4;
      SLV_CMD8_INT_ENA                at 0 range 5 .. 5;
      SLV_CMD9_INT_ENA                at 0 range 6 .. 6;
      SLV_CMDA_INT_ENA                at 0 range 7 .. 7;
      SLV_RD_DMA_DONE_INT_ENA         at 0 range 8 .. 8;
      SLV_WR_DMA_DONE_INT_ENA         at 0 range 9 .. 9;
      SLV_RD_BUF_DONE_INT_ENA         at 0 range 10 .. 10;
      SLV_WR_BUF_DONE_INT_ENA         at 0 range 11 .. 11;
      TRANS_DONE_INT_ENA              at 0 range 12 .. 12;
      DMA_SEG_TRANS_DONE_INT_ENA      at 0 range 13 .. 13;
      SEG_MAGIC_ERR_INT_ENA           at 0 range 14 .. 14;
      SLV_BUF_ADDR_ERR_INT_ENA        at 0 range 15 .. 15;
      SLV_CMD_ERR_INT_ENA             at 0 range 16 .. 16;
      MST_RX_AFIFO_WFULL_ERR_INT_ENA  at 0 range 17 .. 17;
      MST_TX_AFIFO_REMPTY_ERR_INT_ENA at 0 range 18 .. 18;
      APP2_INT_ENA                    at 0 range 19 .. 19;
      APP1_INT_ENA                    at 0 range 20 .. 20;
      Reserved_21_31                  at 0 range 21 .. 31;
   end record;

   --  SPI interrupt clear register
   type DMA_INT_CLR_Register is record
      --  Write-only. The clear bit for SPI_DMA_INFIFO_FULL_ERR_INT interrupt.
      DMA_INFIFO_FULL_ERR_INT_CLR     : Boolean := False;
      --  Write-only. The clear bit for SPI_DMA_OUTFIFO_EMPTY_ERR_INT
      --  interrupt.
      DMA_OUTFIFO_EMPTY_ERR_INT_CLR   : Boolean := False;
      --  Write-only. The clear bit for SPI slave Ex_QPI interrupt.
      SLV_EX_QPI_INT_CLR              : Boolean := False;
      --  Write-only. The clear bit for SPI slave En_QPI interrupt.
      SLV_EN_QPI_INT_CLR              : Boolean := False;
      --  Write-only. The clear bit for SPI slave CMD7 interrupt.
      SLV_CMD7_INT_CLR                : Boolean := False;
      --  Write-only. The clear bit for SPI slave CMD8 interrupt.
      SLV_CMD8_INT_CLR                : Boolean := False;
      --  Write-only. The clear bit for SPI slave CMD9 interrupt.
      SLV_CMD9_INT_CLR                : Boolean := False;
      --  Write-only. The clear bit for SPI slave CMDA interrupt.
      SLV_CMDA_INT_CLR                : Boolean := False;
      --  Write-only. The clear bit for SPI_SLV_RD_DMA_DONE_INT interrupt.
      SLV_RD_DMA_DONE_INT_CLR         : Boolean := False;
      --  Write-only. The clear bit for SPI_SLV_WR_DMA_DONE_INT interrupt.
      SLV_WR_DMA_DONE_INT_CLR         : Boolean := False;
      --  Write-only. The clear bit for SPI_SLV_RD_BUF_DONE_INT interrupt.
      SLV_RD_BUF_DONE_INT_CLR         : Boolean := False;
      --  Write-only. The clear bit for SPI_SLV_WR_BUF_DONE_INT interrupt.
      SLV_WR_BUF_DONE_INT_CLR         : Boolean := False;
      --  Write-only. The clear bit for SPI_TRANS_DONE_INT interrupt.
      TRANS_DONE_INT_CLR              : Boolean := False;
      --  Write-only. The clear bit for SPI_DMA_SEG_TRANS_DONE_INT interrupt.
      DMA_SEG_TRANS_DONE_INT_CLR      : Boolean := False;
      --  Write-only. The clear bit for SPI_SEG_MAGIC_ERR_INT interrupt.
      SEG_MAGIC_ERR_INT_CLR           : Boolean := False;
      --  Write-only. The clear bit for SPI_SLV_BUF_ADDR_ERR_INT interrupt.
      SLV_BUF_ADDR_ERR_INT_CLR        : Boolean := False;
      --  Write-only. The clear bit for SPI_SLV_CMD_ERR_INT interrupt.
      SLV_CMD_ERR_INT_CLR             : Boolean := False;
      --  Write-only. The clear bit for SPI_MST_RX_AFIFO_WFULL_ERR_INT
      --  interrupt.
      MST_RX_AFIFO_WFULL_ERR_INT_CLR  : Boolean := False;
      --  Write-only. The clear bit for SPI_MST_TX_AFIFO_REMPTY_ERR_INT
      --  interrupt.
      MST_TX_AFIFO_REMPTY_ERR_INT_CLR : Boolean := False;
      --  Write-only. The clear bit for SPI_APP2_INT interrupt.
      APP2_INT_CLR                    : Boolean := False;
      --  Write-only. The clear bit for SPI_APP1_INT interrupt.
      APP1_INT_CLR                    : Boolean := False;
      --  unspecified
      Reserved_21_31                  : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_INT_CLR_Register use record
      DMA_INFIFO_FULL_ERR_INT_CLR     at 0 range 0 .. 0;
      DMA_OUTFIFO_EMPTY_ERR_INT_CLR   at 0 range 1 .. 1;
      SLV_EX_QPI_INT_CLR              at 0 range 2 .. 2;
      SLV_EN_QPI_INT_CLR              at 0 range 3 .. 3;
      SLV_CMD7_INT_CLR                at 0 range 4 .. 4;
      SLV_CMD8_INT_CLR                at 0 range 5 .. 5;
      SLV_CMD9_INT_CLR                at 0 range 6 .. 6;
      SLV_CMDA_INT_CLR                at 0 range 7 .. 7;
      SLV_RD_DMA_DONE_INT_CLR         at 0 range 8 .. 8;
      SLV_WR_DMA_DONE_INT_CLR         at 0 range 9 .. 9;
      SLV_RD_BUF_DONE_INT_CLR         at 0 range 10 .. 10;
      SLV_WR_BUF_DONE_INT_CLR         at 0 range 11 .. 11;
      TRANS_DONE_INT_CLR              at 0 range 12 .. 12;
      DMA_SEG_TRANS_DONE_INT_CLR      at 0 range 13 .. 13;
      SEG_MAGIC_ERR_INT_CLR           at 0 range 14 .. 14;
      SLV_BUF_ADDR_ERR_INT_CLR        at 0 range 15 .. 15;
      SLV_CMD_ERR_INT_CLR             at 0 range 16 .. 16;
      MST_RX_AFIFO_WFULL_ERR_INT_CLR  at 0 range 17 .. 17;
      MST_TX_AFIFO_REMPTY_ERR_INT_CLR at 0 range 18 .. 18;
      APP2_INT_CLR                    at 0 range 19 .. 19;
      APP1_INT_CLR                    at 0 range 20 .. 20;
      Reserved_21_31                  at 0 range 21 .. 31;
   end record;

   --  SPI interrupt raw register
   type DMA_INT_RAW_Register is record
      --  1: The current data rate of DMA Rx is smaller than that of SPI, which
      --  will lose the receive data. 0: Others.
      DMA_INFIFO_FULL_ERR_INT_RAW     : Boolean := False;
      --  1: The current data rate of DMA TX is smaller than that of SPI. SPI
      --  will stop in master mode and send out all 0 in slave mode. 0: Others.
      DMA_OUTFIFO_EMPTY_ERR_INT_RAW   : Boolean := False;
      --  The raw bit for SPI slave Ex_QPI interrupt. 1: SPI slave mode Ex_QPI
      --  transmission is ended. 0: Others.
      SLV_EX_QPI_INT_RAW              : Boolean := False;
      --  The raw bit for SPI slave En_QPI interrupt. 1: SPI slave mode En_QPI
      --  transmission is ended. 0: Others.
      SLV_EN_QPI_INT_RAW              : Boolean := False;
      --  The raw bit for SPI slave CMD7 interrupt. 1: SPI slave mode CMD7
      --  transmission is ended. 0: Others.
      SLV_CMD7_INT_RAW                : Boolean := False;
      --  The raw bit for SPI slave CMD8 interrupt. 1: SPI slave mode CMD8
      --  transmission is ended. 0: Others.
      SLV_CMD8_INT_RAW                : Boolean := False;
      --  The raw bit for SPI slave CMD9 interrupt. 1: SPI slave mode CMD9
      --  transmission is ended. 0: Others.
      SLV_CMD9_INT_RAW                : Boolean := False;
      --  The raw bit for SPI slave CMDA interrupt. 1: SPI slave mode CMDA
      --  transmission is ended. 0: Others.
      SLV_CMDA_INT_RAW                : Boolean := False;
      --  The raw bit for SPI_SLV_RD_DMA_DONE_INT interrupt. 1: SPI slave mode
      --  Rd_DMA transmission is ended. 0: Others.
      SLV_RD_DMA_DONE_INT_RAW         : Boolean := False;
      --  The raw bit for SPI_SLV_WR_DMA_DONE_INT interrupt. 1: SPI slave mode
      --  Wr_DMA transmission is ended. 0: Others.
      SLV_WR_DMA_DONE_INT_RAW         : Boolean := False;
      --  The raw bit for SPI_SLV_RD_BUF_DONE_INT interrupt. 1: SPI slave mode
      --  Rd_BUF transmission is ended. 0: Others.
      SLV_RD_BUF_DONE_INT_RAW         : Boolean := False;
      --  The raw bit for SPI_SLV_WR_BUF_DONE_INT interrupt. 1: SPI slave mode
      --  Wr_BUF transmission is ended. 0: Others.
      SLV_WR_BUF_DONE_INT_RAW         : Boolean := False;
      --  The raw bit for SPI_TRANS_DONE_INT interrupt. 1: SPI master mode
      --  transmission is ended. 0: others.
      TRANS_DONE_INT_RAW              : Boolean := False;
      --  The raw bit for SPI_DMA_SEG_TRANS_DONE_INT interrupt. 1: spi master
      --  DMA full-duplex/half-duplex seg-conf-trans ends or slave half-duplex
      --  seg-trans ends. And data has been pushed to corresponding memory. 0:
      --  seg-conf-trans or seg-trans is not ended or not occurred.
      DMA_SEG_TRANS_DONE_INT_RAW      : Boolean := False;
      --  The raw bit for SPI_SEG_MAGIC_ERR_INT interrupt. 1: The magic value
      --  in CONF buffer is error in the DMA seg-conf-trans. 0: others.
      SEG_MAGIC_ERR_INT_RAW           : Boolean := False;
      --  The raw bit for SPI_SLV_BUF_ADDR_ERR_INT interrupt. 1: The accessing
      --  data address of the current SPI slave mode CPU controlled FD, Wr_BUF
      --  or Rd_BUF transmission is bigger than 63. 0: Others.
      SLV_BUF_ADDR_ERR_INT_RAW        : Boolean := False;
      --  The raw bit for SPI_SLV_CMD_ERR_INT interrupt. 1: The slave command
      --  value in the current SPI slave HD mode transmission is not supported.
      --  0: Others.
      SLV_CMD_ERR_INT_RAW             : Boolean := False;
      --  The raw bit for SPI_MST_RX_AFIFO_WFULL_ERR_INT interrupt. 1: There is
      --  a RX AFIFO write-full error when SPI inputs data in master mode. 0:
      --  Others.
      MST_RX_AFIFO_WFULL_ERR_INT_RAW  : Boolean := False;
      --  The raw bit for SPI_MST_TX_AFIFO_REMPTY_ERR_INT interrupt. 1: There
      --  is a TX BUF AFIFO read-empty error when SPI outputs data in master
      --  mode. 0: Others.
      MST_TX_AFIFO_REMPTY_ERR_INT_RAW : Boolean := False;
      --  The raw bit for SPI_APP2_INT interrupt. The value is only controlled
      --  by software.
      APP2_INT_RAW                    : Boolean := False;
      --  The raw bit for SPI_APP1_INT interrupt. The value is only controlled
      --  by software.
      APP1_INT_RAW                    : Boolean := False;
      --  unspecified
      Reserved_21_31                  : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_INT_RAW_Register use record
      DMA_INFIFO_FULL_ERR_INT_RAW     at 0 range 0 .. 0;
      DMA_OUTFIFO_EMPTY_ERR_INT_RAW   at 0 range 1 .. 1;
      SLV_EX_QPI_INT_RAW              at 0 range 2 .. 2;
      SLV_EN_QPI_INT_RAW              at 0 range 3 .. 3;
      SLV_CMD7_INT_RAW                at 0 range 4 .. 4;
      SLV_CMD8_INT_RAW                at 0 range 5 .. 5;
      SLV_CMD9_INT_RAW                at 0 range 6 .. 6;
      SLV_CMDA_INT_RAW                at 0 range 7 .. 7;
      SLV_RD_DMA_DONE_INT_RAW         at 0 range 8 .. 8;
      SLV_WR_DMA_DONE_INT_RAW         at 0 range 9 .. 9;
      SLV_RD_BUF_DONE_INT_RAW         at 0 range 10 .. 10;
      SLV_WR_BUF_DONE_INT_RAW         at 0 range 11 .. 11;
      TRANS_DONE_INT_RAW              at 0 range 12 .. 12;
      DMA_SEG_TRANS_DONE_INT_RAW      at 0 range 13 .. 13;
      SEG_MAGIC_ERR_INT_RAW           at 0 range 14 .. 14;
      SLV_BUF_ADDR_ERR_INT_RAW        at 0 range 15 .. 15;
      SLV_CMD_ERR_INT_RAW             at 0 range 16 .. 16;
      MST_RX_AFIFO_WFULL_ERR_INT_RAW  at 0 range 17 .. 17;
      MST_TX_AFIFO_REMPTY_ERR_INT_RAW at 0 range 18 .. 18;
      APP2_INT_RAW                    at 0 range 19 .. 19;
      APP1_INT_RAW                    at 0 range 20 .. 20;
      Reserved_21_31                  at 0 range 21 .. 31;
   end record;

   --  SPI interrupt status register
   type DMA_INT_ST_Register is record
      --  Read-only. The status bit for SPI_DMA_INFIFO_FULL_ERR_INT interrupt.
      DMA_INFIFO_FULL_ERR_INT_ST     : Boolean;
      --  Read-only. The status bit for SPI_DMA_OUTFIFO_EMPTY_ERR_INT
      --  interrupt.
      DMA_OUTFIFO_EMPTY_ERR_INT_ST   : Boolean;
      --  Read-only. The status bit for SPI slave Ex_QPI interrupt.
      SLV_EX_QPI_INT_ST              : Boolean;
      --  Read-only. The status bit for SPI slave En_QPI interrupt.
      SLV_EN_QPI_INT_ST              : Boolean;
      --  Read-only. The status bit for SPI slave CMD7 interrupt.
      SLV_CMD7_INT_ST                : Boolean;
      --  Read-only. The status bit for SPI slave CMD8 interrupt.
      SLV_CMD8_INT_ST                : Boolean;
      --  Read-only. The status bit for SPI slave CMD9 interrupt.
      SLV_CMD9_INT_ST                : Boolean;
      --  Read-only. The status bit for SPI slave CMDA interrupt.
      SLV_CMDA_INT_ST                : Boolean;
      --  Read-only. The status bit for SPI_SLV_RD_DMA_DONE_INT interrupt.
      SLV_RD_DMA_DONE_INT_ST         : Boolean;
      --  Read-only. The status bit for SPI_SLV_WR_DMA_DONE_INT interrupt.
      SLV_WR_DMA_DONE_INT_ST         : Boolean;
      --  Read-only. The status bit for SPI_SLV_RD_BUF_DONE_INT interrupt.
      SLV_RD_BUF_DONE_INT_ST         : Boolean;
      --  Read-only. The status bit for SPI_SLV_WR_BUF_DONE_INT interrupt.
      SLV_WR_BUF_DONE_INT_ST         : Boolean;
      --  Read-only. The status bit for SPI_TRANS_DONE_INT interrupt.
      TRANS_DONE_INT_ST              : Boolean;
      --  Read-only. The status bit for SPI_DMA_SEG_TRANS_DONE_INT interrupt.
      DMA_SEG_TRANS_DONE_INT_ST      : Boolean;
      --  Read-only. The status bit for SPI_SEG_MAGIC_ERR_INT interrupt.
      SEG_MAGIC_ERR_INT_ST           : Boolean;
      --  Read-only. The status bit for SPI_SLV_BUF_ADDR_ERR_INT interrupt.
      SLV_BUF_ADDR_ERR_INT_ST        : Boolean;
      --  Read-only. The status bit for SPI_SLV_CMD_ERR_INT interrupt.
      SLV_CMD_ERR_INT_ST             : Boolean;
      --  Read-only. The status bit for SPI_MST_RX_AFIFO_WFULL_ERR_INT
      --  interrupt.
      MST_RX_AFIFO_WFULL_ERR_INT_ST  : Boolean;
      --  Read-only. The status bit for SPI_MST_TX_AFIFO_REMPTY_ERR_INT
      --  interrupt.
      MST_TX_AFIFO_REMPTY_ERR_INT_ST : Boolean;
      --  Read-only. The status bit for SPI_APP2_INT interrupt.
      APP2_INT_ST                    : Boolean;
      --  Read-only. The status bit for SPI_APP1_INT interrupt.
      APP1_INT_ST                    : Boolean;
      --  unspecified
      Reserved_21_31                 : ESP32S3_Registers.UInt11;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_INT_ST_Register use record
      DMA_INFIFO_FULL_ERR_INT_ST     at 0 range 0 .. 0;
      DMA_OUTFIFO_EMPTY_ERR_INT_ST   at 0 range 1 .. 1;
      SLV_EX_QPI_INT_ST              at 0 range 2 .. 2;
      SLV_EN_QPI_INT_ST              at 0 range 3 .. 3;
      SLV_CMD7_INT_ST                at 0 range 4 .. 4;
      SLV_CMD8_INT_ST                at 0 range 5 .. 5;
      SLV_CMD9_INT_ST                at 0 range 6 .. 6;
      SLV_CMDA_INT_ST                at 0 range 7 .. 7;
      SLV_RD_DMA_DONE_INT_ST         at 0 range 8 .. 8;
      SLV_WR_DMA_DONE_INT_ST         at 0 range 9 .. 9;
      SLV_RD_BUF_DONE_INT_ST         at 0 range 10 .. 10;
      SLV_WR_BUF_DONE_INT_ST         at 0 range 11 .. 11;
      TRANS_DONE_INT_ST              at 0 range 12 .. 12;
      DMA_SEG_TRANS_DONE_INT_ST      at 0 range 13 .. 13;
      SEG_MAGIC_ERR_INT_ST           at 0 range 14 .. 14;
      SLV_BUF_ADDR_ERR_INT_ST        at 0 range 15 .. 15;
      SLV_CMD_ERR_INT_ST             at 0 range 16 .. 16;
      MST_RX_AFIFO_WFULL_ERR_INT_ST  at 0 range 17 .. 17;
      MST_TX_AFIFO_REMPTY_ERR_INT_ST at 0 range 18 .. 18;
      APP2_INT_ST                    at 0 range 19 .. 19;
      APP1_INT_ST                    at 0 range 20 .. 20;
      Reserved_21_31                 at 0 range 21 .. 31;
   end record;

   --  SPI interrupt software set register
   type DMA_INT_SET_Register is record
      --  Write-only. The software set bit for SPI_DMA_INFIFO_FULL_ERR_INT
      --  interrupt.
      DMA_INFIFO_FULL_ERR_INT_SET     : Boolean := False;
      --  Write-only. The software set bit for SPI_DMA_OUTFIFO_EMPTY_ERR_INT
      --  interrupt.
      DMA_OUTFIFO_EMPTY_ERR_INT_SET   : Boolean := False;
      --  Write-only. The software set bit for SPI slave Ex_QPI interrupt.
      SLV_EX_QPI_INT_SET              : Boolean := False;
      --  Write-only. The software set bit for SPI slave En_QPI interrupt.
      SLV_EN_QPI_INT_SET              : Boolean := False;
      --  Write-only. The software set bit for SPI slave CMD7 interrupt.
      SLV_CMD7_INT_SET                : Boolean := False;
      --  Write-only. The software set bit for SPI slave CMD8 interrupt.
      SLV_CMD8_INT_SET                : Boolean := False;
      --  Write-only. The software set bit for SPI slave CMD9 interrupt.
      SLV_CMD9_INT_SET                : Boolean := False;
      --  Write-only. The software set bit for SPI slave CMDA interrupt.
      SLV_CMDA_INT_SET                : Boolean := False;
      --  Write-only. The software set bit for SPI_SLV_RD_DMA_DONE_INT
      --  interrupt.
      SLV_RD_DMA_DONE_INT_SET         : Boolean := False;
      --  Write-only. The software set bit for SPI_SLV_WR_DMA_DONE_INT
      --  interrupt.
      SLV_WR_DMA_DONE_INT_SET         : Boolean := False;
      --  Write-only. The software set bit for SPI_SLV_RD_BUF_DONE_INT
      --  interrupt.
      SLV_RD_BUF_DONE_INT_SET         : Boolean := False;
      --  Write-only. The software set bit for SPI_SLV_WR_BUF_DONE_INT
      --  interrupt.
      SLV_WR_BUF_DONE_INT_SET         : Boolean := False;
      --  Write-only. The software set bit for SPI_TRANS_DONE_INT interrupt.
      TRANS_DONE_INT_SET              : Boolean := False;
      --  Write-only. The software set bit for SPI_DMA_SEG_TRANS_DONE_INT
      --  interrupt.
      DMA_SEG_TRANS_DONE_INT_SET      : Boolean := False;
      --  Write-only. The software set bit for SPI_SEG_MAGIC_ERR_INT interrupt.
      SEG_MAGIC_ERR_INT_SET           : Boolean := False;
      --  Write-only. The software set bit for SPI_SLV_BUF_ADDR_ERR_INT
      --  interrupt.
      SLV_BUF_ADDR_ERR_INT_SET        : Boolean := False;
      --  Write-only. The software set bit for SPI_SLV_CMD_ERR_INT interrupt.
      SLV_CMD_ERR_INT_SET             : Boolean := False;
      --  Write-only. The software set bit for SPI_MST_RX_AFIFO_WFULL_ERR_INT
      --  interrupt.
      MST_RX_AFIFO_WFULL_ERR_INT_SET  : Boolean := False;
      --  Write-only. The software set bit for SPI_MST_TX_AFIFO_REMPTY_ERR_INT
      --  interrupt.
      MST_TX_AFIFO_REMPTY_ERR_INT_SET : Boolean := False;
      --  Write-only. The software set bit for SPI_APP2_INT interrupt.
      APP2_INT_SET                    : Boolean := False;
      --  Write-only. The software set bit for SPI_APP1_INT interrupt.
      APP1_INT_SET                    : Boolean := False;
      --  unspecified
      Reserved_21_31                  : ESP32S3_Registers.UInt11 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DMA_INT_SET_Register use record
      DMA_INFIFO_FULL_ERR_INT_SET     at 0 range 0 .. 0;
      DMA_OUTFIFO_EMPTY_ERR_INT_SET   at 0 range 1 .. 1;
      SLV_EX_QPI_INT_SET              at 0 range 2 .. 2;
      SLV_EN_QPI_INT_SET              at 0 range 3 .. 3;
      SLV_CMD7_INT_SET                at 0 range 4 .. 4;
      SLV_CMD8_INT_SET                at 0 range 5 .. 5;
      SLV_CMD9_INT_SET                at 0 range 6 .. 6;
      SLV_CMDA_INT_SET                at 0 range 7 .. 7;
      SLV_RD_DMA_DONE_INT_SET         at 0 range 8 .. 8;
      SLV_WR_DMA_DONE_INT_SET         at 0 range 9 .. 9;
      SLV_RD_BUF_DONE_INT_SET         at 0 range 10 .. 10;
      SLV_WR_BUF_DONE_INT_SET         at 0 range 11 .. 11;
      TRANS_DONE_INT_SET              at 0 range 12 .. 12;
      DMA_SEG_TRANS_DONE_INT_SET      at 0 range 13 .. 13;
      SEG_MAGIC_ERR_INT_SET           at 0 range 14 .. 14;
      SLV_BUF_ADDR_ERR_INT_SET        at 0 range 15 .. 15;
      SLV_CMD_ERR_INT_SET             at 0 range 16 .. 16;
      MST_RX_AFIFO_WFULL_ERR_INT_SET  at 0 range 17 .. 17;
      MST_TX_AFIFO_REMPTY_ERR_INT_SET at 0 range 18 .. 18;
      APP2_INT_SET                    at 0 range 19 .. 19;
      APP1_INT_SET                    at 0 range 20 .. 20;
      Reserved_21_31                  at 0 range 21 .. 31;
   end record;

   subtype SLAVE_CLK_MODE_Field is ESP32S3_Registers.UInt2;
   subtype SLAVE_DMA_SEG_MAGIC_VALUE_Field is ESP32S3_Registers.UInt4;

   --  SPI slave control register
   type SLAVE_Register is record
      --  SPI clock mode bits. 0: SPI clock is off when CS inactive 1: SPI
      --  clock is delayed one cycle after CS inactive 2: SPI clock is delayed
      --  two cycles after CS inactive 3: SPI clock is alwasy on. Can be
      --  configured in CONF state.
      CLK_MODE            : SLAVE_CLK_MODE_Field := 16#0#;
      --  {CPOL, CPHA},1: support spi clk mode 1 and 3, first edge output data
      --  B[0]/B[7]. 0: support spi clk mode 0 and 2, first edge output data
      --  B[1]/B[6].
      CLK_MODE_13         : Boolean := False;
      --  It saves half a cycle when tsck is the same as rsck. 1: output data
      --  at rsck posedge 0: output data at tsck posedge
      RSCK_DATA_OUT       : Boolean := False;
      --  unspecified
      Reserved_4_7        : ESP32S3_Registers.UInt4 := 16#0#;
      --  1: SPI_SLV_DATA_BITLEN stores data bit length of master-read-slave
      --  data length in DMA controlled mode(Rd_DMA). 0: others
      SLV_RDDMA_BITLEN_EN : Boolean := False;
      --  1: SPI_SLV_DATA_BITLEN stores data bit length of
      --  master-write-to-slave data length in DMA controlled mode(Wr_DMA). 0:
      --  others
      SLV_WRDMA_BITLEN_EN : Boolean := False;
      --  1: SPI_SLV_DATA_BITLEN stores data bit length of master-read-slave
      --  data length in CPU controlled mode(Rd_BUF). 0: others
      SLV_RDBUF_BITLEN_EN : Boolean := False;
      --  1: SPI_SLV_DATA_BITLEN stores data bit length of
      --  master-write-to-slave data length in CPU controlled mode(Wr_BUF). 0:
      --  others
      SLV_WRBUF_BITLEN_EN : Boolean := False;
      --  unspecified
      Reserved_12_21      : ESP32S3_Registers.UInt10 := 16#0#;
      --  The magic value of BM table in master DMA seg-trans.
      DMA_SEG_MAGIC_VALUE : SLAVE_DMA_SEG_MAGIC_VALUE_Field := 16#A#;
      --  Set SPI work mode. 1: slave mode 0: master mode.
      MODE                : Boolean := False;
      --  Write-only. Software reset enable, reset the spi clock line cs line
      --  and data lines. Can be configured in CONF state.
      SOFT_RESET          : Boolean := False;
      --  1: Enable the DMA CONF phase of current seg-trans operation, which
      --  means seg-trans will start. 0: This is not seg-trans mode.
      USR_CONF            : Boolean := False;
      --  unspecified
      Reserved_29_31      : ESP32S3_Registers.UInt3 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SLAVE_Register use record
      CLK_MODE            at 0 range 0 .. 1;
      CLK_MODE_13         at 0 range 2 .. 2;
      RSCK_DATA_OUT       at 0 range 3 .. 3;
      Reserved_4_7        at 0 range 4 .. 7;
      SLV_RDDMA_BITLEN_EN at 0 range 8 .. 8;
      SLV_WRDMA_BITLEN_EN at 0 range 9 .. 9;
      SLV_RDBUF_BITLEN_EN at 0 range 10 .. 10;
      SLV_WRBUF_BITLEN_EN at 0 range 11 .. 11;
      Reserved_12_21      at 0 range 12 .. 21;
      DMA_SEG_MAGIC_VALUE at 0 range 22 .. 25;
      MODE                at 0 range 26 .. 26;
      SOFT_RESET          at 0 range 27 .. 27;
      USR_CONF            at 0 range 28 .. 28;
      Reserved_29_31      at 0 range 29 .. 31;
   end record;

   subtype SLAVE1_SLV_DATA_BITLEN_Field is ESP32S3_Registers.UInt18;
   subtype SLAVE1_SLV_LAST_COMMAND_Field is ESP32S3_Registers.Byte;
   subtype SLAVE1_SLV_LAST_ADDR_Field is ESP32S3_Registers.UInt6;

   --  SPI slave control register 1
   type SLAVE1_Register is record
      --  The transferred data bit length in SPI slave FD and HD mode.
      SLV_DATA_BITLEN  : SLAVE1_SLV_DATA_BITLEN_Field := 16#0#;
      --  In the slave mode it is the value of command.
      SLV_LAST_COMMAND : SLAVE1_SLV_LAST_COMMAND_Field := 16#0#;
      --  In the slave mode it is the value of address.
      SLV_LAST_ADDR    : SLAVE1_SLV_LAST_ADDR_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SLAVE1_Register use record
      SLV_DATA_BITLEN  at 0 range 0 .. 17;
      SLV_LAST_COMMAND at 0 range 18 .. 25;
      SLV_LAST_ADDR    at 0 range 26 .. 31;
   end record;

   --  SPI module clock and register clock control
   type CLK_GATE_Register is record
      --  Set this bit to enable clk gate
      CLK_EN         : Boolean := False;
      --  Set this bit to power on the SPI module clock.
      MST_CLK_ACTIVE : Boolean := False;
      --  This bit is used to select SPI module clock source in master mode. 1:
      --  PLL_CLK_80M. 0: XTAL CLK.
      MST_CLK_SEL    : Boolean := False;
      --  unspecified
      Reserved_3_31  : ESP32S3_Registers.UInt29 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLK_GATE_Register use record
      CLK_EN         at 0 range 0 .. 0;
      MST_CLK_ACTIVE at 0 range 1 .. 1;
      MST_CLK_SEL    at 0 range 2 .. 2;
      Reserved_3_31  at 0 range 3 .. 31;
   end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt28;

   --  Version control
   type DATE_Register is record
      --  SPI register version.
      DATE           : DATE_DATE_Field := 16#2101190#;
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

   --  SPI (Serial Peripheral Interface) Controller 2
   type SPI2_Peripheral is record
      --  Command control register
      CMD         : aliased CMD_Register;
      --  Address value register
      ADDR        : aliased ESP32S3_Registers.UInt32;
      --  SPI control register
      CTRL        : aliased CTRL_Register;
      --  SPI clock control register
      CLOCK       : aliased CLOCK_Register;
      --  SPI USER control register
      USER        : aliased USER_Register;
      --  SPI USER control register 1
      USER1       : aliased USER1_Register;
      --  SPI USER control register 2
      USER2       : aliased USER2_Register;
      --  SPI data bit length control register
      MS_DLEN     : aliased MS_DLEN_Register;
      --  SPI misc register
      MISC        : aliased MISC_Register;
      --  SPI input delay mode configuration
      DIN_MODE    : aliased DIN_MODE_Register;
      --  SPI input delay number configuration
      DIN_NUM     : aliased DIN_NUM_Register;
      --  SPI output delay mode configuration
      DOUT_MODE   : aliased DOUT_MODE_Register;
      --  SPI DMA control register
      DMA_CONF    : aliased DMA_CONF_Register;
      --  SPI interrupt enable register
      DMA_INT_ENA : aliased DMA_INT_ENA_Register;
      --  SPI interrupt clear register
      DMA_INT_CLR : aliased DMA_INT_CLR_Register;
      --  SPI interrupt raw register
      DMA_INT_RAW : aliased DMA_INT_RAW_Register;
      --  SPI interrupt status register
      DMA_INT_ST  : aliased DMA_INT_ST_Register;
      --  SPI interrupt software set register
      DMA_INT_SET : aliased DMA_INT_SET_Register;
      --  SPI CPU-controlled buffer0
      W0          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer1
      W1          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer2
      W2          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer3
      W3          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer4
      W4          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer5
      W5          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer6
      W6          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer7
      W7          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer8
      W8          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer9
      W9          : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer10
      W10         : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer11
      W11         : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer12
      W12         : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer13
      W13         : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer14
      W14         : aliased ESP32S3_Registers.UInt32;
      --  SPI CPU-controlled buffer15
      W15         : aliased ESP32S3_Registers.UInt32;
      --  SPI slave control register
      SLAVE       : aliased SLAVE_Register;
      --  SPI slave control register 1
      SLAVE1      : aliased SLAVE1_Register;
      --  SPI module clock and register clock control
      CLK_GATE    : aliased CLK_GATE_Register;
      --  Version control
      DATE        : aliased DATE_Register;
   end record
     with Volatile;

   for SPI2_Peripheral use record
      CMD         at 16#0# range 0 .. 31;
      ADDR        at 16#4# range 0 .. 31;
      CTRL        at 16#8# range 0 .. 31;
      CLOCK       at 16#C# range 0 .. 31;
      USER        at 16#10# range 0 .. 31;
      USER1       at 16#14# range 0 .. 31;
      USER2       at 16#18# range 0 .. 31;
      MS_DLEN     at 16#1C# range 0 .. 31;
      MISC        at 16#20# range 0 .. 31;
      DIN_MODE    at 16#24# range 0 .. 31;
      DIN_NUM     at 16#28# range 0 .. 31;
      DOUT_MODE   at 16#2C# range 0 .. 31;
      DMA_CONF    at 16#30# range 0 .. 31;
      DMA_INT_ENA at 16#34# range 0 .. 31;
      DMA_INT_CLR at 16#38# range 0 .. 31;
      DMA_INT_RAW at 16#3C# range 0 .. 31;
      DMA_INT_ST  at 16#40# range 0 .. 31;
      DMA_INT_SET at 16#44# range 0 .. 31;
      W0          at 16#98# range 0 .. 31;
      W1          at 16#9C# range 0 .. 31;
      W2          at 16#A0# range 0 .. 31;
      W3          at 16#A4# range 0 .. 31;
      W4          at 16#A8# range 0 .. 31;
      W5          at 16#AC# range 0 .. 31;
      W6          at 16#B0# range 0 .. 31;
      W7          at 16#B4# range 0 .. 31;
      W8          at 16#B8# range 0 .. 31;
      W9          at 16#BC# range 0 .. 31;
      W10         at 16#C0# range 0 .. 31;
      W11         at 16#C4# range 0 .. 31;
      W12         at 16#C8# range 0 .. 31;
      W13         at 16#CC# range 0 .. 31;
      W14         at 16#D0# range 0 .. 31;
      W15         at 16#D4# range 0 .. 31;
      SLAVE       at 16#E0# range 0 .. 31;
      SLAVE1      at 16#E4# range 0 .. 31;
      CLK_GATE    at 16#E8# range 0 .. 31;
      DATE        at 16#F0# range 0 .. 31;
   end record;

   --  SPI (Serial Peripheral Interface) Controller 2
   SPI2_Periph : aliased SPI2_Peripheral
     with Import, Address => SPI2_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

   --  SPI (Serial Peripheral Interface) Controller 3
   SPI3_Periph : aliased SPI2_Peripheral
     with Import, Address => SPI3_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.SPI2;
