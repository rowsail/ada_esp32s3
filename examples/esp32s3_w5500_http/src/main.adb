--  What it demonstrates
--  ---------------------
--  An HTTP GET *client* over the WIZnet W5500 Ethernet controller, driven
--  through the GNAT.Sockets facade (a TCP stream socket).  It connects out to a
--  web server, sends "GET / HTTP/1.0", and prints the response until the server
--  closes.  This exercises the TCP client path (Connect_Socket / Send_Socket /
--  Receive_Socket) that the W5500 echo server example -- a TCP *server* -- never
--  touches.
--
--  Build & run
--  -----------
--    ./x run esp32s3_w5500_http
--  This example uses the IDF-free bare boot; build.sh sets the embedded runtime
--  profile (ESP32S3_RTS_PROFILE=embedded), not the default light-tasking one.
--
--  How to read the output
--  ----------------------
--  On the console you should see, in order:
--    [http] W5500 HTTP GET client (GNAT.Sockets, TCP)
--    [w5500] link up, IP 192.168.1.50         (or "link DOWN ..." if no cable)
--    [http] connecting to 192.168.1.100:8000 ...
--    [http] --- response ---
--    ... the raw HTTP response (status line, headers, body) ...
--    [http] --- done ---
--  If the W5500 is not found the run prints "[w5500] not found ..." and then
--  idles forever (it never reaches the connect step).
--
--  Hardware / wiring
--  -----------------
--  A WIZnet W5500 SPI Ethernet module on SPI2.  Pins (set in w5500_dev.adb):
--    SCLK = GPIO1, MOSI = GPIO4, MISO = GPIO45, CS = GPIO39,
--    RST  = GPIO11, INT = GPIO3, SPI clock 10 MHz.
--  Network: the board takes the static IP 192.168.1.50 (gateway .254, /24);
--  there is no DHCP here, so put the board and the server on the same subnet.
--  Point Server_IP below at a host on that LAN that is serving HTTP on port
--  8000, e.g. run  python3 -m http.server 8000  on it.
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Streams;   use Ada.Streams;
with GNAT.Sockets;  use GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  The HTTP server to fetch from.  This is on the same /24 as the board's
   --  static IP (192.168.1.50, set in w5500_dev.adb); edit both for your LAN.
   Server_IP : constant String := "192.168.1.100";

   --  TCP port the server listens on (matches  python3 -m http.server 8000).
   Server_Port : constant Port_Type := 8000;

   --  Resource to request.  "/" is the server root.
   Path : constant String := "/";

   --  Receive scratch: read the response in chunks of this many bytes.  The
   --  server may send more than one chunk; we loop until it closes.
   Receive_Buffer_Bytes : constant := 512;

   Sock  : Socket_Type;
   Buf   : Stream_Element_Array (1 .. Receive_Buffer_Bytes);
   Last  : Stream_Element_Offset;   --  index of the last byte received this read
   SLast : Stream_Element_Offset;   --  index of the last byte the send consumed

   --  Pause after boot to let the console settle before the first line prints.
   Startup_Settle : constant Time_Span := Milliseconds (200);

   --  Park interval: once the run is over (or failed) we have nothing left to
   --  do, so we sleep in long blocks rather than busy-wait forever.
   Park_Interval : constant Time_Span := Seconds (3600);   --  one hour

   --  SEA == Stream_Element_Array (the byte type GNAT.Sockets sends/receives).
   --  To_SEA converts an Ada String to that byte array for Send_Socket.
   function To_SEA (S : String) return Stream_Element_Array is
      R : Stream_Element_Array (1 .. S'Length);
   begin
      for I in S'Range loop
         R (Stream_Element_Offset (I - S'First) + 1) := Character'Pos (S (I));
      end loop;
      return R;
   end To_SEA;

   --  Print a received byte array to the console as raw characters.
   procedure Put_SEA (B : Stream_Element_Array) is
   begin
      for E of B loop
         Put (Character'Val (Integer (E)));
      end loop;
   end Put_SEA;

   Request : constant String :=
     "GET " & Path & " HTTP/1.0" & ASCII.CR & ASCII.LF &
     "Host: " & Server_IP & ASCII.CR & ASCII.LF &
     "Connection: close" & ASCII.CR & ASCII.LF &
     ASCII.CR & ASCII.LF;
begin
   delay until Clock + Startup_Settle;
   Put_Line ("[http] W5500 HTTP GET client (GNAT.Sockets, TCP)");

   --  Bring up SPI + reset the W5500 + apply the static IP.  If the chip is not
   --  found there is nothing to do, so park forever.
   if not W5500_Dev.Bring_Up then
      loop
         delay until Clock + Park_Interval;
      end loop;
   end if;

   Create_Socket  (Sock, Family_Inet, Socket_Stream);
   Put_Line ("[http] connecting to " & Server_IP & ":8000 ...");
   Connect_Socket (Sock, (Family_Inet, Inet_Addr (Server_IP), Server_Port));
   Send_Socket    (Sock, To_SEA (Request), SLast);

   Put_Line ("[http] --- response ---");
   loop
      Receive_Socket (Sock, Buf, Last);
      exit when Last < Buf'First;          --  server closed the connection
      Put_SEA (Buf (Buf'First .. Last));
   end loop;
   New_Line;
   Put_Line ("[http] --- done ---");

   Close_Socket (Sock);

   --  Run is complete; nothing more to do, so park forever.
   loop
      delay until Clock + Park_Interval;
   end loop;
end Main;
