--  Ada SAR ADC one-shot self-test on the bare-metal ESP32-S3 (no FreeRTOS, IDF)
--  ===========================================================================
--  What it demonstrates
--    The reusable HAL ADC driver (ESP32S3.ADC) doing software-triggered single
--    conversions.  ADC1 channel 0 is fixed-wired to GPIO1; we drive that one pad
--    HIGH with the GPIO output driver and read the ADC back (expect near full
--    scale), then drive it LOW and read again (expect near zero).  Because the
--    same pad is both driven and ADC-sensed, the test needs no external wiring.
--
--  Build & run
--    ./x run esp32s3_adc_read        --  build + flash + monitor
--    Needs the embedded profile (the Reader handle uses finalization, which
--    light-tasking forbids); build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  Output (PASS = clear high/low separation, and the conversion's DONE flag set)
--    [adc] bare-metal SAR ADC one-shot self-test (drive+sense one pad, no wiring)
--    [adc] ADC1 ch0: drive-high=4095  drive-low=0  PASS
--    [adc]   cal_code=2241  last_done=1
--    [adc] done.
--
--  Hardware / wiring
--    None.  ADC1 ch0 is GPIO1, and that single pad is both driven and sensed, so
--    nothing is connected externally.  (To read a real source instead, leave the
--    pad an input and connect e.g. a potentiometer wiper / 3V3 / GND to GPIO1.)
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.ADC; use ESP32S3.ADC;
with ESP32S3.GPIO;
with ESP32S3.Log; use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  ADC1 channel 0, which the S3 fixed-maps to pad GPIO1 (Channel_Pin asks the
   --  driver for that mapping rather than hard-coding the pin number here).
   Sense_Channel : constant Channel_Index := 0;
   Sense_Pin     : constant ESP32S3.GPIO.Pin_Id := Channel_Pin (ADC1, Sense_Channel);

   --  Let the just-set GPIO level settle on the pad (and through the ADC's input
   --  RC) before sampling.
   Settle_Time : constant Time_Span := Milliseconds (2);

   --  Decision thresholds for the 0 .. 4095 (12-bit) code, default Db_12
   --  attenuation (~3.3 V full scale).  Driven high must read near full scale and
   --  driven low near zero, with a clear gap between them.
   High_Min : constant Natural := 3000;   --  "high" read must exceed this
   Low_Max  : constant Natural := 500;    --  "low"  read must stay under this

   --  Median of a few reads is cheap noise rejection: take three back-to-back
   --  conversions on the channel and return their mean.
   function Sample (R : Reader) return Natural is
      First  : constant Natural := Read (R, Sense_Channel);
      Second : constant Natural := Read (R, Sense_Channel);
      Third  : constant Natural := Read (R, Sense_Channel);
   begin
      return (First + Second + Third) / 3;
   end Sample;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[adc] bare-metal SAR ADC one-shot self-test (drive+sense one pad, no wiring)");

   declare
      R : Reader;

      --  Reads taken with the pad driven high / low.
      High : Natural := 0;
      Low  : Natural := 0;

      Passed : Boolean;
   begin
      --  Claim brings up the SAR analog front-end and self-calibrates it once.
      Claim (R, ADC1);

      --  Drive the pad high, let it settle, read.
      ESP32S3.GPIO.Configure (Sense_Pin, ESP32S3.GPIO.Output);
      ESP32S3.GPIO.Set (Sense_Pin);
      delay until Clock + Settle_Time;
      High := Sample (R);

      --  Drive the pad low, let it settle, read.
      ESP32S3.GPIO.Clear (Sense_Pin);
      delay until Clock + Settle_Time;
      Low := Sample (R);

      --  Clear separation: high near full scale, low near zero.
      Passed := High > High_Min and then Low < Low_Max and then High > Low;
      Put ("[adc] ADC1 ch0: drive-high=");
      Put (High);
      Put ("  drive-low=");
      Put (Low);
      Put ("  ");
      Put_Line (if Passed then "PASS" else "FAIL");
      Put ("[adc]   cal_code=");
      Put (Cal_Code (ADC1));
      Put ("  last_done=");
      Put (Boolean'Pos (Last_Done));
      New_Line;
   end;                                  --  R finalizes -> unit released

   Put_Line ("[adc] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
