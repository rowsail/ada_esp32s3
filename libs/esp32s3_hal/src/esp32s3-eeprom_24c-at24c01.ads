with ESP32S3.EEPROM_24C.Driver;

--  Atmel/Microchip AT24C01 -- 1 Kbit (128 B), 8-byte page, 1 address byte.
--  Same silicon role as ST's M24C01 but HALF the page: they are not interchangeable.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip AT24C01_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.AT24C01 is new ESP32S3.EEPROM_24C.Driver (AT24C01_Part);
