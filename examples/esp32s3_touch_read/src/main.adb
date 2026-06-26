--  Ada capacitive-touch read self-test (ESP32-S3, no FreeRTOS, no IDF)
--  =================================================================
--  What it demonstrates:
--    The reusable HAL touch driver (ESP32S3.Touch): bring up the touch FSM,
--    scan two channels, and read their raw capacitance counts.  With nothing
--    connected, each pad still reads a stable non-zero baseline (its own
--    self-capacitance), and two different pads read different values -- which
--    proves the capacitance-measuring FSM is running on silicon.
--
--  Build & run:
--    ./x run esp32s3_touch_read
--    Built as the *embedded* profile (build.sh sets ESP32S3_RTS_PROFILE).
--
--  Output:
--    Per-channel raw counts, then two PASS/FAIL lines: the baseline check
--    (counts non-zero + distinct) and the threshold-logic check.  Both say
--    PASS on working silicon; "[touch] done." closes the run.
--
--  Hardware / wiring:
--    None required.  The driver maps channel n to GPIO n; this example scans
--    channel 1 (GPIO1) and channel 3 (GPIO3).  Touch GPIO1's pad to raise its
--    count (interactive only -- not part of the automated PASS check).
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.Touch; use ESP32S3.Touch;
with ESP32S3.GPIO;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  "[touch] channel %d (GPIO%d): raw count = %d\n".
   procedure Chan (Ch, Gpio, Raw : Integer) is
   begin
      Put ("[touch] channel ");
      Put (Ch);
      Put (" (GPIO");
      Put (Gpio);
      Put ("): raw count = ");
      Put (Raw);
      New_Line;
   end Chan;

   --  "[touch] ch1: baseline=%d now=%d  Touched(baseline)=%d "
   --  "Touched(baseline+200k)=%d  %s\n" (the two Touched flags print as 0/1).
   procedure Thresh (Baseline, Now : Integer;
                     Untouched, Shifted, Ok : Boolean) is
   begin
      Put ("[touch] ch1: baseline=");
      Put (Baseline);
      Put (" now=");
      Put (Now);
      Put ("  Touched(baseline)=");
      Put (Boolean'Pos (Untouched));
      Put (" Touched(baseline+200k)=");
      Put (Boolean'Pos (Shifted));
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Thresh;

   --  The two channels we scan.  Channel n is wired to GPIO n, so these are
   --  the pads on GPIO1 and GPIO3.
   First_Channel  : constant Channel := 1;     --  GPIO1
   Second_Channel : constant Channel := 3;     --  GPIO3

   --  Console/USB-JTAG needs a moment to attach before the first line; without
   --  it the opening banner can be lost on a fresh boot.
   Console_Settle : constant Time_Span := Milliseconds (200);

   --  The FSM scans channels on the RTC timer; give it a few scan rounds after
   --  Enable so Read returns a settled count rather than the initial 0.
   FSM_Warmup     : constant Time_Span := Milliseconds (50);
begin
   delay until Clock + Console_Settle;
   Put_Line ("[touch] bare-metal capacitive-touch read self-test (no wiring)");

   Setup;
   Enable (First_Channel);
   Enable (Second_Channel);
   delay until Clock + FSM_Warmup;

   declare
      First_Count  : constant Natural := Read (First_Channel);
      Second_Count : constant Natural := Read (Second_Channel);

      --  A live FSM gives every pad a non-zero count, and two physically
      --  different pads read different values; both must hold to PASS.
      Ok : constant Boolean :=
        First_Count > 0
          and then Second_Count > 0
          and then First_Count /= Second_Count;
   begin
      Chan (Integer (First_Channel),  Natural (Pad (First_Channel)),  First_Count);
      Chan (Integer (Second_Channel), Natural (Pad (Second_Channel)), Second_Count);
      Put ("[touch] baseline counts non-zero + distinct: ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end;

   --  Touch-detection test: capture the untouched baseline, then check the
   --  threshold logic.  Against the real baseline the pad reads "not touched";
   --  against a deliberately-shifted reference it reads "touched" -- proving the
   --  margin comparison.  (A finger raises the real count past the margin.)
   declare
      --  How far the live count must deviate from the reference before Touched
      --  reports a touch.  Sized well above run-to-run baseline noise but below
      --  a real finger's swing.
      Touch_Margin   : constant Natural := 50_000;

      --  Synthetic touch: push the reference this far past the live count so it
      --  clears Touch_Margin with no finger -- emulating what a touch does.
      Touch_Shift    : constant Natural := 200_000;

      Baseline       : constant Natural := Read (First_Channel);

      --  vs. the real baseline: the live count sits within the margin, so this
      --  reads "not touched".
      Touched_At_Base   : constant Boolean :=
        Touched (First_Channel, Baseline, Margin => Touch_Margin);

      --  vs. the shifted reference: the deviation exceeds the margin, so this
      --  reads "touched" -- exercising the positive path.
      Touched_At_Shift  : constant Boolean :=
        Touched (First_Channel, Baseline + Touch_Shift, Margin => Touch_Margin);

      Ok : constant Boolean := not Touched_At_Base and then Touched_At_Shift;
   begin
      Thresh (Baseline, Read (First_Channel),
              Touched_At_Base, Touched_At_Shift, Ok);
   end;

   Put_Line ("[touch] done.");

   --  Self-test is over; park the CPU so the console stays attached for reading.
   declare
      Idle_Period : constant Time_Span := Seconds (3600);
   begin
      loop
         delay until Clock + Idle_Period;
      end loop;
   end;
end Main;
