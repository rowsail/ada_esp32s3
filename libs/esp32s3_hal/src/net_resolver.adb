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

      --  Ask the caller's nameserver ourselves, over UDP, through the facade.
      if DNS_Client.Resolve (DNS_Server, Name, Addr, Timeout => Timeout) then
         return True;
      end if;

      --  Then a resolver that does NOT listen on port 53.  Measured on
      --  cellular (1NCE Cat-M1): stretches where every port-53 query is
      --  swallowed -- by whatever intercepts DNS in the carrier core --
      --  regardless of source port or nameserver, while the same query to
      --  OpenDNS on 443 answers at once.  A fallback that shares the port
      --  shares the fate, so this one deliberately does not.
      return DNS_Client.Resolve
        (GNAT.Sockets.Inet_Addr (Fallback_DNS), Name, Addr,
         Timeout => Timeout, Server_Port => 443);
   end Resolve;

end Net_Resolver;
