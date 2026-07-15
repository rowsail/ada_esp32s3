--  Port glue: the handful of C symbols the Espressif Wi-Fi/PHY blobs reference
--  that are NOT in the blobs, NOT in ROM, and NOT part of the OS-adapter table.
--  In a normal IDF build these come from the open-source esp_wifi/esp_phy/
--  wpa_supplicant/mesh C sources; here they are provided in Ada.
--
--  Three groups (see the body):
--    * mesh entry points -- never reached in STA scan, so safe no-ops;
--    * PHY/logging glue (phy_enter/exit_critical, the *printf family) -- minimal;
--    * two data symbols (the default WPA crypto table + the WIFI_EVENT base).
--
--  This package has no operations of its own; it exists so its body's exported
--  C symbols are pulled into the link.  WiFi's body withs it.
package ESP32S3.WiFi.Port is
   pragma Elaborate_Body;

   --  Register a minimal wpa_funcs table with the blob (normally done by
   --  esp_supplicant_init, which we skip).  Its pointer lands in g_ic+0x1b4;
   --  the RX path derefs it (e.g. wpa_sta_rx_mgmt at +0x54), so a null table
   --  faults the WMAC ISR.  All 27 slots are a no-op returning 0 ("not handled"
   --  -> the scan module processes beacons itself).  Call after init_internal.
   procedure Register_Wpa_Stub;

end ESP32S3.WiFi.Port;
