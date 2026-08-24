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

package ESP32S3_Registers.INTERRUPT_CORE0 is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype PRO_MAC_INTR_MAP_MAC_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  mac interrupt configuration register
   type PRO_MAC_INTR_MAP_Register is record
      --  this register used to map mac interrupt to one of core0's external
      --  interrupt
      MAC_INTR_MAP  : PRO_MAC_INTR_MAP_MAC_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PRO_MAC_INTR_MAP_Register use
     record
       MAC_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype MAC_NMI_MAP_MAC_NMI_MAP_Field is ESP32S3_Registers.UInt5;

   --  mac_nmi interrupt configuration register
   type MAC_NMI_MAP_Register is record
      --  this register used to map_nmi interrupt to one of core0's external
      --  interrupt
      MAC_NMI_MAP   : MAC_NMI_MAP_MAC_NMI_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for MAC_NMI_MAP_Register use
     record
       MAC_NMI_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype PWR_INTR_MAP_PWR_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  pwr interrupt configuration register
   type PWR_INTR_MAP_Register is record
      --  this register used to map pwr interrupt to one of core0's external
      --  interrupt
      PWR_INTR_MAP  : PWR_INTR_MAP_PWR_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PWR_INTR_MAP_Register use
     record
       PWR_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype BB_INT_MAP_BB_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  bb interrupt configuration register
   type BB_INT_MAP_Register is record
      --  this register used to map bb interrupt to one of core0's external
      --  interrupt
      BB_INT_MAP    : BB_INT_MAP_BB_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for BB_INT_MAP_Register use
     record
       BB_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype BT_MAC_INT_MAP_BT_MAC_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  bb_mac interrupt configuration register
   type BT_MAC_INT_MAP_Register is record
      --  this register used to map bb_mac interrupt to one of core0's external
      --  interrupt
      BT_MAC_INT_MAP : BT_MAC_INT_MAP_BT_MAC_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for BT_MAC_INT_MAP_Register use
     record
       BT_MAC_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype BT_BB_INT_MAP_BT_BB_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  bt_bb interrupt configuration register
   type BT_BB_INT_MAP_Register is record
      --  this register used to map bt_bb interrupt to one of core0's external
      --  interrupt
      BT_BB_INT_MAP : BT_BB_INT_MAP_BT_BB_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for BT_BB_INT_MAP_Register use
     record
       BT_BB_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype BT_BB_NMI_MAP_BT_BB_NMI_MAP_Field is ESP32S3_Registers.UInt5;

   --  bt_bb_nmi interrupt configuration register
   type BT_BB_NMI_MAP_Register is record
      --  this register used to map bb_bt_nmi interrupt to one of core0's
      --  external interrupt
      BT_BB_NMI_MAP : BT_BB_NMI_MAP_BT_BB_NMI_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for BT_BB_NMI_MAP_Register use
     record
       BT_BB_NMI_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype RWBT_IRQ_MAP_RWBT_IRQ_MAP_Field is ESP32S3_Registers.UInt5;

   --  rwbt_irq interrupt configuration register
   type RWBT_IRQ_MAP_Register is record
      --  this register used to map rwbt_irq interrupt to one of core0's
      --  external interrupt
      RWBT_IRQ_MAP  : RWBT_IRQ_MAP_RWBT_IRQ_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RWBT_IRQ_MAP_Register use
     record
       RWBT_IRQ_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype RWBLE_IRQ_MAP_RWBLE_IRQ_MAP_Field is ESP32S3_Registers.UInt5;

   --  rwble_irq interrupt configuration register
   type RWBLE_IRQ_MAP_Register is record
      --  this register used to map rwble_irq interrupt to one of core0's
      --  external interrupt
      RWBLE_IRQ_MAP : RWBLE_IRQ_MAP_RWBLE_IRQ_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RWBLE_IRQ_MAP_Register use
     record
       RWBLE_IRQ_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype RWBT_NMI_MAP_RWBT_NMI_MAP_Field is ESP32S3_Registers.UInt5;

   --  rwbt_nmi interrupt configuration register
   type RWBT_NMI_MAP_Register is record
      --  this register used to map mac rwbt_nmi to one of core0's external
      --  interrupt
      RWBT_NMI_MAP  : RWBT_NMI_MAP_RWBT_NMI_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RWBT_NMI_MAP_Register use
     record
       RWBT_NMI_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype RWBLE_NMI_MAP_RWBLE_NMI_MAP_Field is ESP32S3_Registers.UInt5;

   --  rwble_nmi interrupt configuration register
   type RWBLE_NMI_MAP_Register is record
      --  this register used to map rwble_nmi interrupt to one of core0's
      --  external interrupt
      RWBLE_NMI_MAP : RWBLE_NMI_MAP_RWBLE_NMI_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RWBLE_NMI_MAP_Register use
     record
       RWBLE_NMI_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype I2C_MST_INT_MAP_I2C_MST_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  i2c_mst interrupt configuration register
   type I2C_MST_INT_MAP_Register is record
      --  this register used to map i2c_mst interrupt to one of core0's
      --  external interrupt
      I2C_MST_INT_MAP : I2C_MST_INT_MAP_I2C_MST_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31   : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for I2C_MST_INT_MAP_Register use
     record
       I2C_MST_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SLC0_INTR_MAP_SLC0_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  slc0 interrupt configuration register
   type SLC0_INTR_MAP_Register is record
      --  this register used to map slc0 interrupt to one of core0's external
      --  interrupt
      SLC0_INTR_MAP : SLC0_INTR_MAP_SLC0_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SLC0_INTR_MAP_Register use
     record
       SLC0_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SLC1_INTR_MAP_SLC1_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  slc1 interrupt configuration register
   type SLC1_INTR_MAP_Register is record
      --  this register used to map slc1 interrupt to one of core0's external
      --  interrupt
      SLC1_INTR_MAP : SLC1_INTR_MAP_SLC1_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SLC1_INTR_MAP_Register use
     record
       SLC1_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype UHCI0_INTR_MAP_UHCI0_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  uhci0 interrupt configuration register
   type UHCI0_INTR_MAP_Register is record
      --  this register used to map uhci0 interrupt to one of core0's external
      --  interrupt
      UHCI0_INTR_MAP : UHCI0_INTR_MAP_UHCI0_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for UHCI0_INTR_MAP_Register use
     record
       UHCI0_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype UHCI1_INTR_MAP_UHCI1_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  uhci1 interrupt configuration register
   type UHCI1_INTR_MAP_Register is record
      --  this register used to map uhci1 interrupt to one of core0's external
      --  interrupt
      UHCI1_INTR_MAP : UHCI1_INTR_MAP_UHCI1_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for UHCI1_INTR_MAP_Register use
     record
       UHCI1_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype GPIO_INTERRUPT_PRO_MAP_GPIO_INTERRUPT_PRO_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  gpio_interrupt_pro interrupt configuration register
   type GPIO_INTERRUPT_PRO_MAP_Register is record
      --  this register used to map gpio_interrupt_pro interrupt to one of
      --  core0's external interrupt
      GPIO_INTERRUPT_PRO_MAP :
        GPIO_INTERRUPT_PRO_MAP_GPIO_INTERRUPT_PRO_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31          : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for GPIO_INTERRUPT_PRO_MAP_Register use
     record
       GPIO_INTERRUPT_PRO_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype GPIO_INTERRUPT_PRO_NMI_MAP_GPIO_INTERRUPT_PRO_NMI_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  gpio_interrupt_pro_nmi interrupt configuration register
   type GPIO_INTERRUPT_PRO_NMI_MAP_Register is record
      --  this register used to map gpio_interrupt_pro_nmi interrupt to one of
      --  core0's external interrupt
      GPIO_INTERRUPT_PRO_NMI_MAP :
        GPIO_INTERRUPT_PRO_NMI_MAP_GPIO_INTERRUPT_PRO_NMI_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31              : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for GPIO_INTERRUPT_PRO_NMI_MAP_Register use
     record
       GPIO_INTERRUPT_PRO_NMI_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype GPIO_INTERRUPT_APP_MAP_GPIO_INTERRUPT_APP_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  gpio_interrupt_app interrupt configuration register
   type GPIO_INTERRUPT_APP_MAP_Register is record
      --  this register used to map gpio_interrupt_app interrupt to one of
      --  core0's external interrupt
      GPIO_INTERRUPT_APP_MAP :
        GPIO_INTERRUPT_APP_MAP_GPIO_INTERRUPT_APP_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31          : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for GPIO_INTERRUPT_APP_MAP_Register use
     record
       GPIO_INTERRUPT_APP_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype GPIO_INTERRUPT_APP_NMI_MAP_GPIO_INTERRUPT_APP_NMI_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  gpio_interrupt_app_nmi interrupt configuration register
   type GPIO_INTERRUPT_APP_NMI_MAP_Register is record
      --  this register used to map gpio_interrupt_app_nmi interrupt to one of
      --  core0's external interrupt
      GPIO_INTERRUPT_APP_NMI_MAP :
        GPIO_INTERRUPT_APP_NMI_MAP_GPIO_INTERRUPT_APP_NMI_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31              : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for GPIO_INTERRUPT_APP_NMI_MAP_Register use
     record
       GPIO_INTERRUPT_APP_NMI_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SPI_INTR_1_MAP_SPI_INTR_1_MAP_Field is ESP32S3_Registers.UInt5;

   --  spi_intr_1 interrupt configuration register
   type SPI_INTR_1_MAP_Register is record
      --  this register used to map spi_intr_1 interrupt to one of core0's
      --  external interrupt
      SPI_INTR_1_MAP : SPI_INTR_1_MAP_SPI_INTR_1_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SPI_INTR_1_MAP_Register use
     record
       SPI_INTR_1_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SPI_INTR_2_MAP_SPI_INTR_2_MAP_Field is ESP32S3_Registers.UInt5;

   --  spi_intr_2 interrupt configuration register
   type SPI_INTR_2_MAP_Register is record
      --  this register used to map spi_intr_2 interrupt to one of core0's
      --  external interrupt
      SPI_INTR_2_MAP : SPI_INTR_2_MAP_SPI_INTR_2_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SPI_INTR_2_MAP_Register use
     record
       SPI_INTR_2_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SPI_INTR_3_MAP_SPI_INTR_3_MAP_Field is ESP32S3_Registers.UInt5;

   --  spi_intr_3 interrupt configuration register
   type SPI_INTR_3_MAP_Register is record
      --  this register used to map spi_intr_3 interrupt to one of core0's
      --  external interrupt
      SPI_INTR_3_MAP : SPI_INTR_3_MAP_SPI_INTR_3_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SPI_INTR_3_MAP_Register use
     record
       SPI_INTR_3_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SPI_INTR_4_MAP_SPI_INTR_4_MAP_Field is ESP32S3_Registers.UInt5;

   --  spi_intr_4 interrupt configuration register
   type SPI_INTR_4_MAP_Register is record
      --  this register used to map spi_intr_4 interrupt to one of core0's
      --  external interrupt
      SPI_INTR_4_MAP : SPI_INTR_4_MAP_SPI_INTR_4_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SPI_INTR_4_MAP_Register use
     record
       SPI_INTR_4_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype LCD_CAM_INT_MAP_LCD_CAM_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  lcd_cam interrupt configuration register
   type LCD_CAM_INT_MAP_Register is record
      --  this register used to map lcd_cam interrupt to one of core0's
      --  external interrupt
      LCD_CAM_INT_MAP : LCD_CAM_INT_MAP_LCD_CAM_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31   : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for LCD_CAM_INT_MAP_Register use
     record
       LCD_CAM_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype I2S0_INT_MAP_I2S0_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  i2s0 interrupt configuration register
   type I2S0_INT_MAP_Register is record
      --  this register used to map i2s0 interrupt to one of core0's external
      --  interrupt
      I2S0_INT_MAP  : I2S0_INT_MAP_I2S0_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for I2S0_INT_MAP_Register use
     record
       I2S0_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype I2S1_INT_MAP_I2S1_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  i2s1 interrupt configuration register
   type I2S1_INT_MAP_Register is record
      --  this register used to map i2s1 interrupt to one of core0's external
      --  interrupt
      I2S1_INT_MAP  : I2S1_INT_MAP_I2S1_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for I2S1_INT_MAP_Register use
     record
       I2S1_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype UART_INTR_MAP_UART_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  uart interrupt configuration register
   type UART_INTR_MAP_Register is record
      --  this register used to map uart interrupt to one of core0's external
      --  interrupt
      UART_INTR_MAP : UART_INTR_MAP_UART_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for UART_INTR_MAP_Register use
     record
       UART_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype UART1_INTR_MAP_UART1_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  uart1 interrupt configuration register
   type UART1_INTR_MAP_Register is record
      --  this register used to map uart1 interrupt to one of core0's external
      --  interrupt
      UART1_INTR_MAP : UART1_INTR_MAP_UART1_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for UART1_INTR_MAP_Register use
     record
       UART1_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype UART2_INTR_MAP_UART2_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  uart2 interrupt configuration register
   type UART2_INTR_MAP_Register is record
      --  this register used to map uart2 interrupt to one of core0's external
      --  interrupt
      UART2_INTR_MAP : UART2_INTR_MAP_UART2_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for UART2_INTR_MAP_Register use
     record
       UART2_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SDIO_HOST_INTERRUPT_MAP_SDIO_HOST_INTERRUPT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  sdio_host interrupt configuration register
   type SDIO_HOST_INTERRUPT_MAP_Register is record
      --  this register used to map sdio_host interrupt to one of core0's
      --  external interrupt
      SDIO_HOST_INTERRUPT_MAP :
        SDIO_HOST_INTERRUPT_MAP_SDIO_HOST_INTERRUPT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SDIO_HOST_INTERRUPT_MAP_Register use
     record
       SDIO_HOST_INTERRUPT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype PWM0_INTR_MAP_PWM0_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  pwm0 interrupt configuration register
   type PWM0_INTR_MAP_Register is record
      --  this register used to map pwm0 interrupt to one of core0's external
      --  interrupt
      PWM0_INTR_MAP : PWM0_INTR_MAP_PWM0_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PWM0_INTR_MAP_Register use
     record
       PWM0_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype PWM1_INTR_MAP_PWM1_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  pwm1 interrupt configuration register
   type PWM1_INTR_MAP_Register is record
      --  this register used to map pwm1 interrupt to one of core0's external
      --  interrupt
      PWM1_INTR_MAP : PWM1_INTR_MAP_PWM1_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PWM1_INTR_MAP_Register use
     record
       PWM1_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype PWM2_INTR_MAP_PWM2_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  pwm2 interrupt configuration register
   type PWM2_INTR_MAP_Register is record
      --  this register used to map pwm2 interrupt to one of core0's external
      --  interrupt
      PWM2_INTR_MAP : PWM2_INTR_MAP_PWM2_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PWM2_INTR_MAP_Register use
     record
       PWM2_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype PWM3_INTR_MAP_PWM3_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  pwm3 interrupt configuration register
   type PWM3_INTR_MAP_Register is record
      --  this register used to map pwm3 interrupt to one of core0's external
      --  interrupt
      PWM3_INTR_MAP : PWM3_INTR_MAP_PWM3_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PWM3_INTR_MAP_Register use
     record
       PWM3_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype LEDC_INT_MAP_LEDC_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  ledc interrupt configuration register
   type LEDC_INT_MAP_Register is record
      --  this register used to map ledc interrupt to one of core0's external
      --  interrupt
      LEDC_INT_MAP  : LEDC_INT_MAP_LEDC_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for LEDC_INT_MAP_Register use
     record
       LEDC_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype EFUSE_INT_MAP_EFUSE_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  efuse interrupt configuration register
   type EFUSE_INT_MAP_Register is record
      --  this register used to map efuse interrupt to one of core0's external
      --  interrupt
      EFUSE_INT_MAP : EFUSE_INT_MAP_EFUSE_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for EFUSE_INT_MAP_Register use
     record
       EFUSE_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CAN_INT_MAP_CAN_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  can interrupt configuration register
   type CAN_INT_MAP_Register is record
      --  this register used to map can interrupt to one of core0's external
      --  interrupt
      CAN_INT_MAP   : CAN_INT_MAP_CAN_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CAN_INT_MAP_Register use
     record
       CAN_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype USB_INTR_MAP_USB_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  usb interrupt configuration register
   type USB_INTR_MAP_Register is record
      --  this register used to map usb interrupt to one of core0's external
      --  interrupt
      USB_INTR_MAP  : USB_INTR_MAP_USB_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for USB_INTR_MAP_Register use
     record
       USB_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype RTC_CORE_INTR_MAP_RTC_CORE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  rtc_core interrupt configuration register
   type RTC_CORE_INTR_MAP_Register is record
      --  this register used to map rtc_core interrupt to one of core0's
      --  external interrupt
      RTC_CORE_INTR_MAP : RTC_CORE_INTR_MAP_RTC_CORE_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31     : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RTC_CORE_INTR_MAP_Register use
     record
       RTC_CORE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype RMT_INTR_MAP_RMT_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  rmt interrupt configuration register
   type RMT_INTR_MAP_Register is record
      --  this register used to map rmt interrupt to one of core0's external
      --  interrupt
      RMT_INTR_MAP  : RMT_INTR_MAP_RMT_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RMT_INTR_MAP_Register use
     record
       RMT_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype PCNT_INTR_MAP_PCNT_INTR_MAP_Field is ESP32S3_Registers.UInt5;

   --  pcnt interrupt configuration register
   type PCNT_INTR_MAP_Register is record
      --  this register used to map pcnt interrupt to one of core0's external
      --  interrupt
      PCNT_INTR_MAP : PCNT_INTR_MAP_PCNT_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PCNT_INTR_MAP_Register use
     record
       PCNT_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype I2C_EXT0_INTR_MAP_I2C_EXT0_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  i2c_ext0 interrupt configuration register
   type I2C_EXT0_INTR_MAP_Register is record
      --  this register used to map i2c_ext0 interrupt to one of core0's
      --  external interrupt
      I2C_EXT0_INTR_MAP : I2C_EXT0_INTR_MAP_I2C_EXT0_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31     : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for I2C_EXT0_INTR_MAP_Register use
     record
       I2C_EXT0_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype I2C_EXT1_INTR_MAP_I2C_EXT1_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  i2c_ext1 interrupt configuration register
   type I2C_EXT1_INTR_MAP_Register is record
      --  this register used to map i2c_ext1 interrupt to one of core0's
      --  external interrupt
      I2C_EXT1_INTR_MAP : I2C_EXT1_INTR_MAP_I2C_EXT1_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31     : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for I2C_EXT1_INTR_MAP_Register use
     record
       I2C_EXT1_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SPI2_DMA_INT_MAP_SPI2_DMA_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  spi2_dma interrupt configuration register
   type SPI2_DMA_INT_MAP_Register is record
      --  this register used to map spi2_dma interrupt to one of core0's
      --  external interrupt
      SPI2_DMA_INT_MAP : SPI2_DMA_INT_MAP_SPI2_DMA_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31    : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SPI2_DMA_INT_MAP_Register use
     record
       SPI2_DMA_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SPI3_DMA_INT_MAP_SPI3_DMA_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  spi3_dma interrupt configuration register
   type SPI3_DMA_INT_MAP_Register is record
      --  this register used to map spi3_dma interrupt to one of core0's
      --  external interrupt
      SPI3_DMA_INT_MAP : SPI3_DMA_INT_MAP_SPI3_DMA_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31    : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SPI3_DMA_INT_MAP_Register use
     record
       SPI3_DMA_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SPI4_DMA_INT_MAP_SPI4_DMA_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  spi4_dma interrupt configuration register
   type SPI4_DMA_INT_MAP_Register is record
      --  this register used to map spi4_dma interrupt to one of core0's
      --  external interrupt
      SPI4_DMA_INT_MAP : SPI4_DMA_INT_MAP_SPI4_DMA_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31    : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SPI4_DMA_INT_MAP_Register use
     record
       SPI4_DMA_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype WDG_INT_MAP_WDG_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  wdg interrupt configuration register
   type WDG_INT_MAP_Register is record
      --  this register used to map wdg interrupt to one of core0's external
      --  interrupt
      WDG_INT_MAP   : WDG_INT_MAP_WDG_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for WDG_INT_MAP_Register use
     record
       WDG_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype TIMER_INT1_MAP_TIMER_INT1_MAP_Field is ESP32S3_Registers.UInt5;

   --  timer_int1 interrupt configuration register
   type TIMER_INT1_MAP_Register is record
      --  this register used to map timer_int1 interrupt to one of core0's
      --  external interrupt
      TIMER_INT1_MAP : TIMER_INT1_MAP_TIMER_INT1_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIMER_INT1_MAP_Register use
     record
       TIMER_INT1_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype TIMER_INT2_MAP_TIMER_INT2_MAP_Field is ESP32S3_Registers.UInt5;

   --  timer_int2 interrupt configuration register
   type TIMER_INT2_MAP_Register is record
      --  this register used to map timer_int2 interrupt to one of core0's
      --  external interrupt
      TIMER_INT2_MAP : TIMER_INT2_MAP_TIMER_INT2_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TIMER_INT2_MAP_Register use
     record
       TIMER_INT2_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype TG_T0_INT_MAP_TG_T0_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  tg_t0 interrupt configuration register
   type TG_T0_INT_MAP_Register is record
      --  this register used to map tg_t0 interrupt to one of core0's external
      --  interrupt
      TG_T0_INT_MAP : TG_T0_INT_MAP_TG_T0_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TG_T0_INT_MAP_Register use
     record
       TG_T0_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype TG_T1_INT_MAP_TG_T1_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  tg_t1 interrupt configuration register
   type TG_T1_INT_MAP_Register is record
      --  this register used to map tg_t1 interrupt to one of core0's external
      --  interrupt
      TG_T1_INT_MAP : TG_T1_INT_MAP_TG_T1_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TG_T1_INT_MAP_Register use
     record
       TG_T1_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype TG_WDT_INT_MAP_TG_WDT_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  tg_wdt interrupt configuration register
   type TG_WDT_INT_MAP_Register is record
      --  this register used to map rg_wdt interrupt to one of core0's external
      --  interrupt
      TG_WDT_INT_MAP : TG_WDT_INT_MAP_TG_WDT_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TG_WDT_INT_MAP_Register use
     record
       TG_WDT_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype TG1_T0_INT_MAP_TG1_T0_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  tg1_t0 interrupt configuration register
   type TG1_T0_INT_MAP_Register is record
      --  this register used to map tg1_t0 interrupt to one of core0's external
      --  interrupt
      TG1_T0_INT_MAP : TG1_T0_INT_MAP_TG1_T0_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TG1_T0_INT_MAP_Register use
     record
       TG1_T0_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype TG1_T1_INT_MAP_TG1_T1_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  tg1_t1 interrupt configuration register
   type TG1_T1_INT_MAP_Register is record
      --  this register used to map tg1_t1 interrupt to one of core0's external
      --  interrupt
      TG1_T1_INT_MAP : TG1_T1_INT_MAP_TG1_T1_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31  : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TG1_T1_INT_MAP_Register use
     record
       TG1_T1_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype TG1_WDT_INT_MAP_TG1_WDT_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  tg1_wdt interrupt configuration register
   type TG1_WDT_INT_MAP_Register is record
      --  this register used to map tg1_wdt interrupt to one of core0's
      --  external interrupt
      TG1_WDT_INT_MAP : TG1_WDT_INT_MAP_TG1_WDT_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31   : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for TG1_WDT_INT_MAP_Register use
     record
       TG1_WDT_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CACHE_IA_INT_MAP_CACHE_IA_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  cache_ia interrupt configuration register
   type CACHE_IA_INT_MAP_Register is record
      --  this register used to map cache_ia interrupt to one of core0's
      --  external interrupt
      CACHE_IA_INT_MAP : CACHE_IA_INT_MAP_CACHE_IA_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31    : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CACHE_IA_INT_MAP_Register use
     record
       CACHE_IA_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SYSTIMER_TARGET0_INT_MAP_SYSTIMER_TARGET0_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  systimer_target0 interrupt configuration register
   type SYSTIMER_TARGET0_INT_MAP_Register is record
      --  this register used to map systimer_target0 interrupt to one of
      --  core0's external interrupt
      SYSTIMER_TARGET0_INT_MAP :
        SYSTIMER_TARGET0_INT_MAP_SYSTIMER_TARGET0_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31            : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SYSTIMER_TARGET0_INT_MAP_Register use
     record
       SYSTIMER_TARGET0_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SYSTIMER_TARGET1_INT_MAP_SYSTIMER_TARGET1_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  systimer_target1 interrupt configuration register
   type SYSTIMER_TARGET1_INT_MAP_Register is record
      --  this register used to map systimer_target1 interrupt to one of
      --  core0's external interrupt
      SYSTIMER_TARGET1_INT_MAP :
        SYSTIMER_TARGET1_INT_MAP_SYSTIMER_TARGET1_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31            : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SYSTIMER_TARGET1_INT_MAP_Register use
     record
       SYSTIMER_TARGET1_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SYSTIMER_TARGET2_INT_MAP_SYSTIMER_TARGET2_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  systimer_target2 interrupt configuration register
   type SYSTIMER_TARGET2_INT_MAP_Register is record
      --  this register used to map systimer_target2 interrupt to one of
      --  core0's external interrupt
      SYSTIMER_TARGET2_INT_MAP :
        SYSTIMER_TARGET2_INT_MAP_SYSTIMER_TARGET2_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31            : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SYSTIMER_TARGET2_INT_MAP_Register use
     record
       SYSTIMER_TARGET2_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SPI_MEM_REJECT_INTR_MAP_SPI_MEM_REJECT_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  spi_mem_reject interrupt configuration register
   type SPI_MEM_REJECT_INTR_MAP_Register is record
      --  this register used to map spi_mem_reject interrupt to one of core0's
      --  external interrupt
      SPI_MEM_REJECT_INTR_MAP :
        SPI_MEM_REJECT_INTR_MAP_SPI_MEM_REJECT_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SPI_MEM_REJECT_INTR_MAP_Register use
     record
       SPI_MEM_REJECT_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DCACHE_PRELOAD_INT_MAP_DCACHE_PRELOAD_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dcache_prelaod interrupt configuration register
   type DCACHE_PRELOAD_INT_MAP_Register is record
      --  this register used to map dcache_prelaod interrupt to one of core0's
      --  external interrupt
      DCACHE_PRELOAD_INT_MAP :
        DCACHE_PRELOAD_INT_MAP_DCACHE_PRELOAD_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31          : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DCACHE_PRELOAD_INT_MAP_Register use
     record
       DCACHE_PRELOAD_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype ICACHE_PRELOAD_INT_MAP_ICACHE_PRELOAD_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  icache_preload interrupt configuration register
   type ICACHE_PRELOAD_INT_MAP_Register is record
      --  this register used to map icache_preload interrupt to one of core0's
      --  external interrupt
      ICACHE_PRELOAD_INT_MAP :
        ICACHE_PRELOAD_INT_MAP_ICACHE_PRELOAD_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31          : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ICACHE_PRELOAD_INT_MAP_Register use
     record
       ICACHE_PRELOAD_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DCACHE_SYNC_INT_MAP_DCACHE_SYNC_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dcache_sync interrupt configuration register
   type DCACHE_SYNC_INT_MAP_Register is record
      --  this register used to map dcache_sync interrupt to one of core0's
      --  external interrupt
      DCACHE_SYNC_INT_MAP : DCACHE_SYNC_INT_MAP_DCACHE_SYNC_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31       : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DCACHE_SYNC_INT_MAP_Register use
     record
       DCACHE_SYNC_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype ICACHE_SYNC_INT_MAP_ICACHE_SYNC_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  icache_sync interrupt configuration register
   type ICACHE_SYNC_INT_MAP_Register is record
      --  this register used to map icache_sync interrupt to one of core0's
      --  external interrupt
      ICACHE_SYNC_INT_MAP : ICACHE_SYNC_INT_MAP_ICACHE_SYNC_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31       : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ICACHE_SYNC_INT_MAP_Register use
     record
       ICACHE_SYNC_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype APB_ADC_INT_MAP_APB_ADC_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  apb_adc interrupt configuration register
   type APB_ADC_INT_MAP_Register is record
      --  this register used to map apb_adc interrupt to one of core0's
      --  external interrupt
      APB_ADC_INT_MAP : APB_ADC_INT_MAP_APB_ADC_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31   : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for APB_ADC_INT_MAP_Register use
     record
       APB_ADC_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_IN_CH0_INT_MAP_DMA_IN_CH0_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_in_ch0 interrupt configuration register
   type DMA_IN_CH0_INT_MAP_Register is record
      --  this register used to map dma_in_ch0 interrupt to one of core0's
      --  external interrupt
      DMA_IN_CH0_INT_MAP : DMA_IN_CH0_INT_MAP_DMA_IN_CH0_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31      : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_IN_CH0_INT_MAP_Register use
     record
       DMA_IN_CH0_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_IN_CH1_INT_MAP_DMA_IN_CH1_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_in_ch1 interrupt configuration register
   type DMA_IN_CH1_INT_MAP_Register is record
      --  this register used to map dma_in_ch1 interrupt to one of core0's
      --  external interrupt
      DMA_IN_CH1_INT_MAP : DMA_IN_CH1_INT_MAP_DMA_IN_CH1_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31      : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_IN_CH1_INT_MAP_Register use
     record
       DMA_IN_CH1_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_IN_CH2_INT_MAP_DMA_IN_CH2_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_in_ch2 interrupt configuration register
   type DMA_IN_CH2_INT_MAP_Register is record
      --  this register used to map dma_in_ch2 interrupt to one of core0's
      --  external interrupt
      DMA_IN_CH2_INT_MAP : DMA_IN_CH2_INT_MAP_DMA_IN_CH2_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31      : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_IN_CH2_INT_MAP_Register use
     record
       DMA_IN_CH2_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_IN_CH3_INT_MAP_DMA_IN_CH3_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_in_ch3 interrupt configuration register
   type DMA_IN_CH3_INT_MAP_Register is record
      --  this register used to map dma_in_ch3 interrupt to one of core0's
      --  external interrupt
      DMA_IN_CH3_INT_MAP : DMA_IN_CH3_INT_MAP_DMA_IN_CH3_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31      : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_IN_CH3_INT_MAP_Register use
     record
       DMA_IN_CH3_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_IN_CH4_INT_MAP_DMA_IN_CH4_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_in_ch4 interrupt configuration register
   type DMA_IN_CH4_INT_MAP_Register is record
      --  this register used to map dma_in_ch4 interrupt to one of core0's
      --  external interrupt
      DMA_IN_CH4_INT_MAP : DMA_IN_CH4_INT_MAP_DMA_IN_CH4_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31      : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_IN_CH4_INT_MAP_Register use
     record
       DMA_IN_CH4_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_OUT_CH0_INT_MAP_DMA_OUT_CH0_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_out_ch0 interrupt configuration register
   type DMA_OUT_CH0_INT_MAP_Register is record
      --  this register used to map dma_out_ch0 interrupt to one of core0's
      --  external interrupt
      DMA_OUT_CH0_INT_MAP : DMA_OUT_CH0_INT_MAP_DMA_OUT_CH0_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31       : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_OUT_CH0_INT_MAP_Register use
     record
       DMA_OUT_CH0_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_OUT_CH1_INT_MAP_DMA_OUT_CH1_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_out_ch1 interrupt configuration register
   type DMA_OUT_CH1_INT_MAP_Register is record
      --  this register used to map dma_out_ch1 interrupt to one of core0's
      --  external interrupt
      DMA_OUT_CH1_INT_MAP : DMA_OUT_CH1_INT_MAP_DMA_OUT_CH1_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31       : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_OUT_CH1_INT_MAP_Register use
     record
       DMA_OUT_CH1_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_OUT_CH2_INT_MAP_DMA_OUT_CH2_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_out_ch2 interrupt configuration register
   type DMA_OUT_CH2_INT_MAP_Register is record
      --  this register used to map dma_out_ch2 interrupt to one of core0's
      --  external interrupt
      DMA_OUT_CH2_INT_MAP : DMA_OUT_CH2_INT_MAP_DMA_OUT_CH2_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31       : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_OUT_CH2_INT_MAP_Register use
     record
       DMA_OUT_CH2_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_OUT_CH3_INT_MAP_DMA_OUT_CH3_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_out_ch3 interrupt configuration register
   type DMA_OUT_CH3_INT_MAP_Register is record
      --  this register used to map dma_out_ch3 interrupt to one of core0's
      --  external interrupt
      DMA_OUT_CH3_INT_MAP : DMA_OUT_CH3_INT_MAP_DMA_OUT_CH3_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31       : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_OUT_CH3_INT_MAP_Register use
     record
       DMA_OUT_CH3_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_OUT_CH4_INT_MAP_DMA_OUT_CH4_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_out_ch4 interrupt configuration register
   type DMA_OUT_CH4_INT_MAP_Register is record
      --  this register used to map dma_out_ch4 interrupt to one of core0's
      --  external interrupt
      DMA_OUT_CH4_INT_MAP : DMA_OUT_CH4_INT_MAP_DMA_OUT_CH4_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31       : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_OUT_CH4_INT_MAP_Register use
     record
       DMA_OUT_CH4_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype RSA_INT_MAP_RSA_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  rsa interrupt configuration register
   type RSA_INT_MAP_Register is record
      --  this register used to map rsa interrupt to one of core0's external
      --  interrupt
      RSA_INT_MAP   : RSA_INT_MAP_RSA_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for RSA_INT_MAP_Register use
     record
       RSA_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype AES_INT_MAP_AES_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  aes interrupt configuration register
   type AES_INT_MAP_Register is record
      --  this register used to map aes interrupt to one of core0's external
      --  interrupt
      AES_INT_MAP   : AES_INT_MAP_AES_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for AES_INT_MAP_Register use
     record
       AES_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype SHA_INT_MAP_SHA_INT_MAP_Field is ESP32S3_Registers.UInt5;

   --  sha interrupt configuration register
   type SHA_INT_MAP_Register is record
      --  this register used to map sha interrupt to one of core0's external
      --  interrupt
      SHA_INT_MAP   : SHA_INT_MAP_SHA_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31 : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for SHA_INT_MAP_Register use
     record
       SHA_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CPU_INTR_FROM_CPU_0_MAP_CPU_INTR_FROM_CPU_0_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  cpu_intr_from_cpu_0 interrupt configuration register
   type CPU_INTR_FROM_CPU_0_MAP_Register is record
      --  this register used to map cpu_intr_from_cpu_0 interrupt to one of
      --  core0's external interrupt
      CPU_INTR_FROM_CPU_0_MAP :
        CPU_INTR_FROM_CPU_0_MAP_CPU_INTR_FROM_CPU_0_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CPU_INTR_FROM_CPU_0_MAP_Register use
     record
       CPU_INTR_FROM_CPU_0_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CPU_INTR_FROM_CPU_1_MAP_CPU_INTR_FROM_CPU_1_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  cpu_intr_from_cpu_1 interrupt configuration register
   type CPU_INTR_FROM_CPU_1_MAP_Register is record
      --  this register used to map cpu_intr_from_cpu_1 interrupt to one of
      --  core0's external interrupt
      CPU_INTR_FROM_CPU_1_MAP :
        CPU_INTR_FROM_CPU_1_MAP_CPU_INTR_FROM_CPU_1_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CPU_INTR_FROM_CPU_1_MAP_Register use
     record
       CPU_INTR_FROM_CPU_1_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CPU_INTR_FROM_CPU_2_MAP_CPU_INTR_FROM_CPU_2_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  cpu_intr_from_cpu_2 interrupt configuration register
   type CPU_INTR_FROM_CPU_2_MAP_Register is record
      --  this register used to map cpu_intr_from_cpu_2 interrupt to one of
      --  core0's external interrupt
      CPU_INTR_FROM_CPU_2_MAP :
        CPU_INTR_FROM_CPU_2_MAP_CPU_INTR_FROM_CPU_2_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CPU_INTR_FROM_CPU_2_MAP_Register use
     record
       CPU_INTR_FROM_CPU_2_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CPU_INTR_FROM_CPU_3_MAP_CPU_INTR_FROM_CPU_3_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  cpu_intr_from_cpu_3 interrupt configuration register
   type CPU_INTR_FROM_CPU_3_MAP_Register is record
      --  this register used to map cpu_intr_from_cpu_3 interrupt to one of
      --  core0's external interrupt
      CPU_INTR_FROM_CPU_3_MAP :
        CPU_INTR_FROM_CPU_3_MAP_CPU_INTR_FROM_CPU_3_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CPU_INTR_FROM_CPU_3_MAP_Register use
     record
       CPU_INTR_FROM_CPU_3_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype ASSIST_DEBUG_INTR_MAP_ASSIST_DEBUG_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  assist_debug interrupt configuration register
   type ASSIST_DEBUG_INTR_MAP_Register is record
      --  this register used to map assist_debug interrupt to one of core0's
      --  external interrupt
      ASSIST_DEBUG_INTR_MAP :
        ASSIST_DEBUG_INTR_MAP_ASSIST_DEBUG_INTR_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31         : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for ASSIST_DEBUG_INTR_MAP_Register use
     record
       ASSIST_DEBUG_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP_DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_pms_monitor_violatile interrupt configuration register
   type DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP_Register is record
      --  this register used to map dma_pms_monitor_violatile interrupt to one
      --  of core0's external interrupt
      DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP :
        DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP_DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                            : ESP32S3_Registers.UInt27 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP_Register use
     record
       DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  core0_IRam0_pms_monitor_violatile interrupt configuration register
   type CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register is record
      --  this register used to map core0_IRam0_pms_monitor_violatile interrupt
      --  to one of core0's external interrupt
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP :
        CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                             : ESP32S3_Registers.UInt27 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register use
     record
       CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  core0_DRam0_pms_monitor_violatile interrupt configuration register
   type CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register is record
      --  this register used to map core0_DRam0_pms_monitor_violatile interrupt
      --  to one of core0's external interrupt
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP :
        CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                             : ESP32S3_Registers.UInt27 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register use
     record
       CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  core0_PIF_pms_monitor_violatile interrupt configuration register
   type CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Register is record
      --  this register used to map core0_PIF_pms_monitor_violatile interrupt
      --  to one of core0's external interrupt
      CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP :
        CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                           : ESP32S3_Registers.UInt27 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Register use
     record
       CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  core0_PIF_pms_monitor_violatile_size interrupt configuration register
   type CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Register is record
      --  this register used to map core0_PIF_pms_monitor_violatile_size
      --  interrupt to one of core0's external interrupt
      CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP :
        CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                                :
        ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Register use
     record
       CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  core1_IRam0_pms_monitor_violatile interrupt configuration register
   type CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register is record
      --  this register used to map core1_IRam0_pms_monitor_violatile interrupt
      --  to one of core0's external interrupt
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP :
        CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                             : ESP32S3_Registers.UInt27 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register use
     record
       CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  core1_DRam0_pms_monitor_violatile interrupt configuration register
   type CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register is record
      --  this register used to map core1_DRam0_pms_monitor_violatile interrupt
      --  to one of core0's external interrupt
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP :
        CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                             : ESP32S3_Registers.UInt27 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register use
     record
       CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  core1_PIF_pms_monitor_violatile interrupt configuration register
   type CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Register is record
      --  this register used to map core1_PIF_pms_monitor_violatile interrupt
      --  to one of core0's external interrupt
      CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP :
        CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                           : ESP32S3_Registers.UInt27 :=
        16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Register use
     record
       CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  core1_PIF_pms_monitor_violatile_size interrupt configuration register
   type CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Register is record
      --  this register used to map core1_PIF_pms_monitor_violatile_size
      --  interrupt to one of core0's external interrupt
      CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP :
        CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31                                :
        ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Register use
     record
       CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype BACKUP_PMS_VIOLATE_INTR_MAP_BACKUP_PMS_VIOLATE_INTR_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  backup_pms_monitor_violatile interrupt configuration register
   type BACKUP_PMS_VIOLATE_INTR_MAP_Register is record
      --  this register used to map backup_pms_monitor_violatile interrupt to
      --  one of core0's external interrupt
      BACKUP_PMS_VIOLATE_INTR_MAP :
        BACKUP_PMS_VIOLATE_INTR_MAP_BACKUP_PMS_VIOLATE_INTR_MAP_Field :=
          16#10#;
      --  unspecified
      Reserved_5_31               : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for BACKUP_PMS_VIOLATE_INTR_MAP_Register use
     record
       BACKUP_PMS_VIOLATE_INTR_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CACHE_CORE0_ACS_INT_MAP_CACHE_CORE0_ACS_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  cache_core0_acs interrupt configuration register
   type CACHE_CORE0_ACS_INT_MAP_Register is record
      --  this register used to map cache_core0_acs interrupt to one of core0's
      --  external interrupt
      CACHE_CORE0_ACS_INT_MAP :
        CACHE_CORE0_ACS_INT_MAP_CACHE_CORE0_ACS_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CACHE_CORE0_ACS_INT_MAP_Register use
     record
       CACHE_CORE0_ACS_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype CACHE_CORE1_ACS_INT_MAP_CACHE_CORE1_ACS_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  cache_core1_acs interrupt configuration register
   type CACHE_CORE1_ACS_INT_MAP_Register is record
      --  this register used to map cache_core1_acs interrupt to one of core0's
      --  external interrupt
      CACHE_CORE1_ACS_INT_MAP :
        CACHE_CORE1_ACS_INT_MAP_CACHE_CORE1_ACS_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31           : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CACHE_CORE1_ACS_INT_MAP_Register use
     record
       CACHE_CORE1_ACS_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype USB_DEVICE_INT_MAP_USB_DEVICE_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  usb_device interrupt configuration register
   type USB_DEVICE_INT_MAP_Register is record
      --  this register used to map usb_device interrupt to one of core0's
      --  external interrupt
      USB_DEVICE_INT_MAP : USB_DEVICE_INT_MAP_USB_DEVICE_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31      : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for USB_DEVICE_INT_MAP_Register use
     record
       USB_DEVICE_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype PERI_BACKUP_INT_MAP_PERI_BACKUP_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  peri_backup interrupt configuration register
   type PERI_BACKUP_INT_MAP_Register is record
      --  this register used to map peri_backup interrupt to one of core0's
      --  external interrupt
      PERI_BACKUP_INT_MAP : PERI_BACKUP_INT_MAP_PERI_BACKUP_INT_MAP_Field :=
        16#10#;
      --  unspecified
      Reserved_5_31       : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for PERI_BACKUP_INT_MAP_Register use
     record
       PERI_BACKUP_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   subtype DMA_EXTMEM_REJECT_INT_MAP_DMA_EXTMEM_REJECT_INT_MAP_Field is
     ESP32S3_Registers.UInt5;

   --  dma_extmem_reject interrupt configuration register
   type DMA_EXTMEM_REJECT_INT_MAP_Register is record
      --  this register used to map dma_extmem_reject interrupt to one of
      --  core0's external interrupt
      DMA_EXTMEM_REJECT_INT_MAP :
        DMA_EXTMEM_REJECT_INT_MAP_DMA_EXTMEM_REJECT_INT_MAP_Field := 16#10#;
      --  unspecified
      Reserved_5_31             : ESP32S3_Registers.UInt27 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DMA_EXTMEM_REJECT_INT_MAP_Register use
     record
       DMA_EXTMEM_REJECT_INT_MAP at 0 range 0 .. 4;
       Reserved_5_31 at 0 range 5 .. 31;
     end record;

   --  clock gate register
   type CLOCK_GATE_Register is record
      --  this register uesd to control clock-gating interupt martrix
      REG_CLK_EN    : Boolean := True;
      --  unspecified
      Reserved_1_31 : ESP32S3_Registers.UInt31 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for CLOCK_GATE_Register use
     record
       REG_CLK_EN at 0 range 0 .. 0;
       Reserved_1_31 at 0 range 1 .. 31;
     end record;

   subtype DATE_INTERRUPT_REG_DATE_Field is ESP32S3_Registers.UInt28;

   --  version register
   type DATE_Register is record
      --  version register
      INTERRUPT_REG_DATE : DATE_INTERRUPT_REG_DATE_Field := 16#2012300#;
      --  unspecified
      Reserved_28_31     : ESP32S3_Registers.UInt4 := 16#0#;
   end record
   with
     Volatile_Full_Access,
     Object_Size => 32,
     Bit_Order   => System.Low_Order_First;

   for DATE_Register use
     record
       INTERRUPT_REG_DATE at 0 range 0 .. 27;
       Reserved_28_31 at 0 range 28 .. 31;
     end record;

   -----------------
   -- Peripherals --
   -----------------

   --  Interrupt Controller (Core 0)
   type INTERRUPT_CORE0_Peripheral is record
      --  mac interrupt configuration register
      PRO_MAC_INTR_MAP                             :
        aliased PRO_MAC_INTR_MAP_Register;
      --  mac_nmi interrupt configuration register
      MAC_NMI_MAP                                  :
        aliased MAC_NMI_MAP_Register;
      --  pwr interrupt configuration register
      PWR_INTR_MAP                                 :
        aliased PWR_INTR_MAP_Register;
      --  bb interrupt configuration register
      BB_INT_MAP                                   :
        aliased BB_INT_MAP_Register;
      --  bb_mac interrupt configuration register
      BT_MAC_INT_MAP                               :
        aliased BT_MAC_INT_MAP_Register;
      --  bt_bb interrupt configuration register
      BT_BB_INT_MAP                                :
        aliased BT_BB_INT_MAP_Register;
      --  bt_bb_nmi interrupt configuration register
      BT_BB_NMI_MAP                                :
        aliased BT_BB_NMI_MAP_Register;
      --  rwbt_irq interrupt configuration register
      RWBT_IRQ_MAP                                 :
        aliased RWBT_IRQ_MAP_Register;
      --  rwble_irq interrupt configuration register
      RWBLE_IRQ_MAP                                :
        aliased RWBLE_IRQ_MAP_Register;
      --  rwbt_nmi interrupt configuration register
      RWBT_NMI_MAP                                 :
        aliased RWBT_NMI_MAP_Register;
      --  rwble_nmi interrupt configuration register
      RWBLE_NMI_MAP                                :
        aliased RWBLE_NMI_MAP_Register;
      --  i2c_mst interrupt configuration register
      I2C_MST_INT_MAP                              :
        aliased I2C_MST_INT_MAP_Register;
      --  slc0 interrupt configuration register
      SLC0_INTR_MAP                                :
        aliased SLC0_INTR_MAP_Register;
      --  slc1 interrupt configuration register
      SLC1_INTR_MAP                                :
        aliased SLC1_INTR_MAP_Register;
      --  uhci0 interrupt configuration register
      UHCI0_INTR_MAP                               :
        aliased UHCI0_INTR_MAP_Register;
      --  uhci1 interrupt configuration register
      UHCI1_INTR_MAP                               :
        aliased UHCI1_INTR_MAP_Register;
      --  gpio_interrupt_pro interrupt configuration register
      GPIO_INTERRUPT_PRO_MAP                       :
        aliased GPIO_INTERRUPT_PRO_MAP_Register;
      --  gpio_interrupt_pro_nmi interrupt configuration register
      GPIO_INTERRUPT_PRO_NMI_MAP                   :
        aliased GPIO_INTERRUPT_PRO_NMI_MAP_Register;
      --  gpio_interrupt_app interrupt configuration register
      GPIO_INTERRUPT_APP_MAP                       :
        aliased GPIO_INTERRUPT_APP_MAP_Register;
      --  gpio_interrupt_app_nmi interrupt configuration register
      GPIO_INTERRUPT_APP_NMI_MAP                   :
        aliased GPIO_INTERRUPT_APP_NMI_MAP_Register;
      --  spi_intr_1 interrupt configuration register
      SPI_INTR_1_MAP                               :
        aliased SPI_INTR_1_MAP_Register;
      --  spi_intr_2 interrupt configuration register
      SPI_INTR_2_MAP                               :
        aliased SPI_INTR_2_MAP_Register;
      --  spi_intr_3 interrupt configuration register
      SPI_INTR_3_MAP                               :
        aliased SPI_INTR_3_MAP_Register;
      --  spi_intr_4 interrupt configuration register
      SPI_INTR_4_MAP                               :
        aliased SPI_INTR_4_MAP_Register;
      --  lcd_cam interrupt configuration register
      LCD_CAM_INT_MAP                              :
        aliased LCD_CAM_INT_MAP_Register;
      --  i2s0 interrupt configuration register
      I2S0_INT_MAP                                 :
        aliased I2S0_INT_MAP_Register;
      --  i2s1 interrupt configuration register
      I2S1_INT_MAP                                 :
        aliased I2S1_INT_MAP_Register;
      --  uart interrupt configuration register
      UART_INTR_MAP                                :
        aliased UART_INTR_MAP_Register;
      --  uart1 interrupt configuration register
      UART1_INTR_MAP                               :
        aliased UART1_INTR_MAP_Register;
      --  uart2 interrupt configuration register
      UART2_INTR_MAP                               :
        aliased UART2_INTR_MAP_Register;
      --  sdio_host interrupt configuration register
      SDIO_HOST_INTERRUPT_MAP                      :
        aliased SDIO_HOST_INTERRUPT_MAP_Register;
      --  pwm0 interrupt configuration register
      PWM0_INTR_MAP                                :
        aliased PWM0_INTR_MAP_Register;
      --  pwm1 interrupt configuration register
      PWM1_INTR_MAP                                :
        aliased PWM1_INTR_MAP_Register;
      --  pwm2 interrupt configuration register
      PWM2_INTR_MAP                                :
        aliased PWM2_INTR_MAP_Register;
      --  pwm3 interrupt configuration register
      PWM3_INTR_MAP                                :
        aliased PWM3_INTR_MAP_Register;
      --  ledc interrupt configuration register
      LEDC_INT_MAP                                 :
        aliased LEDC_INT_MAP_Register;
      --  efuse interrupt configuration register
      EFUSE_INT_MAP                                :
        aliased EFUSE_INT_MAP_Register;
      --  can interrupt configuration register
      CAN_INT_MAP                                  :
        aliased CAN_INT_MAP_Register;
      --  usb interrupt configuration register
      USB_INTR_MAP                                 :
        aliased USB_INTR_MAP_Register;
      --  rtc_core interrupt configuration register
      RTC_CORE_INTR_MAP                            :
        aliased RTC_CORE_INTR_MAP_Register;
      --  rmt interrupt configuration register
      RMT_INTR_MAP                                 :
        aliased RMT_INTR_MAP_Register;
      --  pcnt interrupt configuration register
      PCNT_INTR_MAP                                :
        aliased PCNT_INTR_MAP_Register;
      --  i2c_ext0 interrupt configuration register
      I2C_EXT0_INTR_MAP                            :
        aliased I2C_EXT0_INTR_MAP_Register;
      --  i2c_ext1 interrupt configuration register
      I2C_EXT1_INTR_MAP                            :
        aliased I2C_EXT1_INTR_MAP_Register;
      --  spi2_dma interrupt configuration register
      SPI2_DMA_INT_MAP                             :
        aliased SPI2_DMA_INT_MAP_Register;
      --  spi3_dma interrupt configuration register
      SPI3_DMA_INT_MAP                             :
        aliased SPI3_DMA_INT_MAP_Register;
      --  spi4_dma interrupt configuration register
      SPI4_DMA_INT_MAP                             :
        aliased SPI4_DMA_INT_MAP_Register;
      --  wdg interrupt configuration register
      WDG_INT_MAP                                  :
        aliased WDG_INT_MAP_Register;
      --  timer_int1 interrupt configuration register
      TIMER_INT1_MAP                               :
        aliased TIMER_INT1_MAP_Register;
      --  timer_int2 interrupt configuration register
      TIMER_INT2_MAP                               :
        aliased TIMER_INT2_MAP_Register;
      --  tg_t0 interrupt configuration register
      TG_T0_INT_MAP                                :
        aliased TG_T0_INT_MAP_Register;
      --  tg_t1 interrupt configuration register
      TG_T1_INT_MAP                                :
        aliased TG_T1_INT_MAP_Register;
      --  tg_wdt interrupt configuration register
      TG_WDT_INT_MAP                               :
        aliased TG_WDT_INT_MAP_Register;
      --  tg1_t0 interrupt configuration register
      TG1_T0_INT_MAP                               :
        aliased TG1_T0_INT_MAP_Register;
      --  tg1_t1 interrupt configuration register
      TG1_T1_INT_MAP                               :
        aliased TG1_T1_INT_MAP_Register;
      --  tg1_wdt interrupt configuration register
      TG1_WDT_INT_MAP                              :
        aliased TG1_WDT_INT_MAP_Register;
      --  cache_ia interrupt configuration register
      CACHE_IA_INT_MAP                             :
        aliased CACHE_IA_INT_MAP_Register;
      --  systimer_target0 interrupt configuration register
      SYSTIMER_TARGET0_INT_MAP                     :
        aliased SYSTIMER_TARGET0_INT_MAP_Register;
      --  systimer_target1 interrupt configuration register
      SYSTIMER_TARGET1_INT_MAP                     :
        aliased SYSTIMER_TARGET1_INT_MAP_Register;
      --  systimer_target2 interrupt configuration register
      SYSTIMER_TARGET2_INT_MAP                     :
        aliased SYSTIMER_TARGET2_INT_MAP_Register;
      --  spi_mem_reject interrupt configuration register
      SPI_MEM_REJECT_INTR_MAP                      :
        aliased SPI_MEM_REJECT_INTR_MAP_Register;
      --  dcache_prelaod interrupt configuration register
      DCACHE_PRELOAD_INT_MAP                       :
        aliased DCACHE_PRELOAD_INT_MAP_Register;
      --  icache_preload interrupt configuration register
      ICACHE_PRELOAD_INT_MAP                       :
        aliased ICACHE_PRELOAD_INT_MAP_Register;
      --  dcache_sync interrupt configuration register
      DCACHE_SYNC_INT_MAP                          :
        aliased DCACHE_SYNC_INT_MAP_Register;
      --  icache_sync interrupt configuration register
      ICACHE_SYNC_INT_MAP                          :
        aliased ICACHE_SYNC_INT_MAP_Register;
      --  apb_adc interrupt configuration register
      APB_ADC_INT_MAP                              :
        aliased APB_ADC_INT_MAP_Register;
      --  dma_in_ch0 interrupt configuration register
      DMA_IN_CH0_INT_MAP                           :
        aliased DMA_IN_CH0_INT_MAP_Register;
      --  dma_in_ch1 interrupt configuration register
      DMA_IN_CH1_INT_MAP                           :
        aliased DMA_IN_CH1_INT_MAP_Register;
      --  dma_in_ch2 interrupt configuration register
      DMA_IN_CH2_INT_MAP                           :
        aliased DMA_IN_CH2_INT_MAP_Register;
      --  dma_in_ch3 interrupt configuration register
      DMA_IN_CH3_INT_MAP                           :
        aliased DMA_IN_CH3_INT_MAP_Register;
      --  dma_in_ch4 interrupt configuration register
      DMA_IN_CH4_INT_MAP                           :
        aliased DMA_IN_CH4_INT_MAP_Register;
      --  dma_out_ch0 interrupt configuration register
      DMA_OUT_CH0_INT_MAP                          :
        aliased DMA_OUT_CH0_INT_MAP_Register;
      --  dma_out_ch1 interrupt configuration register
      DMA_OUT_CH1_INT_MAP                          :
        aliased DMA_OUT_CH1_INT_MAP_Register;
      --  dma_out_ch2 interrupt configuration register
      DMA_OUT_CH2_INT_MAP                          :
        aliased DMA_OUT_CH2_INT_MAP_Register;
      --  dma_out_ch3 interrupt configuration register
      DMA_OUT_CH3_INT_MAP                          :
        aliased DMA_OUT_CH3_INT_MAP_Register;
      --  dma_out_ch4 interrupt configuration register
      DMA_OUT_CH4_INT_MAP                          :
        aliased DMA_OUT_CH4_INT_MAP_Register;
      --  rsa interrupt configuration register
      RSA_INT_MAP                                  :
        aliased RSA_INT_MAP_Register;
      --  aes interrupt configuration register
      AES_INT_MAP                                  :
        aliased AES_INT_MAP_Register;
      --  sha interrupt configuration register
      SHA_INT_MAP                                  :
        aliased SHA_INT_MAP_Register;
      --  cpu_intr_from_cpu_0 interrupt configuration register
      CPU_INTR_FROM_CPU_0_MAP                      :
        aliased CPU_INTR_FROM_CPU_0_MAP_Register;
      --  cpu_intr_from_cpu_1 interrupt configuration register
      CPU_INTR_FROM_CPU_1_MAP                      :
        aliased CPU_INTR_FROM_CPU_1_MAP_Register;
      --  cpu_intr_from_cpu_2 interrupt configuration register
      CPU_INTR_FROM_CPU_2_MAP                      :
        aliased CPU_INTR_FROM_CPU_2_MAP_Register;
      --  cpu_intr_from_cpu_3 interrupt configuration register
      CPU_INTR_FROM_CPU_3_MAP                      :
        aliased CPU_INTR_FROM_CPU_3_MAP_Register;
      --  assist_debug interrupt configuration register
      ASSIST_DEBUG_INTR_MAP                        :
        aliased ASSIST_DEBUG_INTR_MAP_Register;
      --  dma_pms_monitor_violatile interrupt configuration register
      DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP     :
        aliased DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP_Register;
      --  core0_IRam0_pms_monitor_violatile interrupt configuration register
      CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP    :
        aliased CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register;
      --  core0_DRam0_pms_monitor_violatile interrupt configuration register
      CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP    :
        aliased CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register;
      --  core0_PIF_pms_monitor_violatile interrupt configuration register
      CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP      :
        aliased CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Register;
      --  core0_PIF_pms_monitor_violatile_size interrupt configuration register
      CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP :
        aliased CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Register;
      --  core1_IRam0_pms_monitor_violatile interrupt configuration register
      CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP    :
        aliased CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register;
      --  core1_DRam0_pms_monitor_violatile interrupt configuration register
      CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP    :
        aliased CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP_Register;
      --  core1_PIF_pms_monitor_violatile interrupt configuration register
      CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP      :
        aliased CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP_Register;
      --  core1_PIF_pms_monitor_violatile_size interrupt configuration register
      CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP :
        aliased CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP_Register;
      --  backup_pms_monitor_violatile interrupt configuration register
      BACKUP_PMS_VIOLATE_INTR_MAP                  :
        aliased BACKUP_PMS_VIOLATE_INTR_MAP_Register;
      --  cache_core0_acs interrupt configuration register
      CACHE_CORE0_ACS_INT_MAP                      :
        aliased CACHE_CORE0_ACS_INT_MAP_Register;
      --  cache_core1_acs interrupt configuration register
      CACHE_CORE1_ACS_INT_MAP                      :
        aliased CACHE_CORE1_ACS_INT_MAP_Register;
      --  usb_device interrupt configuration register
      USB_DEVICE_INT_MAP                           :
        aliased USB_DEVICE_INT_MAP_Register;
      --  peri_backup interrupt configuration register
      PERI_BACKUP_INT_MAP                          :
        aliased PERI_BACKUP_INT_MAP_Register;
      --  dma_extmem_reject interrupt configuration register
      DMA_EXTMEM_REJECT_INT_MAP                    :
        aliased DMA_EXTMEM_REJECT_INT_MAP_Register;
      --  interrupt status register
      PRO_INTR_STATUS_0                            :
        aliased ESP32S3_Registers.UInt32;
      --  interrupt status register
      PRO_INTR_STATUS_1                            :
        aliased ESP32S3_Registers.UInt32;
      --  interrupt status register
      PRO_INTR_STATUS_2                            :
        aliased ESP32S3_Registers.UInt32;
      --  interrupt status register
      PRO_INTR_STATUS_3                            :
        aliased ESP32S3_Registers.UInt32;
      --  clock gate register
      CLOCK_GATE                                   :
        aliased CLOCK_GATE_Register;
      --  version register
      DATE                                         : aliased DATE_Register;
   end record
   with Volatile;

   for INTERRUPT_CORE0_Peripheral use
     record
       PRO_MAC_INTR_MAP at 16#0# range 0 .. 31;
       MAC_NMI_MAP at 16#4# range 0 .. 31;
       PWR_INTR_MAP at 16#8# range 0 .. 31;
       BB_INT_MAP at 16#C# range 0 .. 31;
       BT_MAC_INT_MAP at 16#10# range 0 .. 31;
       BT_BB_INT_MAP at 16#14# range 0 .. 31;
       BT_BB_NMI_MAP at 16#18# range 0 .. 31;
       RWBT_IRQ_MAP at 16#1C# range 0 .. 31;
       RWBLE_IRQ_MAP at 16#20# range 0 .. 31;
       RWBT_NMI_MAP at 16#24# range 0 .. 31;
       RWBLE_NMI_MAP at 16#28# range 0 .. 31;
       I2C_MST_INT_MAP at 16#2C# range 0 .. 31;
       SLC0_INTR_MAP at 16#30# range 0 .. 31;
       SLC1_INTR_MAP at 16#34# range 0 .. 31;
       UHCI0_INTR_MAP at 16#38# range 0 .. 31;
       UHCI1_INTR_MAP at 16#3C# range 0 .. 31;
       GPIO_INTERRUPT_PRO_MAP at 16#40# range 0 .. 31;
       GPIO_INTERRUPT_PRO_NMI_MAP at 16#44# range 0 .. 31;
       GPIO_INTERRUPT_APP_MAP at 16#48# range 0 .. 31;
       GPIO_INTERRUPT_APP_NMI_MAP at 16#4C# range 0 .. 31;
       SPI_INTR_1_MAP at 16#50# range 0 .. 31;
       SPI_INTR_2_MAP at 16#54# range 0 .. 31;
       SPI_INTR_3_MAP at 16#58# range 0 .. 31;
       SPI_INTR_4_MAP at 16#5C# range 0 .. 31;
       LCD_CAM_INT_MAP at 16#60# range 0 .. 31;
       I2S0_INT_MAP at 16#64# range 0 .. 31;
       I2S1_INT_MAP at 16#68# range 0 .. 31;
       UART_INTR_MAP at 16#6C# range 0 .. 31;
       UART1_INTR_MAP at 16#70# range 0 .. 31;
       UART2_INTR_MAP at 16#74# range 0 .. 31;
       SDIO_HOST_INTERRUPT_MAP at 16#78# range 0 .. 31;
       PWM0_INTR_MAP at 16#7C# range 0 .. 31;
       PWM1_INTR_MAP at 16#80# range 0 .. 31;
       PWM2_INTR_MAP at 16#84# range 0 .. 31;
       PWM3_INTR_MAP at 16#88# range 0 .. 31;
       LEDC_INT_MAP at 16#8C# range 0 .. 31;
       EFUSE_INT_MAP at 16#90# range 0 .. 31;
       CAN_INT_MAP at 16#94# range 0 .. 31;
       USB_INTR_MAP at 16#98# range 0 .. 31;
       RTC_CORE_INTR_MAP at 16#9C# range 0 .. 31;
       RMT_INTR_MAP at 16#A0# range 0 .. 31;
       PCNT_INTR_MAP at 16#A4# range 0 .. 31;
       I2C_EXT0_INTR_MAP at 16#A8# range 0 .. 31;
       I2C_EXT1_INTR_MAP at 16#AC# range 0 .. 31;
       SPI2_DMA_INT_MAP at 16#B0# range 0 .. 31;
       SPI3_DMA_INT_MAP at 16#B4# range 0 .. 31;
       SPI4_DMA_INT_MAP at 16#B8# range 0 .. 31;
       WDG_INT_MAP at 16#BC# range 0 .. 31;
       TIMER_INT1_MAP at 16#C0# range 0 .. 31;
       TIMER_INT2_MAP at 16#C4# range 0 .. 31;
       TG_T0_INT_MAP at 16#C8# range 0 .. 31;
       TG_T1_INT_MAP at 16#CC# range 0 .. 31;
       TG_WDT_INT_MAP at 16#D0# range 0 .. 31;
       TG1_T0_INT_MAP at 16#D4# range 0 .. 31;
       TG1_T1_INT_MAP at 16#D8# range 0 .. 31;
       TG1_WDT_INT_MAP at 16#DC# range 0 .. 31;
       CACHE_IA_INT_MAP at 16#E0# range 0 .. 31;
       SYSTIMER_TARGET0_INT_MAP at 16#E4# range 0 .. 31;
       SYSTIMER_TARGET1_INT_MAP at 16#E8# range 0 .. 31;
       SYSTIMER_TARGET2_INT_MAP at 16#EC# range 0 .. 31;
       SPI_MEM_REJECT_INTR_MAP at 16#F0# range 0 .. 31;
       DCACHE_PRELOAD_INT_MAP at 16#F4# range 0 .. 31;
       ICACHE_PRELOAD_INT_MAP at 16#F8# range 0 .. 31;
       DCACHE_SYNC_INT_MAP at 16#FC# range 0 .. 31;
       ICACHE_SYNC_INT_MAP at 16#100# range 0 .. 31;
       APB_ADC_INT_MAP at 16#104# range 0 .. 31;
       DMA_IN_CH0_INT_MAP at 16#108# range 0 .. 31;
       DMA_IN_CH1_INT_MAP at 16#10C# range 0 .. 31;
       DMA_IN_CH2_INT_MAP at 16#110# range 0 .. 31;
       DMA_IN_CH3_INT_MAP at 16#114# range 0 .. 31;
       DMA_IN_CH4_INT_MAP at 16#118# range 0 .. 31;
       DMA_OUT_CH0_INT_MAP at 16#11C# range 0 .. 31;
       DMA_OUT_CH1_INT_MAP at 16#120# range 0 .. 31;
       DMA_OUT_CH2_INT_MAP at 16#124# range 0 .. 31;
       DMA_OUT_CH3_INT_MAP at 16#128# range 0 .. 31;
       DMA_OUT_CH4_INT_MAP at 16#12C# range 0 .. 31;
       RSA_INT_MAP at 16#130# range 0 .. 31;
       AES_INT_MAP at 16#134# range 0 .. 31;
       SHA_INT_MAP at 16#138# range 0 .. 31;
       CPU_INTR_FROM_CPU_0_MAP at 16#13C# range 0 .. 31;
       CPU_INTR_FROM_CPU_1_MAP at 16#140# range 0 .. 31;
       CPU_INTR_FROM_CPU_2_MAP at 16#144# range 0 .. 31;
       CPU_INTR_FROM_CPU_3_MAP at 16#148# range 0 .. 31;
       ASSIST_DEBUG_INTR_MAP at 16#14C# range 0 .. 31;
       DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP at 16#150# range 0 .. 31;
       CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP at 16#154# range 0 .. 31;
       CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP at 16#158# range 0 .. 31;
       CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP at 16#15C# range 0 .. 31;
       CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP at 16#160# range 0 .. 31;
       CORE_1_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP at 16#164# range 0 .. 31;
       CORE_1_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP at 16#168# range 0 .. 31;
       CORE_1_PIF_PMS_MONITOR_VIOLATE_INTR_MAP at 16#16C# range 0 .. 31;
       CORE_1_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP at 16#170# range 0 .. 31;
       BACKUP_PMS_VIOLATE_INTR_MAP at 16#174# range 0 .. 31;
       CACHE_CORE0_ACS_INT_MAP at 16#178# range 0 .. 31;
       CACHE_CORE1_ACS_INT_MAP at 16#17C# range 0 .. 31;
       USB_DEVICE_INT_MAP at 16#180# range 0 .. 31;
       PERI_BACKUP_INT_MAP at 16#184# range 0 .. 31;
       DMA_EXTMEM_REJECT_INT_MAP at 16#188# range 0 .. 31;
       PRO_INTR_STATUS_0 at 16#18C# range 0 .. 31;
       PRO_INTR_STATUS_1 at 16#190# range 0 .. 31;
       PRO_INTR_STATUS_2 at 16#194# range 0 .. 31;
       PRO_INTR_STATUS_3 at 16#198# range 0 .. 31;
       CLOCK_GATE at 16#19C# range 0 .. 31;
       DATE at 16#7FC# range 0 .. 31;
     end record;

   --  Interrupt Controller (Core 0)
   INTERRUPT_CORE0_Periph : aliased INTERRUPT_CORE0_Peripheral
   with Import, Address => INTERRUPT_CORE0_Base, Volatile,
        Async_Readers    => True,
        Async_Writers    => True,
        Effective_Reads  => False,
        Effective_Writes => True;

end ESP32S3_Registers.INTERRUPT_CORE0;
