with Interfaces; use Interfaces;
with System;
with System.Storage_Elements; use System.Storage_Elements;
with System.Machine_Code; use System.Machine_Code;
with ESP32S3.WiFi.Supplicant;

package body ESP32S3.WiFi.Port is

   --  ------------------------------------------------------------------------
   --  Data symbols
   --  ------------------------------------------------------------------------

   --  wpa_crypto_funcs_t default table (44 bytes): uint32 size, uint32 version,
   --  then 9 crypto function pointers.  esp_wifi_init_internal validates the
   --  leading size/version (a zero table => ESP_ERR_INVALID_ARG), so those are
   --  set; the 9 callbacks stay null -- a scan never invokes crypto (they matter
   --  only at association/EAPOL, a later milestone).  size = 44 (0x2C),
   --  version = ESP_WIFI_CRYPTO_VERSION (1), little-endian.
   type Crypto_Table is array (1 .. 44) of Interfaces.Unsigned_8;
   G_Wpa_Crypto : Crypto_Table :=
     (1 => 44, 5 => 1, others => 0)
     with Export, Convention => C,
          External_Name => "g_wifi_default_wpa_crypto_funcs";

   --  esp_event_base_t WIFI_EVENT -- a (const char *) event-base tag.  The blob
   --  passes it to the OS-adapter event-post slot; only its identity matters.
   Wifi_Event_Name : aliased constant String := "WIFI_EVENT" & ASCII.NUL;
   WIFI_EVENT : System.Address := Wifi_Event_Name'Address
     with Export, Convention => C, External_Name => "WIFI_EVENT";

   --  ------------------------------------------------------------------------
   --  PHY / logging glue
   --  ------------------------------------------------------------------------

   --  PHY critical section.  The PHY/RF register sequences (calibration) must
   --  not be interrupted, so genuinely mask interrupts: `rsil` raises INTLEVEL
   --  and returns the prior PS (nestable); `wsr.ps` restores it.
   function Phy_Enter_Critical return Interfaces.Unsigned_32
     with Export, Convention => C, External_Name => "phy_enter_critical";
   function Phy_Enter_Critical return Interfaces.Unsigned_32 is
      Old : Interfaces.Unsigned_32;
   begin
      Asm ("rsil %0, 3",
           Outputs  => Interfaces.Unsigned_32'Asm_Output ("=a", Old),
           Volatile => True);
      return Old;
   end Phy_Enter_Critical;

   procedure Phy_Exit_Critical (State : Interfaces.Unsigned_32)
     with Export, Convention => C, External_Name => "phy_exit_critical";
   procedure Phy_Exit_Critical (State : Interfaces.Unsigned_32) is
   begin
      Asm ("wsr.ps %0" & ASCII.LF & "rsync",
           Inputs   => Interfaces.Unsigned_32'Asm_Input ("a", State),
           Volatile => True);
   end Phy_Exit_Critical;

   --  printf-family sinks.  The blobs log through these; we drop the text (the
   --  varargs are ignored -- caller-cleans-up on the windowed Xtensa ABI) and
   --  report "0 characters written".
   function Phy_Printf (Fmt : System.Address) return Interfaces.Integer_32
     with Export, Convention => C, External_Name => "phy_printf";
   function Phy_Printf (Fmt : System.Address) return Interfaces.Integer_32 is (0);

   function Pp_Printf (Fmt : System.Address) return Interfaces.Integer_32
     with Export, Convention => C, External_Name => "pp_printf";
   function Pp_Printf (Fmt : System.Address) return Interfaces.Integer_32 is (0);

   function Net80211_Printf (Fmt : System.Address) return Interfaces.Integer_32
     with Export, Convention => C, External_Name => "net80211_printf";
   function Net80211_Printf (Fmt : System.Address) return Interfaces.Integer_32
   is (0);

   procedure Coex_Pti_Print
     with Export, Convention => C, External_Name => "coex_pti_print";
   procedure Coex_Pti_Print is null;

   function Puts (S : System.Address) return Interfaces.Integer_32
     with Export, Convention => C, External_Name => "puts";
   function Puts (S : System.Address) return Interfaces.Integer_32 is (0);

   --  sprintf(buf, fmt, ...) -> int.  Minimal: NUL-terminate the buffer and
   --  report 0.  A scan does not depend on formatted output.
   function Sprintf (Buf : System.Address; Fmt : System.Address)
     return Interfaces.Integer_32
     with Export, Convention => C, External_Name => "sprintf";
   function Sprintf (Buf : System.Address; Fmt : System.Address)
     return Interfaces.Integer_32
   is
      B : Interfaces.Unsigned_8 with Import, Address => Buf;
   begin
      B := 0;
      return 0;
   end Sprintf;

   --  hexstr2bin(hex, buf, len): parse up to len bytes of ASCII hex into buf.
   --  Returns 0 on success, -1 on a malformed digit (wpa_supplicant semantics).
   function Hexstr2bin
     (Hex : System.Address; Buf : System.Address; Len : Interfaces.Unsigned_32)
      return Interfaces.Integer_32
     with Export, Convention => C, External_Name => "hexstr2bin";
   function Hexstr2bin
     (Hex : System.Address; Buf : System.Address; Len : Interfaces.Unsigned_32)
      return Interfaces.Integer_32
   is
      function Nyb (C : Interfaces.Unsigned_8; V : out Interfaces.Unsigned_8)
        return Boolean is
      begin
         case C is
            when Character'Pos ('0') .. Character'Pos ('9') =>
               V := C - Character'Pos ('0');
            when Character'Pos ('a') .. Character'Pos ('f') =>
               V := C - Character'Pos ('a') + 10;
            when Character'Pos ('A') .. Character'Pos ('F') =>
               V := C - Character'Pos ('A') + 10;
            when others =>
               return False;
         end case;
         return True;
      end Nyb;

      Hi, Lo : Interfaces.Unsigned_8;
   begin
      for I in 0 .. Integer (Len) - 1 loop
         declare
            Hc : Interfaces.Unsigned_8
              with Import, Address => Hex + Storage_Offset (2 * I);
            Lc : Interfaces.Unsigned_8
              with Import, Address => Hex + Storage_Offset (2 * I + 1);
            Ob : Interfaces.Unsigned_8
              with Import, Address => Buf + Storage_Offset (I);
         begin
            if not Nyb (Hc, Hi) or else not Nyb (Lc, Lo) then
               return -1;
            end if;
            Ob := Interfaces.Shift_Left (Hi, 4) or Lo;
         end;
      end loop;
      return 0;
   end Hexstr2bin;

   --  ------------------------------------------------------------------------
   --  Minimal wpa_funcs table (27 function-pointer slots).  Every slot points
   --  at a no-op returning 0, which satisfies int/bool/pointer returns on the
   --  windowed ABI; void returns ignore it.  Registered with the blob so
   --  g_ic+0x1b4 is non-null and the RX ISR's wpa_sta_rx_mgmt(+0x54) call is
   --  safe (returns "not handled" -> the scan module keeps the beacon).
   function Wpa_Noop return Interfaces.Integer_32 with Convention => C;
   function Wpa_Noop return Interfaces.Integer_32 is (0);   --  int: 0 = OK

   function Wpa_True return Interfaces.Integer_32 with Convention => C;
   function Wpa_True return Interfaces.Integer_32 is (1);   --  bool: TRUE = OK

   --  EAPOL TX-done callback (eapol_txcb_t = void(u8*, size_t, bool)).  The
   --  real wpa_attach registers this in wpa_sta_init; the blob may gate its
   --  EAPOL RX/handshake handoff on a registered supplicant.
   procedure Eapol_Txcb
     (Payload : System.Address; Len : Interfaces.Unsigned_32;
      Failure : Interfaces.Unsigned_8) with Convention => C;
   procedure Eapol_Txcb
     (Payload : System.Address; Len : Interfaces.Unsigned_32;
      Failure : Interfaces.Unsigned_8)
   is
      pragma Unreferenced (Payload, Len, Failure);
   begin
      Supplicant.On_Eapol_Txdone;   --  installs the PTK once msg 4 has left
   end Eapol_Txcb;

   function C_Register_Eapol_Txdonecb (Fn : System.Address)
      return Interfaces.Integer_32
     with Import, Convention => C,
          External_Name => "esp_wifi_register_eapol_txdonecb_internal";

   --  wpa_sta_init: mirror wpa_attach's blob-facing step (register the EAPOL
   --  tx-done cb) then return TRUE.
   function Wpa_Sta_Init return Interfaces.Integer_32 with Convention => C;
   function Wpa_Sta_Init return Interfaces.Integer_32 is
      Rc : constant Interfaces.Integer_32 :=
        C_Register_Eapol_Txdonecb (Eapol_Txcb'Address);
      pragma Unreferenced (Rc);
   begin
      return 1;
   end Wpa_Sta_Init;

   --  The wpa_funcs table (27 slots, blob order).  The pure-Ada supplicant
   --  supplies the ones that drive a WPA2-PSK connection -- sta_init (registers
   --  the EAPOL tx-done cb), sta_connect, rx_eapol, in_4way_handshake.  The
   --  bool-returning slots must return TRUE for "ok" (Wpa_True); every other
   --  slot is a Wpa_Noop returning 0, which satisfies int/bool/pointer returns
   --  on the windowed ABI and lets the blob run (void returns ignore it).
   type Fn_Table is array (1 .. 27) of System.Address;
   Wpa_Stub : aliased Fn_Table :=
     (1  => Wpa_Sta_Init'Address,             --  wpa_sta_init      (bool)
      2  => Wpa_True'Address,                 --  wpa_sta_deinit    (bool)
      3  => Supplicant.Sta_Connect'Address,   --  wpa_sta_connect
      6  => Supplicant.Rx_Eapol'Address,      --  wpa_sta_rx_eapol
      7  => Supplicant.In_4way'Address,       --  wpa_sta_in_4way_handshake
      others => Wpa_Noop'Address);

   procedure Esp_Wifi_Register_Wpa_Cb (Cb : System.Address)
     with Import, Convention => C,
          External_Name => "esp_wifi_register_wpa_cb_internal";

   procedure Register_Wpa_Stub is
   begin
      Esp_Wifi_Register_Wpa_Cb (Wpa_Stub'Address);
   end Register_Wpa_Stub;

   --  ------------------------------------------------------------------------
   --  Mesh entry points -- unreachable in STA scan; no-ops that keep the link
   --  resolved.  (esp-mesh is a separate feature we do not build.)
   --  ------------------------------------------------------------------------
   procedure Mesh_Noop_1
     with Export, Convention => C, External_Name => "ieee80211_init_mesh_assoc_ie";
   procedure Mesh_Noop_1 is null;
   procedure Mesh_Noop_2
     with Export, Convention => C, External_Name => "ieee80211_vnd_mesh_quick_get";
   procedure Mesh_Noop_2 is null;
   procedure Mesh_Noop_3
     with Export, Convention => C, External_Name => "ieee80211_vnd_mesh_quick_set";
   procedure Mesh_Noop_3 is null;
   procedure Mesh_Noop_4
     with Export, Convention => C, External_Name => "ieee80211_vnd_mesh_roots_get";
   procedure Mesh_Noop_4 is null;
   procedure Mesh_Noop_5
     with Export, Convention => C, External_Name => "ieee80211_vnd_mesh_roots_set";
   procedure Mesh_Noop_5 is null;
   procedure Mesh_Noop_6
     with Export, Convention => C, External_Name => "mesh_clear_parent_candidate";
   procedure Mesh_Noop_6 is null;
   procedure Mesh_Noop_7
     with Export, Convention => C, External_Name => "mesh_get_parent_candidate";
   procedure Mesh_Noop_7 is null;
   procedure Mesh_Noop_8
     with Export, Convention => C,
          External_Name => "mesh_get_parent_monitor_config";
   procedure Mesh_Noop_8 is null;
   procedure Mesh_Noop_9
     with Export, Convention => C, External_Name => "mesh_get_rssi_threshold";
   procedure Mesh_Noop_9 is null;
   procedure Mesh_Noop_10
     with Export, Convention => C, External_Name => "mesh_set_ie_crypto_config";
   procedure Mesh_Noop_10 is null;
   procedure Mesh_Noop_11
     with Export, Convention => C, External_Name => "mesh_set_parent_candidate";
   procedure Mesh_Noop_11 is null;
   procedure Mesh_Noop_12
     with Export, Convention => C,
          External_Name => "mesh_set_parent_monitor_config";
   procedure Mesh_Noop_12 is null;
   procedure Mesh_Noop_13
     with Export, Convention => C, External_Name => "mesh_set_rssi_threshold";
   procedure Mesh_Noop_13 is null;

end ESP32S3.WiFi.Port;
