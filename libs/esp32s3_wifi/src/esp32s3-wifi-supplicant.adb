with Interfaces;              use Interfaces;
with Ada.Real_Time;           use Ada.Real_Time;
with Ada.Unchecked_Conversion;
with System;
with System.Storage_Elements; use System.Storage_Elements;
with ESP32S3.SHA;
with ESP32S3.MAC;
with ESP32S3.AES;
with ESP32S3.Log;

package body ESP32S3.WiFi.Supplicant is

   subtype U8  is Interfaces.Unsigned_8;
   type Bytes is array (Natural range <>) of U8;

   --  --- credentials + handshake state ------------------------------------
   G_Ssid     : Bytes (0 .. 31) := (others => 0);
   G_Ssid_Len : Natural := 0;
   G_Pass     : Bytes (0 .. 63) := (others => 0);
   G_Pass_Len : Natural := 0;

   AA    : Bytes (0 .. 5) := (others => 0);     --  AP MAC (authenticator)
   SPA   : Bytes (0 .. 5) := (others => 0);     --  our MAC (supplicant)
   PMK   : Bytes (0 .. 31) := (others => 0);
   SNonce : Bytes (0 .. 31) := (others => 0);
   KCK   : Bytes (0 .. 15) := (others => 0);
   KEK   : Bytes (0 .. 15) := (others => 0);
   TK    : Bytes (0 .. 15) := (others => 0);

   In_HS : Boolean := False;
   Install_Pending : Boolean := False;   --  install PTK on next EAPOL tx-done

   --  --- blob entry points -------------------------------------------------
   function C_Tx (Ifx : Interfaces.Integer_32; Buf : System.Address;
                  Len : Interfaces.Unsigned_32) return Interfaces.Integer_32
     with Import, Convention => C, External_Name => "esp_wifi_internal_tx";

   function C_Set_Key
     (Alg : Interfaces.Integer_32; Addr : System.Address;
      Key_Idx, Set_Tx : Interfaces.Integer_32; Seq : System.Address;
      Seq_Len : Interfaces.Unsigned_32; Key : System.Address;
      Key_Len : Interfaces.Unsigned_32; Key_Flag : Interfaces.Integer_32)
      return Interfaces.Integer_32
     with Import, Convention => C,
          External_Name => "esp_wifi_set_sta_key_internal";

   function C_Set_Appie
     (Kind : Interfaces.Unsigned_8; Ie : System.Address;
      Len : Interfaces.Unsigned_16; Flag : Interfaces.Unsigned_8)
      return Interfaces.Integer_32
     with Import, Convention => C,
          External_Name => "esp_wifi_set_appie_internal";

   --  Triggers the actual 802.11 association (the tail of IDF's wpa_sta_connect).
   function C_Sta_Connect (BSSID : System.Address) return Interfaces.Integer_32
     with Import, Convention => C,
          External_Name => "esp_wifi_sta_connect_internal";

   --  Tell the blob the 4-way handshake succeeded (real supplicant's
   --  wpa_neg_complete): authorises the 802.1X port + posts STA_CONNECTED.
   procedure C_Auth_Done
     with Import, Convention => C,
          External_Name => "esp_wifi_auth_done_internal";

   --  The blob's interface-control block: set_appie stores the RSN appie in it
   --  (at g_ic+56), and the assoc-req builder reads it via the active VAP (see
   --  Sta_Connect for the VAP-to-g_ic link).
   G_Ic : U8 with Import, Convention => C, External_Name => "g_ic";

   --  g_wifi_nvs holds a pointer to the active-interface state; the blob's
   --  assoc_req_construct uses a3 = [g_wifi_nvs]+4 and reads the RSN appie via
   --  [a3+64]+56.
   G_Wifi_Nvs : System.Address
     with Import, Convention => C, External_Name => "g_wifi_nvs";

   --  The ROM STA RX path (sta_input) dispatches received data frames to the
   --  callback stored in this global; esp_wifi_internal_reg_rxcb writes it.
   Sta_Rxcb_Cell : System.Address
     with Import, Convention => C, External_Name => "sta_rxcb";

   --  True when the caller runs on the blob's wifi task: ieee80211_ioctl (used
   --  by set_appie / set_sta_key / reg_rxcb / connect) only executes inline when
   --  this holds; otherwise it posts to ppTask.  Our async round-trip does not
   --  complete, so these MUST be called from a wifi-task context.
   function C_On_Wifi_Task return Interfaces.Integer_32
     with Import, Convention => C, External_Name => "current_task_is_wifi_task";

   --  ieee80211_set_sta_gtk_index(keyid, slot): writes node[0x135]=slot and
   --  node[0x137+keyid]=slot -- the per-keyid HW-slot map that crypto_decap
   --  reads.  ppInstallKey only calls this for HW slots < 2, so the PAIRWISE
   --  key (which lands in slot 4) leaves node[0x137] (unicast, keyid 0) unset
   --  and unicast CCMP decrypt drops every frame -- we set it ourselves.
   procedure C_Set_Sta_Gtk_Index (Keyid, Slot : Interfaces.Integer_32)
     with Import, Convention => C, External_Name => "ieee80211_set_sta_gtk_index";

   --  ic_set_sta(flag, ni): register (flag=1) the AP peer node as an associated
   --  HW station -- the low-MAC station-insert that binds "frames whose TA = this
   --  MAC belong to station N, decrypt with N's key slots".  cnx_node_join does
   --  this in the normal connect flow; our stub skips it, so the HW drops every
   --  encrypted frame from the AP before it reaches the software RX path.
   procedure C_Ic_Set_Sta (Flag : Interfaces.Unsigned_8; Ni : System.Address)
     with Import, Convention => C, External_Name => "ic_set_sta";

   --  cnx_node_join(ni, reason): the blob's sanctioned "node joined the BSS"
   --  handler -- populates the node's rate/cap fields, allocates its HW station
   --  index + bitmap, and runs ic_set_sta (the low-MAC station insert) that our
   --  stub skips.  (It also emits an assoc-req; we are already associated, so
   --  the AP should just re-ack.)
   procedure C_Cnx_Node_Join
     (Ni : System.Address; Reason : Interfaces.Integer_32)
     with Import, Convention => C, External_Name => "cnx_node_join";

   WPA_ALG_CCMP     : constant := 3;
   --  PAIRWISE|RX|TX -- NOT the MODIFY(0x01) variant: the blob maps MODIFY to an
   --  internal key-type 2 that skips ic_set_key, so the PTK never reaches the HW
   --  crypto table (keyvalid slot 4 stays 0).  0x2D is only for legacy WPA1
   --  Extended-Key-ID (use_ext_key_id); WPA2/WPA3 use 0x2C (see IDF wpa.c).
   KF_PTK           : constant := 16#2C#;   --  PAIRWISE|RX|TX
   --  The canonical two-step pairwise install (per blob RE) was tried as a way
   --  to avoid the direct HW-key-RAM write: 0x24 (PAIRWISE|RX, set_tx=0) to
   --  write the slot, then 0x2D (MODIFY|PAIRWISE|RX|TX) to enable TX.  It leaves
   --  the HW slot-4 material zero exactly like the single 0x2C (both reach the
   --  same hal_crypto_set_key_entry leaf), so it does NOT help.  Kept here to
   --  document the dead end; see Write_HW_Pairwise_Key for what actually works.
   KF_PTK_SET       : constant := 16#24#;   --  PAIRWISE|RX  (does not land material)
   KF_PTK_TX        : constant := 16#2D#;   --  MODIFY|PAIRWISE|RX|TX (idem)
   KF_GTK           : constant := 16#14#;   --  GROUP|RX
   WIFI_APPIE_RSN       : constant := 4;
   WIFI_APPIE_WPA       : constant := 3;
   WIFI_APPIE_ASSOC_REQ : constant := 1;   --  generic IEs appended to assoc-req

   --  ----------------------------------------------------------------------
   --  Crypto built on the hardware SHA-1 / AES.
   --  ----------------------------------------------------------------------
   subtype Digest is ESP32S3.SHA.SHA1_Digest;   --  Byte_Array (0 .. 19)

   function SHA1 (M : Bytes) return Digest is
      D : constant ESP32S3.SHA.Byte_Array (0 .. M'Length - 1) :=
        ESP32S3.SHA.Byte_Array (M);
   begin
      return ESP32S3.SHA.Hash_1 (D);
   end SHA1;

   function HMAC (Key, Msg : Bytes) return Digest is
      K0    : Bytes (0 .. 63) := (others => 0);
      Ipad  : Bytes (0 .. 63);
      Opad  : Bytes (0 .. 63);
      Inner : Bytes (0 .. 63 + Msg'Length);
      Outer : Bytes (0 .. 63 + 20);
   begin
      if Key'Length > 64 then
         declare
            KH : constant Digest := SHA1 (Key);
         begin
            K0 (0 .. 19) := Bytes (KH);
         end;
      else
         K0 (0 .. Key'Length - 1) := Key;
      end if;
      for I in 0 .. 63 loop
         Ipad (I) := K0 (I) xor 16#36#;
         Opad (I) := K0 (I) xor 16#5C#;
      end loop;
      Inner (0 .. 63) := Ipad;
      Inner (64 .. 63 + Msg'Length) := Msg;
      Outer (0 .. 63) := Opad;
      Outer (64 .. 83) := Bytes (SHA1 (Inner));
      return SHA1 (Outer);
   end HMAC;

   --  PBKDF2-HMAC-SHA1(pass, ssid, 4096, 32) -> the WPA PMK.
   procedure Derive_PMK is
      C     : constant := 4096;
      procedure F (Block : U8; Out20 : out Bytes) is
         Salt : Bytes (0 .. G_Ssid_Len + 3);
         U    : Digest;
         T    : Bytes (0 .. 19) := (others => 0);
      begin
         Salt (0 .. G_Ssid_Len - 1) := G_Ssid (0 .. G_Ssid_Len - 1);
         Salt (G_Ssid_Len)     := 0;
         Salt (G_Ssid_Len + 1) := 0;
         Salt (G_Ssid_Len + 2) := 0;
         Salt (G_Ssid_Len + 3) := Block;
         U := HMAC (G_Pass (0 .. G_Pass_Len - 1), Salt);
         T := Bytes (U);
         for Iter in 2 .. C loop
            U := HMAC (G_Pass (0 .. G_Pass_Len - 1), Bytes (U));
            for I in 0 .. 19 loop
               T (I) := T (I) xor U (I);
            end loop;
         end loop;
         Out20 := T;
      end F;
      B1 : Bytes (0 .. 19);
      B2 : Bytes (0 .. 19);
   begin
      F (1, B1);
      F (2, B2);
      PMK (0 .. 19)  := B1;
      PMK (20 .. 31) := B2 (0 .. 11);
   end Derive_PMK;

   --  SHA1-PRF(K, label, data, n bytes).
   procedure PRF (K : Bytes; Label : String; Data : Bytes;
                  Out_Bytes : out Bytes)
   is
      N    : constant Natural := Out_Bytes'Length;
      Msg  : Bytes (0 .. Label'Length + Data'Length + 1);
      Pos  : Natural := 0;
      Ctr  : U8 := 0;
   begin
      for I in Label'Range loop
         Msg (I - Label'First) := Character'Pos (Label (I));
      end loop;
      Msg (Label'Length) := 0;
      Msg (Label'Length + 1 .. Label'Length + Data'Length) := Data;
      while Pos < N loop
         Msg (Msg'Last) := Ctr;
         declare
            H : constant Digest := HMAC (K, Msg);
            Take : constant Natural := Natural'Min (20, N - Pos);
         begin
            Out_Bytes (Out_Bytes'First + Pos ..
                       Out_Bytes'First + Pos + Take - 1) :=
              Bytes (H) (0 .. Take - 1);
            Pos := Pos + Take;
         end;
         Ctr := Ctr + 1;
      end loop;
   end PRF;

   --  a < b for equal-length byte strings (big-endian numeric compare).
   function Lt (A, B : Bytes) return Boolean is
   begin
      for I in 0 .. A'Length - 1 loop
         if A (A'First + I) /= B (B'First + I) then
            return A (A'First + I) < B (B'First + I);
         end if;
      end loop;
      return False;
   end Lt;

   --  Derive the PTK from PMK + the two MACs + the two nonces (802.11i).
   procedure Derive_PTK (ANonce_In : Bytes) is
      An   : constant Bytes (0 .. 31) := ANonce_In;   --  normalise bounds
      Data : Bytes (0 .. 75);   --  min|max MAC (12) + min|max nonce (64)
      PTK  : Bytes (0 .. 47);
   begin
      if Lt (AA, SPA) then
         Data (0 .. 5) := AA;  Data (6 .. 11) := SPA;
      else
         Data (0 .. 5) := SPA; Data (6 .. 11) := AA;
      end if;
      if Lt (An, SNonce) then
         Data (12 .. 43) := An;  Data (44 .. 75) := SNonce;
      else
         Data (12 .. 43) := SNonce;  Data (44 .. 75) := An;
      end if;
      PRF (PMK, "Pairwise key expansion", Data, PTK);
      KCK := PTK (0 .. 15);
      KEK := PTK (16 .. 31);
      TK  := PTK (32 .. 47);
   end Derive_PTK;

   --  ----------------------------------------------------------------------
   --  EAPOL-Key frame offsets (within the 802.1X payload the blob hands us).
   --  ----------------------------------------------------------------------
   O_Info   : constant := 5;    --  key_info (2, big-endian)
   O_Replay : constant := 9;    --  replay counter (8)
   O_Nonce  : constant := 17;   --  key_nonce (32)
   O_RSC    : constant := 65;   --  key RSC (8) -- initial group-key seq
   O_MIC    : constant := 81;   --  key_mic (16)
   O_DataLn : constant := 97;   --  key_data_length (2)
   O_Data   : constant := 99;   --  key_data

   --  The RSN IE we (via the blob) put in the assoc request -- WPA2-PSK-CCMP.
   RSN_IE : constant Bytes (0 .. 21) :=
     (16#30#, 16#14#, 16#01#, 16#00#,
      16#00#, 16#0F#, 16#AC#, 16#04#,        --  group cipher: CCMP
      16#01#, 16#00#, 16#00#, 16#0F#, 16#AC#, 16#04#,  --  pairwise: CCMP
      16#01#, 16#00#, 16#00#, 16#0F#, 16#AC#, 16#02#,  --  AKM: PSK
      16#00#, 16#00#);                        --  RSN cap: none -- matches the
                                              --  IE a real client uses on this
                                              --  AP (sniffer-confirmed)

   --  The appie must be a WRITABLE {u16 len, IE bytes} buffer: esp_wifi_set_
   --  appie_internal (flag=1) writes the length into the first two bytes and
   --  stores the pointer; the assoc-req builder then reads the IE from ptr+2.
   --  (A read-only raw IE in flash fails both the len write and the +2 read.)
   Appie_Buf : Bytes (0 .. 23) :=
     (0, 0) & RSN_IE;

   --  Rough entropy for SNonce (connectivity, not strong randomness).
   procedure Fill_SNonce is
      T : constant Unsigned_64 :=
        Unsigned_64 (To_Duration (Clock - Time_First) * 1_000_000.0);
      S : Unsigned_32 := Unsigned_32 (T and 16#FFFF_FFFF#) xor 16#5A5A_1234#;
   begin
      for I in SNonce'Range loop
         S := S * 1_103_515_245 + 12_345;
         SNonce (I) := U8 (Shift_Right (S, 24) and 16#FF#);
      end loop;
   end Fill_SNonce;

   --  Send an EAPOL-Key body as an 802.3 frame (dst=AA, src=SPA, 0x888E).
   procedure Send_Eapol (Body_Bytes : Bytes) is
      Frame : Bytes (0 .. 13 + Body_Bytes'Length);
   begin
      Frame (0 .. 5)   := AA;               --  dst
      Frame (6 .. 11)  := SPA;              --  src
      Frame (12)       := 16#88#;           --  ethertype 0x888E (EAPOL)
      Frame (13)       := 16#8E#;
      Frame (14 .. 13 + Body_Bytes'Length) := Body_Bytes;
      declare
         Rc : constant Interfaces.Integer_32 :=
           C_Tx (0, Frame'Address, Frame'Length);
         pragma Unreferenced (Rc);
      begin
         null;
      end;
   end Send_Eapol;

   --  Build msg 2 or 4 of the 4-way handshake and send it (MIC over the body).
   procedure Send_Reply
     (Replay : Bytes; Info : Unsigned_16; Nonce : Bytes; Key_Data : Bytes)
   is
      Klen : constant Natural := Key_Data'Length;
      Body_Bytes : Bytes (0 .. O_Data + Klen - 1) := (others => 0);
      Mic  : Digest;
   begin
      Body_Bytes (0) := 2;                        --  802.1X version 2
      Body_Bytes (1) := 3;                        --  type = EAPOL-Key
      Body_Bytes (2) := U8 (Shift_Right (Unsigned_16 (O_Data + Klen - 4), 8));
      Body_Bytes (3) := U8 (Unsigned_16 (O_Data + Klen - 4) and 16#FF#);
      Body_Bytes (4) := 2;                        --  descriptor type = RSN
      Body_Bytes (O_Info)     := U8 (Shift_Right (Info, 8));
      Body_Bytes (O_Info + 1) := U8 (Info and 16#FF#);
      Body_Bytes (O_Replay .. O_Replay + 7) := Replay;
      Body_Bytes (O_Nonce .. O_Nonce + 31) := Nonce;
      Body_Bytes (O_DataLn)     := U8 (Shift_Right (Unsigned_16 (Klen), 8));
      Body_Bytes (O_DataLn + 1) := U8 (Unsigned_16 (Klen) and 16#FF#);
      if Klen > 0 then
         Body_Bytes (O_Data .. O_Data + Klen - 1) := Key_Data;
      end if;
      --  MIC over the whole body with the MIC field zeroed (already zero).
      Mic := HMAC (KCK, Body_Bytes);
      Body_Bytes (O_MIC .. O_MIC + 15) := Bytes (Mic) (0 .. 15);
      Send_Eapol (Body_Bytes);
   end Send_Reply;

   --  --- group key (GTK) -----------------------------------------------------
   --  msg 3's key_data is AES-key-wrapped (RFC 3394) under the KEK; unwrap it,
   --  find the GTK KDE, and install the group key so we can receive broadcast /
   --  multicast (ARP, the DHCP OFFER) -- everything the AP sends group-addressed.
   Gtk_Rc    : Interfaces.Integer_32 := 16#7FFF#;   --  not attempted
   Gtk_Found : Boolean := False;

   --  RFC 3394 AES key unwrap.  Wrapped'Length must be a multiple of 8 and > 8;
   --  Plain gets Wrapped'Length - 8 bytes.  Ok is False if the integrity check
   --  (the recovered A == A6A6...A6) fails.
   procedure AES_Unwrap
     (Kek : Bytes; Wrapped : Bytes; Plain : out Bytes; Ok : out Boolean)
   is
      N : constant Natural := Wrapped'Length / 8 - 1;
      A : Bytes (0 .. 7);
      R : Bytes (0 .. Natural'Max (N, 1) * 8 - 1);
      K : constant ESP32S3.AES.Key_Bytes (0 .. 15) :=
        ESP32S3.AES.Key_Bytes (Kek (Kek'First .. Kek'First + 15));
   begin
      Ok := False;
      Plain := (Plain'Range => 0);
      if N = 0 or else Wrapped'Length mod 8 /= 0
        or else Plain'Length < N * 8
      then
         return;
      end if;
      for B in 0 .. 7 loop
         A (B) := Wrapped (Wrapped'First + B);
      end loop;
      for I in 0 .. N * 8 - 1 loop
         R (I) := Wrapped (Wrapped'First + 8 + I);
      end loop;
      for J in reverse 0 .. 5 loop
         for I in reverse 1 .. N loop
            declare
               T   : constant Unsigned_64 := Unsigned_64 (N * J + I);
               Blk : ESP32S3.AES.Block;
               Dec : ESP32S3.AES.Block;
            begin
               for B in 0 .. 7 loop            --  A := A xor t (big-endian)
                  A (B) := A (B) xor
                    U8 (Shift_Right (T, (7 - B) * 8) and 16#FF#);
               end loop;
               for B in 0 .. 7 loop
                  Blk (B)     := A (B);
                  Blk (8 + B) := R ((I - 1) * 8 + B);
               end loop;
               Dec := ESP32S3.AES.Decrypt_ECB (K, Blk);
               for B in 0 .. 7 loop
                  A (B) := Dec (B);
                  R ((I - 1) * 8 + B) := Dec (8 + B);
               end loop;
            end;
         end loop;
      end loop;
      Ok := (for all B in 0 .. 7 => A (B) = 16#A6#);
      for I in 0 .. N * 8 - 1 loop
         Plain (Plain'First + I) := R (I);
      end loop;
   end AES_Unwrap;

   --  Unwrap msg 3's key_data, locate the GTK KDE (00-0F-AC type 1), and install
   --  the group key.  Msg is the whole EAPOL-Key body handed to us.
   procedure Install_Gtk_From_Msg3 (Msg : Bytes) is
      Klen  : constant Natural :=
        Natural (Shift_Left (Unsigned_16 (Msg (Msg'First + O_DataLn)), 8) or
                 Unsigned_16 (Msg (Msg'First + O_DataLn + 1)));
      Plain : Bytes (0 .. (if Klen >= 8 then Klen - 8 - 1 else 0));
      Ok    : Boolean;
   begin
      if Klen < 16 or else Klen mod 8 /= 0
        or else Msg'First + O_Data + Klen - 1 > Msg'Last
      then
         return;
      end if;
      AES_Unwrap (KEK, Msg (Msg'First + O_Data .. Msg'First + O_Data + Klen - 1),
                  Plain, Ok);
      if not Ok then
         return;
      end if;
      --  Walk the KDEs / IEs in the plaintext key_data looking for the GTK KDE:
      --  0xDD, len, 00 0F AC, 01, key-info, reserved, GTK(16).
      declare
         I : Natural := Plain'First;
      begin
         while I + 1 <= Plain'Last loop
            declare
               Id  : constant U8 := Plain (I);
               Len : constant Natural := Natural (Plain (I + 1));
            begin
               exit when Len = 0 or else I + 1 + Len > Plain'Last;
               if Id = 16#DD# and then Len >= 22
                 and then Plain (I + 2) = 16#00# and then Plain (I + 3) = 16#0F#
                 and then Plain (I + 4) = 16#AC# and then Plain (I + 5) = 16#01#
               then
                  declare
                     Key_Id : constant Interfaces.Integer_32 :=
                       Interfaces.Integer_32 (Plain (I + 6) and 16#03#);
                     Set_Tx : constant Interfaces.Integer_32 :=
                       (if (Plain (I + 6) and 16#04#) /= 0 then 1 else 0);
                     Gtk    : Bytes (0 .. 15) := Plain (I + 8 .. I + 23);
                     Rsc    : Bytes (0 .. 5)  := Msg (Msg'First + O_RSC ..
                                                      Msg'First + O_RSC + 5);
                  begin
                     Gtk_Found := True;
                     --  addr = the AP's MAC (AA), exactly as the ESP supplicant
                     --  does (wpa.c wpa_supplicant_install_gtk passes sm->bssid,
                     --  NOT broadcast -- the commented-out ff:ff:.. is a trap).
                     Gtk_Rc := C_Set_Key (WPA_ALG_CCMP, AA'Address, Key_Id,
                                          Set_Tx, Rsc'Address, 6, Gtk'Address,
                                          16, KF_GTK);
                     return;
                  end;
               end if;
               I := I + 2 + Len;
            end;
         end loop;
      end;
   end Install_Gtk_From_Msg3;

   --  ----------------------------------------------------------------------
   procedure Set_Credentials (SSID : String; Passphrase : String) is
   begin
      G_Ssid_Len := Natural'Min (SSID'Length, 32);
      for I in 0 .. G_Ssid_Len - 1 loop
         G_Ssid (I) := Character'Pos (SSID (SSID'First + I));
      end loop;
      G_Pass_Len := Natural'Min (Passphrase'Length, 64);
      for I in 0 .. G_Pass_Len - 1 loop
         G_Pass (I) := Character'Pos (Passphrase (Passphrase'First + I));
      end loop;
   end Set_Credentials;

   --  Our station MAC = the eFuse factory base MAC (via the shared HAL).
   procedure Read_Own_Mac is
      M : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Wi_Fi_Station;
   begin
      for I in 0 .. 5 loop
         SPA (I) := M (I);
      end loop;
   end Read_Own_Mac;

   Txdone_Count : Natural := 0;
   Ptk_Rc       : Interfaces.Integer_32 := 16#7FFF#;   --  not attempted

   --  The AP peer node: node = *(*(g_ic + 16) + 228).  Used for the controlled
   --  port byte (node[36]), the key-slot map, and the HW station binding.
   function Read_Ptr (A : System.Address) return System.Address is
      P : System.Address with Import, Address => A;
   begin
      return P;
   end Read_Ptr;

   function Node_Addr return System.Address is
      use type System.Address;
      Iface : constant System.Address := Read_Ptr (G_Ic'Address + 16);
   begin
      if Iface = System.Null_Address then
         return System.Null_Address;
      end if;
      return Read_Ptr (Iface + 228);
   end Node_Addr;

   function Sta_Connect (BSSID : System.Address) return Interfaces.Integer_32 is
      use type System.Address;
      B : Bytes (0 .. 5) with Import, Address => BSSID;
   begin
      AA := B;
      Read_Own_Mac;
      Derive_PMK;   --  PBKDF2-HMAC-SHA1(pass, ssid, 4096, 32)
      In_HS := True;

      --  Publish the assoc RSN IE here (wifi task, right before the assoc), as
      --  the real wpa_sta_connect does -- safe inline thanks to the OS-adapter
      --  task-identity fix (esp_wifi_set_appie_internal's ieee80211_ioctl runs
      --  in place instead of posting+waiting on the wifi task = a deadlock).
      if G_Pass_Len > 0 then
         Publish_Rsn_Ie;
         --  Link the active VAP's appie base ([a3+64], a3 = [g_wifi_nvs]+4) to
         --  g_ic, where set_appie stored the RSN appie.  The blob's assoc-req
         --  builder reads the RSN IE from [a3+64]+56, but our stubbed connection
         --  setup leaves that pointer null, so the RSN IE would be dropped.
         declare
            A3       : constant System.Address := G_Wifi_Nvs + 4;
            Vap_Base : System.Address with Import, Address => A3 + 64;
         begin
            Vap_Base := G_Ic'Address;
         end;
      end if;

      --  Register the 802.3 RX callback HERE, in the wifi-task context (same as
      --  the appie/connect ioctls above): esp_wifi_internal_reg_rxcb's ioctl
      --  (cmd 26) stores sta_rxcb synchronously only when
      --  current_task_is_wifi_task() is true; from the env task it is posted to
      --  ppTask and never lands, so sta_input drops every received data frame.
      ESP32S3.WiFi.Start_Data_Path;

      --  Issue the association synchronously, exactly as the real
      --  wpa_sta_connect does (its tail is esp_wifi_sta_connect_internal); the
      --  task-identity fix keeps this ioctl inline too, so no deferral needed.
      return C_Sta_Connect (AA'Address);
   end Sta_Connect;

   function Rx_Eapol
     (Src : System.Address; Buf : System.Address; Len : Interfaces.Unsigned_32)
      return Interfaces.Integer_32
   is
      pragma Unreferenced (Src);
      L    : constant Natural := Natural (Len);
      Msg  : Bytes (0 .. L - 1) with Import, Address => Buf;
      Info : constant Unsigned_16 :=
        Shift_Left (Unsigned_16 (Msg (O_Info)), 8) or
        Unsigned_16 (Msg (O_Info + 1));
      Has_Mic : constant Boolean := (Info and 16#0100#) /= 0;
      Replay  : constant Bytes := Msg (O_Replay .. O_Replay + 7);
   begin
      if not Has_Mic then
         --  Message 1/4: ANonce present, no MIC.  Reply with msg 2 (SNonce+RSN).
         Fill_SNonce;
         Derive_PTK (Msg (O_Nonce .. O_Nonce + 31));
         Send_Reply (Replay,
                     Info => 16#010A#,   --  version 2 | pairwise | MIC
                     Nonce => SNonce,
                     Key_Data => RSN_IE);
      else
         --  Message 3/4: install the group key from the (AES-wrapped) key_data,
         --  reply with msg 4, then install the pairwise key once msg 4 has left
         --  the radio (see On_Eapol_Txdone).  The GTK lets us receive broadcast
         --  and multicast frames (ARP, the DHCP OFFER, ...).
         Install_Gtk_From_Msg3 (Msg);
         Send_Reply (Replay,
                     Info => 16#030A#,   --  version 2 | pairwise | MIC | secure
                     Nonce => (0 .. 31 => 0),
                     Key_Data => (1 .. 0 => 0));
         Install_Pending := True;
      end if;
      return 0;
   end Rx_Eapol;

   function In_4way return Interfaces.Integer_32 is
     (if In_HS then 1 else 0);

   function Diag_Txdone_Count return Natural is (Txdone_Count);
   function Diag_Ptk_Rc return Interfaces.Integer_32 is (Ptk_Rc);

   Port_Seen : Interfaces.Integer_32 := -1;   --  node[36] as auth_done left it
   function Diag_Port_State return Interfaces.Integer_32 is (Port_Seen);
   function Diag_Gtk_Found return Boolean is (Gtk_Found);
   function Diag_Gtk_Rc return Interfaces.Integer_32 is (Gtk_Rc);

   --  Force the controlled port open (node[36] := 0) -- what cnx_auth_done is
   --  supposed to do; belt-and-suspenders if its early-exits skipped the write.
   procedure Force_Port_Open is
      use type System.Address;
      N : constant System.Address := Node_Addr;
   begin
      if N /= System.Null_Address then
         declare
            B : U8 with Import, Address => N + 36;
         begin
            B := 0;
         end;
      end if;
   end Force_Port_Open;

   --  Write the raw 16-byte pairwise key (TK) into the hardware crypto key RAM
   --  for slot 4.  The blob's key-install leaf sets the slot MAC and keyvalid
   --  bit but skips the material copy in our bare-metal port, so we do it here.
   --  Slot s keeps its key material at 0x60034400 + s*40 + 8, as raw key
   --  little-endian words.  The pairwise transient key lives in slot 4.
   procedure Write_HW_Pairwise_Key (Key : Bytes) is
      use type Interfaces.Unsigned_32;
      Slot4_Material : constant Interfaces.Unsigned_32 := 16#600344A8#;

      --  The little-endian 32-bit word made of the 4 key bytes at offset Byte.
      function Little_Endian_Word (Byte : Natural) return Interfaces.Unsigned_32
      is
        (Interfaces.Unsigned_32 (Key (Key'First + Byte))
         or Shift_Left (Interfaces.Unsigned_32 (Key (Key'First + Byte + 1)), 8)
         or Shift_Left (Interfaces.Unsigned_32 (Key (Key'First + Byte + 2)), 16)
         or Shift_Left (Interfaces.Unsigned_32 (Key (Key'First + Byte + 3)), 24));
   begin
      for Word in 0 .. 3 loop
         declare
            Cell : Interfaces.Unsigned_32 with Import, Volatile,
              Address => System'To_Address
                (Slot4_Material + Interfaces.Unsigned_32 (Word) * 4);
         begin
            Cell := Little_Endian_Word (Word * 4);
         end;
      end loop;
   end Write_HW_Pairwise_Key;

   procedure On_Eapol_Txdone is
      Zero_Seq : Bytes (0 .. 5) := (others => 0);
      Zero_Key : Bytes (0 .. 15) := (others => 0);   --  dummy key for the blob
   begin
      Txdone_Count := Txdone_Count + 1;
      if Install_Pending then
         Install_Pending := False;
         In_HS := False;
         --  Install the pairwise key now that msg4 has left the radio.  This
         --  call sets the HW slot-4 MAC address and keyvalid bit, and populates
         --  the software key object (PN tracking and TX encap need it).  But in
         --  our stubbed bare-metal port the blob never lands the 16-byte key
         --  material in the HW crypto key RAM: hal_crypto_enable, at the tail of
         --  wDev_Insert_KeyEntry, appears to clear the slot again in our context.
         --  A two-board sniffer plus a full HW-key-RAM scan proved it: the SW
         --  keyobj held the key, HW slot-4 material stayed zero, so the radio
         --  encrypted unicast with the wrong bytes and the AP dropped every
         --  frame (no DHCP OFFER).  The canonical two-step blob install
         --  (KF_PTK_SET then KF_PTK_TX) was tried too and leaves it zero the same
         --  way, so do NOT retry that; write the material ourselves below.
         --  De-blob (keys never touch the blob): hand C_Set_Key a DUMMY zero
         --  key.  It still sets up the HW slot metadata (MAC, valid) and the
         --  blob's SW key object (PN / TX-encap bookkeeping), but the real TK is
         --  never passed into blob C -- we derive it in Ada (PTK) and write the
         --  real 16-byte material straight into the HW slot below.
         Ptk_Rc := C_Set_Key (WPA_ALG_CCMP, AA'Address, 0, 1,
                              Zero_Seq'Address, 6, Zero_Key'Address, 16, KF_PTK);
         --  Write the raw TK straight into the slot-4 key-material words.  Layout
         --  from blob RE (hal_crypto_set_key_entry): slot s key material lives at
         --  0x60034400 + s*40 + 8, as little-endian words; pairwise is slot 4.
         Write_HW_Pairwise_Key (TK);
         C_Auth_Done;   --  4-way done: authorise the port + post CONNECTED
         --  Record the controlled-port byte auth_done left, then force it open
         --  so the 802.3 data path can transmit (node[36] := 0).
         declare
            use type System.Address;
            N : constant System.Address := Node_Addr;
         begin
            if N /= System.Null_Address then
               declare
                  B : U8 with Import, Address => N + 36;
               begin
                  Port_Seen := Interfaces.Integer_32 (B);
               end;
            end if;
         end;
         Force_Port_Open;
         --  Enable per-frame CCMP encryption for our TX DATA frames.  The encap
         --  gate (ieee80211_encap_esfbuf @0x4037aa3a) encrypts iff
         --  vif[0xA4] bit4 AND node[12] bit0.  ppInstallKey programs the key but
         --  never sets these -- the full RUN transition does, which our stub
         --  skips -- so without them the DISCOVER goes out IN CLEAR and the AP
         --  (CCMP-only) silently drops it (no OFFER; the AP looks silent).
         declare
            use type System.Address;
            Vif : constant System.Address := Read_Ptr (G_Ic'Address + 16);
            Nn  : constant System.Address := Node_Addr;
         begin
            if Vif /= System.Null_Address then
               declare
                  W : Interfaces.Unsigned_32 with Import, Address => Vif + 16#A4#;
               begin
                  --  Reference STA has vif[0xA4]=0x2010: bit4 (privacy) AND
                  --  bit13 (0x2000) -- the latter is the RX-decrypt/data-path
                  --  enable the full RUN transition sets and our stub skipped.
                  W := W or 16#2010#;
               end;
            end if;
            if Nn /= System.Null_Address then
               declare
                  W : Interfaces.Unsigned_32 with Import, Address => Nn + 12;
               begin
                  W := W or 1;         --  per-node "encrypt frames to this peer"
               end;
            end if;
         end;
         --  Register the 802.3 RX callback HERE, in the wifi-task context: the
         --  reg_rxcb ioctl (cmd 26) only stores sta_rxcb synchronously when
         --  current_task_is_wifi_task() is true; called from the env task it is
         --  posted to ppTask and the store never lands, so sta_input drops every
         --  received data frame.  On_Eapol_Txdone runs on the wifi task.
         ESP32S3.WiFi.Start_Data_Path;
      end if;
   end On_Eapol_Txdone;

   procedure Publish_Rsn_Ie is
      --  Point the RSN appie at our writable {u16 len, IE} buffer, len = the IE
      --  length (22).  set_appie stores the pointer at g_ic+56 and writes 22
      --  into Appie_Buf(0..1).
      Rc : constant Interfaces.Integer_32 :=
        C_Set_Appie (WIFI_APPIE_RSN, Appie_Buf'Address, RSN_IE'Length, 1);
      pragma Unreferenced (Rc);
   begin
      null;
   end Publish_Rsn_Ie;

end ESP32S3.WiFi.Supplicant;
