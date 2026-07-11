with ESP32S3.FRAM_I2C.Driver;

--  256 Kbit / 32 KiB I2C FRAM.  Parts: Fujitsu MB85RC256V; Cypress FM24W256; FM31256 (FRAM array only).
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_I2C.Kbit_256 is new ESP32S3.FRAM_I2C.Driver (Kbit_256_Part);
