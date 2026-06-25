--  WIZnet W5500 TCP echo server on the bare-metal ESP32-S3 (no FreeRTOS, no IDF),
--  written against the standard GNAT.Sockets API.
--
--  The whole W5500 stack is exercised: the SPI transport + bring-up
--  (ESP32S3.W5500), the socket engine (ESP32S3.W5500.Sockets), INTn interrupts
--  (ESP32S3.W5500.Interrupts), and the GNAT.Sockets subset on top -- so the echo
--  server below is just Create/Bind/Listen/Accept/Receive/Send/Close, the same
--  code shape you would write on a desktop.
--
--  Board wiring: MISO=IO45 MOSI=IO4 SCLK=IO1 SCSn=IO39  INTn=IO3(pu) RSTn=IO11(pu).
--  Try it from a host on the same LAN:  nc 192.168.1.50 5000
with Interfaces;
with Ada.Real_Time; use Ada.Real_Time;
with Ada.Streams;   use Ada.Streams;

with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.W5500.Interrupts;
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

   Server, Client : Socket_Type;
   Peer           : Sock_Addr_Type;
   Buf            : Stream_Element_Array (1 .. 512);
   Last, SLast    : Stream_Element_Offset;

   procedure Put_IP (A : Net.IPv4_Address) is
   begin
      for I in A'Range loop
         Put (Integer (A (I)));
         if I < A'Last then Put ("."); end if;
      end loop;
   end Put_IP;

   My_MAC     : constant Net.MAC_Address  := (16#00#, 16#08#, 16#DC#,
                                              16#01#, 16#02#, 16#03#);
   My_IP      : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 50);
   My_Subnet  : constant Net.IPv4_Address := Net.IPv4 (255, 255, 255, 0);
   My_Gateway : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 1);
begin
   delay until Clock + Milliseconds (200);   --  let the console settle
   Put_Line ("[w5500] WIZnet W5500 GNAT.Sockets echo server");

   --  Bring the chip up (this part is W5500-specific).
   Net.Setup (Dev, Sclk => 1, Mosi => 4, Miso => 45, Cs => 39,
              Rst => 11, Int => 3, Host => ESP32S3.SPI.SPI2,
              Clock_Hz => 10_000_000);
   Net.Reset (Dev, Ok);
   Put ("[w5500] VERSIONR = 0x");
   Put_Hex (Interfaces.Unsigned_32 (Net.Version (Dev)), 2);
   Put_Line (if Ok then "  (W5500 present)" else "  (unexpected -- check wiring!)");
   if not Ok then
      loop delay until Clock + Seconds (3600); end loop;
   end if;
   Net.Configure (Dev, MAC => My_MAC, IP => My_IP,
                  Subnet => My_Subnet, Gateway => My_Gateway);
   Put ("[w5500] IP = ");  Put_IP (Net.Get_IP (Dev));  New_Line;

   for Try in 1 .. 20 loop                    --  PHY auto-neg takes ~secs
      exit when Net.Link (Dev) = Net.Up;
      delay until Clock + Milliseconds (250);
   end loop;
   Put_Line (if Net.Link (Dev) = Net.Up then "[w5500] link up" else "[w5500] link down");
   Ints.Enable (Dev);                         --  sleep on INTn, not poll
   Put_Line (if Ints.Armed then "[w5500] interrupts armed (INTn=IO3)"
                           else "[w5500] polling");

   --  Hand the chip to the GNAT.Sockets facade; from here it is ordinary
   --  GNAT.Sockets code.
   GNAT.Sockets.Initialize (Dev'Access);
   Put_Line ("[w5500] GNAT.Sockets TCP echo on 192.168.1.50:5000"
             & "  (try:  nc 192.168.1.50 5000)");

   loop
      Create_Socket (Server, Family_Inet, Socket_Stream);
      Bind_Socket   (Server, (Family => Family_Inet,
                              Addr   => Any_Inet_Addr, Port => 5000));
      Listen_Socket (Server);

      Accept_Socket (Server, Client, Peer);    --  blocks (on INTn) for a client
      Put ("[w5500] client ");  Put_Line (Image (Peer.Addr));

      loop
         Receive_Socket (Client, Buf, Last);   --  blocks (on INTn) for data
         exit when Last < Buf'First;           --  peer closed the connection
         Send_Socket (Client, Buf (Buf'First .. Last), SLast);   --  echo it back
      end loop;

      Put_Line ("[w5500] client disconnected");
      Close_Socket (Client);
   end loop;
end Main;
