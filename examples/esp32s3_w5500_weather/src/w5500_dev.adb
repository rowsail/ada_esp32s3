with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.SPI;
with ESP32S3.W5500;
with GNAT.Sockets;
with ESP32S3.Log;   use ESP32S3.Log;

package body W5500_Dev is
   package Net renames ESP32S3.W5500;
   use type Net.Link_State;

   MAC : constant Net.MAC_Address := (16#00#, 16#08#, 16#DC#, 16#01#, 16#02#, 16#03#);

   function Bring_Up return Boolean is
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
      Net.Configure (Dev,
                     MAC     => MAC,
                     IP      => Net.IPv4 (192, 168, 1, 50),
                     Subnet  => Net.IPv4 (255, 255, 255, 0),
                     Gateway => Net.IPv4 (192, 168, 1, 254));
      for Try in 1 .. 40 loop                       --  PHY auto-neg takes ~secs
         exit when Net.Link (Dev) = Net.Up;
         delay until Clock + Milliseconds (250);
      end loop;
      Put_Line (if Net.Link (Dev) = Net.Up
                then "[w5500] link up, IP 192.168.1.50"
                else "[w5500] link DOWN -- check the cable");
      GNAT.Sockets.Initialize (Dev'Access);
      return True;
   end Bring_Up;
end W5500_Dev;
