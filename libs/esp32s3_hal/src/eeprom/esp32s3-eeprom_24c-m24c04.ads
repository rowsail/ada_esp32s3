with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24C04 -- 4 Kbit (512 B), 16-byte page, 1 address byte.
--  A8 folds into the select byte and eats E0: leave A0 Low, 4 parts per bus.
--  Microchip's 24LC04B and Atmel's AT24C04 share this geometry.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24C04_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24C04 is new ESP32S3.EEPROM_24C.Driver (M24C04_Part);
