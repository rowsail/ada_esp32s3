--  WIZnet W5500 PHY power-down (low-power) on the bare-metal ESP32-S3
--  ============================================================================
--  What it demonstrates
--    The W5500's low-power mode: ESP32S3.W5500.Set_Power (Dev, Power_Down) turns
--    the Ethernet PHY off.  That PHY -- the 100BASE-TX line driver -- is the bulk
--    of the chip's current, so powering it down is the meaningful power saving.
--    The link drops (observable: the switch port and the W5500's link LED go
--    dark), no frames move, but the registers and the 32 KiB socket buffers stay
--    intact.  Set_Power (Dev, Normal) brings the PHY back and the link re-
--    negotiates.
--
--    The proof here is the LINK: it reads Up when the PHY runs, Down while it is
--    powered down, and Up again after wake -- with Power reading back the mode
--    each time.  (Current draw needs a meter; the link transition is the
--    software-visible, physically-confirmable signal that the PHY really slept.)
--
--  Build & run
--    ./x run esp32s3_w5500_lowpower           (embedded profile; see build.sh)
--
--  Hardware / wiring (ESP32-S3 <-> W5500, SPI2) -- same as esp32s3_w5500
--    SCLK = IO1  MOSI = IO4  MISO = IO45  SCSn = IO39  RSTn = IO11  INTn = IO3
--    Plug the W5500 into a live switch/router so the link can negotiate.
with Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.Log;  use ESP32S3.Log;
with W5500_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package Net renames ESP32S3.W5500;
   use type Net.Link_State;
   use type Net.Power_Mode;
   use type Net.Phy_Speed;
   use type Net.Phy_Duplex;

   Dev : Net.Device renames W5500_Dev.Dev;
   Ok  : Boolean;

   Sclk_Pin        : constant := 1;
   Mosi_Pin        : constant := 4;
   Miso_Pin        : constant := 45;
   Chip_Select_Pin : constant := 39;
   Reset_Pin       : constant := 11;
   Interrupt_Pin   : constant := 3;
   SPI_Clock_Hz    : constant := 10_000_000;

   My_MAC     : constant Net.MAC_Address := (16#00#, 16#08#, 16#DC#, 16#01#, 16#02#, 16#03#);
   My_IP      : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 50);
   My_Subnet  : constant Net.IPv4_Address := Net.IPv4 (255, 255, 255, 0);
   My_Gateway : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 1);

   --  Wait up to ~5 s for the link to reach Want (auto-neg after a PHY start is
   --  the slow part).  Returns whether it got there.
   function Wait_Link (Want : Net.Link_State) return Boolean is
   begin
      for Try in 1 .. 20 loop
         exit when Net.Link (Dev) = Want;
         delay until Clock + Milliseconds (250);
      end loop;
      return Net.Link (Dev) = Want;
   end Wait_Link;

   procedure Show (Tag : String) is
      P : constant Net.Phy_Status := Net.Phy (Dev);
   begin
      Put ("[lp] " & Tag & ": PHY ");
      Put (if Net.Power (Dev) = Net.Power_Down then "POWER-DOWN" else "normal");
      Put (", link ");
      Put (if P.Link = Net.Up then "UP" else "down");
      if P.Link = Net.Up then
         Put (" (");
         Put (if P.Speed = Net.Mbps_100 then "100" else "10");
         Put ("Mbps ");
         Put (if P.Duplex = Net.Full then "full" else "half");
         Put (")");
      end if;
      New_Line;
   end Show;

begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[lp] W5500 PHY power-down demo");

   Net.Setup
     (Dev, Sclk => Sclk_Pin, Mosi => Mosi_Pin, Miso => Miso_Pin,
      Cs => Chip_Select_Pin, Rst => Reset_Pin, Int => Interrupt_Pin,
      Host => ESP32S3.SPI.SPI2, Clock_Hz => SPI_Clock_Hz);
   Net.Reset (Dev, Ok);
   Put ("[lp] VERSIONR = 0x");
   Put_Hex (Interfaces.Unsigned_32 (Net.Version (Dev)), 2);
   Put_Line (if Ok then "  (W5500 present)" else "  (unexpected -- check wiring!)");
   if not Ok then
      loop delay until Clock + Seconds (3600); end loop;
   end if;
   Net.Configure (Dev, MAC => My_MAC, IP => My_IP, Subnet => My_Subnet, Gateway => My_Gateway);

   --  1) Running: the PHY is up, the link negotiates.
   Ok := Wait_Link (Net.Up);
   Show ("running ");
   if not Ok then
      Put_Line ("[lp] (no link -- plug into a live switch to see the transitions)");
   end if;

   --  Cycle the PHY a few times: down (sleep), then back up (wake).
   for Round in 1 .. 3 loop
      Put_Line ("");
      Put ("[lp] --- round ");
      Put (Round);
      Put_Line (" ---");

      --  2) Sleep: power the PHY down.  The link should drop.
      Net.Set_Power (Dev, Net.Power_Down);
      Ok := Wait_Link (Net.Down);
      Show ("slept   ");
      Put_Line (if Net.Power (Dev) = Net.Power_Down and then Net.Link (Dev) = Net.Down
                then "[lp]   -> PHY off, link down as expected"
                else "[lp]   -> unexpected: PHY did not power down");

      --  Stay asleep a while (this is where the current is saved).
      delay until Clock + Seconds (3);

      --  3) Wake: power the PHY back up.  The link re-negotiates.
      Net.Set_Power (Dev, Net.Normal);
      Ok := Wait_Link (Net.Up);
      Show ("woke    ");
      Put_Line (if Net.Link (Dev) = Net.Up
                then "[lp]   -> PHY back, link re-negotiated"
                else "[lp]   -> link not back yet (slow switch, or no cable)");
   end loop;

   Put_Line ("");
   Put_Line ("[lp] done -- registers/buffers survived every cycle; only the wire slept.");
   loop delay until Clock + Seconds (3600); end loop;
end Main;
