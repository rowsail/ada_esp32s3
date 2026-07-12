--  One name, four DNS transports: UDP, TCP, DoT and DoH, over the W5500.
--  ============================================================================
--
--  What it demonstrates
--    The same host name resolved four ways, over Ethernet:
--
--      * UDP  on port 53   -- the ordinary case (DNS_Client.Resolve).
--      * TCP  on port 53   -- RFC 7766, DNS's own escape hatch when UDP is
--                             mangled (DNS_Client.Resolve_TCP).
--      * DoT  on port 853  -- RFC 7858, the query framed inside TLS 1.3.
--      * DoH  on port 443  -- RFC 8484, the query as an HTTP/1.1 POST in TLS.
--
--    All four build the SAME proven query bytes (DNS_Client.Wire) and walk
--    the reply with the SAME proven parser (DNS_Client.Parse); only the
--    carriage differs.  The point of the encrypted pair: port-53 UDP is the
--    most interfered-with traffic on the internet -- carriers, hotels and
--    national firewalls all tamper with it -- and DoT/DoH are designed to be
--    indistinguishable from ordinary TLS, so an interceptor cannot even see
--    them, let alone block them.
--
--    The DoT/DoH legs speak to Google Public DNS (dns.google, 8.8.8.8) and
--    pin its P-256 issuing intermediate (DoT_Anchor.WE2_DER).  Pinning the
--    intermediate rather than a root is a demo simplification: the public
--    DoT roots are P-384 ECC, which this TLS stack does not verify yet; the
--    leaf verifies under WE2 with ECDSA-P256-SHA256, which it does.
--
--  Build & run:  ./x run esp32s3_dns_secure       (or ./build.sh, ./flash.sh)
--
--  Output
--    DHCP lease, NTP time, then one "[dns] <transport>: <name> = a.b.c.d"
--    line per transport (or "failed"), and a summary.
--
--  Hardware / wiring
--    The W5500 on SPI2 (SCLK=IO1 MOSI=IO4 MISO=IO45 CS=IO39 RST=IO11 INT=IO3),
--    a cable to a DHCP network with a route to the internet.
with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;

with GNAT.Sockets; use GNAT.Sockets;
with Net_Devices;
with ESP32S3.Strings;
with DNS_Client;
with DNS_TLS;
with NTP_Client;
with TLS_Client;
with X509;
with Chain_Verify;
with Chain_Buffers;
with DoT_Anchor;

