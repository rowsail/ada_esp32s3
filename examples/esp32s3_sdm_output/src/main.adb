--  Ada SDM self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ==================================================================
--  What:  Exercises the reusable HAL SDM driver (ESP32S3.SDM) -- the GPIO
--         sigma-delta-modulator unit's eight 1-bit density-modulated outputs.
--         It sets a channel to several output densities and measures each back
--         by GPIO-sampling the output pad's average (high samples / total) over
--         a window -- NO wiring.  A sigma-delta stream's average equals its
--         programmed density, so the sampled fraction should track the set
--         value.  Also checks the controlled (RAII) Channel handle.
--
--  Build & run:  ./x run esp32s3_sdm_output
--         Built as the embedded profile (build.sh sets ESP32S3_RTS_PROFILE=
--         embedded); the SDM Channel uses finalization, which light-tasking
--         forbids.
--
--  Output:  one line per density (set vs measured, PASS within 6 %), then one
--         RAII line, then "[sdm] done.":
--             [sdm] bare-metal SDM sigma-delta density self-test (GPIO-sampled, no wiring)
--             [sdm] density set=25%    measured=25.0%    PASS
--             [sdm] density set=50%    measured=50.0%    PASS
--             [sdm] density set=75%    measured=75.0%    PASS
--             [sdm] raii: 8-claimed=y 9th-rejected=y reclaimed=y  PASS
--             [sdm] done.
--
--  Hardware:  none required -- the SDM output (GPIO4) is read back digitally on
--         the same pin, so no wiring.  For a real analog output you would put an
--         RC low-pass on GPIO4 (e.g. 1 k + 100 nF) to recover the density as a
--         voltage, or just an LED + series resistor to dim it.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SDM;   use ESP32S3.SDM;
with ESP32S3.GPIO;
with ESP32S3.Log;   use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   --  Pad the SDM channel drives; also the pad we GPIO-sample to read it back.
   Output_Pin : constant ESP32S3.GPIO.Pin_Id := 4;

   --  Which of the eight SDM channels (0 .. 7) carries the density test.
   Test_Channel_Index : constant Channel_Index := 0;

   --  Sigma-delta carrier (pulse-stream) frequency.  Deliberately low so the
   --  GPIO sampler oversamples each bit and averages fairly; a fast 50 %-density
   --  square would otherwise alias against the fixed sample loop.  The density
   --  itself is carrier-independent.
   Carrier_Frequency_Hz : constant Positive := 400_000;

   --  Output densities to set and measure back, as a percentage of high time.
   --  25/50/75 % give an unambiguous low/mid/high spread to confirm tracking.
   Densities : constant array (1 .. 3) of Density_Percent := (25.0, 50.0, 75.0);

   --  Window over which we average the output pad to recover its density.
   Measure_Window_Ms : constant Positive := 50;

   --  Let the new density propagate through the modulator before sampling.
   Settle_Ms : constant Positive := 5;

   --  Allowed set-vs-measured error: the digital sampler can never be exact, so
   --  6 % covers the quantisation/aliasing slack while still catching a real bug.
   Tolerance_Percent : constant Float := 6.0;

   --  Average the output pad over Window_Ms -> high fraction as a percentage.
   function Measure (Window_Ms : Positive) return Float is
      Deadline : constant Time := Clock + Milliseconds (Window_Ms);
      Samples : Natural := 0;
      Highs   : Natural := 0;
   begin
      loop
         Samples := Samples + 1;
         if ESP32S3.GPIO.Read (Output_Pin) then
            Highs := Highs + 1;
         end if;
         exit when Clock >= Deadline;
      end loop;
      return Float (Highs) / Float (Samples) * 100.0;
   end Measure;

   Measured : Float;
   Ok       : Boolean;

   --  Let the USB-Serial-JTAG console settle before the first line is printed.
   Console_Warmup_Ms : constant Positive := 200;
begin
   delay until Clock + Milliseconds (Console_Warmup_Ms);
   Put_Line ("[sdm] bare-metal SDM sigma-delta density self-test "
             & "(GPIO-sampled, no wiring)");

   declare
      Ch : Channel;
   begin
      Claim (Ch, Test_Channel_Index);
      Configure (Ch, Pin => Output_Pin, Carrier_Hz => Carrier_Frequency_Hz);
      for I in Densities'Range loop
         Set_Density (Ch, Densities (I));
         delay until Clock + Milliseconds (Settle_Ms);
         Measured := Measure (Measure_Window_Ms);
         Ok := abs (Measured - Float (Densities (I))) <= Tolerance_Percent;
         Put ("[sdm] density set=");
         Put (Integer (Float (Densities (I))));
         Put ("%   measured=");
         --  Print one decimal place: scale by 10, render with Put_Fixed's
         --  fixed-point formatter (field 10, one fractional digit).
         Put_Fixed (Integer (Measured * 10.0), 10, 1);
         Put ("%   ");
         Put_Line (if Ok then "PASS" else "FAIL");
      end loop;
   end;                                  --  Ch finalizes -> output low, released

   --  RAII: claim all 8 channels, confirm a 9th fails, reclaim on scope exit.
   declare
      Eight          : Boolean := False;
      Ninth_Rejected : Boolean := False;
      Reclaimed      : Boolean := False;
   begin
      declare
         C0 : Channel;
         C1 : Channel;
         C2 : Channel;
         C3 : Channel;
         C4 : Channel;
         C5 : Channel;
         C6 : Channel;
         C7 : Channel;
         Extra : Channel;
      begin
         Claim (C0, 0);
         Claim (C1, 1);
         Claim (C2, 2);
         Claim (C3, 3);
         Claim (C4, 4);
         Claim (C5, 5);
         Claim (C6, 6);
         Claim (C7, 7);
         Eight := Is_Valid (C0) and then Is_Valid (C7);
         --  All eight are now held, so a ninth claim must fail (invalid handle).
         Claim (Extra, 0);
         Ninth_Rejected := not Is_Valid (Extra);
      end;

      declare
         C : Channel;
      begin
         Claim (C, 0);
         Reclaimed := Is_Valid (C);
      end;

      Put ("[sdm] raii: 8-claimed=");
      Put (if Eight then "y" else "n");
      Put (" 9th-rejected=");
      Put (if Ninth_Rejected then "y" else "n");
      Put (" reclaimed=");
      Put (if Reclaimed then "y" else "n");
      Put ("  ");
      Put_Line (if Eight and Ninth_Rejected and Reclaimed then "PASS" else "FAIL");
   end;

   Put_Line ("[sdm] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
