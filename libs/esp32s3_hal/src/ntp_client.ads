with Interfaces;
with GNAT.Sockets;

--  A tiny, portable SNTP/NTP time client.  Like DNS_Client, it is written entirely
--  against GNAT.Sockets (a UDP query to an NTP server, reading the transmit
--  timestamp out of the reply), so the same source compiles and runs on desktop
--  GNAT.Sockets and on the bare-metal W5500 facade alike -- nothing here is
--  chip-specific.
--
--  Use it with one `with NTP_Client;`.  GNAT.Sockets must already be usable (on the
--  W5500, call GNAT.Sockets.Initialize (Device) once during bring-up).

package NTP_Client is

   --  Query the NTP server at Server (UDP port 123) for the current UTC time.
   --  True with Unix_Time set (seconds since 1970-01-01 UTC) on success; False if
   --  the server does not answer within Timeout or the reply is unusable.
   --
   --  Timeout caps the wait for the reply (via the Receive_Timeout socket option);
   --  0.0, the default, blocks indefinitely.  Local_Port is the UDP source port.
   function Query
     (Server     : GNAT.Sockets.Inet_Addr_Type;
      Unix_Time  : out Interfaces.Integer_64;
      Timeout    : Duration := 0.0;
      Local_Port : GNAT.Sockets.Port_Type := 12_300) return Boolean;

   --  Break a Unix time (seconds since 1970-01-01 UTC) into UTC calendar fields
   --  (Howard Hinnant's civil-from-days algorithm; valid for any Gregorian date).
   procedure To_UTC
     (Unix_Time : Interfaces.Integer_64;
      Year      : out Integer;
      Month     : out Integer;
      Day       : out Integer;
      Hour      : out Integer;
      Minute    : out Integer;
      Second    : out Integer)
   with Post =>
        Month in 1 .. 12
        and then Day in 1 .. 31
        and then Hour in 0 .. 23
        and then Minute in 0 .. 59
        and then Second in 0 .. 59;

end NTP_Client;
