--  Root of the reusable ESP32-S3 peripheral drivers (the hand-written HAL).
--
--  The thin register layer lives under ESP32S3_Registers.* (svd2ada-generated;
--  see ../svd and ../regenerate.sh) and is never hand-edited. Driver packages are
--  children of this one: ESP32S3.GPIO, ESP32S3.RNG, ESP32S3.Temperature,
--  ESP32S3.GDMA, ESP32S3.SPI (and, later, ESP32S3.UART, ESP32S3.I2S, ...).
--  Consumers `with "esp32s3_hal.gpr";` (by name, or by relative path in-repo) then
--  `with ESP32S3.<Peripheral>;`. See ../README.md.

package ESP32S3 is
   pragma Pure;
end ESP32S3;
