--  ESP32-S3 Wi-Fi HTTP fetch over a pure-Ada software TCP stack.
--
--  What it does: associates to the Wi-Fi network in Wifi_Credentials, brings up
--  the pure-Ada IPv4/ARP/UDP/TCP engine (ESP32S3.WiFi.IP), gets an address by
--  DHCP, resolves a hostname, then opens a TCP connection through the standard
--  GNAT.Sockets facade and fetches "/" over HTTP -- proving the whole TCP path
--  (SYN handshake, reliable send, in-order receive, FIN close) on the radio,
--  with no offloaded TCP/IP stack.
--
--  Build & run:  ./build.sh + ./flash.sh /dev/ttyUSB0.  First copy
--  src/wifi_credentials.ads.template to src/wifi_credentials.ads and fill in
--  your network (that file is git-ignored).
--
--  Output: association, "DHCP ... IP=...", "resolved <host> = a.b.c.d",
--  "connect ... OK", then the HTTP response and a byte count.
--
--  Hardware: none beyond the board; console on UART0.
with Interfaces;
with Ada.Streams;    use Ada.Streams;
with Ada.Real_Time;  use Ada.Real_Time;
with Wifi_Credentials;
with ESP32S3.Log;    use ESP32S3.Log;
with ESP32S3.WiFi;   use ESP32S3.WiFi;
with ESP32S3.WiFi.IP;
with ESP32S3.WiFi.DHCP;
with ESP32S3.WiFi.Net_Device;
with ESP32S3.UART;
with ESP32S3.UART.Text;
with ESP32S3.Serial;
with GNAT.Sockets;   use GNAT.Sockets;
with DNS_Client;
with Net_Devices;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   Con          : aliased ESP32S3.UART.Session;
   St           : Status;
   Target_BSSID : constant MAC_Address := MAC_Address (Wifi_Credentials.BSSID);
   Host         : constant String := "example.com";
   HTTP_Port    : constant := 80;

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
   Put_Line ("=== ESP32-S3 Wi-Fi HTTP (pure-Ada TCP stack) ===");

   Put ("Initialize ... ");
   Initialize (St);
   if St /= OK then
      Put_Line ("FAILED");
      loop
         delay until Clock + Seconds (1);
      end loop;
   end if;
   Put_Line ("OK");

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
   Put (ESP32S3.WiFi.Current_Channel); Put_Line (")");

   ESP32S3.WiFi.IP.Start;
   Put ("DHCP ... ");
   declare
      Lease : ESP32S3.WiFi.DHCP.Lease;
   begin
      if not ESP32S3.WiFi.DHCP.Acquire (0, Lease, Tries => 40) then
         Put_Line ("FAILED");
         loop
            delay until Clock + Seconds (1);
         end loop;
      end if;
      Put ("IP=");   Put_IP (Lease.Addr);
      Put (" gw=");  Put_IP (Lease.Gateway);
      Put (" dns="); Put_IP (Lease.DNS);
      New_Line;

      ESP32S3.WiFi.Net_Device.Register_Default;

      declare
         DNS_Srv : constant GNAT.Sockets.Inet_Addr_Type :=
           GNAT.Sockets.Inet_Addr (Net_Devices.IPv4_Address (Lease.DNS));
         Server  : GNAT.Sockets.Inet_Addr_Type;
      begin
         Put ("resolve " & Host & " ... ");
         declare
            Resolved : Boolean := False;
         begin
            for Attempt in 1 .. 5 loop
               Resolved := DNS_Client.Resolve (DNS_Srv, Host, Server,
                                               Timeout => 5.0);
               exit when Resolved;
            end loop;
            if not Resolved then
               Put_Line ("FAILED");
               loop
                  delay until Clock + Seconds (1);
               end loop;
            end if;
         end;
         Put_Line (GNAT.Sockets.Image (Server));

         --  Fetch "/" over HTTP through the GNAT.Sockets facade (software TCP).
         declare
            Sock  : Socket_Type;
            CRLF  : constant String := (Character'Val (13), Character'Val (10));
            Req   : constant String :=
              "GET / HTTP/1.0" & CRLF & "Host: " & Host & CRLF &
              "Connection: close" & CRLF & CRLF;
            Req_B : Stream_Element_Array (1 .. Req'Length);
            SLast : Stream_Element_Offset;
            Buf   : Stream_Element_Array (1 .. 512);
            Last  : Stream_Element_Offset;
            Total : Natural := 0;
         begin
            for I in Req'Range loop
               Req_B (Stream_Element_Offset (I - Req'First + 1)) :=
                 Stream_Element (Character'Pos (Req (I)));
            end loop;

            Create_Socket (Sock, Family_Inet, Socket_Stream);
            Set_Socket_Option
              (Sock, Socket_Level, (Receive_Timeout, Timeout => 10.0));
            Put ("connect " & Host & " ... ");
            Connect_Socket (Sock, (Family_Inet, Server, HTTP_Port));
            Put_Line ("OK");

            Send_Socket (Sock, Req_B, SLast);
            Put_Line ("--- response ---");
            loop
               begin
                  Receive_Socket (Sock, Buf, Last);
               exception
                  when Socket_Error =>
                     exit;                       --  timeout or reset
               end;
               exit when Last < Buf'First;       --  peer closed (end of stream)
               declare
                  S : String (1 .. Natural (Last - Buf'First + 1));
               begin
                  for I in S'Range loop
                     S (I) := Character'Val
                       (Buf (Buf'First + Stream_Element_Offset (I - 1)));
                  end loop;
                  Put (S);
               end;
               Total := Total + Natural (Last - Buf'First + 1);
            end loop;
            New_Line;
            Put_Line ("--- end ---");
            Put ("total bytes = "); Put (Total); New_Line;
            Close_Socket (Sock);
         end;
      end;
   end;

   loop
      delay until Clock + Seconds (1);
   end loop;
end Main;
