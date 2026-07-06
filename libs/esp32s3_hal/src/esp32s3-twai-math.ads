--  Pure bit-timing arithmetic extracted from ESP32S3.TWAI.Engine (Open).  No
--  registers: this is the CAN baud-rate prescaler math only, split out so it can
--  be formally proved (see libs/esp32s3_hal/test/twai_math_prove).  The Engine
--  body calls Prescaler and keeps every register write to itself -- so this
--  extraction is behaviour-neutral.

package ESP32S3.TWAI.Math
  with SPARK_Mode => On
is

   Src_Hz     : constant := 80_000_000;   --  APB clock feeds the TWAI
   Tq_Per_Bit : constant := 20;           --  20 time-quanta per CAN bit

   --  Even, clamped BRP (effective divisor / 2 pair) for a CAN bit rate.  The
   --  hardware BAUD_PRESC field is BRP / 2 - 1, so the driver wants BRP in the
   --  even range 2 .. 128.  The Pre bounds Bit_Rate to its real hardware domain
   --  (a real CAN bus tops out at 1 Mbit/s) so Bit_Rate * Tq_Per_Bit cannot
   --  overflow Integer.
   function Prescaler (Bit_Rate : Positive) return Natural
     with Pre  => Bit_Rate <= 1_000_000,
          Post => Prescaler'Result in 2 .. 128
                  and then Prescaler'Result mod 2 = 0;

end ESP32S3.TWAI.Math;
