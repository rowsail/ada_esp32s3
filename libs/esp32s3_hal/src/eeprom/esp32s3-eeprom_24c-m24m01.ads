with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24M01 -- 1 Mbit (128 KiB), 256-byte page, 2 address bytes.
--  A16 folds into the select byte and eats E0: leave A0 Low, 4 parts per bus.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24M01_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24M01 is new ESP32S3.EEPROM_24C.Driver (M24M01_Part);
