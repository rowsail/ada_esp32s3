pragma Warnings (Off);
with Interfaces.C;  use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;
with Blink;
with Intr_Vector_Test; use Intr_Vector_Test;   --  L2/L3 fire + THREADPTR + Log (was glue.c)

--  What it demonstrates
--  --------------------
--  pragma Attach_Handler (on a protected object, reached through Ada.Interrupts)
--  building AND running under the FULL runtime profile -- the full-profile twin
--  of esp32s3_intr_levels.  On the `full` profile GNAT lowers an interrupt PO to
--  the full dynamic machinery (System.Interrupts.Register_Interrupt_Handler);
--  until the bare-board full System.Interrupts existed
--  (crates/esp32s3_rts/full_overlay/gnarl/s-interr.{ads,adb}) Blink failed to
--  build on full with "Register_Interrupt_Handler not defined".  Blink's two
--  library-level interrupt POs (see blink.adb) attach with pragma Attach_Handler
--  exactly as on embedded; if this links and the counts climb on hardware, the
--  full dynamic interrupt path is in place.
--
--  The test body is identical to the embedded version, so it also re-checks
--  interrupt-vector context preservation under the full kernel.  A low-priority
--  "victim" holds register-resident state across a tight loop -- four FP
--  accumulators (the identity X := X * Loop_Mul * Loop_Inv, with both factors
--  read once from Volatile cells so the optimizer keeps them in F registers with NO in-loop
--  memory traffic) plus a THREADPTR sentinel.  Each batch it fires the L2 and L3
--  device interrupts (which preempt it through __gnat_level2_vector /
--  __gnat_level3_vector); the L5 tick preempts it asynchronously throughout.  If
--  any vector failed to save/restore the preempted context, an accumulator or
--  THREADPTR comes back wrong and we log 911.
--
--  Build & run
--  -----------
--      ./x run full_intr        --  full profile; build.sh sets
--                                   ESP32S3_RTS_PROFILE=full
--
--  Output  ([intr] <n>)
--  --------------------
--  Per clean batch: 1xxxxx = L2 handler count, 2xxxxx = L3 handler count,
--  3xxxxx = clean-batch counter.  PASS = all three climbing together with NO
--  911 (911 = context lost: an accumulator or THREADPTR came back wrong).
--
--  Hardware
--  --------
--  None (self-contained).  The L2/L3 interrupts are fired in software via the
--  FROM_CPU interrupt-matrix sources -- no external wiring.

procedure Example is

   --  Console-marker bases: the C ada_log prints the integer as "[intr] <n>",
   --  so adding the live count to one of these tags the line (1xxxxx / 2xxxxx /
   --  3xxxxx) without any extra formatting.  Must stay >= the largest count so
   --  the leading digit is never carried away.
   L2_Marker_Base    : constant Interfaces.C.int := 100_000;  --  1xxxxx = L2
   L3_Marker_Base    : constant Interfaces.C.int := 200_000;  --  2xxxxx = L3
   Clean_Marker_Base : constant Interfaces.C.int := 300_000;  --  3xxxxx = clean
   Context_Lost      : constant Interfaces.C.int := 911;      --  context lost

   --  THREADPTR sentinel: an arbitrary recognizable value parked in the
   --  per-task TP register before the loop and re-read after, to catch a vector
   --  that clobbered it.
   Sentinel : constant Interfaces.C.unsigned := 16#DEAD_0001#;

   --  Loop factors: Loop_Mul * Loop_Inv = 1.0 exactly (2.0 * 0.5), so each
   --  accumulator is an identity over the batch and must return to its seed.
   --  Read from Volatile cells so the compiler cannot fold the loop away.
   Mul_Cell : Float := 2.0
   with Volatile;
   Inv_Cell : Float := 0.5
   with Volatile;
   Loop_Mul : constant Float := Mul_Cell;
   Loop_Inv : constant Float := Inv_Cell;

   --  Four FP accumulators with distinct seeds -- each must come back to its
   --  seed (1.0 / 2.0 / 3.0 / 4.0) after a clean batch.
   X1 : Float := 1.0;
   X2 : Float := 2.0;
   X3 : Float := 3.0;
   X4 : Float := 4.0;

   --  Batch loop length and the period at which the L2/L3 interrupts are fired
   --  within it (every 100_000 iterations => 4 fire-points per batch).
   Batch_Iterations : constant := 400_000;
   Fire_Period      : constant := 100_000;

   Clean_Batches : Interfaces.C.int := 0;    --  clean-batch counter
begin
   Setup;                       --  route FROM_CPU_0/1 -> CPU_INT 19/23 (L2/L3)
   Set_TP (Sentinel);
   loop
      for I in 1 .. Batch_Iterations loop
         X1 := X1 * Loop_Mul * Loop_Inv;
         X2 := X2 * Loop_Mul * Loop_Inv;
         X3 := X3 * Loop_Mul * Loop_Inv;
         X4 := X4 * Loop_Mul * Loop_Inv;
         if I mod Fire_Period = 0 then
            Fire_L2;
            Fire_L3;
         end if;
      end loop;

      if X1 /= 1.0 or else X2 /= 2.0 or else X3 /= 3.0 or else X4 /= 4.0 or else Get_TP /= Sentinel
      then
         Log (Context_Lost);
         X1 := 1.0;
         X2 := 2.0;
         X3 := 3.0;
         X4 := 4.0;
         Set_TP (Sentinel);
      else
         Clean_Batches := Clean_Batches + 1;
         Log (L2_Marker_Base + Interfaces.C.int (Blink.L2_Count));
         Log (L3_Marker_Base + Interfaces.C.int (Blink.L3_Count));
         Log (Clean_Marker_Base + Clean_Batches);
      end if;
   end loop;
end Example;
