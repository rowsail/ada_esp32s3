with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.SPI;
with ESP32S3.Strings;
with ESP32S3.W5500.Net_Device;
with ESP32S3.Log; use ESP32S3.Log;

package body W5500_Dev is
   package Net renames ESP32S3.W5500;
   package DHCP renames ESP32S3.W5500.DHCP;
   use type Net.Link_State;

   MAC : constant Net.MAC_Address := (16#00#, 16#08#, 16#DC#, 16#01#, 16#02#, 16#03#);

   --  The static form's fixed address -- edit for your LAN.
   Static_IP      : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 50);
   Static_Subnet  : constant Net.IPv4_Address := Net.IPv4 (255, 255, 255, 0);
   Static_Gateway : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 254);

   function Img (Value : Natural) return String
     renames ESP32S3.Strings.Image;

   function Image (Address : ESP32S3.W5500.IPv4_Address) return String
   is (Img (Natural (Address (0)))
       & "."
       & Img (Natural (Address (1)))
       & "."
       & Img (Natural (Address (2)))
       & "."
       & Img (Natural (Address (3))));

   --  SPI + reset + identity check, shared by both forms.
   function Init_Chip return Boolean is
      Ok : Boolean;
   begin
      Net.Setup
        (Dev,
         Sclk     => 1,
         Mosi     => 4,
         Miso     => 45,
         Cs       => 39,
         Rst      => 11,
         Int      => 3,
         Host     => ESP32S3.SPI.SPI2,
         Clock_Hz => 10_000_000);
      Net.Reset (Dev, Ok);
      if not Ok then
         Put_Line ("[w5500] not found (VERSIONR /= 0x04 -- check wiring)");
      end if;
      return Ok;
   end Init_Chip;

   --  PHY auto-negotiation takes a couple of seconds; wait, bounded.
   procedure Await_Link is
   begin
      for Try in 1 .. 40 loop
         exit when Net.Link (Dev) = Net.Up;
         delay until Clock + Milliseconds (250);
      end loop;
   end Await_Link;

   function Bring_Up
     (Settings : IP_Settings := DHCP_Config;
      Lease    : out DHCP.Lease_Info) return Boolean is
   begin
      if not Init_Chip then
         return False;
      end if;

      Await_Link;
      if Net.Link (Dev) /= Net.Up then
         Put_Line ("[w5500] link DOWN -- check the cable");
         return False;
      end if;

      if Settings.Use_DHCP then
         --  DORA: on success the chip is programmed with the leased IP /
         --  subnet / gateway, and Lease carries them (plus the DNS server).
         if not DHCP.Acquire_Lease (Dev'Access, MAC, Lease) then
            Put_Line ("[w5500] DHCP: no lease (is there a DHCP server?)");
            return False;
         end if;
      else
         --  Static: program the given address and echo it into Lease so the
         --  caller reads Lease.DNS the same way as for DHCP.
         Net.Configure
           (Dev,
            MAC     => MAC,
            IP      => Settings.IP,
            Subnet  => Settings.Subnet,
            Gateway => Settings.Gateway);
         Lease :=
           (IP            => Settings.IP,
            Subnet        => Settings.Subnet,
            Gateway       => Settings.Gateway,
            DNS           => Settings.DNS,
            Lease_Seconds => 0);
      end if;

      ESP32S3.W5500.Net_Device.Register_Default (Dev'Access);
      Put_Line
        ("[w5500] link up; IP "
         & Image (Lease.IP)
         & " gw "
         & Image (Lease.Gateway)
         & " dns "
         & Image (Lease.DNS)
         & (if Settings.Use_DHCP then " (DHCP)" else " (static)"));
      return True;
   end Bring_Up;

   function Bring_Up return Boolean is
   begin
      if not Init_Chip then
         return False;
      end if;
      Net.Configure
        (Dev,
         MAC     => MAC,
         IP      => Static_IP,
         Subnet  => Static_Subnet,
         Gateway => Static_Gateway);
      Await_Link;
      Put_Line
        (if Net.Link (Dev) = Net.Up
         then "[w5500] link up, IP 192.168.1.50"
         else "[w5500] link DOWN -- check the cable");
      ESP32S3.W5500.Net_Device.Register_Default (Dev'Access);
      return True;
   end Bring_Up;

end W5500_Dev;
