with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24256 -- 256 Kbit (32 KiB), 64-byte page, 2 address bytes.
--  Atmel's AT24C256 and Microchip's 24LC256 share this geometry.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24256_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24256 is new ESP32S3.EEPROM_24C.Driver (M24256_Part);
