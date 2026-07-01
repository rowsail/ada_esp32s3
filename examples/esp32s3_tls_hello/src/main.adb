--  Pure-Ada TLS 1.3 client over the W5500 (Ethernet)
--  =================================================
--  What it demonstrates: a complete TLS 1.3 client handshake done entirely in
--  Ada -- no external C TLS library.  The full flight (TLS_Client) runs:
--    X25519 ECDHE key exchange -> HKDF key schedule -> AES-128-GCM record
--    protection -> server CertificateVerify (RSA-PSS) and Finished -> our own
--    client Finished -> certificate chain validated to a pinned root
--    (Trust_Anchors + Chain_Verify) -> an encrypted HTTP GET and the decrypted
--    response.  All crypto is Ada (SPARKNaCl) plus the ESP32-S3 accelerators.
--
--  Build & run: `./x run esp32s3_tls_hello`.  Uses the embedded runtime profile,
--  which build.sh selects (ESP32S3_RTS_PROFILE=embedded).
--
--  Output: progress lines tagged "[tls]".  A successful run prints the
--  negotiated cipher suite and server key share, the derived handshake secrets,
--  "encrypted handshake decrypted + authenticated (Finished seen)", the
--  CertificateVerify / Finished / chain-validation results, "ready=yes", and
--  finally the decrypted HTTP response after "sent HTTP GET (encrypted)".
--
--  Hardware: needs the W5500 Ethernet module wired per w5500_dev.adb (the board
--  takes static IP 192.168.1.50), on a LAN with a reachable TLS 1.3 server.  Set
--  Server_IP / Server_Port / Host below to that server, for example:
--    openssl s_server -tls1_3 -accept 4433 -cert c.pem -key k.pem
--  whose root certificate is pinned in trust_anchors.ads.
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;
with GNAT.Sockets;  use GNAT.Sockets;
with TLS_Client;
with X509;
with Chain_Verify;
with Chain_Buffers;
with Trust_Anchors;
with W5500_Dev;
with ESP32S3.RNG;
with ESP32S3.Log;   use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  The TLS server to reach.  Server_Port matches the openssl s_server
   --  -accept port above; Host is the name sent in SNI and checked against the
   --  certificate, so it must match the server's certificate subject/SAN.
   Server_IP   : constant String    := "192.168.1.100";
   Server_Port : constant Port_Type := 4433;
   Host        : constant String    := "test.example.com";

   --  Bound the TCP connect retries: the W5500 link and the server may not be
   --  ready the instant we boot.
   Max_Connect_Tries : constant := 20;
   Connect_Retry     : constant Time_Span := Milliseconds (700);

   Sock    : Socket_Type;        --  the TCP socket carrying the encrypted records
   Session : TLS_Client.Session; --  TLS state (keys, transcript, peer cert chain)
   Ok      : Boolean;            --  did the handshake open successfully?

   --  Set True only once the server is REALLY authenticated: its Finished and
   --  CertificateVerify checked AND its cert chain validated to our pinned root.
   --  The application-data exchange is gated on this, not on Ready alone.
   Peer_Authenticated : Boolean := False;
