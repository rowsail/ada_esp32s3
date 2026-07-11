with ESP32S3.FRAM_I2C.Driver;

--  512 Kbit / 64 KiB I2C FRAM.  Parts: Fujitsu MB85RC512T; Cypress FM24V05.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_I2C.Kbit_512 is new ESP32S3.FRAM_I2C.Driver (Kbit_512_Part);
