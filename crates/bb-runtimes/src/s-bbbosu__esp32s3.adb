------------------------------------------------------------------------------
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                S Y S T E M . B B . B O A R D _ S U P P O R T             --
--                                  B o d y                                 --
--                                                                          --
--  Xtensa LX7 (ESP32-S3) port.                                            --
--                                                                          --
--  Clock/alarm use the Xtensa CCOUNT (free-running cycle counter) and      --
--  CCOMPARE0 (internal timer 0 -> interrupt 6, level 1).  ESP-IDF's        --
--  FreeRTOS tick runs off the systimer, so all CCOMPAREn are free.  The    --
--  CCOMPARE0 interrupt is registered through ESP-IDF's low-level CPU        --
--  interrupt dispatch (esp_cpu_intr_set_handler, in glue.c) and routed to  --
--  System.BB.Interrupts.Interrupt_Wrapper, which runs the alarm handler    --
--  and performs the context switch on return.  (Coexistence step toward    --
--  a full FreeRTOS handoff.)                                               --
------------------------------------------------------------------------------

pragma Restrictions (No_Elaboration_Code);

with Interfaces;                  use Interfaces;
with System.Machine_Code;         use System.Machine_Code;
with System.BB.Parameters;
with System.BB.CPU_Primitives;
with System.BB.CPU_Primitives.Multiprocessors;
with System.BB.Threads.Queues;

