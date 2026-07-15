--  Pure-Ada driver for the ESP32-S3 Wi-Fi radio.
--
--  The radio's MAC/PHY are undocumented, so this drives it through Espressif's
--  closed blobs (libnet80211/libpp/libphy/libcore); the glue those blobs need --
--  the OS adapter, PHY/RF calibration, timers, interrupts -- is written in Ada
--  against the embedded (Jorvik) runtime.  See BRINGUP.md.
--
--  The end goal is to present Wi-Fi to the chip-neutral network stack as a
--  Net_Device (a NIC).  Today the surface below brings the radio up, scans for
--  access points, and associates to a WPA2-PSK network (the pure-Ada 4-way
--  handshake lives in ESP32S3.WiFi.Supplicant).  This spec is the stable public
--  face; the version-locked C structs stay internal (in the body), converted
--  into these clean records.
--
--  Concurrency: this package drives a single radio and is NOT re-entrant -- one
--  caller (typically the environment task) owns it; do not call Scan / Connect
--  from two tasks at once.  Connect returns as soon as the association is
--  started; the association and the 4-way handshake then run to completion on
--  the internal Wi-Fi task, so poll Connected to learn when the link is up.
with Interfaces;
with System;

package ESP32S3.WiFi is

   type MAC_Address is array (1 .. 6) of Interfaces.Unsigned_8;

   --  Access-point security (subset of wifi_auth_mode_t).
   type Auth_Mode is
     (Open, WEP, WPA_PSK, WPA2_PSK, WPA_WPA2_PSK,
      WPA2_Enterprise, WPA3_PSK, WPA2_WPA3_PSK, Other);

   Max_SSID : constant := 32;

   type AP_Record is record
      SSID     : String (1 .. Max_SSID) := (others => ' ');
      SSID_Len : Natural := 0;
      BSSID    : MAC_Address := (others => 0);
      Channel  : Natural := 0;
      RSSI     : Integer := 0;          --  signal strength, dBm (negative)
      Auth     : Auth_Mode := Other;
   end record;

   type AP_List is array (Positive range <>) of AP_Record;

   type Status is
     (OK,
      Not_Initialized,   --  Initialize not called or failed
      Busy,              --  a scan/operation is already running
      Timeout,
      Radio_Error);      --  the blob reported a failure

   --  Bring the radio up in station mode: clocks, PHY + RF calibration, the OS
   --  adapter, esp_wifi_init / set_mode(STA) / start.  Must succeed before Scan.
   --  (Milestone M0 -- the hard part; hardware only.)
   procedure Initialize (Result : out Status);

   --  Blocking scan for access points.  Fills Found (1 .. Count) with up to
   --  Found'Length of the strongest APs found; Count is how many were returned.
   --  (Milestone M1.)
   procedure Scan
     (Found : out AP_List; Count : out Natural; Result : out Status);

   --  Associate with an access point (Milestone M2).  Passphrase = "" connects
   --  to an OPEN network; a non-empty passphrase runs the WPA2-PSK 4-way
   --  handshake.  Connect only starts the association (it completes on the
   --  Wi-Fi task); poll Connected to know when the link is up.  BSSID pins the
   --  association to one specific AP (all-zero = let the blob pick the strongest
   --  matching SSID) -- needed when several APs share an SSID with DIFFERENT
   --  security (e.g. a WPA2 guest vAP alongside a WPA3/PMF primary).
   procedure Connect
     (SSID       : String;
      Passphrase : String := "";
      BSSID      : MAC_Address := (others => 0);
      Result     : out Status);

   --  True while associated to an AP (station has a valid link).
   function Connected return Boolean;

   --  Primary channel of the currently-associated AP (0 if not connected) --
   --  the BSSID we pin to can live on a channel other than the one a scan
   --  reported, so read it from the live link.
   function Current_Channel return Natural;

   --  BSSID of the currently-associated AP (all-zero if not connected).
   function Current_BSSID return MAC_Address;

   --  --- raw-frame seam for a software network stack (Milestone M3) ---------
   --  The blob presents the link as raw 802.3 frames (dst[6] src[6]
   --  ethertype[2] payload); a pure-Ada IP/UDP/TCP stack rides on top and is
   --  what ESP32S3.WiFi.Net_Device exposes to GNAT.Sockets.

   --  (Re)register the 802.3 RX path.  Call once the link is up: the connection
   --  setup can leave the low-level RX callback unset, so frames only start
   --  arriving after this.
   procedure Start_Data_Path;

   --  Diagnostic: how many times the RX callback has fired.
   function Rx_Callback_Count return Natural;

   --  Diagnostic: return code of the last esp_wifi_internal_reg_rxcb call
   --  (0 = OK; 16#7FFF# = Start_Data_Path not called yet).
   function Rx_Reg_Rc return Interfaces.Integer_32;

   --  Diagnostic: total frames/events the WMAC ISR has posted to ppTask.  A
   --  rising count means the radio is receiving; flat = nothing arriving.
   function Isr_Posts return Natural;

   --  Diagnostics for the WPA2 4-way handshake: number of EAPOL tx-done
   --  callbacks seen and the return code of the pairwise-key install
   --  (0 = OK; 16#7FFF# = the install was never reached).
   function Handshake_Txdone_Count return Natural;
   function Handshake_Ptk_Rc return Interfaces.Integer_32;

   --  The 802.1X controlled-port byte as the blob's auth_done left it:
   --  0 = open (data TX allowed), 2 = EAPOL-only (data blocked), -1 = no node.
   function Handshake_Port_State return Interfaces.Integer_32;

   --  Group-key (GTK) install result: was a GTK found in msg 3, and its
   --  esp_wifi_set_sta_key_internal return code (0 = OK).  Needed for receiving
   --  broadcast/multicast frames.
   function Handshake_Gtk_Found return Boolean;
   function Handshake_Gtk_Rc return Interfaces.Integer_32;

   --  Transmit one 802.3 frame.  Returns True if the blob accepted it.
   function Send_Frame (Data : System.Address; Len : Natural) return Boolean;

   --  Handler for a received 802.3 frame.  It is called from the Wi-Fi task
   --  context once per frame and MUST consume (copy out) the bytes during the
   --  call -- the buffer is freed on return.  Must be a closure-free,
   --  library-level procedure (No_Implicit_Dynamic_Code -- no trampolines).
   type Frame_Handler is access procedure (Data : System.Address; Len : Natural);
   procedure Set_Frame_Handler (Handler : Frame_Handler);

   --  --- PHY RF-calibration persistence -----------------------------------
   --
   --  By default the radio runs a FULL RF calibration on every bring-up (~tens
   --  of ms + a burst of analog activity).  Register storage hooks to persist
   --  the calibration result across boots: when a valid stored blob is loaded,
   --  the driver runs a fast PARTIAL calibration (temperature compensation off
   --  the stored baseline) instead of a full one.
   --
   --  The SDK owns the FULL/PARTIAL decision; the application owns the storage
   --  (main-flash partition, external SPI flash, ...), so this does not bind the
   --  driver to any particular non-volatile medium.  With no hooks registered,
   --  behaviour is unchanged (FULL cal every boot).
   --
   --  The blob is opaque (esp_phy_calibration_data_t); it carries its own
   --  version + the chip MAC, which the driver checks before trusting a loaded
   --  blob (so an image moved to another chip recalibrates).  Persist it verbatim
   --  and hand it back verbatim.
   Cal_Blob_Size : constant := 1904;
   type Cal_Blob is array (0 .. Cal_Blob_Size - 1) of Interfaces.Unsigned_8;

   --  Fill Blob from non-volatile storage.  Return True iff a stored blob was
   --  produced (its validity is then re-checked by the driver).  Must be a
   --  closure-free, library-level function (No_Implicit_Dynamic_Code).
   type Cal_Load_Hook is access function (Blob : out Cal_Blob) return Boolean;

   --  Persist Blob (called once, right after a FULL calibration).  Must be
   --  closure-free and library-level.
   type Cal_Store_Hook is access procedure (Blob : Cal_Blob);

   --  Register the pair.  Call before Initialize (the first Phy_Enable reads
   --  them).  Either may be null (e.g. Store only, to capture a baseline once).
   procedure Set_Cal_Store (Load : Cal_Load_Hook; Store : Cal_Store_Hook);

end ESP32S3.WiFi;
