--  What it demonstrates
--  --------------------
--  Real-world HTTPS over pure-Ada TLS 1.3: fetch a live weather forecast from
--  api.open-meteo.com, end to end on the bare-metal ESP32-S3 with no external C
--  TLS library.  The full pipeline runs in one example:
--
--    DNS (DNS_Client) -> TCP connect :443 -> TLS 1.3 handshake (TLS_Client:
--    X25519 ECDHE, AES-128-GCM, HKDF, RSA-PSS CertificateVerify, Finished) ->
--    validate the server's certificate chain to a pinned root (ISRG Root X1,
--    Let's Encrypt) -> encrypted HTTP GET -> decrypt and parse the JSON forecast.
--
--  All crypto is Ada (SPARKNaCl) + the ESP32-S3 accelerators -- no C TLS stack.
--
--  Build & run
--  -----------
--    ./x run esp32s3_tls_weather
--  Needs the embedded profile; build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  How to read the output
--  ----------------------
--  Every line is prefixed "[wx]" (or "[w5500]" from the NIC bring-up).  The run
--  walks the pipeline aloud: link up -> DNS answer -> NTP time -> "TLS 1.3 up"
--  with the negotiated cipher -> CertificateVerify / Finished OK -> chain
--  validation to ISRG Root X1 -> and finally the fetched data:
--      [wx]   temperature : <value> C
--      [wx]   wind speed  : <value> km/h
--  Any earlier failure prints a "[wx] ... failed/aborting" line and parks the
--  board (it does not reset).
--
--  Hardware
--  --------
--  Networking over a W5500 Ethernet module on SPI2 (pins wired in w5500_dev.adb),
--  plus a live internet path to the API host.  NTP is queried first because the
--  board has no RTC: certificate validity (not-before / not-after) cannot be
--  checked without trusted wall-clock time, so the run aborts if NTP fails.
--
--  Edit Latitude / Longitude below for another place.
with Ada.Real_Time;  use Ada.Real_Time;
with Interfaces;
with GNAT.Sockets;   use GNAT.Sockets;
with TLS_Client;
with X509;
with Chain_Verify;
with Chain_Buffers;
with Trust_Anchors;
with DNS_Client;
with NTP_Client;
with W5500_Dev;
with ESP32S3.RNG;
with ESP32S3.Log;    use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   Host        : constant String         := "api.open-meteo.com";
   DNS_Server  : constant Inet_Addr_Type := Inet_Addr ("8.8.8.8");      --  Google public DNS
   NTP_Server  : constant Inet_Addr_Type := Inet_Addr ("216.239.35.0"); --  time.google.com
   Server_Port : constant Port_Type      := 443;                        --  HTTPS
   Latitude    : constant String         := "52.52";    --  Berlin, DE
   Longitude   : constant String         := "13.41";

   --  How long DNS / NTP lookups wait for a UDP reply before giving up (seconds).
   Lookup_Timeout : constant Duration := 5.0;

   --  The TLS handshake is retried: the path to this host is intermittently
   --  flaky, so give it several attempts spaced by a short back-off.
   Max_Handshake_Attempts : constant := 8;
   Handshake_Retry_Delay  : constant Time_Span := Milliseconds (800);

   --  When the run can go no further it parks here forever rather than resetting,
   --  so the last console line stays on screen for inspection.
   Park_Forever : constant Time_Span := Seconds (3600);

   Now : X509.Time_64;       --  current UTC (from NTP), for cert-validity checks

   CRLF : constant String := (1 => ASCII.CR, 2 => ASCII.LF);
   Req  : constant String :=
     "GET /v1/forecast?latitude=" & Latitude & "&longitude=" & Longitude
       & "&current=temperature_2m,wind_speed_10m HTTP/1.0" & CRLF
       & "Host: " & Host & CRLF & "Connection: close" & CRLF & CRLF;

   Server_IP : Inet_Addr_Type;
   Sock      : Socket_Type;
   Session   : TLS_Client.Session;
   Ok        : Boolean := False;

   --  Minimal JSON scrape (no parser): return the NUMERIC value following the
   --  literal Key within Text, e.g. Field (..., """temperature_2m""") -> "14.3".
   --  The same key also appears in the "current_units" object with a STRING value
   --  (e.g. "temperature_2m":"C"), so skip any occurrence whose value is not a
   --  number and keep searching -- the real "current" object comes later.
   function Field (Text : String; Key : String) return String is
      Scan : Natural := Text'First;     --  where the next Key match is sought
   begin
      while Scan <= Text'Last - Key'Length + 1 loop
         if Text (Scan .. Scan + Key'Length - 1) = Key then
            declare
               Value_Start : Natural := Scan + Key'Length;
            begin
               --  Step over the ':' and any spaces between key and value.
               while Value_Start <= Text'Last
                 and then (Text (Value_Start) = ' ' or else Text (Value_Start) = ':')
               loop
                  Value_Start := Value_Start + 1;
               end loop;
               --  A digit or leading '-' means this is the numeric occurrence.
               if Value_Start <= Text'Last
                 and then (Text (Value_Start) in '0' .. '9'
                           or else Text (Value_Start) = '-')
               then
                  declare
                     Value_End : Natural := Value_Start;   --  one past the number
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
               Scan := Scan + Key'Length;    --  string value: keep searching
            end;
         else
            Scan := Scan + 1;
         end if;
      end loop;
      return "";
   end Field;

begin
   --  Let the console settle before the first line so no banner text is lost.
   delay until Clock + Milliseconds (200);
   ESP32S3.RNG.Enable_Entropy_Source;            --  keys need real entropy (CSPRNG)
   Put_Line ("[wx] pure-Ada HTTPS weather (TLS 1.3 over the W5500)");
   if not W5500_Dev.Bring_Up then
      loop
         delay until Clock + Park_Forever;
      end loop;
   end if;

   --  Resolve the API host by name (portable DNS_Client over GNAT.Sockets).
   Put_Line ("[wx] resolving " & Host & " ...");
   if not DNS_Client.Resolve (DNS_Server, Host, Server_IP, Timeout => Lookup_Timeout) then
      Put_Line ("[wx] DNS resolution failed");
      loop
         delay until Clock + Park_Forever;
      end loop;
   end if;
   Put_Line ("[wx] " & Host & " = " & Image (Server_IP));

   --  Current UTC time from NTP -- the board has no RTC, and certificate validity
   --  cannot be checked without trusted time, so abort if NTP does not answer.
   declare
      Unix                                          : Interfaces.Integer_64;
      Year, Month, Day, Hour, Minute, Second        : Integer;
      --  Print a date/time field zero-padded to two digits (e.g. 7 -> "07").
      procedure Put_Padded (N : Integer) is
      begin
         if N < 10 then
            Put ("0");
         end if;
         Put (N);
      end Put_Padded;
   begin
      Put_Line ("[wx] getting time from NTP ...");
      if not NTP_Client.Query (NTP_Server, Unix, Timeout => Lookup_Timeout) then
         Put_Line ("[wx] NTP failed -- cannot verify certificate validity, aborting");
         loop
            delay until Clock + Park_Forever;
         end loop;
      end if;
      NTP_Client.To_UTC (Unix, Year, Month, Day, Hour, Minute, Second);
      Now := X509.Pack_Time (Year, Month, Day, Hour, Minute, Second);
      --  Print "[wx] NTP UTC = YYYY-MM-DD HH:MM:SS".
      Put ("[wx] NTP UTC = ");
      Put (Year);
      Put ("-");
      Put_Padded (Month);
      Put ("-");
      Put_Padded (Day);
      Put (" ");
      Put_Padded (Hour);
      Put (":");
      Put_Padded (Minute);
      Put (":");
      Put_Padded (Second);
      New_Line;
   end;

   --  TLS 1.3 handshake, retried (the path to this host is intermittently flaky).
   for Attempt in 1 .. Max_Handshake_Attempts loop
      begin
         Create_Socket  (Sock, Family_Inet, Socket_Stream);
         Connect_Socket (Sock, (Family_Inet, Server_IP, Server_Port));
         TLS_Client.Hello (Session, Sock, Host, Ok);
      exception
         when others => Ok := False;
      end;
      exit when Ok;
      --  Drop the dead socket before the next attempt; ignore any close error.
      begin
         Close_Socket (Sock);
      exception
         when others => null;
      end;
      Put_Line ("[wx] handshake attempt" & Integer'Image (Attempt) & " failed; retry");
      delay until Clock + Handshake_Retry_Delay;
   end loop;

   if not Ok then
      Put_Line ("[wx] TLS handshake failed");
      loop
         delay until Clock + Park_Forever;
      end loop;
   end if;

   Put ("[wx] TLS 1.3 up: cipher 0x");
   Put_Hex (Interfaces.Unsigned_32 (TLS_Client.Cipher_Suite (Session)), 4);
   New_Line;
   Put_Line ("[wx] CertificateVerify (RSA-PSS): "
             & (if TLS_Client.Server_Cert_Verify_OK (Session) then "OK" else "FAIL"));
   Put_Line ("[wx] server Finished: "
             & (if TLS_Client.Server_Finished_OK (Session) then "OK" else "FAIL"));

   --  Authenticate the chain: validate the server's leaf+intermediate up to the
   --  pinned ISRG Root X1, checking each link's signature and the leaf hostname.
   declare
      use Chain_Verify;
      Anchors : constant Cert_List :=
        (1 => (Data => Trust_Anchors.Root_DER'Access));
      Verdict : Result;
   begin
      Chain_Buffers.Reset;
      for I in 1 .. TLS_Client.Server_Cert_Count (Session) loop
         Chain_Buffers.Add (TLS_Client.Server_Chain_Cert (Session, I));
      end loop;
      Verdict := Validate (Chain_Buffers.Chain, Anchors, Host, Now);
      Put_Line ("[wx] chain validation to ISRG Root X1:" & Natural'Image
                (TLS_Client.Server_Cert_Count (Session)) & " certs -> " & Result'Image (Verdict));

      --  Authenticate the peer before sending ANY application data.  Three
      --  independent conditions must ALL hold:
      --    * the chain validates to the pinned root (Verdict = Valid) -- the cert
      --      is a trusted, in-date cert for this host;
      --    * CertificateVerify passed (Server_Cert_Verify_OK) -- the server proved
      --      possession of that cert's PRIVATE key.  This is essential: the channel
      --      opens on Finished alone, so a MITM replaying the real (public) cert
      --      chain without the key reaches this point with Verdict = Valid but
      --      CertificateVerify FAILED -- sending on the chain check alone would
      --      hand the request to the impersonator;
      --    * the server Finished verified (Server_Finished_OK) -- transcript
      --      integrity.
      if Verdict /= Valid
        or else not TLS_Client.Server_Cert_Verify_OK (Session)
        or else not TLS_Client.Server_Finished_OK (Session)
      then
         Put_Line ("[wx] WARNING: peer NOT authenticated"
                   & " (chain/CertificateVerify/Finished) -- aborting before sending data");
         Close_Socket (Sock);
         loop
            delay until Clock + Park_Forever;
         end loop;
      end if;
   end;

   --  Encrypted application data: send the GET, decrypt the (possibly multi-record)
   --  response, then scrape the current temperature and wind speed from the JSON.
   declare
      --  One TLS record's worth of plaintext per Recv call (records cap at 16 KiB,
      --  but the forecast arrives in small chunks, so 1 KiB at a time is plenty).
      Recv_Chunk : constant := 1024;
      --  Whole-response accumulator: the Open-Meteo "current" reply is a few
      --  hundred bytes; 2 KiB holds it with headroom and bounds the JSON scrape.
      Resp_Cap   : constant := 2048;

      Req_Bytes : TLS_Client.Byte_Array (0 .. Req'Length - 1);
      Buf       : TLS_Client.Byte_Array (0 .. Recv_Chunk - 1);
      Last      : Natural;
      Recv_Ok   : Boolean;
      Resp      : String (1 .. Resp_Cap);
      Resp_Len  : Natural := 0;
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
            Put_Line ("[wx] could not parse the forecast (response below)");
            Put_Line (Resp (1 .. Resp_Len));
         else
            Put_Line ("[wx] forecast for " & Latitude & ", " & Longitude & " (HTTPS):");
            Put_Line ("[wx]   temperature : " & Temp & " C");
            Put_Line ("[wx]   wind speed  : " & Wind & " km/h");
         end if;
      end;
   end;

   Close_Socket (Sock);
   loop
      delay until Clock + Park_Forever;
   end loop;
end Main;
