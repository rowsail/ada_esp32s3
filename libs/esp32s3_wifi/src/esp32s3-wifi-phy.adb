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
   Cal_Size        : constant := 1904;
   Mac_Offset      : constant := 4;     --  .mac starts after version[4]
   PHY_RF_CAL_FULL : constant Interfaces.Integer_32 := 2;

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
            Base : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Base;
            M    : array (0 .. 5) of Unsigned_8
              with Import, Address => Cal + Mac_Offset;
         begin
            for I in 0 .. 5 loop
               M (I) := Base (I);
            end loop;
         end;
         --  Full RF calibration.  A non-zero result is normal here (the cal
         --  self-check flags the fresh/no-NVS buffer), so it is not an error.
         declare
            Rc : constant Interfaces.Integer_32 :=
              Register_Chipv7_Phy (Phy_Init_Data'Address, Cal, PHY_RF_CAL_FULL);
            pragma Unreferenced (Rc);
         begin
            null;
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
