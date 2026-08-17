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

package ESP32S3_Registers.SYSTEM is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   --  Core0 control regiter 0
   type CORE_1_CONTROL_0_Register is record
      --  Set 1 to stall core1
      CONTROL_CORE_1_RUNSTALL   : Boolean := False;
      --  Set 1 to open core1 clock
      CONTROL_CORE_1_CLKGATE_EN : Boolean := False;
      --  Set 1 to let core1 reset
      CONTROL_CORE_1_RESETING   : Boolean := True;
      --  unspecified
      Reserved_3_31             : ESP32S3_Registers.UInt29 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CORE_1_CONTROL_0_Register use
     record
       CONTROL_CORE_1_RUNSTALL at 0 range 0 .. 0;
       CONTROL_CORE_1_CLKGATE_EN at 0 range 1 .. 1;
       CONTROL_CORE_1_RESETING at 0 range 2 .. 2;
       Reserved_3_31 at 0 range 3 .. 31;
     end record;

   --  cpu_peripheral clock configuration register
   type CPU_PERI_CLK_EN_Register is record
      --  unspecified
      Reserved_0_5          : ESP32S3_Registers.UInt6 := 16#0#;
      --  Set 1 to open assist_debug module clock
      CLK_EN_ASSIST_DEBUG   : Boolean := False;
      --  Set 1 to open dedicated_gpio module clk
      CLK_EN_DEDICATED_GPIO : Boolean := False;
      --  unspecified
      Reserved_8_31         : ESP32S3_Registers.UInt24 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CPU_PERI_CLK_EN_Register use
     record
       Reserved_0_5 at 0 range 0 .. 5;
       CLK_EN_ASSIST_DEBUG at 0 range 6 .. 6;
       CLK_EN_DEDICATED_GPIO at 0 range 7 .. 7;
       Reserved_8_31 at 0 range 8 .. 31;
     end record;

   --  cpu_peripheral reset configuration regsiter
   type CPU_PERI_RST_EN_Register is record
      --  unspecified
      Reserved_0_5          : ESP32S3_Registers.UInt6 := 16#0#;
      --  Set 1 to let assist_debug module reset
      RST_EN_ASSIST_DEBUG   : Boolean := True;
      --  Set 1 to let dedicated_gpio module reset
      RST_EN_DEDICATED_GPIO : Boolean := True;
      --  unspecified
      Reserved_8_31         : ESP32S3_Registers.UInt24 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CPU_PERI_RST_EN_Register use
     record
       Reserved_0_5 at 0 range 0 .. 5;
       RST_EN_ASSIST_DEBUG at 0 range 6 .. 6;
       RST_EN_DEDICATED_GPIO at 0 range 7 .. 7;
       Reserved_8_31 at 0 range 8 .. 31;
     end record;

   subtype CPU_PER_CONF_CPUPERIOD_SEL_Field is ESP32S3_Registers.UInt2;
   subtype CPU_PER_CONF_CPU_WAITI_DELAY_NUM_Field is ESP32S3_Registers.UInt4;

   --  cpu peripheral clock configuration register
   type CPU_PER_CONF_Register is record
      --  This field used to sel cpu clock frequent.
      CPUPERIOD_SEL          : CPU_PER_CONF_CPUPERIOD_SEL_Field := 16#0#;
      --  This field used to sel pll frequent.
      PLL_FREQ_SEL           : Boolean := True;
      --  Set 1 to force cpu_waiti_clk enable.
      CPU_WAIT_MODE_FORCE_ON : Boolean := True;
      --  This field used to set delay cycle when cpu enter waiti mode, after
      --  delay waiti_clk will close
      CPU_WAITI_DELAY_NUM    : CPU_PER_CONF_CPU_WAITI_DELAY_NUM_Field := 16#0#;
      --  unspecified
      Reserved_8_31          : ESP32S3_Registers.UInt24 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CPU_PER_CONF_Register use
     record
       CPUPERIOD_SEL at 0 range 0 .. 1;
       PLL_FREQ_SEL at 0 range 2 .. 2;
       CPU_WAIT_MODE_FORCE_ON at 0 range 3 .. 3;
       CPU_WAITI_DELAY_NUM at 0 range 4 .. 7;
       Reserved_8_31 at 0 range 8 .. 31;
     end record;

   --  memory power down mask configuration register
   type MEM_PD_MASK_Register is record
      --  Set 1 to mask memory power down.
      LSLP_MEM_PD_MASK : Boolean := True;
      --  unspecified
      Reserved_1_31    : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for MEM_PD_MASK_Register use
     record
       LSLP_MEM_PD_MASK at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   --  peripheral clock configuration regsiter 0
   type PERIP_CLK_EN0_Register is record
      --  Set 1 to enable TIMERS clock
      TIMERS_CLK_EN      : Boolean := True;
      --  Set 1 to enable SPI01 clock
      SPI01_CLK_EN       : Boolean := True;
      --  Set 1 to enable UART clock
      UART_CLK_EN        : Boolean := True;
      --  Set 1 to enable WDG clock
      WDG_CLK_EN         : Boolean := True;
      --  Set 1 to enable I2S0 clock
      I2S0_CLK_EN        : Boolean := False;
      --  Set 1 to enable UART1 clock
      UART1_CLK_EN       : Boolean := True;
      --  Set 1 to enable SPI2 clock
      SPI2_CLK_EN        : Boolean := True;
      --  Set 1 to enable I2C_EXT0 clock
      I2C_EXT0_CLK_EN    : Boolean := False;
      --  Set 1 to enable UHCI0 clock
      UHCI0_CLK_EN       : Boolean := False;
      --  Set 1 to enable RMT clock
      RMT_CLK_EN         : Boolean := False;
      --  Set 1 to enable PCNT clock
      PCNT_CLK_EN        : Boolean := False;
      --  Set 1 to enable LEDC clock
      LEDC_CLK_EN        : Boolean := False;
      --  Set 1 to enable UHCI1 clock
      UHCI1_CLK_EN       : Boolean := False;
      --  Set 1 to enable TIMERGROUP clock
      TIMERGROUP_CLK_EN  : Boolean := True;
      --  Set 1 to enable EFUSE clock
      EFUSE_CLK_EN       : Boolean := True;
      --  Set 1 to enable TIMERGROUP1 clock
      TIMERGROUP1_CLK_EN : Boolean := True;
      --  Set 1 to enable SPI3 clock
      SPI3_CLK_EN        : Boolean := True;
      --  Set 1 to enable PWM0 clock
      PWM0_CLK_EN        : Boolean := False;
      --  Set 1 to enable I2C_EXT1 clock
      I2C_EXT1_CLK_EN    : Boolean := False;
      --  Set 1 to enable CAN clock
      TWAI_CLK_EN        : Boolean := False;
      --  Set 1 to enable PWM1 clock
      PWM1_CLK_EN        : Boolean := False;
      --  Set 1 to enable I2S1 clock
      I2S1_CLK_EN        : Boolean := False;
      --  Set 1 to enable SPI2_DMA clock
      SPI2_DMA_CLK_EN    : Boolean := True;
      --  Set 1 to enable USB clock
      USB_CLK_EN         : Boolean := True;
      --  Set 1 to enable UART_MEM clock
      UART_MEM_CLK_EN    : Boolean := True;
      --  Set 1 to enable PWM2 clock
      PWM2_CLK_EN        : Boolean := False;
      --  Set 1 to enable PWM3 clock
      PWM3_CLK_EN        : Boolean := False;
      --  Set 1 to enable SPI4 clock
      SPI3_DMA_CLK_EN    : Boolean := True;
      --  Set 1 to enable APB_SARADC clock
      APB_SARADC_CLK_EN  : Boolean := True;
      --  Set 1 to enable SYSTEMTIMER clock
      SYSTIMER_CLK_EN    : Boolean := True;
      --  Set 1 to enable ADC2_ARB clock
      ADC2_ARB_CLK_EN    : Boolean := True;
      --  Set 1 to enable SPI4 clock
      SPI4_CLK_EN        : Boolean := True;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for PERIP_CLK_EN0_Register use
     record
       TIMERS_CLK_EN at 0 range 0 .. 0;
       SPI01_CLK_EN at 0 range 1 .. 1;
       UART_CLK_EN at 0 range 2 .. 2;
       WDG_CLK_EN at 0 range 3 .. 3;
       I2S0_CLK_EN at 0 range 4 .. 4;
       UART1_CLK_EN at 0 range 5 .. 5;
       SPI2_CLK_EN at 0 range 6 .. 6;
       I2C_EXT0_CLK_EN at 0 range 7 .. 7;
       UHCI0_CLK_EN at 0 range 8 .. 8;
       RMT_CLK_EN at 0 range 9 .. 9;
       PCNT_CLK_EN at 0 range 10 .. 10;
       LEDC_CLK_EN at 0 range 11 .. 11;
       UHCI1_CLK_EN at 0 range 12 .. 12;
       TIMERGROUP_CLK_EN at 0 range 13 .. 13;
       EFUSE_CLK_EN at 0 range 14 .. 14;
       TIMERGROUP1_CLK_EN at 0 range 15 .. 15;
       SPI3_CLK_EN at 0 range 16 .. 16;
       PWM0_CLK_EN at 0 range 17 .. 17;
       I2C_EXT1_CLK_EN at 0 range 18 .. 18;
       TWAI_CLK_EN at 0 range 19 .. 19;
       PWM1_CLK_EN at 0 range 20 .. 20;
       I2S1_CLK_EN at 0 range 21 .. 21;
       SPI2_DMA_CLK_EN at 0 range 22 .. 22;
       USB_CLK_EN at 0 range 23 .. 23;
       UART_MEM_CLK_EN at 0 range 24 .. 24;
       PWM2_CLK_EN at 0 range 25 .. 25;
       PWM3_CLK_EN at 0 range 26 .. 26;
       SPI3_DMA_CLK_EN at 0 range 27 .. 27;
       APB_SARADC_CLK_EN at 0 range 28 .. 28;
       SYSTIMER_CLK_EN at 0 range 29 .. 29;
       ADC2_ARB_CLK_EN at 0 range 30 .. 30;
       SPI4_CLK_EN at 0 range 31 .. 31;
     end record;

   --  peripheral clock configuration regsiter 1
   type PERIP_CLK_EN1_Register is record
      --  Set 1 to enable BACKUP clock
      PERI_BACKUP_CLK_EN : Boolean := False;
      --  Set 1 to enable AES clock
      CRYPTO_AES_CLK_EN  : Boolean := False;
      --  Set 1 to enable SHA clock
      CRYPTO_SHA_CLK_EN  : Boolean := False;
      --  Set 1 to enable RSA clock
      CRYPTO_RSA_CLK_EN  : Boolean := False;
      --  Set 1 to enable DS clock
      CRYPTO_DS_CLK_EN   : Boolean := False;
      --  Set 1 to enable HMAC clock
      CRYPTO_HMAC_CLK_EN : Boolean := False;
      --  Set 1 to enable DMA clock
      DMA_CLK_EN         : Boolean := False;
      --  Set 1 to enable SDIO_HOST clock
      SDIO_HOST_CLK_EN   : Boolean := False;
      --  Set 1 to enable LCD_CAM clock
      LCD_CAM_CLK_EN     : Boolean := False;
      --  Set 1 to enable UART2 clock
      UART2_CLK_EN       : Boolean := True;
      --  Set 1 to enable USB_DEVICE clock
      USB_DEVICE_CLK_EN  : Boolean := True;
      --  unspecified
      Reserved_11_31     : ESP32S3_Registers.UInt21 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for PERIP_CLK_EN1_Register use
     record
       PERI_BACKUP_CLK_EN at 0 range 0 .. 0;
       CRYPTO_AES_CLK_EN at 0 range 1 .. 1;
       CRYPTO_SHA_CLK_EN at 0 range 2 .. 2;
       CRYPTO_RSA_CLK_EN at 0 range 3 .. 3;
       CRYPTO_DS_CLK_EN at 0 range 4 .. 4;
       CRYPTO_HMAC_CLK_EN at 0 range 5 .. 5;
       DMA_CLK_EN at 0 range 6 .. 6;
       SDIO_HOST_CLK_EN at 0 range 7 .. 7;
       LCD_CAM_CLK_EN at 0 range 8 .. 8;
       UART2_CLK_EN at 0 range 9 .. 9;
       USB_DEVICE_CLK_EN at 0 range 10 .. 10;
       Reserved_11_31 at 0 range 11 .. 31;
     end record;

   --  peripheral reset configuration register0
   type PERIP_RST_EN0_Register is record
      --  Set 1 to let TIMERS reset
      TIMERS_RST      : Boolean := False;
      --  Set 1 to let SPI01 reset
      SPI01_RST       : Boolean := False;
      --  Set 1 to let UART reset
      UART_RST        : Boolean := False;
      --  Set 1 to let WDG reset
      WDG_RST         : Boolean := False;
      --  Set 1 to let I2S0 reset
      I2S0_RST        : Boolean := False;
      --  Set 1 to let UART1 reset
      UART1_RST       : Boolean := False;
      --  Set 1 to let SPI2 reset
      SPI2_RST        : Boolean := False;
      --  Set 1 to let I2C_EXT0 reset
      I2C_EXT0_RST    : Boolean := False;
      --  Set 1 to let UHCI0 reset
      UHCI0_RST       : Boolean := False;
      --  Set 1 to let RMT reset
      RMT_RST         : Boolean := False;
      --  Set 1 to let PCNT reset
      PCNT_RST        : Boolean := False;
      --  Set 1 to let LEDC reset
      LEDC_RST        : Boolean := False;
      --  Set 1 to let UHCI1 reset
      UHCI1_RST       : Boolean := False;
      --  Set 1 to let TIMERGROUP reset
      TIMERGROUP_RST  : Boolean := False;
      --  Set 1 to let EFUSE reset
      EFUSE_RST       : Boolean := False;
      --  Set 1 to let TIMERGROUP1 reset
      TIMERGROUP1_RST : Boolean := False;
      --  Set 1 to let SPI3 reset
      SPI3_RST        : Boolean := False;
      --  Set 1 to let PWM0 reset
      PWM0_RST        : Boolean := False;
      --  Set 1 to let I2C_EXT1 reset
      I2C_EXT1_RST    : Boolean := False;
      --  Set 1 to let CAN reset
      TWAI_RST        : Boolean := False;
      --  Set 1 to let PWM1 reset
      PWM1_RST        : Boolean := False;
      --  Set 1 to let I2S1 reset
      I2S1_RST        : Boolean := False;
      --  Set 1 to let SPI2 reset
      SPI2_DMA_RST    : Boolean := False;
      --  Set 1 to let USB reset
      USB_RST         : Boolean := False;
      --  Set 1 to let UART_MEM reset
      UART_MEM_RST    : Boolean := False;
      --  Set 1 to let PWM2 reset
      PWM2_RST        : Boolean := False;
      --  Set 1 to let PWM3 reset
      PWM3_RST        : Boolean := False;
      --  Set 1 to let SPI3 reset
      SPI3_DMA_RST    : Boolean := False;
      --  Set 1 to let APB_SARADC reset
      APB_SARADC_RST  : Boolean := False;
      --  Set 1 to let SYSTIMER reset
      SYSTIMER_RST    : Boolean := False;
      --  Set 1 to let ADC2_ARB reset
      ADC2_ARB_RST    : Boolean := False;
      --  Set 1 to let SPI4 reset
      SPI4_RST        : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for PERIP_RST_EN0_Register use
     record
       TIMERS_RST at 0 range 0 .. 0;
       SPI01_RST at 0 range 1 .. 1;
       UART_RST at 0 range 2 .. 2;
       WDG_RST at 0 range 3 .. 3;
       I2S0_RST at 0 range 4 .. 4;
       UART1_RST at 0 range 5 .. 5;
       SPI2_RST at 0 range 6 .. 6;
       I2C_EXT0_RST at 0 range 7 .. 7;
       UHCI0_RST at 0 range 8 .. 8;
       RMT_RST at 0 range 9 .. 9;
       PCNT_RST at 0 range 10 .. 10;
       LEDC_RST at 0 range 11 .. 11;
       UHCI1_RST at 0 range 12 .. 12;
       TIMERGROUP_RST at 0 range 13 .. 13;
       EFUSE_RST at 0 range 14 .. 14;
       TIMERGROUP1_RST at 0 range 15 .. 15;
       SPI3_RST at 0 range 16 .. 16;
       PWM0_RST at 0 range 17 .. 17;
       I2C_EXT1_RST at 0 range 18 .. 18;
       TWAI_RST at 0 range 19 .. 19;
       PWM1_RST at 0 range 20 .. 20;
       I2S1_RST at 0 range 21 .. 21;
       SPI2_DMA_RST at 0 range 22 .. 22;
       USB_RST at 0 range 23 .. 23;
       UART_MEM_RST at 0 range 24 .. 24;
       PWM2_RST at 0 range 25 .. 25;
       PWM3_RST at 0 range 26 .. 26;
       SPI3_DMA_RST at 0 range 27 .. 27;
       APB_SARADC_RST at 0 range 28 .. 28;
       SYSTIMER_RST at 0 range 29 .. 29;
       ADC2_ARB_RST at 0 range 30 .. 30;
       SPI4_RST at 0 range 31 .. 31;
     end record;

   --  peripheral reset configuration regsiter 1
   type PERIP_RST_EN1_Register is record
      --  Set 1 to let BACKUP reset
      PERI_BACKUP_RST : Boolean := False;
      --  Set 1 to let CRYPTO_AES reset
      CRYPTO_AES_RST  : Boolean := True;
      --  Set 1 to let CRYPTO_SHA reset
      CRYPTO_SHA_RST  : Boolean := True;
      --  Set 1 to let CRYPTO_RSA reset
      CRYPTO_RSA_RST  : Boolean := True;
      --  Set 1 to let CRYPTO_DS reset
      CRYPTO_DS_RST   : Boolean := True;
      --  Set 1 to let CRYPTO_HMAC reset
      CRYPTO_HMAC_RST : Boolean := True;
      --  Set 1 to let DMA reset
      DMA_RST         : Boolean := True;
      --  Set 1 to let SDIO_HOST reset
      SDIO_HOST_RST   : Boolean := True;
      --  Set 1 to let LCD_CAM reset
      LCD_CAM_RST     : Boolean := True;
      --  Set 1 to let UART2 reset
      UART2_RST       : Boolean := False;
      --  Set 1 to let USB_DEVICE reset
      USB_DEVICE_RST  : Boolean := False;
      --  unspecified
      Reserved_11_31  : ESP32S3_Registers.UInt21 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for PERIP_RST_EN1_Register use
     record
       PERI_BACKUP_RST at 0 range 0 .. 0;
       CRYPTO_AES_RST at 0 range 1 .. 1;
       CRYPTO_SHA_RST at 0 range 2 .. 2;
       CRYPTO_RSA_RST at 0 range 3 .. 3;
       CRYPTO_DS_RST at 0 range 4 .. 4;
       CRYPTO_HMAC_RST at 0 range 5 .. 5;
       DMA_RST at 0 range 6 .. 6;
       SDIO_HOST_RST at 0 range 7 .. 7;
       LCD_CAM_RST at 0 range 8 .. 8;
       UART2_RST at 0 range 9 .. 9;
       USB_DEVICE_RST at 0 range 10 .. 10;
       Reserved_11_31 at 0 range 11 .. 31;
     end record;

   subtype BT_LPCK_DIV_INT_BT_LPCK_DIV_NUM_Field is ESP32S3_Registers.UInt12;

   --  low power clock frequent division factor configuration regsiter
   type BT_LPCK_DIV_INT_Register is record
      --  This field is lower power clock frequent division factor
      BT_LPCK_DIV_NUM : BT_LPCK_DIV_INT_BT_LPCK_DIV_NUM_Field := 16#FF#;
      --  unspecified
      Reserved_12_31  : ESP32S3_Registers.UInt20 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for BT_LPCK_DIV_INT_Register use
     record
       BT_LPCK_DIV_NUM at 0 range 0 .. 11;
       Reserved_12_31 at 0 range 12 .. 31;
     end record;

   subtype BT_LPCK_DIV_FRAC_BT_LPCK_DIV_B_Field is ESP32S3_Registers.UInt12;
   subtype BT_LPCK_DIV_FRAC_BT_LPCK_DIV_A_Field is ESP32S3_Registers.UInt12;

   --  low power clock configuration register
   type BT_LPCK_DIV_FRAC_Register is record
      --  This field is lower power clock frequent division factor b
      BT_LPCK_DIV_B      : BT_LPCK_DIV_FRAC_BT_LPCK_DIV_B_Field := 16#1#;
      --  This field is lower power clock frequent division factor a
      BT_LPCK_DIV_A      : BT_LPCK_DIV_FRAC_BT_LPCK_DIV_A_Field := 16#1#;
      --  Set 1 to select rtc-slow clock as rtc low power clock
      LPCLK_SEL_RTC_SLOW : Boolean := False;
      --  Set 1 to select 8m clock as rtc low power clock
      LPCLK_SEL_8M       : Boolean := True;
      --  Set 1 to select xtal clock as rtc low power clock
      LPCLK_SEL_XTAL     : Boolean := False;
      --  Set 1 to select xtal32k clock as low power clock
      LPCLK_SEL_XTAL32K  : Boolean := False;
      --  Set 1 to enable RTC low power clock
      LPCLK_RTC_EN       : Boolean := False;
      --  unspecified
      Reserved_29_31     : ESP32S3_Registers.UInt3 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for BT_LPCK_DIV_FRAC_Register use
     record
       BT_LPCK_DIV_B at 0 range 0 .. 11;
       BT_LPCK_DIV_A at 0 range 12 .. 23;
       LPCLK_SEL_RTC_SLOW at 0 range 24 .. 24;
       LPCLK_SEL_8M at 0 range 25 .. 25;
       LPCLK_SEL_XTAL at 0 range 26 .. 26;
       LPCLK_SEL_XTAL32K at 0 range 27 .. 27;
       LPCLK_RTC_EN at 0 range 28 .. 28;
       Reserved_29_31 at 0 range 29 .. 31;
     end record;

   --  interrupt source register 0
   type CPU_INTR_FROM_CPU_0_Register is record
      --  Set 1 to generate cpu interrupt 0
      CPU_INTR_FROM_CPU_0 : Boolean := False;
      --  unspecified
      Reserved_1_31       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CPU_INTR_FROM_CPU_0_Register use
     record
       CPU_INTR_FROM_CPU_0 at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   --  interrupt source register 1
   type CPU_INTR_FROM_CPU_1_Register is record
      --  Set 1 to generate cpu interrupt 1
      CPU_INTR_FROM_CPU_1 : Boolean := False;
      --  unspecified
      Reserved_1_31       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CPU_INTR_FROM_CPU_1_Register use
     record
       CPU_INTR_FROM_CPU_1 at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   --  interrupt source register 2
   type CPU_INTR_FROM_CPU_2_Register is record
      --  Set 1 to generate cpu interrupt 2
      CPU_INTR_FROM_CPU_2 : Boolean := False;
      --  unspecified
      Reserved_1_31       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CPU_INTR_FROM_CPU_2_Register use
     record
       CPU_INTR_FROM_CPU_2 at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   --  interrupt source register 3
   type CPU_INTR_FROM_CPU_3_Register is record
      --  Set 1 to generate cpu interrupt 3
      CPU_INTR_FROM_CPU_3 : Boolean := False;
      --  unspecified
      Reserved_1_31       : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CPU_INTR_FROM_CPU_3_Register use
     record
       CPU_INTR_FROM_CPU_3 at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   --  rsa memory power control register
   type RSA_PD_CTRL_Register is record
      --  Set 1 to power down RSA memory. This bit has the lowest priority.When
      --  Digital Signature occupies the RSA, this bit is invalid.
      RSA_MEM_PD       : Boolean := True;
      --  Set 1 to force power up RSA memory, this bit has the second highest
      --  priority.
      RSA_MEM_FORCE_PU : Boolean := False;
      --  Set 1 to force power down RSA memory,this bit has the highest
      --  priority.
      RSA_MEM_FORCE_PD : Boolean := False;
      --  unspecified
      Reserved_3_31    : ESP32S3_Registers.UInt29 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for RSA_PD_CTRL_Register use
     record
       RSA_MEM_PD at 0 range 0 .. 0;
       RSA_MEM_FORCE_PU at 0 range 1 .. 1;
       RSA_MEM_FORCE_PD at 0 range 2 .. 2;
       Reserved_3_31 at 0 range 3 .. 31;
     end record;

   --  EDMA control register
   type EDMA_CTRL_Register is record
      --  Set 1 to enable EDMA clock.
      EDMA_CLK_ON   : Boolean := True;
      --  Set 1 to let EDMA reset
      EDMA_RESET    : Boolean := False;
      --  unspecified
      Reserved_2_31 : ESP32S3_Registers.UInt30 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for EDMA_CTRL_Register use
     record
       EDMA_CLK_ON at 0 range 0 .. 0;
       EDMA_RESET at 0 range 1 .. 1;
       Reserved_2_31 at 0 range 2 .. 31;
     end record;

   --  Cache control register
   type CACHE_CONTROL_Register is record
      --  Set 1 to enable icache clock
      ICACHE_CLK_ON : Boolean := True;
      --  Set 1 to let icache reset
      ICACHE_RESET  : Boolean := False;
      --  Set 1 to enable dcache clock
      DCACHE_CLK_ON : Boolean := True;
      --  Set 1 to let dcache reset
      DCACHE_RESET  : Boolean := False;
      --  unspecified
      Reserved_4_31 : ESP32S3_Registers.UInt28 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CACHE_CONTROL_Register use
     record
       ICACHE_CLK_ON at 0 range 0 .. 0;
       ICACHE_RESET at 0 range 1 .. 1;
       DCACHE_CLK_ON at 0 range 2 .. 2;
       DCACHE_RESET at 0 range 3 .. 3;
       Reserved_4_31 at 0 range 4 .. 31;
     end record;

   --  External memory encrypt and decrypt control register
   type EXTERNAL_DEVICE_ENCRYPT_DECRYPT_CONTROL_Register is record
      --  Set 1 to enable the SPI manual encrypt.
      ENABLE_SPI_MANUAL_ENCRYPT      : Boolean := False;
      --  Set 1 to enable download DB encrypt.
      ENABLE_DOWNLOAD_DB_ENCRYPT     : Boolean := False;
      --  Set 1 to enable download G0CB decrypt
      ENABLE_DOWNLOAD_G0CB_DECRYPT   : Boolean := False;
      --  Set 1 to enable download manual encrypt
      ENABLE_DOWNLOAD_MANUAL_ENCRYPT : Boolean := False;
      --  unspecified
      Reserved_4_31                  : ESP32S3_Registers.UInt28 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for EXTERNAL_DEVICE_ENCRYPT_DECRYPT_CONTROL_Register use
     record
       ENABLE_SPI_MANUAL_ENCRYPT at 0 range 0 .. 0;
       ENABLE_DOWNLOAD_DB_ENCRYPT at 0 range 1 .. 1;
       ENABLE_DOWNLOAD_G0CB_DECRYPT at 0 range 2 .. 2;
       ENABLE_DOWNLOAD_MANUAL_ENCRYPT at 0 range 3 .. 3;
       Reserved_4_31 at 0 range 4 .. 31;
     end record;

   subtype RTC_FASTMEM_CONFIG_RTC_MEM_CRC_ADDR_Field is
     ESP32S3_Registers.UInt11;
   subtype RTC_FASTMEM_CONFIG_RTC_MEM_CRC_LEN_Field is
     ESP32S3_Registers.UInt11;

   --  RTC fast memory configuration register
   type RTC_FASTMEM_CONFIG_Register is record
      --  unspecified
      Reserved_0_7       : ESP32S3_Registers.Byte := 16#0#;
      --  Set 1 to start the CRC of RTC memory
      RTC_MEM_CRC_START  : Boolean := False;
      --  This field is used to set address of RTC memory for CRC.
      RTC_MEM_CRC_ADDR   : RTC_FASTMEM_CONFIG_RTC_MEM_CRC_ADDR_Field := 16#0#;
      --  This field is used to set length of RTC memory for CRC based on start
      --  address.
      RTC_MEM_CRC_LEN    : RTC_FASTMEM_CONFIG_RTC_MEM_CRC_LEN_Field := 16#7FF#;
      --  Read-only. This bit stores the status of RTC memory CRC.1 means
      --  finished.
      RTC_MEM_CRC_FINISH : Boolean := False;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for RTC_FASTMEM_CONFIG_Register use
     record
       Reserved_0_7 at 0 range 0 .. 7;
       RTC_MEM_CRC_START at 0 range 8 .. 8;
       RTC_MEM_CRC_ADDR at 0 range 9 .. 19;
       RTC_MEM_CRC_LEN at 0 range 20 .. 30;
       RTC_MEM_CRC_FINISH at 0 range 31 .. 31;
     end record;

   --  ******* Description ***********
   type REDUNDANT_ECO_CTRL_Register is record
      --  ******* Description ***********
      REDUNDANT_ECO_DRIVE  : Boolean := False;
      --  Read-only. ******* Description ***********
      REDUNDANT_ECO_RESULT : Boolean := False;
      --  unspecified
      Reserved_2_31        : ESP32S3_Registers.UInt30 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for REDUNDANT_ECO_CTRL_Register use
     record
       REDUNDANT_ECO_DRIVE at 0 range 0 .. 0;
       REDUNDANT_ECO_RESULT at 0 range 1 .. 1;
       Reserved_2_31 at 0 range 2 .. 31;
     end record;

   --  ******* Description ***********
   type CLOCK_GATE_Register is record
      --  ******* Description ***********
      CLK_EN        : Boolean := True;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for CLOCK_GATE_Register use
     record
       CLK_EN at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   subtype SYSCLK_CONF_PRE_DIV_CNT_Field is ESP32S3_Registers.UInt10;
   subtype SYSCLK_CONF_SOC_CLK_SEL_Field is ESP32S3_Registers.UInt2;
   subtype SYSCLK_CONF_CLK_XTAL_FREQ_Field is ESP32S3_Registers.UInt7;

   --  System clock configuration register.
   type SYSCLK_CONF_Register is record
      --  This field is used to set the count of prescaler of XTAL_CLK.
      PRE_DIV_CNT    : SYSCLK_CONF_PRE_DIV_CNT_Field := 16#1#;
      --  This field is used to select soc clock.
      SOC_CLK_SEL    : SYSCLK_CONF_SOC_CLK_SEL_Field := 16#0#;
      --  Read-only. This field is used to read xtal frequency in MHz.
      CLK_XTAL_FREQ  : SYSCLK_CONF_CLK_XTAL_FREQ_Field := 16#0#;
      --  Read-only. Reserved.
      CLK_DIV_EN     : Boolean := False;
      --  unspecified
      Reserved_20_31 : ESP32S3_Registers.UInt12 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for SYSCLK_CONF_Register use
     record
       PRE_DIV_CNT at 0 range 0 .. 9;
       SOC_CLK_SEL at 0 range 10 .. 11;
       CLK_XTAL_FREQ at 0 range 12 .. 18;
       CLK_DIV_EN at 0 range 19 .. 19;
       Reserved_20_31 at 0 range 20 .. 31;
     end record;

   subtype MEM_PVT_MEM_PATH_LEN_Field is ESP32S3_Registers.UInt4;
   subtype MEM_PVT_MEM_TIMING_ERR_CNT_Field is ESP32S3_Registers.UInt16;
   subtype MEM_PVT_MEM_VT_SEL_Field is ESP32S3_Registers.UInt2;

   --  ******* Description ***********
   type MEM_PVT_Register is record
      --  ******* Description ***********
      MEM_PATH_LEN       : MEM_PVT_MEM_PATH_LEN_Field := 16#3#;
      --  Write-only. ******* Description ***********
      MEM_ERR_CNT_CLR    : Boolean := False;
      --  ******* Description ***********
      MONITOR_EN         : Boolean := False;
      --  Read-only. ******* Description ***********
      MEM_TIMING_ERR_CNT : MEM_PVT_MEM_TIMING_ERR_CNT_Field := 16#0#;
      --  ******* Description ***********
      MEM_VT_SEL         : MEM_PVT_MEM_VT_SEL_Field := 16#0#;
      --  unspecified
      Reserved_24_31     : ESP32S3_Registers.Byte := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for MEM_PVT_Register use
     record
       MEM_PATH_LEN at 0 range 0 .. 3;
       MEM_ERR_CNT_CLR at 0 range 4 .. 4;
       MONITOR_EN at 0 range 5 .. 5;
       MEM_TIMING_ERR_CNT at 0 range 6 .. 21;
       MEM_VT_SEL at 0 range 22 .. 23;
       Reserved_24_31 at 0 range 24 .. 31;
     end record;

   subtype COMB_PVT_LVT_CONF_COMB_PATH_LEN_LVT_Field is
     ESP32S3_Registers.UInt5;

   --  ******* Description ***********
   type COMB_PVT_LVT_CONF_Register is record
      --  ******* Description ***********
      COMB_PATH_LEN_LVT       : COMB_PVT_LVT_CONF_COMB_PATH_LEN_LVT_Field :=
        16#3#;
      --  Write-only. ******* Description ***********
      COMB_ERR_CNT_CLR_LVT    : Boolean := False;
      --  ******* Description ***********
      COMB_PVT_MONITOR_EN_LVT : Boolean := False;
      --  unspecified
      Reserved_7_31           : ESP32S3_Registers.UInt25 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_LVT_CONF_Register use
     record
       COMB_PATH_LEN_LVT at 0 range 0 .. 4;
       COMB_ERR_CNT_CLR_LVT at 0 range 5 .. 5;
       COMB_PVT_MONITOR_EN_LVT at 0 range 6 .. 6;
       Reserved_7_31 at 0 range 7 .. 31;
     end record;

   subtype COMB_PVT_NVT_CONF_COMB_PATH_LEN_NVT_Field is
     ESP32S3_Registers.UInt5;

   --  ******* Description ***********
   type COMB_PVT_NVT_CONF_Register is record
      --  ******* Description ***********
      COMB_PATH_LEN_NVT       : COMB_PVT_NVT_CONF_COMB_PATH_LEN_NVT_Field :=
        16#3#;
      --  Write-only. ******* Description ***********
      COMB_ERR_CNT_CLR_NVT    : Boolean := False;
      --  ******* Description ***********
      COMB_PVT_MONITOR_EN_NVT : Boolean := False;
      --  unspecified
      Reserved_7_31           : ESP32S3_Registers.UInt25 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_NVT_CONF_Register use
     record
       COMB_PATH_LEN_NVT at 0 range 0 .. 4;
       COMB_ERR_CNT_CLR_NVT at 0 range 5 .. 5;
       COMB_PVT_MONITOR_EN_NVT at 0 range 6 .. 6;
       Reserved_7_31 at 0 range 7 .. 31;
     end record;

   subtype COMB_PVT_HVT_CONF_COMB_PATH_LEN_HVT_Field is
     ESP32S3_Registers.UInt5;

   --  ******* Description ***********
   type COMB_PVT_HVT_CONF_Register is record
      --  ******* Description ***********
      COMB_PATH_LEN_HVT       : COMB_PVT_HVT_CONF_COMB_PATH_LEN_HVT_Field :=
        16#3#;
      --  Write-only. ******* Description ***********
      COMB_ERR_CNT_CLR_HVT    : Boolean := False;
      --  ******* Description ***********
      COMB_PVT_MONITOR_EN_HVT : Boolean := False;
      --  unspecified
      Reserved_7_31           : ESP32S3_Registers.UInt25 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_HVT_CONF_Register use
     record
       COMB_PATH_LEN_HVT at 0 range 0 .. 4;
       COMB_ERR_CNT_CLR_HVT at 0 range 5 .. 5;
       COMB_PVT_MONITOR_EN_HVT at 0 range 6 .. 6;
       Reserved_7_31 at 0 range 7 .. 31;
     end record;

   subtype COMB_PVT_ERR_LVT_SITE0_COMB_TIMING_ERR_CNT_LVT_SITE0_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_LVT_SITE0_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_LVT_SITE0 :
        COMB_PVT_ERR_LVT_SITE0_COMB_TIMING_ERR_CNT_LVT_SITE0_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_LVT_SITE0_Register use
     record
       COMB_TIMING_ERR_CNT_LVT_SITE0 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_NVT_SITE0_COMB_TIMING_ERR_CNT_NVT_SITE0_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_NVT_SITE0_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_NVT_SITE0 :
        COMB_PVT_ERR_NVT_SITE0_COMB_TIMING_ERR_CNT_NVT_SITE0_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_NVT_SITE0_Register use
     record
       COMB_TIMING_ERR_CNT_NVT_SITE0 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_HVT_SITE0_COMB_TIMING_ERR_CNT_HVT_SITE0_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_HVT_SITE0_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_HVT_SITE0 :
        COMB_PVT_ERR_HVT_SITE0_COMB_TIMING_ERR_CNT_HVT_SITE0_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_HVT_SITE0_Register use
     record
       COMB_TIMING_ERR_CNT_HVT_SITE0 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_LVT_SITE1_COMB_TIMING_ERR_CNT_LVT_SITE1_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_LVT_SITE1_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_LVT_SITE1 :
        COMB_PVT_ERR_LVT_SITE1_COMB_TIMING_ERR_CNT_LVT_SITE1_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_LVT_SITE1_Register use
     record
       COMB_TIMING_ERR_CNT_LVT_SITE1 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_NVT_SITE1_COMB_TIMING_ERR_CNT_NVT_SITE1_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_NVT_SITE1_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_NVT_SITE1 :
        COMB_PVT_ERR_NVT_SITE1_COMB_TIMING_ERR_CNT_NVT_SITE1_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_NVT_SITE1_Register use
     record
       COMB_TIMING_ERR_CNT_NVT_SITE1 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_HVT_SITE1_COMB_TIMING_ERR_CNT_HVT_SITE1_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_HVT_SITE1_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_HVT_SITE1 :
        COMB_PVT_ERR_HVT_SITE1_COMB_TIMING_ERR_CNT_HVT_SITE1_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_HVT_SITE1_Register use
     record
       COMB_TIMING_ERR_CNT_HVT_SITE1 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_LVT_SITE2_COMB_TIMING_ERR_CNT_LVT_SITE2_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_LVT_SITE2_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_LVT_SITE2 :
        COMB_PVT_ERR_LVT_SITE2_COMB_TIMING_ERR_CNT_LVT_SITE2_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_LVT_SITE2_Register use
     record
       COMB_TIMING_ERR_CNT_LVT_SITE2 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_NVT_SITE2_COMB_TIMING_ERR_CNT_NVT_SITE2_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_NVT_SITE2_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_NVT_SITE2 :
        COMB_PVT_ERR_NVT_SITE2_COMB_TIMING_ERR_CNT_NVT_SITE2_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_NVT_SITE2_Register use
     record
       COMB_TIMING_ERR_CNT_NVT_SITE2 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_HVT_SITE2_COMB_TIMING_ERR_CNT_HVT_SITE2_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_HVT_SITE2_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_HVT_SITE2 :
        COMB_PVT_ERR_HVT_SITE2_COMB_TIMING_ERR_CNT_HVT_SITE2_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_HVT_SITE2_Register use
     record
       COMB_TIMING_ERR_CNT_HVT_SITE2 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_LVT_SITE3_COMB_TIMING_ERR_CNT_LVT_SITE3_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_LVT_SITE3_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_LVT_SITE3 :
        COMB_PVT_ERR_LVT_SITE3_COMB_TIMING_ERR_CNT_LVT_SITE3_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_LVT_SITE3_Register use
     record
       COMB_TIMING_ERR_CNT_LVT_SITE3 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_NVT_SITE3_COMB_TIMING_ERR_CNT_NVT_SITE3_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_NVT_SITE3_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_NVT_SITE3 :
        COMB_PVT_ERR_NVT_SITE3_COMB_TIMING_ERR_CNT_NVT_SITE3_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_NVT_SITE3_Register use
     record
       COMB_TIMING_ERR_CNT_NVT_SITE3 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype COMB_PVT_ERR_HVT_SITE3_COMB_TIMING_ERR_CNT_HVT_SITE3_Field is
     ESP32S3_Registers.UInt16;

   --  ******* Description ***********
   type COMB_PVT_ERR_HVT_SITE3_Register is record
      --  Read-only. ******* Description ***********
      COMB_TIMING_ERR_CNT_HVT_SITE3 :
        COMB_PVT_ERR_HVT_SITE3_COMB_TIMING_ERR_CNT_HVT_SITE3_Field;
      --  unspecified
      Reserved_16_31                : ESP32S3_Registers.UInt16;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for COMB_PVT_ERR_HVT_SITE3_Register use
     record
       COMB_TIMING_ERR_CNT_HVT_SITE3 at 0 range 0 .. 15;
       Reserved_16_31 at 0 range 16 .. 31;
     end record;

   subtype DATE_DATE_Field is ESP32S3_Registers.UInt28;

   --  version register
   type DATE_Register is record
      --  version register
      DATE           : DATE_DATE_Field := 16#2101220#;
      --  unspecified
      Reserved_28_31 : ESP32S3_Registers.UInt4 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => Standard.System.Low_Order_First;

   for DATE_Register use
     record
       DATE at 0 range 0 .. 27;
       Reserved_28_31 at 0 range 28 .. 31;
     end record;

   -----------------
   -- Peripherals --
   -----------------

   --  System Configuration Registers
   type SYSTEM_Peripheral is record
      --  Core0 control regiter 0
      CORE_1_CONTROL_0                        :
        aliased CORE_1_CONTROL_0_Register;
      --  Core0 control regiter 1
      CORE_1_CONTROL_1                        :
        aliased ESP32S3_Registers.UInt32;
      --  cpu_peripheral clock configuration register
      CPU_PERI_CLK_EN                         :
        aliased CPU_PERI_CLK_EN_Register;
      --  cpu_peripheral reset configuration regsiter
      CPU_PERI_RST_EN                         :
        aliased CPU_PERI_RST_EN_Register;
      --  cpu peripheral clock configuration register
      CPU_PER_CONF                            : aliased CPU_PER_CONF_Register;
      --  memory power down mask configuration register
      MEM_PD_MASK                             : aliased MEM_PD_MASK_Register;
      --  peripheral clock configuration regsiter 0
      PERIP_CLK_EN0                           : aliased PERIP_CLK_EN0_Register;
      --  peripheral clock configuration regsiter 1
      PERIP_CLK_EN1                           : aliased PERIP_CLK_EN1_Register;
      --  peripheral reset configuration register0
      PERIP_RST_EN0                           : aliased PERIP_RST_EN0_Register;
      --  peripheral reset configuration regsiter 1
      PERIP_RST_EN1                           : aliased PERIP_RST_EN1_Register;
      --  low power clock frequent division factor configuration regsiter
      BT_LPCK_DIV_INT                         :
        aliased BT_LPCK_DIV_INT_Register;
      --  low power clock configuration register
      BT_LPCK_DIV_FRAC                        :
        aliased BT_LPCK_DIV_FRAC_Register;
      --  interrupt source register 0
      CPU_INTR_FROM_CPU_0                     :
        aliased CPU_INTR_FROM_CPU_0_Register;
      --  interrupt source register 1
      CPU_INTR_FROM_CPU_1                     :
        aliased CPU_INTR_FROM_CPU_1_Register;
      --  interrupt source register 2
      CPU_INTR_FROM_CPU_2                     :
        aliased CPU_INTR_FROM_CPU_2_Register;
      --  interrupt source register 3
      CPU_INTR_FROM_CPU_3                     :
        aliased CPU_INTR_FROM_CPU_3_Register;
      --  rsa memory power control register
      RSA_PD_CTRL                             : aliased RSA_PD_CTRL_Register;
      --  EDMA control register
      EDMA_CTRL                               : aliased EDMA_CTRL_Register;
      --  Cache control register
      CACHE_CONTROL                           : aliased CACHE_CONTROL_Register;
      --  External memory encrypt and decrypt control register
      EXTERNAL_DEVICE_ENCRYPT_DECRYPT_CONTROL :
        aliased EXTERNAL_DEVICE_ENCRYPT_DECRYPT_CONTROL_Register;
      --  RTC fast memory configuration register
      RTC_FASTMEM_CONFIG                      :
        aliased RTC_FASTMEM_CONFIG_Register;
      --  RTC fast memory CRC control register
      RTC_FASTMEM_CRC                         :
        aliased ESP32S3_Registers.UInt32;
      --  ******* Description ***********
      REDUNDANT_ECO_CTRL                      :
        aliased REDUNDANT_ECO_CTRL_Register;
      --  ******* Description ***********
      CLOCK_GATE                              : aliased CLOCK_GATE_Register;
      --  System clock configuration register.
      SYSCLK_CONF                             : aliased SYSCLK_CONF_Register;
      --  ******* Description ***********
      MEM_PVT                                 : aliased MEM_PVT_Register;
      --  ******* Description ***********
      COMB_PVT_LVT_CONF                       :
        aliased COMB_PVT_LVT_CONF_Register;
      --  ******* Description ***********
      COMB_PVT_NVT_CONF                       :
        aliased COMB_PVT_NVT_CONF_Register;
      --  ******* Description ***********
      COMB_PVT_HVT_CONF                       :
        aliased COMB_PVT_HVT_CONF_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_LVT_SITE0                  :
        aliased COMB_PVT_ERR_LVT_SITE0_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_NVT_SITE0                  :
        aliased COMB_PVT_ERR_NVT_SITE0_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_HVT_SITE0                  :
        aliased COMB_PVT_ERR_HVT_SITE0_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_LVT_SITE1                  :
        aliased COMB_PVT_ERR_LVT_SITE1_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_NVT_SITE1                  :
        aliased COMB_PVT_ERR_NVT_SITE1_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_HVT_SITE1                  :
        aliased COMB_PVT_ERR_HVT_SITE1_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_LVT_SITE2                  :
        aliased COMB_PVT_ERR_LVT_SITE2_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_NVT_SITE2                  :
        aliased COMB_PVT_ERR_NVT_SITE2_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_HVT_SITE2                  :
        aliased COMB_PVT_ERR_HVT_SITE2_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_LVT_SITE3                  :
        aliased COMB_PVT_ERR_LVT_SITE3_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_NVT_SITE3                  :
        aliased COMB_PVT_ERR_NVT_SITE3_Register;
      --  ******* Description ***********
      COMB_PVT_ERR_HVT_SITE3                  :
        aliased COMB_PVT_ERR_HVT_SITE3_Register;
      --  version register
      DATE                                    : aliased DATE_Register;
   end record
   with Volatile;

   for SYSTEM_Peripheral use
     record
       CORE_1_CONTROL_0 at 16#0# range 0 .. 31;
       CORE_1_CONTROL_1 at 16#4# range 0 .. 31;
       CPU_PERI_CLK_EN at 16#8# range 0 .. 31;
       CPU_PERI_RST_EN at 16#C# range 0 .. 31;
       CPU_PER_CONF at 16#10# range 0 .. 31;
       MEM_PD_MASK at 16#14# range 0 .. 31;
       PERIP_CLK_EN0 at 16#18# range 0 .. 31;
       PERIP_CLK_EN1 at 16#1C# range 0 .. 31;
       PERIP_RST_EN0 at 16#20# range 0 .. 31;
       PERIP_RST_EN1 at 16#24# range 0 .. 31;
       BT_LPCK_DIV_INT at 16#28# range 0 .. 31;
       BT_LPCK_DIV_FRAC at 16#2C# range 0 .. 31;
       CPU_INTR_FROM_CPU_0 at 16#30# range 0 .. 31;
       CPU_INTR_FROM_CPU_1 at 16#34# range 0 .. 31;
       CPU_INTR_FROM_CPU_2 at 16#38# range 0 .. 31;
       CPU_INTR_FROM_CPU_3 at 16#3C# range 0 .. 31;
       RSA_PD_CTRL at 16#40# range 0 .. 31;
       EDMA_CTRL at 16#44# range 0 .. 31;
       CACHE_CONTROL at 16#48# range 0 .. 31;
       EXTERNAL_DEVICE_ENCRYPT_DECRYPT_CONTROL at 16#4C# range 0 .. 31;
       RTC_FASTMEM_CONFIG at 16#50# range 0 .. 31;
       RTC_FASTMEM_CRC at 16#54# range 0 .. 31;
       REDUNDANT_ECO_CTRL at 16#58# range 0 .. 31;
       CLOCK_GATE at 16#5C# range 0 .. 31;
       SYSCLK_CONF at 16#60# range 0 .. 31;
       MEM_PVT at 16#64# range 0 .. 31;
       COMB_PVT_LVT_CONF at 16#68# range 0 .. 31;
       COMB_PVT_NVT_CONF at 16#6C# range 0 .. 31;
       COMB_PVT_HVT_CONF at 16#70# range 0 .. 31;
       COMB_PVT_ERR_LVT_SITE0 at 16#74# range 0 .. 31;
       COMB_PVT_ERR_NVT_SITE0 at 16#78# range 0 .. 31;
       COMB_PVT_ERR_HVT_SITE0 at 16#7C# range 0 .. 31;
       COMB_PVT_ERR_LVT_SITE1 at 16#80# range 0 .. 31;
       COMB_PVT_ERR_NVT_SITE1 at 16#84# range 0 .. 31;
       COMB_PVT_ERR_HVT_SITE1 at 16#88# range 0 .. 31;
       COMB_PVT_ERR_LVT_SITE2 at 16#8C# range 0 .. 31;
       COMB_PVT_ERR_NVT_SITE2 at 16#90# range 0 .. 31;
       COMB_PVT_ERR_HVT_SITE2 at 16#94# range 0 .. 31;
       COMB_PVT_ERR_LVT_SITE3 at 16#98# range 0 .. 31;
       COMB_PVT_ERR_NVT_SITE3 at 16#9C# range 0 .. 31;
       COMB_PVT_ERR_HVT_SITE3 at 16#A0# range 0 .. 31;
       DATE at 16#FFC# range 0 .. 31;
     end record;

   --  System Configuration Registers
   SYSTEM_Periph : aliased SYSTEM_Peripheral
   with Import, Address => SYSTEM_Base;

end ESP32S3_Registers.SYSTEM;
