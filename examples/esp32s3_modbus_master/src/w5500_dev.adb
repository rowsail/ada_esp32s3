with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.W5500.DHCP;
with ESP32S3.W5500.Net_Device;
with ESP32S3.Log;   use ESP32S3.Log;

package body W5500_Dev is
   package Net  renames ESP32S3.W5500;
   package DHCP renames ESP32S3.W5500.DHCP;
   use type Net.Link_State;

   MAC : constant Net.MAC_Address := (16#00#, 16#08#, 16#DC#, 16#01#, 16#02#, 16#03#);

   --  Natural'Image without its leading space.
   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   function Image (A : ESP32S3.W5500.IPv4_Address) return String is
     (Img (Natural (A (0))) & "." & Img (Natural (A (1))) & "."
      & Img (Natural (A (2))) & "." & Img (Natural (A (3))));

   function Bring_Up
     (Settings : IP_Settings := DHCP_Config;
      Lease    : out DHCP.Lease_Info) return Boolean
   is
      Ok : Boolean;
   begin
      Net.Setup (Dev, Sclk => 1, Mosi => 4, Miso => 45, Cs => 39,
                 Rst => 11, Int => 3, Host => ESP32S3.SPI.SPI2,
                 Clock_Hz => 10_000_000);
      Net.Reset (Dev, Ok);
      if not Ok then
         Put_Line ("[w5500] not found (VERSIONR /= 0x04 -- check wiring)");
         return False;
      end if;

      for Try in 1 .. 40 loop                       --  PHY auto-neg takes ~secs
         exit when Net.Link (Dev) = Net.Up;
         delay until Clock + Milliseconds (250);
      end loop;
      if Net.Link (Dev) /= Net.Up then
         Put_Line ("[w5500] link DOWN -- check the cable");
         return False;
      end if;

      if Settings.Use_DHCP then
         --  DORA: on success the chip is programmed with the leased IP / subnet /
         --  gateway, and Lease carries them (plus the DNS server).
         if not DHCP.Acquire_Lease (Dev'Access, MAC, Lease) then
            Put_Line ("[w5500] DHCP: no lease (is there a DHCP server?)");
            return False;
         end if;
      else
         --  Static: program the given address and echo it into Lease so the
         --  caller reads Lease.DNS the same way as for DHCP.
         Net.Configure (Dev, MAC => MAC, IP => Settings.IP,
                        Subnet => Settings.Subnet, Gateway => Settings.Gateway);
         Lease := (IP => Settings.IP, Subnet => Settings.Subnet,
                   Gateway => Settings.Gateway, DNS => Settings.DNS,
                   Lease_Seconds => 0);
      end if;

      ESP32S3.W5500.Net_Device.Register_Default (Dev'Access);
      Put_Line ("[w5500] link up; IP " & Image (Lease.IP)
                & " gw " & Image (Lease.Gateway)
                & " dns " & Image (Lease.DNS)
                & (if Settings.Use_DHCP then " (DHCP)" else " (static)"));
      return True;
   end Bring_Up;
end W5500_Dev;