with ESP32S3.W5500.DHCP;
with ESP32S3.W5500.Interrupts;
with ESP32S3.RNG;
with ESP32S3.Log; use ESP32S3.Log;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  The name to resolve.  The plain UDP/TCP legs use the network's OWN
   --  resolver (from the DHCP lease): reachable by both, and not subject to
   --  the common policy of filtering external port-53 traffic.  The DoT/DoH
   --  legs go to Google Public DNS, which those legs are precisely designed
   --  to reach THROUGH such filtering.
   Query_Name  : constant String := "example.com";
   Public_DNS  : constant Inet_Addr_Type := Inet_Addr ("8.8.8.8");
   DoH_Host    : constant String := "dns.google";   --  TLS SNI + HTTP Host

   Plain_DNS   : Inet_Addr_Type;   --  the lease's resolver, set at bring-up

   Lease   : ESP32S3.W5500.DHCP.Lease_Info;
   Now     : X509.Time_64;
   Ok      : Boolean;
   Addr    : Inet_Addr_Type;
   Wins    : Natural := 0;

   function Image (A : Inet_Addr_Type) return String is
      O : constant Net_Devices.IPv4_Address := GNAT.Sockets.Octets_Of (A);
      function N (X : Net_Devices.Octet) return String
      is (ESP32S3.Strings.Image (Natural (X)));
   begin
      return N (O (0)) & "." & N (O (1)) & "." & N (O (2)) & "." & N (O (3));
   end Image;

   procedure Report (Transport : String; Got : Boolean; A : Inet_Addr_Type) is
   begin
      if Got then
         Wins := Wins + 1;
         Put_Line ("[dns] " & Transport & ": " & Query_Name & " = " & Image (A));
      else
         Put_Line ("[dns] " & Transport & ": failed");
      end if;
   end Report;

   --  Stand up a TLS 1.3 session to Public_DNS on Port, authenticate
   --  dns.google's leaf under the pinned WE2 intermediate, and leave the
   --  socket + session open for the caller.  Ok is False (socket closed) on
   --  any failure.
   procedure Secure_Connect
     (Port    : Port_Type;
      Sock    : out Socket_Type;
      Session : out TLS_Client.Session;
      Ready   : out Boolean)
   is
      use Chain_Verify;
      Anchors : constant Cert_List :=
        (1 => (Data => DoT_Anchor.WE2_DER'Access));
      Verdict : Result;
   begin
      Ready := False;
      begin
         Create_Socket (Sock, Family_Inet, Socket_Stream);
         Connect_Socket (Sock, (Family_Inet, Public_DNS, Port));
         TLS_Client.Hello (Session, Sock, DoH_Host, Ok);
      exception
         when others =>
            Ok := False;
      end;
      if not Ok then
         begin
            Close_Socket (Sock);
         exception
            when others => null;
         end;
         return;
      end if;

      Chain_Buffers.Reset;
      if TLS_Client.Server_Cert_Count (Session) >= 1 then
         Chain_Buffers.Add (TLS_Client.Server_Chain_Cert (Session, 1));
      end if;
      --  Add ONLY the leaf and validate it directly under the pinned WE2
      --  intermediate.  Google serves the full path down to a P-384 ECC root
      --  this TLS stack does not parse; feeding that root to the validator
      --  yields Malformed, and it is not needed -- the leaf verifies under
      --  WE2 with ECDSA-P256-SHA256.
      Verdict := Validate (Chain_Buffers.Chain, Anchors, DoH_Host, Now);

      if Verdict = Valid
        and then TLS_Client.Server_Cert_Verify_OK (Session)
        and then TLS_Client.Server_Finished_OK (Session)
      then
         Ready := True;
      else
         Put_Line ("[dns]   (TLS auth failed: chain "
                   & Result'Image (Verdict) & ")");
         begin
            Close_Socket (Sock);
         exception
            when others => null;
         end;
      end if;
   end Secure_Connect;

begin
   delay until Clock + Milliseconds (200);
   ESP32S3.RNG.Enable_Entropy_Source;
   Put_Line ("");
   Put_Line ("[dns] one name, four transports -- UDP / TCP / DoT / DoH");

   if not W5500_Dev.Bring_Up (Lease => Lease) then
      Put_Line ("[dns] no network -- check the cable and the DHCP server");
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;
   ESP32S3.W5500.Interrupts.Enable (W5500_Dev.Dev);
   Plain_DNS := Inet_Addr (W5500_Dev.Image (Lease.DNS));

   --  Trusted UTC for the certificate-validity checks (DoT/DoH).
   declare
      Unix : Interfaces.Integer_64;
      Y, Mo, D, H, Mi, S : Integer;
   begin
      if NTP_Client.Query (Inet_Addr ("162.159.200.1"), Unix, Timeout => 8.0) then
         NTP_Client.To_UTC (Unix, Y, Mo, D, H, Mi, S);
         Now := X509.Pack_Time (Y, Mo, D, H, Mi, S);
         Put_Line ("[dns] clock synced from NTP");
      else
         Put_Line ("[dns] NTP failed -- DoT/DoH cert dates cannot be checked");
      end if;
   end;

   ---------------------------------------------------------------------------
   --  1. UDP on 53.
   ---------------------------------------------------------------------------
   Ok := DNS_Client.Resolve (Plain_DNS, Query_Name, Addr, Timeout => 5.0);
   Report ("UDP  (53) ", Ok, Addr);

   ---------------------------------------------------------------------------
   --  2. TCP on 53.
   ---------------------------------------------------------------------------
   Ok := DNS_Client.Resolve_TCP (Plain_DNS, Query_Name, Addr, Timeout => 5.0);
   Report ("TCP  (53) ", Ok, Addr);

   ---------------------------------------------------------------------------
   --  3. DoT on 853.
   ---------------------------------------------------------------------------
   declare
      Sock    : Socket_Type;
      Session : TLS_Client.Session;
      Ready   : Boolean;
   begin
      Secure_Connect (853, Sock, Session, Ready);
      if Ready then
         DNS_TLS.Resolve_DoT (Session, Sock, Query_Name, Addr, Ok);
         Report ("DoT  (853)", Ok, Addr);
         begin
            Close_Socket (Sock);
         exception
            when others => null;
         end;
      else
         Report ("DoT  (853)", False, Addr);
      end if;
   end;

   ---------------------------------------------------------------------------
   --  4. DoH on 443.
   ---------------------------------------------------------------------------
   declare
      Sock    : Socket_Type;
      Session : TLS_Client.Session;
      Ready   : Boolean;
   begin
      Secure_Connect (443, Sock, Session, Ready);
      if Ready then
         DNS_TLS.Resolve_DoH
           (Session, Sock, DoH_Host, Query_Name, Addr, Ok);
         Report ("DoH  (443)", Ok, Addr);
         begin
            Close_Socket (Sock);
         exception
            when others => null;
         end;
      else
         Report ("DoH  (443)", False, Addr);
      end if;
   end;

   Put_Line ("[dns] done --" & Natural'Image (Wins) & " of 4 transports resolved");
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
