with ESP32S3.FRAM_SPI.Driver;

--  16 Kbit / 2 KiB SPI FRAM.  Parts: Fujitsu MB85RS16.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Kbit_16 is new ESP32S3.FRAM_SPI.Driver (Kbit_16_Part);
