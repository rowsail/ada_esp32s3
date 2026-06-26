--  Ada LEDC PWM self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  =======================================================================
--  What it demonstrates
--  --------------------
--  The reusable LED/PWM-controller HAL (ESP32S3.LEDC): it generates PWM and
--  measures it back with NO external wiring -- the channel's output pad is
--  sampled with ESP32S3.GPIO.Read in a tight loop over a timed window (high
--  samples / total = duty, rising edges / elapsed = frequency).  It also
--  exercises the controlled (RAII) Channel handle: claim all 8, confirm a 9th
--  is rejected, and prove reclamation on scope exit.
--
--  Build & run
--  -----------
--      ./x run esp32s3_ledc_pwm
--  Embedded profile (build.sh sets ESP32S3_RTS_PROFILE=embedded); the Channel
--  uses finalization, which light-tasking forbids, so this is embedded/full.
--
--  How to read the output
--  ----------------------
--  One "[ledc] duty set=..." line per duty: measured duty and frequency, then
--  PASS if both land within tolerance (duty +/-4 %, freq +/-10 %).  The "[ledc]
--  raii:" line PASSes when all 8 claims succeed, the 9th is rejected, and a
--  fresh claim succeeds after the handles leave scope.  "[ledc] done." last.
--
--  Hardware / wiring
--  -----------------
--  None (self-contained).  The driver toggles GPIO4 and this same pin is read
--  back internally; nothing need be connected.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.LEDC;  use ESP32S3.LEDC;
with ESP32S3.GPIO;
with ESP32S3.Log;   use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the test runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   procedure Banner is
   begin
      Put_Line ("[ledc] bare-metal LEDC PWM self-test (GPIO-sampled, no wiring)");
   end Banner;

   procedure Result (Set_Pct, Meas_Pct_X10, Meas_Hz : Integer; Ok : Boolean) is
   begin
      Put ("[ledc] duty set=");
      Put (Set_Pct);
      Put ("%   measured=");
      Put_Fixed (Meas_Pct_X10, 10, 1);
      Put ("%   freq=");
      Put (Meas_Hz);
      Put (" Hz  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Result;

   procedure Raii_Result (Eight, Ninth, Reclaimed, Ok : Boolean) is
   begin
      Put ("[ledc] raii: 8-claimed=");
      Put (if Eight then "y" else "n");
      Put (" 9th-rejected=");
      Put (if Ninth then "y" else "n");
      Put (" reclaimed=");
      Put (if Reclaimed then "y" else "n");
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Raii_Result;

   procedure Done is
   begin
      Put_Line ("[ledc] done.");
   end Done;

   --  GPIO pin the LEDC channel drives and that we sample back (no wiring: the
   --  driver toggles this pad and GPIO.Read reads the same pad internally).
   Output_Pin : constant ESP32S3.GPIO.Pin_Id := 4;

   --  PWM frequency, in Hz.  5 kHz is well above the flicker threshold for an
   --  LED and low enough that a 10-bit duty resolution still fits under the
   --  80 MHz APB clock (the Q10.8 timer divider covers it without saturating).
   Frequency_Hz : constant := 5_000;

   --  Duty resolution, in bits: 10 bits -> 1024 duty steps (0 .. 1023).
   Duty_Resolution_Bits : constant := 10;

   --  Duty cycles to sweep, as percentages.  25 % and 75 % read back as
   --  distinct values, proving real PWM and that Set_Duty changes it at run time.
   Duties : constant array (1 .. 2) of Duty_Percent := (25.0, 75.0);

   --  Measurement window, in ms: long enough to count many PWM periods (5 kHz
   --  -> ~250 periods in 50 ms) so the high-sample fraction is a stable duty.
   Measure_Window_Ms : constant := 50;

   --  Settle delay, in ms, after changing the duty before we measure it.
   Duty_Settle_Ms : constant := 5;

   --  Delay, in ms, before the first console line (lets the USB-Serial-JTAG
   --  link enumerate so the banner is not lost).
   Startup_Delay_Ms : constant := 200;

   --  Pass tolerances: measured duty within this many percentage points, and
   --  measured frequency within this fraction, of the configured value.
   Duty_Tolerance_Pct  : constant := 4.0;
   Freq_Tolerance_Frac : constant := 0.10;

   --  Idle-loop hop length, in seconds: park core 0 in long sleeps once the
   --  test is done (the value is arbitrary; it just must not return).
   Idle_Hop_Seconds : constant := 3600;

   --  Sample the (driver-driven) output pad for Window_Ms; return the high-sample
   --  fraction as a duty %, and rising-edges / elapsed-time as a frequency.
   procedure Measure (Pin : ESP32S3.GPIO.Pin_Id; Window_Ms : Positive;
                      Duty_Pct, Freq_Hz : out Float)
   is
      T0       : constant Time := Clock;
      Deadline : constant Time := T0 + Milliseconds (Window_Ms);
      Samples, Highs, Rising : Natural := 0;
      Cur  : Boolean;
      Prev : Boolean := False;
      Secs : Float;
   begin
      loop
         Cur := ESP32S3.GPIO.Read (Pin);
         Samples := Samples + 1;
         if Cur then
            Highs := Highs + 1;
            if not Prev then
               Rising := Rising + 1;
            end if;
         end if;
         Prev := Cur;
         exit when Clock >= Deadline;
      end loop;
      Secs := Float (To_Duration (Clock - T0));
      Duty_Pct := (if Samples = 0 then 0.0
                   else Float (Highs) / Float (Samples) * 100.0);
      Freq_Hz  := (if Secs = 0.0 then 0.0 else Float (Rising) / Secs);
   end Measure;

   D, F : Float;
   Ok   : Boolean;
begin
   --  Let the console settle before the first line (USB-Serial-JTAG enumerate).
   delay until Clock + Milliseconds (Startup_Delay_Ms);
   Banner;

   --  PWM test on channel 0 at 5 kHz, 10-bit, sampled at 25 % and 75 %.
   declare
      Ch0 : Channel;
   begin
      Claim (Ch0, 0);                    --  own channel 0
      Configure (Ch0,
                 Freq => Frequency_Hz,
                 Pin  => Output_Pin,
                 Bits => Duty_Resolution_Bits);
      for I in Duties'Range loop
         Set_Duty (Ch0, Duties (I));
         delay until Clock + Milliseconds (Duty_Settle_Ms);
         Measure (Output_Pin, Measure_Window_Ms, D, F);
         Ok := abs (D - Float (Duties (I))) <= Duty_Tolerance_Pct
                 and then
               abs (F - Float (Frequency_Hz))
                 <= Float (Frequency_Hz) * Freq_Tolerance_Frac;
         Result (Integer (Float (Duties (I))), Integer (D * 10.0), Integer (F),
                 Ok);
      end loop;
   end;                                  --  Ch0 finalizes -> output stopped, freed

   --  RAII: claim all 8, confirm a 9th fails, then prove reclamation on scope exit.
   declare
      All_Eight_Claimed : Boolean := False;
      Ninth_Rejected    : Boolean := False;
      Reclaimed         : Boolean := False;
   begin
      declare
         C0    : Channel;
         C1    : Channel;
         C2    : Channel;
         C3    : Channel;
         C4    : Channel;
         C5    : Channel;
         C6    : Channel;
         C7    : Channel;
         Extra : Channel;               --  the over-claim (9th) -- must be rejected
      begin
         Claim (C0, 0);
         Claim (C1, 1);
         Claim (C2, 2);
         Claim (C3, 3);
         Claim (C4, 4);
         Claim (C5, 5);
         Claim (C6, 6);
         Claim (C7, 7);
         --  First and last handle valid -> the whole pool was handed out.
         All_Eight_Claimed := Is_Valid (C0) and then Is_Valid (C7);
         Claim (Extra, 0);              --  channel 0 already taken: no free channel
         Ninth_Rejected := not Is_Valid (Extra);
      end;                              --  all finalize -> freed

      --  After the pool emptied, a fresh claim of channel 0 must succeed again.
      declare
         C : Channel;
      begin
         Claim (C, 0);
         Reclaimed := Is_Valid (C);
      end;

      Raii_Result (All_Eight_Claimed, Ninth_Rejected, Reclaimed,
                   All_Eight_Claimed and Ninth_Rejected and Reclaimed);
   end;

   Done;

   --  Test finished: park core 0 forever (sleep in long hops) so the monitor
   --  keeps the console open without the program returning.
   loop
      delay until Clock + Seconds (Idle_Hop_Seconds);
   end loop;
end Main;
