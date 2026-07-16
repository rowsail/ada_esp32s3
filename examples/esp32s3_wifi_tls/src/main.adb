--  ESP32-S3 Wi-Fi HTTPS: pure-Ada TLS 1.3 over the software TCP stack.
--
--  What it demonstrates: real-world HTTPS end to end on the radio, with no
--  offloaded TCP/IP and no C TLS library.  The pipeline is:
--
--    Wi-Fi assoc + DHCP -> DNS -> NTP (wall clock for cert validity) ->
--    TCP connect :443 (ESP32S3.WiFi.IP TCP) -> TLS 1.3 handshake (TLS_Client:
--    X25519 ECDHE, AES-128-GCM, RSA-PSS CertificateVerify, Finished) ->
--    validate the cert chain to the pinned ISRG Root X1 -> encrypted HTTP GET ->
--    decrypt + scrape the JSON forecast from api.open-meteo.com.
--
--  All crypto is Ada (SPARKNaCl + the ESP32-S3 accelerators).
--
--  Build & run:  ./build.sh + ./flash.sh /dev/ttyUSB0.  First copy
--  src/wifi_credentials.ads.template to src/wifi_credentials.ads and fill in
--  your network (that file is git-ignored).
--
--  Output: assoc/DHCP, DNS answer, NTP UTC, "TLS 1.3 up" with the cipher,
--  CertificateVerify / Finished / chain validation, then the forecast.
--
--  Hardware: none beyond the board; console on UART0.  Needs a live internet
--  path to the API host.
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

   Host        : constant String := "api.open-meteo.com";
   NTP_Server  : constant Inet_Addr_Type := Inet_Addr ("216.239.35.0");  --  time.google.com
   Server_Port : constant Port_Type := 443;
   Latitude    : constant String := "52.52";     --  Berlin, DE
   Longitude   : constant String := "13.41";

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
   Req  : constant String :=
     "GET /v1/forecast?latitude=" & Latitude & "&longitude=" & Longitude
     & "&current=temperature_2m,wind_speed_10m HTTP/1.0" & CRLF
     & "Host: " & Host & CRLF & "Connection: close" & CRLF & CRLF;

   DNS_Srv   : Inet_Addr_Type;
   Server_IP : Inet_Addr_Type;
   Sock      : Socket_Type;
   Session   : TLS_Client.Session;
   Handshake_OK : Boolean := False;

   --  Minimal JSON scrape: the numeric value following the literal Key.
   function Field (Text : String; Key : String) return String is
      Scan : Natural := Text'First;
   begin
      while Scan <= Text'Last - Key'Length + 1 loop
         if Text (Scan .. Scan + Key'Length - 1) = Key then
            declare
               Value_Start : Natural := Scan + Key'Length;
            begin
               while Value_Start <= Text'Last
                 and then (Text (Value_Start) = ' ' or else Text (Value_Start) = ':')
               loop
                  Value_Start := Value_Start + 1;
               end loop;
               if Value_Start <= Text'Last
                 and then (Text (Value_Start) in '0' .. '9'
                           or else Text (Value_Start) = '-')
               then
                  declare
                     Value_End : Natural := Value_Start;
                  begin
                     while Value_End <= Text'Last
                       and then (Text (Value_End) in '0' .. '9'
                                 or else Text (Value_End) = '.'
                                 or else Text (Value_End) = '-')
                     loop
                        Value_End := Value_End + 1;
                     end loop;
                     return Text (Value_Start .. Value_End - 1);
                  end;
               end if;
               Scan := Scan + Key'Length;
            end;
         else
            Scan := Scan + 1;
         end if;
      end loop;
      return "";
   end Field;
begin
   ESP32S3.UART.Acquire (Con, ESP32S3.UART.UART0);
   ESP32S3.Serial.Set_Output (ESP32S3.UART.Text.As_Device (Con));
   ESP32S3.RNG.Enable_Entropy_Source;            --  keys need real entropy

   --  Persist the PHY RF calibration across boots: a stored baseline drives a
   --  fast PARTIAL cal instead of a FULL one.  Register before Initialize.
   ESP32S3.WiFi.Set_Cal_Store
     (Cal_Store_Demo.Load'Access, Cal_Store_Demo.Store'Access);

   Put_Line ("");
   Put_Line ("=== ESP32-S3 Wi-Fi HTTPS (pure-Ada TLS 1.3 over software TCP) ===");

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
   Put_Line ("CertificateVerify (RSA-PSS): "
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
   end;

   --  Encrypted GET, decrypt the response, scrape the forecast.
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

      declare
         Temp : constant String := Field (Resp (1 .. Resp_Len), """temperature_2m""");
         Wind : constant String := Field (Resp (1 .. Resp_Len), """wind_speed_10m""");
      begin
         if Temp = "" then
            Put_Line ("could not parse forecast (response below)");
            Put_Line (Resp (1 .. Resp_Len));
         else
            Put_Line ("forecast for " & Latitude & ", " & Longitude & " (HTTPS):");
            Put_Line ("  temperature : " & Temp & " C");
            Put_Line ("  wind speed  : " & Wind & " km/h");
         end if;
      end;
   end;

   Close_Socket (Sock);
   Show_Deblob_Result;
   loop
      delay until Clock + Park;
   end loop;
end Main;
