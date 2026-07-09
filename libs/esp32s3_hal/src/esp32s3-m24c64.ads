with ESP32S3.EEPROM_24C;

--  STMicroelectronics M24C64 64-Kbit (8 KiB) serial I2C EEPROM.
--
--  Byte-addressable 0 .. 8191, written 32 bytes at a time, two word-address
--  bytes, and all three chip-enable straps intact -- so the 7-bit slave address
--  is 0x50 + A2*4 + A1*2 + A0 and up to eight parts share one bus.
--
--  Everything else lives in the generic; see ESP32S3.EEPROM_24C for the protocol
--  the whole 24C family shares, and for how to instantiate other densities.
--  Microchip's 24LC64 and Atmel's AT24C64 have the same geometry and work here.
package ESP32S3.M24C64 is new ESP32S3.EEPROM_24C
  (Capacity_Bytes     => 8_192,
   Page_Bytes         => 32,
   Word_Address_Bytes => 2);
