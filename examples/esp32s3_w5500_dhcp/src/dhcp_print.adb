with Interfaces;
use type Interfaces.Unsigned_32;
with ESP32S3.W5500;
with ESP32S3.Log; use ESP32S3.Log;

package body DHCP_Print is
   --  Print an IPv4 address in dotted-decimal form, e.g. "192.168.1.50".
   procedure Put_IP (Address : ESP32S3.W5500.IPv4_Address) is
   begin
      for I in Address'Range loop
         Put (Integer (Address (I)));
         if I < Address'Last then
            Put (".");
         end if;
      end loop;
   end Put_IP;

   procedure On_Bound (Lease : ESP32S3.W5500.DHCP.Lease_Info) is
   begin
      Put ("[dhcp] bound: IP ");
      Put_IP (Lease.IP);
      Put (" mask ");
      Put_IP (Lease.Subnet);
      Put (" gw ");
      Put_IP (Lease.Gateway);
      Put (" dns ");
      Put_IP (Lease.DNS);
      Put (" lease ");
      --  Lease_Seconds is a full Unsigned_32; DHCP's infinite lease is 0xFFFFFFFF
      --  (RFC 2131).  Print it as an unsigned value -- `Integer (Lease_Seconds)`
      --  raised Constraint_Error for any lease above Integer'Last (2^31-1),
      --  including the infinite lease, crashing this bind callback.
      if Lease.Lease_Seconds = 16#FFFF_FFFF# then
         Put_Line ("infinite (0xFFFFFFFF)");
      else
         Put_Unsigned (Lease.Lease_Seconds);
         Put_Line (" s");
      end if;
   end On_Bound;
end DHCP_Print;
