with ESP32S3.FRAM_I2C.Driver;

--  16 Kbit / 2 KiB I2C FRAM.  Parts: Fujitsu MB85RC16V; Cypress FM24C16B / FM24CL16B.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_I2C.Kbit_16 is new ESP32S3.FRAM_I2C.Driver (Kbit_16_Part);
