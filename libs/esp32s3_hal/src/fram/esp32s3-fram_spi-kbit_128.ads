with ESP32S3.FRAM_SPI.Driver;

--  128 Kbit / 16 KiB SPI FRAM.  Parts: Fujitsu MB85RS128B; Cypress FM25V01.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Kbit_128 is new ESP32S3.FRAM_SPI.Driver (Kbit_128_Part);
