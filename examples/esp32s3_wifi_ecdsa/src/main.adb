--  ESP32-S3 Wi-Fi ECDSA: authenticate an ALL-ECDSA certificate chain.
--
--  What it demonstrates: the pure-Ada P-256 and P-384 implementations
--  (libs/tls/p256.adb, p384.adb) verifying real signatures from a real server,
--  on the board, rather than against baked-in vectors.
--
--  Why it exists separately from esp32s3_wifi_tls: that example proves the
--  whole HTTPS pipeline, but the chain it walks (api.open-meteo.com up to ISRG
--  Root X1) is RSA end to end, so it never calls P256.Verify or P384.Verify.
--  The only other on-board exercise of P-384, esp32s3_dns_secure, needs a W5500
--  on SPI2.  This one needs nothing but the radio.
--
--  The host is letsencrypt.org, whose chain is ECDSA all the way up to the SAME
--  pinned ISRG Root X1 this repo already ships, so no new trust anchor is
--  needed.  At the time of writing it is:
--
--    [1] CN=letsencrypt.org        key EC P-256   <- verified with [2]'s P-384
--    [2] CN=YE2 (Let's Encrypt)    key EC P-384   <- verified with [3]'s P-384
--    [3] CN=Root YE (ISRG)         key EC P-384   <- verified with [4]'s P-384
--    [4] CN=ISRG Root X2           key EC P-384   <- verified with the anchor (RSA)
--
--  so validating it runs P384.Verify three times, and the handshake's
--  CertificateVerify -- signed with the leaf's P-256 key -- runs P256.Verify.
--  The example REPORTS that breakdown rather than asserting it, and fails if
--  the chain stops exercising ECDSA (a CA can re-issue under a different key at
--  any time; if that happens the run says so instead of quietly passing).
--
--  Build & run:  ./build.sh + ./flash.sh /dev/ttyACM0.  First copy
--  src/wifi_credentials.ads.template to src/wifi_credentials.ads and fill in
--  your network (that file is git-ignored).
--
--  Output: assoc/DHCP, DNS answer, NTP UTC, "TLS 1.3 up" with the cipher, the
--  per-certificate key breakdown, which primitive verified which link, and a
--  final PASS/FAIL.
--
--  Hardware: none beyond the board; console on UART0.  Needs a live internet
--  path to the host.
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;
with Wifi_Credentials;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.WiFi;  use ESP32S3.WiFi;
with ESP32S3.WiFi.IP;
with ESP32S3.WiFi.DHCP;
with ESP32S3.WiFi.Net_Device;
with ESP32S3.UART;
with ESP32S3.UART.Text;
with ESP32S3.Serial;
with ESP32S3.RNG;
with GNAT.Sockets;  use GNAT.Sockets;
with TLS_Client;
with X509;
with Chain_Verify;
with Chain_Buffers;
with Trust_Anchors;
with DNS_Client;
with NTP_Client;
with Net_Devices;
with Cal_Store_Demo;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   Con          : aliased ESP32S3.UART.Session;
   St           : Status;
   Target_BSSID : constant MAC_Address := MAC_Address (Wifi_Credentials.BSSID);

   --  Chosen for its certificate chain, not its content: ECDSA to the root,
   --  under an anchor this repo already pins.  See the header.
   Host        : constant String := "letsencrypt.org";
   NTP_Server  : constant Inet_Addr_Type := Inet_Addr ("216.239.35.0");  --  time.google.com
   Server_Port : constant Port_Type := 443;

   Lookup_Timeout : constant Duration := 5.0;
   Max_Handshake_Attempts : constant := 6;
   Handshake_Retry_Delay  : constant Time_Span := Milliseconds (800);
   Park : constant Time_Span := Seconds (3600);

   Now : X509.Time_64;

   --  De-blob confirmation: the Ada replacements for the blob's HW key-slot
   --  programmer (hal_crypto_set_key_entry) and slot-clear (hal_crypto_clr_key_
   --  entry) are wired via linker --wrap in the wifi library.  These counters
   --  (exported from the supplicant) prove OUR Ada code ran -- so the blob's
   --  key-slot crypto never executed.  A successful HTTPS fetch above already
   --  proves the Ada key install is correct (unicast decrypts).
   Wrap_Set_Count : Interfaces.Unsigned_32
     with Import, Convention => C, External_Name => "ada_wrap_set_key_count";
   Wrap_Clr_Count : Interfaces.Unsigned_32
     with Import, Convention => C, External_Name => "ada_wrap_clr_key_count";
   Wrap_En_Count : Interfaces.Unsigned_32
     with Import, Convention => C, External_Name => "ada_wrap_enable_count";
   procedure Show_Deblob_Result is
   begin
      Put_Line ("");
      Put_Line ("==== DE-BLOB: Ada cipher-engine programming ran (blob's did not) ====");
      Put ("  Wrap_Set_Key    (was hal_crypto_set_key_entry) fired = ");
      Put_Unsigned (Wrap_Set_Count); New_Line;
      Put ("  Wrap_Clr_Key    (was hal_crypto_clr_key_entry) fired = ");
      Put_Unsigned (Wrap_Clr_Count); New_Line;
      Put ("  Wrap_Crypto_Enable (was hal_crypto_enable)     fired = ");
      Put_Unsigned (Wrap_En_Count); New_Line;
      Put_Line ("====================================================================");
   end Show_Deblob_Result;

   CRLF : constant String := (1 => ASCII.CR, 2 => ASCII.LF);
   --  The body is irrelevant here -- the point is that the peer authenticated.
   --  Ask for the smallest useful thing and report only the status line.
   Req  : constant String :=
     "GET / HTTP/1.0" & CRLF
     & "Host: " & Host & CRLF & "Connection: close" & CRLF & CRLF;

   DNS_Srv   : Inet_Addr_Type;
   Server_IP : Inet_Addr_Type;
   Sock      : Socket_Type;
   Session   : TLS_Client.Session;
   Handshake_OK : Boolean := False;

   --  What the run actually exercised, for the verdict at the end.
   Chain_OK   : Boolean := False;
   P256_Links : Natural := 0;             --  chain links verified with a P-256 key
   P384_Links : Natural := 0;             --  ... and with a P-384 key
   Leaf_Key   : X509.Key_Algorithm := X509.Key_Other;
   Http_OK    : Boolean := False;

begin
   ESP32S3.UART.Acquire (Con, ESP32S3.UART.UART0);
   ESP32S3.Serial.Set_Output (ESP32S3.UART.Text.As_Device (Con));
   ESP32S3.RNG.Enable_Entropy_Source;            --  keys need real entropy

   --  Persist the PHY RF calibration across boots: a stored baseline drives a
   --  fast PARTIAL cal instead of a FULL one.  Register before Initialize.
   ESP32S3.WiFi.Set_Cal_Store
     (Cal_Store_Demo.Load'Access, Cal_Store_Demo.Store'Access);

   Put_Line ("");
   Put_Line ("=== ESP32-S3 Wi-Fi ECDSA (pure-Ada P-256 / P-384 chain auth) ===");

   Put ("Initialize ... ");
   Initialize (St);
   if St /= OK then
      Put_Line ("FAILED");
      loop
         delay until Clock + Park;
      end loop;
   end if;
   Put_Line ("OK");

   Put_Line ("Connecting to '" & Wifi_Credentials.SSID & "' ...");
   loop
      Connect (Wifi_Credentials.SSID, Wifi_Credentials.Pass,
               BSSID => Target_BSSID, Result => St);
      for I in 1 .. 100 loop
         exit when Connected and then ESP32S3.WiFi.Handshake_Txdone_Count > 0;
         delay until Clock + Milliseconds (100);
      end loop;
      exit when Connected and then ESP32S3.WiFi.Handshake_Txdone_Count > 0;
      Put_Line ("  retry (handshake incomplete) ...");
   end loop;
   Put ("  associated (channel ");
   Put (ESP32S3.WiFi.Current_Channel); Put_Line (")");

   ESP32S3.WiFi.IP.Start;
   Put ("DHCP ... ");
   declare
      Lease : ESP32S3.WiFi.DHCP.Lease;
      procedure Put_IP (A : ESP32S3.WiFi.IP.IPv4) is
      begin
         for I in A'Range loop
            Put (Integer (A (I)));
            if I < A'Last then Put ("."); end if;
         end loop;
      end Put_IP;
   begin
      if not ESP32S3.WiFi.DHCP.Acquire (0, Lease, Tries => 40) then
         Put_Line ("FAILED");
         loop
            delay until Clock + Park;
         end loop;
      end if;
      Put ("IP="); Put_IP (Lease.Addr); Put (" dns="); Put_IP (Lease.DNS);
      New_Line;
      ESP32S3.WiFi.Net_Device.Register_Default;
      DNS_Srv := Inet_Addr (Net_Devices.IPv4_Address (Lease.DNS));
   end;

   --  Resolve the API host (retry: the first unicast warms the gateway ARP).
   Put ("resolving " & Host & " ... ");
   declare
      Resolved : Boolean := False;
   begin
      for Attempt in 1 .. 5 loop
         Resolved := DNS_Client.Resolve (DNS_Srv, Host, Server_IP,
                                         Timeout => Lookup_Timeout);
         exit when Resolved;
      end loop;
      if not Resolved then
         Put_Line ("FAILED");
         loop
            delay until Clock + Park;
         end loop;
      end if;
   end;
   Put_Line (Image (Server_IP));

   --  Wall-clock UTC from NTP: certificate validity needs trusted time.
   declare
      Unix : Interfaces.Integer_64;
      Y, M, D, H, Mi, S : Integer;
   begin
      Put ("NTP ... ");
      if not NTP_Client.Query (NTP_Server, Unix, Timeout => Lookup_Timeout) then
         Put_Line ("FAILED (cannot verify cert validity), aborting");
         loop
            delay until Clock + Park;
         end loop;
      end if;
      NTP_Client.To_UTC (Unix, Y, M, D, H, Mi, S);
      Now := X509.Pack_Time (Y, M, D, H, Mi, S);
      Put ("UTC "); Put (Y); Put ("-"); Put (M); Put ("-"); Put (D);
      Put (" "); Put (H); Put (":"); Put (Mi); New_Line;
   end;

   --  TLS 1.3 handshake, retried (the path can be intermittently flaky).
   for Attempt in 1 .. Max_Handshake_Attempts loop
      begin
         Create_Socket (Sock, Family_Inet, Socket_Stream);
         Set_Socket_Option (Sock, Socket_Level, (Receive_Timeout, Timeout => 15.0));
         Connect_Socket (Sock, (Family_Inet, Server_IP, Server_Port));
         TLS_Client.Hello (Session, Sock, Host, Handshake_OK);
      exception
         when others =>
            Handshake_OK := False;
      end;
      exit when Handshake_OK;
      begin
         Close_Socket (Sock);
      exception
         when others => null;
      end;
      Put_Line ("TLS handshake attempt" & Integer'Image (Attempt) & " failed; retry");
      delay until Clock + Handshake_Retry_Delay;
   end loop;

   if not Handshake_OK then
      Put_Line ("TLS handshake FAILED");
      loop
         delay until Clock + Park;
      end loop;
   end if;

   Put ("TLS 1.3 up: cipher 0x");
   Put_Hex (Interfaces.Unsigned_32 (TLS_Client.Cipher_Suite (Session)), 4);
   New_Line;
   --  Signed with the LEAF's key.  With this host that is P-256, so this line
   --  is P256.Verify's verdict; the per-cert table below names the key used.
   Put_Line ("CertificateVerify: "
     & (if TLS_Client.Server_Cert_Verify_OK (Session) then "OK" else "FAIL"));
   Put_Line ("server Finished: "
     & (if TLS_Client.Server_Finished_OK (Session) then "OK" else "FAIL"));

   --  Authenticate the chain to the pinned ISRG Root X1 before sending data.
   declare
      use Chain_Verify;
      Anchors : constant Cert_List := (1 => (Data => Trust_Anchors.Root_DER'Access));
      Verdict : Result;
   begin
      Chain_Buffers.Reset;
      for I in 1 .. TLS_Client.Server_Cert_Count (Session) loop
         Chain_Buffers.Add (TLS_Client.Server_Chain_Cert (Session, I));
      end loop;
      Verdict := Validate (Chain_Buffers.Chain, Anchors, Host, Now);
      Put_Line ("chain validation to ISRG Root X1:"
        & Natural'Image (TLS_Client.Server_Cert_Count (Session))
        & " certs -> " & Result'Image (Verdict));

      if Verdict /= Valid
        or else not TLS_Client.Server_Cert_Verify_OK (Session)
        or else not TLS_Client.Server_Finished_OK (Session)
      then
         Put_Line ("WARNING: peer NOT authenticated -- aborting before sending");
         Close_Socket (Sock);
         loop
            delay until Clock + Park;
         end loop;
      end if;
      Chain_OK := True;
   end;

   --  Which primitive actually did the work.  A certificate is verified with
   --  its ISSUER's key, so for cert I the operative column is cert I+1's key
   --  algorithm; the last cert is verified against the pinned anchor.
   declare
      use type X509.Key_Algorithm;
      --  TLS_Client.Max_Chain is in that package's private part, so size the
      --  table here and clamp; the chain validator has already accepted N.
      Max_Certs : constant := 8;
      N : constant Natural :=
        Natural'Min (TLS_Client.Server_Cert_Count (Session), Max_Certs);
      Certs : array (1 .. Max_Certs) of X509.Certificate;

      function Key_Image (K : X509.Key_Algorithm) return String
      is (case K is
             when X509.Key_RSA     => "RSA",
             when X509.Key_EC_P256 => "EC P-256",
             when X509.Key_EC_P384 => "EC P-384",
             when X509.Key_Ed25519 => "Ed25519",
             when X509.Key_Other   => "other");

      procedure Tally (K : X509.Key_Algorithm) is
      begin
         case K is
            when X509.Key_EC_P256 => P256_Links := P256_Links + 1;
            when X509.Key_EC_P384 => P384_Links := P384_Links + 1;
            when others           => null;
         end case;
      end Tally;
   begin
      for I in 1 .. N loop
         X509.Parse (TLS_Client.Server_Chain_Cert (Session, I), Certs (I));
      end loop;

      Put_Line ("chain, leaf first:");
      for I in 1 .. N loop
         Put ("  ["); Put (I); Put ("] key=" & Key_Image (Certs (I).Key_Kind));
         if I < N then
            Put (" -- verified with ["); Put (I + 1);
            Put ("] key=" & Key_Image (Certs (I + 1).Key_Kind));
            Tally (Certs (I + 1).Key_Kind);
         else
            Put (" -- verified with the pinned ISRG Root X1 (RSA)");
         end if;
         New_Line;
      end loop;

      --  The handshake signature is made with the leaf's own key.
      if N >= 1 then
         Leaf_Key := Certs (1).Key_Kind;
      end if;

      Put_Line ("primitives exercised on this run:");
      Put ("  P256.Verify : CertificateVerify=");
      Put ((if Leaf_Key = X509.Key_EC_P256 then "yes" else "no"));
      Put (", chain links="); Put (P256_Links); New_Line;
      Put ("  P384.Verify : chain links="); Put (P384_Links); New_Line;
   end;

   --  Encrypted GET over the authenticated session, then the status line.
   declare
      Recv_Chunk : constant := 1024;
      Resp_Cap   : constant := 2048;
      Req_Bytes  : TLS_Client.Byte_Array (0 .. Req'Length - 1);
      Buf        : TLS_Client.Byte_Array (0 .. Recv_Chunk - 1);
      Last       : Natural;
      Recv_Ok    : Boolean;
      Resp       : String (1 .. Resp_Cap);
      Resp_Len   : Natural := 0;
   begin
      for I in 0 .. Req'Length - 1 loop
         Req_Bytes (I) := Interfaces.Unsigned_8 (Character'Pos (Req (Req'First + I)));
      end loop;
      TLS_Client.Send (Session, Sock, Req_Bytes);
      --  Send reports a failed or truncated write on the session, not
      --  through a status or an exception -- check it before reading a
      --  reply to a request that may never have left the board.
      if TLS_Client.IO_Failed (Session) then
         Put_Line ("TLS: request send failed (link down)");
         return;
      end if;

      loop
         TLS_Client.Recv (Session, Sock, Buf, Last, Recv_Ok);
         exit when not Recv_Ok;
         for I in Buf'First .. Last loop
            if Resp_Len < Resp'Last then
               Resp_Len := Resp_Len + 1;
               Resp (Resp_Len) := Character'Val (Natural (Buf (I)));
            end if;
         end loop;
      end loop;

      --  Only the status line matters: a 2xx/3xx proves the encrypted request
      --  went out and the reply decrypted under keys agreed with a peer we
      --  authenticated with ECDSA.
      declare
         Eol : Natural := Resp_Len;
      begin
         for I in 1 .. Resp_Len loop
            if Resp (I) = ASCII.CR or else Resp (I) = ASCII.LF then
               Eol := I - 1;
               exit;
            end if;
         end loop;
         if Resp_Len = 0 then
            Put_Line ("no response body");
         else
            Http_OK := Eol >= 12 and then Resp (1 .. 7) = "HTTP/1.";
            Put_Line ("response: " & Resp (1 .. Eol));
         end if;
      end;
   end;

   Close_Socket (Sock);

   --  A pass needs the peer authenticated AND ECDSA to have done it.  If the CA
   --  re-issues under RSA the run reports FAILURE rather than passing on a path
   --  that no longer touches p256.adb / p384.adb.
   declare
      use type X509.Key_Algorithm;
      Used_ECDSA : constant Boolean :=
        P384_Links > 0 or else P256_Links > 0
        or else Leaf_Key = X509.Key_EC_P256 or else Leaf_Key = X509.Key_EC_P384;
   begin
      Put_Line ("");
      if Chain_OK and then Http_OK and then Used_ECDSA then
         Put_Line ("[ecdsa] result: ALL PASS"
           & " (P-384 links=" & Natural'Image (P384_Links)
           & ", P-256 links=" & Natural'Image (P256_Links) & " )");
      elsif Chain_OK and then Http_OK then
         Put_Line ("[ecdsa] result: FAILURE -- chain authenticated but with no"
           & " ECDSA link; this host no longer exercises P-256/P-384");
      else
         Put_Line ("[ecdsa] result: FAILURE");
      end if;
   end;

   Show_Deblob_Result;
   loop
      delay until Clock + Park;
   end loop;
end Main;
