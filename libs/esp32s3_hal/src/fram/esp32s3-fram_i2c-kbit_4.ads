with ESP32S3.FRAM_I2C.Driver;

--  4 Kbit / 512 B I2C FRAM.  Parts: Fujitsu MB85RC04V; Cypress FM24C04B.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_I2C.Kbit_4 is new ESP32S3.FRAM_I2C.Driver (Kbit_4_Part);
