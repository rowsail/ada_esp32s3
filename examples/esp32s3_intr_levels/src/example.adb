pragma Warnings (Off);
with Interfaces.C; use Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;
with Blink;

--  What it demonstrates
--  ---------------------
--  Xtensa interrupt-priority (level) handling and context preservation across
--  the L2 / L3 / L5 vectors.  A low-priority "victim" holds register-resident
--  state across a tight loop: four FP accumulators (the exact identity
--  X := X * Loop_Mul * Loop_Inv, with the two factors read once from Volatile
--  cells so the optimizer keeps them in F registers with NO in-loop memory
--  traffic) plus a THREADPTR sentinel.  Each batch it fires the L2 and L3
--  device interrupts (which preempt it through __gnat_level2_vector /
--  __gnat_level3_vector); the L5 timer tick preempts it asynchronously
--  throughout.  If any vector failed to save/restore the preempted context an
--  accumulator or THREADPTR comes back wrong, and we log 911.
--
--  The level <-> CPU_INT mapping exercised here (the S3 fixes each CPU interrupt
--  at one priority level): L2 = Device_L2_0 = CPU_INT 19, L3 = Device_L3_0 =
--  CPU_INT 23, L5 = the always-firing timer tick.  L4 has no vector on this port
--  (EXCSAVE_4 is scratch for L5); L1 carries no async interrupts here -- see the
--  book ch. "The Context Switch".
--
--  Build & run
--  -----------
--  `./x run esp32s3_intr_levels` -- needs the embedded profile, which the
--  example's build.sh selects (ESP32S3_RTS_PROFILE=embedded): pragma
--  Attach_Handler (the Ada.Interrupts layer) needs the Jorvik interrupt
--  machinery that the configurable full runtime omits.
--
--  Output
--  ------
--  Lines are "[intr] <n>".  Per clean batch three markers print, distinguished
--  by the leading digit (the count is added to a 100_000-spaced base):
--    1xxxxx = cumulative L2 handler count,
--    2xxxxx = cumulative L3 handler count,
--    3xxxxx = clean-batch counter.
--  PASS looks like L2/L3 climbing together with the clean-batch counter, with
--  NO 911 (911 = a vector lost the preempted context).
--
--  Hardware
--  --------
--  None.  The L2/L3 interrupts are software-fired through the FROM_CPU
--  interrupt-matrix sources (see glue.c); the L5 tick is the runtime timer.
procedure Example is
   procedure Log (Marker : Interfaces.C.int);
   pragma Import (C, Log, "ada_log");
   procedure Setup;   pragma Import (C, Setup,   "ada_setup_l2l3");
   procedure Fire_L2; pragma Import (C, Fire_L2, "ada_fire_l2");
   procedure Fire_L3; pragma Import (C, Fire_L3, "ada_fire_l3");
   function  Get_TP return Interfaces.C.unsigned;
   pragma Import (C, Get_TP, "ada_get_tp");
   procedure Set_TP (V : Interfaces.C.unsigned);
   pragma Import (C, Set_TP, "ada_set_tp");

   --  Per-task TLS sentinel written into THREADPTR.  An arbitrary recognizable
   --  value: if a vector clobbers THREADPTR it will not read back as this.
   Sentinel : constant Interfaces.C.unsigned := 16#DEAD_0001#;

   --  Marker bases the console decodes by leading digit (see the Output header):
   --  the live count is added to a 100_000-spaced base.
   L2_Marker_Base    : constant Interfaces.C.int := 100_000;   --  1xxxxx = L2
   L3_Marker_Base    : constant Interfaces.C.int := 200_000;   --  2xxxxx = L3
   Clean_Marker_Base : constant Interfaces.C.int := 300_000;   --  3xxxxx = clean
   Context_Lost      : constant Interfaces.C.int := 911;       --  vector lost ctx

   --  Loop count per batch, and how often within it to fire L2 + L3.
   Batch_Iterations  : constant := 400_000;
   Fire_Interval     : constant := 100_000;

   --  The accumulator identity: each step multiplies by Loop_Mul * Loop_Inv,
   --  which equals 1.0 exactly in IEEE Float (2.0 * 0.5), so a correctly
   --  preserved accumulator returns to its seed after the batch.  Read once from
   --  Volatile cells so the optimizer keeps both factors in F registers and the
   --  loop does NO in-loop memory traffic -- the FP register file is the state a
   --  preempting vector must save/restore.
   Mul_Cell : Float := 2.0 with Volatile;
   Inv_Cell : Float := 0.5 with Volatile;
   Loop_Mul : constant Float := Mul_Cell;
   Loop_Inv : constant Float := Inv_Cell;

   --  Four accumulators, each seeded to a distinct value it must return to.
   Acc_1 : Float := 1.0;
   Acc_2 : Float := 2.0;
   Acc_3 : Float := 3.0;
   Acc_4 : Float := 4.0;

   Clean_Batches : Interfaces.C.int := 0;
begin
   Setup;                       --  route FROM_CPU_0/1 -> CPU_INT 19/23 (L2/L3)
   Set_TP (Sentinel);
   loop
      for I in 1 .. Batch_Iterations loop
         Acc_1 := Acc_1 * Loop_Mul * Loop_Inv;
         Acc_2 := Acc_2 * Loop_Mul * Loop_Inv;
         Acc_3 := Acc_3 * Loop_Mul * Loop_Inv;
         Acc_4 := Acc_4 * Loop_Mul * Loop_Inv;
         if I mod Fire_Interval = 0 then
            Fire_L2;
            Fire_L3;
         end if;
      end loop;

      if Acc_1 /= 1.0 or else Acc_2 /= 2.0 or else Acc_3 /= 3.0
        or else Acc_4 /= 4.0
        or else Get_TP /= Sentinel
      then
         Log (Context_Lost);
         Acc_1 := 1.0;
         Acc_2 := 2.0;
         Acc_3 := 3.0;
         Acc_4 := 4.0;
         Set_TP (Sentinel);
      else
         Clean_Batches := Clean_Batches + 1;
         Log (L2_Marker_Base + Interfaces.C.int (Blink.L2_Count));
         Log (L3_Marker_Base + Interfaces.C.int (Blink.L3_Count));
         Log (Clean_Marker_Base + Clean_Batches);
      end if;
   end loop;
end Example;
