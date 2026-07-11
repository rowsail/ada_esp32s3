with ESP32S3.FRAM_SPI.Driver;

--  64 Kbit / 8 KiB SPI FRAM.  Parts: Fujitsu MB85RS64; Cypress FM25CL64B.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Kbit_64 is new ESP32S3.FRAM_SPI.Driver (Kbit_64_Part);
