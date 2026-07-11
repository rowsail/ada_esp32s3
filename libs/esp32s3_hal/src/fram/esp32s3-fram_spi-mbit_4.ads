with ESP32S3.FRAM_SPI.Driver;

--  4 Mbit / 512 KiB SPI FRAM (3 addr bytes).  Parts: Fujitsu MB85RS4MT.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_SPI.Mbit_4 is new ESP32S3.FRAM_SPI.Driver (Mbit_4_Part);
