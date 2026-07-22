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

package ESP32S3_Registers.USB_DEVICE is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype EP1_RDWR_BYTE_Field is ESP32S3_Registers.Byte;

   --  Endpoint 1 FIFO register
   type EP1_Register is record
      --  Write and read byte data to/from UART Tx/Rx FIFO through this field.
      --  When USB_DEVICE_SERIAL_IN_EMPTY_INT is set, then user can write data
      --  (up to 64 bytes) into UART Tx FIFO. When
      --  USB_DEVICE_SERIAL_OUT_RECV_PKT_INT is set, user can check
      --  USB_DEVICE_OUT_EP1_WR_ADDR USB_DEVICE_OUT_EP0_RD_ADDR to know how
      --  many data is received, then read data from UART Rx FIFO.
      RDWR_BYTE     : EP1_RDWR_BYTE_Field := 16#0#;
      --  unspecified
      Reserved_8_31 : ESP32S3_Registers.UInt24 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for EP1_Register use
     record
       RDWR_BYTE at 0 range 0 .. 7;
       Reserved_8_31 at 0 range 8 .. 31;
     end record;

   --  Endpoint 1 configure and status register
   type EP1_CONF_Register is record
      --  Write-only. Set this bit to indicate writing byte data to UART Tx
      --  FIFO is done.
      WR_DONE                  : Boolean := False;
      --  Read-only. 1'b1: Indicate UART Tx FIFO is not full and can write data
      --  into in. After writing USB_DEVICE_WR_DONE, this bit would be 0 until
      --  data in UART Tx FIFO is read by USB Host.
      SERIAL_IN_EP_DATA_FREE   : Boolean := True;
      --  Read-only. 1'b1: Indicate there is data in UART Rx FIFO.
      SERIAL_OUT_EP_DATA_AVAIL : Boolean := False;
      --  unspecified
      Reserved_3_31            : ESP32S3_Registers.UInt29 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for EP1_CONF_Register use
     record
       WR_DONE at 0 range 0 .. 0;
       SERIAL_IN_EP_DATA_FREE at 0 range 1 .. 1;
       SERIAL_OUT_EP_DATA_AVAIL at 0 range 2 .. 2;
       Reserved_3_31 at 0 range 3 .. 31;
     end record;

   --  Raw status interrupt
   type INT_RAW_Register is record
      --  The raw interrupt bit turns to high level when flush cmd is received
      --  for IN endpoint 2 of JTAG.
      JTAG_IN_FLUSH_INT_RAW        : Boolean := False;
      --  The raw interrupt bit turns to high level when SOF frame is received.
      SOF_INT_RAW                  : Boolean := False;
      --  The raw interrupt bit turns to high level when Serial Port OUT
      --  Endpoint received one packet.
      SERIAL_OUT_RECV_PKT_INT_RAW  : Boolean := False;
      --  The raw interrupt bit turns to high level when Serial Port IN
      --  Endpoint is empty.
      SERIAL_IN_EMPTY_INT_RAW      : Boolean := True;
      --  The raw interrupt bit turns to high level when pid error is detected.
      PID_ERR_INT_RAW              : Boolean := False;
      --  The raw interrupt bit turns to high level when CRC5 error is
      --  detected.
      CRC5_ERR_INT_RAW             : Boolean := False;
      --  The raw interrupt bit turns to high level when CRC16 error is
      --  detected.
      CRC16_ERR_INT_RAW            : Boolean := False;
      --  The raw interrupt bit turns to high level when stuff error is
      --  detected.
      STUFF_ERR_INT_RAW            : Boolean := False;
      --  The raw interrupt bit turns to high level when IN token for IN
      --  endpoint 1 is received.
      IN_TOKEN_REC_IN_EP1_INT_RAW  : Boolean := False;
      --  The raw interrupt bit turns to high level when usb bus reset is
      --  detected.
      USB_BUS_RESET_INT_RAW        : Boolean := False;
      --  The raw interrupt bit turns to high level when OUT endpoint 1
      --  received packet with zero palyload.
      OUT_EP1_ZERO_PAYLOAD_INT_RAW : Boolean := False;
      --  The raw interrupt bit turns to high level when OUT endpoint 2
      --  received packet with zero palyload.
      OUT_EP2_ZERO_PAYLOAD_INT_RAW : Boolean := False;
      --  unspecified
      Reserved_12_31               : ESP32S3_Registers.UInt20 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_RAW_Register use
     record
       JTAG_IN_FLUSH_INT_RAW at 0 range 0 .. 0;
       SOF_INT_RAW at 0 range 1 .. 1;
       SERIAL_OUT_RECV_PKT_INT_RAW at 0 range 2 .. 2;
       SERIAL_IN_EMPTY_INT_RAW at 0 range 3 .. 3;
       PID_ERR_INT_RAW at 0 range 4 .. 4;
       CRC5_ERR_INT_RAW at 0 range 5 .. 5;
       CRC16_ERR_INT_RAW at 0 range 6 .. 6;
       STUFF_ERR_INT_RAW at 0 range 7 .. 7;
       IN_TOKEN_REC_IN_EP1_INT_RAW at 0 range 8 .. 8;
       USB_BUS_RESET_INT_RAW at 0 range 9 .. 9;
       OUT_EP1_ZERO_PAYLOAD_INT_RAW at 0 range 10 .. 10;
       OUT_EP2_ZERO_PAYLOAD_INT_RAW at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   --  Masked interrupt
   type INT_ST_Register is record
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_JTAG_IN_FLUSH_INT interrupt.
      JTAG_IN_FLUSH_INT_ST        : Boolean;
      --  Read-only. The raw interrupt status bit for the USB_DEVICE_SOF_INT
      --  interrupt.
      SOF_INT_ST                  : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_SERIAL_OUT_RECV_PKT_INT interrupt.
      SERIAL_OUT_RECV_PKT_INT_ST  : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_SERIAL_IN_EMPTY_INT interrupt.
      SERIAL_IN_EMPTY_INT_ST      : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_PID_ERR_INT interrupt.
      PID_ERR_INT_ST              : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_CRC5_ERR_INT interrupt.
      CRC5_ERR_INT_ST             : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_CRC16_ERR_INT interrupt.
      CRC16_ERR_INT_ST            : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_STUFF_ERR_INT interrupt.
      STUFF_ERR_INT_ST            : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_IN_TOKEN_REC_IN_EP1_INT interrupt.
      IN_TOKEN_REC_IN_EP1_INT_ST  : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_USB_BUS_RESET_INT interrupt.
      USB_BUS_RESET_INT_ST        : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_OUT_EP1_ZERO_PAYLOAD_INT interrupt.
      OUT_EP1_ZERO_PAYLOAD_INT_ST : Boolean;
      --  Read-only. The raw interrupt status bit for the
      --  USB_DEVICE_OUT_EP2_ZERO_PAYLOAD_INT interrupt.
      OUT_EP2_ZERO_PAYLOAD_INT_ST : Boolean;
      --  unspecified
      Reserved_12_31              : ESP32S3_Registers.UInt20;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ST_Register use
     record
       JTAG_IN_FLUSH_INT_ST at 0 range 0 .. 0;
       SOF_INT_ST at 0 range 1 .. 1;
       SERIAL_OUT_RECV_PKT_INT_ST at 0 range 2 .. 2;
       SERIAL_IN_EMPTY_INT_ST at 0 range 3 .. 3;
       PID_ERR_INT_ST at 0 range 4 .. 4;
       CRC5_ERR_INT_ST at 0 range 5 .. 5;
       CRC16_ERR_INT_ST at 0 range 6 .. 6;
       STUFF_ERR_INT_ST at 0 range 7 .. 7;
       IN_TOKEN_REC_IN_EP1_INT_ST at 0 range 8 .. 8;
       USB_BUS_RESET_INT_ST at 0 range 9 .. 9;
       OUT_EP1_ZERO_PAYLOAD_INT_ST at 0 range 10 .. 10;
       OUT_EP2_ZERO_PAYLOAD_INT_ST at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   --  Interrupt enable bits
   type INT_ENA_Register is record
      --  The interrupt enable bit for the USB_DEVICE_JTAG_IN_FLUSH_INT
      --  interrupt.
      JTAG_IN_FLUSH_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_SOF_INT interrupt.
      SOF_INT_ENA                  : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_SERIAL_OUT_RECV_PKT_INT
      --  interrupt.
      SERIAL_OUT_RECV_PKT_INT_ENA  : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_SERIAL_IN_EMPTY_INT
      --  interrupt.
      SERIAL_IN_EMPTY_INT_ENA      : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_PID_ERR_INT interrupt.
      PID_ERR_INT_ENA              : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_CRC5_ERR_INT interrupt.
      CRC5_ERR_INT_ENA             : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_CRC16_ERR_INT interrupt.
      CRC16_ERR_INT_ENA            : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_STUFF_ERR_INT interrupt.
      STUFF_ERR_INT_ENA            : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_IN_TOKEN_REC_IN_EP1_INT
      --  interrupt.
      IN_TOKEN_REC_IN_EP1_INT_ENA  : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_USB_BUS_RESET_INT
      --  interrupt.
      USB_BUS_RESET_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_OUT_EP1_ZERO_PAYLOAD_INT
      --  interrupt.
      OUT_EP1_ZERO_PAYLOAD_INT_ENA : Boolean := False;
      --  The interrupt enable bit for the USB_DEVICE_OUT_EP2_ZERO_PAYLOAD_INT
      --  interrupt.
      OUT_EP2_ZERO_PAYLOAD_INT_ENA : Boolean := False;
      --  unspecified
      Reserved_12_31               : ESP32S3_Registers.UInt20 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_ENA_Register use
     record
       JTAG_IN_FLUSH_INT_ENA at 0 range 0 .. 0;
       SOF_INT_ENA at 0 range 1 .. 1;
       SERIAL_OUT_RECV_PKT_INT_ENA at 0 range 2 .. 2;
       SERIAL_IN_EMPTY_INT_ENA at 0 range 3 .. 3;
       PID_ERR_INT_ENA at 0 range 4 .. 4;
       CRC5_ERR_INT_ENA at 0 range 5 .. 5;
       CRC16_ERR_INT_ENA at 0 range 6 .. 6;
       STUFF_ERR_INT_ENA at 0 range 7 .. 7;
       IN_TOKEN_REC_IN_EP1_INT_ENA at 0 range 8 .. 8;
       USB_BUS_RESET_INT_ENA at 0 range 9 .. 9;
       OUT_EP1_ZERO_PAYLOAD_INT_ENA at 0 range 10 .. 10;
       OUT_EP2_ZERO_PAYLOAD_INT_ENA at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   --  Interrupt clear bits
   type INT_CLR_Register is record
      --  Write-only. Set this bit to clear the USB_DEVICE_JTAG_IN_FLUSH_INT
      --  interrupt.
      JTAG_IN_FLUSH_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear the USB_DEVICE_JTAG_SOF_INT
      --  interrupt.
      SOF_INT_CLR                  : Boolean := False;
      --  Write-only. Set this bit to clear the
      --  USB_DEVICE_SERIAL_OUT_RECV_PKT_INT interrupt.
      SERIAL_OUT_RECV_PKT_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the USB_DEVICE_SERIAL_IN_EMPTY_INT
      --  interrupt.
      SERIAL_IN_EMPTY_INT_CLR      : Boolean := False;
      --  Write-only. Set this bit to clear the USB_DEVICE_PID_ERR_INT
      --  interrupt.
      PID_ERR_INT_CLR              : Boolean := False;
      --  Write-only. Set this bit to clear the USB_DEVICE_CRC5_ERR_INT
      --  interrupt.
      CRC5_ERR_INT_CLR             : Boolean := False;
      --  Write-only. Set this bit to clear the USB_DEVICE_CRC16_ERR_INT
      --  interrupt.
      CRC16_ERR_INT_CLR            : Boolean := False;
      --  Write-only. Set this bit to clear the USB_DEVICE_STUFF_ERR_INT
      --  interrupt.
      STUFF_ERR_INT_CLR            : Boolean := False;
      --  Write-only. Set this bit to clear the USB_DEVICE_IN_TOKEN_IN_EP1_INT
      --  interrupt.
      IN_TOKEN_REC_IN_EP1_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the USB_DEVICE_USB_BUS_RESET_INT
      --  interrupt.
      USB_BUS_RESET_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear the
      --  USB_DEVICE_OUT_EP1_ZERO_PAYLOAD_INT interrupt.
      OUT_EP1_ZERO_PAYLOAD_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear the
      --  USB_DEVICE_OUT_EP2_ZERO_PAYLOAD_INT interrupt.
      OUT_EP2_ZERO_PAYLOAD_INT_CLR : Boolean := False;
      --  unspecified
      Reserved_12_31               : ESP32S3_Registers.UInt20 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for INT_CLR_Register use
     record
       JTAG_IN_FLUSH_INT_CLR at 0 range 0 .. 0;
       SOF_INT_CLR at 0 range 1 .. 1;
       SERIAL_OUT_RECV_PKT_INT_CLR at 0 range 2 .. 2;
       SERIAL_IN_EMPTY_INT_CLR at 0 range 3 .. 3;
       PID_ERR_INT_CLR at 0 range 4 .. 4;
       CRC5_ERR_INT_CLR at 0 range 5 .. 5;
       CRC16_ERR_INT_CLR at 0 range 6 .. 6;
       STUFF_ERR_INT_CLR at 0 range 7 .. 7;
       IN_TOKEN_REC_IN_EP1_INT_CLR at 0 range 8 .. 8;
       USB_BUS_RESET_INT_CLR at 0 range 9 .. 9;
       OUT_EP1_ZERO_PAYLOAD_INT_CLR at 0 range 10 .. 10;
       OUT_EP2_ZERO_PAYLOAD_INT_CLR at 0 range 11 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   subtype CONF0_VREFH_Field is ESP32S3_Registers.UInt2;
   subtype CONF0_VREFL_Field is ESP32S3_Registers.UInt2;

   --  Configure 0 register
   type CONF0_Register is record
      --  Select internal/external PHY
      PHY_SEL             : Boolean := False;
      --  Enable software control USB D+ D- exchange
      EXCHG_PINS_OVERRIDE : Boolean := False;
      --  USB D+ D- exchange
      EXCHG_PINS          : Boolean := False;
      --  Control single-end input high threshold,1.76V to 2V, step 80mV
      VREFH               : CONF0_VREFH_Field := 16#0#;
      --  Control single-end input low threshold,0.8V to 1.04V, step 80mV
      VREFL               : CONF0_VREFL_Field := 16#0#;
      --  Enable software control input threshold
      VREF_OVERRIDE       : Boolean := False;
      --  Enable software control USB D+ D- pullup pulldown
      PAD_PULL_OVERRIDE   : Boolean := False;
      --  Control USB D+ pull up.
      DP_PULLUP           : Boolean := True;
      --  Control USB D+ pull down.
      DP_PULLDOWN         : Boolean := False;
      --  Control USB D- pull up.
      DM_PULLUP           : Boolean := False;
      --  Control USB D- pull down.
      DM_PULLDOWN         : Boolean := False;
      --  Control pull up value.
      PULLUP_VALUE        : Boolean := False;
      --  Enable USB pad function.
      USB_PAD_ENABLE      : Boolean := True;
      --  0: TX output at clock negedge. 1: Tx output at clock posedge.
      PHY_TX_EDGE_SEL     : Boolean := False;
      --  Set this bit usb_jtag, the connection between usb_jtag and internal
      --  JTAG is disconnected, and MTMS, MTDI, MTCK are output through GPIO
      --  Matrix, MTDO is input through GPIO Matrix.
      USB_JTAG_BRIDGE_EN  : Boolean := False;
      --  unspecified
      Reserved_17_31      : ESP32S3_Registers.UInt15 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CONF0_Register use
     record
       PHY_SEL at 0 range 0 .. 0;
       EXCHG_PINS_OVERRIDE at 0 range 1 .. 1;
       EXCHG_PINS at 0 range 2 .. 2;
       VREFH at 0 range 3 .. 4;
       VREFL at 0 range 5 .. 6;
       VREF_OVERRIDE at 0 range 7 .. 7;
       PAD_PULL_OVERRIDE at 0 range 8 .. 8;
       DP_PULLUP at 0 range 9 .. 9;
       DP_PULLDOWN at 0 range 10 .. 10;
       DM_PULLUP at 0 range 11 .. 11;
       DM_PULLDOWN at 0 range 12 .. 12;
       PULLUP_VALUE at 0 range 13 .. 13;
       USB_PAD_ENABLE at 0 range 14 .. 14;
       PHY_TX_EDGE_SEL at 0 range 15 .. 15;
       USB_JTAG_BRIDGE_EN at 0 range 16 .. 16;
       Reserved_17_31 at 0 range 17 .. 31;
     end record;

   --  USB Internal PHY test register
   type TEST_Register is record
      --  Enable test of the USB pad
      ENABLE        : Boolean := False;
      --  USB pad oen in test
      USB_OE        : Boolean := False;
      --  USB D+ tx value in test
      TX_DP         : Boolean := False;
      --  USB D- tx value in test
      TX_DM         : Boolean := False;
      --  Read-only. USB differential rx value in test
      RX_RCV        : Boolean := False;
      --  Read-only. USB D+ rx value in test
      RX_DP         : Boolean := False;
      --  Read-only. USB D- rx value in test
      RX_DM         : Boolean := False;
      --  unspecified
      Reserved_7_31 : ESP32S3_Registers.UInt25 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TEST_Register use
     record
       ENABLE at 0 range 0 .. 0;
       USB_OE at 0 range 1 .. 1;
       TX_DP at 0 range 2 .. 2;
       TX_DM at 0 range 3 .. 3;
       RX_RCV at 0 range 4 .. 4;
       RX_DP at 0 range 5 .. 5;
       RX_DM at 0 range 6 .. 6;
       Reserved_7_31 at 0 range 7 .. 31;
     end record;

   subtype JFIFO_ST_IN_FIFO_CNT_Field is ESP32S3_Registers.UInt2;
   subtype JFIFO_ST_OUT_FIFO_CNT_Field is ESP32S3_Registers.UInt2;

   --  USB-JTAG FIFO status
   type JFIFO_ST_Register is record
      --  Read-only. JTAT in fifo counter.
      IN_FIFO_CNT    : JFIFO_ST_IN_FIFO_CNT_Field := 16#0#;
      --  Read-only. 1: JTAG in fifo is empty.
      IN_FIFO_EMPTY  : Boolean := True;
      --  Read-only. 1: JTAG in fifo is full.
      IN_FIFO_FULL   : Boolean := False;
      --  Read-only. JTAT out fifo counter.
      OUT_FIFO_CNT   : JFIFO_ST_OUT_FIFO_CNT_Field := 16#0#;
      --  Read-only. 1: JTAG out fifo is empty.
      OUT_FIFO_EMPTY : Boolean := True;
      --  Read-only. 1: JTAG out fifo is full.
      OUT_FIFO_FULL  : Boolean := False;
      --  Write 1 to reset JTAG in fifo.
      IN_FIFO_RESET  : Boolean := False;
      --  Write 1 to reset JTAG out fifo.
      OUT_FIFO_RESET : Boolean := False;
      --  unspecified
      Reserved_10_31 : ESP32S3_Registers.UInt22 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for JFIFO_ST_Register use
     record
       IN_FIFO_CNT at 0 range 0 .. 1;
       IN_FIFO_EMPTY at 0 range 2 .. 2;
       IN_FIFO_FULL at 0 range 3 .. 3;
       OUT_FIFO_CNT at 0 range 4 .. 5;
       OUT_FIFO_EMPTY at 0 range 6 .. 6;
       OUT_FIFO_FULL at 0 range 7 .. 7;
       IN_FIFO_RESET at 0 range 8 .. 8;
       OUT_FIFO_RESET at 0 range 9 .. 9;
       Reserved_10_31 at 0 range 10 .. 31;
     end record;

   subtype FRAM_NUM_SOF_FRAME_INDEX_Field is ESP32S3_Registers.UInt11;

   --  SOF frame number
   type FRAM_NUM_Register is record
      --  Read-only. Frame index of received SOF frame.
      SOF_FRAME_INDEX : FRAM_NUM_SOF_FRAME_INDEX_Field;
      --  unspecified
      Reserved_11_31  : ESP32S3_Registers.UInt21;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for FRAM_NUM_Register use
     record
       SOF_FRAME_INDEX at 0 range 0 .. 10;
       Reserved_11_31 at 0 range 11 .. 31;
     end record;

   subtype IN_EP0_ST_IN_EP0_STATE_Field is ESP32S3_Registers.UInt2;
   subtype IN_EP0_ST_IN_EP0_WR_ADDR_Field is ESP32S3_Registers.UInt7;
   subtype IN_EP0_ST_IN_EP0_RD_ADDR_Field is ESP32S3_Registers.UInt7;

   --  IN Endpoint 0 status
   type IN_EP0_ST_Register is record
      --  Read-only. State of IN Endpoint 0.
      IN_EP0_STATE   : IN_EP0_ST_IN_EP0_STATE_Field;
      --  Read-only. Write data address of IN endpoint 0.
      IN_EP0_WR_ADDR : IN_EP0_ST_IN_EP0_WR_ADDR_Field;
      --  Read-only. Read data address of IN endpoint 0.
      IN_EP0_RD_ADDR : IN_EP0_ST_IN_EP0_RD_ADDR_Field;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for IN_EP0_ST_Register use
     record
       IN_EP0_STATE at 0 range 0 .. 1;
       IN_EP0_WR_ADDR at 0 range 2 .. 8;
       IN_EP0_RD_ADDR at 0 range 9 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype IN_EP1_ST_IN_EP1_STATE_Field is ESP32S3_Registers.UInt2;
   subtype IN_EP1_ST_IN_EP1_WR_ADDR_Field is ESP32S3_Registers.UInt7;
   subtype IN_EP1_ST_IN_EP1_RD_ADDR_Field is ESP32S3_Registers.UInt7;

   --  IN Endpoint 1 status
   type IN_EP1_ST_Register is record
      --  Read-only. State of IN Endpoint 1.
      IN_EP1_STATE   : IN_EP1_ST_IN_EP1_STATE_Field;
      --  Read-only. Write data address of IN endpoint 1.
      IN_EP1_WR_ADDR : IN_EP1_ST_IN_EP1_WR_ADDR_Field;
      --  Read-only. Read data address of IN endpoint 1.
      IN_EP1_RD_ADDR : IN_EP1_ST_IN_EP1_RD_ADDR_Field;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for IN_EP1_ST_Register use
     record
       IN_EP1_STATE at 0 range 0 .. 1;
       IN_EP1_WR_ADDR at 0 range 2 .. 8;
       IN_EP1_RD_ADDR at 0 range 9 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype IN_EP2_ST_IN_EP2_STATE_Field is ESP32S3_Registers.UInt2;
   subtype IN_EP2_ST_IN_EP2_WR_ADDR_Field is ESP32S3_Registers.UInt7;
   subtype IN_EP2_ST_IN_EP2_RD_ADDR_Field is ESP32S3_Registers.UInt7;

   --  IN Endpoint 2 status
   type IN_EP2_ST_Register is record
      --  Read-only. State of IN Endpoint 2.
      IN_EP2_STATE   : IN_EP2_ST_IN_EP2_STATE_Field;
      --  Read-only. Write data address of IN endpoint 2.
      IN_EP2_WR_ADDR : IN_EP2_ST_IN_EP2_WR_ADDR_Field;
      --  Read-only. Read data address of IN endpoint 2.
      IN_EP2_RD_ADDR : IN_EP2_ST_IN_EP2_RD_ADDR_Field;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for IN_EP2_ST_Register use
     record
       IN_EP2_STATE at 0 range 0 .. 1;
       IN_EP2_WR_ADDR at 0 range 2 .. 8;
       IN_EP2_RD_ADDR at 0 range 9 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype IN_EP3_ST_IN_EP3_STATE_Field is ESP32S3_Registers.UInt2;
   subtype IN_EP3_ST_IN_EP3_WR_ADDR_Field is ESP32S3_Registers.UInt7;
   subtype IN_EP3_ST_IN_EP3_RD_ADDR_Field is ESP32S3_Registers.UInt7;

   --  IN Endpoint 3 status
   type IN_EP3_ST_Register is record
      --  Read-only. State of IN Endpoint 3.
      IN_EP3_STATE   : IN_EP3_ST_IN_EP3_STATE_Field;
      --  Read-only. Write data address of IN endpoint 3.
      IN_EP3_WR_ADDR : IN_EP3_ST_IN_EP3_WR_ADDR_Field;
      --  Read-only. Read data address of IN endpoint 3.
      IN_EP3_RD_ADDR : IN_EP3_ST_IN_EP3_RD_ADDR_Field;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for IN_EP3_ST_Register use
     record
       IN_EP3_STATE at 0 range 0 .. 1;
       IN_EP3_WR_ADDR at 0 range 2 .. 8;
       IN_EP3_RD_ADDR at 0 range 9 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype OUT_EP0_ST_OUT_EP0_STATE_Field is ESP32S3_Registers.UInt2;
   subtype OUT_EP0_ST_OUT_EP0_WR_ADDR_Field is ESP32S3_Registers.UInt7;
   subtype OUT_EP0_ST_OUT_EP0_RD_ADDR_Field is ESP32S3_Registers.UInt7;

   --  OUT Endpoint 0 status
   type OUT_EP0_ST_Register is record
      --  Read-only. State of OUT Endpoint 0.
      OUT_EP0_STATE   : OUT_EP0_ST_OUT_EP0_STATE_Field;
      --  Read-only. Write data address of OUT endpoint 0. When
      --  USB_DEVICE_SERIAL_OUT_RECV_PKT_INT is detected, there are
      --  USB_DEVICE_OUT_EP0_WR_ADDR-2 bytes data in OUT EP0.
      OUT_EP0_WR_ADDR : OUT_EP0_ST_OUT_EP0_WR_ADDR_Field;
      --  Read-only. Read data address of OUT endpoint 0.
      OUT_EP0_RD_ADDR : OUT_EP0_ST_OUT_EP0_RD_ADDR_Field;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for OUT_EP0_ST_Register use
     record
       OUT_EP0_STATE at 0 range 0 .. 1;
       OUT_EP0_WR_ADDR at 0 range 2 .. 8;
       OUT_EP0_RD_ADDR at 0 range 9 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype OUT_EP1_ST_OUT_EP1_STATE_Field is ESP32S3_Registers.UInt2;
   subtype OUT_EP1_ST_OUT_EP1_WR_ADDR_Field is ESP32S3_Registers.UInt7;
   subtype OUT_EP1_ST_OUT_EP1_RD_ADDR_Field is ESP32S3_Registers.UInt7;
   subtype OUT_EP1_ST_OUT_EP1_REC_DATA_CNT_Field is ESP32S3_Registers.UInt7;

   --  OUT Endpoint 1 status
   type OUT_EP1_ST_Register is record
      --  Read-only. State of OUT Endpoint 1.
      OUT_EP1_STATE        : OUT_EP1_ST_OUT_EP1_STATE_Field;
      --  Read-only. Write data address of OUT endpoint 1. When
      --  USB_DEVICE_SERIAL_OUT_RECV_PKT_INT is detected, there are
      --  USB_DEVICE_OUT_EP1_WR_ADDR-2 bytes data in OUT EP1.
      OUT_EP1_WR_ADDR      : OUT_EP1_ST_OUT_EP1_WR_ADDR_Field;
      --  Read-only. Read data address of OUT endpoint 1.
      OUT_EP1_RD_ADDR      : OUT_EP1_ST_OUT_EP1_RD_ADDR_Field;
      --  Read-only. Data count in OUT endpoint 1 when one packet is received.
      OUT_EP1_REC_DATA_CNT : OUT_EP1_ST_OUT_EP1_REC_DATA_CNT_Field;
      --  unspecified
      Reserved_23_31       : ESP32S3_Registers.UInt9;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for OUT_EP1_ST_Register use
     record
       OUT_EP1_STATE at 0 range 0 .. 1;
       OUT_EP1_WR_ADDR at 0 range 2 .. 8;
       OUT_EP1_RD_ADDR at 0 range 9 .. 15;
       OUT_EP1_REC_DATA_CNT at 0 range 16 .. 22;
       Reserved_23_31 at 0 range 23 .. 31;
     end record;

   subtype OUT_EP2_ST_OUT_EP2_STATE_Field is ESP32S3_Registers.UInt2;
   subtype OUT_EP2_ST_OUT_EP2_WR_ADDR_Field is ESP32S3_Registers.UInt7;
   subtype OUT_EP2_ST_OUT_EP2_RD_ADDR_Field is ESP32S3_Registers.UInt7;

   --  OUT Endpoint 2 status
   type OUT_EP2_ST_Register is record
      --  Read-only. State of OUT Endpoint 2.
      OUT_EP2_STATE   : OUT_EP2_ST_OUT_EP2_STATE_Field;
      --  Read-only. Write data address of OUT endpoint 2. When
      --  USB_DEVICE_SERIAL_OUT_RECV_PKT_INT is detected, there are
      --  USB_DEVICE_OUT_EP2_WR_ADDR-2 bytes data in OUT EP2.
      OUT_EP2_WR_ADDR : OUT_EP2_ST_OUT_EP2_WR_ADDR_Field;
      --  Read-only. Read data address of OUT endpoint 2.
      OUT_EP2_RD_ADDR : OUT_EP2_ST_OUT_EP2_RD_ADDR_Field;
      --  unspecified
      Reserved_16_31  : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for OUT_EP2_ST_Register use
     record
       OUT_EP2_STATE at 0 range 0 .. 1;
       OUT_EP2_WR_ADDR at 0 range 2 .. 8;
       OUT_EP2_RD_ADDR at 0 range 9 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   --  MISC register
   type MISC_CONF_Register is record
      --  1'h1: Force clock on for register. 1'h0: Support clock only when
      --  application writes registers.
      CLK_EN        : Boolean := False;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for MISC_CONF_Register use
     record
       CLK_EN at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   --  Power control
   type MEM_CONF_Register is record
      --  1: power down usb memory.
      USB_MEM_PD     : Boolean := False;
      --  1: Force clock on for usb memory.
      USB_MEM_CLK_EN : Boolean := True;
      --  unspecified
      Reserved_2_31  : ESP32S3_Registers.UInt30 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for MEM_CONF_Register use
     record
       USB_MEM_PD at 0 range 0 .. 0;
       USB_MEM_CLK_EN at 0 range 1 .. 1;
       Reserved_2_31 at 0 range 2 .. 31;
     end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Full-speed USB Serial/JTAG Controller
   type USB_DEVICE_Peripheral is record
      --  Endpoint 1 FIFO register
      EP1        : aliased EP1_Register;
      --  Endpoint 1 configure and status register
      EP1_CONF   : aliased EP1_CONF_Register;
      --  Raw status interrupt
      INT_RAW    : aliased INT_RAW_Register;
      --  Masked interrupt
      INT_ST     : aliased INT_ST_Register;
      --  Interrupt enable bits
      INT_ENA    : aliased INT_ENA_Register;
      --  Interrupt clear bits
      INT_CLR    : aliased INT_CLR_Register;
      --  Configure 0 register
      CONF0      : aliased CONF0_Register;
      --  USB Internal PHY test register
      TEST       : aliased TEST_Register;
      --  USB-JTAG FIFO status
      JFIFO_ST   : aliased JFIFO_ST_Register;
      --  SOF frame number
      FRAM_NUM   : aliased FRAM_NUM_Register;
      --  IN Endpoint 0 status
      IN_EP0_ST  : aliased IN_EP0_ST_Register;
      --  IN Endpoint 1 status
      IN_EP1_ST  : aliased IN_EP1_ST_Register;
      --  IN Endpoint 2 status
      IN_EP2_ST  : aliased IN_EP2_ST_Register;
      --  IN Endpoint 3 status
      IN_EP3_ST  : aliased IN_EP3_ST_Register;
      --  OUT Endpoint 0 status
      OUT_EP0_ST : aliased OUT_EP0_ST_Register;
      --  OUT Endpoint 1 status
      OUT_EP1_ST : aliased OUT_EP1_ST_Register;
      --  OUT Endpoint 2 status
      OUT_EP2_ST : aliased OUT_EP2_ST_Register;
      --  MISC register
      MISC_CONF  : aliased MISC_CONF_Register;
      --  Power control
      MEM_CONF   : aliased MEM_CONF_Register;
      --  Version control register
      DATE       : aliased ESP32S3_Registers.UInt32;
   end record
   with Volatile;

   for USB_DEVICE_Peripheral use
     record
       EP1 at 16#0# range 0 .. 31;
       EP1_CONF at 16#4# range 0 .. 31;
       INT_RAW at 16#8# range 0 .. 31;
       INT_ST at 16#C# range 0 .. 31;
       INT_ENA at 16#10# range 0 .. 31;
       INT_CLR at 16#14# range 0 .. 31;
       CONF0 at 16#18# range 0 .. 31;
       TEST at 16#1C# range 0 .. 31;
       JFIFO_ST at 16#20# range 0 .. 31;
       FRAM_NUM at 16#24# range 0 .. 31;
       IN_EP0_ST at 16#28# range 0 .. 31;
       IN_EP1_ST at 16#2C# range 0 .. 31;
       IN_EP2_ST at 16#30# range 0 .. 31;
       IN_EP3_ST at 16#34# range 0 .. 31;
       OUT_EP0_ST at 16#38# range 0 .. 31;
       OUT_EP1_ST at 16#3C# range 0 .. 31;
       OUT_EP2_ST at 16#40# range 0 .. 31;
       MISC_CONF at 16#44# range 0 .. 31;
       MEM_CONF at 16#48# range 0 .. 31;
       DATE at 16#80# range 0 .. 31;
     end record;

   --  Full-speed USB Serial/JTAG Controller
   USB_DEVICE_Periph : aliased USB_DEVICE_Peripheral
   with Import, Address => USB_DEVICE_Base;

end ESP32S3_Registers.USB_DEVICE;
