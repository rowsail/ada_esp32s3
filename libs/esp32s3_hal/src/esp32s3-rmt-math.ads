--  Pure tick-divider arithmetic extracted from ESP32S3.RMT (Div_Of).  No
--  registers: just the 80 MHz / resolution divider, split out so it can be
--  formally proved (see libs/esp32s3_hal/test/rmt_math_prove).  The driver's
--  Div_Of now returns Byte (Divider (...)) -- same raise, same value, behaviour-
--  neutral.

package ESP32S3.RMT.Math
  with SPARK_Mode => On
is

   Src_Hz : constant := 80_000_000;   --  APB clock feeds the RMT

   --  Per-channel 8-bit DIV_CNT divider off the 80 MHz source.  The lowest
   --  representable resolution is Src_Hz / 255 (~314 kHz); a lower Resolution_Hz
   --  (Div > 255) is out of range and raises Constraint_Error rather than
   --  silently mis-timing every symbol.  The Pre states the in-range domain, so
   --  the result provably lands in 1 .. 255 and the raise is unreachable.
   function Divider (Resolution_Hz : Positive) return Natural
     with Pre  => Resolution_Hz > Src_Hz / 256,
          Post => Divider'Result in 1 .. 255;

end ESP32S3.RMT.Math;
