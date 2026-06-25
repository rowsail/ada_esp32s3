with ESP32S3.W5500;

--  The W5500 as a library-level, aliased board resource, plus a one-call bring-up
--  (SPI + reset + static IP 192.168.1.50 / gateway .254 + wait for link) that also
--  hands the chip to the GNAT.Sockets facade.  Edit the addresses in the body for
--  your own LAN.
package W5500_Dev is
   Dev : aliased ESP32S3.W5500.Device;
   function Bring_Up return Boolean;     --  False if the chip is not found
end W5500_Dev;
