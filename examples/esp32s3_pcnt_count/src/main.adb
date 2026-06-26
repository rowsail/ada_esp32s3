--  Ada PCNT self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  ===================================================================
--  What it demonstrates:
--    The reusable HAL PCNT driver (ESP32S3.PCNT).  A GPIO is software-toggled a
--    known number of times and that SAME pad is routed into a PCNT unit (the
--    GPIO matrix feeds the pad into the counter input -- no wiring); the counted
--    edges are compared to the number driven.  Also checks the controlled (RAII)
--    Unit handle: claim all four units, confirm a fifth claim is rejected, then
--    confirm a unit is reusable once its handle leaves scope.
--
--  Build & run:
--    ./x run esp32s3_pcnt_count
--    Needs the embedded profile (the controlled Unit handle uses finalization,
--    which light-tasking forbids); build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  Output (PASS looks like):
--    [pcnt] bare-metal PCNT pulse-counter self-test (no wiring)
--    [pcnt] count: pulses-driven=100 counted=100  PASS
--    [pcnt] raii: 4-claimed=y 5th-rejected=y reclaimed=y  PASS
--    [pcnt] done.
--
--  Hardware / wiring:
--    None (self-contained).  GPIO4 is both the software-driven output and the
--    PCNT input -- the GPIO matrix loops the pad back into the counter on-chip,
--    so no external wire or pulse source is needed.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.PCNT;  use ESP32S3.PCNT;
with ESP32S3.GPIO;
with ESP32S3.Log;   use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   procedure Banner is
   begin
      Put_Line ("[pcnt] bare-metal PCNT pulse-counter self-test (no wiring)");
   end Banner;

   procedure Result (Pulses, Counted : Integer; Ok : Boolean) is
   begin
      Put ("[pcnt] count: pulses-driven=");
      Put (Pulses);
      Put (" counted=");
      Put (Counted);
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Result;

   procedure Raii_Result (Four, Fifth, Reclaimed, Ok : Boolean) is
   begin
      Put ("[pcnt] raii: 4-claimed=");
      Put (if Four then "y" else "n");
      Put (" 5th-rejected=");
      Put (if Fifth then "y" else "n");
      Put (" reclaimed=");
      Put (if Reclaimed then "y" else "n");
      Put ("  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Raii_Result;

   procedure Done is
   begin
      Put_Line ("[pcnt] done.");
   end Done;

   --  The pad that is both the software-driven output and the PCNT input; the
   --  GPIO matrix loops it back into the counter on-chip (no external wiring).
   Input_Pin : constant ESP32S3.GPIO.Pin_Id := 4;

   --  PCNT unit (of the four, 0 .. 3) used for the counting test.
   Counting_Unit : constant Unit_Index := 0;

   --  Number of clean high pulses driven; the counter must read back exactly
   --  this many.
   Pulse_Count : constant := 100;

   --  Settle delay held at each level.  A few microseconds is long enough that
   --  the PCNT glitch filter accepts the edge as a real pulse rather than noise.
   Level_Hold : constant Time_Span := Microseconds (20);

   --  Let the USB-Serial-JTAG console enumerate before the first banner line.
   Console_Warmup : constant Time_Span := Milliseconds (200);

   --  Park forever after the report (re-arming each hour) so the console output
   --  stays put for the monitor.
   Idle_Interval : constant Time_Span := Seconds (3600);

   procedure Settle is
   begin
      delay until Clock + Level_Hold;
   end Settle;
begin
   delay until Clock + Console_Warmup;
   Banner;

   --  Counting test: drive the pin low, then Pulse_Count clean high pulses, and
   --  count the rising edges.
   declare
      Counter : Unit;
      Counted : Integer;
      Ok      : Boolean;
   begin
      ESP32S3.GPIO.Configure (Input_Pin, ESP32S3.GPIO.Output);
      ESP32S3.GPIO.Clear (Input_Pin);
      Claim (Counter, Counting_Unit);
      Configure (Counter, Pin => Input_Pin);   --  default: count rising edges
      Settle;

      for Pulse in 1 .. Pulse_Count loop
         ESP32S3.GPIO.Set (Input_Pin);         --  rising edge -> counter +1
         Settle;
         ESP32S3.GPIO.Clear (Input_Pin);       --  falling edge (not counted)
         Settle;
      end loop;

      Counted := Count (Counter);
      Ok      := (Counted = Pulse_Count);
      Result (Pulse_Count, Counted, Ok);
   end;                                  --  Counter finalizes -> paused, released

   --  RAII: claim all 4 units, confirm a 5th fails, then reclaim on scope exit.
   declare
      Four, Fifth_Rejected, Reclaimed : Boolean := False;
   begin
      declare
         U0, U1, U2, U3, Extra : Unit;
      begin
         Claim (U0, 0);
         Claim (U1, 1);
         Claim (U2, 2);
         Claim (U3, 3);
         Four := Is_Valid (U0) and then Is_Valid (U1)
                   and then Is_Valid (U2) and then Is_Valid (U3);
         Claim (Extra, 0);
         Fifth_Rejected := not Is_Valid (Extra);
      end;

      declare
         U : Unit;
      begin
         Claim (U, 0);
         Reclaimed := Is_Valid (U);
      end;

      Raii_Result (Four, Fifth_Rejected, Reclaimed,
                   Four and Fifth_Rejected and Reclaimed);
   end;

   Done;

   loop
      delay until Clock + Idle_Interval;
   end loop;
end Main;
