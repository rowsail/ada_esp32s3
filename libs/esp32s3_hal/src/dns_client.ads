with GNAT.Sockets;

--  A tiny, portable DNS resolver.  It is written entirely against GNAT.Sockets
--  (a UDP A-record query to a resolver, parsing the first address out of the
--  reply), so the same source compiles and runs on desktop GNAT.Sockets and on the
--  bare-metal W5500 facade alike -- nothing here is chip-specific.
--
--  Use it with one `with DNS_Client;`.  GNAT.Sockets must already be usable (on the
--  W5500, call GNAT.Sockets.Initialize (Device) once during bring-up; on a desktop
--  it always is).

package DNS_Client is

   --  Resolve Name (e.g. "api.open-meteo.com") to its first IPv4 address by querying
   --  the resolver at Server (e.g. Inet_Addr ("8.8.8.8")).  True with Addr set on
   --  success; False with Addr = Any_Inet_Addr if the resolver does not answer in
   --  time or the reply carries no A record.
   --
   --  Timeout caps the wait for the reply (via the Receive_Timeout socket option);
   --  0.0, the default, blocks indefinitely.  Local_Port is the UDP source port to
   --  bind.
   function Resolve
     (Server     : GNAT.Sockets.Inet_Addr_Type;
      Name       : String;
      Addr       : out GNAT.Sockets.Inet_Addr_Type;
      Timeout    : Duration := 0.0;
      Local_Port : GNAT.Sockets.Port_Type := 13_001) return Boolean;

end DNS_Client;
