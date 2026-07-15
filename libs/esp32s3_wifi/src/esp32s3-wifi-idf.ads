--  Bindings to the Espressif esp_wifi entry points needed for init + scan,
--  pinned to ESP-IDF v5.4.4 / esp32s3.  Struct layouts are ground-truthed with a
--  target (xtensa esp32s3) compile probe against the IDF headers, not guessed:
--    sizeof(wifi_ap_record_t)   = 92; ssid@6, primary(channel)@39, rssi@44,
--                                 authmode@48
--    sizeof(wifi_scan_config_t) = 44
--  These symbols resolve only against the linked blobs (libnet80211/libpp/
--  libcore) in the bare-boot image.
with Interfaces;
with System;

private package ESP32S3.WiFi.IDF is

   subtype Esp_Err is Interfaces.Integer_32;   --  esp_err_t
   ESP_OK : constant Esp_Err := 0;

   WIFI_MODE_STA : constant Interfaces.Integer_32 := 1;

   --  wifi_auth_mode_t values (v5.4.4).
   AUTH_OPEN          : constant := 0;
   AUTH_WEP           : constant := 1;
   AUTH_WPA_PSK       : constant := 2;
   AUTH_WPA2_PSK      : constant := 3;
   AUTH_WPA_WPA2_PSK  : constant := 4;
   AUTH_ENTERPRISE    : constant := 5;   --  == WPA2_ENTERPRISE
   AUTH_WPA3_PSK      : constant := 6;
   AUTH_WPA2_WPA3_PSK : constant := 7;

   --  Exact 92-byte wifi_ap_record_t; only the fields we surface are named, the
   --  version-specific tail (country/he_ap/bandwidth/vht) is left as padding via
   --  the explicit 'Size so the array stride stays correct.
   type BSSID_Bytes is array (0 .. 5) of Interfaces.Unsigned_8;
   type SSID_Bytes  is array (0 .. 32) of Interfaces.Unsigned_8;   --  uint8[33]

   type C_AP_Record is record
      BSSID    : BSSID_Bytes;
      SSID     : SSID_Bytes;
      Primary  : Interfaces.Unsigned_8;    --  channel
      RSSI     : Interfaces.Integer_8;
      Authmode : Interfaces.Unsigned_32;   --  wifi_auth_mode_t
      Pairwise : Interfaces.Unsigned_32;   --  wifi_cipher_type_t @52
      Group    : Interfaces.Unsigned_32;   --  wifi_cipher_type_t @56
   end record
     with Convention => C;
   for C_AP_Record use record
      BSSID    at 0  range 0 .. 47;
      SSID     at 6  range 0 .. 263;
      Primary  at 39 range 0 .. 7;
      RSSI     at 44 range 0 .. 7;
      Authmode at 48 range 0 .. 31;
      Pairwise at 52 range 0 .. 31;
      Group    at 56 range 0 .. 31;
   end record;
   for C_AP_Record'Size use 92 * 8;

   type C_AP_Array is array (Positive range <>) of C_AP_Record
     with Convention => C, Component_Size => 92 * 8;

   --  wifi_init_config_t (v5.4.4, esp32s3): sizeof = 152; all buffer/enable
   --  fields are plain int.  wpa_crypto_funcs is a 44-byte struct-by-value copied
   --  from the extern default.  Defaults are the resolved WIFI_INIT_CONFIG_DEFAULT
   --  values (see BRINGUP.md).
   type Wpa_Crypto_Funcs is array (1 .. 44) of Interfaces.Unsigned_8
     with Convention => C;

   G_Default_Wpa_Crypto : Wpa_Crypto_Funcs
     with Import, Convention => C,
          External_Name => "g_wifi_default_wpa_crypto_funcs";

   type Wifi_Init_Config is record
      Osi_Funcs           : System.Address := System.Null_Address;
      Wpa_Crypto          : Wpa_Crypto_Funcs := [others => 0];
      Static_Rx_Buf_Num   : Interfaces.Integer_32 := 10;
      Dynamic_Rx_Buf_Num  : Interfaces.Integer_32 := 32;
      Tx_Buf_Type         : Interfaces.Integer_32 := 1;
      Static_Tx_Buf_Num   : Interfaces.Integer_32 := 0;
      Dynamic_Tx_Buf_Num  : Interfaces.Integer_32 := 32;
      Rx_Mgmt_Buf_Type    : Interfaces.Integer_32 := 0;
      Rx_Mgmt_Buf_Num     : Interfaces.Integer_32 := 5;
      Cache_Tx_Buf_Num    : Interfaces.Integer_32 := 0;
      Csi_Enable          : Interfaces.Integer_32 := 0;
      Ampdu_Rx_Enable     : Interfaces.Integer_32 := 1;
      Ampdu_Tx_Enable     : Interfaces.Integer_32 := 1;
      Amsdu_Tx_Enable     : Interfaces.Integer_32 := 0;
      Nvs_Enable          : Interfaces.Integer_32 := 0;   --  no NVS: calibrate
                                                          --  fresh each boot
                                                          --  (scan needs no
                                                          --  persistent store)
      Nano_Enable         : Interfaces.Integer_32 := 0;
      Rx_Ba_Win           : Interfaces.Integer_32 := 6;
      Wifi_Task_Core_Id   : Interfaces.Integer_32 := 0;
      Beacon_Max_Len      : Interfaces.Integer_32 := 752;
      Mgmt_Sbuf_Num       : Interfaces.Integer_32 := 32;
      Feature_Caps        : Interfaces.Unsigned_64 := 16#A1#;
      Sta_Disconnected_Pm : Interfaces.Integer_32 := 1;   --  C bool in a word
      Espnow_Max_Encrypt  : Interfaces.Integer_32 := 7;
      Tx_Hetb_Queue_Num   : Interfaces.Integer_32 := 1;
      Dump_Hesigb_Enable  : Interfaces.Integer_32 := 0;   --  C bool in a word
      Magic               : Interfaces.Integer_32 := 16#1F2F3F4F#;
   end record
     with Convention => C;
   for Wifi_Init_Config'Size use 152 * 8;

   --  Default config with our OS-adapter table and the extern crypto funcs.
   function Default_Config (Osi_Table : System.Address) return Wifi_Init_Config
   is (Osi_Funcs  => Osi_Table,
       Wpa_Crypto => G_Default_Wpa_Crypto,
       others     => <>);

   --  --- entry points (link against the blobs) -----------------------------

   --  The public esp_wifi_init is an open-source IDF wrapper (not in the blobs);
   --  it does PHY power-domain/modem + supplicant setup around the blob core.  We
   --  call the blob core directly and add the wrapper's steps as hardware demands
   --  (see ESP32S3.WiFi.Port and BRINGUP.md).
   function Esp_Wifi_Init (Config : System.Address) return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_init_internal";

   function Esp_Wifi_Set_Mode (Mode : Interfaces.Integer_32) return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_set_mode";

   function Esp_Wifi_Start return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_start";

   --  Config = null gives a default all-channel scan; Block /= 0 waits for it.
   function Esp_Wifi_Scan_Start
     (Config : System.Address; Block : Interfaces.Unsigned_8) return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_scan_start";

   function Esp_Wifi_Scan_Get_Ap_Num
     (Number : access Interfaces.Unsigned_16) return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_scan_get_ap_num";

   function Esp_Wifi_Scan_Get_Ap_Records
     (Number : access Interfaces.Unsigned_16; Ap_Records : System.Address)
      return Esp_Err
     with Import, Convention => C,
          External_Name => "esp_wifi_scan_get_ap_records";

   --  --- association / data path -------------------------------------------
   WIFI_IF_STA : constant Interfaces.Integer_32 := 0;

   --  wifi_config_t (union; STA is the largest) = 184 bytes; ssid at offset 0
   --  (uint8[32]), password at 32, threshold at 116.  A zeroed config with just
   --  the SSID connects to an OPEN AP (threshold.authmode = 0 = OPEN).
   Config_Size : constant := 184;

   function Esp_Wifi_Set_Config
     (Interface_Id : Interfaces.Integer_32; Config : System.Address)
      return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_set_config";

   --  esp_wifi_connect is an open IDF wrapper; the blob core is _internal.
   function Esp_Wifi_Connect return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_connect_internal";

   --  Returns ESP_OK only while associated (fills a wifi_ap_record_t = 92 B).
   function Esp_Wifi_Sta_Get_Ap_Info (Ap_Info : System.Address) return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_sta_get_ap_info";

   --  Register the 802.3 RX callback (opens the data path; also the M3 NIC seam).
   function Esp_Wifi_Internal_Reg_Rxcb
     (Interface_Id : Interfaces.Integer_32; Cb : System.Address) return Esp_Err
     with Import, Convention => C,
          External_Name => "esp_wifi_internal_reg_rxcb";

   procedure Esp_Wifi_Internal_Free_Rx_Buffer (Eb : System.Address)
     with Import, Convention => C,
          External_Name => "esp_wifi_internal_free_rx_buffer";

   --  Transmit a raw 802.3 frame on an interface (the M3 NIC TX seam).
   function Esp_Wifi_Internal_Tx
     (Interface_Id : Interfaces.Integer_32; Buffer : System.Address;
      Len : Interfaces.Unsigned_16) return Esp_Err
     with Import, Convention => C, External_Name => "esp_wifi_internal_tx";

end ESP32S3.WiFi.IDF;
