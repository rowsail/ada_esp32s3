with ESP32S3.FRAM_SPI.Driver;

--  4 Kbit / 512 B SPI FRAM (1 addr byte + A8-in-opcode).  Parts: Cypress FM25040B / FM25L04B.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Kbit_4 is new ESP32S3.FRAM_SPI.Driver (Kbit_4_Part);
