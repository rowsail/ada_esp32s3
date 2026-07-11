with ESP32S3.FRAM_SPI.Driver;

--  2 Mbit / 256 KiB SPI FRAM (3 addr bytes).  Parts: Fujitsu MB85RS2MT; Cypress FM25V20.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Mbit_2 is new ESP32S3.FRAM_SPI.Driver (Mbit_2_Part);
