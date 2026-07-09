with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24C16 -- 16 Kbit (2 KiB), 16-byte page, 1 address byte.
--  A10..A8 fold in and eat all three straps: leave A0/A1/A2 Low, and only ONE
--  of these can sit on a bus.  Microchip's 24LC16B shares this geometry.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24C16_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24C16 is new ESP32S3.EEPROM_24C.Driver (M24C16_Part);
