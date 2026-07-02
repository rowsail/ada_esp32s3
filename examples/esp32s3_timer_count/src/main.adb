--  Ada general-purpose timer self-test on the bare-metal ESP32-S3 (no IDF)
--  =======================================================================
--  What:    Exercises the reusable HAL timer driver (ESP32S3.Timer): run TIMG0's
--           timer at 1 MHz and cross-check its count against the runtime's own
--           wall clock over a fixed delay (the two independent time bases should
--           agree), then verify a one-shot alarm fires at the programmed count.
--           Also checks the controlled (RAII) Timer handle.
--  Build & run:  ./x run esp32s3_timer_count   (built as the embedded profile;
--           build.sh sets ESP32S3_RTS_PROFILE=embedded -- the Timer handle is
--           finalized/controlled, which light-tasking forbids).
--  Output:  three lines -- the banner, the 50 ms count cross-check, and the
--           30 ms one-shot alarm -- each ending PASS:
--             [timer] bare-metal general-purpose timer self-test
--             [timer] 1 MHz count over 50 ms: expected~50000 measured=50015  PASS
--             [timer] alarm@30000: fired=1 at~30001 us  PASS
--             [timer] done.
--           (measured / "at~" values vary run to run; the tolerances pass them).
--  Hardware:  none (self-contained -- the two clocks are both on-chip).
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.Timer; use ESP32S3.Timer;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  Which timer group to drive: 0 = TIMG0, 1 = TIMG1.
   TIMG0 : constant Timer_Index := 0;

   --  Counter clock.  The driver derives the prescaler from the 80 MHz APB clock:
   --  divider = 80_000_000 / Tick_Hz = 80, so each tick is 80 / 80 MHz = 1 us.
   Tick_Rate_Hz : constant := 1_000_000;       --  -> 1 tick = 1 us

   --  Count cross-check: run for this much *runtime* time and expect Tick_Rate_Hz
   --  * 0.050 s = 50_000 ticks back from the (independently clocked) timer.
   Count_Window   : constant Time_Span := Milliseconds (50);
   Expected_Count : constant := 50_000;         --  Tick_Rate_Hz * 0.050 s
   Count_Tol_Frac : constant := 50;             --  pass within Expected/50 = 2 %

   --  One-shot alarm: fire when the counter reaches this tick (30_000 us = 30 ms).
   Alarm_Ticks  : constant := 30_000;          --  30 ms at 1 us/tick
   Alarm_Tol_Us : constant := 5_000;           --  generous slack for the poll loop

   --  Bound the busy-poll waiting for the alarm so a missed alarm can't hang.
   Poll_Guard : constant := 50_000_000;

   --  "[timer] 1 MHz count over 50 ms: expected~%d measured=%d  %s\n".
   procedure Count_Result (Expected, Measured : Integer; Ok : Boolean) is
   begin
      Put ("[timer] 1 MHz count over 50 ms: expected~");
      Put (Expected);
      Put (" measured=");
      Put (Measured);
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Count_Result;

   --  "[timer] alarm@30000: fired=%d at~%d us  %s\n" (fired printed as 0/1).
   procedure Alarm_Result (Fired : Boolean; Elapsed_Us : Integer; Ok : Boolean) is
   begin
      Put ("[timer] alarm@30000: fired=");
      Put (Boolean'Pos (Fired));
      Put (" at~");
      Put (Elapsed_Us);
      Put (" us  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Alarm_Result;

begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[timer] bare-metal general-purpose timer self-test");

   declare
      T : Timer;
   begin
      Claim (T, TIMG0);
      Configure (T, Tick_Hz => Tick_Rate_Hz);    --  1 tick = 1 us

      --  Count test: run for 50 ms of runtime time, expect ~50000 ticks.
      Reset (T);
      Start (T);
      delay until Clock + Count_Window;
      declare
         Measured : constant Ticks := Value (T);
         Ok       : constant Boolean :=
           abs (Integer (Measured) - Expected_Count)
           <= Expected_Count / Count_Tol_Frac;   --  within 2 %
      begin
         Count_Result (Expected_Count, Integer (Measured), Ok);
      end;
      Stop (T);

      --  Alarm test: reset, alarm at 30000 ticks (30 ms), run and wait for it.
      Reset (T);
      Set_Alarm (T, Alarm_Ticks);
      declare
         T0    : constant Time := Clock;
         Guard : Natural := Poll_Guard;
         Fired : Boolean := False;
         Us    : Integer;
      begin
         Start (T);
         while not Fired and then Guard > 0 loop
            Fired := Alarm_Fired (T);
            Guard := Guard - 1;
         end loop;
         Us := Integer (To_Duration (Clock - T0) * 1_000_000.0);
         --  Should fire near 30 ms (30000 us); allow generous slack for the
         --  polling loop and clock granularity.
         Alarm_Result (Fired, Us, Fired and then abs (Us - Alarm_Ticks) <= Alarm_Tol_Us);
         Clear_Alarm (T);
         Stop (T);
      end;
   end;                                  --  T finalizes -> stopped, released

   Put_Line ("[timer] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
