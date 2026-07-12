with GNAT.Sockets;

--  A tiny, portable DNS resolver.  It is written entirely against GNAT.Sockets
--  (a UDP A-record query to a resolver, parsing the first address out of the
--  reply), so the same source compiles and runs on desktop GNAT.Sockets and on the
--  bare-metal W5500 facade alike -- nothing here is chip-specific.
--
--  Use it with one `with DNS_Client;`.  GNAT.Sockets must already be usable (on the
--  W5500, call GNAT.Sockets.Initialize (Device) once during bring-up; on a desktop
--  it always is).
--
--  Concurrency: Resolve keeps two benign package-global rotors (the transaction
--  id and the default source port).  Concurrent calls from several tasks do not
--  corrupt anything, but two in-flight queries can land on the same source port
--  and one then fails its reply check -- a failed lookup, not an error.  If you
--  resolve from more than one task, serialise the calls or accept the retry.

package DNS_Client is

   use type GNAT.Sockets.Inet_Addr_Type;   --  '=' in Resolve's Post

   --  Resolve Name (e.g. "api.open-meteo.com") to its first IPv4 address by querying
   --  the resolver at Server (e.g. Inet_Addr ("8.8.8.8")).  True with Addr set on
   --  success; False with Addr = Any_Inet_Addr if the resolver does not answer in
   --  time or the reply carries no A record.
   --
   --  Timeout caps the wait for the reply (via the Receive_Timeout socket option);
   --  0.0, the default, blocks indefinitely.
   --
   --  Local_Port is the UDP source port to bind; 0, the default, picks a fresh
   --  port from the IANA dynamic range on every query.  Never fix the source
   --  port without a reason: a fixed port narrows the reply-spoofing search
   --  space, and -- measured on cellular -- lets a carrier-NAT flow that has
   --  gone bad (a query killed mid-flight) blackhole every later query, with
   --  each retry refreshing the poisoned entry so it never ages out.
   --  Server_Port is the resolver's UDP port.  53 unless you have a reason;
   --  the reason that exists in the field is a carrier network whose broken
   --  transparent proxy swallows port-53 traffic, where a resolver listening
   --  on an alternate port (OpenDNS answers on 5353 and 443) still works.
   function Resolve
     (Server      : GNAT.Sockets.Inet_Addr_Type;
      Name        : String;
      Addr        : out GNAT.Sockets.Inet_Addr_Type;
      Timeout     : Duration := 0.0;
      Local_Port  : GNAT.Sockets.Port_Type := 0;
      Server_Port : GNAT.Sockets.Port_Type := 53) return Boolean
   with Pre  => Name'Length > 0,
        Post =>
          (if not Resolve'Result then Addr = GNAT.Sockets.Any_Inet_Addr);

end DNS_Client;
