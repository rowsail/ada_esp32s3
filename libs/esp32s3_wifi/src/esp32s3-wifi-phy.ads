--  PHY / RF bring-up.  Reproduces the essence of ESP-IDF's esp_phy_enable for
--  the Wi-Fi path: enable the Wi-Fi/BT common clock, then hand the blob's
--  register_chipv7_phy the default PHY init data + a calibration-data buffer so
--  it runs RF calibration.  These map onto the OS-adapter _phy_enable/_phy_
--  disable slots (void -> void).
private package ESP32S3.WiFi.PHY is
   procedure Phy_Enable  with Convention => C;
   procedure Phy_Disable with Convention => C;

   --  Register the RF-calibration persistence hooks (forwarded from the public
   --  ESP32S3.WiFi.Set_Cal_Store).  When a valid blob is loaded, the first
   --  Phy_Enable does a PARTIAL calibration off it instead of a FULL one.
   procedure Set_Cal_Store (Load : Cal_Load_Hook; Store : Cal_Store_Hook);
end ESP32S3.WiFi.PHY;
