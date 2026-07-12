with Net_Devices;
with DNS_Client;

package body Net_Resolver is

   use type Net_Devices.Device_Access;

   function Resolve
     (Name       : String;
      Addr       : out GNAT.Sockets.Inet_Addr_Type;
      DNS_Server : GNAT.Sockets.Inet_Addr_Type := GNAT.Sockets.Inet_Addr (Default_DNS);
      Timeout    : Duration := 5.0) return Boolean
   is
      Dev : constant Net_Devices.Device_Access := GNAT.Sockets.Device_For (DNS_Server);
   begin
      Addr := GNAT.Sockets.Any_Inet_Addr;

      if Dev = null then
         return False;                       --  nothing live can reach a resolver
      end if;

      --  The ladder.  Each rung dodges a failure mode the one above it was
      --  measured to have, on a real carrier:
      --
      --   1. UDP to the caller's nameserver on 53 -- the cheap common case.
      --   2. UDP to a resolver that does NOT listen on 53 (OpenDNS on 443):
      --      rides out an interceptor that swallows port-53 traffic
      --      regardless of source port or nameserver.
      --   3. TCP on 53 -- DNS's own designed escape hatch (RFC 7766), for
      --      the stretches where EVERY UDP form is dead while TCP flows.
      --      A handshake per lookup, so it is the last rung, not the first.
      if DNS_Client.Resolve (DNS_Server, Name, Addr, Timeout => Timeout) then
         return True;
      end if;
      if DNS_Client.Resolve
        (GNAT.Sockets.Inet_Addr (Fallback_DNS), Name, Addr,
         Timeout => Timeout, Server_Port => 443)
      then
         return True;
      end if;
      return DNS_Client.Resolve_TCP (DNS_Server, Name, Addr, Timeout => Timeout);
   end Resolve;

end Net_Resolver;
