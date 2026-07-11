with ESP32S3.FRAM_I2C.Driver;

--  64 Kbit / 8 KiB I2C FRAM.  Parts: Fujitsu MB85RC64V; Cypress FM24C64B / FM24CL64B.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_I2C.Kbit_64 is new ESP32S3.FRAM_I2C.Driver (Kbit_64_Part);
