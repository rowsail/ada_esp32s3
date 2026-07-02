--  What it demonstrates
--  ---------------------
--  A DNS name lookup over the W5500 Ethernet chip, using the portable
--  DNS_Client module.  DNS_Client.Resolve sends a standard A-record query
--  (UDP, over GNAT.Sockets) to a resolver and returns the first IPv4 address
--  from the answer, handling DNS name compression.  The protocol details live
--  in the module (libs/esp32s3_hal/src/dns_client.adb) -- because it is written
--  against GNAT.Sockets it is portable, and any project reuses it with
--  `with DNS_Client;`.
--
--  Build & run
--  -----------
--    ./x run esp32s3_w5500_dns
--  Needs the embedded runtime profile; build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  How to read the output
--  ----------------------
--  Over the console you should see, in order:
--    [dns] W5500 DNS lookup (DNS_Client over GNAT.Sockets, UDP)
--    [w5500] link up, IP 192.168.1.50
--    [dns] resolving example.com ...
--    [dns] example.com = <some IPv4 address>
--  The final line is the answer from the resolver (the address example.com
--  currently maps to).  Failure paths instead print "[w5500] not found ..." /
--  "[w5500] link DOWN ..." (wiring/cable), or "[dns] no answer (timed out) ..."
--  if the query gets no A record back within the timeout.
--
--  Hardware / wiring
--  -----------------
--  A WIZnet W5500 Ethernet module on SPI2, wired (S3 GPIO -> W5500 pin) per
--  W5500_Dev (src/w5500_dev.adb): SCLK=1, MOSI=4, MISO=45, CS=39, RST=11,
--  INT=3, at 10 MHz.  Plug the module into your LAN with a live cable.
--  The board takes the static IP 192.168.1.50 (gateway .254); edit those, and
--  the SPI pins, in src/w5500_dev.adb to match your own network and wiring.
with Ada.Real_Time; use Ada.Real_Time;
with GNAT.Sockets;  use GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;
with DNS_Client;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  The recursive resolver to query: Google Public DNS at 8.8.8.8.
   DNS_Server : constant Inet_Addr_Type := Inet_Addr ("8.8.8.8");

   --  The hostname to resolve to an IPv4 (A-record) address.
   Hostname : constant String := "example.com";

   --  Seconds to wait for the resolver's reply before giving up.
   Resolve_Timeout : constant Duration := 3.0;

   --  Let the W5500's power-on reset settle before we drive it.
   Reset_Settle : constant Time_Span := Milliseconds (200);

   --  When done (or wedged), park the task instead of returning.
   Park_Interval : constant Time_Span := Seconds (3600);

   Addr : Inet_Addr_Type;   --  the resolved address, filled in on success
begin
   delay until Clock + Reset_Settle;
   Put_Line ("[dns] W5500 DNS lookup (DNS_Client over GNAT.Sockets, UDP)");
   if not W5500_Dev.Bring_Up then
      --  No chip / no link: nothing to do, so park here forever.
      loop
         delay until Clock + Park_Interval;
      end loop;
   end if;

   Put_Line ("[dns] resolving " & Hostname & " ...");
   if DNS_Client.Resolve (DNS_Server, Hostname, Addr, Timeout => Resolve_Timeout) then
      Put_Line ("[dns] " & Hostname & " = " & Image (Addr));
   else
      Put_Line ("[dns] no answer (timed out) or no A record");
   end if;

   --  Done -- park the task (the example has no further work).
   loop
      delay until Clock + Park_Interval;
   end loop;
end Main;
