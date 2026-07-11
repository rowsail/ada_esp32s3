with ESP32S3.EEPROM_24C.Driver;

--  STMicroelectronics M24C64 -- 64 Kbit (8 KiB), 32-byte page, 2 address bytes.
--  All three chip-enable straps intact: 0x50 + A2*4 + A1*2 + A0, 8 per bus.
--  Microchip's 24LC64 and Atmel's AT24C64 share this geometry and work here.
--
--  STATUS: HARDWARE-VERIFIED -- run against a real part on the
--  esp32s3_m24c64 example board (I2C0, SDA = IO41, SCL = IO40).
package ESP32S3.EEPROM_24C.M24C64 is new ESP32S3.EEPROM_24C.Driver (M24C64_Part);
