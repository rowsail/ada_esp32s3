with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24C02 -- 2 Kbit (256 B), 16-byte page, 1 address byte.
--  NOT for Atmel/Microchip 2K parts: their page is 8 bytes -- see AT24C02.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24C02_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24C02 is new ESP32S3.EEPROM_24C.Driver (M24C02_Part);
