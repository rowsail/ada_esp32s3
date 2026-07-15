--  ESP32-S3 Wi-Fi scan + WPA2 connect, end to end on libs/esp32s3_wifi.
--
--  What it does: brings the radio up (ESP32S3.WiFi.Initialize), lists the access
--  points in range once (Scan), then associates to the AP in Wifi_Credentials
--  and runs the pure-Ada WPA2 4-way handshake (Connect), looping so the link is
--  re-established if it drops.
--
--  Build & run:  ./x run esp32s3_wifi_scan   (or ./build.sh + ./flash.sh).
--  First copy src/wifi_credentials.ads.template to src/wifi_credentials.ads and
--  fill in your network (the real file is git-ignored).
--
--  Output: "found N AP(s):" then one line per AP (SSID / channel / RSSI / auth /
--  BSSID), then "Connecting to AP '<ssid>' ..." and "*** ASSOCIATED ***" once
--  the handshake completes (or "not associated" if it does not).
--
--  Hardware: none beyond the board.  Console is on UART0 (this board is a
--  UART-bridge, not the USB-serial-JTAG); a JTAG board would use the default
--  console instead.
with Interfaces;
with Wifi_Credentials;
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.WiFi;  use ESP32S3.WiFi;
with ESP32S3.UART;
with ESP32S3.UART.Text;
with ESP32S3.Serial;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  This board is wired to a UART bridge (not the USB-serial-JTAG), so route
   --  console output to UART0 (the ROM-console pads) instead of the JTAG console.
   Con : aliased ESP32S3.UART.Session;

   function Auth_Image (A : Auth_Mode) return String is
     (case A is
        when Open            => "OPEN",
        when WEP             => "WEP",
        when WPA_PSK         => "WPA",
        when WPA2_PSK        => "WPA2",
        when WPA_WPA2_PSK    => "WPA/WPA2",
        when WPA2_Enterprise => "WPA2-ENT",
        when WPA3_PSK        => "WPA3",
        when WPA2_WPA3_PSK   => "WPA2/WPA3",
        when others          => "?");

   function Status_Image (S : Status) return String is
     (case S is
        when OK              => "OK",
        when Not_Initialized => "NOT_INITIALIZED",
        when Busy            => "BUSY",
        when Timeout         => "TIMEOUT",
        when Radio_Error     => "RADIO_ERROR");

   St    : Status;
   Found : AP_List (1 .. 20);
   Count : Natural;

   --  AP to associate with -- SSID / password / optional pinned BSSID come from
   --  the (git-ignored) Wifi_Credentials; copy wifi_credentials.ads.template to
   --  wifi_credentials.ads and fill in your own network before building.
   Target_SSID  : constant String := Wifi_Credentials.SSID;
   Target_Pass  : constant String := Wifi_Credentials.Pass;
   Target_BSSID : constant MAC_Address :=
     MAC_Address (Wifi_Credentials.BSSID);
begin
   ESP32S3.UART.Acquire (Con, ESP32S3.UART.UART0);
   ESP32S3.Serial.Set_Output (ESP32S3.UART.Text.As_Device (Con));

   Put_Line ("");
   Put_Line ("=== ESP32-S3 Wi-Fi scan ===");

   Put ("Initialize ... ");
   Initialize (St);
   Put_Line (Status_Image (St));
   if St /= OK then
      Put_Line ("init failed -- radio not up; see which OS-adapter slot halted.");
      loop
         delay until Clock + Seconds (1);
      end loop;
   end if;

   --  M1: one scan to show what is in range.
   Put_Line ("Scanning ...");
   Scan (Found, Count, St);
   if St = OK then
      Put ("  found "); Put (Count); Put_Line (" AP(s):");
      for I in 1 .. Count loop
         declare
            R : AP_Record renames Found (I);
         begin
            Put ("  - ");
            Put (R.SSID (1 .. R.SSID_Len));
            Put ("  ch="); Put (R.Channel);
            Put ("  rssi="); Put (R.RSSI);
            Put ("  "); Put (Auth_Image (R.Auth));
            Put ("  bssid=");
            for K in R.BSSID'Range loop
               Put_Hex (Interfaces.Unsigned_32 (R.BSSID (K)));
               if K < R.BSSID'Last then Put (":"); end if;
            end loop;
            New_Line;
         end;
      end loop;
   else
      Put ("  scan status "); Put_Line (Status_Image (St));
   end if;

   --  M2: associate to an access point.  Retry in a loop so an external
   --  sniffer on the AP's channel gets many chances to capture the exchange.
   --  Target_BSSID pins one AP when several share an SSID with different
   --  security (all-zero in the credentials => strongest match).
   loop
      Put_Line ("Connecting to AP '" & Target_SSID & "' ...");
      Connect (Target_SSID, Target_Pass,
               BSSID  => Target_BSSID,
               Result => St);
      Put ("  connect start: "); Put_Line (Status_Image (St));

      for I in 1 .. 60 loop         --  poll up to ~6 s for association
         exit when Connected;
         delay until Clock + Milliseconds (100);
      end loop;

      Put_Line (if Connected then "*** ASSOCIATED ***" else "not associated");
      delay until Clock + Seconds (4);
   end loop;
end Main;
