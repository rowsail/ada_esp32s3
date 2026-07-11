with ESP32S3.FRAM_I2C.Driver;

--  1 Mbit / 128 KiB I2C FRAM.  Parts: Fujitsu MB85RC1MT; Cypress FM24V10.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_I2C.Mbit_1 is new ESP32S3.FRAM_I2C.Driver (Mbit_1_Part);
