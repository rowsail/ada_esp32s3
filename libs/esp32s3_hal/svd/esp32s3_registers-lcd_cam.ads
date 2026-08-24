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

package ESP32S3_Registers.LCD_CAM is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype LCD_CLOCK_LCD_CLKCNT_N_Field is ESP32S3_Registers.UInt6;
   subtype LCD_CLOCK_LCD_CLKM_DIV_NUM_Field is ESP32S3_Registers.Byte;
   subtype LCD_CLOCK_LCD_CLKM_DIV_B_Field is ESP32S3_Registers.UInt6;
   subtype LCD_CLOCK_LCD_CLKM_DIV_A_Field is ESP32S3_Registers.UInt6;
   subtype LCD_CLOCK_LCD_CLK_SEL_Field is ESP32S3_Registers.UInt2;

   --  LCD clock configuration register
   type LCD_CLOCK_Register is record
      --  f<SUB>LCD_PCLK</SUB> = f<SUB>LCD_CLK</SUB>/(LCD_CAM_LCD_CLKCNT_N + 1)
      --  when LCD_CAM_LCD_CLK_EQU_SYSCLK is 0. Note: this field must not be
      --  configured to 0.
      LCD_CLKCNT_N       : LCD_CLOCK_LCD_CLKCNT_N_Field := 16#0#;
      --  1: f<SUB>LCD_PCLK</SUB> = f<SUB>LCD_CLK</SUB>. 0:
      --  f<SUB>LCD_PCLK</SUB> = f<SUB>LCD_CLK</SUB>/(LCD_CAM_LCD_CLKCNT_N +
      --  1).
      LCD_CLK_EQU_SYSCLK : Boolean := False;
      --  1: LCD_PCLK line is high in idle. 0: LCD_PCLK line is low in idle.
      LCD_CK_IDLE_EDGE   : Boolean := False;
      --  1: LCD_PCLK is high in the first half clock cycle. 0: LCD_PCLK is low
      --  in the first half clock cycle.
      LCD_CK_OUT_EDGE    : Boolean := False;
      --  Integral LCD clock divider value.
      LCD_CLKM_DIV_NUM   : LCD_CLOCK_LCD_CLKM_DIV_NUM_Field := 16#0#;
      --  Fractional clock divider numerator value.
      LCD_CLKM_DIV_B     : LCD_CLOCK_LCD_CLKM_DIV_B_Field := 16#0#;
      --  Fractional clock divider denominator value.
      LCD_CLKM_DIV_A     : LCD_CLOCK_LCD_CLKM_DIV_A_Field := 16#0#;
      --  Select LCD module source clock. 0: clock source is disabled. 1:
      --  XTAL_CLK. 2: PLL_D2_CLK. 3: PLL_F160M_CLK.
      LCD_CLK_SEL        : LCD_CLOCK_LCD_CLK_SEL_Field := 16#0#;
      --  Set this bit to force enable the clock for all configuration
      --  registers. Clock gate is not used.
      CLK_EN             : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_CLOCK_Register use record
      LCD_CLKCNT_N       at 0 range 0 .. 5;
      LCD_CLK_EQU_SYSCLK at 0 range 6 .. 6;
      LCD_CK_IDLE_EDGE   at 0 range 7 .. 7;
      LCD_CK_OUT_EDGE    at 0 range 8 .. 8;
      LCD_CLKM_DIV_NUM   at 0 range 9 .. 16;
      LCD_CLKM_DIV_B     at 0 range 17 .. 22;
      LCD_CLKM_DIV_A     at 0 range 23 .. 28;
      LCD_CLK_SEL        at 0 range 29 .. 30;
      CLK_EN             at 0 range 31 .. 31;
   end record;

   subtype CAM_CTRL_CAM_VSYNC_FILTER_THRES_Field is ESP32S3_Registers.UInt3;
   subtype CAM_CTRL_CAM_CLKM_DIV_NUM_Field is ESP32S3_Registers.Byte;
   subtype CAM_CTRL_CAM_CLKM_DIV_B_Field is ESP32S3_Registers.UInt6;
   subtype CAM_CTRL_CAM_CLKM_DIV_A_Field is ESP32S3_Registers.UInt6;
   subtype CAM_CTRL_CAM_CLK_SEL_Field is ESP32S3_Registers.UInt2;

   --  Camera clock configuration register
   type CAM_CTRL_Register is record
      --  Camera stop enable signal, 1: camera stops when GDMA Rx FIFO is full.
      --  0: Do not stop.
      CAM_STOP_EN            : Boolean := False;
      --  Filter threshold value for CAM_VSYNC signal.
      CAM_VSYNC_FILTER_THRES : CAM_CTRL_CAM_VSYNC_FILTER_THRES_Field := 16#0#;
      --  1: Update camera registers. This bit is cleared by hardware. 0: Do
      --  not care.
      CAM_UPDATE             : Boolean := False;
      --  1: Invert data byte order, only valid in 16-bit mode. 0: Do not
      --  change.
      CAM_BYTE_ORDER         : Boolean := False;
      --  1: Change data bit order, change CAM_DATA_in[7:0] to CAM_DATA_in[0:7]
      --  in 8-bit mode, and bits[15:0] to bits[0:15] in 16-bit mode. 0: Do not
      --  change.
      CAM_BIT_ORDER          : Boolean := False;
      --  1: Enable to generate LCD_CAM_CAM_HS_INT. 0: Disable.
      CAM_LINE_INT_EN        : Boolean := False;
      --  1: Enable CAM_VSYNC to generate in_suc_eof. 0: in_suc_eof is
      --  controlled by LCD_CAM_CAM_REC_DATA_BYTELEN.
      CAM_VS_EOF_EN          : Boolean := False;
      --  Integral camera clock divider value.
      CAM_CLKM_DIV_NUM       : CAM_CTRL_CAM_CLKM_DIV_NUM_Field := 16#0#;
      --  Fractional clock divider numerator value.
      CAM_CLKM_DIV_B         : CAM_CTRL_CAM_CLKM_DIV_B_Field := 16#0#;
      --  Fractional clock divider denominator value.
      CAM_CLKM_DIV_A         : CAM_CTRL_CAM_CLKM_DIV_A_Field := 16#0#;
      --  Select camera module source clock. 0: Clock source is disabled. 1:
      --  XTAL_CLK. 2: PLL_D2_CLK. 3: PLL_F160M_CLK.
      CAM_CLK_SEL            : CAM_CTRL_CAM_CLK_SEL_Field := 16#0#;
      --  unspecified
      Reserved_31_31         : ESP32S3_Registers.Bit := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CAM_CTRL_Register use record
      CAM_STOP_EN            at 0 range 0 .. 0;
      CAM_VSYNC_FILTER_THRES at 0 range 1 .. 3;
      CAM_UPDATE             at 0 range 4 .. 4;
      CAM_BYTE_ORDER         at 0 range 5 .. 5;
      CAM_BIT_ORDER          at 0 range 6 .. 6;
      CAM_LINE_INT_EN        at 0 range 7 .. 7;
      CAM_VS_EOF_EN          at 0 range 8 .. 8;
      CAM_CLKM_DIV_NUM       at 0 range 9 .. 16;
      CAM_CLKM_DIV_B         at 0 range 17 .. 22;
      CAM_CLKM_DIV_A         at 0 range 23 .. 28;
      CAM_CLK_SEL            at 0 range 29 .. 30;
      Reserved_31_31         at 0 range 31 .. 31;
   end record;

   subtype CAM_CTRL1_CAM_REC_DATA_BYTELEN_Field is ESP32S3_Registers.UInt16;
   subtype CAM_CTRL1_CAM_LINE_INT_NUM_Field is ESP32S3_Registers.UInt6;

   --  Camera control register
   type CAM_CTRL1_Register is record
      --  Configure camera received data byte length. When the length of
      --  received data reaches this value + 1, GDMA in_suc_eof_int is
      --  triggered.
      CAM_REC_DATA_BYTELEN : CAM_CTRL1_CAM_REC_DATA_BYTELEN_Field := 16#0#;
      --  Configure line number. When the number of received lines reaches this
      --  value + 1, LCD_CAM_CAM_HS_INT is triggered.
      CAM_LINE_INT_NUM     : CAM_CTRL1_CAM_LINE_INT_NUM_Field := 16#0#;
      --  1: Invert the input signal CAM_PCLK. 0: Do not invert.
      CAM_CLK_INV          : Boolean := False;
      --  1: Enable CAM_VSYNC filter function. 0: Bypass.
      CAM_VSYNC_FILTER_EN  : Boolean := False;
      --  1: The width of input data is 16 bits. 0: The width of input data is
      --  8 bits.
      CAM_2BYTE_EN         : Boolean := False;
      --  CAM_DE invert enable signal, valid in high level.
      CAM_DE_INV           : Boolean := False;
      --  CAM_HSYNC invert enable signal, valid in high level.
      CAM_HSYNC_INV        : Boolean := False;
      --  CAM_VSYNC invert enable signal, valid in high level.
      CAM_VSYNC_INV        : Boolean := False;
      --  1: Input control signals are CAM_DE and CAM_HSYNC. CAM_VSYNC is 1. 0:
      --  Input control signals are CAM_DE and CAM_VSYNC. CAM_HSYNC and CAM_DE
      --  are all 1 at the the same time.
      CAM_VH_DE_MODE_EN    : Boolean := False;
      --  Camera module start signal.
      CAM_START            : Boolean := False;
      --  Write-only. Camera module reset signal.
      CAM_RESET            : Boolean := False;
      --  Write-only. Camera Async Rx FIFO reset signal.
      CAM_AFIFO_RESET      : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CAM_CTRL1_Register use record
      CAM_REC_DATA_BYTELEN at 0 range 0 .. 15;
      CAM_LINE_INT_NUM     at 0 range 16 .. 21;
      CAM_CLK_INV          at 0 range 22 .. 22;
      CAM_VSYNC_FILTER_EN  at 0 range 23 .. 23;
      CAM_2BYTE_EN         at 0 range 24 .. 24;
      CAM_DE_INV           at 0 range 25 .. 25;
      CAM_HSYNC_INV        at 0 range 26 .. 26;
      CAM_VSYNC_INV        at 0 range 27 .. 27;
      CAM_VH_DE_MODE_EN    at 0 range 28 .. 28;
      CAM_START            at 0 range 29 .. 29;
      CAM_RESET            at 0 range 30 .. 30;
      CAM_AFIFO_RESET      at 0 range 31 .. 31;
   end record;

   subtype CAM_RGB_YUV_CAM_CONV_YUV2YUV_MODE_Field is ESP32S3_Registers.UInt2;
   subtype CAM_RGB_YUV_CAM_CONV_YUV_MODE_Field is ESP32S3_Registers.UInt2;

   --  Camera data format conversion register
   type CAM_RGB_YUV_Register is record
      --  unspecified
      Reserved_0_20           : ESP32S3_Registers.UInt21 := 16#0#;
      --  Swap every two 8-bit input data. 1: Enabled. 0: Disabled.
      CAM_CONV_8BITS_DATA_INV : Boolean := False;
      --  In YUV-to-YUV mode, 0: data is converted to YUV422 format. 1: data is
      --  converted to YUV420 format. 2: data is converted to YUV411 format. 3:
      --  disabled. To enable YUV-to-YUV mode, LCD_CAM_CAM_CONV_TRANS_MODE must
      --  be set to 1.
      CAM_CONV_YUV2YUV_MODE   : CAM_RGB_YUV_CAM_CONV_YUV2YUV_MODE_Field :=
                                 16#0#;
      --  In YUV-to-YUV mode and YUV-to-RGB mode, LCD_CAM_CAM_CONV_YUV_MODE
      --  decides the YUV mode of input data. 0: input data is in YUV422
      --  format. 1: input data is in YUV420 format. 2: input data is in YUV411
      --  format. In RGB-to-YUV mode, 0: data is converted to YUV422 format. 1:
      --  data is converted to YUV420 format. 2: data is converted to YUV411
      --  format.
      CAM_CONV_YUV_MODE       : CAM_RGB_YUV_CAM_CONV_YUV_MODE_Field := 16#0#;
      --  0: BT601. 1: BT709.
      CAM_CONV_PROTOCOL_MODE  : Boolean := False;
      --  Configure color range for output data. 0: limited color range. 1:
      --  full color range.
      CAM_CONV_DATA_OUT_MODE  : Boolean := False;
      --  Configure color range for input data. 0: limited color range. 1: full
      --  color range.
      CAM_CONV_DATA_IN_MODE   : Boolean := False;
      --  0: 16-bit mode. 1: 8-bit mode.
      CAM_CONV_MODE_8BITS_ON  : Boolean := False;
      --  0: converted to RGB format. 1: converted to YUV format.
      CAM_CONV_TRANS_MODE     : Boolean := False;
      --  0: Bypass converter. 1: Enable converter.
      CAM_CONV_BYPASS         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for CAM_RGB_YUV_Register use record
      Reserved_0_20           at 0 range 0 .. 20;
      CAM_CONV_8BITS_DATA_INV at 0 range 21 .. 21;
      CAM_CONV_YUV2YUV_MODE   at 0 range 22 .. 23;
      CAM_CONV_YUV_MODE       at 0 range 24 .. 25;
      CAM_CONV_PROTOCOL_MODE  at 0 range 26 .. 26;
      CAM_CONV_DATA_OUT_MODE  at 0 range 27 .. 27;
      CAM_CONV_DATA_IN_MODE   at 0 range 28 .. 28;
      CAM_CONV_MODE_8BITS_ON  at 0 range 29 .. 29;
      CAM_CONV_TRANS_MODE     at 0 range 30 .. 30;
      CAM_CONV_BYPASS         at 0 range 31 .. 31;
   end record;

   subtype LCD_RGB_YUV_LCD_CONV_YUV2YUV_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_RGB_YUV_LCD_CONV_YUV_MODE_Field is ESP32S3_Registers.UInt2;

   --  LCD data format conversion register
   type LCD_RGB_YUV_Register is record
      --  unspecified
      Reserved_0_19           : ESP32S3_Registers.UInt20 := 16#0#;
      --  Swap every two 8-bit input data. 1: Enabled. 0: Disabled.
      LCD_CONV_8BITS_DATA_INV : Boolean := False;
      --  unspecified
      Reserved_21_21          : ESP32S3_Registers.Bit := 16#0#;
      --  In YUV-to-YUV mode, 0: data is converted to YUV422 format. 1: data is
      --  converted to YUV420 format. 2: data is converted to YUV411 format. 3:
      --  disabled. To enable YUV-to-YUV mode, LCD_CAM_LCD_CONV_TRANS_MODE must
      --  be set to 1.
      LCD_CONV_YUV2YUV_MODE   : LCD_RGB_YUV_LCD_CONV_YUV2YUV_MODE_Field :=
                                 16#0#;
      --  In YUV-to-YUV mode and YUV-to-RGB mode, LCD_CAM_LCD_CONV_YUV_MODE
      --  decides the YUV mode of input data. 0: input data is in YUV422
      --  format. 1: input data is in YUV420 format. 2: input data is in YUV411
      --  format. In RGB-to-YUV mode, 0: data is converted to YUV422 format. 1:
      --  data is converted to YUV420 format. 2: data is converted to YUV411
      --  format.
      LCD_CONV_YUV_MODE       : LCD_RGB_YUV_LCD_CONV_YUV_MODE_Field := 16#0#;
      --  0: BT601. 1: BT709.
      LCD_CONV_PROTOCOL_MODE  : Boolean := False;
      --  Configure color range for output data. 0: limited color range. 1:
      --  full color range.
      LCD_CONV_DATA_OUT_MODE  : Boolean := False;
      --  Configure color range for input data. 0: limited color range. 1: full
      --  color range.
      LCD_CONV_DATA_IN_MODE   : Boolean := False;
      --  0: 16-bit mode. 1: 8-bit mode.
      LCD_CONV_MODE_8BITS_ON  : Boolean := False;
      --  0: converted to RGB format. 1: converted to YUV format.
      LCD_CONV_TRANS_MODE     : Boolean := False;
      --  0: Bypass converter. 1: Enable converter.
      LCD_CONV_BYPASS         : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_RGB_YUV_Register use record
      Reserved_0_19           at 0 range 0 .. 19;
      LCD_CONV_8BITS_DATA_INV at 0 range 20 .. 20;
      Reserved_21_21          at 0 range 21 .. 21;
      LCD_CONV_YUV2YUV_MODE   at 0 range 22 .. 23;
      LCD_CONV_YUV_MODE       at 0 range 24 .. 25;
      LCD_CONV_PROTOCOL_MODE  at 0 range 26 .. 26;
      LCD_CONV_DATA_OUT_MODE  at 0 range 27 .. 27;
      LCD_CONV_DATA_IN_MODE   at 0 range 28 .. 28;
      LCD_CONV_MODE_8BITS_ON  at 0 range 29 .. 29;
      LCD_CONV_TRANS_MODE     at 0 range 30 .. 30;
      LCD_CONV_BYPASS         at 0 range 31 .. 31;
   end record;

   subtype LCD_USER_LCD_DOUT_CYCLELEN_Field is ESP32S3_Registers.UInt13;
   subtype LCD_USER_LCD_DUMMY_CYCLELEN_Field is ESP32S3_Registers.UInt2;

   --  LCD user configuration register
   type LCD_USER_Register is record
      --  Configure the cycles for DOUT phase of LCD module. The cycles = this
      --  value + 1.
      LCD_DOUT_CYCLELEN  : LCD_USER_LCD_DOUT_CYCLELEN_Field := 16#0#;
      --  LCD continues outputting data when LCD is in DOUT phase, till
      --  LCD_CAM_LCD_START is cleared or LCD_CAM_LCD_RESET is set.
      LCD_ALWAYS_OUT_EN  : Boolean := False;
      --  unspecified
      Reserved_14_18     : ESP32S3_Registers.UInt5 := 16#0#;
      --  1: Swap every two data bytes, valid in 8-bit mode. 0: Do not swap.
      LCD_8BITS_ORDER    : Boolean := False;
      --  1: Update LCD registers. This bit is cleared by hardware. 0: Do not
      --  care.
      LCD_UPDATE         : Boolean := False;
      --  1: Change data bit order. Change LCD_DATA_out[7:0] to
      --  LCD_DATA_out[0:7] in 8-bit mode, and bits[15:0] to bits[0:15] in
      --  16-bit mode. 0: Do not change.
      LCD_BIT_ORDER      : Boolean := False;
      --  1: Invert data byte order, only valid in 16-bit mode. 0: Do not
      --  invert.
      LCD_BYTE_ORDER     : Boolean := False;
      --  1: The width of output LCD data is 16 bits. 0: The width of output
      --  LCD data is 8 bits.
      LCD_2BYTE_EN       : Boolean := False;
      --  1: Be able to send data out in LCD sequence when LCD starts. 0:
      --  Disable.
      LCD_DOUT           : Boolean := False;
      --  1: Enable DUMMY phase in LCD sequence when LCD starts. 0: Disable.
      LCD_DUMMY          : Boolean := False;
      --  1: Be able to send command in LCD sequence when LCD starts. 0:
      --  Disable.
      LCD_CMD            : Boolean := False;
      --  LCD starts sending data enable signal, valid in high level.
      LCD_START          : Boolean := False;
      --  Write-only. Reset LCD module.
      LCD_RESET          : Boolean := False;
      --  Configure DUMMY cycles. DUMMY cycles = this value + 1.
      LCD_DUMMY_CYCLELEN : LCD_USER_LCD_DUMMY_CYCLELEN_Field := 16#0#;
      --  The cycle length of command phase. 1: 2 cycles. 0: 1 cycle.
      LCD_CMD_2_CYCLE_EN : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_USER_Register use record
      LCD_DOUT_CYCLELEN  at 0 range 0 .. 12;
      LCD_ALWAYS_OUT_EN  at 0 range 13 .. 13;
      Reserved_14_18     at 0 range 14 .. 18;
      LCD_8BITS_ORDER    at 0 range 19 .. 19;
      LCD_UPDATE         at 0 range 20 .. 20;
      LCD_BIT_ORDER      at 0 range 21 .. 21;
      LCD_BYTE_ORDER     at 0 range 22 .. 22;
      LCD_2BYTE_EN       at 0 range 23 .. 23;
      LCD_DOUT           at 0 range 24 .. 24;
      LCD_DUMMY          at 0 range 25 .. 25;
      LCD_CMD            at 0 range 26 .. 26;
      LCD_START          at 0 range 27 .. 27;
      LCD_RESET          at 0 range 28 .. 28;
      LCD_DUMMY_CYCLELEN at 0 range 29 .. 30;
      LCD_CMD_2_CYCLE_EN at 0 range 31 .. 31;
   end record;

   subtype LCD_MISC_LCD_AFIFO_THRESHOLD_NUM_Field is ESP32S3_Registers.UInt5;
   subtype LCD_MISC_LCD_VFK_CYCLELEN_Field is ESP32S3_Registers.UInt6;
   subtype LCD_MISC_LCD_VBK_CYCLELEN_Field is ESP32S3_Registers.UInt13;

   --  LCD MISC configuration register
   type LCD_MISC_Register is record
      --  unspecified
      Reserved_0_0            : ESP32S3_Registers.Bit := 16#0#;
      --  Set the threshold for Async Tx FIFO full event.
      LCD_AFIFO_THRESHOLD_NUM : LCD_MISC_LCD_AFIFO_THRESHOLD_NUM_Field :=
                                 16#11#;
      --  Configure the setup cycles in LCD non-RGB mode. Setup cycles expected
      --  = this value + 1.
      LCD_VFK_CYCLELEN        : LCD_MISC_LCD_VFK_CYCLELEN_Field := 16#0#;
      --  Configure the hold time cycles in LCD non-RGB mode. Hold cycles
      --  expected = this value + 1. %Configure the cycles for vertical back
      --  blank region in LCD RGB mode, the cycles = this value + 1. Or
      --  configure the hold time cycles in LCD non-RGB mode, the cycles = this
      --  value + 1.
      LCD_VBK_CYCLELEN        : LCD_MISC_LCD_VBK_CYCLELEN_Field := 16#0#;
      --  1: Send the next frame data when the current frame is sent out. 0:
      --  LCD stops when the current frame is sent out.
      LCD_NEXT_FRAME_EN       : Boolean := False;
      --  1: Enable blank region when LCD sends data out. 0: No blank region.
      LCD_BK_EN               : Boolean := False;
      --  Write-only. Async Tx FIFO reset signal.
      LCD_AFIFO_RESET         : Boolean := False;
      --  1: LCD_CD = !LCD_CAM_LCD_CD_IDLE_EDGE when LCD is in DOUT phase. 0:
      --  LCD_CD = LCD_CAM_LCD_CD_IDLE_EDGE.
      LCD_CD_DATA_SET         : Boolean := False;
      --  1: LCD_CD = !LCD_CAM_LCD_CD_IDLE_EDGE when LCD is in DUMMY phase. 0:
      --  LCD_CD = LCD_CAM_LCD_CD_IDLE_EDGE.
      LCD_CD_DUMMY_SET        : Boolean := False;
      --  1: LCD_CD = !LCD_CAM_LCD_CD_IDLE_EDGE when LCD is in CMD phase. 0:
      --  LCD_CD = LCD_CAM_LCD_CD_IDLE_EDGE.
      LCD_CD_CMD_SET          : Boolean := False;
      --  The default value of LCD_CD.
      LCD_CD_IDLE_EDGE        : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_MISC_Register use record
      Reserved_0_0            at 0 range 0 .. 0;
      LCD_AFIFO_THRESHOLD_NUM at 0 range 1 .. 5;
      LCD_VFK_CYCLELEN        at 0 range 6 .. 11;
      LCD_VBK_CYCLELEN        at 0 range 12 .. 24;
      LCD_NEXT_FRAME_EN       at 0 range 25 .. 25;
      LCD_BK_EN               at 0 range 26 .. 26;
      LCD_AFIFO_RESET         at 0 range 27 .. 27;
      LCD_CD_DATA_SET         at 0 range 28 .. 28;
      LCD_CD_DUMMY_SET        at 0 range 29 .. 29;
      LCD_CD_CMD_SET          at 0 range 30 .. 30;
      LCD_CD_IDLE_EDGE        at 0 range 31 .. 31;
   end record;

   subtype LCD_CTRL_LCD_HB_FRONT_Field is ESP32S3_Registers.UInt11;
   subtype LCD_CTRL_LCD_VA_HEIGHT_Field is ESP32S3_Registers.UInt10;
   subtype LCD_CTRL_LCD_VT_HEIGHT_Field is ESP32S3_Registers.UInt10;

   --  LCD signal configuration register
   type LCD_CTRL_Register is record
      --  It is the horizontal blank front porch of a frame.
      LCD_HB_FRONT    : LCD_CTRL_LCD_HB_FRONT_Field := 16#0#;
      --  It is the vertical active height of a frame.
      LCD_VA_HEIGHT   : LCD_CTRL_LCD_VA_HEIGHT_Field := 16#0#;
      --  It is the vertical total height of a frame.
      LCD_VT_HEIGHT   : LCD_CTRL_LCD_VT_HEIGHT_Field := 16#0#;
      --  1: Enable RGB mode, and input VSYNC, HSYNC, and DE signals. 0:
      --  Disable.
      LCD_RGB_MODE_EN : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_CTRL_Register use record
      LCD_HB_FRONT    at 0 range 0 .. 10;
      LCD_VA_HEIGHT   at 0 range 11 .. 20;
      LCD_VT_HEIGHT   at 0 range 21 .. 30;
      LCD_RGB_MODE_EN at 0 range 31 .. 31;
   end record;

   subtype LCD_CTRL1_LCD_VB_FRONT_Field is ESP32S3_Registers.Byte;
   subtype LCD_CTRL1_LCD_HA_WIDTH_Field is ESP32S3_Registers.UInt12;
   subtype LCD_CTRL1_LCD_HT_WIDTH_Field is ESP32S3_Registers.UInt12;

   --  LCD signal configuration register 1
   type LCD_CTRL1_Register is record
      --  It is the vertical blank front porch of a frame.
      LCD_VB_FRONT : LCD_CTRL1_LCD_VB_FRONT_Field := 16#0#;
      --  It is the horizontal active width of a frame.
      LCD_HA_WIDTH : LCD_CTRL1_LCD_HA_WIDTH_Field := 16#0#;
      --  It is the horizontal total width of a frame.
      LCD_HT_WIDTH : LCD_CTRL1_LCD_HT_WIDTH_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_CTRL1_Register use record
      LCD_VB_FRONT at 0 range 0 .. 7;
      LCD_HA_WIDTH at 0 range 8 .. 19;
      LCD_HT_WIDTH at 0 range 20 .. 31;
   end record;

   subtype LCD_CTRL2_LCD_VSYNC_WIDTH_Field is ESP32S3_Registers.UInt7;
   subtype LCD_CTRL2_LCD_HSYNC_WIDTH_Field is ESP32S3_Registers.UInt7;
   subtype LCD_CTRL2_LCD_HSYNC_POSITION_Field is ESP32S3_Registers.Byte;

   --  LCD signal configuration register 2
   type LCD_CTRL2_Register is record
      --  It is the width of LCD_VSYNC active pulse in a line.
      LCD_VSYNC_WIDTH    : LCD_CTRL2_LCD_VSYNC_WIDTH_Field := 16#0#;
      --  It is the idle value of LCD_VSYNC.
      LCD_VSYNC_IDLE_POL : Boolean := False;
      --  It is the idle value of LCD_DE.
      LCD_DE_IDLE_POL    : Boolean := False;
      --  1: The pulse of LCD_HSYNC is out in vertical blanking lines in RGB
      --  mode. 0: LCD_HSYNC pulse is valid only in active region lines in RGB
      --  mode.
      LCD_HS_BLANK_EN    : Boolean := False;
      --  unspecified
      Reserved_10_15     : ESP32S3_Registers.UInt6 := 16#0#;
      --  It is the width of LCD_HSYNC active pulse in a line.
      LCD_HSYNC_WIDTH    : LCD_CTRL2_LCD_HSYNC_WIDTH_Field := 16#0#;
      --  It is the idle value of LCD_HSYNC.
      LCD_HSYNC_IDLE_POL : Boolean := False;
      --  It is the position of LCD_HSYNC active pulse in a line.
      LCD_HSYNC_POSITION : LCD_CTRL2_LCD_HSYNC_POSITION_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_CTRL2_Register use record
      LCD_VSYNC_WIDTH    at 0 range 0 .. 6;
      LCD_VSYNC_IDLE_POL at 0 range 7 .. 7;
      LCD_DE_IDLE_POL    at 0 range 8 .. 8;
      LCD_HS_BLANK_EN    at 0 range 9 .. 9;
      Reserved_10_15     at 0 range 10 .. 15;
      LCD_HSYNC_WIDTH    at 0 range 16 .. 22;
      LCD_HSYNC_IDLE_POL at 0 range 23 .. 23;
      LCD_HSYNC_POSITION at 0 range 24 .. 31;
   end record;

   subtype LCD_DLY_MODE_LCD_CD_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DLY_MODE_LCD_DE_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DLY_MODE_LCD_HSYNC_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DLY_MODE_LCD_VSYNC_MODE_Field is ESP32S3_Registers.UInt2;

   --  LCD signal delay configuration register
   type LCD_DLY_MODE_Register is record
      --  The output LCD_CD is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      LCD_CD_MODE    : LCD_DLY_MODE_LCD_CD_MODE_Field := 16#0#;
      --  The output LCD_DE is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      LCD_DE_MODE    : LCD_DLY_MODE_LCD_DE_MODE_Field := 16#0#;
      --  The output LCD_HSYNC is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      LCD_HSYNC_MODE : LCD_DLY_MODE_LCD_HSYNC_MODE_Field := 16#0#;
      --  The output LCD_VSYNC is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delay by
      --  the falling edge of LCD_CLK.
      LCD_VSYNC_MODE : LCD_DLY_MODE_LCD_VSYNC_MODE_Field := 16#0#;
      --  unspecified
      Reserved_8_31  : ESP32S3_Registers.UInt24 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_DLY_MODE_Register use record
      LCD_CD_MODE    at 0 range 0 .. 1;
      LCD_DE_MODE    at 0 range 2 .. 3;
      LCD_HSYNC_MODE at 0 range 4 .. 5;
      LCD_VSYNC_MODE at 0 range 6 .. 7;
      Reserved_8_31  at 0 range 8 .. 31;
   end record;

   subtype LCD_DATA_DOUT_MODE_DOUT0_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT1_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT2_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT3_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT4_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT5_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT6_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT7_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT8_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT9_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT10_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT11_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT12_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT13_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT14_MODE_Field is ESP32S3_Registers.UInt2;
   subtype LCD_DATA_DOUT_MODE_DOUT15_MODE_Field is ESP32S3_Registers.UInt2;

   --  LCD data delay configuration register
   type LCD_DATA_DOUT_MODE_Register is record
      --  The output data bit 0 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT0_MODE  : LCD_DATA_DOUT_MODE_DOUT0_MODE_Field := 16#0#;
      --  The output data bit 1 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT1_MODE  : LCD_DATA_DOUT_MODE_DOUT1_MODE_Field := 16#0#;
      --  The output data bit 2 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT2_MODE  : LCD_DATA_DOUT_MODE_DOUT2_MODE_Field := 16#0#;
      --  The output data bit 3 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT3_MODE  : LCD_DATA_DOUT_MODE_DOUT3_MODE_Field := 16#0#;
      --  The output data bit 4 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT4_MODE  : LCD_DATA_DOUT_MODE_DOUT4_MODE_Field := 16#0#;
      --  The output data bit 5 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT5_MODE  : LCD_DATA_DOUT_MODE_DOUT5_MODE_Field := 16#0#;
      --  The output data bit 6 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT6_MODE  : LCD_DATA_DOUT_MODE_DOUT6_MODE_Field := 16#0#;
      --  The output data bit 7 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT7_MODE  : LCD_DATA_DOUT_MODE_DOUT7_MODE_Field := 16#0#;
      --  The output data bit 8 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT8_MODE  : LCD_DATA_DOUT_MODE_DOUT8_MODE_Field := 16#0#;
      --  The output data bit 9 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT9_MODE  : LCD_DATA_DOUT_MODE_DOUT9_MODE_Field := 16#0#;
      --  The output data bit 10 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT10_MODE : LCD_DATA_DOUT_MODE_DOUT10_MODE_Field := 16#0#;
      --  The output data bit 11 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT11_MODE : LCD_DATA_DOUT_MODE_DOUT11_MODE_Field := 16#0#;
      --  The output data bit 12 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT12_MODE : LCD_DATA_DOUT_MODE_DOUT12_MODE_Field := 16#0#;
      --  The output data bit 13 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT13_MODE : LCD_DATA_DOUT_MODE_DOUT13_MODE_Field := 16#0#;
      --  The output data bit 14 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT14_MODE : LCD_DATA_DOUT_MODE_DOUT14_MODE_Field := 16#0#;
      --  The output data bit 15 is delayed by module clock LCD_CLK. 0: output
      --  without delay. 1: delayed by the rising edge of LCD_CLK. 2: delayed
      --  by the falling edge of LCD_CLK.
      DOUT15_MODE : LCD_DATA_DOUT_MODE_DOUT15_MODE_Field := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LCD_DATA_DOUT_MODE_Register use record
      DOUT0_MODE  at 0 range 0 .. 1;
      DOUT1_MODE  at 0 range 2 .. 3;
      DOUT2_MODE  at 0 range 4 .. 5;
      DOUT3_MODE  at 0 range 6 .. 7;
      DOUT4_MODE  at 0 range 8 .. 9;
      DOUT5_MODE  at 0 range 10 .. 11;
      DOUT6_MODE  at 0 range 12 .. 13;
      DOUT7_MODE  at 0 range 14 .. 15;
      DOUT8_MODE  at 0 range 16 .. 17;
      DOUT9_MODE  at 0 range 18 .. 19;
      DOUT10_MODE at 0 range 20 .. 21;
      DOUT11_MODE at 0 range 22 .. 23;
      DOUT12_MODE at 0 range 24 .. 25;
      DOUT13_MODE at 0 range 26 .. 27;
      DOUT14_MODE at 0 range 28 .. 29;
      DOUT15_MODE at 0 range 30 .. 31;
   end record;

   --  LCD_CAM GDMA interrupt enable register
   type LC_DMA_INT_ENA_Register is record
      --  The enable bit for LCD_CAM_LCD_VSYNC_INT interrupt.
      LCD_VSYNC_INT_ENA      : Boolean := False;
      --  The enable bit for LCD_CAM_LCD_TRANS_DONE_INT interrupt.
      LCD_TRANS_DONE_INT_ENA : Boolean := False;
      --  The enable bit for LCD_CAM_CAM_VSYNC_INT interrupt.
      CAM_VSYNC_INT_ENA      : Boolean := False;
      --  The enable bit for LCD_CAM_CAM_HS_INT interrupt.
      CAM_HS_INT_ENA         : Boolean := False;
      --  unspecified
      Reserved_4_31          : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LC_DMA_INT_ENA_Register use record
      LCD_VSYNC_INT_ENA      at 0 range 0 .. 0;
      LCD_TRANS_DONE_INT_ENA at 0 range 1 .. 1;
      CAM_VSYNC_INT_ENA      at 0 range 2 .. 2;
      CAM_HS_INT_ENA         at 0 range 3 .. 3;
      Reserved_4_31          at 0 range 4 .. 31;
   end record;

   --  LCD_CAM GDMA raw interrupt status register
   type LC_DMA_INT_RAW_Register is record
      --  Read-only. The raw bit for LCD_CAM_LCD_VSYNC_INT interrupt.
      LCD_VSYNC_INT_RAW      : Boolean;
      --  Read-only. The raw bit for LCD_CAM_LCD_TRANS_DONE_INT interrupt.
      LCD_TRANS_DONE_INT_RAW : Boolean;
      --  Read-only. The raw bit for LCD_CAM_CAM_VSYNC_INT interrupt.
      CAM_VSYNC_INT_RAW      : Boolean;
      --  Read-only. The raw bit for LCD_CAM_CAM_HS_INT interrupt.
      CAM_HS_INT_RAW         : Boolean;
      --  unspecified
      Reserved_4_31          : ESP32S3_Registers.UInt28;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LC_DMA_INT_RAW_Register use record
      LCD_VSYNC_INT_RAW      at 0 range 0 .. 0;
      LCD_TRANS_DONE_INT_RAW at 0 range 1 .. 1;
      CAM_VSYNC_INT_RAW      at 0 range 2 .. 2;
      CAM_HS_INT_RAW         at 0 range 3 .. 3;
      Reserved_4_31          at 0 range 4 .. 31;
   end record;

   --  LCD_CAM GDMA masked interrupt status register
   type LC_DMA_INT_ST_Register is record
      --  Read-only. The status bit for LCD_CAM_LCD_VSYNC_INT interrupt.
      LCD_VSYNC_INT_ST      : Boolean;
      --  Read-only. The status bit for LCD_CAM_LCD_TRANS_DONE_INT interrupt.
      LCD_TRANS_DONE_INT_ST : Boolean;
      --  Read-only. The status bit for LCD_CAM_CAM_VSYNC_INT interrupt.
      CAM_VSYNC_INT_ST      : Boolean;
      --  Read-only. The status bit for LCD_CAM_CAM_HS_INT interrupt.
      CAM_HS_INT_ST         : Boolean;
      --  unspecified
      Reserved_4_31         : ESP32S3_Registers.UInt28;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LC_DMA_INT_ST_Register use record
      LCD_VSYNC_INT_ST      at 0 range 0 .. 0;
      LCD_TRANS_DONE_INT_ST at 0 range 1 .. 1;
      CAM_VSYNC_INT_ST      at 0 range 2 .. 2;
      CAM_HS_INT_ST         at 0 range 3 .. 3;
      Reserved_4_31         at 0 range 4 .. 31;
   end record;

   --  LCD_CAM GDMA interrupt clear register
   type LC_DMA_INT_CLR_Register is record
      --  Write-only. The clear bit for LCD_CAM_LCD_VSYNC_INT interrupt.
      LCD_VSYNC_INT_CLR      : Boolean := False;
      --  Write-only. The clear bit for LCD_CAM_LCD_TRANS_DONE_INT interrupt.
      LCD_TRANS_DONE_INT_CLR : Boolean := False;
      --  Write-only. The clear bit for LCD_CAM_CAM_VSYNC_INT interrupt.
      CAM_VSYNC_INT_CLR      : Boolean := False;
      --  Write-only. The clear bit for LCD_CAM_CAM_HS_INT interrupt.
      CAM_HS_INT_CLR         : Boolean := False;
      --  unspecified
      Reserved_4_31          : ESP32S3_Registers.UInt28 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LC_DMA_INT_CLR_Register use record
      LCD_VSYNC_INT_CLR      at 0 range 0 .. 0;
      LCD_TRANS_DONE_INT_CLR at 0 range 1 .. 1;
      CAM_VSYNC_INT_CLR      at 0 range 2 .. 2;
      CAM_HS_INT_CLR         at 0 range 3 .. 3;
      Reserved_4_31          at 0 range 4 .. 31;
   end record;

   subtype LC_REG_DATE_LC_DATE_Field is ESP32S3_Registers.UInt28;

   --  Version control register
   type LC_REG_DATE_Register is record
      --  Version control register
      LC_DATE        : LC_REG_DATE_LC_DATE_Field := 16#2003020#;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for LC_REG_DATE_Register use record
      LC_DATE        at 0 range 0 .. 27;
      Reserved_28_31 at 0 range 28 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Camera/LCD Controller
   type LCD_CAM_Peripheral is record
      --  LCD clock configuration register
      LCD_CLOCK          : aliased LCD_CLOCK_Register;
      --  Camera clock configuration register
      CAM_CTRL           : aliased CAM_CTRL_Register;
      --  Camera control register
      CAM_CTRL1          : aliased CAM_CTRL1_Register;
      --  Camera data format conversion register
      CAM_RGB_YUV        : aliased CAM_RGB_YUV_Register;
      --  LCD data format conversion register
      LCD_RGB_YUV        : aliased LCD_RGB_YUV_Register;
      --  LCD user configuration register
      LCD_USER           : aliased LCD_USER_Register;
      --  LCD MISC configuration register
      LCD_MISC           : aliased LCD_MISC_Register;
      --  LCD signal configuration register
      LCD_CTRL           : aliased LCD_CTRL_Register;
      --  LCD signal configuration register 1
      LCD_CTRL1          : aliased LCD_CTRL1_Register;
      --  LCD signal configuration register 2
      LCD_CTRL2          : aliased LCD_CTRL2_Register;
      --  LCD command value configuration register
      LCD_CMD_VAL        : aliased ESP32S3_Registers.UInt32;
      --  LCD signal delay configuration register
      LCD_DLY_MODE       : aliased LCD_DLY_MODE_Register;
      --  LCD data delay configuration register
      LCD_DATA_DOUT_MODE : aliased LCD_DATA_DOUT_MODE_Register;
      --  LCD_CAM GDMA interrupt enable register
      LC_DMA_INT_ENA     : aliased LC_DMA_INT_ENA_Register;
      --  LCD_CAM GDMA raw interrupt status register
      LC_DMA_INT_RAW     : aliased LC_DMA_INT_RAW_Register;
      --  LCD_CAM GDMA masked interrupt status register
      LC_DMA_INT_ST      : aliased LC_DMA_INT_ST_Register;
      --  LCD_CAM GDMA interrupt clear register
      LC_DMA_INT_CLR     : aliased LC_DMA_INT_CLR_Register;
      --  Version control register
      LC_REG_DATE        : aliased LC_REG_DATE_Register;
   end record
     with Volatile;

   for LCD_CAM_Peripheral use record
      LCD_CLOCK          at 16#0# range 0 .. 31;
      CAM_CTRL           at 16#4# range 0 .. 31;
      CAM_CTRL1          at 16#8# range 0 .. 31;
      CAM_RGB_YUV        at 16#C# range 0 .. 31;
      LCD_RGB_YUV        at 16#10# range 0 .. 31;
      LCD_USER           at 16#14# range 0 .. 31;
      LCD_MISC           at 16#18# range 0 .. 31;
      LCD_CTRL           at 16#1C# range 0 .. 31;
      LCD_CTRL1          at 16#20# range 0 .. 31;
      LCD_CTRL2          at 16#24# range 0 .. 31;
      LCD_CMD_VAL        at 16#28# range 0 .. 31;
      LCD_DLY_MODE       at 16#30# range 0 .. 31;
      LCD_DATA_DOUT_MODE at 16#38# range 0 .. 31;
      LC_DMA_INT_ENA     at 16#64# range 0 .. 31;
      LC_DMA_INT_RAW     at 16#68# range 0 .. 31;
      LC_DMA_INT_ST      at 16#6C# range 0 .. 31;
      LC_DMA_INT_CLR     at 16#70# range 0 .. 31;
      LC_REG_DATE        at 16#FC# range 0 .. 31;
   end record;

   --  Camera/LCD Controller
   LCD_CAM_Periph : aliased LCD_CAM_Peripheral
     with Import, Address => LCD_CAM_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.LCD_CAM;
