with ESP32S3.FRAM_SPI.Driver;

--  512 Kbit / 64 KiB SPI FRAM.  Parts: Cypress FM25V05.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Kbit_512 is new ESP32S3.FRAM_SPI.Driver (Kbit_512_Part);
