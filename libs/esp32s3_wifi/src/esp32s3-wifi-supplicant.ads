--  WPA2-PSK supplicant (the 4-way handshake), pure Ada over the ESP32-S3
--  hardware SHA-1 and AES.  The blob's net80211 does 802.11 auth/assoc and hands
--  us the EAPOL-Key frames through the wpa_funcs callbacks (see ESP32S3.WiFi.
--  Port): wpa_sta_connect gives us the AP MAC, wpa_sta_rx_eapol feeds each
--  EAPOL-Key.  We derive the PMK (PBKDF2-HMAC-SHA1), run the handshake (PTK via
--  SHA1-PRF, MIC via HMAC-SHA1, GTK via AES key-unwrap), reply with msg 2/4 over
--  esp_wifi_internal_tx, and install the keys with esp_wifi_set_sta_key_internal.
with Interfaces;
with System;

private package ESP32S3.WiFi.Supplicant is

   --  Set once from ESP32S3.WiFi.Connect, before association starts.
   procedure Set_Credentials (SSID : String; Passphrase : String);

   --  Publish our RSN IE (WPA2-PSK-CCMP) as the assoc IE so the blob's assoc
   --  request advertises WPA2 and the AP starts the 4-way handshake.  MUST be
   --  called from a NON-wifi-task context (e.g. ESP32S3.WiFi.Connect on the env
   --  task) -- esp_wifi_set_appie_internal blocks and would deadlock the wifi
   --  task.  Call after set_config, before esp_wifi_connect.
   procedure Publish_Rsn_Ie;

   --  wpa_funcs hooks (called by the blob; wired into Port.Wpa_Stub).
   --  wpa_sta_connect(bssid): record the AP MAC and derive the PMK.
   function Sta_Connect (BSSID : System.Address) return Interfaces.Integer_32
     with Convention => C;

   --  wpa_sta_rx_eapol(src, buf, len): drive the 4-way handshake.
   function Rx_Eapol
     (Src : System.Address; Buf : System.Address; Len : Interfaces.Unsigned_32)
      return Interfaces.Integer_32 with Convention => C;

   --  wpa_sta_in_4way_handshake(): TRUE while the handshake is running.
   function In_4way return Interfaces.Integer_32 with Convention => C;

   --  Called from the EAPOL tx-done callback (Port.Eapol_Txcb): once msg 4 has
   --  actually left the radio, install the pairwise key.  Installing it earlier
   --  (right after queueing msg 4) makes the HW encrypt the still-queued msg 4.
   procedure On_Eapol_Txdone;

   --  Diagnostics: number of EAPOL tx-done callbacks seen, and the return code
   --  of the pairwise-key install (0 = OK; 16#7FFF# = not attempted yet).
   function Diag_Txdone_Count return Natural;
   function Diag_Ptk_Rc return Interfaces.Integer_32;

   --  The 802.1X controlled-port byte node[36] as esp_wifi_auth_done_internal
   --  left it: 0 = open (data TX allowed), 2 = EAPOL-only, -1 = node not found.
   function Diag_Port_State return Interfaces.Integer_32;

   --  Group-key install: True once a GTK KDE was found in msg 3, and the return
   --  code of esp_wifi_set_sta_key_internal for it (0 = OK, 16#7FFF# = not run).
   function Diag_Gtk_Found return Boolean;
   function Diag_Gtk_Rc return Interfaces.Integer_32;

end ESP32S3.WiFi.Supplicant;