begin
   delay until Clock + Milliseconds (200);
   --  TLS key generation needs real randomness; turn on the hardware CSPRNG
   --  entropy source before any keys are produced.
   ESP32S3.RNG.Enable_Entropy_Source;
   Put_Line ("[tls] pure-Ada TLS 1.3 client over the W5500");
   if not W5500_Dev.Bring_Up then
      --  No link/chip: nothing more to do, so idle forever rather than spin.
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   Ok := False;
   declare
      Connected : Boolean := False;
   begin
      Put_Line ("[tls] connecting to " & Server_IP & ":4433 ...");
      for Try in 1 .. Max_Connect_Tries loop
         begin
            Create_Socket  (Sock, Family_Inet, Socket_Stream);
            Connect_Socket (Sock, (Family_Inet, Inet_Addr (Server_IP), Server_Port));
            Connected := True;
            exit;
         exception
            when others =>
               --  Connect failed this round; drop the half-open socket and
               --  wait before the next attempt.
               begin
                  Close_Socket (Sock);
               exception
                  when others => null;
               end;
               delay until Clock + Connect_Retry;
         end;
      end loop;
      if Connected then
         TLS_Client.Hello (Session, Sock, Host, Ok);
      else
         Put_Line ("[tls] could not connect");
      end if;
   exception
      when others =>
         Put_Line ("[tls] handshake exception");
   end;

   if Ok then
      Put ("[tls] ServerHello: cipher suite = 0x");
      Put_Hex (Interfaces.Unsigned_32 (TLS_Client.Cipher_Suite (Session)), 4);
      New_Line;
      Put ("[tls] server key share = ");
      declare
         --  Just preview the first few bytes of the 32-byte X25519 share.
         Key_Share_Preview : constant := 8;
         Key_Share : constant TLS_Client.Byte_Array :=
           TLS_Client.Server_Key_Share (Session);
      begin
         for I in 0 .. Key_Share_Preview - 1 loop
            Put_Hex (Interfaces.Unsigned_32 (Key_Share (Key_Share'First + I)), 2);
         end loop;
         Put_Line (" ...");
      end;
      Put_Line ("[tls] handshake opening OK");
      if TLS_Client.Keys_Ready (Session) then
         --  Dump the inputs and derived handshake secrets so a run can be
         --  cross-checked against a reference TLS trace (e.g. Wireshark keylog).
         Put ("[tls] client_random=");
         declare
            Client_Random : constant TLS_Client.Byte_Array :=
              TLS_Client.Client_Random (Session);
         begin
            for I in Client_Random'Range loop
               Put_Hex (Interfaces.Unsigned_32 (Client_Random (I)), 2);
            end loop;
         end;
         New_Line;
         Put ("[tls] s_hs_secret=");
         declare
            Server_Handshake_Secret : constant TLS_Client.Byte_Array :=
              TLS_Client.Server_HS_Secret (Session);
         begin
            for I in Server_Handshake_Secret'Range loop
               Put_Hex (Interfaces.Unsigned_32 (Server_Handshake_Secret (I)), 2);
            end loop;
         end;
         New_Line;
         Put ("[tls] c_hs_secret=");
         declare
            Client_Handshake_Secret : constant TLS_Client.Byte_Array :=
              TLS_Client.Client_HS_Secret (Session);
         begin
            for I in Client_Handshake_Secret'Range loop
               Put_Hex (Interfaces.Unsigned_32 (Client_Handshake_Secret (I)), 2);
            end loop;
         end;
         New_Line;
      end if;

      if TLS_Client.Flight_OK (Session) then
         Put_Line ("[tls] encrypted handshake decrypted + authenticated (Finished seen)");
         Put_Line ("[tls] server CertificateVerify (RSA-PSS): "
                   & (if TLS_Client.Server_Cert_Verify_OK (Session) then "OK" else "FAIL"));
         Put_Line ("[tls] server Finished verify: "
                   & (if TLS_Client.Server_Finished_OK (Session) then "OK" else "FAIL"));
         if TLS_Client.Have_Server_Cert (Session) then
            declare
               DER : constant TLS_Client.Byte_Array := TLS_Client.Server_Cert (Session);
               Cert_Bytes : X509.Byte_Array (0 .. DER'Length - 1);
               Cert       : X509.Certificate;
            begin
               --  Re-base the leaf DER to 0-based bounds for X509.Parse.
               for I in 0 .. DER'Length - 1 loop
                  Cert_Bytes (I) := DER (DER'First + I);
               end loop;
               X509.Parse (Cert_Bytes, Cert);
               Put ("[tls] server cert" & Natural'Image (DER'Length) & " bytes: ");
               if Cert.Valid then
                  Put ("parsed; host match=");
                  Put_Line
                    (if X509.Host_Matches (Cert_Bytes, Cert, Host) then "yes" else "no");
               else
                  Put_Line ("PARSE FAIL");
               end if;
            end;
         end if;

         --  Anchor the server's chain to our pinned root (Chain_Verify): every
         --  link's signature, each cert's validity at Now, and the leaf hostname.
         --  Now would come from NTP in production; here it is a fixed reference.
         if TLS_Client.Server_Cert_Count (Session) >= 1 then
            declare
               use Chain_Verify;
               Now          : constant X509.Time_64 :=
                 X509.Pack_Time (2026, 6, 25, 12, 0, 0);
               Anchors      : constant Cert_List :=
                 (1 => (Data => Trust_Anchors.Root_DER'Access));
               Chain_Result : Result;
            begin
               Chain_Buffers.Reset;
               for I in 1 .. TLS_Client.Server_Cert_Count (Session) loop
                  Chain_Buffers.Add (TLS_Client.Server_Chain_Cert (Session, I));
               end loop;
               Chain_Result := Validate (Chain_Buffers.Chain, Anchors, Host, Now);
               Put_Line ("[tls] chain validation (pinned root):" & Natural'Image
                         (TLS_Client.Server_Cert_Count (Session)) & " certs -> "
                         & Result'Image (Chain_Result));

               --  GATE the connection here.  We are inside `if Flight_OK`, so the
               --  encrypted handshake was authenticated (Finished seen); require
               --  ALSO that the server proved possession of its certificate's key
               --  (CertificateVerify) and that its chain validates to our pinned
               --  root -- Validate additionally enforces the leaf host match and
               --  each cert's validity window.  Only then is the peer trusted.
               Peer_Authenticated :=
                 TLS_Client.Server_Cert_Verify_OK (Session)
                 and then TLS_Client.Server_Finished_OK (Session)
                 and then Chain_Result = Valid;
            end;
         end if;
      else
         Put_Line ("[tls] encrypted handshake decrypt FAILED");
      end if;

      Put_Line ("[tls] ready=" & (if TLS_Client.Ready (Session) then "yes" else "no"));
      Put_Line ("[tls] peer authenticated="
                & (if Peer_Authenticated then "yes" else "no"));

      --  Encrypted application data: send the HTTP GET ONLY if the peer is both
      --  Ready AND authenticated.  Ready alone means the TLS handshake completed
      --  cryptographically; it does NOT mean the certificate chain was trusted.
      --  Sending on Ready alone would exchange data with an unauthenticated
      --  (possibly forged / MITM) server -- the bug this gate closes.
      if TLS_Client.Ready (Session) and then Peer_Authenticated then
         declare
            --  HTTP/1.0 GET; "Connection: close" so the server ends the body
            --  by closing, which is how Recv below sees the end of data.
            Req : constant String :=
              "GET / HTTP/1.0" & ASCII.CR & ASCII.LF
              & "Host: " & Host & ASCII.CR & ASCII.LF
              & "Connection: close" & ASCII.CR & ASCII.LF & ASCII.CR & ASCII.LF;

            Recv_Buf_Size : constant := 1024;  --  one TLS record's worth of plaintext

            Req_Bytes : TLS_Client.Byte_Array (0 .. Req'Length - 1);
            Buf       : TLS_Client.Byte_Array (0 .. Recv_Buf_Size - 1);
            Last      : Natural;
            Recv_Ok   : Boolean;
         begin
            --  Convert the request text to bytes for the encrypted Send.
            for I in 0 .. Req'Length - 1 loop
               Req_Bytes (I) :=
                 Interfaces.Unsigned_8 (Character'Pos (Req (Req'First + I)));
            end loop;
            TLS_Client.Send (Session, Sock, Req_Bytes);
            Put_Line ("[tls] sent HTTP GET (encrypted)");
            TLS_Client.Recv (Session, Sock, Buf, Last, Recv_Ok);
            if Recv_Ok then
               Put_Line ("[tls] decrypted response:");
               for I in Buf'First .. Last loop
                  Put (Character'Val (Natural (Buf (I))));
               end loop;
               New_Line;
            else
               Put_Line ("[tls] no application data (server closed / alert)");
            end if;
         end;
      elsif TLS_Client.Ready (Session) then
         Put_Line ("[tls] REFUSING app data: handshake ready but peer NOT "
                   & "authenticated (cert chain not trusted) -- connection rejected");
      end if;
   else
      Put_Line ("[tls] handshake opening FAILED");
   end if;

   Close_Socket (Sock);
   --  Done; this is a one-shot demo, so idle forever instead of returning.
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
