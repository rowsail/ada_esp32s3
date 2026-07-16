--  Pure clock-divider arithmetic extracted from ESP32S3.LEDC (Configure).  No
--  registers: this is the Q10.8 CLK_DIV math only, split out so it can be
--  formally proved (see libs/esp32s3_hal/test/ledc_math_prove).  The driver body
--  calls Clock_Divider and keeps every register write to itself -- behaviour-
--  neutral relocation of the exact expression.

package ESP32S3.LEDC.Math
  with SPARK_Mode => On
is

   Src_Hz : constant := 80_000_000;   --  APB clock feeds the LEDC timers

   --  CLK_DIV is Q10.8: divisor = Src / (Freq * 2**Bits), expressed in 1/256ths,
   --  clamped to the field range [1.0 .. 2**18-1/256] i.e. 256 .. 2**18-1.  The
   --  Pre keeps Freq in its real hardware domain (LEDC PWM never runs below a few
   --  hertz) so the intermediate quotient fits Natural before the clamp.
   function Clock_Divider (Freq : Positive; Bits : Resolution) return Natural
     with Pre  => Freq >= 16,
          Post => Clock_Divider'Result in 256 .. 2**18 - 1;

   --  Duty count for Percent of full scale: Max * Percent / 100, clamped to the
   --  step count Max = 2**Bits (Bits in 1 .. 14 -> Max in 2 .. 16384).  The
   --  Float scaling is proved free of range/overflow error for every legal
   --  Percent (0 .. 100); Set_Duty writes the returned count to the DUTY field.
   function Duty_Count (Bits : Resolution; Percent : Duty_Percent) return Natural
     with Post => Duty_Count'Result <= 16_384;

end ESP32S3.LEDC.Math;
