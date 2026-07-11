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

      --  Ask a nameserver ourselves, over UDP, through the facade.
      return DNS_Client.Resolve (DNS_Server, Name, Addr, Timeout => Timeout);
   end Resolve;

end Net_Resolver;
