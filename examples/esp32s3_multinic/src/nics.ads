with ESP32S3.W5500;
with ESP32S3.W5500.Net_Device;

--  Library-level holder for the SECOND W5500 interface.  Its access is stored in
--  the GNAT.Sockets registry (Add_Interface), which outlives Main -- so, like the
--  filesystem mounts, the device and its Net_Device.Instance must live at library
--  level (a Main-local object would fail the accessibility check).

package NICs is
   Eth1_Dev : aliased ESP32S3.W5500.Device;
   Eth1_If  : aliased ESP32S3.W5500.Net_Device.Instance;
end NICs;
