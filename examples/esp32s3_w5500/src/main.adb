--  WIZnet W5500 TCP echo server on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ============================================================================
--  What it demonstrates
--    The whole W5500 Ethernet stack exercised end to end, then ordinary sockets
--    on top.  The chip bring-up is W5500-specific (the SPI transport
--    ESP32S3.W5500, the socket engine ESP32S3.W5500.Sockets, and the INTn
--    interrupt path ESP32S3.W5500.Interrupts), but once the chip is registered
--    as the default network interface the echo loop is just
--    Create/Bind/Listen/Accept/Receive/Send/Close -- the same standard
--    GNAT.Sockets code you would write on a desktop.
--
--    Unlike the client examples (http/ntp/dns/weather), which hide the bring-up
--    in a W5500_Dev package and so keep Main portable GNAT.Sockets, this one
--    inlines the bring-up and interrupt arming on purpose: it is the "whole
--    stack in one file" example.  The echo loop itself is still portable.
--
--  Build & run
--    ./x run esp32s3_w5500
--    Needs the embedded (or full) profile: the W5500 driver uses a controlled
--    SPI Session, which the default light-tasking profile does not provide.
--    build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  Output (over the serial console)
--    [w5500] WIZnet W5500 GNAT.Sockets echo server
--    [w5500] VERSIONR = 0x04  (W5500 present)        <- 0x04 is the chip's
--                                                       fixed version byte; any
--                                                       other value prints
--                                                       "(unexpected -- check
--                                                       wiring!)" and the demo
--                                                       parks forever
--    [w5500] IP = 192.168.1.50
--    [w5500] link up                                 <- or "link down" if the
--                                                       PHY never negotiated
--    [w5500] interrupts armed (INTn=IO3)             <- or "polling" if INTn
--                                                       could not be armed
--    [w5500] GNAT.Sockets TCP echo on 192.168.1.50:5000  (try:  nc 192.168.1.50 5000)
--    [w5500] client 192.168.1.x                      <- per connection
--    [w5500] client disconnected
--
--  Hardware / wiring (ESP32-S3 <-> W5500, SPI2)
--    SCLK = IO1    MOSI = IO4    MISO = IO45    SCSn (chip-select) = IO39
--    RSTn = IO11 (active-low reset, pulled up)   INTn = IO3 (active-low, pulled up)
--    SPI clock 10 MHz.  Static network setup (no DHCP):
--      MAC 00:08:DC:01:02:03   IP 192.168.1.50   mask 255.255.255.0   gw 192.168.1.1
--    Put the host on the same LAN and try:  nc 192.168.1.50 5000
with Interfaces;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Streams;   use Ada.Streams;

with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.W5500.Interrupts;
with ESP32S3.W5500.Net_Device;
with GNAT.Sockets;  use GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;
with W5500_Dev;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the demo runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package Net  renames ESP32S3.W5500;
   package Ints renames ESP32S3.W5500.Interrupts;
   use type Net.Link_State;

   Dev : Net.Device renames W5500_Dev.Dev;   --  the library-level, aliased W5500
   Ok  : Boolean;

   --  ESP32-S3 SPI2 pins routed to the W5500 (see the header for the wiring).
   Sclk_Pin         : constant := 1;    --  SPI clock          -> W5500 SCLK
   Mosi_Pin         : constant := 4;    --  master out         -> W5500 MOSI
   Miso_Pin         : constant := 45;   --  master in          <- W5500 MISO
   Chip_Select_Pin  : constant := 39;   --  chip select (SCSn), driven per frame
   Reset_Pin        : constant := 11;   --  RSTn, active-low, externally pulled up
   Interrupt_Pin    : constant := 3;    --  INTn, active-low, externally pulled up
   SPI_Clock_Hz     : constant := 10_000_000;   --  10 MHz SPI bus to the W5500

   --  Static network identity for this node (no DHCP in the echo demo).
   My_MAC     : constant Net.MAC_Address  := (16#00#, 16#08#, 16#DC#,
                                              16#01#, 16#02#, 16#03#);
   My_IP      : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 50);
   My_Subnet  : constant Net.IPv4_Address := Net.IPv4 (255, 255, 255, 0);
   My_Gateway : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 1);

   Echo_Port  : constant Port_Type := 5000;   --  TCP port the echo server listens on

   --  Bring-up timing.
   Console_Settle      : constant Time_Span := Milliseconds (200);  --  let UART drain
   Link_Poll_Attempts  : constant := 20;                  --  PHY auto-neg takes ~secs
   Link_Poll_Interval  : constant Time_Span := Milliseconds (250); --  between checks
   Park_Interval       : constant Time_Span := Seconds (3600);  --  idle wait when no chip

   Server, Client : Socket_Type;
   Peer           : Sock_Addr_Type;
   Buf            : Stream_Element_Array (1 .. 512);   --  per-pass echo buffer (bytes)
   Last, SLast    : Stream_Element_Offset;

   procedure Put_IP (A : Net.IPv4_Address) is
   begin
      for I in A'Range loop
         Put (Integer (A (I)));
         if I < A'Last then
            Put (".");                          --  dot between octets, not after the last
         end if;
      end loop;
   end Put_IP;
