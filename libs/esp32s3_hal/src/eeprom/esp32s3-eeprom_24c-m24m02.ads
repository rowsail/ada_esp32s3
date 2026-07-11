with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24M02 -- 2 Mbit (256 KiB), 256-byte page, 2 address bytes.
--  A17,A16 fold in and eat E0,E1: leave A0/A1 Low, 2 parts per bus.
--
--  STATUS: UNTESTED -- geometry transcribed from the datasheet, never run
--  against silicon.  The protocol is shared with the verified M24C64, so
--  this is very likely right; please flip M24M02_Part to Verified in the
--  catalogue once you have exercised it.  (Instances export
--  Hardware_Verified.)
package ESP32S3.EEPROM_24C.M24M02 is new ESP32S3.EEPROM_24C.Driver (M24M02_Part);
