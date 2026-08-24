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

package ESP32S3_Registers.UHCI is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  UHCI configuration register
   type CONF0_Register is record
      --  Write 1, then write 0 to this bit to reset decode state machine.
      TX_RST             : Boolean := False;
      --  Write 1, then write 0 to this bit to reset encode state machine.
      RX_RST             : Boolean := False;
      --  Set this bit to link up HCI and UART0.
      UART0_CE           : Boolean := False;
      --  Set this bit to link up HCI and UART1.
      UART1_CE           : Boolean := False;
      --  Set this bit to link up HCI and UART2.
      UART2_CE           : Boolean := False;
      --  Set this bit to separate the data frame using a special char.
      SEPER_EN           : Boolean := True;
      --  Set this bit to encode the data packet with a formatting header.
      HEAD_EN            : Boolean := True;
      --  Set this bit to enable UHCI to receive the 16 bit CRC.
      CRC_REC_EN         : Boolean := True;
      --  If this bit is set to 1, UHCI will end the payload receiving process
      --  when UART has been in idle state.
      UART_IDLE_EOF_EN   : Boolean := False;
      --  If this bit is set to 1, UHCI decoder receiving payload data is end
      --  when the receiving byte count has reached the specified value. The
      --  value is payload length indicated by UHCI packet header when
      --  UHCI_HEAD_EN is 1 or the value is configuration value when
      --  UHCI_HEAD_EN is 0. If this bit is set to 0, UHCI decoder receiving
      --  payload data is end when 0xc0 is received.
      LEN_EOF_EN         : Boolean := True;
      --  Set this bit to enable data integrity checking by appending a 16 bit
      --  CCITT-CRC to end of the payload.
      ENCODE_CRC_EN      : Boolean := True;
      --  1'b1: Force clock on for register. 1'b0: Support clock only when
      --  application writes registers.
      CLK_EN             : Boolean := False;
      --  If this bit is set to 1, UHCI will end payload receive process when
      --  NULL frame is received by UART.
      UART_RX_BRK_EOF_EN : Boolean := False;
      --  unspecified
      Reserved_13_31     : ESP32S3_Registers.UInt19 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CONF0_Register use record
      TX_RST             at 0 range 0 .. 0;
      RX_RST             at 0 range 1 .. 1;
      UART0_CE           at 0 range 2 .. 2;
      UART1_CE           at 0 range 3 .. 3;
      UART2_CE           at 0 range 4 .. 4;
      SEPER_EN           at 0 range 5 .. 5;
      HEAD_EN            at 0 range 6 .. 6;
      CRC_REC_EN         at 0 range 7 .. 7;
      UART_IDLE_EOF_EN   at 0 range 8 .. 8;
      LEN_EOF_EN         at 0 range 9 .. 9;
      ENCODE_CRC_EN      at 0 range 10 .. 10;
      CLK_EN             at 0 range 11 .. 11;
      UART_RX_BRK_EOF_EN at 0 range 12 .. 12;
      Reserved_13_31     at 0 range 13 .. 31;
   end record;

   --  Raw interrupt status
   type INT_RAW_Register is record
      --  This is the interrupt raw bit. Triggered when a separator char has
      --  been sent.
      RX_START_INT_RAW     : Boolean := False;
      --  This is the interrupt raw bit. Triggered when UHCI detects a
      --  separator char.
      TX_START_INT_RAW     : Boolean := False;
      --  This is the interrupt raw bit. Triggered when UHCI takes more time to
      --  receive data than configure value.
      RX_HUNG_INT_RAW      : Boolean := False;
      --  This is the interrupt raw bit. Triggered when UHCI takes more time to
      --  read data from RAM than the configured value.
      TX_HUNG_INT_RAW      : Boolean := False;
      --  This is the interrupt raw bit. Triggered when UHCI has sent out a
      --  short packet using single_send registers.
      SEND_S_REG_Q_INT_RAW : Boolean := False;
      --  This is the interrupt raw bit. Triggered when UHCI has sent out a
      --  short packet using always_send registers.
      SEND_A_REG_Q_INT_RAW : Boolean := False;
      --  This is the interrupt raw bit. Triggered when there are some errors
      --  in EOF in the transmit data.
      OUT_EOF_INT_RAW      : Boolean := False;
      --  This is the interrupt raw bit. Triggered when set
      --  UHCI_APP_CTRL0_IN_SET.
      APP_CTRL0_INT_RAW    : Boolean := False;
      --  This is the interrupt raw bit. Triggered when set
      --  UHCI_APP_CTRL1_IN_SET.
      APP_CTRL1_INT_RAW    : Boolean := False;
      --  unspecified
      Reserved_9_31        : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_Register use record
      RX_START_INT_RAW     at 0 range 0 .. 0;
      TX_START_INT_RAW     at 0 range 1 .. 1;
      RX_HUNG_INT_RAW      at 0 range 2 .. 2;
      TX_HUNG_INT_RAW      at 0 range 3 .. 3;
      SEND_S_REG_Q_INT_RAW at 0 range 4 .. 4;
      SEND_A_REG_Q_INT_RAW at 0 range 5 .. 5;
      OUT_EOF_INT_RAW      at 0 range 6 .. 6;
      APP_CTRL0_INT_RAW    at 0 range 7 .. 7;
      APP_CTRL1_INT_RAW    at 0 range 8 .. 8;
      Reserved_9_31        at 0 range 9 .. 31;
   end record;

   --  Masked interrupt status
   type INT_ST_Register is record
      --  Read-only. This is the masked interrupt bit for UHCI_RX_START_INT
      --  interrupt when UHCI_RX_START_INT_ENA is set to 1.
      RX_START_INT_ST        : Boolean;
      --  Read-only. This is the masked interrupt bit for UHCI_TX_START_INT
      --  interrupt when UHCI_TX_START_INT_ENA is set to 1.
      TX_START_INT_ST        : Boolean;
      --  Read-only. This is the masked interrupt bit for UHCI_RX_HUNG_INT
      --  interrupt when UHCI_RX_HUNG_INT_ENA is set to 1.
      RX_HUNG_INT_ST         : Boolean;
      --  Read-only. This is the masked interrupt bit for UHCI_TX_HUNG_INT
      --  interrupt when UHCI_TX_HUNG_INT_ENA is set to 1.
      TX_HUNG_INT_ST         : Boolean;
      --  Read-only. This is the masked interrupt bit for UHCI_SEND_S_REQ_Q_INT
      --  interrupt when UHCI_SEND_S_REQ_Q_INT_ENA is set to 1.
      SEND_S_REG_Q_INT_ST    : Boolean;
      --  Read-only. This is the masked interrupt bit for UHCI_SEND_A_REQ_Q_INT
      --  interrupt when UHCI_SEND_A_REQ_Q_INT_ENA is set to 1.
      SEND_A_REG_Q_INT_ST    : Boolean;
      --  Read-only. This is the masked interrupt bit for
      --  UHCI_OUTLINK_EOF_ERR_INT interrupt when UHCI_OUTLINK_EOF_ERR_INT_ENA
      --  is set to 1.
      OUTLINK_EOF_ERR_INT_ST : Boolean;
      --  Read-only. This is the masked interrupt bit for UHCI_APP_CTRL0_INT
      --  interrupt when UHCI_APP_CTRL0_INT_ENA is set to 1.
      APP_CTRL0_INT_ST       : Boolean;
      --  Read-only. This is the masked interrupt bit for UHCI_APP_CTRL1_INT
      --  interrupt when UHCI_APP_CTRL1_INT_ENA is set to 1.
      APP_CTRL1_INT_ST       : Boolean;
      --  unspecified
      Reserved_9_31          : ESP32S3_Registers.UInt23;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ST_Register use record
      RX_START_INT_ST        at 0 range 0 .. 0;
      TX_START_INT_ST        at 0 range 1 .. 1;
      RX_HUNG_INT_ST         at 0 range 2 .. 2;
      TX_HUNG_INT_ST         at 0 range 3 .. 3;
      SEND_S_REG_Q_INT_ST    at 0 range 4 .. 4;
      SEND_A_REG_Q_INT_ST    at 0 range 5 .. 5;
      OUTLINK_EOF_ERR_INT_ST at 0 range 6 .. 6;
      APP_CTRL0_INT_ST       at 0 range 7 .. 7;
      APP_CTRL1_INT_ST       at 0 range 8 .. 8;
      Reserved_9_31          at 0 range 9 .. 31;
   end record;

   --  Interrupt enable bits
   type INT_ENA_Register is record
      --  This is the interrupt enable bit for UHCI_RX_START_INT interrupt.
      RX_START_INT_ENA        : Boolean := False;
      --  This is the interrupt enable bit for UHCI_TX_START_INT interrupt.
      TX_START_INT_ENA        : Boolean := False;
      --  This is the interrupt enable bit for UHCI_RX_HUNG_INT interrupt.
      RX_HUNG_INT_ENA         : Boolean := False;
      --  This is the interrupt enable bit for UHCI_TX_HUNG_INT interrupt.
      TX_HUNG_INT_ENA         : Boolean := False;
      --  This is the interrupt enable bit for UHCI_SEND_S_REQ_Q_INT interrupt.
      SEND_S_REG_Q_INT_ENA    : Boolean := False;
      --  This is the interrupt enable bit for UHCI_SEND_A_REQ_Q_INT interrupt.
      SEND_A_REG_Q_INT_ENA    : Boolean := False;
      --  This is the interrupt enable bit for UHCI_OUTLINK_EOF_ERR_INT
      --  interrupt.
      OUTLINK_EOF_ERR_INT_ENA : Boolean := False;
      --  This is the interrupt enable bit for UHCI_APP_CTRL0_INT interrupt.
      APP_CTRL0_INT_ENA       : Boolean := False;
      --  This is the interrupt enable bit for UHCI_APP_CTRL1_INT interrupt.
      APP_CTRL1_INT_ENA       : Boolean := False;
      --  unspecified
      Reserved_9_31           : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_Register use record
      RX_START_INT_ENA        at 0 range 0 .. 0;
      TX_START_INT_ENA        at 0 range 1 .. 1;
      RX_HUNG_INT_ENA         at 0 range 2 .. 2;
      TX_HUNG_INT_ENA         at 0 range 3 .. 3;
      SEND_S_REG_Q_INT_ENA    at 0 range 4 .. 4;
      SEND_A_REG_Q_INT_ENA    at 0 range 5 .. 5;
      OUTLINK_EOF_ERR_INT_ENA at 0 range 6 .. 6;
      APP_CTRL0_INT_ENA       at 0 range 7 .. 7;
      APP_CTRL1_INT_ENA       at 0 range 8 .. 8;
      Reserved_9_31           at 0 range 9 .. 31;
   end record;

   --  Interrupt clear bits
   type INT_CLR_Register is record
      --  Write-only. Set this bit to clear UHCI_RX_START_INT interrupt.
      RX_START_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear UHCI_TX_START_INT interrupt.
      TX_START_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear UHCI_RX_HUNG_INT interrupt.
      RX_HUNG_INT_CLR         : Boolean := False;
      --  Write-only. Set this bit to clear UHCI_TX_HUNG_INT interrupt.
      TX_HUNG_INT_CLR         : Boolean := False;
      --  Write-only. Set this bit to clear UHCI_SEND_S_REQ_Q_INT interrupt.
      SEND_S_REG_Q_INT_CLR    : Boolean := False;
      --  Write-only. Set this bit to clear UHCI_SEND_A_REQ_Q_INT interrupt.
      SEND_A_REG_Q_INT_CLR    : Boolean := False;
      --  Write-only. Set this bit to clear UHCI_OUTLINK_EOF_ERR_INT interrupt.
      OUTLINK_EOF_ERR_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear UHCI_APP_CTRL0_INT interrupt.
      APP_CTRL0_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear UHCI_APP_CTRL1_INT interrupt.
      APP_CTRL1_INT_CLR       : Boolean := False;
      --  unspecified
      Reserved_9_31           : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_Register use record
      RX_START_INT_CLR        at 0 range 0 .. 0;
      TX_START_INT_CLR        at 0 range 1 .. 1;
      RX_HUNG_INT_CLR         at 0 range 2 .. 2;
      TX_HUNG_INT_CLR         at 0 range 3 .. 3;
      SEND_S_REG_Q_INT_CLR    at 0 range 4 .. 4;
      SEND_A_REG_Q_INT_CLR    at 0 range 5 .. 5;
      OUTLINK_EOF_ERR_INT_CLR at 0 range 6 .. 6;
      APP_CTRL0_INT_CLR       at 0 range 7 .. 7;
      APP_CTRL1_INT_CLR       at 0 range 8 .. 8;
      Reserved_9_31           at 0 range 9 .. 31;
   end record;

   --  Software interrupt trigger source
   type APP_INT_SET_Register is record
      --  Write-only. This bit is software interrupt trigger source of
      --  UHCI_APP_CTRL0_INT.
      APP_CTRL0_INT_SET : Boolean := False;
      --  Write-only. This bit is software interrupt trigger source of
      --  UHCI_APP_CTRL1_INT.
      APP_CTRL1_INT_SET : Boolean := False;
      --  unspecified
      Reserved_2_31     : ESP32S3_Registers.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for APP_INT_SET_Register use record
      APP_CTRL0_INT_SET at 0 range 0 .. 0;
      APP_CTRL1_INT_SET at 0 range 1 .. 1;
      Reserved_2_31     at 0 range 2 .. 31;
   end record;

   --  UHCI configuration register
   type CONF1_Register is record
      --  This is the enable bit to check header checksum when UHCI receives a
      --  data packet.
      CHECK_SUM_EN    : Boolean := True;
      --  This is the enable bit to check sequence number when UHCI receives a
      --  data packet.
      CHECK_SEQ_EN    : Boolean := True;
      --  Set this bit to support CRC calculation. Data Integrity Check Present
      --  bit in UHCI packet frame should be 1.
      CRC_DISABLE     : Boolean := False;
      --  Set this bit to save the packet header when HCI receives a data
      --  packet.
      SAVE_HEAD       : Boolean := False;
      --  Set this bit to encode the data packet with a checksum.
      TX_CHECK_SUM_RE : Boolean := True;
      --  Set this bit to encode the data packet with an acknowledgment when a
      --  reliable packet is to be transmit.
      TX_ACK_NUM_RE   : Boolean := True;
      --  unspecified
      Reserved_6_6    : ESP32S3_Registers.Bit := 16#0#;
      --  The uhci-encoder will jump to ST_SW_WAIT status if this register is
      --  set to 1.
      WAIT_SW_START   : Boolean := False;
      --  If current UHCI_ENCODE_STATE is ST_SW_WAIT, the UHCI will start to
      --  send data packet out when this bit is set to 1.
      SW_START        : Boolean := False;
      --  unspecified
      Reserved_9_31   : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CONF1_Register use record
      CHECK_SUM_EN    at 0 range 0 .. 0;
      CHECK_SEQ_EN    at 0 range 1 .. 1;
      CRC_DISABLE     at 0 range 2 .. 2;
      SAVE_HEAD       at 0 range 3 .. 3;
      TX_CHECK_SUM_RE at 0 range 4 .. 4;
      TX_ACK_NUM_RE   at 0 range 5 .. 5;
      Reserved_6_6    at 0 range 6 .. 6;
      WAIT_SW_START   at 0 range 7 .. 7;
      SW_START        at 0 range 8 .. 8;
      Reserved_9_31   at 0 range 9 .. 31;
   end record;

   subtype STATE0_RX_ERR_CAUSE_Field is ESP32S3_Registers.UInt3;
   subtype STATE0_DECODE_STATE_Field is ESP32S3_Registers.UInt3;

   --  UHCI receive status
   type STATE0_Register is record
      --  Read-only. This register indicates the error type when DMA has
      --  received a packet with error. 3'b001: Checksum error in HCI packet.
      --  3'b010: Sequence number error in HCI packet. 3'b011: CRC bit error in
      --  HCI packet. 3'b100: 0xc0 is found but received HCI packet is not end.
      --  3'b101: 0xc0 is not found when receiving HCI packet is end. 3'b110:
      --  CRC check error.
      RX_ERR_CAUSE  : STATE0_RX_ERR_CAUSE_Field;
      --  Read-only. UHCI decoder status.
      DECODE_STATE  : STATE0_DECODE_STATE_Field;
      --  unspecified
      Reserved_6_31 : ESP32S3_Registers.UInt26;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for STATE0_Register use record
      RX_ERR_CAUSE  at 0 range 0 .. 2;
      DECODE_STATE  at 0 range 3 .. 5;
      Reserved_6_31 at 0 range 6 .. 31;
   end record;

   subtype STATE1_ENCODE_STATE_Field is ESP32S3_Registers.UInt3;

   --  UHCI transmit status
   type STATE1_Register is record
      --  Read-only. UHCI encoder status.
      ENCODE_STATE  : STATE1_ENCODE_STATE_Field;
      --  unspecified
      Reserved_3_31 : ESP32S3_Registers.UInt29;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for STATE1_Register use record
      ENCODE_STATE  at 0 range 0 .. 2;
      Reserved_3_31 at 0 range 3 .. 31;
   end record;

   --  Escape character configuration
   type ESCAPE_CONF_Register is record
      --  Set this bit to enable decoding char 0xc0 when DMA receives data.
      TX_C0_ESC_EN  : Boolean := True;
      --  Set this bit to enable decoding char 0xdb when DMA receives data.
      TX_DB_ESC_EN  : Boolean := True;
      --  Set this bit to enable decoding flow control char 0x11 when DMA
      --  receives data.
      TX_11_ESC_EN  : Boolean := False;
      --  Set this bit to enable decoding flow control char 0x13 when DMA
      --  receives data.
      TX_13_ESC_EN  : Boolean := False;
      --  Set this bit to enable replacing 0xc0 by special char when DMA sends
      --  data.
      RX_C0_ESC_EN  : Boolean := True;
      --  Set this bit to enable replacing 0xdb by special char when DMA sends
      --  data.
      RX_DB_ESC_EN  : Boolean := True;
      --  Set this bit to enable replacing flow control char 0x11 by special
      --  char when DMA sends data.
      RX_11_ESC_EN  : Boolean := False;
      --  Set this bit to enable replacing flow control char 0x13 by special
      --  char when DMA sends data.
      RX_13_ESC_EN  : Boolean := False;
      --  unspecified
      Reserved_8_31 : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ESCAPE_CONF_Register use record
      TX_C0_ESC_EN  at 0 range 0 .. 0;
      TX_DB_ESC_EN  at 0 range 1 .. 1;
      TX_11_ESC_EN  at 0 range 2 .. 2;
      TX_13_ESC_EN  at 0 range 3 .. 3;
      RX_C0_ESC_EN  at 0 range 4 .. 4;
      RX_DB_ESC_EN  at 0 range 5 .. 5;
      RX_11_ESC_EN  at 0 range 6 .. 6;
      RX_13_ESC_EN  at 0 range 7 .. 7;
      Reserved_8_31 at 0 range 8 .. 31;
   end record;

   subtype HUNG_CONF_TXFIFO_TIMEOUT_Field is ESP32S3_Registers.Byte;
   subtype HUNG_CONF_TXFIFO_TIMEOUT_SHIFT_Field is ESP32S3_Registers.UInt3;
   subtype HUNG_CONF_RXFIFO_TIMEOUT_Field is ESP32S3_Registers.Byte;
   subtype HUNG_CONF_RXFIFO_TIMEOUT_SHIFT_Field is ESP32S3_Registers.UInt3;

   --  Timeout configuration
   type HUNG_CONF_Register is record
      --  This register stores the timeout value. It will produce the
      --  UHCI_TX_HUNG_INT interrupt when DMA takes more time to receive data.
      TXFIFO_TIMEOUT       : HUNG_CONF_TXFIFO_TIMEOUT_Field := 16#10#;
      --  This register is used to configure the tick count maximum value.
      TXFIFO_TIMEOUT_SHIFT : HUNG_CONF_TXFIFO_TIMEOUT_SHIFT_Field := 16#0#;
      --  This is the enable bit for Tx-FIFO receive-data timeout.
      TXFIFO_TIMEOUT_ENA   : Boolean := True;
      --  This register stores the timeout value. It will produce the
      --  UHCI_RX_HUNG_INT interrupt when DMA takes more time to read data from
      --  RAM.
      RXFIFO_TIMEOUT       : HUNG_CONF_RXFIFO_TIMEOUT_Field := 16#10#;
      --  This register is used to configure the tick count maximum value.
      RXFIFO_TIMEOUT_SHIFT : HUNG_CONF_RXFIFO_TIMEOUT_SHIFT_Field := 16#0#;
      --  This is the enable bit for DMA send-data timeout.
      RXFIFO_TIMEOUT_ENA   : Boolean := True;
      --  unspecified
      Reserved_24_31       : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HUNG_CONF_Register use record
      TXFIFO_TIMEOUT       at 0 range 0 .. 7;
      TXFIFO_TIMEOUT_SHIFT at 0 range 8 .. 10;
      TXFIFO_TIMEOUT_ENA   at 0 range 11 .. 11;
      RXFIFO_TIMEOUT       at 0 range 12 .. 19;
      RXFIFO_TIMEOUT_SHIFT at 0 range 20 .. 22;
      RXFIFO_TIMEOUT_ENA   at 0 range 23 .. 23;
      Reserved_24_31       at 0 range 24 .. 31;
   end record;

   subtype ACK_NUM_ACK_NUM_Field is ESP32S3_Registers.UInt3;

   --  UHCI ACK number configuration
   type ACK_NUM_Register is record
      --  This ACK number used in software flow control.
      ACK_NUM       : ACK_NUM_ACK_NUM_Field := 16#0#;
      --  Write-only. Set this bit to 1, the value configured by UHCI_ACK_NUM
      --  would be loaded.
      LOAD          : Boolean := True;
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ACK_NUM_Register use record
      ACK_NUM       at 0 range 0 .. 2;
      LOAD          at 0 range 3 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   subtype QUICK_SENT_SINGLE_SEND_NUM_Field is ESP32S3_Registers.UInt3;
   subtype QUICK_SENT_ALWAYS_SEND_NUM_Field is ESP32S3_Registers.UInt3;

   --  UHCI quick send configuration register
   type QUICK_SENT_Register is record
      --  This register is used to specify the single_send register.
      SINGLE_SEND_NUM : QUICK_SENT_SINGLE_SEND_NUM_Field := 16#0#;
      --  Set this bit to enable single_send mode to send short packet.
      SINGLE_SEND_EN  : Boolean := False;
      --  This register is used to specify the always_send register.
      ALWAYS_SEND_NUM : QUICK_SENT_ALWAYS_SEND_NUM_Field := 16#0#;
      --  Set this bit to enable always_send mode to send short packet.
      ALWAYS_SEND_EN  : Boolean := False;
      --  unspecified
      Reserved_8_31   : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for QUICK_SENT_Register use record
      SINGLE_SEND_NUM at 0 range 0 .. 2;
      SINGLE_SEND_EN  at 0 range 3 .. 3;
      ALWAYS_SEND_NUM at 0 range 4 .. 6;
      ALWAYS_SEND_EN  at 0 range 7 .. 7;
      Reserved_8_31   at 0 range 8 .. 31;
   end record;

   subtype ESC_CONF0_SEPER_CHAR_Field is ESP32S3_Registers.Byte;
   --  ESC_CONF0_SEPER_ESC_CHAR array element
   subtype ESC_CONF0_SEPER_ESC_CHAR_Element is ESP32S3_Registers.Byte;

   --  ESC_CONF0_SEPER_ESC_CHAR array
   type ESC_CONF0_SEPER_ESC_CHAR_Field_Array is array (0 .. 1)
     of ESC_CONF0_SEPER_ESC_CHAR_Element
     with Component_Size => 8, Size => 16;

   --  Type definition for ESC_CONF0_SEPER_ESC_CHAR
   type ESC_CONF0_SEPER_ESC_CHAR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  SEPER_ESC_CHAR as a value
            Val : ESP32S3_Registers.UInt16;
         when True =>
            --  SEPER_ESC_CHAR as an array
            Arr : ESC_CONF0_SEPER_ESC_CHAR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 16;

   for ESC_CONF0_SEPER_ESC_CHAR_Field use record
      Val at 0 range 0 .. 15;
      Arr at 0 range 0 .. 15;
   end record;

   --  Escape sequence configuration register 0
   type ESC_CONF0_Register is record
      --  This register is used to define the separate char that need to be
      --  encoded, default is 0xc0.
      SEPER_CHAR     : ESC_CONF0_SEPER_CHAR_Field := 16#C0#;
      --  This register is used to define the first char of slip escape
      --  sequence when encoding the separate char, default is 0xdb.
      SEPER_ESC_CHAR : ESC_CONF0_SEPER_ESC_CHAR_Field :=
                        (As_Array => False, Val => 16#DB#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ESC_CONF0_Register use record
      SEPER_CHAR     at 0 range 0 .. 7;
      SEPER_ESC_CHAR at 0 range 8 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype ESC_CONF1_ESC_SEQ0_Field is ESP32S3_Registers.Byte;
   --  ESC_CONF1_ESC_SEQ0_CHAR array element
   subtype ESC_CONF1_ESC_SEQ0_CHAR_Element is ESP32S3_Registers.Byte;

   --  ESC_CONF1_ESC_SEQ0_CHAR array
   type ESC_CONF1_ESC_SEQ0_CHAR_Field_Array is array (0 .. 1)
     of ESC_CONF1_ESC_SEQ0_CHAR_Element
     with Component_Size => 8, Size => 16;

   --  Type definition for ESC_CONF1_ESC_SEQ0_CHAR
   type ESC_CONF1_ESC_SEQ0_CHAR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ESC_SEQ0_CHAR as a value
            Val : ESP32S3_Registers.UInt16;
         when True =>
            --  ESC_SEQ0_CHAR as an array
            Arr : ESC_CONF1_ESC_SEQ0_CHAR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 16;

   for ESC_CONF1_ESC_SEQ0_CHAR_Field use record
      Val at 0 range 0 .. 15;
      Arr at 0 range 0 .. 15;
   end record;

   --  Escape sequence configuration register 1
   type ESC_CONF1_Register is record
      --  This register is used to define a char that need to be encoded,
      --  default is 0xdb that used as the first char of slip escape sequence.
      ESC_SEQ0       : ESC_CONF1_ESC_SEQ0_Field := 16#DB#;
      --  This register is used to define the first char of slip escape
      --  sequence when encoding the UHCI_ESC_SEQ0, default is 0xdb.
      ESC_SEQ0_CHAR  : ESC_CONF1_ESC_SEQ0_CHAR_Field :=
                        (As_Array => False, Val => 16#DB#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ESC_CONF1_Register use record
      ESC_SEQ0       at 0 range 0 .. 7;
      ESC_SEQ0_CHAR  at 0 range 8 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype ESC_CONF2_ESC_SEQ1_Field is ESP32S3_Registers.Byte;
   --  ESC_CONF2_ESC_SEQ1_CHAR array element
   subtype ESC_CONF2_ESC_SEQ1_CHAR_Element is ESP32S3_Registers.Byte;

   --  ESC_CONF2_ESC_SEQ1_CHAR array
   type ESC_CONF2_ESC_SEQ1_CHAR_Field_Array is array (0 .. 1)
     of ESC_CONF2_ESC_SEQ1_CHAR_Element
     with Component_Size => 8, Size => 16;

   --  Type definition for ESC_CONF2_ESC_SEQ1_CHAR
   type ESC_CONF2_ESC_SEQ1_CHAR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ESC_SEQ1_CHAR as a value
            Val : ESP32S3_Registers.UInt16;
         when True =>
            --  ESC_SEQ1_CHAR as an array
            Arr : ESC_CONF2_ESC_SEQ1_CHAR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 16;

   for ESC_CONF2_ESC_SEQ1_CHAR_Field use record
      Val at 0 range 0 .. 15;
      Arr at 0 range 0 .. 15;
   end record;

   --  Escape sequence configuration register 2
   type ESC_CONF2_Register is record
      --  This register is used to define a char that need to be encoded,
      --  default is 0x11 that used as flow control char.
      ESC_SEQ1       : ESC_CONF2_ESC_SEQ1_Field := 16#11#;
      --  This register is used to define the first char of slip escape
      --  sequence when encoding the UHCI_ESC_SEQ1, default is 0xdb.
      ESC_SEQ1_CHAR  : ESC_CONF2_ESC_SEQ1_CHAR_Field :=
                        (As_Array => False, Val => 16#DB#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ESC_CONF2_Register use record
      ESC_SEQ1       at 0 range 0 .. 7;
      ESC_SEQ1_CHAR  at 0 range 8 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype ESC_CONF3_ESC_SEQ2_Field is ESP32S3_Registers.Byte;
   --  ESC_CONF3_ESC_SEQ2_CHAR array element
   subtype ESC_CONF3_ESC_SEQ2_CHAR_Element is ESP32S3_Registers.Byte;

   --  ESC_CONF3_ESC_SEQ2_CHAR array
   type ESC_CONF3_ESC_SEQ2_CHAR_Field_Array is array (0 .. 1)
     of ESC_CONF3_ESC_SEQ2_CHAR_Element
     with Component_Size => 8, Size => 16;

   --  Type definition for ESC_CONF3_ESC_SEQ2_CHAR
   type ESC_CONF3_ESC_SEQ2_CHAR_Field
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  ESC_SEQ2_CHAR as a value
            Val : ESP32S3_Registers.UInt16;
         when True =>
            --  ESC_SEQ2_CHAR as an array
            Arr : ESC_CONF3_ESC_SEQ2_CHAR_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 16;

   for ESC_CONF3_ESC_SEQ2_CHAR_Field use record
      Val at 0 range 0 .. 15;
      Arr at 0 range 0 .. 15;
   end record;

   --  Escape sequence configuration register 3
   type ESC_CONF3_Register is record
      --  This register is used to define a char that need to be decoded,
      --  default is 0x13 that used as flow control char.
      ESC_SEQ2       : ESC_CONF3_ESC_SEQ2_Field := 16#13#;
      --  This register is used to define the first char of slip escape
      --  sequence when encoding the UHCI_ESC_SEQ2, default is 0xdb.
      ESC_SEQ2_CHAR  : ESC_CONF3_ESC_SEQ2_CHAR_Field :=
                        (As_Array => False, Val => 16#DB#);
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ESC_CONF3_Register use record
      ESC_SEQ2       at 0 range 0 .. 7;
      ESC_SEQ2_CHAR  at 0 range 8 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype PKT_THRES_PKT_THRS_Field is ESP32S3_Registers.UInt13;

   --  Configure register for packet length
   type PKT_THRES_Register is record
      --  This register is used to configure the maximum value of the packet
      --  length when UHCI_HEAD_EN is 0.
      PKT_THRS       : PKT_THRES_PKT_THRS_Field := 16#80#;
      --  unspecified
      Reserved_13_31 : ESP32S3_Registers.UInt19 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for PKT_THRES_Register use record
      PKT_THRS       at 0 range 0 .. 12;
      Reserved_13_31 at 0 range 13 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Universal Host Controller Interface 0
   type UHCI_Peripheral is record
      --  UHCI configuration register
      CONF0        : aliased CONF0_Register;
      --  Raw interrupt status
      INT_RAW      : aliased INT_RAW_Register;
      --  Masked interrupt status
      INT_ST       : aliased INT_ST_Register;
      --  Interrupt enable bits
      INT_ENA      : aliased INT_ENA_Register;
      --  Interrupt clear bits
      INT_CLR      : aliased INT_CLR_Register;
      --  Software interrupt trigger source
      APP_INT_SET  : aliased APP_INT_SET_Register;
      --  UHCI configuration register
      CONF1        : aliased CONF1_Register;
      --  UHCI receive status
      STATE0       : aliased STATE0_Register;
      --  UHCI transmit status
      STATE1       : aliased STATE1_Register;
      --  Escape character configuration
      ESCAPE_CONF  : aliased ESCAPE_CONF_Register;
      --  Timeout configuration
      HUNG_CONF    : aliased HUNG_CONF_Register;
      --  UHCI ACK number configuration
      ACK_NUM      : aliased ACK_NUM_Register;
      --  UHCI packet header register
      RX_HEAD      : aliased ESP32S3_Registers.UInt32;
      --  UHCI quick send configuration register
      QUICK_SENT   : aliased QUICK_SENT_Register;
      --  Q0_WORD0 quick_sent register
      REG_Q0_WORD0 : aliased ESP32S3_Registers.UInt32;
      --  Q0_WORD1 quick_sent register
      REG_Q0_WORD1 : aliased ESP32S3_Registers.UInt32;
      --  Q1_WORD0 quick_sent register
      REG_Q1_WORD0 : aliased ESP32S3_Registers.UInt32;
      --  Q1_WORD1 quick_sent register
      REG_Q1_WORD1 : aliased ESP32S3_Registers.UInt32;
      --  Q2_WORD0 quick_sent register
      REG_Q2_WORD0 : aliased ESP32S3_Registers.UInt32;
      --  Q2_WORD1 quick_sent register
      REG_Q2_WORD1 : aliased ESP32S3_Registers.UInt32;
      --  Q3_WORD0 quick_sent register
      REG_Q3_WORD0 : aliased ESP32S3_Registers.UInt32;
      --  Q3_WORD1 quick_sent register
      REG_Q3_WORD1 : aliased ESP32S3_Registers.UInt32;
      --  Q4_WORD0 quick_sent register
      REG_Q4_WORD0 : aliased ESP32S3_Registers.UInt32;
      --  Q4_WORD1 quick_sent register
      REG_Q4_WORD1 : aliased ESP32S3_Registers.UInt32;
      --  Q5_WORD0 quick_sent register
      REG_Q5_WORD0 : aliased ESP32S3_Registers.UInt32;
      --  Q5_WORD1 quick_sent register
      REG_Q5_WORD1 : aliased ESP32S3_Registers.UInt32;
      --  Q6_WORD0 quick_sent register
      REG_Q6_WORD0 : aliased ESP32S3_Registers.UInt32;
      --  Q6_WORD1 quick_sent register
      REG_Q6_WORD1 : aliased ESP32S3_Registers.UInt32;
      --  Escape sequence configuration register 0
      ESC_CONF0    : aliased ESC_CONF0_Register;
      --  Escape sequence configuration register 1
      ESC_CONF1    : aliased ESC_CONF1_Register;
      --  Escape sequence configuration register 2
      ESC_CONF2    : aliased ESC_CONF2_Register;
      --  Escape sequence configuration register 3
      ESC_CONF3    : aliased ESC_CONF3_Register;
      --  Configure register for packet length
      PKT_THRES    : aliased PKT_THRES_Register;
      --  UHCI version control register
      DATE         : aliased ESP32S3_Registers.UInt32;
   end record
     with Volatile;

   for UHCI_Peripheral use record
      CONF0        at 16#0# range 0 .. 31;
      INT_RAW      at 16#4# range 0 .. 31;
      INT_ST       at 16#8# range 0 .. 31;
      INT_ENA      at 16#C# range 0 .. 31;
      INT_CLR      at 16#10# range 0 .. 31;
      APP_INT_SET  at 16#14# range 0 .. 31;
      CONF1        at 16#18# range 0 .. 31;
      STATE0       at 16#1C# range 0 .. 31;
      STATE1       at 16#20# range 0 .. 31;
      ESCAPE_CONF  at 16#24# range 0 .. 31;
      HUNG_CONF    at 16#28# range 0 .. 31;
      ACK_NUM      at 16#2C# range 0 .. 31;
      RX_HEAD      at 16#30# range 0 .. 31;
      QUICK_SENT   at 16#34# range 0 .. 31;
      REG_Q0_WORD0 at 16#38# range 0 .. 31;
      REG_Q0_WORD1 at 16#3C# range 0 .. 31;
      REG_Q1_WORD0 at 16#40# range 0 .. 31;
      REG_Q1_WORD1 at 16#44# range 0 .. 31;
      REG_Q2_WORD0 at 16#48# range 0 .. 31;
      REG_Q2_WORD1 at 16#4C# range 0 .. 31;
      REG_Q3_WORD0 at 16#50# range 0 .. 31;
      REG_Q3_WORD1 at 16#54# range 0 .. 31;
      REG_Q4_WORD0 at 16#58# range 0 .. 31;
      REG_Q4_WORD1 at 16#5C# range 0 .. 31;
      REG_Q5_WORD0 at 16#60# range 0 .. 31;
      REG_Q5_WORD1 at 16#64# range 0 .. 31;
      REG_Q6_WORD0 at 16#68# range 0 .. 31;
      REG_Q6_WORD1 at 16#6C# range 0 .. 31;
      ESC_CONF0    at 16#70# range 0 .. 31;
      ESC_CONF1    at 16#74# range 0 .. 31;
      ESC_CONF2    at 16#78# range 0 .. 31;
      ESC_CONF3    at 16#7C# range 0 .. 31;
      PKT_THRES    at 16#80# range 0 .. 31;
      DATE         at 16#84# range 0 .. 31;
   end record;

   --  Universal Host Controller Interface 0
   UHCI0_Periph : aliased UHCI_Peripheral
     with Import, Address => UHCI0_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

   --  Universal Host Controller Interface 1
   UHCI1_Periph : aliased UHCI_Peripheral
     with Import, Address => UHCI1_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.UHCI;
