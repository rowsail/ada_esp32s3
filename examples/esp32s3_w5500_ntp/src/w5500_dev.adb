with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.SPI;
with ESP32S3.W5500;
with ESP32S3.W5500.Net_Device;
with ESP32S3.Log;   use ESP32S3.Log;

package body W5500_Dev is
   package Net renames ESP32S3.W5500;
   use type Net.Link_State;

   --  SPI wiring to the W5500 module (ESP32-S3 GPIO numbers).
   SPI_Sclk_Pin : constant := 1;    --  serial clock     -> W5500 SCLK
   SPI_Mosi_Pin : constant := 4;    --  host -> chip      -> W5500 MOSI
   SPI_Miso_Pin : constant := 45;   --  chip -> host      -> W5500 MISO
   SPI_Cs_Pin   : constant := 39;   --  chip select       -> W5500 SCSn
   Reset_Pin    : constant := 11;   --  active-low reset  -> W5500 RSTn
   Int_Pin      : constant := 3;    --  interrupt out     -> W5500 INTn

   --  SPI bus clock.  The W5500 supports far more, but 10 MHz is a safe,
   --  reliable rate over typical jumper wiring.
   SPI_Clock_Hz : constant := 10_000_000;

   --  Station MAC address.  Locally-administered, unique on the LAN; change it
   --  if you run several of these boards on the same network.
   MAC : constant Net.MAC_Address := (16#00#, 16#08#, 16#DC#, 16#01#, 16#02#, 16#03#);

   --  Static IPv4 configuration for this board.  Edit for your own LAN.
   Static_IP      : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 50);
   Subnet_Mask    : constant Net.IPv4_Address := Net.IPv4 (255, 255, 255, 0);
   Gateway_IP     : constant Net.IPv4_Address := Net.IPv4 (192, 168, 1, 254);

   --  Wait for Ethernet link-up: PHY auto-negotiation takes a few seconds.
   --  Poll up to Link_Poll_Tries times, Link_Poll_Interval_Ms apart.
   Link_Poll_Tries       : constant := 40;
   Link_Poll_Interval_Ms : constant := 250;

   function Bring_Up return Boolean is
      Reset_Ok : Boolean;
   begin
      Net.Setup (Dev,
                 Sclk     => SPI_Sclk_Pin,
                 Mosi     => SPI_Mosi_Pin,
                 Miso     => SPI_Miso_Pin,
                 Cs       => SPI_Cs_Pin,
                 Rst      => Reset_Pin,
                 Int      => Int_Pin,
                 Host     => ESP32S3.SPI.SPI2,
                 Clock_Hz => SPI_Clock_Hz);
      Net.Reset (Dev, Reset_Ok);
      if not Reset_Ok then
         Put_Line ("[w5500] not found (VERSIONR /= 0x04 -- check wiring)");
         return False;
      end if;
      Net.Configure (Dev,
                     MAC     => MAC,
                     IP      => Static_IP,
                     Subnet  => Subnet_Mask,
                     Gateway => Gateway_IP);
      for Try in 1 .. Link_Poll_Tries loop
         exit when Net.Link (Dev) = Net.Up;
         delay until Clock + Milliseconds (Link_Poll_Interval_Ms);
      end loop;
      Put_Line (if Net.Link (Dev) = Net.Up
                then "[w5500] link up, IP 192.168.1.50"
                else "[w5500] link DOWN -- check the cable");
      ESP32S3.W5500.Net_Device.Register_Default (Dev'Access);
      return True;
   end Bring_Up;
end W5500_Dev;