package body System.BB.Board_Support is

   use System.Multiprocessors;

   Alarm_Interrupt_ID : constant System.BB.Interrupts.Interrupt_ID := 16;
   --  CCOMPARE2 raises Xtensa internal interrupt 16 (level 5).  We OWN the
   --  level-5 vector (xt_highint5, in the application's startup glue), so the
   --  interrupt entry/exit and the context switch are fully native (no
   --  ESP-IDF interrupt dispatch).  The vector saves the interrupted context,
   --  calls __gnat_timer_interrupt below, then restores + RFE.

   Alarm_Interrupt_Bit  : constant Unsigned_32 := 2 ** 16;  --  CCOMPARE2/int16
   Poke_Interrupt_Bit   : constant Unsigned_32 := 2 ** 31;  --  CPU_INT 31 (L5)
   Device_Interrupt_Id  : constant := 23;                   --  CPU_INT 23 (L3)
   Device_Interrupt_Bit : constant Unsigned_32 := 2 ** Device_Interrupt_Id;

   --  Level-2 device interrupt slots (CPU_INT 19/20/21 = Device_L2_0/1/2).
   L2_0_Id  : constant System.BB.Interrupts.Interrupt_ID := 19;
   L2_1_Id  : constant System.BB.Interrupts.Interrupt_ID := 20;
   L2_2_Id  : constant System.BB.Interrupts.Interrupt_ID := 21;
   L2_0_Bit : constant Unsigned_32 := 2 ** 19;
   L2_1_Bit : constant Unsigned_32 := 2 ** 20;
   L2_2_Bit : constant Unsigned_32 := 2 ** 21;
   --  The single level-5 vector serves both the timer (CCOMPARE2) and the
   --  cross-core poke; Timer_Interrupt reads the INTERRUPT register to see
   --  which fired.  The poke is a FROM_CPU matrix source routed to CPU_INT 31
   --  on each core (set up in glue.c); CPU_INT 31 is level-triggered, so the
   --  handler deasserts it by clearing the FROM_CPU source register.

   type Reg32 is mod 2 ** 32 with Size => 32;

   From_CPU_2 : Reg32 with Volatile, Import,
     Address => System'To_Address (16#600C_0038#);
   --  SYSTEM_CPU_INTR_FROM_CPU_2_REG: poke target core 0 (write 1; clear 0).
   From_CPU_3 : Reg32 with Volatile, Import,
     Address => System'To_Address (16#600C_003C#);
   --  SYSTEM_CPU_INTR_FROM_CPU_3_REG: poke target core 1.

   --  Preemptive context-switch deferral (Option A; see s-bbcppr +
   --  context_switch.S __gnat_preempt_dispatch).  A switch requested inside a
   --  native interrupt is deferred (Context_Switch sets Switch_Pending); the
   --  vector epilogue dispatches it with no second window spill.

   type Core_Word_Array is array (0 .. 1) of Unsigned_32;
   pragma Volatile_Components (Core_Word_Array);

   In_Native_Int : Core_Word_Array := (0, 0);
   pragma Export (Asm, In_Native_Int, "__gnat_in_native_int");
   --  Per-core native-interrupt nesting depth.

   Switch_Pending : Core_Word_Array := (0, 0);
   pragma Export (Asm, Switch_Pending, "__gnat_switch_pending");
   --  Per-core "a context switch was deferred" flag, consumed by the vector.

   procedure Clear_Poke;
   --  Deassert this core's pending FROM_CPU poke source.

   procedure Timer_Interrupt
     with Export, Convention => C, External_Name => "__gnat_timer_interrupt";
   --  Called from the level-5 vector: run the alarm handler, then context
   --  switch if a higher-priority task became ready (interrupt epilogue).

   procedure Native_Enable_Tick
     with Import, Convention => C, External_Name => "native_enable_tick";
   --  Enables int 16 (esp_cpu_intr_enable) once the handler is attached.

   procedure Native_Enable_Cpu_Int (N : Integer)
     with Import, Convention => C, External_Name => "native_enable_cpu_int";
   --  esp_cpu_intr_enable (1 << N) on the current core.

   function Native_CPU_Freq_Hz return Unsigned_32
     with Import, Convention => C, External_Name => "native_cpu_freq_hz";
   --  Actual configured CPU clock (esp_clk_cpu_freq).

   procedure Native_Freq_Panic (Expected, Actual : Unsigned_32)
     with Import, Convention => C, External_Name => "native_freq_panic",
          No_Return;
   --  Loudly report a Clock_Frequency / hardware-clock mismatch and halt.

   procedure Level3_Dispatch
     with Export, Convention => C, External_Name => "__gnat_level3_dispatch";
   --  Called from the native level-3 vector: ack the device source, run its
   --  GNARL handler (Interrupt_Wrapper), then the interrupt-epilogue context
   --  switch -- the same shape as Timer_Interrupt but for level 3.

   procedure Level2_Dispatch
     with Export, Convention => C, External_Name => "__gnat_level2_dispatch";
   --  Level-2 device dispatch (CPU_INT 19/20/21).  Like Level3_Dispatch but
   --  with an atomic native-nesting bump: L2 can be preempted by L3/L5 (which,
   --  sitting at the top of their nests, don't need that).

   procedure Park_Alarm;
   --  Push CCOMPARE2 ~a full period ahead so int 16 cannot fire spuriously
   --  before a real alarm is programmed.

   ----------------
   -- Park_Alarm --
   ----------------

   procedure Park_Alarm is
   begin
      Asm ("rsr.ccount a3"     & ASCII.LF & ASCII.HT &
           "addi a3, a3, -1"   & ASCII.LF & ASCII.HT &
           "wsr.ccompare2 a3"  & ASCII.LF & ASCII.HT &
           "rsync",
           Clobber  => "a3",
           Volatile => True);
   end Park_Alarm;

   --------------------
   -- Timer_Interrupt --
   --------------------

   procedure Clear_Poke is
   begin
      --  Clear only THIS core's source (clearing the other core's would drop a
      --  poke it has not yet serviced).
      if Multiprocessors.Current_CPU = CPU'First then
         From_CPU_2 := 0;
      else
         From_CPU_3 := 0;
      end if;
   end Clear_Poke;

   procedure Timer_Interrupt is
      Pending : Unsigned_32;
      Core    : constant Integer := Integer (Multiprocessors.Current_CPU) - 1;
   begin
      --  Servicing a native interrupt: defer any context switch requested
      --  below to the vector epilogue.  Runs at INTLEVEL 5 (masked), so this
      --  update is not preemptible on this core.
      In_Native_Int (Core) := In_Native_Int (Core) + 1;

      Asm ("rsr.interrupt %0",
           Outputs  => Unsigned_32'Asm_Output ("=r", Pending),
           Volatile => True);

      --  Cross-core poke (CPU_INT 31): ack the source, then run the GNARL poke
      --  handler (this CPU's expired timing events + alarm wakeups).
      if (Pending and Poke_Interrupt_Bit) /= 0 then
         Clear_Poke;
         System.BB.CPU_Primitives.Multiprocessors.Poke_Handler;
      end if;

      --  Timer alarm (CCOMPARE2 / int 16): the attached Alarm_Handler re-arms
      --  CCOMPARE2, which clears int 16.
      if (Pending and Alarm_Interrupt_Bit) /= 0 then
         System.BB.Interrupts.Interrupt_Wrapper (Alarm_Interrupt_ID);
      end if;

      --  Interrupt epilogue: switch to the highest-priority ready thread if it
      --  differs from the one we interrupted.  Context_Switch saves the
      --  interrupted thread "solicited" (returning here); the level-5 vector
      --  performs the final register restore + RFE when it is resumed.

      --  Context_Switch defers while In_Native_Int /= 0 (sets Switch_Pending);
      --  the vector epilogue performs the real dispatch.
      if System.BB.Threads.Queues.Context_Switch_Needed then
         System.BB.CPU_Primitives.Context_Switch;
      end if;

      In_Native_Int (Core) := In_Native_Int (Core) - 1;
   end Timer_Interrupt;

   ---------------------
   -- Level3_Dispatch --
   ---------------------

   procedure Level3_Dispatch is
      Pending : Unsigned_32;
      Core    : constant Integer := Integer (Multiprocessors.Current_CPU) - 1;
   begin
      --  Same deferral as Timer_Interrupt.  NOTE: runs at INTLEVEL 3 so a
      --  level-5 tick can preempt it; the non-atomic +1/-1 is safe only while
      --  level 5 is the sole other native level (current coexistence config).
      In_Native_Int (Core) := In_Native_Int (Core) + 1;

      Asm ("rsr.interrupt %0",
           Outputs  => Unsigned_32'Asm_Output ("=r", Pending),
           Volatile => True);

      if (Pending and Device_Interrupt_Bit) /= 0 then
         --  Run the attached handler; it clears the device source (CPU_INT 23
         --  is level-triggered, so clearing the source deasserts it).  The
         --  handler runs at level-3 priority, so int 23 stays masked until it
         --  returns -- no storm despite the still-asserted source.
         System.BB.Interrupts.Interrupt_Wrapper (Device_Interrupt_Id);
      end if;

      if System.BB.Threads.Queues.Context_Switch_Needed then
         System.BB.CPU_Primitives.Context_Switch;
      end if;

      In_Native_Int (Core) := In_Native_Int (Core) - 1;
   end Level3_Dispatch;

   ---------------------
   -- Level2_Dispatch --
   ---------------------

   procedure Level2_Dispatch is
      Pending : Unsigned_32;
      Saved   : Unsigned_32;
      Core    : constant Integer := Integer (Multiprocessors.Current_CPU) - 1;
   begin
      --  Enter the native interrupt.  Unlike L3/L5, level 2 can be preempted
      --  by a higher native level (L3 or the L5 tick) *during* this counter
      --  bump; that could leave In_Native_Int transiently 0 and let the higher
      --  level context-switch out of this still-active dispatch.  So mask all
      --  interrupts across the bump (rsil 15) to make it atomic.
      Asm ("rsil %0, 15",
           Outputs => Unsigned_32'Asm_Output ("=r", Saved), Volatile => True);
      In_Native_Int (Core) := In_Native_Int (Core) + 1;
      Asm ("wsr.ps %0" & ASCII.LF & ASCII.HT & "rsync",
           Inputs => Unsigned_32'Asm_Input ("r", Saved), Volatile => True);

      Asm ("rsr.interrupt %0",
           Outputs  => Unsigned_32'Asm_Output ("=r", Pending),
           Volatile => True);

      if (Pending and L2_0_Bit) /= 0 then
         System.BB.Interrupts.Interrupt_Wrapper (L2_0_Id);
      end if;
      if (Pending and L2_1_Bit) /= 0 then
         System.BB.Interrupts.Interrupt_Wrapper (L2_1_Id);
      end if;
      if (Pending and L2_2_Bit) /= 0 then
         System.BB.Interrupts.Interrupt_Wrapper (L2_2_Id);
      end if;

      if System.BB.Threads.Queues.Context_Switch_Needed then
         System.BB.CPU_Primitives.Context_Switch;
      end if;

      Asm ("rsil %0, 15",
           Outputs => Unsigned_32'Asm_Output ("=r", Saved), Volatile => True);
      In_Native_Int (Core) := In_Native_Int (Core) - 1;
      Asm ("wsr.ps %0" & ASCII.LF & ASCII.HT & "rsync",
           Inputs => Unsigned_32'Asm_Input ("r", Saved), Volatile => True);
   end Level2_Dispatch;

   ----------------------
   -- Initialize_Board --
   ----------------------

   procedure Initialize_Board is
      --  Read_Clock is CCOUNT and Ticks_Per_Second = Clock_Frequency, so the
      --  constant must match the actual CPU clock or all Ada.Real_Time timing
      --  is silently scaled.  The frequency is necessarily compile-time
      --  (Ada.Real_Time bakes Time_Unit = 1 / Ticks_Per_Second), so we cannot
      --  adapt -- instead fail loudly if the hardware disagrees.
      Expected : constant Unsigned_32 :=
        Unsigned_32 (System.BB.Parameters.Clock_Frequency);
      Actual   : constant Unsigned_32 := Native_CPU_Freq_Hz;
   begin
      if Actual /= Expected then
         Native_Freq_Panic (Expected, Actual);
      end if;
      Park_Alarm;             --  no spurious int 16 before a real alarm
   end Initialize_Board;

   ----------
   -- Time --
   ----------

   package body Time is

      function Read_Count return Timer_Interval;
      pragma Inline (Read_Count);

      function Native_Systimer_Count return Unsigned_64
        with Import, Convention => C,
             External_Name => "native_systimer_count";
      --  Raw shared 16 MHz SYSTIMER UNIT0 count (same value on both cores).

      ----------------
      -- Read_Count --
      ----------------

      function Read_Count return Timer_Interval is
         Count : Timer_Interval;
      begin
         Asm ("rsr.ccount %0",
              Outputs  => Timer_Interval'Asm_Output ("=r", Count),
              Volatile => True);
         return Count;
      end Read_Count;

      ----------------
      -- Read_Clock --
      ----------------

      function Read_Clock return BB.Time.Time is
         --  Shared SYSTIMER (16 MHz, identical on both cores) scaled x15 into
         --  the 240 MHz Time unit.  The systimer is a 52-bit counter, so x15
         --  (56-bit) fits the 64-bit Time directly: return the FULL value, not
         --  the low 32 bits.  It is already a shared, monotone clock, so
         --  System.BB.Time uses it as-is (offset by Epoch in Clock) with NO
         --  Software_Clock 32-bit-wrap extension -- whose cross-core
         --  Update_In_Progress retry stalled the highest-frequency reader.
         --  Replaces per-core CCOUNT (offset ~tens of ms). Set_Alarm
         --  still arms CCOMPARE2 = CCOUNT + delta (relative), offset cancels.
      begin
         return BB.Time.Time (Native_Systimer_Count * 15);
      end Read_Clock;

      ------------------------
      -- Max_Timer_Interval --
      ------------------------

      function Max_Timer_Interval return Timer_Interval is
        (Timer_Interval'Last);

      ---------------
      -- Set_Alarm --
      ---------------

      procedure Set_Alarm (Ticks : Timer_Interval) is
         Small    : constant Boolean := Ticks < 2 ** 20;
         Margin   : Timer_Interval := (if Ticks = 0 then 1 else Ticks);
         Deadline : Timer_Interval;
      begin
         --  Arm CCOMPARE2 = CCOUNT + Margin.  The Xtensa CCOMPARE interrupt
         --  fires ONLY on the exact CCOUNT = CCOMPARE2 match, so a deadline
         --  that is already in the past when written is MISSED and will not
         --  fire until CCOUNT wraps a full 2**32 (~17.9 s).  This bites tiny
         --  intervals: Update_Alarm programs Time_Difference = 1 whenever an
         --  alarm is due, and CCOUNT advances past CCOUNT+1 between Read_Count
         --  and the wsr.  A lost alarm desynchronises the alarm bookkeeping
         --  (Pending_Alarm), so a delayed task then wakes only on the next
         --  periodic clock update ~Max_Sleep later (ACATS CXD8002 measured
         --  15.47 s for an 8 us delay).  For a small interval, re-arm with a
         --  widening margin until the deadline is provably still ahead of
         --  CCOUNT (modular forward distance in 1 .. 2**31-1).  A large
         --  interval is billions of ticks ahead and cannot be missed, so arm
         --  it once -- which also avoids the past/future ambiguity for
         --  deadlines more than 2**31 ticks away (e.g. Max_Sleep = 7/8*2**32).
         loop
            Deadline := Read_Count + Margin;
            Asm ("wsr.ccompare2 %0" & ASCII.LF & ASCII.HT & "rsync",
                 Inputs   => Timer_Interval'Asm_Input ("r", Deadline),
                 Volatile => True);
            exit when not Small
              or else Deadline - Read_Count - 1 < 2 ** 31 - 1;
            Margin := Margin + 64;
         end loop;
      end Set_Alarm;

      -------------------------
      -- Clear_Alarm_Interrupt --
      -------------------------

      procedure Clear_Alarm_Interrupt is
         --  Writing CCOMPARE0 clears the pending int 6.  Park it almost a full
         --  period ahead so it does not immediately re-fire; the next
         --  Set_Alarm programs the real deadline.
         Park : constant Timer_Interval := Read_Count - 1;
      begin
         Asm ("wsr.ccompare2 %0" & ASCII.LF & ASCII.HT & "rsync",
              Inputs   => Timer_Interval'Asm_Input ("r", Park),
              Volatile => True);
      end Clear_Alarm_Interrupt;

      ---------------------------
      -- Install_Alarm_Handler --
      ---------------------------

      procedure Install_Alarm_Handler
        (Handler : System.BB.Interrupts.Interrupt_Handler)
      is
      begin
         System.BB.Interrupts.Attach_Handler
           (Handler, Alarm_Interrupt_ID, Interrupt_Priority'Last);
         Native_Enable_Tick;   --  safe to let int 6 fire now
      end Install_Alarm_Handler;

   end Time;

   ----------------
   -- Interrupts --
   ----------------

   package body Interrupts is

      ---------------------------
      -- Priority_Of_Interrupt --
      ---------------------------

      function Priority_Of_Interrupt
        (Interrupt : System.BB.Interrupts.Interrupt_ID)
         return System.Any_Priority
      is
         --  Map each ESP32-S3 CPU interrupt's fixed Xtensa level to its Ada
         --  interrupt priority, so Interrupt_Wrapper raises to that level.
         --  Interrupt_Priority'Last = level 5 (kernel tick); each lower level
         --  is one priority less (the inverse of the Enable_Interrupts map).
         Level : Natural;
      begin
         case Interrupt is
            when 16 | 26 | 31      => Level := 5;  --  CCOMPARE2, poke (L5)
            when 24 | 25 | 28 | 30 => Level := 4;
            when 22 | 23 | 27 | 29 => Level := 3;  --  29 = SW int (L3)
            when 19 | 20 | 21      => Level := 2;
            when others            => Level := 5;  --  unknown: top (safe)
         end case;
         return Interrupt_Priority'Last - (5 - Level);
      end Priority_Of_Interrupt;

      -------------------------------
      -- Install_Interrupt_Handler --
      -------------------------------

      procedure Install_Interrupt_Handler
        (Interrupt : System.BB.Interrupts.Interrupt_ID;
         Prio      : Interrupt_Priority)
      is
         pragma Unreferenced (Prio);
      begin
         --  Enable the CPU interrupt on this core.  Its dedicated vector (the
         --  level of CPU_INT Interrupt) routes to our native dispatch; matrix
         --  routing for a real device source is done by the caller / glue.
         Native_Enable_Cpu_Int (Integer (Interrupt));
      end Install_Interrupt_Handler;

      --------------------------
      -- Set_Current_Priority --
      --------------------------

      procedure Set_Current_Priority (Priority : Integer) is
         pragma Unreferenced (Priority);
      begin
         --  Gross interrupt masking is handled by CPU_Primitives
         --  Disable/Enable_Interrupts; per-priority ceiling masking is future
         --  work.
         null;
      end Set_Current_Priority;

      ----------------
      -- Power_Down --
      ----------------

      procedure Power_Down is
      begin
         Asm ("waiti 0", Volatile => True);
      end Power_Down;

   end Interrupts;

   ---------------------
   -- Multiprocessors --
   ---------------------

   package body Multiprocessors is

      procedure Initialize_Slave (CPU_Id : CPU)
        with Import, Convention => C,
             External_Name => "__gnat_initialize_slave";
      --  GNARL slave entry (S.Task_Primitives.Operations.Initialize_Slave):
      --  creates this CPU's idle thread, sets Running_Thread_Table, then runs
      --  the idle loop (Power_Down) until a task is scheduled on this core.

      procedure Native_Release_Core1
        with Import, Convention => C, External_Name => "native_release_core1";
      --  Release the parked ESP-IDF core-1 task so it calls Core1_Entry below.

      procedure Native_Setup_Poke_Core0
        with Import, Convention => C,
             External_Name => "native_setup_poke_core0";
      --  Route FROM_CPU_INTR2 -> CPU_INT 31 on core 0 and enable it (core 0).

      procedure Native_Setup_Poke_Core1
        with Import, Convention => C,
             External_Name => "native_setup_poke_core1";
      --  Route FROM_CPU_INTR3 -> CPU_INT 31 on core 1 and enable int 31 + the
      --  CCOMPARE2 timer (int 16) there (run on core 1).

      function Number_Of_CPUs return CPU is (CPU'Last);

      function Current_CPU return CPU is
         Result : Integer;
      begin
         --  ESP32-S3: PRID bit 13 selects the core (0 = PRO_CPU/core 0,
         --  1 = APP_CPU/core 1).  System.Multiprocessors.CPU is 1-based, so
         --  the running CPU id is that bit plus one.
         Asm ("rsr.prid %0"        & ASCII.LF & ASCII.HT &
              "extui  %0, %0, 13, 1",
              Outputs  => Integer'Asm_Output ("=r", Result),
              Volatile => True);
         return CPU (Result + 1);
      end Current_CPU;

      procedure Poke_CPU (CPU_Id : CPU) is
      begin
         --  Assert the target core's FROM_CPU source (matrix-routed to its
         --  CPU_INT 31, level 5 -> our xt_highint5 -> Poke_Handler).
         if CPU_Id = CPU'First then
            From_CPU_2 := 1;   --  core 0
         else
            From_CPU_3 := 1;   --  core 1
         end if;
      end Poke_CPU;

      ----------------
      -- Core1_Entry --
      ----------------

      procedure Core1_Entry
        with Export, Convention => C,
             External_Name => "__gnat_esp32s3_core1_entry";
      --  Called on core 1 by the (now FreeRTOS-suspended) ESP-IDF core-1 task
      --  once Start_All_CPUs has released it.  ESP-IDF already brought the CPU
      --  up (VECBASE is shared with core 0, so our level-5 vector applies here
      --  too), hence CPU_Primitives.Initialize_CPU is a no-op.  Entering the
      --  GNARL slave never returns: it becomes this core's idle context.

      procedure Core1_Entry is
      begin
         --  Keep interrupts masked through slave kernel initialisation; the
         --  idle loop's Power_Down (waiti 0) re-enables them, at which point
         --  the first tick/poke can drive a context switch.
         CPU_Primitives.Disable_Interrupts;
         CPU_Primitives.Initialize_CPU;   --  enable the FPU on core 1
         Native_Setup_Poke_Core1;   --  enable poke (int 31) + timer (int 16)
         Initialize_Slave (Current_CPU);
      end Core1_Entry;

      procedure Start_All_CPUs is
      begin
         --  Enable this (master) core's poke interrupt, then release core 1.
         --  We cannot "launch" core 1 (ESP-IDF already booted it); instead the
         --  ESP-IDF core-1 task parks itself with the FreeRTOS scheduler
         --  suspended and waits for this release, then calls Core1_Entry.
         Native_Setup_Poke_Core0;
         Native_Release_Core1;
      end Start_All_CPUs;

   end Multiprocessors;

end System.BB.Board_Support;
