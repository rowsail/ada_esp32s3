--  What it demonstrates
--  ---------------------
--  A REAL-WORLD FTP client run over the W5500: it logs in anonymously to the
--  public GNU FTP server (ftp.gnu.org), prints a file's SIZE, downloads it (RETR,
--  counting bytes and comparing to SIZE), lists the root (NLST), and quits.  The
--  FTP analogue of esp32s3_tls_weather: same DNS bring-up, plain FTP instead of
--  HTTPS.  Passive mode, binary, read-only (anonymous FTP can't upload).
--
--  Build & run
--  -----------
--    ./x run esp32s3_ftp_inet
--  build.sh sets the embedded runtime profile (ESP32S3_RTS_PROFILE=embedded).
--
--  Network
--  -------
--  DHCP: the board gets its IP, subnet, GATEWAY and DNS server from your router
--  (nothing to hand-configure).  Plug the W5500 into a LAN that has a DHCP server
--  and internet access, with outbound FTP (port 21, passive) permitted.  Host
--  name resolution uses the DHCP-provided DNS (falling back to 8.8.8.8).
--
--  Expected output (abridged)
--  --------------------------
--    [ftp] real-world FTP client -> ftp.gnu.org (anonymous)
--    [w5500] link up; DHCP IP 192.168.1.50 gw 192.168.1.1 dns 192.168.1.1
--    [ftp] resolving ftp.gnu.org via 192.168.1.1 ...
--    [ftp] ftp.gnu.org = 209.51.188.20
--    [ftp] logged in.
--    [ftp] SIZE /README = 2814 bytes
--    [ftp] RETR /README: 2814 bytes received, result OK
--    [ftp] --- NLST / ---
--    /README
--    /gnu
--    /pub
--    ...
--    [ftp] done.
with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Sockets;  use GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.W5500;
with ESP32S3.W5500.DHCP;
with W5500_Dev;
with DNS_Client;
with FTP_Client;
with FTP_Sinks;
with System;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use type FTP_Client.Status;
   use type ESP32S3.W5500.IPv4_Address;

   --  How the board gets its address.  Default: DHCP (router supplies IP /
   --  gateway / DNS).  For a static address instead, replace this with e.g.:
   --    Net_Config : constant W5500_Dev.IP_Settings :=
   --      (Use_DHCP => False,
   --       IP      => ESP32S3.W5500.IPv4 (192, 168, 1, 50),
   --       Subnet  => ESP32S3.W5500.IPv4 (255, 255, 255, 0),
   --       Gateway => ESP32S3.W5500.IPv4 (192, 168, 1, 1),
   --       DNS     => ESP32S3.W5500.IPv4 (8, 8, 8, 8));
   Net_Config : constant W5500_Dev.IP_Settings := W5500_Dev.DHCP_Config;

   Host     : constant String := "ftp.gnu.org";
   FTP_Port : constant Port_Type := 21;
   User     : constant String := "anonymous";
   Pass     : constant String := "esp32s3@example.com";
   Get_Path : constant String := "/README";

   Lookup_Timeout : constant Duration := 5.0;
   Op_Timeout     : constant Duration := 15.0;
   Park           : constant Time_Span := Seconds (3600);

   No_Address : constant ESP32S3.W5500.IPv4_Address := (0, 0, 0, 0);

   Lease      : ESP32S3.W5500.DHCP.Lease_Info;
   DNS_Server : Inet_Addr_Type;
   Server_IP  : Inet_Addr_Type;
   Session    : FTP_Client.Session;
   Result     : FTP_Client.Status;
   Size       : Natural;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[ftp] real-world FTP client -> " & Host & " (anonymous)");

   --  Bring up the link per Net_Config (DHCP by default; static if you set it).
   if not W5500_Dev.Bring_Up (Net_Config, Lease) then
      loop
         delay until Clock + Park;
      end loop;
   end if;

   --  Use the lease's resolver (DHCP- or statically-set); fall back to public DNS.
   DNS_Server :=
     (if Lease.DNS = No_Address
      then Inet_Addr ("8.8.8.8")
      else Inet_Addr (W5500_Dev.Image (Lease.DNS)));

   Put_Line ("[ftp] resolving " & Host & " via " & Image (DNS_Server) & " ...");
   if not DNS_Client.Resolve (DNS_Server, Host, Server_IP, Timeout => Lookup_Timeout) then
      Put_Line ("[ftp] DNS resolution failed");
      loop
         delay until Clock + Park;
      end loop;
   end if;
   Put_Line ("[ftp] " & Host & " = " & Image (Server_IP));

   FTP_Client.Connect
     (Session,
      Host     => Server_IP,
      User     => User,
      Password => Pass,
      Result   => Result,
      Port     => FTP_Port,
      Timeout  => Op_Timeout);
   if Result /= FTP_Client.OK then
      Put ("[ftp] connect/login failed: ");
      Put_Line (Result'Image);
      loop
         delay until Clock + Park;
      end loop;
   end if;
   Put_Line ("[ftp] logged in.");

   --  SIZE + download a file, counting bytes (compare to SIZE for a sanity check).
   FTP_Client.File_Size (Session, Get_Path, Size, Result);
   if Result = FTP_Client.OK then
      Put ("[ftp] SIZE " & Get_Path & " = ");
      Put (Size);
      Put_Line (" bytes");
   end if;

   FTP_Sinks.Reset_Count;
   FTP_Client.Retrieve
     (Session, Get_Path, FTP_Sinks.Count_Chunk'Access, System.Null_Address, Result);
   Put ("[ftp] RETR " & Get_Path & ": ");
   Put (FTP_Sinks.Bytes_Seen);
   Put (" bytes received, result ");
   Put_Line (Result'Image);

   --  List the root directory.
   Put_Line ("[ftp] --- NLST / ---");
   FTP_Client.List (Session, FTP_Sinks.Put_Chunk'Access, System.Null_Address, Result, Path => "/");
   New_Line;
   Put ("[ftp] list result: ");
   Put_Line (Result'Image);

   FTP_Client.Quit (Session);
   Put_Line ("[ftp] done.");

   loop
      delay until Clock + Park;
   end loop;
end Main;
