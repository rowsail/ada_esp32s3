with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24128 -- 128 Kbit (16 KiB), 64-byte page, 2 address bytes.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24128_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24128 is new ESP32S3.EEPROM_24C.Driver (M24128_Part);
