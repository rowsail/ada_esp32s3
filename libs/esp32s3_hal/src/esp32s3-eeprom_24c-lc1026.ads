with ESP32S3.EEPROM_24C.Driver;

--  Microchip 24LC1026 -- 1 Mbit (128 KiB), 128-byte page, 2 address bytes.
--  Its sequential read cannot cross the 512-Kbit block, so Read splits there.
--  Its sibling 24LC1025 puts the block bit in the HIGH select-byte position and
--  is NOT supported by this driver -- see the catalogue's header.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip LC1026_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.LC1026 is new ESP32S3.EEPROM_24C.Driver (LC1026_Part);
