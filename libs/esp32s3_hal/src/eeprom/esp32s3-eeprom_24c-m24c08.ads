with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24C08 -- 8 Kbit (1 KiB), 16-byte page, 1 address byte.
--  A9,A8 fold in and eat E0,E1: leave A0/A1 Low, 2 parts per bus.
--  Microchip's 24LC08B and Atmel's AT24C08 share this geometry.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24C08_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24C08 is new ESP32S3.EEPROM_24C.Driver (M24C08_Part);
