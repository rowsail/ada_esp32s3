--  What it demonstrates
--  ---------------------
--  An anonymous FTP *server* on the ESP32-S3, exposing the ext4-on-W25Q-flash
--  filesystem over the network: a desktop FTP client (FileZilla, the `ftp` CLI, a
--  browser, Python ftplib) can browse, download, upload, delete and mkdir on the
--  board's flash.  It is the server counterpart to esp32s3_ftp / esp32s3_ftp_inet
--  (the FTP *client*), and ties the whole stack together: W5500 + GNAT.Sockets +
--  FTP_Server on top of ESP32S3.Ext4 -> Block_Dev.WL -> W25Q.
--
--  Build & run
--  -----------
--    ./x run esp32s3_ftp_server
--  Then, from a host on the same LAN (the board prints its IP):
--    ftp <board-ip>        (user: anything, password: anything -- anonymous)
--    python3 -c "from ftplib import FTP; f=FTP('<board-ip>'); f.login(); print(f.nlst())"
--
--  Network: DHCP (the router supplies IP/gateway/DNS).  The flash is formatted
--  FRESH on every boot (a fresh ext4), seeded with /readme.txt and an /uploads
--  directory -- so uploads survive only until the next reset.  PASSIVE mode, a
--  fixed data port (50000); make sure FTP and that port are reachable on your LAN.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI;
with ESP32S3.W25Q;
with ESP32S3.GPIO;
with ESP32S3.Log;                   use ESP32S3.Log;
with ESP32S3.Block_Dev;             use ESP32S3.Block_Dev;
with ESP32S3.Block_Dev.W25Q_Source;
with ESP32S3.Block_Dev.WL;
with ESP32S3.Ext4;                  use ESP32S3.Ext4;
with ESP32S3.Ext4.Mkfs;
with ESP32S3.Ext4.FS;
with ESP32S3.Ext4.VFS;
with ESP32S3.W5500.DHCP;
with W5500_Dev;
with FTP_Server;
with Flash_FS;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SPI  renames ESP32S3.SPI;
   package W25Q renames ESP32S3.W25Q;
   package BDW  renames ESP32S3.Block_Dev.W25Q_Source;
   package WL   renames ESP32S3.Block_Dev.WL;
   package FS   renames ESP32S3.Ext4.FS;
   package Mkfs renames ESP32S3.Ext4.Mkfs;

   SCLK_Pin : constant := 1;
   MOSI_Pin : constant := 4;
   MISO_Pin : constant := 45;
   CS_Pin   : constant ESP32S3.GPIO.Pin_Id := 21;
   Clock_Hz : constant := 8_000_000;

   Flash : W25Q.Flash :=
     (Host => SPI.SPI2, Clock_Hz => Clock_Hz, CS_Pin => CS_Pin, others => <>);
   ID      : W25Q.JEDEC_ID;
   Mode_OK : Boolean;

   --  The flash stack lives in Flash_FS (library level -- see that package).
   Raw : ESP32S3.Block_Dev.W25Q_Source.Source renames Flash_FS.Raw;
   Vol : ESP32S3.Block_Dev.WL.Volume          renames Flash_FS.Vol;
   Dev : Device                               renames Flash_FS.Dev;
   M   : FS.Mount                             renames Flash_FS.M;
   N   : Inode_Number;

   Lease : ESP32S3.W5500.DHCP.Lease_Info;
   Park  : constant Time_Span := Seconds (3600);

   function To_Bytes (S : String) return Byte_Array is
      B : Byte_Array (0 .. S'Length - 1);
   begin
      for I in B'Range loop
         B (I) := Unsigned_8 (Character'Pos (S (S'First + I)));
      end loop;
      return B;
   end To_Bytes;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[ftpd] ext4-flash anonymous FTP server");

   --  1. Network up via DHCP (gives us the IP that PASV must advertise).
   if not W5500_Dev.Bring_Up (Lease => Lease) then
      loop
         delay until Clock + Park;
      end loop;
   end if;

   --  2. Flash + a fresh ext4 filesystem over the wear-leveling FTL.
   SPI.Setup (SPI.SPI2);
   SPI.Configure_Pins (SPI.SPI2, Sclk => SCLK_Pin, Mosi => MOSI_Pin, Miso => MISO_Pin);
   W25Q.Read_Identification (Flash, ID);
   W25Q.Initialize (Flash, Mode_OK);
   if ID.Manufacturer /= 16#EF# or else not Mode_OK then
      Put_Line ("[ftpd] flash not found -- check wiring");
      loop
         delay until Clock + Park;
      end loop;
   end if;

   BDW.Configure (Raw, Flash => Flash);
   WL.Attach (Vol, BDW.Make (Raw'Access), Update_Rate => 64);
   WL.Format (Vol);
   Dev := WL.Make (Vol'Access);
   Mkfs.Format (Dev, Volume_Label => "ESP32FLASH", Journal => False);
   M.Open (Dev, Read_Only => False);

   --  3. Seed a little content so the first listing is not empty.
   N := M.Create_File ("/", "readme.txt");
   M.Write_File
     (N, To_Bytes ("Files on the ESP32-S3 ext4 flash, served over FTP." & ASCII.LF));
   M.Mkdir ("/", "uploads");
   M.Commit;

   --  4. Mount the flash at "/flash" in the FTP server's namespace.  To expose a
   --  second device later (e.g. an SD card on Block_Dev.SDMMC_Source), bring it up
   --  the same way and add one line: ESP32S3.Ext4.VFS.Add ("sd", SD_M'Access);
   --  -- the mount objects must be library-level (Flash_FS), so their access can
   --  be stored in the VFS table that outlives this procedure.
   ESP32S3.Ext4.VFS.Add ("flash", M'Access);

   Put_Line ("[ftpd] serving on " & W5500_Dev.Image (Lease.IP)
             & ":21  (anonymous, read-write)  ->  /flash");

   --  5. Serve forever.  No Local_IP: the server reads its own address from each
   --  accepted connection (Get_Socket_Name), so PASV always advertises the IP the
   --  client reached us on -- whatever DHCP currently assigned.
   FTP_Server.Run (Server_Name => "Ada ESP32-S3");
end Main;
