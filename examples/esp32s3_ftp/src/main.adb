--  What it demonstrates
--  ---------------------
--  An FTP *client* over the WIZnet W5500 Ethernet controller, driven through the
--  portable FTP_Client package (which is itself written against the GNAT.Sockets
--  facade).  It logs in to an FTP server, prints the SIZE of a file, downloads it
--  (RETR) to the console, lists the directory (NLST), and quits.  Passive mode,
--  binary -- the embedded-friendly profile (only outbound connections).
--
--  Build & run
--  -----------
--    ./x run esp32s3_ftp
--  build.sh sets the embedded runtime profile (ESP32S3_RTS_PROFILE=embedded).
--
--  How to read the output
--  ----------------------
--    [ftp] W5500 FTP client (FTP_Client over GNAT.Sockets)
--    [w5500] link up, IP 192.168.1.50
--    [ftp] connecting to 192.168.1.100:21 ...
--    [ftp] logged in.
--    [ftp] SIZE /hello.txt = 30
--    [ftp] --- RETR /hello.txt ---
--    hello from the ftp host test
--    [ftp] --- NLST ---
--    hello.txt
--    [ftp] done.
--
--  Hardware / network
--  ------------------
--  A WIZnet W5500 SPI module on SPI2 (pins in w5500_dev.adb).  The board takes the
--  static IP 192.168.1.50 (/24, gateway .254); put it and the FTP server on the
--  same subnet and point Server_IP below at the server.  A quick local server:
--    python3 libs/esp32s3_hal/test/ftp_host/ftp_server.py   (prints its port)
--  or any FTP daemon on port 21 with the credentials below.
with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Sockets;  use GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;
with W5500_Dev;
with FTP_Client;
with FTP_Print;
with System;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use type FTP_Client.Status;

   --  The FTP server to talk to (same /24 as the board's static IP).  Edit for
   --  your LAN; credentials match the bundled test server (any user/pass there).
   Server_IP   : constant String := "192.168.1.100";   --  the LAN host running the server
   Server_Port : constant Port_Type :=
     2121;              --  matches ftp_server.py 2121 (21 for a real daemon)
   User        : constant String := "demo";
   Pass        : constant String := "password";
   Get_Path    : constant String := "/hello.txt";
   Put_Path    : constant String := "/from_board.bin";   --  STOR target

   Startup_Settle : constant Time_Span := Milliseconds (200);
   Park_Interval  : constant Time_Span := Seconds (3600);

   S  : FTP_Client.Session;
   St : FTP_Client.Status;
   Sz : Natural;
begin
   delay until Clock + Startup_Settle;
   Put_Line ("[ftp] W5500 FTP client (FTP_Client over GNAT.Sockets)");

   if not W5500_Dev.Bring_Up then
      Put_Line ("[w5500] not found -- check wiring; idling.");
      loop
         delay until Clock + Park_Interval;
      end loop;
   end if;

   Put ("[ftp] connecting to " & Server_IP & ":");
   Put (Integer (Server_Port));
   Put_Line (" ...");

   FTP_Client.Connect
     (S,
      Host     => Inet_Addr (Server_IP),
      User     => User,
      Password => Pass,
      Result   => St,
      Port     => Server_Port,
      Timeout  => 10.0);

   if St /= FTP_Client.OK then
      Put ("[ftp] connect/login failed: ");
      Put_Line (St'Image);
   else
      Put_Line ("[ftp] logged in.");

      FTP_Client.File_Size (S, Get_Path, Sz, St);
      if St = FTP_Client.OK then
         Put ("[ftp] SIZE " & Get_Path & " = ");
         Put (Sz);
         New_Line;
      end if;

      Put_Line ("[ftp] --- RETR " & Get_Path & " ---");
      FTP_Client.Retrieve (S, Get_Path, FTP_Print.Put_Chunk'Access, System.Null_Address, St);
      New_Line;
      Put ("[ftp] retrieve result: ");
      Put_Line (St'Image);

      Put_Line ("[ftp] --- NLST ---");
      FTP_Client.List (S, FTP_Print.Put_Chunk'Access, System.Null_Address, St);
      Put ("[ftp] list result: ");
      Put_Line (St'Image);

      --  Test SENDING: upload a generated file (STOR), then read it back (RETR)
      --  and verify it byte-exact -- a full upload round-trip from the board.
      Put_Line ("[ftp] --- STOR + read-back round-trip ---");
      FTP_Print.Reset_Source;
      FTP_Client.Store (S, Put_Path, FTP_Print.Test_Source'Access, System.Null_Address, St);
      Put ("[ftp] STOR " & Put_Path & " (");
      Put (FTP_Print.Upload_Bytes);
      Put (" bytes): ");
      Put_Line (St'Image);

      if St = FTP_Client.OK then
         FTP_Print.Reset_Verify;
         FTP_Client.Retrieve (S, Put_Path, FTP_Print.Verify_Chunk'Access, System.Null_Address, St);
         Put ("[ftp] read-back ");
         Put (FTP_Print.Verify_Count);
         Put (" bytes: ");
         if St = FTP_Client.OK
           and then FTP_Print.Verify_OK
           and then FTP_Print.Verify_Count = FTP_Print.Upload_Bytes
         then
            Put_Line ("round-trip VERIFIED");
         else
            Put_Line ("MISMATCH (" & St'Image & ")");
         end if;
      end if;

      FTP_Client.Quit (S);
      Put_Line ("[ftp] done.");
   end if;

   loop
      delay until Clock + Park_Interval;
   end loop;
end Main;
