with Interfaces;

--  The factory MAC address programmed into the ESP32-S3's eFuse, and the
--  per-interface MACs the chip derives from it.  Espressif allocates each part a
--  block of FOUR universally-administered addresses: the eFuse base is the Wi-Fi
--  station MAC, and soft-AP / Bluetooth / Ethernet are base + 1 / + 2 / + 3.  Use
--  Ethernet for a W5500 to give it a unique, manufacturer-assigned address instead
--  of a hand-picked one.
--
--  Reads the eFuse shadow registers directly (latched at reset); no clock or driver
--  state needed, so every routine is a pure read.

package ESP32S3.MAC is

   --  Six bytes, most-significant first: MAC (0) is the OUI's first byte -- the
   --  order the W5500 and DHCP expect.
   type MAC_Address is array (0 .. 5) of Interfaces.Unsigned_8;

   --  The factory base MAC (= the Wi-Fi station MAC).
   function Base return MAC_Address;

   --  The four universal per-interface MACs derived from the base.
   function Wi_Fi_Station return MAC_Address;   --  base + 0  (= Base)
   function Wi_Fi_SoftAP return MAC_Address;   --  base + 1
   function Bluetooth return MAC_Address;   --  base + 2
   function Ethernet return MAC_Address;   --  base + 3

   --  Base with Offset added to its last byte.  Offsets 0 .. 3 are the universal
   --  MACs above.  A larger offset (e.g. for a SECOND Ethernet NIC) is no longer a
   --  registered address, so mark it with Local so it cannot clash with a real one.
   function Derived (Offset : Interfaces.Unsigned_8) return MAC_Address;

   --  Mark a MAC locally administered (set bit 1 of byte 0) and unicast (clear bit
   --  0) -- for addresses you assign yourself rather than the factory block.
   function Local (Addr : MAC_Address) return MAC_Address;

   --  "aa:bb:cc:dd:ee:ff"
   function Image (Addr : MAC_Address) return String;

end ESP32S3.MAC;
