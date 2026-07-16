with Interfaces;               use Interfaces;
with System;
with System.Storage_Elements;  use System.Storage_Elements;
with System.Machine_Code;      use System.Machine_Code;
with ESP32S3.Log;
with ESP32S3.MAC;

package body ESP32S3.WiFi.PHY is

   use type System.Address;

   --  Default esp32s3 PHY init data (esp_phy_init_data_t.params[128]), the exact
   --  bytes IDF's phy_init_data.c produces at the default max TX power (20 dBm).
   Phy_Init_Data : constant array (0 .. 127) of Unsigned_8 :=
     (16#00#, 16#00#, 16#50#, 16#50#, 16#50#, 16#4C#, 16#4C#, 16#48#,
      16#4C#, 16#48#, 16#48#, 16#44#, 16#4A#, 16#46#, 16#46#, 16#42#,
      16#00#, 16#00#, 16#00#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#,
      16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#FF#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#74#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#,
      16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#, 16#00#);

   --  esp_phy_calibration_data_t = version[4] + mac[6] + opaque[1894] = 1904 B.
   Cal_Size           : constant := 1904;
   Mac_Offset         : constant := 4;     --  .mac starts after version[4]
   PHY_RF_CAL_PARTIAL : constant Interfaces.Integer_32 := 0;
   PHY_RF_CAL_FULL    : constant Interfaces.Integer_32 := 2;

   --  RF-calibration persistence hooks (see ESP32S3.WiFi.Set_Cal_Store).
   Load_Hook  : Cal_Load_Hook  := null;
   Store_Hook : Cal_Store_Hook := null;

   procedure Set_Cal_Store (Load : Cal_Load_Hook; Store : Cal_Store_Hook) is
   begin
      Load_Hook  := Load;
      Store_Hook := Store;
   end Set_Cal_Store;

   --  A stored blob is trustworthy only if its embedded MAC is THIS chip's (an
   --  image copied to another board must recalibrate).  The version[4] + opaque
   --  data are produced by this same PHY lib, so the MAC check suffices here.
   function Blob_Matches_Chip (Blob : Cal_Blob) return Boolean is
      Base : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Base;
   begin
      for I in 0 .. 5 loop
         if Blob (Mac_Offset + I) /= Base (I) then
            return False;
         end if;
      end loop;
      return True;
   end Blob_Matches_Chip;

   --  Clock enables in SYSCON_WIFI_CLK_EN_REG (esp_phy_common_clock_enable +
   --  phy_module_enable): WIFI_BT_COMMON (0x78078F, already includes PHY_EN bit
   --  22 0x400000) plus the RNG clock (BIT15 0x8000) that phy_module_enable adds
   --  before RF calibration.
   Wifi_Clk_En_Reg : constant := 16#6002_6014#;
   --  0x78078F = WIFI_BT_COMMON (incl PHY_EN bit22), 0x8000 = RNG; also OR the
   --  full SYSTEM_WIFI_CLK_EN composite (0xFB9FCF) so the MAC/BB clocks are on.
   Phy_Clk_Mask    : constant Unsigned_32 :=
     16#0078_078F# or 16#0000_8000# or 16#00FB_9FCF#;

   function Register_Chipv7_Phy
     (Init, Cal : System.Address; Mode : Interfaces.Integer_32)
      return Interfaces.Integer_32
     with Import, Convention => C, External_Name => "register_chipv7_phy";

   procedure Phy_Wakeup_Init
     with Import, Convention => C, External_Name => "phy_wakeup_init";

   function C_Calloc (N, Sz : Unsigned_32) return System.Address
     with Import, Convention => C, External_Name => "calloc";
   procedure C_Free (P : System.Address)
     with Import, Convention => C, External_Name => "free";

   Calibrated : Boolean := False;

   --  ---- libphy de-blob: first transpiled function (proof of method) --------
   --  force_txrx_off(en): a self-contained libphy primitive -- a read-modify-
   --  write of the TX/RX force register 0x60006110 (bits 9/11) with 1 us settling
   --  gaps, no i2c / g_phyFuns / ROM.  Faithful Ada port of the disassembly,
   --  wired in by linker --wrap so the blob's version never runs.  A wrong TX/RX
   --  force sequence disrupts the radio, so "still associates + fetches" proves
   --  the port.  See research/wifi-re/PHY_BOUNDARY.md.
   procedure Ets_Delay_Us (Us : Interfaces.Unsigned_32)
     with Import, Convention => C, External_Name => "ets_delay_us";

   Force_Txrx_Count : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_force_txrx_count";

   procedure Wrap_Force_Txrx_Off (En : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_force_txrx_off";
   procedure Wrap_Force_Txrx_Off (En : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
      Reg  : Interfaces.Unsigned_32 with Import, Volatile,
        Address => System'To_Address (16#6000_6110#);
      Mask : constant Interfaces.Unsigned_32 := 16#FFFF_F0FF#;  --  clear bits 8..11
      Final : Interfaces.Unsigned_32;
   begin
      Force_Txrx_Count := Force_Txrx_Count + 1;
      if (En and 16#FF#) /= 0 then
         --  Force TX/RX off: set bit 11, settle, then set bits 9+11.
         Reg := (Reg and Mask) or 16#0000_0800#;
         Ets_Delay_Us (1);
         Final := (Reg and Mask) or 16#0000_0A00#;
      else
         --  Release: set bit 9, settle, then clear bits 8..11.
         Reg := (Reg and Mask) or 16#0000_0200#;
         Ets_Delay_Us (1);
         Final := Reg and Mask;
      end if;
      Reg := Final;
      Ets_Delay_Us (1);
   end Wrap_Force_Txrx_Off;

   --  Batch 2: three more self-contained baseband/SYSCON RMW primitives (0x6001c
   --  low-rate mode, 0x60026 wifi-enable).  Same faithful-port pattern.
   Ports2_Count : Interfaces.Unsigned_32 := 0
     with Export, Convention => C, External_Name => "ada_phy_ports2_count";

   procedure Poke (Addr, Val : Interfaces.Unsigned_32) is
      Cell : Interfaces.Unsigned_32 with Import, Volatile,
        Address => System'To_Address (Addr);
   begin
      Cell := Val;
   end Poke;
   function Peek (Addr : Interfaces.Unsigned_32) return Interfaces.Unsigned_32 is
      Cell : Interfaces.Unsigned_32 with Import, Volatile,
        Address => System'To_Address (Addr);
   begin
      return Cell;
   end Peek;

   procedure Wrap_Disable_Low_Rate
     with Export, Convention => C, External_Name => "__wrap_phy_disable_low_rate";
   procedure Wrap_Disable_Low_Rate is
      use type Interfaces.Unsigned_32;
   begin
      Ports2_Count := Ports2_Count + 1;
      Poke (16#6001_C860#, Peek (16#6001_C860#) and 16#FFFF_FBFF#);  --  clr bit10
      Poke (16#6001_C860#, Peek (16#6001_C860#) and 16#FFFF_F7FF#);  --  clr bit11
      Poke (16#6001_C87C#, Peek (16#6001_C87C#) and 16#FFFF_F7FF#);  --  clr bit11
   end Wrap_Disable_Low_Rate;

   procedure Wrap_Enable_Low_Rate
     with Export, Convention => C, External_Name => "__wrap_phy_enable_low_rate";
   procedure Wrap_Enable_Low_Rate is
      use type Interfaces.Unsigned_32;
   begin
      Ports2_Count := Ports2_Count + 1;
      Poke (16#6001_C860#, Peek (16#6001_C860#) or 16#0000_0400#);   --  set bit10
      Poke (16#6001_C860#, Peek (16#6001_C860#) or 16#0000_0800#);   --  set bit11
      Poke (16#6001_C87C#, Peek (16#6001_C87C#) or 16#0000_0800#);   --  set bit11
   end Wrap_Enable_Low_Rate;

   procedure Wrap_Wifi_Enable_Set (En : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "__wrap_phy_wifi_enable_set";
   procedure Wrap_Wifi_Enable_Set (En : Interfaces.Unsigned_32) is
      use type Interfaces.Unsigned_32;
      V : constant Interfaces.Unsigned_32 := Peek (16#6002_600C#);
   begin
      Ports2_Count := Ports2_Count + 1;
      if (En and 16#FF#) /= 0 then
         Poke (16#6002_600C#, V or 16#0000_0002#);   --  set bit1
      else
         Poke (16#6002_600C#, V and 16#FFFF_FFFD#);  --  clear bit1
      end if;
   end Wrap_Wifi_Enable_Set;

   procedure Phy_Enable is
      Cal : System.Address;
      Clk : Unsigned_32 with Import, Volatile,
              Address => To_Address (Wifi_Clk_En_Reg);
   begin
      Clk := Clk or Phy_Clk_Mask;   --  common clock + PHY-cal/RNG clock

      if not Calibrated then
         Cal := C_Calloc (1, Cal_Size);
         if Cal = System.Null_Address then
            ESP32S3.Log.Put_Line ("[wifi] PHY: cal_data alloc failed");
            return;
         end if;
         declare
            --  Overlay the heap cal buffer as a Cal_Blob so the hooks read/write
            --  it in place -- no 1904-byte copy on the (small) Wi-Fi task stack.
            Cal_Bytes : Cal_Blob with Import, Address => Cal;
            Mode      : Interfaces.Integer_32 := PHY_RF_CAL_FULL;
            Loaded    : Boolean := False;
         begin
            --  A valid stored calibration -> fast PARTIAL cal off its baseline.
            --  Load_Hook fills Cal_Bytes in place; if it is not this chip's blob
            --  we fall through to FULL (which stamps the MAC + overwrites all).
            if Load_Hook /= null
              and then Load_Hook (Cal_Bytes)
              and then Blob_Matches_Chip (Cal_Bytes)
            then
               Mode   := PHY_RF_CAL_PARTIAL;
               Loaded := True;
            end if;

            --  Fresh FULL buffer: stamp this chip's MAC (the cal keys off it).
            if not Loaded then
               declare
                  Base : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Base;
               begin
                  for I in 0 .. 5 loop
                     Cal_Bytes (Mac_Offset + I) := Base (I);
                  end loop;
               end;
            end if;

            if Loaded then
               ESP32S3.Log.Put_Line ("[wifi] PHY: RF cal PARTIAL (stored baseline)");
            else
               ESP32S3.Log.Put_Line ("[wifi] PHY: RF cal FULL");
            end if;

            --  Run RF calibration (PARTIAL or FULL).  A non-zero result is
            --  normal for a fresh FULL buffer (the cal self-check), not an error.
            declare
               Rc : constant Interfaces.Integer_32 :=
                 Register_Chipv7_Phy (Phy_Init_Data'Address, Cal, Mode);
               pragma Unreferenced (Rc);
            begin
               null;
            end;

            --  Persist a freshly-produced FULL calibration for the next boot.
            --  (Full-cal output is inherently good, so storing here is safe.)
            if not Loaded and then Store_Hook /= null then
               Store_Hook (Cal_Bytes);
            end if;
         end;
         C_Free (Cal);   --  PHY keeps its own copy of the calibration data
         Calibrated := True;
      else
         Phy_Wakeup_Init;
      end if;
   end Phy_Enable;

   procedure Phy_Disable is
   begin
      null;   --  leave the RF on (continuous scanning); TODO phy_close_rf
   end Phy_Disable;

end ESP32S3.WiFi.PHY;
