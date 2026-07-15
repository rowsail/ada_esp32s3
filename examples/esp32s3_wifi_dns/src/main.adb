--  ESP32-S3 Wi-Fi DNS over a pure-Ada software IP stack.
--
--  What it does: associates to the Wi-Fi network in Wifi_Credentials, brings up
--  the pure-Ada IPv4/ARP/UDP engine (ESP32S3.WiFi.IP), gets an address by DHCP,
--  registers the Wi-Fi link as a Net_Devices.Device NIC, and then resolves a
--  hostname with the chip-neutral DNS_Client over GNAT.Sockets -- proving the
--  whole UDP path (Ethernet -> ARP -> IP -> UDP -> DHCP/DNS) end to end on the
--  radio, with no offloaded TCP/IP stack.
--
--  Build & run:  ./build.sh + ./flash.sh /dev/ttyUSB0.  First copy
--  src/wifi_credentials.ads.template to src/wifi_credentials.ads and fill in
--  your network (that file is git-ignored).
--
--  Output: "DHCP ... IP=... gw=... dns=..." then repeatedly
--  "resolve api.open-meteo.com ... <a.b.c.d>".
--
--  Hardware: none beyond the board; console on UART0.
with Interfaces;
with System;
with Ada.Real_Time; use Ada.Real_Time;
with Wifi_Credentials;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.WiFi;  use ESP32S3.WiFi;
with ESP32S3.WiFi.IP;
with ESP32S3.WiFi.DHCP;
with ESP32S3.WiFi.Net_Device;
with ESP32S3.UART;
with ESP32S3.UART.Text;
with ESP32S3.Serial;
with GNAT.Sockets;
with DNS_Client;
with Net_Devices;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   Con          : aliased ESP32S3.UART.Session;
   St           : Status;
   Target_BSSID : constant MAC_Address := MAC_Address (Wifi_Credentials.BSSID);

   procedure Put_IP (A : ESP32S3.WiFi.IP.IPv4) is
   begin
      for I in A'Range loop
         Put (Integer (A (I)));
         if I < A'Last then
            Put (".");
         end if;
      end loop;
   end Put_IP;
begin
   ESP32S3.UART.Acquire (Con, ESP32S3.UART.UART0);
   ESP32S3.Serial.Set_Output (ESP32S3.UART.Text.As_Device (Con));

   Put_Line ("");
   Put_Line ("=== ESP32-S3 Wi-Fi DNS (pure-Ada IP stack) ===");

   Put ("Initialize ... ");
   Initialize (St);
   if St /= OK then
      Put_Line ("FAILED");
      loop
         delay until Clock + Seconds (1);
      end loop;
   end if;
   Put_Line ("OK");

   --  Associate and wait for the WPA2 4-way handshake to actually COMPLETE
   --  (the EAPOL tx-done callback fired = keys installed + port authorised);
   --  Connected alone turns true at association, before the handshake finishes.
   Put_Line ("Connecting to '" & Wifi_Credentials.SSID & "' ...");
   loop
      Connect (Wifi_Credentials.SSID, Wifi_Credentials.Pass,
               BSSID => Target_BSSID, Result => St);
      for I in 1 .. 100 loop
         exit when Connected
           and then ESP32S3.WiFi.Handshake_Txdone_Count > 0;
         delay until Clock + Milliseconds (100);
      end loop;
      exit when Connected
        and then ESP32S3.WiFi.Handshake_Txdone_Count > 0;
      Put_Line ("  retry (handshake incomplete) ...");
   end loop;
   Put ("  associated (channel ");
   Put (ESP32S3.WiFi.Current_Channel); Put (") BSSID ");
   declare
      B : constant MAC_Address := ESP32S3.WiFi.Current_BSSID;
   begin
      for I in B'Range loop
         Put_Hex (Interfaces.Unsigned_32 (B (I)), 2);
         if I < B'Last then Put (":"); end if;
      end loop;
   end;
   New_Line;

   --  Bring up the software IP stack and get an address by DHCP.
   ESP32S3.WiFi.IP.Start;
   declare
      M : constant ESP32S3.WiFi.IP.MAC := ESP32S3.WiFi.IP.Own_MAC;
   begin
      Put ("our MAC ");
      for I in M'Range loop
         Put_Hex (Interfaces.Unsigned_32 (M (I)), 2);
         if I < M'Last then Put (":"); end if;
      end loop;
      New_Line;
   end;
   Put ("DHCP ... ");
   declare
      Lease : ESP32S3.WiFi.DHCP.Lease;
   begin
      if not ESP32S3.WiFi.DHCP.Acquire (0, Lease, Tries => 40) then
         Put ("FAILED  (rx="); Put (ESP32S3.WiFi.IP.Rx_Frames);
         Put (" tx="); Put (ESP32S3.WiFi.IP.Tx_Frames);
         Put (" drop="); Put (ESP32S3.WiFi.IP.Drop_Frames);
         Put (" txdone="); Put (ESP32S3.WiFi.Handshake_Txdone_Count);
         Put (" ptk_rc="); Put (Integer (ESP32S3.WiFi.Handshake_Ptk_Rc));
         Put_Line (")");
         loop
            delay until Clock + Seconds (1);
         end loop;
      end if;
      Put ("IP=");   Put_IP (Lease.Addr);
      Put (" gw=");  Put_IP (Lease.Gateway);
      Put (" dns="); Put_IP (Lease.DNS);
      New_Line;

      --  Register the Wi-Fi NIC and resolve a name over it with the standard,
      --  chip-neutral DNS client.
      ESP32S3.WiFi.Net_Device.Register_Default;

      declare
         DNS_Srv : constant GNAT.Sockets.Inet_Addr_Type :=
           GNAT.Sockets.Inet_Addr (Net_Devices.IPv4_Address (Lease.DNS));
         Host    : constant String := "api.open-meteo.com";
         Addr    : GNAT.Sockets.Inet_Addr_Type;
      begin
         loop
            Put ("resolve " & Host & " ... ");
            if DNS_Client.Resolve (DNS_Srv, Host, Addr, Timeout => 5.0) then
               Put_Line (GNAT.Sockets.Image (Addr));
            else
               Put_Line ("FAILED");
            end if;
            delay until Clock + Seconds (5);
         end loop;
      end;
   end;
end Main;
