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

package ESP32S3_Registers.SDHOST is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  Control register
   type CTRL_Register is record
      --  To reset controller, firmware should set this bit. This bit is
      --  auto-cleared after two AHB and two sdhost_cclk_in clock cycles.
      CONTROLLER_RESET              : Boolean := False;
      --  To reset FIFO, firmware should set bit to 1. This bit is auto-cleared
      --  after completion of reset operation. Note: FIFO pointers will be out
      --  of reset after 2 cycles of system clocks in addition to
      --  synchronization delay (2 cycles of card clock), after the fifo_reset
      --  is cleared.
      FIFO_RESET                    : Boolean := False;
      --  To reset DMA interface, firmware should set bit to 1. This bit is
      --  auto-cleared after two AHB clocks.
      DMA_RESET                     : Boolean := False;
      --  unspecified
      Reserved_3_3                  : ESP32S3_Registers.Bit := 16#0#;
      --  Global interrupt enable/disable bit. 0: Disable; 1: Enable.
      INT_ENABLE                    : Boolean := False;
      --  unspecified
      Reserved_5_5                  : ESP32S3_Registers.Bit := 16#0#;
      --  For sending read-wait to SDIO cards.
      READ_WAIT                     : Boolean := False;
      --  Bit automatically clears once response is sent. To wait for MMC card
      --  interrupts, host issues CMD40 and waits for interrupt response from
      --  MMC card(s). In the meantime, if host wants SD/MMC to exit waiting
      --  for interrupt state, it can set this bit, at which time SD/MMC
      --  command state-machine sends CMD40 response on bus and returns to idle
      --  state.
      SEND_IRQ_RESPONSE             : Boolean := False;
      --  After a suspend-command is issued during a read-operation, software
      --  polls the card to find when the suspend-event occurred. Once the
      --  suspend-event has occurred, software sets the bit which will reset
      --  the data state machine that is waiting for the next block of data.
      --  This bit is automatically cleared once the data state machine is
      --  reset to idle.
      ABORT_READ_DATA               : Boolean := False;
      --  When set, SD/MMC sends CCSD to the CE-ATA device. Software sets this
      --  bit only if the current command is expecting CCS (that is, RW_BLK),
      --  and if interrupts are enabled for the CE-ATA device. Once the CCSD
      --  pattern is sent to the device, SD/MMC automatically clears the
      --  SDHOST_SEND_CCSD bit. It also sets the Command Done (CD) bit in the
      --  SDHOST_RINTSTS_REG register, and generates an interrupt for the host,
      --  in case the Command Done interrupt is not masked. NOTE: Once the
      --  SDHOST_SEND_CCSD bit is set, it takes two card clock cycles to drive
      --  the CCSD on the CMD line. Due to this, within the boundary conditions
      --  the CCSD may be sent to the CE-ATA device, even if the device has
      --  signalled CCS.
      SEND_CCSD                     : Boolean := False;
      --  Always Set SDHOST_SEND_AUTO_STOP_CCSD and SDHOST_SEND_CCSD bits
      --  together; SDHOST_SEND_AUTO_STOP_CCSD should not be set independently
      --  of send_ccsd. When set, SD/MMC automatically sends an
      --  internally-generated STOP command (CMD12) to the CE-ATA device. After
      --  sending this internally-generated STOP command, the Auto Command Done
      --  (ACD) bit in SDHOST_RINTSTS_REG is set and an interrupt is generated
      --  for the host, in case the ACD interrupt is not masked. After sending
      --  the Command Completion Signal Disable (CCSD), SD/MMC automatically
      --  clears the SDHOST_SEND_AUTO_STOP_CCSD bit.
      SEND_AUTO_STOP_CCSD           : Boolean := False;
      --  Software should appropriately write to this bit after the power-on
      --  reset or any other reset to the CE-ATA device. After reset, the
      --  CE-ATA device's interrupt is usually disabled (nIEN = 1). If the host
      --  enables the CE-ATA device's interrupt, then software should set this
      --  bit.
      CEATA_DEVICE_INTERRUPT_STATUS : Boolean := False;
      --  unspecified
      Reserved_12_31                : ESP32S3_Registers.UInt20 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTRL_Register use record
      CONTROLLER_RESET              at 0 range 0 .. 0;
      FIFO_RESET                    at 0 range 1 .. 1;
      DMA_RESET                     at 0 range 2 .. 2;
      Reserved_3_3                  at 0 range 3 .. 3;
      INT_ENABLE                    at 0 range 4 .. 4;
      Reserved_5_5                  at 0 range 5 .. 5;
      READ_WAIT                     at 0 range 6 .. 6;
      SEND_IRQ_RESPONSE             at 0 range 7 .. 7;
      ABORT_READ_DATA               at 0 range 8 .. 8;
      SEND_CCSD                     at 0 range 9 .. 9;
      SEND_AUTO_STOP_CCSD           at 0 range 10 .. 10;
      CEATA_DEVICE_INTERRUPT_STATUS at 0 range 11 .. 11;
      Reserved_12_31                at 0 range 12 .. 31;
   end record;

   --  CLKDIV_CLK_DIVIDER array element
   subtype CLKDIV_CLK_DIVIDER_Element is ESP32S3_Registers.Byte;

   --  CLKDIV_CLK_DIVIDER array
   type CLKDIV_CLK_DIVIDER_Field_Array is array (0 .. 3)
     of CLKDIV_CLK_DIVIDER_Element
     with Component_Size => 8, Size => 32;

   --  Clock divider configuration register
   type CLKDIV_Register
     (As_Array : Boolean := False)
   is record
      case As_Array is
         when False =>
            --  CLK_DIVIDER as a value
            Val : ESP32S3_Registers.UInt32;
         when True =>
            --  CLK_DIVIDER as an array
            Arr : CLKDIV_CLK_DIVIDER_Field_Array;
      end case;
   end record
     with Unchecked_Union, Size => 32, Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLKDIV_Register use record
      Val at 0 range 0 .. 31;
      Arr at 0 range 0 .. 31;
   end record;

   subtype CLKSRC_CLKSRC_Field is ESP32S3_Registers.UInt4;

   --  Clock source selection register
   type CLKSRC_Register is record
      --  Clock divider source for two SD cards is supported. Each card has two
      --  bits assigned to it. For example, bit[1:0] are assigned for card 0,
      --  bit[3:2] are assigned for card 1. Card 0 maps and internally routes
      --  clock divider[0:3] outputs to cclk_out[1:0] pins, depending on bit
      --  value. 00 : Clock divider 0; 01 : Clock divider 1; 10 : Clock divider
      --  2; 11 : Clock divider 3.
      CLKSRC        : CLKSRC_CLKSRC_Field := 16#0#;
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLKSRC_Register use record
      CLKSRC        at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   subtype CLKENA_CCLK_ENABLE_Field is ESP32S3_Registers.UInt2;
   subtype CLKENA_LP_ENABLE_Field is ESP32S3_Registers.UInt2;

   --  Clock enable register
   type CLKENA_Register is record
      --  Clock-enable control for two SD card clocks and one MMC card clock is
      --  supported. One bit per card. 0: Clock disabled; 1: Clock enabled.
      CCLK_ENABLE    : CLKENA_CCLK_ENABLE_Field := 16#0#;
      --  unspecified
      Reserved_2_15  : ESP32S3_Registers.UInt14 := 16#0#;
      --  Disable clock when the card is in IDLE state. One bit per card. 0:
      --  clock disabled; 1: clock enabled.
      LP_ENABLE      : CLKENA_LP_ENABLE_Field := 16#0#;
      --  unspecified
      Reserved_18_31 : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLKENA_Register use record
      CCLK_ENABLE    at 0 range 0 .. 1;
      Reserved_2_15  at 0 range 2 .. 15;
      LP_ENABLE      at 0 range 16 .. 17;
      Reserved_18_31 at 0 range 18 .. 31;
   end record;

   subtype TMOUT_RESPONSE_TIMEOUT_Field is ESP32S3_Registers.Byte;
   subtype TMOUT_DATA_TIMEOUT_Field is ESP32S3_Registers.UInt24;

   --  Data and response timeout configuration register
   type TMOUT_Register is record
      --  Response timeout value. Value is specified in terms of number of card
      --  output clocks, i.e., sdhost_cclk_out.
      RESPONSE_TIMEOUT : TMOUT_RESPONSE_TIMEOUT_Field := 16#40#;
      --  Value for card data read timeout. This value is also used for data
      --  starvation by host timeout. The timeout counter is started only after
      --  the card clock is stopped. This value is specified in number of card
      --  output clocks, i.e. sdhost_cclk_out of the selected card. NOTE: The
      --  software timer should be used if the timeout value is in the order of
      --  100 ms. In this case, read data timeout interrupt needs to be
      --  disabled.
      DATA_TIMEOUT     : TMOUT_DATA_TIMEOUT_Field := 16#FFFFFF#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TMOUT_Register use record
      RESPONSE_TIMEOUT at 0 range 0 .. 7;
      DATA_TIMEOUT     at 0 range 8 .. 31;
   end record;

   subtype CTYPE_CARD_WIDTH4_Field is ESP32S3_Registers.UInt2;
   subtype CTYPE_CARD_WIDTH8_Field is ESP32S3_Registers.UInt2;

   --  Card bus width configuration register
   type CTYPE_Register is record
      --  One bit per card indicates if card is 1-bit or 4-bit mode. 0: 1-bit
      --  mode; 1: 4-bit mode. Bit[1:0] correspond to card[1:0] respectively.
      CARD_WIDTH4    : CTYPE_CARD_WIDTH4_Field := 16#0#;
      --  unspecified
      Reserved_2_15  : ESP32S3_Registers.UInt14 := 16#0#;
      --  One bit per card indicates if card is in 8-bit mode. 0: Non 8-bit
      --  mode; 1: 8-bit mode. Bit[17:16] correspond to card[1:0] respectively.
      CARD_WIDTH8    : CTYPE_CARD_WIDTH8_Field := 16#0#;
      --  unspecified
      Reserved_18_31 : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CTYPE_Register use record
      CARD_WIDTH4    at 0 range 0 .. 1;
      Reserved_2_15  at 0 range 2 .. 15;
      CARD_WIDTH8    at 0 range 16 .. 17;
      Reserved_18_31 at 0 range 18 .. 31;
   end record;

   subtype BLKSIZ_BLOCK_SIZE_Field is ESP32S3_Registers.UInt16;

   --  Card data block size configuration register
   type BLKSIZ_Register is record
      --  Block size.
      BLOCK_SIZE     : BLKSIZ_BLOCK_SIZE_Field := 16#200#;
      --  unspecified
      Reserved_16_31 : ESP32S3_Registers.UInt16 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BLKSIZ_Register use record
      BLOCK_SIZE     at 0 range 0 .. 15;
      Reserved_16_31 at 0 range 16 .. 31;
   end record;

   subtype INTMASK_INT_MASK_Field is ESP32S3_Registers.UInt16;
   subtype INTMASK_SDIO_INT_MASK_Field is ESP32S3_Registers.UInt2;

   --  SDIO interrupt mask register
   type INTMASK_Register is record
      --  These bits used to mask unwanted interrupts. A value of 0 masks
      --  interrupt, and a value of 1 enables the interrupt. Bit 15 (EBE):
      --  End-bit error/no CRC error; Bit 14 (ACD): Auto command done; Bit 13
      --  (SBE/BCI): Rx Start Bit Error; Bit 12 (HLE): Hardware locked write
      --  error; Bit 11 (FRUN): FIFO underrun/overrun error; Bit 10 (HTO): Data
      --  starvation-by-host timeout; Bit 9 (DRTO): Data read timeout; Bit 8
      --  (RTO): Response timeout; Bit 7 (DCRC): Data CRC error; Bit 6 (RCRC):
      --  Response CRC error; Bit 5 (RXDR): Receive FIFO data request; Bit 4
      --  (TXDR): Transmit FIFO data request; Bit 3 (DTO): Data transfer over;
      --  Bit 2 (CD): Command done; Bit 1 (RE): Response error; Bit 0 (CD):
      --  Card detect.
      INT_MASK       : INTMASK_INT_MASK_Field := 16#0#;
      --  SDIO interrupt mask, one bit for each card. Bit[17:16] correspond to
      --  card[15:0] respectively. When masked, SDIO interrupt detection for
      --  that card is disabled. 0 masks an interrupt, and 1 enables an
      --  interrupt.
      SDIO_INT_MASK  : INTMASK_SDIO_INT_MASK_Field := 16#0#;
      --  unspecified
      Reserved_18_31 : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for INTMASK_Register use record
      INT_MASK       at 0 range 0 .. 15;
      SDIO_INT_MASK  at 0 range 16 .. 17;
      Reserved_18_31 at 0 range 18 .. 31;
   end record;

   subtype CMD_INDEX_Field is ESP32S3_Registers.UInt6;
   subtype CMD_CARD_NUMBER_Field is ESP32S3_Registers.UInt5;

   --  Command and boot configuration register
   type CMD_Register is record
      --  Command index.
      INDEX                       : CMD_INDEX_Field := 16#0#;
      --  0: No response expected from card; 1: Response expected from card.
      RESPONSE_EXPECT             : Boolean := False;
      --  0: Short response expected from card; 1: Long response expected from
      --  card.
      RESPONSE_LENGTH             : Boolean := False;
      --  0: Do not check; 1: Check response CRC. Some of command responses do
      --  not return valid CRC bits. Software should disable CRC checks for
      --  those commands in order to disable CRC checking by controller.
      CHECK_RESPONSE_CRC          : Boolean := False;
      --  0: No data transfer expected; 1: Data transfer expected.
      DATA_EXPECTED               : Boolean := False;
      --  0: Read from card; 1: Write to card. Don't care if no data is
      --  expected from card.
      READ_WRITE                  : Boolean := False;
      --  0: Block data transfer command; 1: Stream data transfer command.
      --  Don't care if no data expected.
      TRANSFER_MODE               : Boolean := False;
      --  0: No stop command is sent at the end of data transfer; 1: Send stop
      --  command at the end of data transfer.
      SEND_AUTO_STOP              : Boolean := False;
      --  0: Send command at once, even if previous data transfer has not
      --  completed; 1: Wait for previous data transfer to complete before
      --  sending Command. The SDHOST_WAIT_PRVDATA_COMPLETE] = 0 option is
      --  typically used to query status of card during data transfer or to
      --  stop current data transfer. SDHOST_CARD_NUMBERr should be same as in
      --  previous command.
      WAIT_PRVDATA_COMPLETE       : Boolean := False;
      --  0: Neither stop nor abort command can stop current data transfer. If
      --  abort is sent to function-number currently selected or not in
      --  data-transfer mode, then bit should be set to 0; 1: Stop or abort
      --  command intended to stop current data transfer in progress. When
      --  open-ended or predefined data transfer is in progress, and host
      --  issues stop or abort command to stop data transfer, bit should be set
      --  so that command/data state-machines of CIU can return correctly to
      --  idle state.
      STOP_ABORT_CMD              : Boolean := False;
      --  0: Do not send initialization sequence (80 clocks of 1) before
      --  sending this command; 1: Send initialization sequence before sending
      --  this command. After powered on, 80 clocks must be sent to card for
      --  initialization before sending any commands to card. Bit should be set
      --  while sending first command to card so that controller will
      --  initialize clocks before sending command to card.
      SEND_INITIALIZATION         : Boolean := False;
      --  Card number in use. Represents physical slot number of card being
      --  accessed. In SD-only mode, up to two cards are supported.
      CARD_NUMBER                 : CMD_CARD_NUMBER_Field := 16#0#;
      --  0: Normal command sequence; 1: Do not send commands, just update
      --  clock register value into card clock domain. Following register
      --  values are transferred into card clock domain: CLKDIV, CLRSRC, and
      --  CLKENA. Changes card clocks (change frequency, truncate off or on,
      --  and set low-frequency mode). This is provided in order to change
      --  clock frequency or stop clock without having to send command to
      --  cards. During normal command sequence, when
      --  sdhost_update_clock_registers_only = 0, following control registers
      --  are transferred from BIU to CIU: CMD, CMDARG, TMOUT, CTYPE, BLKSIZ,
      --  and BYTCNT. CIU uses new register values for new command sequence to
      --  card(s). When bit is set, there are no Command Done interrupts
      --  because no command is sent to SD_MMC_CEATA cards.
      UPDATE_CLOCK_REGISTERS_ONLY : Boolean := False;
      --  Read access flag. 0: Host is not performing read access (RW_REG or
      --  RW_BLK)towards CE-ATA device; 1: Host is performing read access
      --  (RW_REG or RW_BLK) towards CE-ATA device. Software should set this
      --  bit to indicate that CE-ATA device is being accessed for read
      --  transfer. This bit is used to disable read data timeout indication
      --  while performing CE-ATA read transfers. Maximum value of I/O
      --  transmission delay can be no less than 10 seconds. SD/MMC should not
      --  indicate read data timeout while waiting for data from CE-ATA device.
      READ_CEATA_DEVICE           : Boolean := False;
      --  Expected Command Completion Signal (CCS) configuration. 0: Interrupts
      --  are not enabled in CE-ATA device (nIEN = 1 in ATA control register),
      --  or command does not expect CCS from device; 1: Interrupts are enabled
      --  in CE-ATA device (nIEN = 0), and RW_BLK command expects command
      --  completion signal from CE-ATA device. If the command expects Command
      --  Completion Signal (CCS) from the CE-ATA device, the software should
      --  set this control bit. SD/MMC sets Data Transfer Over (DTO) bit in
      --  RINTSTS register and generates interrupt to host if Data Transfer
      --  Over interrupt is not masked.
      CCS_EXPECTED                : Boolean := False;
      --  unspecified
      Reserved_24_28              : ESP32S3_Registers.UInt5 := 16#0#;
      --  Use Hold Register. 0: CMD and DATA sent to card bypassing HOLD
      --  Register; 1: CMD and DATA sent to card through the HOLD Register.
      USE_HOLE                    : Boolean := True;
      --  unspecified
      Reserved_30_30              : ESP32S3_Registers.Bit := 16#0#;
      --  Start command. Once command is served by the CIU, this bit is
      --  automatically cleared. When this bit is set, host should not attempt
      --  to write to any command registers. If a write is attempted, hardware
      --  lock error is set in raw interrupt register. Once command is sent and
      --  a response is received from SD_MMC_CEATA cards, Command Done bit is
      --  set in the raw interrupt Register.
      START_CMD                   : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CMD_Register use record
      INDEX                       at 0 range 0 .. 5;
      RESPONSE_EXPECT             at 0 range 6 .. 6;
      RESPONSE_LENGTH             at 0 range 7 .. 7;
      CHECK_RESPONSE_CRC          at 0 range 8 .. 8;
      DATA_EXPECTED               at 0 range 9 .. 9;
      READ_WRITE                  at 0 range 10 .. 10;
      TRANSFER_MODE               at 0 range 11 .. 11;
      SEND_AUTO_STOP              at 0 range 12 .. 12;
      WAIT_PRVDATA_COMPLETE       at 0 range 13 .. 13;
      STOP_ABORT_CMD              at 0 range 14 .. 14;
      SEND_INITIALIZATION         at 0 range 15 .. 15;
      CARD_NUMBER                 at 0 range 16 .. 20;
      UPDATE_CLOCK_REGISTERS_ONLY at 0 range 21 .. 21;
      READ_CEATA_DEVICE           at 0 range 22 .. 22;
      CCS_EXPECTED                at 0 range 23 .. 23;
      Reserved_24_28              at 0 range 24 .. 28;
      USE_HOLE                    at 0 range 29 .. 29;
      Reserved_30_30              at 0 range 30 .. 30;
      START_CMD                   at 0 range 31 .. 31;
   end record;

   subtype MINTSTS_INT_STATUS_MSK_Field is ESP32S3_Registers.UInt16;
   subtype MINTSTS_SDIO_INTERRUPT_MSK_Field is ESP32S3_Registers.UInt2;

   --  Masked interrupt status register
   type MINTSTS_Register is record
      --  Read-only. Interrupt enabled only if corresponding bit in interrupt
      --  mask register is set. Bit 15 (EBE): End-bit error/no CRC error; Bit
      --  14 (ACD): Auto command done; Bit 13 (SBE/BCI): RX Start Bit Error;
      --  Bit 12 (HLE): Hardware locked write error; Bit 11 (FRUN): FIFO
      --  underrun/overrun error; Bit 10 (HTO): Data starvation by host timeout
      --  (HTO); Bit 9 (DTRO): Data read timeout; Bit 8 (RTO): Response
      --  timeout; Bit 7 (DCRC): Data CRC error; Bit 6 (RCRC): Response CRC
      --  error; Bit 5 (RXDR): Receive FIFO data request; Bit 4 (TXDR):
      --  Transmit FIFO data request; Bit 3 (DTO): Data transfer over; Bit 2
      --  (CD): Command done; Bit 1 (RE): Response error; Bit 0 (CD): Card
      --  detect.
      INT_STATUS_MSK     : MINTSTS_INT_STATUS_MSK_Field;
      --  Read-only. Interrupt from SDIO card, one bit for each card.
      --  Bit[17:16] correspond to card1 and card0, respectively. SDIO
      --  interrupt for card is enabled only if corresponding
      --  sdhost_sdio_int_mask bit is set in Interrupt mask register (Setting
      --  mask bit enables interrupt).
      SDIO_INTERRUPT_MSK : MINTSTS_SDIO_INTERRUPT_MSK_Field;
      --  unspecified
      Reserved_18_31     : ESP32S3_Registers.UInt14;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for MINTSTS_Register use record
      INT_STATUS_MSK     at 0 range 0 .. 15;
      SDIO_INTERRUPT_MSK at 0 range 16 .. 17;
      Reserved_18_31     at 0 range 18 .. 31;
   end record;

   subtype RINTSTS_INT_STATUS_RAW_Field is ESP32S3_Registers.UInt16;
   subtype RINTSTS_SDIO_INTERRUPT_RAW_Field is ESP32S3_Registers.UInt2;

   --  Raw interrupt status register
   type RINTSTS_Register is record
      --  Setting a bit clears the corresponding interrupt and writing 0 has no
      --  effect. Bits are logged regardless of interrupt mask status. Bit 15
      --  (EBE): End-bit error/no CRC error; Bit 14 (ACD): Auto command done;
      --  Bit 13 (SBE/BCI): RX Start Bit Error; Bit 12 (HLE): Hardware locked
      --  write error; Bit 11 (FRUN): FIFO underrun/overrun error; Bit 10
      --  (HTO): Data starvation by host timeout (HTO); Bit 9 (DTRO): Data read
      --  timeout; Bit 8 (RTO): Response timeout; Bit 7 (DCRC): Data CRC error;
      --  Bit 6 (RCRC): Response CRC error; Bit 5 (RXDR): Receive FIFO data
      --  request; Bit 4 (TXDR): Transmit FIFO data request; Bit 3 (DTO): Data
      --  transfer over; Bit 2 (CD): Command done; Bit 1 (RE): Response error;
      --  Bit 0 (CD): Card detect.
      INT_STATUS_RAW     : RINTSTS_INT_STATUS_RAW_Field := 16#0#;
      --  Interrupt from SDIO card, one bit for each card. Bit[17:16]
      --  correspond to card1 and card0, respectively. Setting a bit clears the
      --  corresponding interrupt bit and writing 0 has no effect. 0: No SDIO
      --  interrupt from card; 1: SDIO interrupt from card.
      SDIO_INTERRUPT_RAW : RINTSTS_SDIO_INTERRUPT_RAW_Field := 16#0#;
      --  unspecified
      Reserved_18_31     : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RINTSTS_Register use record
      INT_STATUS_RAW     at 0 range 0 .. 15;
      SDIO_INTERRUPT_RAW at 0 range 16 .. 17;
      Reserved_18_31     at 0 range 18 .. 31;
   end record;

   subtype STATUS_COMMAND_FSM_STATES_Field is ESP32S3_Registers.UInt4;
   subtype STATUS_RESPONSE_INDEX_Field is ESP32S3_Registers.UInt6;
   subtype STATUS_FIFO_COUNT_Field is ESP32S3_Registers.UInt13;

   --  SD/MMC status register
   type STATUS_Register is record
      --  Read-only. FIFO reached Receive watermark level, not qualified with
      --  data transfer.
      FIFO_RX_WATERMARK  : Boolean;
      --  Read-only. FIFO reached Transmit watermark level, not qualified with
      --  data transfer.
      FIFO_TX_WATERMARK  : Boolean;
      --  Read-only. FIFO is empty status.
      FIFO_EMPTY         : Boolean;
      --  Read-only. FIFO is full status.
      FIFO_FULL          : Boolean;
      --  Read-only. Command FSM states. 0: Idle; 1: Send init sequence; 2:
      --  Send cmd start bit; 3: Send cmd tx bit; 4: Send cmd index + arg; 5:
      --  Send cmd crc7; 6: Send cmd end bit; 7: Receive resp start bit; 8:
      --  Receive resp IRQ response; 9: Receive resp tx bit; 10: Receive resp
      --  cmd idx; 11: Receive resp data; 12: Receive resp crc7; 13: Receive
      --  resp end bit; 14: Cmd path wait NCC; 15: Wait, cmd-to-response
      --  turnaround.
      COMMAND_FSM_STATES : STATUS_COMMAND_FSM_STATES_Field;
      --  Read-only. Raw selected sdhost_card_data[3], checks whether card is
      --  present. 0: card not present; 1: card present.
      DATA_3_STATUS      : Boolean;
      --  Read-only. Inverted version of raw selected sdhost_card_data[0]. 0:
      --  Card data not busy; 1: Card data busy.
      DATA_BUSY          : Boolean;
      --  Read-only. Data transmit or receive state-machine is busy.
      DATA_STATE_MC_BUSY : Boolean;
      --  Read-only. Index of previous response, including any auto-stop sent
      --  by core.
      RESPONSE_INDEX     : STATUS_RESPONSE_INDEX_Field;
      --  Read-only. FIFO count, number of filled locations in FIFO.
      FIFO_COUNT         : STATUS_FIFO_COUNT_Field;
      --  unspecified
      Reserved_30_31     : ESP32S3_Registers.UInt2;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for STATUS_Register use record
      FIFO_RX_WATERMARK  at 0 range 0 .. 0;
      FIFO_TX_WATERMARK  at 0 range 1 .. 1;
      FIFO_EMPTY         at 0 range 2 .. 2;
      FIFO_FULL          at 0 range 3 .. 3;
      COMMAND_FSM_STATES at 0 range 4 .. 7;
      DATA_3_STATUS      at 0 range 8 .. 8;
      DATA_BUSY          at 0 range 9 .. 9;
      DATA_STATE_MC_BUSY at 0 range 10 .. 10;
      RESPONSE_INDEX     at 0 range 11 .. 16;
      FIFO_COUNT         at 0 range 17 .. 29;
      Reserved_30_31     at 0 range 30 .. 31;
   end record;

   subtype FIFOTH_TX_WMARK_Field is ESP32S3_Registers.UInt12;
   subtype FIFOTH_RX_WMARK_Field is ESP32S3_Registers.UInt11;
   subtype FIFOTH_DMA_MULTIPLE_TRANSACTION_SIZE_Field is
     ESP32S3_Registers.UInt3;

   --  FIFO configuration register
   type FIFOTH_Register is record
      --  FIFO threshold watermark level when transmitting data to card. When
      --  FIFO data count is less than or equal to this number, DMA/FIFO
      --  request is raised. If Interrupt is enabled, then interrupt occurs.
      --  During end of packet, request or interrupt is generated, regardless
      --  of threshold programming.In non-DMA mode, when transmit FIFO
      --  threshold (TXDR) interrupt is enabled, then interrupt is generated
      --  instead of DMA request. During end of packet, on last interrupt, host
      --  is responsible for filling FIFO with only required remaining bytes
      --  (not before FIFO is full or after CIU completes data transfers,
      --  because FIFO may not be empty). In DMA mode, at end of packet, if
      --  last transfer is less than burst size, DMA controller does single
      --  cycles until required bytes are transferred.
      TX_WMARK                      : FIFOTH_TX_WMARK_Field := 16#0#;
      --  unspecified
      Reserved_12_15                : ESP32S3_Registers.UInt4 := 16#0#;
      --  FIFO threshold watermark level when receiving data to card.When FIFO
      --  data count reaches greater than this number , DMA/FIFO request is
      --  raised. During end of packet, request is generated regardless of
      --  threshold programming in order to complete any remaining data.In
      --  non-DMA mode, when receiver FIFO threshold (RXDR) interrupt is
      --  enabled, then interrupt is generated instead of DMA request.During
      --  end of packet, interrupt is not generated if threshold programming is
      --  larger than any remaining data. It is responsibility of host to read
      --  remaining bytes on seeing Data Transfer Done interrupt.In DMA mode,
      --  at end of packet, even if remaining bytes are less than threshold,
      --  DMA request does single transfers to flush out any remaining bytes
      --  before Data Transfer Done interrupt is set.
      RX_WMARK                      : FIFOTH_RX_WMARK_Field := 16#0#;
      --  unspecified
      Reserved_27_27                : ESP32S3_Registers.Bit := 16#0#;
      --  Burst size of multiple transaction, should be programmed same as DMA
      --  controller multiple-transaction-size SDHOST_SRC/DEST_MSIZE. 000:
      --  1-byte transfer; 001: 4-byte transfer; 010: 8-byte transfer; 011:
      --  16-byte transfer; 100: 32-byte transfer; 101: 64-byte transfer; 110:
      --  128-byte transfer; 111: 256-byte transfer.
      DMA_MULTIPLE_TRANSACTION_SIZE : FIFOTH_DMA_MULTIPLE_TRANSACTION_SIZE_Field :=
                                       16#0#;
      --  unspecified
      Reserved_31_31                : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for FIFOTH_Register use record
      TX_WMARK                      at 0 range 0 .. 11;
      Reserved_12_15                at 0 range 12 .. 15;
      RX_WMARK                      at 0 range 16 .. 26;
      Reserved_27_27                at 0 range 27 .. 27;
      DMA_MULTIPLE_TRANSACTION_SIZE at 0 range 28 .. 30;
      Reserved_31_31                at 0 range 31 .. 31;
   end record;

   subtype CDETECT_CARD_DETECT_N_Field is ESP32S3_Registers.UInt2;

   --  Card detect register
   type CDETECT_Register is record
      --  Read-only. Value on sdhost_card_detect_n input ports (1 bit per
      --  card), read-only bits. 0 represents presence of card. Only NUM_CARDS
      --  number of bits are implemented.
      CARD_DETECT_N : CDETECT_CARD_DETECT_N_Field;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CDETECT_Register use record
      CARD_DETECT_N at 0 range 0 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype WRTPRT_WRITE_PROTECT_Field is ESP32S3_Registers.UInt2;

   --  Card write protection (WP) status register
   type WRTPRT_Register is record
      --  Read-only. Value on sdhost_card_write_prt input ports (1 bit per
      --  card). 1 represents write protection. Only NUM_CARDS number of bits
      --  are implemented.
      WRITE_PROTECT : WRTPRT_WRITE_PROTECT_Field;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for WRTPRT_Register use record
      WRITE_PROTECT at 0 range 0 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype DEBNCE_DEBOUNCE_COUNT_Field is ESP32S3_Registers.UInt24;

   --  Debounce filter time configuration register
   type DEBNCE_Register is record
      --  Number of host clocks (clk) used by debounce filter logic. The
      --  typical debounce time is 5 \verb+~+ 25 ms to prevent the card
      --  instability when the card is inserted or removed.
      DEBOUNCE_COUNT : DEBNCE_DEBOUNCE_COUNT_Field := 16#0#;
      --  unspecified
      Reserved_24_31 : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for DEBNCE_Register use record
      DEBOUNCE_COUNT at 0 range 0 .. 23;
      Reserved_24_31 at 0 range 24 .. 31;
   end record;

   subtype HCON_CARD_NUM_Field is ESP32S3_Registers.UInt5;
   subtype HCON_DATA_WIDTH_Field is ESP32S3_Registers.UInt3;
   subtype HCON_ADDR_WIDTH_Field is ESP32S3_Registers.UInt6;
   subtype HCON_DMA_WIDTH_Field is ESP32S3_Registers.UInt3;
   subtype HCON_NUM_CLK_DIV_Field is ESP32S3_Registers.UInt2;

   --  Hardware feature register
   type HCON_Register is record
      --  Read-only. Hardware support SDIO and MMC.
      CARD_TYPE      : Boolean;
      --  Read-only. Support card number is 2.
      CARD_NUM       : HCON_CARD_NUM_Field;
      --  Read-only. Register config is APB bus.
      BUS_TYPE       : Boolean;
      --  Read-only. Regisger data widht is 32.
      DATA_WIDTH     : HCON_DATA_WIDTH_Field;
      --  Read-only. Register address width is 32.
      ADDR_WIDTH     : HCON_ADDR_WIDTH_Field;
      --  unspecified
      Reserved_16_17 : ESP32S3_Registers.UInt2;
      --  Read-only. DMA data witdth is 32.
      DMA_WIDTH      : HCON_DMA_WIDTH_Field;
      --  Read-only. Inside RAM in SDMMC module.
      RAM_INDISE     : Boolean;
      --  Read-only. Have a hold regiser in data path .
      HOLD           : Boolean;
      --  unspecified
      Reserved_23_23 : ESP32S3_Registers.Bit;
      --  Read-only. Have 4 clk divider in design .
      NUM_CLK_DIV    : HCON_NUM_CLK_DIV_Field;
      --  unspecified
      Reserved_26_31 : ESP32S3_Registers.UInt6;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for HCON_Register use record
      CARD_TYPE      at 0 range 0 .. 0;
      CARD_NUM       at 0 range 1 .. 5;
      BUS_TYPE       at 0 range 6 .. 6;
      DATA_WIDTH     at 0 range 7 .. 9;
      ADDR_WIDTH     at 0 range 10 .. 15;
      Reserved_16_17 at 0 range 16 .. 17;
      DMA_WIDTH      at 0 range 18 .. 20;
      RAM_INDISE     at 0 range 21 .. 21;
      HOLD           at 0 range 22 .. 22;
      Reserved_23_23 at 0 range 23 .. 23;
      NUM_CLK_DIV    at 0 range 24 .. 25;
      Reserved_26_31 at 0 range 26 .. 31;
   end record;

   subtype UHS_DDR_Field is ESP32S3_Registers.UInt2;

   --  UHS-1 register
   type UHS_Register is record
      --  unspecified
      Reserved_0_15  : ESP32S3_Registers.UInt16 := 16#0#;
      --  DDR mode selecton,1 bit for each card. 0-Non-DDR mdoe. 1-DDR mdoe.
      DDR            : UHS_DDR_Field := 16#0#;
      --  unspecified
      Reserved_18_31 : ESP32S3_Registers.UInt14 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for UHS_Register use record
      Reserved_0_15  at 0 range 0 .. 15;
      DDR            at 0 range 16 .. 17;
      Reserved_18_31 at 0 range 18 .. 31;
   end record;

   subtype RST_N_CARD_RESET_Field is ESP32S3_Registers.UInt2;

   --  Card reset register
   type RST_N_Register is record
      --  Hardware reset. 1: Active mode; 0: Reset. These bits cause the cards
      --  to enter pre-idle state, which requires them to be re-initialized.
      --  SDHOST_RST_CARD_RESET[0] should be set to 1'b0 to reset card0,
      --  SDHOST_RST_CARD_RESET[1] should be set to 1'b0 to reset card1.
      CARD_RESET    : RST_N_CARD_RESET_Field := 16#1#;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for RST_N_Register use record
      CARD_RESET    at 0 range 0 .. 1;
      Reserved_2_31 at 0 range 2 .. 31;
   end record;

   subtype BMOD_PBL_Field is ESP32S3_Registers.UInt3;

   --  Burst mode transfer configuration register
   type BMOD_Register is record
      --  Software Reset. When set, the DMA Controller resets all its internal
      --  registers. It is automatically cleared after one clock cycle.
      SWR            : Boolean := False;
      --  Fixed Burst. Controls whether the AHB Master interface performs fixed
      --  burst transfers or not. When set, the AHB will use only SINGLE,
      --  INCR4, INCR8 or INCR16 during start of normal burst transfers. When
      --  reset, the AHB will use SINGLE and INCR burst transfer operations.
      FB             : Boolean := False;
      --  unspecified
      Reserved_2_6   : ESP32S3_Registers.UInt5 := 16#0#;
      --  IDMAC Enable. When set, the IDMAC is enabled.
      DE             : Boolean := False;
      --  Programmable Burst Length. These bits indicate the maximum number of
      --  beats to be performed in one IDMAC???Internal DMA
      --  Control???transaction. The IDMAC will always attempt to burst as
      --  specified in PBL each time it starts a burst transfer on the host
      --  bus. The permissible values are 1, 4, 8, 16, 32, 64, 128 and 256.
      --  This value is the mirror of MSIZE of FIFOTH register. In order to
      --  change this value, write the required value to FIFOTH register. This
      --  is an encode value as follows: 000: 1-byte transfer; 001: 4-byte
      --  transfer; 010: 8-byte transfer; 011: 16-byte transfer; 100: 32-byte
      --  transfer; 101: 64-byte transfer; 110: 128-byte transfer; 111:
      --  256-byte transfer. PBL is a read-only value and is applicable only
      --  for data access, it does not apply to descriptor access.
      PBL            : BMOD_PBL_Field := 16#0#;
      --  unspecified
      Reserved_11_31 : ESP32S3_Registers.UInt21 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for BMOD_Register use record
      SWR            at 0 range 0 .. 0;
      FB             at 0 range 1 .. 1;
      Reserved_2_6   at 0 range 2 .. 6;
      DE             at 0 range 7 .. 7;
      PBL            at 0 range 8 .. 10;
      Reserved_11_31 at 0 range 11 .. 31;
   end record;

   subtype IDSTS_FBE_CODE_Field is ESP32S3_Registers.UInt3;
   subtype IDSTS_FSM_Field is ESP32S3_Registers.UInt4;

   --  IDMAC status register
   type IDSTS_Register is record
      --  Transmit Interrupt. Indicates that data transmission is finished for
      --  a descriptor. Writing 1 clears this bit.
      TI             : Boolean := False;
      --  Receive Interrupt. Indicates the completion of data reception for a
      --  descriptor. Writing 1 clears this bit.
      RI             : Boolean := False;
      --  Fatal Bus Error Interrupt. Indicates that a Bus Error occurred
      --  (IDSTS[12:10]) . When this bit is set, the DMA disables all its bus
      --  accesses. Writing 1 clears this bit.
      FBE            : Boolean := False;
      --  unspecified
      Reserved_3_3   : ESP32S3_Registers.Bit := 16#0#;
      --  Descriptor Unavailable Interrupt. This bit is set when the descriptor
      --  is unavailable due to OWNER bit = 0 (DES0[31] = 0). Writing 1 clears
      --  this bit.
      DU             : Boolean := False;
      --  Card Error Summary. Indicates the status of the transaction to/from
      --  the card, also present in RINTSTS. Indicates the logical OR of the
      --  following bits: EBE : End Bit Error; RTO : Response Timeout/Boot Ack
      --  Timeout; RCRC : Response CRC; SBE : Start Bit Error; DRTO : Data Read
      --  Timeout/BDS timeout; DCRC : Data CRC for Receive; RE : Response
      --  Error. Writing 1 clears this bit. The abort condition of the IDMAC
      --  depends on the setting of this CES bit. If the CES bit is enabled,
      --  then the IDMAC aborts on a response error.
      CES            : Boolean := False;
      --  unspecified
      Reserved_6_7   : ESP32S3_Registers.UInt2 := 16#0#;
      --  Normal Interrupt Summary. Logical OR of the following: IDSTS[0] :
      --  Transmit Interrupt, IDSTS[1] : Receive Interrupt. Only unmasked bits
      --  affect this bit. This is a sticky bit and must be cleared each time a
      --  corresponding bit that causes NIS to be set is cleared. Writing 1
      --  clears this bit.
      NIS            : Boolean := False;
      --  Abnormal Interrupt Summary. Logical OR of the following: IDSTS[2] :
      --  Fatal Bus Interrupt, IDSTS[4] : DU bit Interrupt. Only unmasked bits
      --  affect this bit. This is a sticky bit and must be cleared each time a
      --  corresponding bit that causes AIS to be set is cleared. Writing 1
      --  clears this bit.
      AIS            : Boolean := False;
      --  Fatal Bus Error Code. Indicates the type of error that caused a Bus
      --  Error. Valid only when the Fatal Bus Error bit IDSTS[2] is set. This
      --  field does not generate an interrupt. 001: Host Abort received during
      --  transmission; 010: Host Abort received during reception; Others:
      --  Reserved.
      FBE_CODE       : IDSTS_FBE_CODE_Field := 16#0#;
      --  DMAC FSM present state. 0: DMA_IDLE (idle state); 1: DMA_SUSPEND
      --  (suspend state); 2: DESC_RD (descriptor reading state); 3: DESC_CHK
      --  (descriptor checking state); 4: DMA_RD_REQ_WAIT (read-data request
      --  waiting state); 5: DMA_WR_REQ_WAIT (write-data request waiting
      --  state); 6: DMA_RD (data-read state); 7: DMA_WR (data-write state); 8:
      --  DESC_CLOSE (descriptor close state).
      FSM            : IDSTS_FSM_Field := 16#0#;
      --  unspecified
      Reserved_17_31 : ESP32S3_Registers.UInt15 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for IDSTS_Register use record
      TI             at 0 range 0 .. 0;
      RI             at 0 range 1 .. 1;
      FBE            at 0 range 2 .. 2;
      Reserved_3_3   at 0 range 3 .. 3;
      DU             at 0 range 4 .. 4;
      CES            at 0 range 5 .. 5;
      Reserved_6_7   at 0 range 6 .. 7;
      NIS            at 0 range 8 .. 8;
      AIS            at 0 range 9 .. 9;
      FBE_CODE       at 0 range 10 .. 12;
      FSM            at 0 range 13 .. 16;
      Reserved_17_31 at 0 range 17 .. 31;
   end record;

   --  IDMAC interrupt enable register
   type IDINTEN_Register is record
      --  Transmit Interrupt Enable. When set with Normal Interrupt Summary
      --  Enable, Transmit Interrupt is enabled. When reset, Transmit Interrupt
      --  is disabled.
      TI             : Boolean := False;
      --  Receive Interrupt Enable. When set with Normal Interrupt Summary
      --  Enable, Receive Interrupt is enabled. When reset, Receive Interrupt
      --  is disabled.
      RI             : Boolean := False;
      --  Fatal Bus Error Enable. When set with Abnormal Interrupt Summary
      --  Enable, the Fatal Bus Error Interrupt is enabled. When reset, Fatal
      --  Bus Error Enable Interrupt is disabled.
      FBE            : Boolean := False;
      --  unspecified
      Reserved_3_3   : ESP32S3_Registers.Bit := 16#0#;
      --  Descriptor Unavailable Interrupt. When set along with Abnormal
      --  Interrupt Summary Enable, the DU interrupt is enabled.
      DU             : Boolean := False;
      --  Card Error summary Interrupt Enable. When set, it enables the Card
      --  Interrupt summary.
      CES            : Boolean := False;
      --  unspecified
      Reserved_6_7   : ESP32S3_Registers.UInt2 := 16#0#;
      --  Normal Interrupt Summary Enable. When set, a normal interrupt is
      --  enabled. When reset, a normal interrupt is disabled. This bit enables
      --  the following bits: IDINTEN[0]: Transmit Interrupt; IDINTEN[1]:
      --  Receive Interrupt.
      NI             : Boolean := False;
      --  Abnormal Interrupt Summary Enable. When set, an abnormal interrupt is
      --  enabled. This bit enables the following bits: IDINTEN[2]: Fatal Bus
      --  Error Interrupt; IDINTEN[4]: DU Interrupt.
      AI             : Boolean := False;
      --  unspecified
      Reserved_10_31 : ESP32S3_Registers.UInt22 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for IDINTEN_Register use record
      TI             at 0 range 0 .. 0;
      RI             at 0 range 1 .. 1;
      FBE            at 0 range 2 .. 2;
      Reserved_3_3   at 0 range 3 .. 3;
      DU             at 0 range 4 .. 4;
      CES            at 0 range 5 .. 5;
      Reserved_6_7   at 0 range 6 .. 7;
      NI             at 0 range 8 .. 8;
      AI             at 0 range 9 .. 9;
      Reserved_10_31 at 0 range 10 .. 31;
   end record;

   subtype CARDTHRCTL_CARDTHRESHOLD_Field is ESP32S3_Registers.UInt16;

   --  Card Threshold Control register
   type CARDTHRCTL_Register is record
      --  Card read threshold enable. 1'b0-Card read threshold disabled.
      --  1'b1-Card read threshold enabled.
      CARDRDTHREN   : Boolean := False;
      --  Busy clear interrupt generation: 1'b0-Busy clear interrypt disabled.
      --  1'b1-Busy clear interrypt enabled.
      CARDCLRINTEN  : Boolean := False;
      --  Applicable when HS400 mode is enabled. 1'b0-Card write Threshold
      --  disabled. 1'b1-Card write Threshold enabled.
      CARDWRTHREN   : Boolean := False;
      --  unspecified
      Reserved_3_15 : ESP32S3_Registers.UInt13 := 16#0#;
      --  The inside FIFO size is 512,This register is applicable when
      --  SDHOST_CARDERTHREN_REG is set to 1 or SDHOST_CARDRDTHREN_REG set to
      --  1.
      CARDTHRESHOLD : CARDTHRCTL_CARDTHRESHOLD_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CARDTHRCTL_Register use record
      CARDRDTHREN   at 0 range 0 .. 0;
      CARDCLRINTEN  at 0 range 1 .. 1;
      CARDWRTHREN   at 0 range 2 .. 2;
      Reserved_3_15 at 0 range 3 .. 15;
      CARDTHRESHOLD at 0 range 16 .. 31;
   end record;

   subtype EMMCDDR_HALFSTARTBIT_Field is ESP32S3_Registers.UInt2;

   --  eMMC DDR register
   type EMMCDDR_Register is record
      --  Control for start bit detection mechanism duration of start bit.Each
      --  bit refers to one slot.Set this bit to 1 for eMMC4.5 and above,set to
      --  0 for SD applications.For eMMC4.5,start bit can be: 1'b0-Full cycle.
      --  1'b1-less than one full cycle.
      HALFSTARTBIT  : EMMCDDR_HALFSTARTBIT_Field := 16#0#;
      --  unspecified
      Reserved_2_30 : ESP32S3_Registers.UInt29 := 16#0#;
      --  Set 1 to enable HS400 mode.
      HS400_MODE    : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for EMMCDDR_Register use record
      HALFSTARTBIT  at 0 range 0 .. 1;
      Reserved_2_30 at 0 range 2 .. 30;
      HS400_MODE    at 0 range 31 .. 31;
   end record;

   subtype ENSHIFT_ENABLE_SHIFT_Field is ESP32S3_Registers.UInt4;

   --  Enable Phase Shift register
   type ENSHIFT_Register is record
      --  Control for the amount of phase shift provided on the default enables
      --  in the design.Two bits assigned for each card. 2'b00-Default phase
      --  shift. 2'b01-Enables shifted to next immediate positive edge.
      --  2'b10-Enables shifted to next immediate negative edge.
      --  2'b11-Reserved.
      ENABLE_SHIFT  : ENSHIFT_ENABLE_SHIFT_Field := 16#0#;
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for ENSHIFT_Register use record
      ENABLE_SHIFT  at 0 range 0 .. 3;
      Reserved_4_31 at 0 range 4 .. 31;
   end record;

   subtype CLK_EDGE_SEL_CCLKIN_EDGE_DRV_SEL_Field is ESP32S3_Registers.UInt3;
   subtype CLK_EDGE_SEL_CCLKIN_EDGE_SAM_SEL_Field is ESP32S3_Registers.UInt3;
   subtype CLK_EDGE_SEL_CCLKIN_EDGE_SLF_SEL_Field is ESP32S3_Registers.UInt3;
   subtype CLK_EDGE_SEL_CCLLKIN_EDGE_H_Field is ESP32S3_Registers.UInt4;
   subtype CLK_EDGE_SEL_CCLLKIN_EDGE_L_Field is ESP32S3_Registers.UInt4;
   subtype CLK_EDGE_SEL_CCLLKIN_EDGE_N_Field is ESP32S3_Registers.UInt4;

   --  SDIO control register.
   type CLK_EDGE_SEL_Register is record
      --  It's used to select the clock phase of the output signal from phase
      --  0, phase 90, phase 180, phase 270.
      CCLKIN_EDGE_DRV_SEL : CLK_EDGE_SEL_CCLKIN_EDGE_DRV_SEL_Field := 16#0#;
      --  It's used to select the clock phase of the input signal from phase 0,
      --  phase 90, phase 180, phase 270.
      CCLKIN_EDGE_SAM_SEL : CLK_EDGE_SEL_CCLKIN_EDGE_SAM_SEL_Field := 16#0#;
      --  It's used to select the clock phase of the internal signal from phase
      --  0, phase 90, phase 180, phase 270.
      CCLKIN_EDGE_SLF_SEL : CLK_EDGE_SEL_CCLKIN_EDGE_SLF_SEL_Field := 16#0#;
      --  The high level of the divider clock. The value should be smaller than
      --  CCLKIN_EDGE_L.
      CCLLKIN_EDGE_H      : CLK_EDGE_SEL_CCLLKIN_EDGE_H_Field := 16#1#;
      --  The low level of the divider clock. The value should be larger than
      --  CCLKIN_EDGE_H.
      CCLLKIN_EDGE_L      : CLK_EDGE_SEL_CCLLKIN_EDGE_L_Field := 16#0#;
      --  The clock division of cclk_in.
      CCLLKIN_EDGE_N      : CLK_EDGE_SEL_CCLLKIN_EDGE_N_Field := 16#1#;
      --  Enable esdio mode.
      ESDIO_MODE          : Boolean := False;
      --  Enable esd mode.
      ESD_MODE            : Boolean := False;
      --  Sdio clock enable.
      CCLK_EN             : Boolean := True;
      --  unspecified
      Reserved_24_31      : ESP32S3_Registers.Byte := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CLK_EDGE_SEL_Register use record
      CCLKIN_EDGE_DRV_SEL at 0 range 0 .. 2;
      CCLKIN_EDGE_SAM_SEL at 0 range 3 .. 5;
      CCLKIN_EDGE_SLF_SEL at 0 range 6 .. 8;
      CCLLKIN_EDGE_H      at 0 range 9 .. 12;
      CCLLKIN_EDGE_L      at 0 range 13 .. 16;
      CCLLKIN_EDGE_N      at 0 range 17 .. 20;
      ESDIO_MODE          at 0 range 21 .. 21;
      ESD_MODE            at 0 range 22 .. 22;
      CCLK_EN             at 0 range 23 .. 23;
      Reserved_24_31      at 0 range 24 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  SD/MMC Host Controller
   type SDHOST_Peripheral is record
      --  Control register
      CTRL         : aliased CTRL_Register;
      --  Clock divider configuration register
      CLKDIV       : aliased CLKDIV_Register;
      --  Clock source selection register
      CLKSRC       : aliased CLKSRC_Register;
      --  Clock enable register
      CLKENA       : aliased CLKENA_Register;
      --  Data and response timeout configuration register
      TMOUT        : aliased TMOUT_Register;
      --  Card bus width configuration register
      CTYPE        : aliased CTYPE_Register;
      --  Card data block size configuration register
      BLKSIZ       : aliased BLKSIZ_Register;
      --  Data transfer length configuration register
      BYTCNT       : aliased ESP32S3_Registers.UInt32;
      --  SDIO interrupt mask register
      INTMASK      : aliased INTMASK_Register;
      --  Command argument data register
      CMDARG       : aliased ESP32S3_Registers.UInt32;
      --  Command and boot configuration register
      CMD          : aliased CMD_Register;
      --  Response data register
      RESP0        : aliased ESP32S3_Registers.UInt32;
      --  Long response data register
      RESP1        : aliased ESP32S3_Registers.UInt32;
      --  Long response data register
      RESP2        : aliased ESP32S3_Registers.UInt32;
      --  Long response data register
      RESP3        : aliased ESP32S3_Registers.UInt32;
      --  Masked interrupt status register
      MINTSTS      : aliased MINTSTS_Register;
      --  Raw interrupt status register
      RINTSTS      : aliased RINTSTS_Register;
      --  SD/MMC status register
      STATUS       : aliased STATUS_Register;
      --  FIFO configuration register
      FIFOTH       : aliased FIFOTH_Register;
      --  Card detect register
      CDETECT      : aliased CDETECT_Register;
      --  Card write protection (WP) status register
      WRTPRT       : aliased WRTPRT_Register;
      --  Transferred byte count register
      TCBCNT       : aliased ESP32S3_Registers.UInt32;
      --  Transferred byte count register
      TBBCNT       : aliased ESP32S3_Registers.UInt32;
      --  Debounce filter time configuration register
      DEBNCE       : aliased DEBNCE_Register;
      --  User ID (scratchpad) register
      USRID        : aliased ESP32S3_Registers.UInt32;
      --  Version ID (scratchpad) register
      VERID        : aliased ESP32S3_Registers.UInt32;
      --  Hardware feature register
      HCON         : aliased HCON_Register;
      --  UHS-1 register
      UHS          : aliased UHS_Register;
      --  Card reset register
      RST_N        : aliased RST_N_Register;
      --  Burst mode transfer configuration register
      BMOD         : aliased BMOD_Register;
      --  Poll demand configuration register
      PLDMND       : aliased ESP32S3_Registers.UInt32;
      --  Descriptor base address register
      DBADDR       : aliased ESP32S3_Registers.UInt32;
      --  IDMAC status register
      IDSTS        : aliased IDSTS_Register;
      --  IDMAC interrupt enable register
      IDINTEN      : aliased IDINTEN_Register;
      --  Host descriptor address pointer
      DSCADDR      : aliased ESP32S3_Registers.UInt32;
      --  Host buffer address pointer register
      BUFADDR      : aliased ESP32S3_Registers.UInt32;
      --  Card Threshold Control register
      CARDTHRCTL   : aliased CARDTHRCTL_Register;
      --  eMMC DDR register
      EMMCDDR      : aliased EMMCDDR_Register;
      --  Enable Phase Shift register
      ENSHIFT      : aliased ENSHIFT_Register;
      --  CPU write and read transmit data by FIFO
      BUFFIFO      : aliased ESP32S3_Registers.UInt32;
      --  SDIO control register.
      CLK_EDGE_SEL : aliased CLK_EDGE_SEL_Register;
   end record
     with Volatile;

   for SDHOST_Peripheral use record
      CTRL         at 16#0# range 0 .. 31;
      CLKDIV       at 16#8# range 0 .. 31;
      CLKSRC       at 16#C# range 0 .. 31;
      CLKENA       at 16#10# range 0 .. 31;
      TMOUT        at 16#14# range 0 .. 31;
      CTYPE        at 16#18# range 0 .. 31;
      BLKSIZ       at 16#1C# range 0 .. 31;
      BYTCNT       at 16#20# range 0 .. 31;
      INTMASK      at 16#24# range 0 .. 31;
      CMDARG       at 16#28# range 0 .. 31;
      CMD          at 16#2C# range 0 .. 31;
      RESP0        at 16#30# range 0 .. 31;
      RESP1        at 16#34# range 0 .. 31;
      RESP2        at 16#38# range 0 .. 31;
      RESP3        at 16#3C# range 0 .. 31;
      MINTSTS      at 16#40# range 0 .. 31;
      RINTSTS      at 16#44# range 0 .. 31;
      STATUS       at 16#48# range 0 .. 31;
      FIFOTH       at 16#4C# range 0 .. 31;
      CDETECT      at 16#50# range 0 .. 31;
      WRTPRT       at 16#54# range 0 .. 31;
      TCBCNT       at 16#5C# range 0 .. 31;
      TBBCNT       at 16#60# range 0 .. 31;
      DEBNCE       at 16#64# range 0 .. 31;
      USRID        at 16#68# range 0 .. 31;
      VERID        at 16#6C# range 0 .. 31;
      HCON         at 16#70# range 0 .. 31;
      UHS          at 16#74# range 0 .. 31;
      RST_N        at 16#78# range 0 .. 31;
      BMOD         at 16#80# range 0 .. 31;
      PLDMND       at 16#84# range 0 .. 31;
      DBADDR       at 16#88# range 0 .. 31;
      IDSTS        at 16#8C# range 0 .. 31;
      IDINTEN      at 16#90# range 0 .. 31;
      DSCADDR      at 16#94# range 0 .. 31;
      BUFADDR      at 16#98# range 0 .. 31;
      CARDTHRCTL   at 16#100# range 0 .. 31;
      EMMCDDR      at 16#10C# range 0 .. 31;
      ENSHIFT      at 16#110# range 0 .. 31;
      BUFFIFO      at 16#200# range 0 .. 31;
      CLK_EDGE_SEL at 16#800# range 0 .. 31;
   end record;

   --  SD/MMC Host Controller
   SDHOST_Periph : aliased SDHOST_Peripheral
     with Import, Address => SDHOST_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => True,
          Effective_Writes => True;

end ESP32S3_Registers.SDHOST;
