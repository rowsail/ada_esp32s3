with GNAT.Sockets;

--  A small anonymous FTP server (RFC 959, passive mode) that exposes one or more
--  ext4 filesystems -- e.g. the ext4-on-W25Q-flash volume, and an SD card -- over
--  the network, so a desktop FTP client can browse, download, upload and manage
--  the board's files.
--
--  The filesystems are presented through ESP32S3.Ext4.VFS: register each one under
--  a name BEFORE calling Run, and they appear as top-level directories in a single
--  tree (e.g. "/flash", "/sd").  The virtual root "/" lists the mount names.  With
--  one mount registered there is just a single "/flash" at the root; adding a
--  second storage device later is one more VFS.Add call -- nothing here changes.
--
--    ESP32S3.Ext4.VFS.Add ("flash", Flash_M'Access);   -- library-level mounts
--    ESP32S3.Ext4.VFS.Add ("sd",    SD_M'Access);       -- (optional, later)
--    FTP_Server.Run (Local_IP => "192.168.1.50");
--
--  Written against GNAT.Sockets (so the same source would run on a desktop).  It
--  serves ONE client at a time: a persistent control connection plus one PASSIVE
--  data connection per transfer, on a fixed data port (a single-client embedded
--  server needs no port range).  PASV only -- the client always connects out to
--  the server, which is all a desktop client needs and keeps the socket model
--  simple.
--
--  Run blocks forever in the calling task, accepting clients in turn.  Needs the
--  embedded or full profile (GNAT.Sockets + the ext4 FS).
package FTP_Server is

   --  Serve the registered VFS mounts over anonymous FTP until the program ends.
   --  Local_IP is what PASV advertises for the data connection.  Leave it ""
   --  (the default) and the server derives it from each accepted connection --
   --  Get_Socket_Name on the control socket gives the interface's own address, so
   --  PASV advertises exactly the IP the client reached the board on (whatever
   --  DHCP or the static config currently has).  Pass a dotted-decimal string only
   --  to override (e.g. a forwarded/public address behind NAT).  Any
   --  username/password is accepted (anonymous).  With Read_Only set, the mutating
   --  commands (STOR/DELE/MKD/RMD) are refused.  Server_Name is announced in the
   --  220 greeting on connect (e.g. "220 Ada ESP32-S3 FTP server ready").
   procedure Run
     (Local_IP    : String := "";
      Server_Name : String := "Ada ESP32-S3";
      Port        : GNAT.Sockets.Port_Type := 21;
      Data_Port   : GNAT.Sockets.Port_Type := 50_000;
      Read_Only   : Boolean := False);

end FTP_Server;
