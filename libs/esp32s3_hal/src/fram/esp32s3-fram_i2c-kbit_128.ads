with ESP32S3.FRAM_I2C.Driver;

--  128 Kbit / 16 KiB I2C FRAM.  Parts: Fujitsu MB85RC128A; Cypress FM24V01.
--  STATUS: UNTESTED -- datasheet-derived, not yet run on silicon.
package ESP32S3.FRAM_I2C.Kbit_128 is new ESP32S3.FRAM_I2C.Driver (Kbit_128_Part);
