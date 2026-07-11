with ESP32S3.FRAM_SPI.Driver;

--  256 Kbit / 32 KiB SPI FRAM.  Parts: Fujitsu MB85RS256B; Cypress FM25V02A / FM25W256.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Kbit_256 is new ESP32S3.FRAM_SPI.Driver (Kbit_256_Part);
