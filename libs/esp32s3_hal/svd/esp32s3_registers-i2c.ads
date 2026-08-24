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

package ESP32S3_Registers.I2C is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype SCL_LOW_PERIOD_SCL_LOW_PERIOD_Field is ESP32S3_Registers.UInt9;

   --  Configures the low level width of the SCL Clock
   type SCL_LOW_PERIOD_Register is record
      --  This register is used to configure for how long SCL remains low in
      --  master mode, in I2C module clock cycles.
      SCL_LOW_PERIOD : SCL_LOW_PERIOD_SCL_LOW_PERIOD_Field := 16#0#;
      --  unspecified
      Reserved_9_31  : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_LOW_PERIOD_Register use record
      SCL_LOW_PERIOD at 0 range 0 .. 8;
      Reserved_9_31  at 0 range 9 .. 31;
   end record;

   --  Transmission setting
   type CTR_Register is record
      --  0: direct output; 1: open drain output.
      SDA_FORCE_OUT          : Boolean := True;
      --  0: direct output; 1: open drain output.
      SCL_FORCE_OUT          : Boolean := True;
      --  This register is used to select the sample mode. 1: sample SDA data
      --  on the SCL low level. 0: sample SDA data on the SCL high level.
      SAMPLE_SCL_LEVEL       : Boolean := False;
      --  This register is used to configure the ACK value that need to sent by
      --  master when the rx_fifo_cnt has reached the threshold.
      RX_FULL_ACK_LEVEL      : Boolean := True;
      --  Set this bit to configure the module as an I2C Master. Clear this bit
      --  to configure the module as an I2C Slave.
      MS_MODE                : Boolean := False;
      --  Write-only. Set this bit to start sending the data in txfifo.
      TRANS_START            : Boolean := False;
      --  This bit is used to control the sending mode for data needing to be
      --  sent. 1: send data from the least significant bit; 0: send data from
      --  the most significant bit.
      TX_LSB_FIRST           : Boolean := False;
      --  This bit is used to control the storage mode for received data. 1:
      --  receive data from the least significant bit; 0: receive data from the
      --  most significant bit.
      RX_LSB_FIRST           : Boolean := False;
      --  Reserved
      CLK_EN                 : Boolean := False;
      --  This is the enable bit for arbitration_lost.
      ARBITRATION_EN         : Boolean := True;
      --  Write-only. This register is used to reset the scl FMS.
      FSM_RST                : Boolean := False;
      --  Write-only. synchronization bit
      CONF_UPGATE            : Boolean := False;
      --  This is the enable bit for slave to send data automatically
      SLV_TX_AUTO_START_EN   : Boolean := False;
      --  This is the enable bit to check if the r/w bit of 10bit addressing
      --  consists with I2C protocol
      ADDR_10BIT_RW_CHECK_EN : Boolean := False;
      --  This is the enable bit to support the 7bit general call function.
      ADDR_BROADCASTING_EN   : Boolean := False;
      --  unspecified
      Reserved_15_31         : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTR_Register use record
      SDA_FORCE_OUT          at 0 range 0 .. 0;
      SCL_FORCE_OUT          at 0 range 1 .. 1;
      SAMPLE_SCL_LEVEL       at 0 range 2 .. 2;
      RX_FULL_ACK_LEVEL      at 0 range 3 .. 3;
      MS_MODE                at 0 range 4 .. 4;
      TRANS_START            at 0 range 5 .. 5;
      TX_LSB_FIRST           at 0 range 6 .. 6;
      RX_LSB_FIRST           at 0 range 7 .. 7;
      CLK_EN                 at 0 range 8 .. 8;
      ARBITRATION_EN         at 0 range 9 .. 9;
      FSM_RST                at 0 range 10 .. 10;
      CONF_UPGATE            at 0 range 11 .. 11;
      SLV_TX_AUTO_START_EN   at 0 range 12 .. 12;
      ADDR_10BIT_RW_CHECK_EN at 0 range 13 .. 13;
      ADDR_BROADCASTING_EN   at 0 range 14 .. 14;
      Reserved_15_31         at 0 range 15 .. 31;
   end record;

   subtype SR_RXFIFO_CNT_Field is ESP32S3_Registers.UInt6;
   subtype SR_STRETCH_CAUSE_Field is ESP32S3_Registers.UInt2;
   subtype SR_TXFIFO_CNT_Field is ESP32S3_Registers.UInt6;
   subtype SR_SCL_MAIN_STATE_LAST_Field is ESP32S3_Registers.UInt3;
   subtype SR_SCL_STATE_LAST_Field is ESP32S3_Registers.UInt3;

   --  Describe I2C work status.
   type SR_Register is record
      --  Read-only. The received ACK value in master mode or slave mode. 0:
      --  ACK, 1: NACK.
      RESP_REC            : Boolean;
      --  Read-only. When in slave mode, 1: master reads from slave; 0: master
      --  writes to slave.
      SLAVE_RW            : Boolean;
      --  unspecified
      Reserved_2_2        : ESP32S3_Registers.Bit;
      --  Read-only. When the I2C controller loses control of SCL line, this
      --  register changes to 1.
      ARB_LOST            : Boolean;
      --  Read-only. 1: the I2C bus is busy transferring data; 0: the I2C bus
      --  is in idle state.
      BUS_BUSY            : Boolean;
      --  Read-only. When configured as an I2C Slave, and the address sent by
      --  the master is equal to the address of the slave, then this bit will
      --  be of high level.
      SLAVE_ADDRESSED     : Boolean;
      --  unspecified
      Reserved_6_7        : ESP32S3_Registers.UInt2;
      --  Read-only. This field represents the amount of data needed to be
      --  sent.
      RXFIFO_CNT          : SR_RXFIFO_CNT_Field;
      --  Read-only. The cause of stretching SCL low in slave mode. 0:
      --  stretching SCL low at the beginning of I2C read data state. 1:
      --  stretching SCL low when I2C Tx FIFO is empty in slave mode. 2:
      --  stretching SCL low when I2C Rx FIFO is full in slave mode.
      STRETCH_CAUSE       : SR_STRETCH_CAUSE_Field;
      --  unspecified
      Reserved_16_17      : ESP32S3_Registers.UInt2;
      --  Read-only. This field stores the amount of received data in RAM.
      TXFIFO_CNT          : SR_TXFIFO_CNT_Field;
      --  Read-only. This field indicates the states of the I2C module state
      --  machine. 0: Idle; 1: Address shift; 2: ACK address; 3: Rx data; 4: Tx
      --  data; 5: Send ACK; 6: Wait ACK
      SCL_MAIN_STATE_LAST : SR_SCL_MAIN_STATE_LAST_Field;
      --  unspecified
      Reserved_27_27      : ESP32S3_Registers.Bit;
      --  Read-only. This field indicates the states of the state machine used
      --  to produce SCL. 0: Idle; 1: Start; 2: Negative edge; 3: Low; 4:
      --  Positive edge; 5: High; 6: Stop
      SCL_STATE_LAST      : SR_SCL_STATE_LAST_Field;
      --  unspecified
      Reserved_31_31      : ESP32S3_Registers.Bit;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SR_Register use record
      RESP_REC            at 0 range 0 .. 0;
      SLAVE_RW            at 0 range 1 .. 1;
      Reserved_2_2        at 0 range 2 .. 2;
      ARB_LOST            at 0 range 3 .. 3;
      BUS_BUSY            at 0 range 4 .. 4;
      SLAVE_ADDRESSED     at 0 range 5 .. 5;
      Reserved_6_7        at 0 range 6 .. 7;
      RXFIFO_CNT          at 0 range 8 .. 13;
      STRETCH_CAUSE       at 0 range 14 .. 15;
      Reserved_16_17      at 0 range 16 .. 17;
      TXFIFO_CNT          at 0 range 18 .. 23;
      SCL_MAIN_STATE_LAST at 0 range 24 .. 26;
      Reserved_27_27      at 0 range 27 .. 27;
      SCL_STATE_LAST      at 0 range 28 .. 30;
      Reserved_31_31      at 0 range 31 .. 31;
   end record;

   subtype TO_TIME_OUT_VALUE_Field is ESP32S3_Registers.UInt5;

   --  Setting time out control for receiving data.
   type TO_Register is record
      --  This register is used to configure the timeout for receiving a data
      --  bit in APB clock cycles.
      TIME_OUT_VALUE : TO_TIME_OUT_VALUE_Field := 16#10#;
      --  This is the enable bit for time out control.
      TIME_OUT_EN    : Boolean := False;
      --  unspecified
      Reserved_6_31  : ESP32S3_Registers.UInt26 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TO_Register use record
      TIME_OUT_VALUE at 0 range 0 .. 4;
      TIME_OUT_EN    at 0 range 5 .. 5;
      Reserved_6_31  at 0 range 6 .. 31;
   end record;

   subtype SLAVE_ADDR_SLAVE_ADDR_Field is ESP32S3_Registers.UInt15;

   --  Local slave address setting
   type SLAVE_ADDR_Register is record
      --  When configured as an I2C Slave, this field is used to configure the
      --  slave address.
      SLAVE_ADDR     : SLAVE_ADDR_SLAVE_ADDR_Field := 16#0#;
      --  unspecified
      Reserved_15_30 : ESP32S3_Registers.UInt16 := 16#0#;
      --  This field is used to enable the slave 10-bit addressing mode in
      --  master mode.
      ADDR_10BIT_EN  : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SLAVE_ADDR_Register use record
      SLAVE_ADDR     at 0 range 0 .. 14;
      Reserved_15_30 at 0 range 15 .. 30;
      ADDR_10BIT_EN  at 0 range 31 .. 31;
   end record;

   subtype FIFO_ST_RXFIFO_RADDR_Field is ESP32S3_Registers.UInt5;
   subtype FIFO_ST_RXFIFO_WADDR_Field is ESP32S3_Registers.UInt5;
   subtype FIFO_ST_TXFIFO_RADDR_Field is ESP32S3_Registers.UInt5;
   subtype FIFO_ST_TXFIFO_WADDR_Field is ESP32S3_Registers.UInt5;
   subtype FIFO_ST_SLAVE_RW_POINT_Field is ESP32S3_Registers.Byte;

   --  FIFO status register.
   type FIFO_ST_Register is record
      --  Read-only. This is the offset address of the APB reading from rxfifo
      RXFIFO_RADDR   : FIFO_ST_RXFIFO_RADDR_Field;
      --  Read-only. This is the offset address of i2c module receiving data
      --  and writing to rxfifo.
      RXFIFO_WADDR   : FIFO_ST_RXFIFO_WADDR_Field;
      --  Read-only. This is the offset address of i2c module reading from
      --  txfifo.
      TXFIFO_RADDR   : FIFO_ST_TXFIFO_RADDR_Field;
      --  Read-only. This is the offset address of APB bus writing to txfifo.
      TXFIFO_WADDR   : FIFO_ST_TXFIFO_WADDR_Field;
      --  unspecified
      Reserved_20_21 : ESP32S3_Registers.UInt2;
      --  Read-only. The received data in I2C slave mode.
      SLAVE_RW_POINT : FIFO_ST_SLAVE_RW_POINT_Field;
      --  unspecified
      Reserved_30_31 : ESP32S3_Registers.UInt2;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FIFO_ST_Register use record
      RXFIFO_RADDR   at 0 range 0 .. 4;
      RXFIFO_WADDR   at 0 range 5 .. 9;
      TXFIFO_RADDR   at 0 range 10 .. 14;
      TXFIFO_WADDR   at 0 range 15 .. 19;
      Reserved_20_21 at 0 range 20 .. 21;
      SLAVE_RW_POINT at 0 range 22 .. 29;
      Reserved_30_31 at 0 range 30 .. 31;
   end record;

   subtype FIFO_CONF_RXFIFO_WM_THRHD_Field is ESP32S3_Registers.UInt5;
   subtype FIFO_CONF_TXFIFO_WM_THRHD_Field is ESP32S3_Registers.UInt5;

   --  FIFO configuration register.
   type FIFO_CONF_Register is record
      --  The water mark threshold of rx FIFO in nonfifo access mode. When
      --  reg_reg_fifo_prt_en is 1 and rx FIFO counter is bigger than
      --  reg_rxfifo_wm_thrhd[4:0], reg_rxfifo_wm_int_raw bit will be valid.
      RXFIFO_WM_THRHD  : FIFO_CONF_RXFIFO_WM_THRHD_Field := 16#B#;
      --  The water mark threshold of tx FIFO in nonfifo access mode. When
      --  reg_reg_fifo_prt_en is 1 and tx FIFO counter is smaller than
      --  reg_txfifo_wm_thrhd[4:0], reg_txfifo_wm_int_raw bit will be valid.
      TXFIFO_WM_THRHD  : FIFO_CONF_TXFIFO_WM_THRHD_Field := 16#4#;
      --  Set this bit to enable APB nonfifo access.
      NONFIFO_EN       : Boolean := False;
      --  When this bit is set to 1, the byte received after the I2C address
      --  byte represents the offset address in the I2C Slave RAM.
      FIFO_ADDR_CFG_EN : Boolean := False;
      --  Set this bit to reset rx-fifo.
      RX_FIFO_RST      : Boolean := False;
      --  Set this bit to reset tx-fifo.
      TX_FIFO_RST      : Boolean := False;
      --  The control enable bit of FIFO pointer in non-fifo access mode. This
      --  bit controls the valid bits and the interrupts of tx/rx_fifo
      --  overflow, underflow, full and empty.
      FIFO_PRT_EN      : Boolean := True;
      --  unspecified
      Reserved_15_31   : ESP32S3_Registers.UInt17 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FIFO_CONF_Register use record
      RXFIFO_WM_THRHD  at 0 range 0 .. 4;
      TXFIFO_WM_THRHD  at 0 range 5 .. 9;
      NONFIFO_EN       at 0 range 10 .. 10;
      FIFO_ADDR_CFG_EN at 0 range 11 .. 11;
      RX_FIFO_RST      at 0 range 12 .. 12;
      TX_FIFO_RST      at 0 range 13 .. 13;
      FIFO_PRT_EN      at 0 range 14 .. 14;
      Reserved_15_31   at 0 range 15 .. 31;
   end record;

   subtype DATA_FIFO_RDATA_Field is ESP32S3_Registers.Byte;

   --  Rx FIFO read data.
   type DATA_Register is record
      --  The value of rx FIFO read data.
      FIFO_RDATA    : DATA_FIFO_RDATA_Field := 16#0#;
      --  unspecified
      Reserved_8_31 : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DATA_Register use record
      FIFO_RDATA    at 0 range 0 .. 7;
      Reserved_8_31 at 0 range 8 .. 31;
   end record;

   --  Raw interrupt status
   type INT_RAW_Register is record
      --  Read-only. The raw interrupt bit for I2C_RXFIFO_WM_INT interrupt.
      RXFIFO_WM_INT_RAW        : Boolean;
      --  Read-only. The raw interrupt bit for I2C_TXFIFO_WM_INT interrupt.
      TXFIFO_WM_INT_RAW        : Boolean;
      --  Read-only. The raw interrupt bit for I2C_RXFIFO_OVF_INT interrupt.
      RXFIFO_OVF_INT_RAW       : Boolean;
      --  Read-only. The raw interrupt bit for the I2C_END_DETECT_INT
      --  interrupt.
      END_DETECT_INT_RAW       : Boolean;
      --  Read-only. The raw interrupt bit for the I2C_END_DETECT_INT
      --  interrupt.
      BYTE_TRANS_DONE_INT_RAW  : Boolean;
      --  Read-only. The raw interrupt bit for the I2C_ARBITRATION_LOST_INT
      --  interrupt.
      ARBITRATION_LOST_INT_RAW : Boolean;
      --  Read-only. The raw interrupt bit for I2C_TRANS_COMPLETE_INT
      --  interrupt.
      MST_TXFIFO_UDF_INT_RAW   : Boolean;
      --  Read-only. The raw interrupt bit for the I2C_TRANS_COMPLETE_INT
      --  interrupt.
      TRANS_COMPLETE_INT_RAW   : Boolean;
      --  Read-only. The raw interrupt bit for the I2C_TIME_OUT_INT interrupt.
      TIME_OUT_INT_RAW         : Boolean;
      --  Read-only. The raw interrupt bit for the I2C_TRANS_START_INT
      --  interrupt.
      TRANS_START_INT_RAW      : Boolean;
      --  Read-only. The raw interrupt bit for I2C_SLAVE_STRETCH_INT interrupt.
      NACK_INT_RAW             : Boolean;
      --  Read-only. The raw interrupt bit for I2C_TXFIFO_OVF_INT interrupt.
      TXFIFO_OVF_INT_RAW       : Boolean;
      --  Read-only. The raw interrupt bit for I2C_RXFIFO_UDF_INT interrupt.
      RXFIFO_UDF_INT_RAW       : Boolean;
      --  Read-only. The raw interrupt bit for I2C_SCL_ST_TO_INT interrupt.
      SCL_ST_TO_INT_RAW        : Boolean;
      --  Read-only. The raw interrupt bit for I2C_SCL_MAIN_ST_TO_INT
      --  interrupt.
      SCL_MAIN_ST_TO_INT_RAW   : Boolean;
      --  Read-only. The raw interrupt bit for I2C_DET_START_INT interrupt.
      DET_START_INT_RAW        : Boolean;
      --  Read-only. The raw interrupt bit for I2C_SLAVE_STRETCH_INT interrupt.
      SLAVE_STRETCH_INT_RAW    : Boolean;
      --  Read-only. The raw interrupt bit for I2C_GENARAL_CALL_INT interrupt.
      GENERAL_CALL_INT_RAW     : Boolean;
      --  unspecified
      Reserved_18_31           : ESP32S3_Registers.UInt14;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_RAW_Register use record
      RXFIFO_WM_INT_RAW        at 0 range 0 .. 0;
      TXFIFO_WM_INT_RAW        at 0 range 1 .. 1;
      RXFIFO_OVF_INT_RAW       at 0 range 2 .. 2;
      END_DETECT_INT_RAW       at 0 range 3 .. 3;
      BYTE_TRANS_DONE_INT_RAW  at 0 range 4 .. 4;
      ARBITRATION_LOST_INT_RAW at 0 range 5 .. 5;
      MST_TXFIFO_UDF_INT_RAW   at 0 range 6 .. 6;
      TRANS_COMPLETE_INT_RAW   at 0 range 7 .. 7;
      TIME_OUT_INT_RAW         at 0 range 8 .. 8;
      TRANS_START_INT_RAW      at 0 range 9 .. 9;
      NACK_INT_RAW             at 0 range 10 .. 10;
      TXFIFO_OVF_INT_RAW       at 0 range 11 .. 11;
      RXFIFO_UDF_INT_RAW       at 0 range 12 .. 12;
      SCL_ST_TO_INT_RAW        at 0 range 13 .. 13;
      SCL_MAIN_ST_TO_INT_RAW   at 0 range 14 .. 14;
      DET_START_INT_RAW        at 0 range 15 .. 15;
      SLAVE_STRETCH_INT_RAW    at 0 range 16 .. 16;
      GENERAL_CALL_INT_RAW     at 0 range 17 .. 17;
      Reserved_18_31           at 0 range 18 .. 31;
   end record;

   --  Interrupt clear bits
   type INT_CLR_Register is record
      --  Write-only. Set this bit to clear I2C_RXFIFO_WM_INT interrupt.
      RXFIFO_WM_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear I2C_TXFIFO_WM_INT interrupt.
      TXFIFO_WM_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear I2C_RXFIFO_OVF_INT interrupt.
      RXFIFO_OVF_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the I2C_END_DETECT_INT interrupt.
      END_DETECT_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear the I2C_END_DETECT_INT interrupt.
      BYTE_TRANS_DONE_INT_CLR  : Boolean := False;
      --  Write-only. Set this bit to clear the I2C_ARBITRATION_LOST_INT
      --  interrupt.
      ARBITRATION_LOST_INT_CLR : Boolean := False;
      --  Write-only. Set this bit to clear I2C_TRANS_COMPLETE_INT interrupt.
      MST_TXFIFO_UDF_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear the I2C_TRANS_COMPLETE_INT
      --  interrupt.
      TRANS_COMPLETE_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear the I2C_TIME_OUT_INT interrupt.
      TIME_OUT_INT_CLR         : Boolean := False;
      --  Write-only. Set this bit to clear the I2C_TRANS_START_INT interrupt.
      TRANS_START_INT_CLR      : Boolean := False;
      --  Write-only. Set this bit to clear I2C_SLAVE_STRETCH_INT interrupt.
      NACK_INT_CLR             : Boolean := False;
      --  Write-only. Set this bit to clear I2C_TXFIFO_OVF_INT interrupt.
      TXFIFO_OVF_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear I2C_RXFIFO_UDF_INT interrupt.
      RXFIFO_UDF_INT_CLR       : Boolean := False;
      --  Write-only. Set this bit to clear I2C_SCL_ST_TO_INT interrupt.
      SCL_ST_TO_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear I2C_SCL_MAIN_ST_TO_INT interrupt.
      SCL_MAIN_ST_TO_INT_CLR   : Boolean := False;
      --  Write-only. Set this bit to clear I2C_DET_START_INT interrupt.
      DET_START_INT_CLR        : Boolean := False;
      --  Write-only. Set this bit to clear I2C_SLAVE_STRETCH_INT interrupt.
      SLAVE_STRETCH_INT_CLR    : Boolean := False;
      --  Write-only. Set this bit for I2C_GENARAL_CALL_INT interrupt.
      GENERAL_CALL_INT_CLR     : Boolean := False;
      --  unspecified
      Reserved_18_31           : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_CLR_Register use record
      RXFIFO_WM_INT_CLR        at 0 range 0 .. 0;
      TXFIFO_WM_INT_CLR        at 0 range 1 .. 1;
      RXFIFO_OVF_INT_CLR       at 0 range 2 .. 2;
      END_DETECT_INT_CLR       at 0 range 3 .. 3;
      BYTE_TRANS_DONE_INT_CLR  at 0 range 4 .. 4;
      ARBITRATION_LOST_INT_CLR at 0 range 5 .. 5;
      MST_TXFIFO_UDF_INT_CLR   at 0 range 6 .. 6;
      TRANS_COMPLETE_INT_CLR   at 0 range 7 .. 7;
      TIME_OUT_INT_CLR         at 0 range 8 .. 8;
      TRANS_START_INT_CLR      at 0 range 9 .. 9;
      NACK_INT_CLR             at 0 range 10 .. 10;
      TXFIFO_OVF_INT_CLR       at 0 range 11 .. 11;
      RXFIFO_UDF_INT_CLR       at 0 range 12 .. 12;
      SCL_ST_TO_INT_CLR        at 0 range 13 .. 13;
      SCL_MAIN_ST_TO_INT_CLR   at 0 range 14 .. 14;
      DET_START_INT_CLR        at 0 range 15 .. 15;
      SLAVE_STRETCH_INT_CLR    at 0 range 16 .. 16;
      GENERAL_CALL_INT_CLR     at 0 range 17 .. 17;
      Reserved_18_31           at 0 range 18 .. 31;
   end record;

   --  Interrupt enable bits
   type INT_ENA_Register is record
      --  The interrupt enable bit for I2C_RXFIFO_WM_INT interrupt.
      RXFIFO_WM_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for I2C_TXFIFO_WM_INT interrupt.
      TXFIFO_WM_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for I2C_RXFIFO_OVF_INT interrupt.
      RXFIFO_OVF_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the I2C_END_DETECT_INT interrupt.
      END_DETECT_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for the I2C_END_DETECT_INT interrupt.
      BYTE_TRANS_DONE_INT_ENA  : Boolean := False;
      --  The interrupt enable bit for the I2C_ARBITRATION_LOST_INT interrupt.
      ARBITRATION_LOST_INT_ENA : Boolean := False;
      --  The interrupt enable bit for I2C_TRANS_COMPLETE_INT interrupt.
      MST_TXFIFO_UDF_INT_ENA   : Boolean := False;
      --  The interrupt enable bit for the I2C_TRANS_COMPLETE_INT interrupt.
      TRANS_COMPLETE_INT_ENA   : Boolean := False;
      --  The interrupt enable bit for the I2C_TIME_OUT_INT interrupt.
      TIME_OUT_INT_ENA         : Boolean := False;
      --  The interrupt enable bit for the I2C_TRANS_START_INT interrupt.
      TRANS_START_INT_ENA      : Boolean := False;
      --  The interrupt enable bit for I2C_SLAVE_STRETCH_INT interrupt.
      NACK_INT_ENA             : Boolean := False;
      --  The interrupt enable bit for I2C_TXFIFO_OVF_INT interrupt.
      TXFIFO_OVF_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for I2C_RXFIFO_UDF_INT interrupt.
      RXFIFO_UDF_INT_ENA       : Boolean := False;
      --  The interrupt enable bit for I2C_SCL_ST_TO_INT interrupt.
      SCL_ST_TO_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for I2C_SCL_MAIN_ST_TO_INT interrupt.
      SCL_MAIN_ST_TO_INT_ENA   : Boolean := False;
      --  The interrupt enable bit for I2C_DET_START_INT interrupt.
      DET_START_INT_ENA        : Boolean := False;
      --  The interrupt enable bit for I2C_SLAVE_STRETCH_INT interrupt.
      SLAVE_STRETCH_INT_ENA    : Boolean := False;
      --  The interrupt enable bit for I2C_GENARAL_CALL_INT interrupt.
      GENERAL_CALL_INT_ENA     : Boolean := False;
      --  unspecified
      Reserved_18_31           : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_ENA_Register use record
      RXFIFO_WM_INT_ENA        at 0 range 0 .. 0;
      TXFIFO_WM_INT_ENA        at 0 range 1 .. 1;
      RXFIFO_OVF_INT_ENA       at 0 range 2 .. 2;
      END_DETECT_INT_ENA       at 0 range 3 .. 3;
      BYTE_TRANS_DONE_INT_ENA  at 0 range 4 .. 4;
      ARBITRATION_LOST_INT_ENA at 0 range 5 .. 5;
      MST_TXFIFO_UDF_INT_ENA   at 0 range 6 .. 6;
      TRANS_COMPLETE_INT_ENA   at 0 range 7 .. 7;
      TIME_OUT_INT_ENA         at 0 range 8 .. 8;
      TRANS_START_INT_ENA      at 0 range 9 .. 9;
      NACK_INT_ENA             at 0 range 10 .. 10;
      TXFIFO_OVF_INT_ENA       at 0 range 11 .. 11;
      RXFIFO_UDF_INT_ENA       at 0 range 12 .. 12;
      SCL_ST_TO_INT_ENA        at 0 range 13 .. 13;
      SCL_MAIN_ST_TO_INT_ENA   at 0 range 14 .. 14;
      DET_START_INT_ENA        at 0 range 15 .. 15;
      SLAVE_STRETCH_INT_ENA    at 0 range 16 .. 16;
      GENERAL_CALL_INT_ENA     at 0 range 17 .. 17;
      Reserved_18_31           at 0 range 18 .. 31;
   end record;

   --  Status of captured I2C communication events
   type INT_STATUS_Register is record
      --  Read-only. The masked interrupt status bit for I2C_RXFIFO_WM_INT
      --  interrupt.
      RXFIFO_WM_INT_ST        : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_TXFIFO_WM_INT
      --  interrupt.
      TXFIFO_WM_INT_ST        : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_RXFIFO_OVF_INT
      --  interrupt.
      RXFIFO_OVF_INT_ST       : Boolean;
      --  Read-only. The masked interrupt status bit for the I2C_END_DETECT_INT
      --  interrupt.
      END_DETECT_INT_ST       : Boolean;
      --  Read-only. The masked interrupt status bit for the I2C_END_DETECT_INT
      --  interrupt.
      BYTE_TRANS_DONE_INT_ST  : Boolean;
      --  Read-only. The masked interrupt status bit for the
      --  I2C_ARBITRATION_LOST_INT interrupt.
      ARBITRATION_LOST_INT_ST : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_TRANS_COMPLETE_INT
      --  interrupt.
      MST_TXFIFO_UDF_INT_ST   : Boolean;
      --  Read-only. The masked interrupt status bit for the
      --  I2C_TRANS_COMPLETE_INT interrupt.
      TRANS_COMPLETE_INT_ST   : Boolean;
      --  Read-only. The masked interrupt status bit for the I2C_TIME_OUT_INT
      --  interrupt.
      TIME_OUT_INT_ST         : Boolean;
      --  Read-only. The masked interrupt status bit for the
      --  I2C_TRANS_START_INT interrupt.
      TRANS_START_INT_ST      : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_SLAVE_STRETCH_INT
      --  interrupt.
      NACK_INT_ST             : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_TXFIFO_OVF_INT
      --  interrupt.
      TXFIFO_OVF_INT_ST       : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_RXFIFO_UDF_INT
      --  interrupt.
      RXFIFO_UDF_INT_ST       : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_SCL_ST_TO_INT
      --  interrupt.
      SCL_ST_TO_INT_ST        : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_SCL_MAIN_ST_TO_INT
      --  interrupt.
      SCL_MAIN_ST_TO_INT_ST   : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_DET_START_INT
      --  interrupt.
      DET_START_INT_ST        : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_SLAVE_STRETCH_INT
      --  interrupt.
      SLAVE_STRETCH_INT_ST    : Boolean;
      --  Read-only. The masked interrupt status bit for I2C_GENARAL_CALL_INT
      --  interrupt.
      GENERAL_CALL_INT_ST     : Boolean;
      --  unspecified
      Reserved_18_31          : ESP32S3_Registers.UInt14;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INT_STATUS_Register use record
      RXFIFO_WM_INT_ST        at 0 range 0 .. 0;
      TXFIFO_WM_INT_ST        at 0 range 1 .. 1;
      RXFIFO_OVF_INT_ST       at 0 range 2 .. 2;
      END_DETECT_INT_ST       at 0 range 3 .. 3;
      BYTE_TRANS_DONE_INT_ST  at 0 range 4 .. 4;
      ARBITRATION_LOST_INT_ST at 0 range 5 .. 5;
      MST_TXFIFO_UDF_INT_ST   at 0 range 6 .. 6;
      TRANS_COMPLETE_INT_ST   at 0 range 7 .. 7;
      TIME_OUT_INT_ST         at 0 range 8 .. 8;
      TRANS_START_INT_ST      at 0 range 9 .. 9;
      NACK_INT_ST             at 0 range 10 .. 10;
      TXFIFO_OVF_INT_ST       at 0 range 11 .. 11;
      RXFIFO_UDF_INT_ST       at 0 range 12 .. 12;
      SCL_ST_TO_INT_ST        at 0 range 13 .. 13;
      SCL_MAIN_ST_TO_INT_ST   at 0 range 14 .. 14;
      DET_START_INT_ST        at 0 range 15 .. 15;
      SLAVE_STRETCH_INT_ST    at 0 range 16 .. 16;
      GENERAL_CALL_INT_ST     at 0 range 17 .. 17;
      Reserved_18_31          at 0 range 18 .. 31;
   end record;

   subtype SDA_HOLD_TIME_Field is ESP32S3_Registers.UInt9;

   --  Configures the hold time after a negative SCL edge.
   type SDA_HOLD_Register is record
      --  This register is used to configure the time to hold the data after
      --  the negative edge of SCL, in I2C module clock cycles.
      TIME          : SDA_HOLD_TIME_Field := 16#0#;
      --  unspecified
      Reserved_9_31 : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SDA_HOLD_Register use record
      TIME          at 0 range 0 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype SDA_SAMPLE_TIME_Field is ESP32S3_Registers.UInt9;

   --  Configures the sample time after a positive SCL edge.
   type SDA_SAMPLE_Register is record
      --  This register is used to configure for how long SDA is sampled, in
      --  I2C module clock cycles.
      TIME          : SDA_SAMPLE_TIME_Field := 16#0#;
      --  unspecified
      Reserved_9_31 : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SDA_SAMPLE_Register use record
      TIME          at 0 range 0 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype SCL_HIGH_PERIOD_SCL_HIGH_PERIOD_Field is ESP32S3_Registers.UInt9;
   subtype SCL_HIGH_PERIOD_SCL_WAIT_HIGH_PERIOD_Field is
     ESP32S3_Registers.UInt7;

   --  Configures the high level width of SCL
   type SCL_HIGH_PERIOD_Register is record
      --  This register is used to configure for how long SCL remains high in
      --  master mode, in I2C module clock cycles.
      SCL_HIGH_PERIOD      : SCL_HIGH_PERIOD_SCL_HIGH_PERIOD_Field := 16#0#;
      --  This register is used to configure for the SCL_FSM's waiting period
      --  for SCL high level in master mode, in I2C module clock cycles.
      SCL_WAIT_HIGH_PERIOD : SCL_HIGH_PERIOD_SCL_WAIT_HIGH_PERIOD_Field :=
                              16#0#;
      --  unspecified
      Reserved_16_31       : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_HIGH_PERIOD_Register use record
      SCL_HIGH_PERIOD      at 0 range 0 .. 8;
      SCL_WAIT_HIGH_PERIOD at 0 range 9 .. 15;
      Reserved_16_31       at 0 range 16 .. 31;
   end record;

   subtype SCL_START_HOLD_TIME_Field is ESP32S3_Registers.UInt9;

   --  Configures the delay between the SDA and SCL negative edge for a start
   --  condition
   type SCL_START_HOLD_Register is record
      --  This register is used to configure the time between the negative edge
      --  of SDA and the negative edge of SCL for a START condition, in I2C
      --  module clock cycles.
      TIME          : SCL_START_HOLD_TIME_Field := 16#8#;
      --  unspecified
      Reserved_9_31 : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_START_HOLD_Register use record
      TIME          at 0 range 0 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype SCL_RSTART_SETUP_TIME_Field is ESP32S3_Registers.UInt9;

   --  Configures the delay between the positive edge of SCL and the negative
   --  edge of SDA
   type SCL_RSTART_SETUP_Register is record
      --  This register is used to configure the time between the positive edge
      --  of SCL and the negative edge of SDA for a RESTART condition, in I2C
      --  module clock cycles.
      TIME          : SCL_RSTART_SETUP_TIME_Field := 16#8#;
      --  unspecified
      Reserved_9_31 : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_RSTART_SETUP_Register use record
      TIME          at 0 range 0 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype SCL_STOP_HOLD_TIME_Field is ESP32S3_Registers.UInt9;

   --  Configures the delay after the SCL clock edge for a stop condition
   type SCL_STOP_HOLD_Register is record
      --  This register is used to configure the delay after the STOP
      --  condition, in I2C module clock cycles.
      TIME          : SCL_STOP_HOLD_TIME_Field := 16#8#;
      --  unspecified
      Reserved_9_31 : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_STOP_HOLD_Register use record
      TIME          at 0 range 0 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype SCL_STOP_SETUP_TIME_Field is ESP32S3_Registers.UInt9;

   --  Configures the delay between the SDA and SCL positive edge for a stop
   --  condition
   type SCL_STOP_SETUP_Register is record
      --  This register is used to configure the time between the positive edge
      --  of SCL and the positive edge of SDA, in I2C module clock cycles.
      TIME          : SCL_STOP_SETUP_TIME_Field := 16#8#;
      --  unspecified
      Reserved_9_31 : ESP32S3_Registers.UInt23 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_STOP_SETUP_Register use record
      TIME          at 0 range 0 .. 8;
      Reserved_9_31 at 0 range 9 .. 31;
   end record;

   subtype FILTER_CFG_SCL_FILTER_THRES_Field is ESP32S3_Registers.UInt4;
   subtype FILTER_CFG_SDA_FILTER_THRES_Field is ESP32S3_Registers.UInt4;

   --  SCL and SDA filter configuration register
   type FILTER_CFG_Register is record
      --  When a pulse on the SCL input has smaller width than this register
      --  value in I2C module clock cycles, the I2C controller will ignore that
      --  pulse.
      SCL_FILTER_THRES : FILTER_CFG_SCL_FILTER_THRES_Field := 16#0#;
      --  When a pulse on the SDA input has smaller width than this register
      --  value in I2C module clock cycles, the I2C controller will ignore that
      --  pulse.
      SDA_FILTER_THRES : FILTER_CFG_SDA_FILTER_THRES_Field := 16#0#;
      --  This is the filter enable bit for SCL.
      SCL_FILTER_EN    : Boolean := True;
      --  This is the filter enable bit for SDA.
      SDA_FILTER_EN    : Boolean := True;
      --  unspecified
      Reserved_10_31   : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FILTER_CFG_Register use record
      SCL_FILTER_THRES at 0 range 0 .. 3;
      SDA_FILTER_THRES at 0 range 4 .. 7;
      SCL_FILTER_EN    at 0 range 8 .. 8;
      SDA_FILTER_EN    at 0 range 9 .. 9;
      Reserved_10_31   at 0 range 10 .. 31;
   end record;

   subtype CLK_CONF_SCLK_DIV_NUM_Field is ESP32S3_Registers.Byte;
   subtype CLK_CONF_SCLK_DIV_A_Field is ESP32S3_Registers.UInt6;
   subtype CLK_CONF_SCLK_DIV_B_Field is ESP32S3_Registers.UInt6;

   --  I2C CLK configuration register
   type CLK_CONF_Register is record
      --  the integral part of the fractional divisor for i2c module
      SCLK_DIV_NUM   : CLK_CONF_SCLK_DIV_NUM_Field := 16#0#;
      --  the numerator of the fractional part of the fractional divisor for
      --  i2c module
      SCLK_DIV_A     : CLK_CONF_SCLK_DIV_A_Field := 16#0#;
      --  the denominator of the fractional part of the fractional divisor for
      --  i2c module
      SCLK_DIV_B     : CLK_CONF_SCLK_DIV_B_Field := 16#0#;
      --  The clock selection for i2c module:0-XTAL;1-CLK_8MHz.
      SCLK_SEL       : Boolean := False;
      --  The clock switch for i2c module
      SCLK_ACTIVE    : Boolean := True;
      --  unspecified
      Reserved_22_31 : ESP32S3_Registers.UInt10 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLK_CONF_Register use record
      SCLK_DIV_NUM   at 0 range 0 .. 7;
      SCLK_DIV_A     at 0 range 8 .. 13;
      SCLK_DIV_B     at 0 range 14 .. 19;
      SCLK_SEL       at 0 range 20 .. 20;
      SCLK_ACTIVE    at 0 range 21 .. 21;
      Reserved_22_31 at 0 range 22 .. 31;
   end record;

   subtype COMD_COMMAND_Field is ESP32S3_Registers.UInt14;

   --  I2C command register %s
   type COMD_Register is record
      --  This is the content of command 0. It consists of three parts: op_code
      --  is the command, 0: RSTART; 1: WRITE; 2: READ; 3: STOP; 4: END.
      --  Byte_num represents the number of bytes that need to be sent or
      --  received. ack_check_en, ack_exp and ack are used to control the ACK
      --  bit. See I2C cmd structure for more Information.
      COMMAND        : COMD_COMMAND_Field := 16#0#;
      --  unspecified
      Reserved_14_30 : ESP32S3_Registers.UInt17 := 16#0#;
      --  When command 0 is done in I2C Master mode, this bit changes to high
      --  level.
      COMMAND_DONE   : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for COMD_Register use record
      COMMAND        at 0 range 0 .. 13;
      Reserved_14_30 at 0 range 14 .. 30;
      COMMAND_DONE   at 0 range 31 .. 31;
   end record;

   --  I2C command register %s
   type COMD_Registers is array (0 .. 7) of COMD_Register;

   subtype SCL_ST_TIME_OUT_SCL_ST_TO_I2C_Field is ESP32S3_Registers.UInt5;

   --  SCL status time out register
   type SCL_ST_TIME_OUT_Register is record
      --  The threshold value of SCL_FSM state unchanged period. It should be o
      --  more than 23
      SCL_ST_TO_I2C : SCL_ST_TIME_OUT_SCL_ST_TO_I2C_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_ST_TIME_OUT_Register use record
      SCL_ST_TO_I2C at 0 range 0 .. 4;
      Reserved_5_31 at 0 range 5 .. 31;
   end record;

   subtype SCL_MAIN_ST_TIME_OUT_SCL_MAIN_ST_TO_I2C_Field is
     ESP32S3_Registers.UInt5;

   --  SCL main status time out register
   type SCL_MAIN_ST_TIME_OUT_Register is record
      --  The threshold value of SCL_MAIN_FSM state unchanged period.nIt should
      --  be o more than 23
      SCL_MAIN_ST_TO_I2C : SCL_MAIN_ST_TIME_OUT_SCL_MAIN_ST_TO_I2C_Field :=
                            16#10#;
      --  unspecified
      Reserved_5_31      : ESP32S3_Registers.UInt27 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_MAIN_ST_TIME_OUT_Register use record
      SCL_MAIN_ST_TO_I2C at 0 range 0 .. 4;
      Reserved_5_31      at 0 range 5 .. 31;
   end record;

   subtype SCL_SP_CONF_SCL_RST_SLV_NUM_Field is ESP32S3_Registers.UInt5;

   --  Power configuration register
   type SCL_SP_CONF_Register is record
      --  When I2C master is IDLE, set this bit to send out SCL pulses. The
      --  number of pulses equals to reg_scl_rst_slv_num[4:0].
      SCL_RST_SLV_EN  : Boolean := False;
      --  Configure the pulses of SCL generated in I2C master mode. Valid when
      --  reg_scl_rst_slv_en is 1.
      SCL_RST_SLV_NUM : SCL_SP_CONF_SCL_RST_SLV_NUM_Field := 16#0#;
      --  The power down enable bit for the I2C output SCL line. 1: Power down.
      --  0: Not power down. Set reg_scl_force_out and reg_scl_pd_en to 1 to
      --  stretch SCL low.
      SCL_PD_EN       : Boolean := False;
      --  The power down enable bit for the I2C output SDA line. 1: Power down.
      --  0: Not power down. Set reg_sda_force_out and reg_sda_pd_en to 1 to
      --  stretch SDA low.
      SDA_PD_EN       : Boolean := False;
      --  unspecified
      Reserved_8_31   : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_SP_CONF_Register use record
      SCL_RST_SLV_EN  at 0 range 0 .. 0;
      SCL_RST_SLV_NUM at 0 range 1 .. 5;
      SCL_PD_EN       at 0 range 6 .. 6;
      SDA_PD_EN       at 0 range 7 .. 7;
      Reserved_8_31   at 0 range 8 .. 31;
   end record;

   subtype SCL_STRETCH_CONF_STRETCH_PROTECT_NUM_Field is
     ESP32S3_Registers.UInt10;

   --  Set SCL stretch of I2C slave
   type SCL_STRETCH_CONF_Register is record
      --  Configure the period of I2C slave stretching SCL line.
      STRETCH_PROTECT_NUM   : SCL_STRETCH_CONF_STRETCH_PROTECT_NUM_Field :=
                               16#0#;
      --  The enable bit for slave SCL stretch function. 1: Enable. 0: Disable.
      --  The SCL output line will be stretched low when
      --  reg_slave_scl_stretch_en is 1 and stretch event happens. The stretch
      --  cause can be seen in reg_stretch_cause.
      SLAVE_SCL_STRETCH_EN  : Boolean := False;
      --  Write-only. Set this bit to clear the I2C slave SCL stretch function.
      SLAVE_SCL_STRETCH_CLR : Boolean := False;
      --  The enable bit for slave to control ACK level function.
      SLAVE_BYTE_ACK_CTL_EN : Boolean := False;
      --  Set the ACK level when slave controlling ACK level function enables.
      SLAVE_BYTE_ACK_LVL    : Boolean := False;
      --  unspecified
      Reserved_14_31        : ESP32S3_Registers.UInt18 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for SCL_STRETCH_CONF_Register use record
      STRETCH_PROTECT_NUM   at 0 range 0 .. 9;
      SLAVE_SCL_STRETCH_EN  at 0 range 10 .. 10;
      SLAVE_SCL_STRETCH_CLR at 0 range 11 .. 11;
      SLAVE_BYTE_ACK_CTL_EN at 0 range 12 .. 12;
      SLAVE_BYTE_ACK_LVL    at 0 range 13 .. 13;
      Reserved_14_31        at 0 range 14 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  I2C (Inter-Integrated Circuit) Controller 0
   type I2C_Peripheral is record
      --  Configures the low level width of the SCL Clock
      SCL_LOW_PERIOD       : aliased SCL_LOW_PERIOD_Register;
      --  Transmission setting
      CTR                  : aliased CTR_Register;
      --  Describe I2C work status.
      SR                   : aliased SR_Register;
      --  Setting time out control for receiving data.
      TO                   : aliased TO_Register;
      --  Local slave address setting
      SLAVE_ADDR           : aliased SLAVE_ADDR_Register;
      --  FIFO status register.
      FIFO_ST              : aliased FIFO_ST_Register;
      --  FIFO configuration register.
      FIFO_CONF            : aliased FIFO_CONF_Register;
      --  Rx FIFO read data.
      DATA                 : aliased DATA_Register;
      --  Raw interrupt status
      INT_RAW              : aliased INT_RAW_Register;
      --  Interrupt clear bits
      INT_CLR              : aliased INT_CLR_Register;
      --  Interrupt enable bits
      INT_ENA              : aliased INT_ENA_Register;
      --  Status of captured I2C communication events
      INT_STATUS           : aliased INT_STATUS_Register;
      --  Configures the hold time after a negative SCL edge.
      SDA_HOLD             : aliased SDA_HOLD_Register;
      --  Configures the sample time after a positive SCL edge.
      SDA_SAMPLE           : aliased SDA_SAMPLE_Register;
      --  Configures the high level width of SCL
      SCL_HIGH_PERIOD      : aliased SCL_HIGH_PERIOD_Register;
      --  Configures the delay between the SDA and SCL negative edge for a
      --  start condition
      SCL_START_HOLD       : aliased SCL_START_HOLD_Register;
      --  Configures the delay between the positive edge of SCL and the
      --  negative edge of SDA
      SCL_RSTART_SETUP     : aliased SCL_RSTART_SETUP_Register;
      --  Configures the delay after the SCL clock edge for a stop condition
      SCL_STOP_HOLD        : aliased SCL_STOP_HOLD_Register;
      --  Configures the delay between the SDA and SCL positive edge for a stop
      --  condition
      SCL_STOP_SETUP       : aliased SCL_STOP_SETUP_Register;
      --  SCL and SDA filter configuration register
      FILTER_CFG           : aliased FILTER_CFG_Register;
      --  I2C CLK configuration register
      CLK_CONF             : aliased CLK_CONF_Register;
      --  I2C command register %s
      COMD                 : aliased COMD_Registers;
      --  SCL status time out register
      SCL_ST_TIME_OUT      : aliased SCL_ST_TIME_OUT_Register;
      --  SCL main status time out register
      SCL_MAIN_ST_TIME_OUT : aliased SCL_MAIN_ST_TIME_OUT_Register;
      --  Power configuration register
      SCL_SP_CONF          : aliased SCL_SP_CONF_Register;
      --  Set SCL stretch of I2C slave
      SCL_STRETCH_CONF     : aliased SCL_STRETCH_CONF_Register;
      --  Version register
      DATE                 : aliased ESP32S3_Registers.UInt32;
      --  I2C TXFIFO base address register
      TXFIFO_START_ADDR    : aliased ESP32S3_Registers.UInt32;
      --  I2C RXFIFO base address register
      RXFIFO_START_ADDR    : aliased ESP32S3_Registers.UInt32;
   end record
     with Volatile;

   for I2C_Peripheral use record
      SCL_LOW_PERIOD       at 16#0# range 0 .. 31;
      CTR                  at 16#4# range 0 .. 31;
      SR                   at 16#8# range 0 .. 31;
      TO                   at 16#C# range 0 .. 31;
      SLAVE_ADDR           at 16#10# range 0 .. 31;
      FIFO_ST              at 16#14# range 0 .. 31;
      FIFO_CONF            at 16#18# range 0 .. 31;
      DATA                 at 16#1C# range 0 .. 31;
      INT_RAW              at 16#20# range 0 .. 31;
      INT_CLR              at 16#24# range 0 .. 31;
      INT_ENA              at 16#28# range 0 .. 31;
      INT_STATUS           at 16#2C# range 0 .. 31;
      SDA_HOLD             at 16#30# range 0 .. 31;
      SDA_SAMPLE           at 16#34# range 0 .. 31;
      SCL_HIGH_PERIOD      at 16#38# range 0 .. 31;
      SCL_START_HOLD       at 16#40# range 0 .. 31;
      SCL_RSTART_SETUP     at 16#44# range 0 .. 31;
      SCL_STOP_HOLD        at 16#48# range 0 .. 31;
      SCL_STOP_SETUP       at 16#4C# range 0 .. 31;
      FILTER_CFG           at 16#50# range 0 .. 31;
      CLK_CONF             at 16#54# range 0 .. 31;
      COMD                 at 16#58# range 0 .. 255;
      SCL_ST_TIME_OUT      at 16#78# range 0 .. 31;
      SCL_MAIN_ST_TIME_OUT at 16#7C# range 0 .. 31;
      SCL_SP_CONF          at 16#80# range 0 .. 31;
      SCL_STRETCH_CONF     at 16#84# range 0 .. 31;
      DATE                 at 16#F8# range 0 .. 31;
      TXFIFO_START_ADDR    at 16#100# range 0 .. 31;
      RXFIFO_START_ADDR    at 16#180# range 0 .. 31;
   end record;

   --  I2C (Inter-Integrated Circuit) Controller 0
   I2C0_Periph : aliased I2C_Peripheral
     with Import, Address => I2C0_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => True,
          Effective_Writes => True;

   --  I2C (Inter-Integrated Circuit) Controller 1
   I2C1_Periph : aliased I2C_Peripheral
     with Import, Address => I2C1_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => True,
          Effective_Writes => True;

end ESP32S3_Registers.I2C;
