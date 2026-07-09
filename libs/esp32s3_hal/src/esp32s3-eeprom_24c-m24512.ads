with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24512 -- 512 Kbit (64 KiB), 128-byte page, 2 address bytes.
--  The largest density whose 16-bit word address still covers the whole array.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24512_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24512 is new ESP32S3.EEPROM_24C.Driver (M24512_Part);
