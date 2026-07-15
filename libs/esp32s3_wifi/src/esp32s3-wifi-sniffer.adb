with ESP32S3.Log;
with System.Storage_Elements; use System.Storage_Elements;

package body ESP32S3.WiFi.Sniffer is

   use Interfaces;

   --  --- blob entry points (all defined in libnet80211/libpp) --------------
   function C_Set_Channel
     (Primary : Unsigned_8; Second : Unsigned_8) return Interfaces.Integer_32
     with Import, Convention => C, External_Name => "esp_wifi_set_channel";

   function C_Set_Promiscuous (Enable : Unsigned_8) return Interfaces.Integer_32
     with Import, Convention => C, External_Name => "esp_wifi_set_promiscuous";

   function C_Set_Promiscuous_Rx_Cb (Cb : System.Address)
      return Interfaces.Integer_32
     with Import, Convention => C,
          External_Name => "esp_wifi_set_promiscuous_rx_cb";

   --  wifi_promiscuous_pkt_t: wifi_pkt_rx_ctrl_t rx_ctrl (48 B) then payload[]
   --  (the raw 802.11 frame).  sig_len (frame length incl. FCS) is bits 0..11
   --  of the last rx_ctrl word (@44).  Probed on target: sizeof rx_ctrl = 48.
   Rx_Ctrl_Len : constant := 48;

   --  wifi_promiscuous_pkt_type_t
   PKT_MGMT : constant := 0;
   PKT_DATA : constant := 2;

   Cur_Chan : Unsigned_8 := 0;    --  channel we are currently parked on

   --  ----------------------------------------------------------------------
   --  Tiny logging helpers (2-digit hex, MAC).
   --  ----------------------------------------------------------------------
   Hex : constant array (0 .. 15) of Character := "0123456789abcdef";

   procedure Put_B (B : Unsigned_8) is
   begin
      ESP32S3.Log.Put (Hex (Natural (Shift_Right (B, 4))));
      ESP32S3.Log.Put (Hex (Natural (B and 16#0F#)));
   end Put_B;

   type Frame is array (Natural range <>) of Unsigned_8;

   procedure Put_Mac (F : Frame; At_Off : Natural) is
   begin
      for I in 0 .. 5 loop
         Put_B (F (At_Off + I));
         if I < 5 then
            ESP32S3.Log.Put (":");
         end if;
      end loop;
   end Put_Mac;

   --  Dump the tagged information elements of a management frame (from Off to
   --  the end): "id/len: bytes" per element, so an RSN IE (id 0x30) is visible.
   procedure Put_Ies (F : Frame; Off : Natural) is
      I : Natural := Off;
   begin
      while I + 1 < F'Last loop
         declare
            Id  : constant Unsigned_8 := F (I);
            Len : constant Natural    := Natural (F (I + 1));
         begin
            exit when I + 2 + Len > F'Last + 1;
            --  Only print the security-relevant IEs (RSN=48, vendor/WPA=221).
            if Id = 48 or else Id = 221 then
               ESP32S3.Log.Put ("      IE ");
               Put_B (Id); ESP32S3.Log.Put ("/"); ESP32S3.Log.Put (Len);
               ESP32S3.Log.Put (":");
               for J in 0 .. Len - 1 loop
                  ESP32S3.Log.Put (" ");
                  Put_B (F (I + 2 + J));
               end loop;
               ESP32S3.Log.New_Line;
            end if;
            I := I + 2 + Len;
         end;
      end loop;
   end Put_Ies;

   --  ----------------------------------------------------------------------
   --  The promiscuous RX callback (Convention C).  Called per received frame.
   --  ----------------------------------------------------------------------
   procedure Rx (Buf : System.Address; Pkt_Type : Unsigned_32)
     with Convention => C;

   Beacon_Dumped : Boolean := False;
   Watch_Set     : Boolean := False;              --  no BSSID baked in
   Watch_Bssid   : Frame (0 .. 5) := (others => 0);
   Sta_Set       : Boolean := False;              --  no station baked in
   Watch_Sta_Mac : Frame (0 .. 5) := (others => 0);
   Raw_Dumped    : Natural := 0;                   --  count of [raw] hex dumps

   procedure Rx (Buf : System.Address; Pkt_Type : Unsigned_32) is
      Len_Word : Unsigned_32 with Import, Address => Buf + (Rx_Ctrl_Len - 4);
      Sig_Len  : constant Natural := Natural (Len_Word and 16#FFF#);
   begin
      if Sig_Len < 24 or else Sig_Len > 1600 then
         return;    --  runt / absurd length -- ignore
      end if;

      declare
         F : Frame (0 .. Sig_Len - 1)
           with Import, Address => Buf + Rx_Ctrl_Len;
         FC      : constant Unsigned_16 :=
           Unsigned_16 (F (0)) or Shift_Left (Unsigned_16 (F (1)), 8);
         F_Type  : constant Unsigned_16 := Shift_Right (FC, 2) and 3;
         Stype : constant Unsigned_16 := Shift_Right (FC, 4) and 16#F#;
      begin
         if Pkt_Type = PKT_MGMT and then F_Type = 0 then
            case Stype is
               when 0 =>    --  assoc request (station -> AP): the IEs we send
                  ESP32S3.Log.Put ("[sniff] ASSOC-REQ src=");
                  Put_Mac (F, 10); ESP32S3.Log.Put (" bssid=");
                  Put_Mac (F, 16); ESP32S3.Log.New_Line;
                  Put_Ies (F, 28);          --  24 hdr + cap(2) + listen(2)
               when 1 =>    --  assoc response (AP -> station): status code
                  ESP32S3.Log.Put ("[sniff] ASSOC-RESP src=");
                  Put_Mac (F, 10); ESP32S3.Log.Put (" status=");
                  ESP32S3.Log.Put (Natural (Unsigned_16 (F (26)) or
                    Shift_Left (Unsigned_16 (F (27)), 8)));
                  ESP32S3.Log.New_Line;
               when 11 =>   --  authentication: status @ 24+4
                  ESP32S3.Log.Put ("[sniff] AUTH src=");
                  Put_Mac (F, 10); ESP32S3.Log.Put (" status=");
                  ESP32S3.Log.Put (Natural (Unsigned_16 (F (28)) or
                    Shift_Left (Unsigned_16 (F (29)), 8)));
                  ESP32S3.Log.New_Line;
               when 10 | 12 =>   --  disassoc / deauth: reason @ 24
                  ESP32S3.Log.Put ("[sniff] ");
                  ESP32S3.Log.Put ((if Stype = 12 then "DEAUTH" else "DISASSOC"));
                  ESP32S3.Log.Put (" src="); Put_Mac (F, 10);
                  ESP32S3.Log.Put (" dst="); Put_Mac (F, 4);
                  ESP32S3.Log.Put (" reason=");
                  ESP32S3.Log.Put (Natural (Unsigned_16 (F (24)) or
                    Shift_Left (Unsigned_16 (F (25)), 8)));
                  ESP32S3.Log.New_Line;
               when 8 =>    --  beacon: dump ONE watched AP's security IEs so we
                  --  can read its real AKM/PMF (set via Watch_Beacon; disabled
                  --  by default so no BSSID is baked into the source).
                  if Watch_Set
                    and then F (16 .. 21) = Watch_Bssid
                    and then not Beacon_Dumped
                  then
                     Beacon_Dumped := True;
                     ESP32S3.Log.Put ("[sniff] BEACON ");
                     Put_Mac (F, 16); ESP32S3.Log.Put (" IEs:");
                     ESP32S3.Log.New_Line;
                     Put_Ies (F, 36);   --  24 hdr + tsf(8)+intvl(2)+cap(2)
                  end if;
               when others =>
                  null;    --  other probes -- skip (too noisy)
            end case;

         elsif Pkt_Type = PKT_DATA and then F_Type = 2 then
            --  Look for EAPOL (ethertype 0x888E) after hdr + LLC/SNAP.
            --  Data hdr is 24 B (26 if QoS, subtype>=8); SNAP = 6 B; then
            --  the 2-byte ethertype.
            declare
               Hdr : constant Natural := (if Stype >= 8 then 26 else 24);
               ET  : constant Natural := Hdr + 6;
            begin
               if ET + 8 < F'Last
                 and then F (ET) = 16#88# and then F (ET + 1) = 16#8E#
               then
                  --  EAPOL payload at ET+2; key_info (u16) at EAPOL+5 = ET+7.
                  ESP32S3.Log.Put ("[sniff] EAPOL src=");
                  Put_Mac (F, 10); ESP32S3.Log.Put (" dst=");
                  Put_Mac (F, 4);
                  ESP32S3.Log.Put (" info=0x");
                  Put_B (F (ET + 7)); Put_B (F (ET + 8));
                  ESP32S3.Log.New_Line;
               end if;
            end;

            --  Data-frame census: any payload frame to/from the watched BSSID.
            --  The payload is encrypted (we read only the 802.11 header), but
            --  this shows whether the station's DHCP data frames reach the air
            --  and whether the AP answers.  Skip tiny (null/keepalive) frames.
            if F'Length > 60
              and then
                ((Watch_Set
                  and then (F (4 .. 9) = Watch_Bssid
                            or else F (10 .. 15) = Watch_Bssid))
                 or else
                 (Sta_Set
                  and then (F (4 .. 9) = Watch_Sta_Mac
                            or else F (10 .. 15) = Watch_Sta_Mac
                            or else F (16 .. 21) = Watch_Sta_Mac)))
            then
               declare
                  To_DS : constant Boolean := (FC and 16#0100#) /= 0;
               begin
                  ESP32S3.Log.Put ("[sniff] DATA ");
                  if To_DS then
                     ESP32S3.Log.Put ("sta->ap sta=");
                     Put_Mac (F, 10);
                     ESP32S3.Log.Put (" dst=");   --  addr3 = final destination
                     Put_Mac (F, 16);
                  else
                     ESP32S3.Log.Put ("ap->sta sta=");
                     Put_Mac (F, 4);
                  end if;
                  ESP32S3.Log.Put (" len=");
                  ESP32S3.Log.Put (Integer (F'Length));
                  ESP32S3.Log.New_Line;
                  --  For PROTECTED (encrypted) frames, dump the full raw 802.11
                  --  frame hex (hdr + CCMP hdr + ciphertext + FCS) so it can be
                  --  decrypted offline with the known PTK/GTK.  Capped to avoid
                  --  flooding the console.
                  if (F (1) and 16#40#) /= 0 and then Raw_Dumped < 24
                    and then Sta_Set and then F (10 .. 15) = Watch_Sta_Mac
                  then
                     Raw_Dumped := Raw_Dumped + 1;
                     ESP32S3.Log.Put ("[raw] ");
                     for I in F'Range loop
                        Put_B (F (I));
                     end loop;
                     ESP32S3.Log.New_Line;
                  end if;
               end;
            end if;
         end if;
      end;
   end Rx;

   --  ----------------------------------------------------------------------
   procedure Start (Channel : Interfaces.Unsigned_8; Result : out Status) is
      Rc : Interfaces.Integer_32;
   begin
      Rc := C_Set_Promiscuous (1);
      if Rc /= 0 then
         Result := Radio_Error;
         return;
      end if;
      Rc := C_Set_Promiscuous_Rx_Cb (Rx'Address);
      if Rc /= 0 then
         Result := Radio_Error;
         return;
      end if;
      Cur_Chan := Channel;
      Rc := C_Set_Channel (Channel, 0);   --  second chan = NONE
      Result := (if Rc = 0 then OK else Radio_Error);
   end Start;

   procedure Stop is
      Rc : Interfaces.Integer_32 := C_Set_Promiscuous (0);
      pragma Unreferenced (Rc);
   begin
      null;
   end Stop;

   procedure Watch_Beacon (BSSID : MAC_Address) is
   begin
      for I in 0 .. 5 loop
         Watch_Bssid (I) := BSSID (BSSID'First + I);
      end loop;
      Watch_Set := True;
      Beacon_Dumped := False;
   end Watch_Beacon;

   procedure Watch_Sta (Station : MAC_Address) is
   begin
      for I in 0 .. 5 loop
         Watch_Sta_Mac (I) := Station (Station'First + I);
      end loop;
      Sta_Set := True;
   end Watch_Sta;

   procedure Set_Channel (Channel : Interfaces.Unsigned_8) is
      Rc : Interfaces.Integer_32 := C_Set_Channel (Channel, 0);
      pragma Unreferenced (Rc);
   begin
      Cur_Chan := Channel;
   end Set_Channel;

end ESP32S3.WiFi.Sniffer;
