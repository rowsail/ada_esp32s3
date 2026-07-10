with Net_Devices;
with DNS_Client;

package body Net_Resolver is

   use type GNAT.Sockets.Inet_Addr_Type;
   use type Net_Devices.Device_Access;

   function Method_For
     (DNS_Server : GNAT.Sockets.Inet_Addr_Type := GNAT.Sockets.Inet_Addr (Default_DNS))
      return Method
   is
      Dev : constant Net_Devices.Device_Access := GNAT.Sockets.Device_For (DNS_Server);
   begin
      if Dev = null then
         return No_Route;
      elsif Dev.all in Net_Devices.Name_Resolver'Class then
         return Device_Resolver;
      else
         return DNS_Query;
      end if;
   end Method_For;

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

      --  The device carries its own resolver: use it, and never open a socket.
      --  The class-wide view conversion dispatches to the device's Resolve_Host.
      if Dev.all in Net_Devices.Name_Resolver'Class then
         declare
            IP : Net_Devices.IPv4_Address;
            Ok : Boolean;
         begin
            Net_Devices.Name_Resolver'Class (Dev.all).Resolve_Host (Name, IP, Ok);
            if not Ok then
               return False;
            end if;
            Addr := GNAT.Sockets.Inet_Addr (IP);
            return True;
         end;
      end if;

      --  Otherwise ask a nameserver ourselves, over UDP, through the facade.
      return DNS_Client.Resolve (DNS_Server, Name, Addr, Timeout => Timeout);
   end Resolve;

end Net_Resolver;
