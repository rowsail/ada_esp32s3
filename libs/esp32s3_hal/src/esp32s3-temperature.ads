with ESP32S3_Registers;

--  ESP32-S3 on-chip temperature sensor.
--
--  Reports the die temperature of the SoC (NOT ambient air -- the chip
--  self-heats under load, so an idle board typically reads a few degrees above
--  room temperature).  Accuracy is roughly +/- 1 C after the part's factory
--  trim, best near the middle of the selected measurement range.
--
--  Bring-up (done by Initialize) follows esp-idf's temperature_sensor_ll:
--  gate the SAR peripheral clock, pulse-reset it, open the analog REGI2C bus,
--  program the sensor's DAC range over that bus (a ROM call), then power the
--  sensor up.  Each reading drives the dump-out / ready handshake that latches
--  a fresh conversion before sampling SAR_TSENS_OUT.
--
--  Task-safe: the sensor is owned by a protected object, so concurrent Read_*
--  from different tasks are serialised automatically (Read_* busy-wait
--  microseconds for the conversion under that lock).  Initialize is optional --
--  the first Read brings the sensor up with the default range if you skip it.
--  (Holding a protected object, this package requires a tasking runtime.)

package ESP32S3.Temperature is
   --  Hardware measurement ranges (TRM "temperature_sensor_attributes").  The
   --  sensor is most accurate near the middle of the chosen range; pick the one
   --  that brackets your expected die temperature.  The default suits a typical
   --  board running near room temperature.
   type Measure_Range is
     (Range_Minus10_80,    --  -10 .. 80 C   (default)
      Range_20_100,        --   20 .. 100 C
      Range_50_125,        --   50 .. 125 C
      Range_Minus30_50,    --  -30 .. 50 C
      Range_Minus40_20);   --  -40 .. 20 C

   --  Power up and configure the sensor.  Call once before any Read_*; safe to
   --  call again to switch range.  (Read_* auto-initialise with the default
   --  range if you never call this.)
   procedure Initialize (Span : Measure_Range := Range_Minus10_80);

   --  Latest die temperature in centi-degrees Celsius, signed
   --  (e.g. 1807 = 18.07 C).  Triggers a fresh conversion and busy-waits
   --  (microseconds) for it.
   function Read_Centi_Celsius return Integer;

   --  Latest die temperature in whole degrees Celsius, truncated toward zero.
   function Read_Celsius return Integer;

   --  Raw 8-bit sensor code (0 .. 255), if you'd rather apply your own curve.
   function Read_Raw return ESP32S3_Registers.Byte;
end ESP32S3.Temperature;
