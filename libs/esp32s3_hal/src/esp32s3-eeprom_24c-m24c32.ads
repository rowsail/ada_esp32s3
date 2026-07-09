with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24C32 -- 32 Kbit (4 KiB), 32-byte page, 2 address bytes.
--  First density with two address bytes, so all three straps are back: 8 per bus.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24C32_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24C32 is new ESP32S3.EEPROM_24C.Driver (M24C32_Part);
