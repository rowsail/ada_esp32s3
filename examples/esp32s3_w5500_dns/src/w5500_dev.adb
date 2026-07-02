with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.W5500.Net_Device;
with ESP32S3.Log;   use ESP32S3.Log;

package body W5500_Dev is
   package Net renames ESP32S3.W5500;
   use type Net.Link_State;

   --  SPI wiring: S3 GPIO -> W5500 pin.  Match these to your board.
   Pin_Sclk : constant := 1;
   Pin_Mosi : constant := 4;
   Pin_Miso : constant := 45;
   Pin_Cs   : constant := 39;
   Pin_Rst  : constant := 11;
   Pin_Int  : constant := 3;

   --  W5500 SPI clock.  10 MHz is a conservative, reliable rate for it.
   SPI_Clock_Hz : constant := 10_000_000;

   --  Station MAC address (locally administered; change to suit your LAN).
   MAC : constant Net.MAC_Address := (16#00#, 16#08#, 16#DC#, 16#01#, 16#02#, 16#03#);

   --  Static IPv4 configuration for this board on your LAN.
   Station_IP : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 50);
   Netmask    : constant Net.IPv4_Address := Net.IPv4 (255, 255, 255, 0);
   Gateway_IP : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 254);

   --  Link-up poll: PHY auto-negotiation takes a few seconds, so try for
   --  up to Link_Poll_Tries x Link_Poll_Interval (= 10 s) before declaring it down.
   Link_Poll_Tries    : constant := 40;
   Link_Poll_Interval : constant Time_Span := Milliseconds (250);

   function Bring_Up return Boolean is
      Ok : Boolean;
   begin
      Net.Setup
        (Dev,
         Sclk     => Pin_Sclk,
         Mosi     => Pin_Mosi,
         Miso     => Pin_Miso,
         Cs       => Pin_Cs,
         Rst      => Pin_Rst,
         Int      => Pin_Int,
         Host     => ESP32S3.SPI.SPI2,
         Clock_Hz => SPI_Clock_Hz);
      Net.Reset (Dev, Ok);
      if not Ok then
         Put_Line ("[w5500] not found (VERSIONR /= 0x04 -- check wiring)");
         return False;
      end if;
      Net.Configure (Dev, MAC => MAC, IP => Station_IP, Subnet => Netmask, Gateway => Gateway_IP);
      for Try in 1 .. Link_Poll_Tries loop
         exit when Net.Link (Dev) = Net.Up;
         delay until Clock + Link_Poll_Interval;
      end loop;
      Put_Line
        (if Net.Link (Dev) = Net.Up
         then "[w5500] link up, IP 192.168.1.50"
         else "[w5500] link DOWN -- check the cable");
      ESP32S3.W5500.Net_Device.Register_Default (Dev'Access);
      return True;
   end Bring_Up;
end W5500_Dev;
