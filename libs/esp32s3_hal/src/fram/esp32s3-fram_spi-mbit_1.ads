with ESP32S3.FRAM_SPI.Driver;

--  1 Mbit / 128 KiB SPI FRAM (3 addr bytes).  Parts: Cypress FM25V10.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Mbit_1 is new ESP32S3.FRAM_SPI.Driver (Mbit_1_Part);
