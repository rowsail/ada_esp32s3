with ESP32S3.W5500;
--  The W5500 as a library-level, aliased board resource (so the socket/DHCP layers
--  can take Dev'Access).  No static IP here -- DHCP assigns it.

package Net_Dev is
   Dev : aliased ESP32S3.W5500.Device;
end Net_Dev;
