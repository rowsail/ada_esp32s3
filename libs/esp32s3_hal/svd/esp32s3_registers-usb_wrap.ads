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

package ESP32S3_Registers.USB_WRAP is
   pragma Preelaborate;

   ---------------
   -- Registers --
   ---------------

   subtype OTG_CONF_VREFH_Field is ESP32S3_Registers.UInt2;
   subtype OTG_CONF_VREFL_Field is ESP32S3_Registers.UInt2;

   --  USB OTG Wrapper Configure Register
   type OTG_CONF_Register is record
      --  This bit is used to enable the software over-ride of srp session end
      --  signal. 1'b0: the signal is controlled by the chip input. 1'b1: the
      --  signal is controlled by the software.
      SRP_SESSEND_OVERRIDE : Boolean := False;
      --  Software over-ride value of srp session end signal.
      SRP_SESSEND_VALUE    : Boolean := False;
      --  Select internal external PHY. 1'b0: Select internal PHY. 1'b1: Select
      --  external PHY.
      PHY_SEL              : Boolean := False;
      --  Force the dfifo to go into low power mode. The data in dfifo will not
      --  lost.
      DFIFO_FORCE_PD       : Boolean := False;
      --  Bypass Debounce filters for avalid,bvalid,vbusvalid,session end, id
      --  signals
      DBNCE_FLTR_BYPASS    : Boolean := False;
      --  Enable software controlle USB D+ D- exchange
      EXCHG_PINS_OVERRIDE  : Boolean := False;
      --  USB D+ D- exchange. 1'b0: don't change. 1'b1: exchange D+ D-
      EXCHG_PINS           : Boolean := False;
      --  Control single-end input high threshold,1.76V to 2V, step 80mV
      VREFH                : OTG_CONF_VREFH_Field := 16#0#;
      --  Control single-end input low threshold,0.8V to 1.04V, step 80mV
      VREFL                : OTG_CONF_VREFL_Field := 16#0#;
      --  Enable software controlle input threshold
      VREF_OVERRIDE        : Boolean := False;
      --  Enable software controlle USB D+ D- pullup pulldown
      PAD_PULL_OVERRIDE    : Boolean := False;
      --  Controlle USB D+ pullup
      DP_PULLUP            : Boolean := False;
      --  Controlle USB D+ pulldown
      DP_PULLDOWN          : Boolean := False;
      --  Controlle USB D+ pullup
      DM_PULLUP            : Boolean := False;
      --  Controlle USB D+ pulldown
      DM_PULLDOWN          : Boolean := False;
      --  Controlle pullup value. 1'b0: typical value is 2.4K. 1'b1: typical
      --  value is 1.2K.
      PULLUP_VALUE         : Boolean := False;
      --  Enable USB pad function
      USB_PAD_ENABLE       : Boolean := True;
      --  Force ahb clock always on
      AHB_CLK_FORCE_ON     : Boolean := True;
      --  Force phy clock always on
      PHY_CLK_FORCE_ON     : Boolean := True;
      --  Select phy tx signal output clock edge. 1'b0: negedge. 1'b1: posedge.
      PHY_TX_EDGE_SEL      : Boolean := False;
      --  Disable the dfifo to go into low power mode. The data in dfifo will
      --  not lost.
      DFIFO_FORCE_PU       : Boolean := False;
      --  unspecified
      Reserved_23_30       : ESP32S3_Registers.Byte := 16#0#;
      --  Disable auto clock gating of CSR registers
      CLK_EN               : Boolean := False;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for OTG_CONF_Register use record
      SRP_SESSEND_OVERRIDE at 0 range 0 .. 0;
      SRP_SESSEND_VALUE    at 0 range 1 .. 1;
      PHY_SEL              at 0 range 2 .. 2;
      DFIFO_FORCE_PD       at 0 range 3 .. 3;
      DBNCE_FLTR_BYPASS    at 0 range 4 .. 4;
      EXCHG_PINS_OVERRIDE  at 0 range 5 .. 5;
      EXCHG_PINS           at 0 range 6 .. 6;
      VREFH                at 0 range 7 .. 8;
      VREFL                at 0 range 9 .. 10;
      VREF_OVERRIDE        at 0 range 11 .. 11;
      PAD_PULL_OVERRIDE    at 0 range 12 .. 12;
      DP_PULLUP            at 0 range 13 .. 13;
      DP_PULLDOWN          at 0 range 14 .. 14;
      DM_PULLUP            at 0 range 15 .. 15;
      DM_PULLDOWN          at 0 range 16 .. 16;
      PULLUP_VALUE         at 0 range 17 .. 17;
      USB_PAD_ENABLE       at 0 range 18 .. 18;
      AHB_CLK_FORCE_ON     at 0 range 19 .. 19;
      PHY_CLK_FORCE_ON     at 0 range 20 .. 20;
      PHY_TX_EDGE_SEL      at 0 range 21 .. 21;
      DFIFO_FORCE_PU       at 0 range 22 .. 22;
      Reserved_23_30       at 0 range 23 .. 30;
      CLK_EN               at 0 range 31 .. 31;
   end record;

   --  USB Internal PHY Testing Register
   type TEST_CONF_Register is record
      --  Enable test of the USB pad
      TEST_ENABLE   : Boolean := False;
      --  USB pad oen in test
      TEST_USB_OE   : Boolean := False;
      --  USB D+ tx value in test
      TEST_TX_DP    : Boolean := False;
      --  USB D- tx value in test
      TEST_TX_DM    : Boolean := False;
      --  Read-only. USB differential rx value in test
      TEST_RX_RCV   : Boolean := False;
      --  Read-only. USB D+ rx value in test
      TEST_RX_DP    : Boolean := False;
      --  Read-only. USB D- rx value in test
      TEST_RX_DM    : Boolean := False;
      --  unspecified
      Reserved_7_31 : ESP32S3_Registers.UInt25 := 16#0#;
   end record
     with Volatile_Full_Access, Object_Size => 32,
          Bit_Order => System.Low_Order_First;

   for TEST_CONF_Register use record
      TEST_ENABLE   at 0 range 0 .. 0;
      TEST_USB_OE   at 0 range 1 .. 1;
      TEST_TX_DP    at 0 range 2 .. 2;
      TEST_TX_DM    at 0 range 3 .. 3;
      TEST_RX_RCV   at 0 range 4 .. 4;
      TEST_RX_DP    at 0 range 5 .. 5;
      TEST_RX_DM    at 0 range 6 .. 6;
      Reserved_7_31 at 0 range 7 .. 31;
   end record;

   -----------------
   -- Peripherals --
   -----------------

   --  USB_WRAP Peripheral
   type USB_WRAP_Peripheral is record
      --  USB OTG Wrapper Configure Register
      OTG_CONF  : aliased OTG_CONF_Register;
      --  USB Internal PHY Testing Register
      TEST_CONF : aliased TEST_CONF_Register;
      --  Version Control Register
      DATE      : aliased ESP32S3_Registers.UInt32;
   end record
     with Volatile;

   for USB_WRAP_Peripheral use record
      OTG_CONF  at 16#0# range 0 .. 31;
      TEST_CONF at 16#4# range 0 .. 31;
      DATE      at 16#3FC# range 0 .. 31;
   end record;

   --  USB_WRAP Peripheral
   USB_WRAP_Periph : aliased USB_WRAP_Peripheral
     with Import, Address => USB_WRAP_Base, Volatile,
          Async_Readers    => True,
          Async_Writers    => True,
          Effective_Reads  => False,
          Effective_Writes => True;

end ESP32S3_Registers.USB_WRAP;
