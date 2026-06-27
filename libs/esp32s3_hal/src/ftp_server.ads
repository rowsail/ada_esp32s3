with GNAT.Sockets;
with ESP32S3.Ext4.FS;

--  A small anonymous FTP server (RFC 959, passive mode) that exposes an ext4
--  filesystem -- e.g. the ext4-on-W25Q-flash volume -- over the network, so a
--  desktop FTP client can browse, download, upload and manage the board's files.
--
--  Written against GNAT.Sockets (so the same source would run on a desktop) plus
--  ESP32S3.Ext4.FS for the storage.  It serves ONE client at a time: a persistent
--  control connection plus one PASSIVE data connection per transfer, on a fixed
--  data port (a single-client embedded server needs no port range).  PASV only --
--  the client always connects out to the server, which is all a desktop client
--  needs and keeps the socket model simple.
--
--  Run blocks forever in the calling task, accepting clients in turn.  Needs the
--  embedded or full profile (GNAT.Sockets + the ext4 FS).
package FTP_Server is

   --  Serve FS over anonymous FTP until the program ends.  Local_IP is the
   --  board's own dotted-decimal address (e.g. "192.168.1.50"); it is what PASV
   --  advertises for the data connection, so it must be the address the client
   --  reaches the board on.  Any username/password is accepted (anonymous).  With
   --  Read_Only set, the mutating commands (STOR/DELE/MKD/RMD) are refused.
   procedure Run
     (FS        : not null access ESP32S3.Ext4.FS.Mount;
      Local_IP  : String;
      Port      : GNAT.Sockets.Port_Type := 21;
      Data_Port : GNAT.Sockets.Port_Type := 50_000;
      Read_Only : Boolean := False);

end FTP_Server;
