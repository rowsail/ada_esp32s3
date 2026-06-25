--  DNS lookup over the W5500, using the portable DNS_Client module.
--
--  DNS_Client.Resolve sends a standard A-record query (UDP, over GNAT.Sockets) to a
--  resolver and returns the first IPv4 address from the answer, handling name
--  compression.  The protocol details live in the module
--  (libs/esp32s3_hal/src/dns_client.adb) -- because it is written against
--  GNAT.Sockets it is portable, and any project reuses it with `with DNS_Client;`.
with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Sockets;  use GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;
with DNS_Client;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   DNS_Server : constant Inet_Addr_Type := Inet_Addr ("8.8.8.8");   --  the resolver
   Hostname   : constant String         := "example.com";          --  what to resolve

   Addr : Inet_Addr_Type;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[dns] W5500 DNS lookup (DNS_Client over GNAT.Sockets, UDP)");
   if not W5500_Dev.Bring_Up then
      loop delay until Clock + Seconds (3600); end loop;
   end if;

   Put_Line ("[dns] resolving " & Hostname & " ...");
   if DNS_Client.Resolve (DNS_Server, Hostname, Addr, Timeout => 3.0) then
      Put_Line ("[dns] " & Hostname & " = " & Image (Addr));
   else
      Put_Line ("[dns] no answer (timed out) or no A record");
   end if;

   loop delay until Clock + Seconds (3600); end loop;
end Main;
