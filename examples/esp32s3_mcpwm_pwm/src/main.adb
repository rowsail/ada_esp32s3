--  Ada MCPWM PWM-output self-test on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  =============================================================================
--
--  What it demonstrates
--  --------------------
--  The reusable HAL motor-control-PWM driver (ESP32S3.MCPWM), exercised across
--  all of its submodules and verified back with NO external wiring: each output
--  pad is sampled with ESP32S3.GPIO.Read in a tight loop over a timed window.
--  Counting high samples gives the duty cycle (a clock-independent ratio);
--  counting rising edges over the measured elapsed time gives the frequency.
--  A generator channel and a capture channel are claimed as limited, controlled
--  RAII handles (Channel / Capture) -- non-copyable and auto-released on scope
--  exit -- so this also exercises the ownership model.  Five tests run: duty,
--  complementary-pair + dead-time, capture, fault-trip and carrier-chopper.
--
--  Build & run
--  -----------
--  ./x run esp32s3_mcpwm_pwm
--  Built as the *embedded* profile (full exceptions, the profile the drivers
--  target -- not the default light tasking); build.sh sets ESP32S3_RTS_PROFILE.
--
--  Output
--  ------
--  One "[mcpwm] ..." line per test, each ending PASS when the measured duty /
--  frequency / overlap land within tolerance, then "[mcpwm] done.".  A run with
--  every line PASS confirms real PWM on silicon.  Report goes through the ROM
--  printf glue (the reliable console path here).
--
--  Hardware / wiring
--  -----------------
--  None -- self-contained (the output pads are sampled internally, not wired).
--  The driver does drive these S3 GPIOs as PWM outputs, so leave them free:
--    GPIO4       duty + capture + fault tests (channel 0)
--    GPIO6/GPIO7 complementary half-bridge pair A/B (channel 1)
--    GPIO10      fault input, driven by us to trip channel 0
--    GPIO9       carrier-chopper output (channel 2)
with Interfaces;   use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.MCPWM;
with ESP32S3.GPIO;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3_Registers.GPIO;   --  snapshot both pair pins in one register read

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the test runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   use ESP32S3.MCPWM;

   procedure Banner is
   begin
      Put_Line ("[mcpwm] bare-metal MCPWM PWM-output self-test "
                & "(GPIO-sampled, no wiring)");
   end Banner;

   procedure Result (Set_Pct, Measured_Pct_X10, Measured_Hz : Integer; Ok : Boolean) is
   begin
      Put ("[mcpwm] duty set=");
      Put (Set_Pct);
      Put ("%  measured=");
      Put_Fixed (Measured_Pct_X10, 10, 1);
      Put ("%  freq=");
      Put (Measured_Hz);
      Put (" Hz  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Result;

   procedure Pair (Duty_A_X10, Duty_B_X10, Overlap_X10 : Integer; Ok : Boolean) is
   begin
      Put ("[mcpwm] pair: A=");
      Put_Fixed (Duty_A_X10, 10, 1);
      Put ("%  B=");
      Put_Fixed (Duty_B_X10, 10, 1);
      Put ("%  overlap=");
      Put_Fixed (Overlap_X10, 10, 1);
      Put ("%  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Pair;

   procedure Capture_Result (Freq_Hz, Duty_X10 : Integer; Ok : Boolean) is
   begin
      Put ("[mcpwm] capture: freq=");
      Put (Freq_Hz);
      Put (" Hz  duty=");
      Put_Fixed (Duty_X10, 10, 1);
      Put ("%  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Capture_Result;

   procedure Fault_Result (Run_Pct, Fault_Pct, Resume_Pct : Integer; Ok : Boolean) is
   begin
      Put ("[mcpwm] fault: run=");
      Put (Run_Pct);
      Put ("%  tripped=");
      Put (Fault_Pct);
      Put ("%  resumed=");
      Put (Resume_Pct);
      Put ("%  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Fault_Result;

   procedure Carrier_Result (Off_Pct, On_Pct : Integer; Ok : Boolean) is
   begin
      Put ("[mcpwm] carrier: off=");
      Put (Off_Pct);
      Put ("%  on=");
      Put (On_Pct);
      Put ("%  ");
      Put_Line (if Ok then "PASS" else "FAIL");
   end Carrier_Result;

   procedure Done is
   begin
      Put_Line ("[mcpwm] done.");
   end Done;

   --  Channel-0 output: duty, capture and fault tests all observe this pad.
   Out_Pin : constant ESP32S3.GPIO.Pin_Id := 4;

   --  PWM carrier frequency for every generator channel.  20 kHz keeps the
   --  period long enough (~50 us) to sample many points per cycle in the
   --  GPIO-read loop, yet above the audible band for a real motor drive.
   Frequency_Hz : constant := 20_000;

   --  Complementary-pair (half-bridge) test pins (A, B) on channel 1.
   Pair_A : constant ESP32S3.GPIO.Pin_Id := 6;
   Pair_B : constant ESP32S3.GPIO.Pin_Id := 7;

   Fault_Pin   : constant ESP32S3.GPIO.Pin_Id := 10;  --  driven by us as the fault
   Carrier_Pin : constant ESP32S3.GPIO.Pin_Id := 9;   --  channel-2 carrier output

   --  Dead-time inserted on each edge of the complementary pair, so the high
   --  and low side of a half-bridge are never on together (no shoot-through).
   --  5 us (10 % of the 50 us period): a sub-microsecond gap is below what the
   --  GPIO-read loop can resolve against a 50 us period, so a small dead-time
   --  reads as spurious overlap; this larger gap is sampled cleanly.  The
   --  dead-time mechanism itself is correct at any value.
   Dead_Time_Ns : constant := 5_000;                  --  5 us

   --  Each pad's duty with the pair at 50 %: 50 % minus the dead-time the driver
   --  trims off each edge (Dead_Time_Ns / period).
   Expected_Pair_Pct : constant Float :=
     50.0 - Float (Dead_Time_Ns) * Float (Frequency_Hz) / 1.0e7;

   --  Duties swept in the first test: a low and a high setting, to prove both
   --  that PWM is generated and that Set_Duty re-targets it at run time.
   Duties : constant array (1 .. 2) of Duty_Percent := (25.0, 75.0);

   --  Pass/fail tolerances.  The GPIO-sampling loop is biased low by a fraction
   --  of a percent (it misses brief states between reads), so the duty windows
   --  are a few percent wide; the timer-based capture test is tighter.
   Duty_Tol_Pct      : constant Float := 4.0;   --  duty test: |measured-set|
   Freq_Tol_Frac     : constant Float := 0.10;  --  duty test: 10 % of frequency
   Pair_Tol_Pct      : constant Float := 6.0;   --  each pad ~50 % (less dead-time)
   Overlap_Max_Pct   : constant Float := 1.0;   --  both-high time must be ~0
   Capture_Freq_Tol_Frac : constant Float := 0.05;  --  capture: 5 % of frequency
   Capture_Duty_Tol_Pct  : constant Float := 3.0;   --  capture: |measured-30 %|
   Fault_Tol_Pct     : constant Float := 6.0;   --  run/resume ~50 %
   Fault_Trip_Max    : constant Float := 2.0;   --  tripped output ~0 %

   --  Claimed channel handles (declared up front so the nested helpers below can
   --  see the capture handle).  Each is released automatically when Main returns.
   Generator0 : Channel;     --  channel 0 -> Out_Pin (duty + capture + fault tests)
   Generator1 : Channel;     --  channel 1 -> complementary pair
   Generator2 : Channel;     --  channel 2 -> carrier test
   Capture_Channel : Capture; --  capture channel 0 -> Out_Pin

   --  Sample the (driver-driven) output pad for Window_Ms; return the high-sample
   --  fraction as a duty %, and rising-edges / elapsed-time as a frequency.
   procedure Measure (Window_Ms : Positive; Duty_Pct, Freq_Hz : out Float) is
      T0      : constant Time := Clock;
      Deadline : constant Time := T0 + Milliseconds (Window_Ms);
      Samples, Highs, Rising : Natural := 0;
      Current  : Boolean;
      Previous : Boolean := False;
      Elapsed_Seconds : Float;
   begin
      loop
         Current := ESP32S3.GPIO.Read (Out_Pin);
         Samples := Samples + 1;
         if Current then
            Highs := Highs + 1;
            if not Previous then
               Rising := Rising + 1;
            end if;
         end if;
         Previous := Current;
         exit when Clock >= Deadline;
      end loop;
      Elapsed_Seconds := Float (To_Duration (Clock - T0));
      Duty_Pct := (if Samples = 0 then 0.0
                   else Float (Highs) / Float (Samples) * 100.0);
      Freq_Hz  := (if Elapsed_Seconds = 0.0 then 0.0
                   else Float (Rising) / Elapsed_Seconds);
   end Measure;

   --  Sample a complementary pair: per-pad duty and the fraction of time BOTH
   --  pads are high (which the dead-time should keep at ~0).
   procedure Measure_Pair (Window_Ms : Positive;
                           Duty_A, Duty_B, Overlap : out Float)
   is
      use type ESP32S3_Registers.UInt32;
      Deadline : constant Time := Clock + Milliseconds (Window_Ms);
      Mask_A   : constant ESP32S3_Registers.UInt32 := 2 ** Natural (Pair_A);
      Mask_B   : constant ESP32S3_Registers.UInt32 := 2 ** Natural (Pair_B);
      Samples, Highs_A, Highs_B, Both : Natural := 0;
      Snap   : ESP32S3_Registers.UInt32;
      A_High, B_High : Boolean;
   begin
      loop
         --  Snapshot both pads in ONE input-register read so A and B are sampled
         --  at the SAME instant (the principled way to measure simultaneous
         --  "both high"; two separate GPIO reads would skew by a few cycles).
         Snap   := ESP32S3_Registers.GPIO.GPIO_Periph.IN_k;
         A_High := (Snap and Mask_A) /= 0;
         B_High := (Snap and Mask_B) /= 0;
         Samples := Samples + 1;
         if A_High then
            Highs_A := Highs_A + 1;
         end if;
         if B_High then
            Highs_B := Highs_B + 1;
         end if;
         if A_High and B_High then       --  both high at once: a dead-time miss
            Both := Both + 1;
         end if;
         exit when Clock >= Deadline;
      end loop;
      Duty_A  := Float (Highs_A) / Float (Samples) * 100.0;
      Duty_B  := Float (Highs_B) / Float (Samples) * 100.0;
      Overlap := Float (Both)    / Float (Samples) * 100.0;
   end Measure_Pair;

   --  High fraction of any (driven) output pad over a window.
   function Duty_Of (Pin : ESP32S3.GPIO.Pin_Id; Window_Ms : Positive) return Float is
      Deadline : constant Time := Clock + Milliseconds (Window_Ms);
      Samples, Highs : Natural := 0;
   begin
      loop
         Samples := Samples + 1;
         if ESP32S3.GPIO.Read (Pin) then
            Highs := Highs + 1;
         end if;
         exit when Clock >= Deadline;
      end loop;
      return Float (Highs) / Float (Samples) * 100.0;
   end Duty_Of;

   --  Measure Out_Pin precisely with the capture submodule: ticks (80 MHz) for
   --  one full period (rising->rising) and the high time (rising->falling).
   procedure Capture_Measure (Period, High : out Natural) is
      --  Collect three timestamps from the capture FIFO -- a rising edge, the
      --  following falling edge, then the next rising edge -- to bracket exactly
      --  one period (rising->rising) and one high time (rising->falling).
      Stamp   : Unsigned_32;       --  one capture timestamp (80 MHz ticks)
      Falling : Boolean;           --  edge of the captured event

      First_Rise, Fall, Next_Rise : Unsigned_32 := 0;
      Got_First_Rise, Got_Fall, Got_Next_Rise : Boolean := False;

      --  Spin bound so a stalled / disconnected capture can't hang the test.
      Spin_Limit : constant Natural := 5_000_000;
      Guard      : Natural := Spin_Limit;
   begin
      while Capture_Pending (Capture_Channel) loop   --  drain stale captures
         Read_Capture (Capture_Channel, Stamp, Falling);
      end loop;
      loop
         if Capture_Pending (Capture_Channel) then
            Read_Capture (Capture_Channel, Stamp, Falling);
            if not Got_First_Rise and then not Falling then
               First_Rise := Stamp;
               Got_First_Rise := True;
            elsif Got_First_Rise and then not Got_Fall and then Falling then
               Fall := Stamp;
               Got_Fall := True;
            elsif Got_Fall and then not Got_Next_Rise and then not Falling then
               Next_Rise := Stamp;
               Got_Next_Rise := True;
            end if;
         end if;
         exit when Got_Next_Rise or else Guard = 0;
         Guard := Guard - 1;
      end loop;
      Period := Natural (Next_Rise - First_Rise);  --  modular sub handles a wrap
      High   := Natural (Fall - First_Rise);
   end Capture_Measure;

   Measured_Duty, Measured_Freq : Float;
   Duty_A, Duty_B, Overlap   : Float;
   Ok                        : Boolean;
begin
   delay until Clock + Milliseconds (200);   --  let the USB console settle first
   Banner;

   Claim (Generator0, MCPWM0, Ch0);   --  first Claim brings up the MCPWM0 clock
   Configure_Channel (Generator0, Freq => Frequency_Hz, Pin => Out_Pin);
   Start (Generator0);

   for I in Duties'Range loop
      Set_Duty (Generator0, Duties (I));
      delay until Clock + Milliseconds (5);     --  let the new duty latch
      Measure (50, Measured_Duty, Measured_Freq);

      Ok := abs (Measured_Duty - Float (Duties (I))) <= Duty_Tol_Pct
              and then
            abs (Measured_Freq - Float (Frequency_Hz))
              <= Float (Frequency_Hz) * Freq_Tol_Frac;

      Result (Integer (Float (Duties (I))), Integer (Measured_Duty * 10.0),
              Integer (Measured_Freq), Ok);
   end loop;

   --  Complementary pair + dead-time on channel 1: A on Pair_A, inverted B on
   --  Pair_B, with 1 us of dead-time, at 50 % duty.  Expect A and B each ~50 %
   --  (minus the dead-time gap) and ~0 % overlap -- the dead-time guarantees the
   --  two are never high together.
   Claim (Generator1, MCPWM0, Ch1);
   Configure_Channel (Generator1, Freq => Frequency_Hz, Pin => Pair_A,
                      Complement_Pin => Pair_B, Dead_Time_Ns => Dead_Time_Ns);
   Start (Generator1);
   Set_Duty (Generator1, 50.0);
   delay until Clock + Milliseconds (5);
   Measure_Pair (50, Duty_A, Duty_B, Overlap);
   Ok := abs (Duty_A - Expected_Pair_Pct) <= Pair_Tol_Pct  --  A: 50 % less dead-time
           and then abs (Duty_B - Expected_Pair_Pct) <= Pair_Tol_Pct  --  B: complement
           and then Overlap < Overlap_Max_Pct;          --  never both high
   Pair (Integer (Duty_A * 10.0), Integer (Duty_B * 10.0),
         Integer (Overlap * 10.0), Ok);

   ----------------------------------------------------------------------------
   --  Test 3: CAPTURE -- feed channel 0's own output (Out_Pin) into capture 0
   --  on the same pad and measure period + high precisely (80 MHz timer).
   ----------------------------------------------------------------------------
   Set_Duty (Generator0, 30.0);
   Claim (Capture_Channel, MCPWM0, Cap0);
   Configure_Capture (Capture_Channel, Pin => Out_Pin, Edge => Both_Edges);
   delay until Clock + Milliseconds (5);
   declare
      Period, High      : Natural;       --  80 MHz timer ticks
      Capture_Freq, Capture_Duty : Float;
   begin
      Capture_Measure (Period, High);
      Capture_Freq := (if Period = 0 then 0.0
                       else Float (Capture_Clock_Hz) / Float (Period));
      Capture_Duty := (if Period = 0 then 0.0
                       else Float (High) / Float (Period) * 100.0);
      Ok := abs (Capture_Freq - Float (Frequency_Hz))
              <= Float (Frequency_Hz) * Capture_Freq_Tol_Frac
              and then abs (Capture_Duty - 30.0) <= Capture_Duty_Tol_Pct;
      Capture_Result (Integer (Capture_Freq), Integer (Capture_Duty * 10.0), Ok);
   end;

   ----------------------------------------------------------------------------
   --  Test 4: FAULT -- drive Fault_Pin and trip channel 0 (force low, one-shot).
   --  Running ~50 %, forced ~0 % while asserted, ~50 % again after Clear_Fault.
   ----------------------------------------------------------------------------
   ESP32S3.GPIO.Configure (Fault_Pin, ESP32S3.GPIO.Output);
   ESP32S3.GPIO.Clear (Fault_Pin);                       --  inactive (no fault)
   Configure_Fault (MCPWM0, Fault0, Pin => Fault_Pin, Active_High => True);
   Protect_Channel (Generator0, Fault0, One_Shot, Force_Low);
   Set_Duty (Generator0, 50.0);
   delay until Clock + Milliseconds (2);
   declare
      Run, Trip, Resume : Float;
   begin
      Run := Duty_Of (Out_Pin, 20);
      ESP32S3.GPIO.Set (Fault_Pin);                      --  assert the fault
      delay until Clock + Milliseconds (2);
      Trip := Duty_Of (Out_Pin, 20);
      ESP32S3.GPIO.Clear (Fault_Pin);                    --  deassert ...
      Clear_Fault (Generator0);                          --  ... and release the latch
      delay until Clock + Milliseconds (2);
      Resume := Duty_Of (Out_Pin, 20);
      Ok := abs (Run - 50.0) <= Fault_Tol_Pct
              and then Trip < Fault_Trip_Max
              and then abs (Resume - 50.0) <= Fault_Tol_Pct;
      Fault_Result (Integer (Run), Integer (Trip), Integer (Resume), Ok);
   end;

   ----------------------------------------------------------------------------
   --  Test 5: CARRIER -- channel 2 at 100 % duty: constant high with the carrier
   --  off, chopped to the carrier's own duty (~50 %) with it on.
   ----------------------------------------------------------------------------
   Claim (Generator2, MCPWM0, Ch2);
   Configure_Channel (Generator2, Freq => Frequency_Hz, Pin => Carrier_Pin);
   Start (Generator2);
   Set_Duty (Generator2, 100.0);
   delay until Clock + Milliseconds (2);
   declare
      --  Carrier (chopper) settings: a high-frequency square wave that the
      --  output is AND-ed with.  Prescale divides the 160 MHz source; the carrier
      --  duty is set in eighths (4/8 = 50 %), so a 100 %-duty channel is chopped
      --  down to ~50 % at the pad.  First_Pulse => 0 starts every cycle chopped.
      Carrier_Prescale     : constant := 15;   --  160 MHz / (15+1) carrier clock
      Carrier_Duty_Eighths : constant := 4;    --  4/8 = 50 % chopper duty
      Carrier_First_Pulse  : constant := 0;    --  no wider leading pulse

      Carrier_Off_Min_Pct : constant Float := 95.0;   --  off: near 100 %
      Carrier_On_Min_Pct  : constant Float := 30.0;   --  on: chopped to ~50 %,
      Carrier_On_Max_Pct  : constant Float := 70.0;   --  accepted 30 .. 70 %

      Off, On : Float;
   begin
      Off := Duty_Of (Carrier_Pin, 20);                  --  ~100 %
      Set_Carrier (Generator2, Enable => True,
                   Prescale     => Carrier_Prescale,
                   Duty_Eighths => Carrier_Duty_Eighths,
                   First_Pulse  => Carrier_First_Pulse);
      delay until Clock + Milliseconds (2);
      On := Duty_Of (Carrier_Pin, 20);                   --  chopped -> ~50 %
      Ok := Off > Carrier_Off_Min_Pct
              and then On in Carrier_On_Min_Pct .. Carrier_On_Max_Pct;
      Carrier_Result (Integer (Off), Integer (On), Ok);
   end;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
