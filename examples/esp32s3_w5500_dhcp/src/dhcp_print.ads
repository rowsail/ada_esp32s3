with ESP32S3.W5500.DHCP;
--  Library-level callback for ESP32S3.W5500.DHCP.Maintain: print each (re)bind.

package DHCP_Print is
   procedure On_Bound (Lease : ESP32S3.W5500.DHCP.Lease_Info);
end DHCP_Print;
