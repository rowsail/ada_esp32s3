--  What it demonstrates
--  ---------------------
--  Multiple network interfaces on one board: TWO W5500s, the routing table that
--  chooses between them, and interface pinning.  Interface 0 is the primary
--  (cabled, DHCP).  Interface 1 is a second W5500 that is present on the SPI bus
--  but NOT plugged into a network -- so its PHY link is DOWN.  That makes it the
--  ideal subject: the routing table must avoid it (it is not up), and a socket
--  pinned to it must fail closed.
--
--  Wiring of the second W5500: CS = IO40, INT = IO2, RESET shared with the first
--  on IO11 -- so it is brought up with NO reset pin (Rst => No_Pin) and a SOFTWARE
--  reset (MR.RST), which resets only that chip and leaves the configured primary
--  alone.  Both chips share SPI2 (SCLK=IO1, MOSI=IO4, MISO=IO45); each drives its
--  own CS as a GPIO, so the bus is shared cleanly.
--
--  Build & run
--  -----------
--    ./x run esp32s3_multinic
--  Watch the serial log: it prints each interface's up/down state, the routing
--  decision for a few destinations, and the pin fail-closed result.
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.GPIO;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.W5500.DHCP;
with ESP32S3.W5500.Net_Device;
with ESP32S3.MAC;
with Net_Devices;
with Net_Routes;
with GNAT.Sockets;
with W5500_Dev;
with NICs;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package W5500 renames ESP32S3.W5500;
   package GS renames GNAT.Sockets;
   use type Net_Devices.Interface_Id;
   use type ESP32S3.W5500.Link_State;

   Eth0 : constant Net_Devices.Interface_Id := 0;   --  primary (DHCP, cabled)
   Eth1 : constant Net_Devices.Interface_Id := 1;   --  secondary (not cabled)

   --  A second MAC for the secondary W5500.  The factory block's Ethernet slot is
   --  already used by the primary, so derive a LOCALLY-administered address (base+4
   --  with the local bit set) -- distinct and guaranteed not to clash with a real
   --  one.
   function To_W5500 (M : ESP32S3.MAC.MAC_Address) return W5500.MAC_Address
   is (W5500.Byte (M (0)),
       W5500.Byte (M (1)),
       W5500.Byte (M (2)),
       W5500.Byte (M (3)),
       W5500.Byte (M (4)),
       W5500.Byte (M (5)));
   MAC1 : constant W5500.MAC_Address := To_W5500 (ESP32S3.MAC.Local (ESP32S3.MAC.Derived (4)));

   Lease     : ESP32S3.W5500.DHCP.Lease_Info;
   Have_Eth1 : Boolean := False;
   Ok        : Boolean;
   Park      : constant Time_Span := Seconds (3600);

   function YN (B : Boolean) return String
   is (if B then "yes" else "no");

   --  Print the interface a destination would route out (via the real registry
   --  liveness), or that no live route exists.
   procedure Show_Route (Label : String; A, B, C, D : W5500.Byte) is
      Dest  : constant Net_Devices.IPv4_Address :=
        (Net_Devices.Octet (A),
         Net_Devices.Octet (B),
         Net_Devices.Octet (C),
         Net_Devices.Octet (D));
      Id    : Net_Devices.Interface_Id;
      Found : Boolean;
   begin
      Net_Routes.Resolve (Dest, Id, Found);
      if Found then
         Put_Line ("[nic] route " & Label & " -> eth" & (if Id = Eth0 then "0" else "1"));
      else
         Put_Line ("[nic] route " & Label & " -> NO ROUTE (no live interface)");
      end if;
   end Show_Route;

   --  Try a TCP connect to 1.1.1.1:53 and report; Pin >= 0 pins to that interface.
   procedure Try_Connect (Label : String; Pin : Integer) is
      S : GS.Socket_Type;
   begin
      GS.Create_Socket (S);
      if Pin >= 0 then
         GS.Set_Interface (S, Net_Devices.Interface_Id (Pin));
      end if;
      begin
         GS.Connect_Socket (S, (GS.Family_Inet, GS.Inet_Addr ("1.1.1.1"), 53));
         Put_Line ("[nic] " & Label & " -> CONNECTED");
      exception
         when GS.Socket_Error =>
            Put_Line ("[nic] " & Label & " -> refused / unreachable");
      end;
      GS.Close_Socket (S);
   end Try_Connect;

begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[nic] multi-interface routing demo (two W5500s)");

   --  1. Primary interface via DHCP.  This also does the shared IO11 hardware
   --  reset (resetting both chips once); it registers as interface 0.
   if not W5500_Dev.Bring_Up (Lease => Lease) then
      Put_Line ("[nic] primary interface failed -- stopping");
      loop
         delay until Clock + Park;
      end loop;
   end if;

   --  2. Secondary W5500: CS=IO40, software reset (no pin -> leaves the primary's
   --  IO11 alone), static address.  Present even with no cable; link stays down.
   W5500.Setup
     (NICs.Eth1_Dev,
      Sclk     => 1,
      Mosi     => 4,
      Miso     => 45,
      Cs       => 40,
      Rst      => ESP32S3.GPIO.No_Pin,
      Int      => 2,
      Host     => ESP32S3.SPI.SPI2,
      Clock_Hz => 10_000_000);
   W5500.Reset (NICs.Eth1_Dev, Ok);                 --  software reset (MR.RST)
   if Ok and then W5500.Present (NICs.Eth1_Dev) then
      W5500.Configure
        (NICs.Eth1_Dev,
         MAC     => MAC1,
         IP      => (10, 0, 0, 2),
         Subnet  => (255, 255, 255, 0),
         Gateway => (10, 0, 0, 1));
      NICs.Eth1_If.Attach (NICs.Eth1_Dev'Access);
      declare
         Id : constant GS.Interface_Id := GS.Add_Interface (NICs.Eth1_If'Access);
         pragma Unreferenced (Id);
      begin
         Have_Eth1 := True;
      end;
      Put_Line ("[nic] secondary W5500 present (CS=IO40), configured 10.0.0.2");
   else
      Put_Line ("[nic] secondary W5500 NOT found on CS=IO40 -- one interface only");
   end if;

   --  3. Liveness, straight from the chips.
   Put_Line ("[nic] eth0 link up: " & YN (W5500.Link (W5500_Dev.Dev) = W5500.Up));
   if Have_Eth1 then
      Put_Line
        ("[nic] eth1 link up: "
         & YN (W5500.Link (NICs.Eth1_Dev) = W5500.Up)
         & "  (expected no -- not cabled)");
   end if;

   --  4. Routes: both interfaces get a default route, the primary preferred by a
   --  lower metric; the secondary's own subnet routes only out the secondary.
   Net_Routes.Set_Default (Eth0, Metric => 10);
   if Have_Eth1 then
      Net_Routes.Set_Default (Eth1, Metric => 100);          --  backup
      Net_Routes.Add_Route ((10, 0, 0, 0), (255, 255, 255, 0), Eth1, Metric => 10);
   end if;

   --  5. Routing decisions (these use each interface's real up/down state).
   Show_Route ("8.8.8.8  ", 8, 8, 8, 8);          --  -> eth0 (eth1 down/backup)
   if Have_Eth1 then
      --  10.0.0.5's most-specific route is via eth1, but eth1 is down -- so it
      --  falls back to the default out the live primary (liveness-aware routing).
      Show_Route ("10.0.0.5 ", 10, 0, 0, 5);
   end if;

   --  6. Pinning: a socket pinned to the down secondary must fail CLOSED, never
   --  fall back to the working primary.
   if Have_Eth1 then
      Try_Connect ("pinned eth1 (down)  ", Pin => Integer (Eth1));
   end if;
   Try_Connect ("routed (-> eth0)    ", Pin => -1);

   Put_Line ("[nic] done.");
   loop
      delay until Clock + Park;
   end loop;
end Main;
