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
