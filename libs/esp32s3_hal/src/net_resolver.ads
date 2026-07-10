with GNAT.Sockets;

--  One way to turn a host name into an address, whatever is carrying the traffic.
--
--  Two mechanisms exist, and which one is right depends on the interface:
--
--   * Some devices resolve names themselves.  A cellular modem asks the
--     network's DNS for you (AT+QIDNSGIP), using the nameserver the operator
--     handed it with the PDP context.  You never name a server, and no UDP
--     socket is opened.
--
--   * Everything else needs a DNS query of our own: a UDP A-record request to a
--     nameserver, which is what DNS_Client does over GNAT.Sockets.
--
--  Resolve picks.  It asks the routing table which device would carry traffic to
--  the nameserver, tests whether that device implements Net_Devices.Name_Resolver,
--  and uses the device's own resolver if so.  Otherwise it falls back to
--  DNS_Client.  Callers write one line and stop caring:
--
--     if Net_Resolver.Resolve ("api.open-meteo.com", Addr) then ...
--
--  The fallback still needs a nameserver to ask, hence DNS_Server -- which is
--  simply ignored on a device that has its own resolver.

package Net_Resolver is

   --  A public resolver, used only by the DNS_Client fallback.
   Default_DNS : constant String := "8.8.8.8";

   --  True with Addr set on success.  On failure Addr is Any_Inet_Addr, matching
   --  DNS_Client's contract.
   function Resolve
     (Name       : String;
      Addr       : out GNAT.Sockets.Inet_Addr_Type;
      DNS_Server : GNAT.Sockets.Inet_Addr_Type := GNAT.Sockets.Inet_Addr (Default_DNS);
      Timeout    : Duration := 5.0) return Boolean
   with Pre => Name'Length > 0;

   --  Which way would Resolve go for this nameserver?  Exposed so an application
   --  (or a test) can report the path it took rather than guess.
   type Method is (Device_Resolver, DNS_Query, No_Route);

   function Method_For
     (DNS_Server : GNAT.Sockets.Inet_Addr_Type := GNAT.Sockets.Inet_Addr (Default_DNS))
      return Method;

end Net_Resolver;