begin
   delay until Clock + Console_Settle;        --  let the console settle
   Put_Line ("[w5500] WIZnet W5500 GNAT.Sockets echo server");

   --  Bring the chip up (this part is W5500-specific).
   Net.Setup (Dev, Sclk => Sclk_Pin, Mosi => Mosi_Pin, Miso => Miso_Pin,
              Cs => Chip_Select_Pin, Rst => Reset_Pin, Int => Interrupt_Pin,
              Host => ESP32S3.SPI.SPI2, Clock_Hz => SPI_Clock_Hz);
   Net.Reset (Dev, Ok);
   Put ("[w5500] VERSIONR = 0x");
   Put_Hex (Interfaces.Unsigned_32 (Net.Version (Dev)), 2);
   Put_Line (if Ok then "  (W5500 present)" else "  (unexpected -- check wiring!)");
   if not Ok then
      loop
         delay until Clock + Park_Interval;   --  no chip: park instead of looping hot
      end loop;
   end if;
   Net.Configure (Dev, MAC => My_MAC, IP => My_IP,
                  Subnet => My_Subnet, Gateway => My_Gateway);
   Put ("[w5500] IP = ");
   Put_IP (Net.Get_IP (Dev));
   New_Line;

   for Try in 1 .. Link_Poll_Attempts loop    --  PHY auto-neg takes ~secs
      exit when Net.Link (Dev) = Net.Up;
      delay until Clock + Link_Poll_Interval;
   end loop;
   Put_Line (if Net.Link (Dev) = Net.Up then "[w5500] link up" else "[w5500] link down");
   Ints.Enable (Dev);                         --  sleep on INTn, not poll
   Put_Line (if Ints.Armed then "[w5500] interrupts armed (INTn=IO3)"
                           else "[w5500] polling");

   --  Register the chip as a network interface; from here it is ordinary
   --  GNAT.Sockets code.
   ESP32S3.W5500.Net_Device.Register_Default (Dev'Access);
   Put_Line ("[w5500] GNAT.Sockets TCP echo on 192.168.1.50:5000"
             & "  (try:  nc 192.168.1.50 5000)");

   loop
      Create_Socket (Server, Family_Inet, Socket_Stream);
      Bind_Socket   (Server, (Family => Family_Inet,
                              Addr   => Any_Inet_Addr, Port => Echo_Port));
      Listen_Socket (Server);

      Accept_Socket (Server, Client, Peer);    --  blocks (on INTn) for a client
      Put ("[w5500] client ");
      Put_Line (Image (Peer.Addr));

      loop
         Receive_Socket (Client, Buf, Last);   --  blocks (on INTn) for data
         exit when Last < Buf'First;           --  peer closed the connection
         Send_Socket (Client, Buf (Buf'First .. Last), SLast);   --  echo it back
      end loop;

      Put_Line ("[w5500] client disconnected");
      Close_Socket (Client);
   end loop;
end Main;
