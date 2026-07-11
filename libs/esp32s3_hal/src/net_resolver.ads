with GNAT.Sockets;

--  One way to turn a host name into an address, whatever is carrying the traffic.
--
--  Resolution is a real DNS query of our own: a UDP A-record request to a
--  nameserver, which is what DNS_Client does over GNAT.Sockets -- so it works
--  identically over Ethernet, cellular, or anything else the routing table
--  points at.  Callers write one line and stop caring:
--
--     if Net_Resolver.Resolve ("api.open-meteo.com", Addr) then ...
--
--  (Devices are never asked to resolve names themselves.  The one modem
--  resolver we tried, the BG95's AT+QIDNSGIP, silently refused answers it did
--  not like the shape of -- a CNAME chain onto several A records fails where
--  a bare A record resolves -- so that path was removed from the stack.)

package Net_Resolver is

   --  A public resolver, asked when the caller does not name one.
   Default_DNS : constant String := "8.8.8.8";

   --  True with Addr set on success.  On failure Addr is Any_Inet_Addr, matching
   --  DNS_Client's contract.
   function Resolve
     (Name       : String;
      Addr       : out GNAT.Sockets.Inet_Addr_Type;
      DNS_Server : GNAT.Sockets.Inet_Addr_Type := GNAT.Sockets.Inet_Addr (Default_DNS);
      Timeout    : Duration := 5.0) return Boolean
   with Pre => Name'Length > 0;

end Net_Resolver;
