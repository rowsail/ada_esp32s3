--  ESP32-S3 Wi-Fi promiscuous sniffer -- a WPA2 ground-truth tool.
--
--  Runs on a SECOND board next to the one under test: brings the radio up,
--  parks on a channel, and decodes the management/EAPOL frames that matter for
--  association (assoc req/resp, auth, deauth, EAPOL-Key).  Point it at the AP's
--  channel, trigger a connect on the other board, and read exactly what the
--  station sends (its RSN IE) and how the AP answers (status / deauth reason).
--
--  Build & run:  ./build.sh + ./flash.sh /dev/ttyACM1
with Interfaces;
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Log;          use ESP32S3.Log;
with ESP32S3.WiFi;         use ESP32S3.WiFi;
with ESP32S3.WiFi.Sniffer;
with ESP32S3.MAC;
with ESP32S3.UART;
with ESP32S3.UART.Text;
with ESP32S3.Serial;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  Runs on the UART-bridge board (/dev/ttyUSB0): route console to UART0.
   Con     : aliased ESP32S3.UART.Session;
   Channel : constant := 7;    --  the target AP's channel (from a scan)
   St      : Status;
begin
   ESP32S3.UART.Acquire (Con, ESP32S3.UART.UART0);
   ESP32S3.Serial.Set_Output (ESP32S3.UART.Text.As_Device (Con));

   Put_Line ("");
   Put_Line ("=== ESP32-S3 Wi-Fi sniffer ===");

   Put ("Initialize ... ");
   Initialize (St);
   if St /= OK then
      Put_Line ("FAILED");
      loop
         delay until Clock + Milliseconds (1000);
      end loop;
   end if;
   Put_Line ("OK");

   declare
      M : constant ESP32S3.MAC.MAC_Address := ESP32S3.MAC.Wi_Fi_Station;
   begin
      Put ("sniffer MAC ");
      for I in M'Range loop
         Put_Hex (Interfaces.Unsigned_32 (M (I)), 2);
         if I < M'Last then Put (":"); end if;
      end loop;
      New_Line;
   end;

   ESP32S3.WiFi.Sniffer.Start (Channel, St);
   Put_Line ((if St = OK then "sniffing (hopping 1/6/11) ..." else "FAILED"));

   --  Filter the data-frame census to the RED2 vAP (BSSID 3a:32:74:f2:36:02):
   --  print + raw-dump every payload data frame to/from it, so we can capture
   --  the AP's encrypted group frames and decrypt them offline with our GTK.
   ESP32S3.WiFi.Sniffer.Watch_Beacon
     ((16#3A#, 16#32#, 16#74#, 16#F2#, 16#36#, 16#02#));
   --  Also any frame involving the TX board's station MAC (28:84:85:48:83:10).
   ESP32S3.WiFi.Sniffer.Watch_Sta
     ((16#28#, 16#84#, 16#85#, 16#48#, 16#83#, 16#10#));

   --  Hop the 2.4 GHz non-overlapping channels so we catch the station's
   --  assoc/deauth whichever BSSID the station picks.  Frames are decoded
   --  and printed from the promiscuous callback between these hop markers.
   --  Parked on channel 6 (the target AP's channel) for this diagnosis.
   ESP32S3.WiFi.Sniffer.Set_Channel (7);
   loop
      delay until Clock + Milliseconds (2000);
   end loop;
end Main;
