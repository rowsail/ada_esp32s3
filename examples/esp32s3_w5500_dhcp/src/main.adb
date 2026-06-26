--  DHCP client on the W5500 with automatic lease maintenance
--  =========================================================
--  What it demonstrates
--    The W5500 Ethernet driver acquiring its IP address by DHCP instead of a
--    static one, and then keeping that lease alive on its own.
--    ESP32S3.W5500.DHCP.Maintain starts a background task that acquires an
--    address (the DORA exchange: Discover / Offer / Request / Acknowledge) and
--    then holds it: it renews (unicast) at ~T1 = 50 % of the lease, rebinds
--    (broadcast) at ~T2 = 87.5 %, and re-acquires on expiry -- reprogramming the
--    chip each time.  The On_Bound callback prints the lease on every (re)bind.
--    After the first bind the chip is configured, so the higher layers (socket
--    engine, GNAT.Sockets) are ready to use the leased address.
--
--    DHCP is necessarily chip-level, not portable GNAT.Sockets: it must run
--    before an address exists and then program the obtained IP / mask / gateway
--    into the interface -- operations that sit below the sockets API on any
--    platform (raw sockets + ioctl on a desktop; Net.Configure here).  So this
--    example rides ESP32S3.W5500.DHCP directly.
--
--  Build & run
--    ./x run esp32s3_w5500_dhcp
--    build.sh sets ESP32S3_RTS_PROFILE=embedded (DHCP needs the embedded or full
--    profile -- the socket engine and the background maintenance task).
--
--  Output
--    [dhcp] W5500 DHCP client with lease maintenance
--    [dhcp] link up
--    [dhcp] starting lease maintenance (acquire + auto-renew) ...
--    [dhcp] bound: IP 192.168.1.50 mask 255.255.255.0 gw 192.168.1.1 dns ... lease 86400 s
--    The "bound:" line is printed by On_Bound on every (re)bind; the exact
--    addresses come from your router.  "[dhcp] link down" prints instead of
--    "link up" if no cable / PHY link came up in time; "[dhcp] W5500 not found
--    -- check wiring" prints if the chip never answered the presence check.
--
--  Hardware
--    A WIZnet W5500 Ethernet module on SPI2, wired:
--      SCLK = IO1, MOSI = IO4, MISO = IO45, CS = IO39, RSTn = IO11, INTn = IO3.
--    The W5500's RJ45 must be on a LAN that has a DHCP server (a normal home /
--    office router).  No static IP is configured -- the router assigns one.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.W5500.DHCP;
with ESP32S3.Log;   use ESP32S3.Log;
with Net_Dev;
with DHCP_Print;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package Net  renames ESP32S3.W5500;
   package DHCP renames ESP32S3.W5500.DHCP;
   use type Net.Link_State;

   Device : Net.Device renames Net_Dev.Dev;

   --  W5500-to-SoC wiring on SPI2 (the values passed to Net.Setup's pins).
   SPI_Clock_Pin    : constant := 1;     --  SCLK
   SPI_Mosi_Pin     : constant := 4;     --  MOSI (controller out, peripheral in)
   SPI_Miso_Pin     : constant := 45;    --  MISO (controller in, peripheral out)
   Chip_Select_Pin  : constant := 39;    --  CS  (active low, held low per frame)
   Reset_Pin        : constant := 11;    --  RSTn (active low)
   Interrupt_Pin    : constant := 3;     --  INTn (active low, pulled up)

   --  Conservative initial SPI clock; the W5500 tolerates up to 80 MHz once the
   --  wiring is proven, but 10 MHz brings the link up reliably first.
   SPI_Clock_Hz     : constant := 10_000_000;

   --  Client hardware identity for the DHCP exchange.  This is a WIZnet
   --  locally-administered MAC (OUI 00:08:DC); give each board a distinct one.
   Client_MAC : constant Net.MAC_Address :=
     (16#00#, 16#08#, 16#DC#, 16#01#, 16#02#, 16#03#);

   --  PHY auto-negotiation can take a few seconds, so poll the link up to
   --  Link_Up_Polls times, waiting Link_Poll_Interval between checks.
   Link_Up_Polls       : constant := 40;
   Link_Poll_Interval  : constant Time_Span := Milliseconds (250);

   --  How long to wait after power-up before the first console line, so the
   --  serial monitor has attached and does not miss the banner.
   Startup_Delay       : constant Time_Span := Milliseconds (200);

   --  Idle period for the parking loop: the maintenance task does all the work,
   --  so Main just sleeps in long (one-hour) hops forever.
   Park_Interval       : constant Time_Span := Seconds (3600);

   Present : Boolean;     --  True once Reset confirms the chip answered
begin
   delay until Clock + Startup_Delay;
   Put_Line ("[dhcp] W5500 DHCP client with lease maintenance");

   Net.Setup (Device,
              Sclk     => SPI_Clock_Pin,
              Mosi     => SPI_Mosi_Pin,
              Miso     => SPI_Miso_Pin,
              Cs       => Chip_Select_Pin,
              Rst      => Reset_Pin,
              Int      => Interrupt_Pin,
              Host     => ESP32S3.SPI.SPI2,
              Clock_Hz => SPI_Clock_Hz);

   Net.Reset (Device, Present);
   if not Present then
      Put_Line ("[dhcp] W5500 not found -- check wiring");
      loop
         delay until Clock + Park_Interval;
      end loop;
   end if;

   for Poll in 1 .. Link_Up_Polls loop
      exit when Net.Link (Device) = Net.Up;
      delay until Clock + Link_Poll_Interval;
   end loop;
   Put_Line
     (if Net.Link (Device) = Net.Up then "[dhcp] link up" else "[dhcp] link down");

   --  Start the background task: it acquires a lease (On_Bound prints it) and then
   --  renews / rebinds it automatically for as long as the program runs.
   Put_Line ("[dhcp] starting lease maintenance (acquire + auto-renew) ...");
   DHCP.Maintain (Device'Access, Client_MAC, On_Bound => DHCP_Print.On_Bound'Access);

   loop
      delay until Clock + Park_Interval;
   end loop;
end Main;
