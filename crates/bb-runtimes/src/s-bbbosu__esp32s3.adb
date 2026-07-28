------------------------------------------------------------------------------
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                S Y S T E M . B B . B O A R D _ S U P P O R T             --
--                                  B o d y                                 --
--                                                                          --
--  Xtensa LX7 (ESP32-S3) port.                                            --
--                                                                          --
--  The clock reads the shared 16 MHz SYSTIMER UNIT0 count (Read_Clock, x15  --
--  into the 240 MHz Time unit).  The alarm is a SYSTIMER UNIT0 comparator --
--  per core (TARGET0/core 0, TARGET1/core 1) whose matrix interrupt is      --
--  routed to CPU_INT 21 (level 2) -> the native level-2 vector             --
--  (highint5.S) -> Level2_Dispatch -> Interrupt_Wrapper.  Per the FreeRTOS  --
--  Xtensa model every OS-interacting interrupt sits at a level <=           --
--  XCHAL_EXCM_LEVEL and handlers are dispatched at EXCM_LEVEL; the vector   --
--  performs any needed context switch at its outermost exit.  The systimer  --
--  keeps counting while a core idles in waiti, so the alarm still fires     --
--  when the whole system is idle; CCOUNT/CCOMPARE2 (the old tick) halted    --
--  in waiti and could deadlock a fully-idle system, so it is not used.      --
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

   Alarm_Interrupt_ID : constant System.BB.Interrupts.Interrupt_ID := 21;
   --  The alarm is a SYSTIMER UNIT0 comparator (TARGET0 on core 0, TARGET1 on
   --  core 1) whose matrix interrupt is routed to CPU_INT 21 (Device_L2_2,
   --  LEVEL 2) on each core -- see native_setup_systimer_core* in bare_boot.
   --  It was CPU_INT 26 (level 5), but a level-5 tick can preempt an L2/L3
   --  window spill and corrupt WINDOWSTART; per the FreeRTOS model the tick
   --  must be <= EXCM_LEVEL (3) so the spill mask covers it.  At L2 it is
   --  dispatched by the ordinary Level2_Dispatch (the L2_2 slot already calls
   --  its handler), so no bespoke tick vector is needed -- xt_highint5 is now
   --  unused.  We use the systimer (a free-running 16 MHz counter that keeps
   --  ticking in waiti), so the alarm still fires when the system is idle.

   Device_Interrupt_Id  : constant := 23;                   --  CPU_INT 23 (L3)
   Device_Interrupt_Bit : constant Unsigned_32 := 2 ** Device_Interrupt_Id;
   --  Second level-3 device slot (CPU_INT 27 = Device_L3_1), for a
   --  hard-real-time source that must be taken AHEAD of the level-2 devices
   --  -- the LCD RGB bounce refill, which the TWAI traffic (L2) was starving
   --  past its ~1 ms deadline when both shared level 2.  Handlers dispatch at
   --  EXCM_LEVEL and so do not preempt each other, but a pending level 3 is
   --  vectored before any pending level 2 and preempts task code first.
   Device_L3_1_Id  : constant := 27;                        --  CPU_INT 27 (L3)
   Device_L3_1_Bit : constant Unsigned_32 := 2 ** Device_L3_1_Id;

   SW_L3_Id  : constant System.BB.Interrupts.Interrupt_ID := 29;
   SW_L3_Bit : constant Unsigned_32 := 2 ** SW_L3_Id;
   --  CPU_INT 29 = software-triggered level-3 source (wsr.intset bit 29).
   --  A handler attached to it (Ada.Interrupts.Names.SW_L3) is cleared by the
   --  wrapper acking wsr.intclr; used by the stress suite to fire L3 over the
   --  cross-core poke path.

   --  Level-2 device interrupt slots (CPU_INT 19/20/21 = Device_L2_0/1/2).
   L2_0_Id  : constant System.BB.Interrupts.Interrupt_ID := 19;
   L2_1_Id  : constant System.BB.Interrupts.Interrupt_ID := 20;
   L2_2_Id  : constant System.BB.Interrupts.Interrupt_ID := 21;
   L2_0_Bit : constant Unsigned_32 := 2 ** 19;
   L2_1_Bit : constant Unsigned_32 := 2 ** 20;
   L2_2_Bit : constant Unsigned_32 := 2 ** 21;
   --  CPU_INT 21 (L2_2) is shared by the SYSTIMER alarm and the cross-core
   --  FROM_CPU poke (both matrix sources are mapped to it in bare_boot);
   --  Level2_Dispatch reads the FROM_CPU register to tell them apart.  Both
   --  sources are level-triggered, deasserted by clearing their registers.

   type Reg32 is mod 2 ** 32 with Size => 32;

   From_CPU_2 : Reg32 with Volatile, Import,
     Address => System'To_Address (16#600C_0038#);
   --  SYSTEM_CPU_INTR_FROM_CPU_2_REG: poke target core 0 (write 1; clear 0).
   From_CPU_3 : Reg32 with Volatile, Import,
     Address => System'To_Address (16#600C_003C#);
   --  SYSTEM_CPU_INTR_FROM_CPU_3_REG: poke target core 1.

   --  SYSTIMER (base 0x6002_3000) UNIT0 comparators = the tickless alarm.
   --  Core 0 arms TARGET0, core 1 arms TARGET1; each comparator's matrix
   --  interrupt routed to CPU_INT 26 on its own core.  WORK_EN + INT_ENA and
   --  the matrix routing are done once by native_setup_systimer_core* here we
   --  only load the deadline (Set_Alarm) and ack it (Clear_Alarm_Interrupt).
   Systimer_Target0_Hi   : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_301C#);
   Systimer_Target0_Lo   : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_3020#);
   Systimer_Target0_Conf : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_3034#);
   Systimer_Comp0_Load   : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_3050#);
   Systimer_Target1_Hi   : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_3024#);
   Systimer_Target1_Lo   : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_3028#);
   Systimer_Target1_Conf : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_3038#);
   Systimer_Comp1_Load   : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_3054#);
   Systimer_Int_Clr      : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_306C#);
   --  INT_CLR: TARGET0 = bit 0, TARGET1 = bit 1 (write-1-to-clear).

   Systimer_Conf         : Reg32 with Volatile, Import,
     Address => System'To_Address (16#6002_3000#);
   Target0_Work_En       : constant Reg32 := 2 ** 24;
   Target1_Work_En       : constant Reg32 := 2 ** 25;
   --  CONF: per-comparator WORK_EN bits.  The alarm-miss compensation (the
   --  hardware fires immediately when the loaded target is already in the
   --  past, SOC_SYSTIMER_ALARM_MISS_COMPENSATE) is evaluated when WORK_EN is
   --  raised -- so arming MUST toggle it around the load, as esp-idf's
   --  systimer_hal does.  NB the two cores each RMW their own bit of this
   --  shared register; both do so only inside their own kernel sections, and
   --  the arming is per-core rare, so the cross-core RMW window is accepted
   --  for now (a shared spin lock would close it).

   --  Interrupt architecture (the FreeRTOS Xtensa model; see highint5.S for
   --  the full design note).  The vector saves the complete context, hops
   --  onto the per-CPU interrupt stack and calls the dispatch below AT
   --  INTLEVEL = EXCM_LEVEL, so these bodies (and every handler they run)
   --  are never preempted by another OS-band interrupt.  They do exactly one
   --  job -- service the pending sources.  All bookkeeping lives in the
   --  vector: the nesting count (__gnat_int_nest, owned by the vector asm)
   --  and the context switch, which the OUTERMOST vector epilogue performs
   --  itself by comparing First_Thread with Running_Thread -- these bodies
   --  never call Context_Switch (and s-bbcppr.Context_Switch refuses to
   --  switch while __gnat_int_nest is nonzero).

   procedure Clear_Poke;
   --  Deassert this core's pending FROM_CPU poke source.

   procedure Native_Setup_Systimer_Core0
     with Import, Convention => C,
          External_Name => "native_setup_systimer_core0";
   procedure Native_Setup_Systimer_Core1
     with Import, Convention => C,
          External_Name => "native_setup_systimer_core1";
   --  Per-core: route the SYSTIMER TARGETx int to CPU_INT 21, enable that
   --  comparator + its interrupt, and unmask the CPU int (core 0 -> TARGET0,
   --  core 1 -> TARGET1).  Defined in bare_boot.adb (typed SVD access).

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
   --  Called from the native level-3 vector: service every pending level-3
   --  device source (CPU_INT 23 and 27) through Interrupt_Wrapper.

   procedure Level2_Dispatch
     with Export, Convention => C, External_Name => "__gnat_level2_dispatch";
   --  Called from the native level-2 vector: service every pending level-2
   --  source -- the device slots (CPU_INT 19/20) and the shared tick +
   --  cross-core-poke slot (CPU_INT 21).

   procedure Park_Alarm;
   --  Push CCOMPARE2 ~a full period ahead so int 16 cannot fire spuriously
   --  before a real alarm is programmed.

   ----------------
   -- Park_Alarm --
   ----------------

   procedure Park_Alarm is
   begin
      --  Load a far-future deadline into both comparators and clear any stale
      --  interrupt, so neither fires before the first real Set_Alarm.  Runs
      --  before native_setup_systimer_core* sets WORK_EN, so it is purely
      --  defensive (COMPx_LOAD latches the target regardless of WORK_EN).
      Systimer_Target0_Hi := 16#F_FFFF#;
      Systimer_Target0_Lo := 16#FFFF_FFFF#;
      Systimer_Target0_Conf := 0;
      Systimer_Comp0_Load := 1;
      Systimer_Target1_Hi := 16#F_FFFF#;
      Systimer_Target1_Lo := 16#FFFF_FFFF#;
      Systimer_Target1_Conf := 0;
      Systimer_Comp1_Load := 1;
      Systimer_Int_Clr := 16#3#;   --  clear TARGET0 + TARGET1
   end Park_Alarm;

   ----------------
   -- Clear_Poke --
   ----------------

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

   ---------------------
   -- Level3_Dispatch --
   ---------------------

   procedure Level3_Dispatch is
      Pending : Unsigned_32;
   begin
      Asm ("rsr.interrupt %0",
           Outputs  => Unsigned_32'Asm_Output ("=r", Pending),
           Volatile => True);

      if (Pending and Device_Interrupt_Bit) /= 0 then
         --  Run the attached handler; it clears the device source (CPU_INT 23
         --  is level-triggered, so clearing the source deasserts it).  The
         --  source stays masked until the vector returns -- no storm despite
         --  the still-asserted line.
         System.BB.Interrupts.Interrupt_Wrapper (Device_Interrupt_Id);
      end if;
      if (Pending and Device_L3_1_Bit) /= 0 then
         --  Second L3 device source (CPU_INT 27); same shape as int 23.
         System.BB.Interrupts.Interrupt_Wrapper (Device_L3_1_Id);
      end if;
      if (Pending and SW_L3_Bit) /= 0 then
         --  Software-triggered L3 source (CPU_INT 29); the handler must ack it
         --  (wsr.intclr bit 29) so it does not re-fire on return.
         System.BB.Interrupts.Interrupt_Wrapper (SW_L3_Id);
      end if;
   end Level3_Dispatch;

   ---------------------
   -- Level2_Dispatch --
   ---------------------

   procedure Level2_Dispatch is
      Pending : Unsigned_32;
      Core    : constant Integer := Integer (Multiprocessors.Current_CPU) - 1;
   begin
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
         --  Shared tick + cross-core poke slot (CPU_INT 21).  Both the
         --  SYSTIMER alarm and the FROM_CPU poke route here.  Handle the poke
         --  only when its FROM_CPU source is actually asserted (else this is
         --  an alarm-only tick), then run the alarm handler -- which
         --  re-checks the clock, so it is safe even if only the poke fired.
         if (if Core = 0 then From_CPU_2 else From_CPU_3) /= 0 then
            Clear_Poke;

            --  The poke consumer wakes tasks, and each wakeup's
            --  Leave_Kernel re-enables interrupts to the RUNNING thread's
            --  active priority.  Called bare, that is the interrupted
            --  TASK's priority -- INTLEVEL drops to the task band in the
            --  middle of this vector, re-opening the OS-band nesting the
            --  vector architecture forbids (under a cross-core wakeup
            --  storm the system then lives in that forbidden regime).
            --  Mirror Interrupt_Wrapper's ceiling protocol: raise the
            --  interrupted thread around the poke so every nested
            --  Leave_Kernel stays in the masked band.
            --
            --  The ceiling MUST reach Interrupt_Priority'Last, not merely
            --  L2_2's own (level-2) priority.  A level-3 device source
            --  (CPU_INT 23/27 -- notably the RGB-LCD bounce refill) sits
            --  ABOVE this level-2 slot, so an L2_2 ceiling leaves INTLEVEL at
            --  the level-2 band after Poke_Handler's Leave_Kernel; the L3
            --  refill then preempts the restore Change_Priority below
            --  mid-requeue and corrupts this CPU's ready queue (idle left
            --  mis-ranked at the head -> eventual idle.Next self-loop).

            declare
               Self_Id         : constant System.BB.Threads.Thread_Id :=
                 System.BB.Threads.Thread_Self;
               Caller_Priority : constant Integer :=
                 System.BB.Threads.Get_Priority (Self_Id);
            begin
               System.BB.Threads.Queues.Change_Priority
                 (Self_Id, System.Interrupt_Priority'Last);
               System.BB.CPU_Primitives.Multiprocessors.Poke_Handler;
               System.BB.Threads.Queues.Change_Priority
                 (Self_Id, Caller_Priority);
            end;
         end if;
         System.BB.Interrupts.Interrupt_Wrapper (L2_2_Id);
      end if;
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

      function Native_Systimer_Count return Unsigned_64
        with Import, Convention => C,
             External_Name => "native_systimer_count";
      --  Raw shared 16 MHz SYSTIMER UNIT0 count (same value on both cores).

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

      Systimer_Arm_Lock : aliased Interfaces.Unsigned_32 := 0
        with Volatile;
      --  SYSTIMER_CONF is ONE register shared by both cores, and Set_Alarm
      --  read-modify-writes it (the WORK_EN toggle) -- concurrently from
      --  both cores.  A stale write-back from one core glitches the OTHER
      --  core's WORK_EN mid-arm: re-enabling it while that core's TARGET
      --  HI/LO are half-written makes the alarm-miss compensation evaluate
      --  a torn target (a spurious fire -- observed as a self-sustaining
      --  ~60 us cross-core interrupt storm), and re-disabling can kill a
      --  just-armed comparator (a lost alarm).  Serialise the arm sequence
      --  across cores with a S32C1I spinlock, exactly as ESP-IDF wraps its
      --  systimer alarm operations in a cross-core critical section.  The
      --  caller runs under Enter_Kernel (local interrupts masked), so the
      --  holder cannot be preempted and the other core spins for at most
      --  the ~10-write sequence.

      procedure Systimer_Arm_Acquire;
      procedure Systimer_Arm_Release;

      procedure Systimer_Arm_Acquire is
         use Interfaces;
         Old  : Unsigned_32;
         Zero : constant Unsigned_32 := 0;
      begin
         loop
            Old := 1;
            Asm
              ("wsr.scompare1 %1"      & ASCII.LF & ASCII.HT &
               "s32c1i        %0, %2, 0",
               Outputs  => Unsigned_32'Asm_Output ("+r", Old),
               Inputs   =>
                 (Unsigned_32'Asm_Input ("r", Zero),
                  System.Address'Asm_Input
                    ("r", Systimer_Arm_Lock'Address)),
               Volatile => True,
               Clobber  => "memory");
            exit when Old = 0;
         end loop;
      end Systimer_Arm_Acquire;

      procedure Systimer_Arm_Release is
         use Interfaces;
         Zero : constant Unsigned_32 := 0;
      begin
         Asm
           ("memw" & ASCII.LF & ASCII.HT & "s32i.n %0, %1, 0",
            Inputs   =>
              (Unsigned_32'Asm_Input ("r", Zero),
               System.Address'Asm_Input ("r", Systimer_Arm_Lock'Address)),
            Volatile => True,
            Clobber  => "memory");
      end Systimer_Arm_Release;

      procedure Set_Alarm (Ticks : Timer_Interval) is
         Core     : constant Integer :=
           Integer (Multiprocessors.Current_CPU) - 1;   --  0=core0, 1=core1
         Now      : constant Unsigned_64 := Native_Systimer_Count;
         --  Ticks is in 240 MHz Time-units (Read_Clock = systimer count x15);
         --  convert back to raw 16 MHz systimer ticks.  Floor at 1 so a 0/tiny
         --  interval still lands ahead of "now" AT COMPUTATION TIME.  The
         --  count can still overtake the target during the multi-register
         --  arming sequence below -- and a comparator loaded with a target
         --  already in the past NEVER fires unless the hardware alarm-miss
         --  compensation gets to evaluate it, which happens on the WORK_EN
         --  rising edge (hence the toggle below).  A missed arm here killed
         --  every "delay until" in the system, permanently, the first time
         --  the timing-event pattern produced a near-zero re-arm delta.
         St_Delta : constant Unsigned_64 :=
           Unsigned_64'Max (1, Unsigned_64 (Ticks) / 15);
         Deadline : constant Unsigned_64 := Now + St_Delta;
         Hi       : constant Reg32 :=
           Reg32 (Shift_Right (Deadline, 32) and 16#F_FFFF#);
         Lo       : constant Reg32 := Reg32 (Deadline and 16#FFFF_FFFF#);
      begin
         --  Arm this core's UNIT0 comparator (one-shot), esp-idf's sequence:
         --  WORK_EN off -> target -> CONF (0 = UNIT0, one-shot) -> LOAD ->
         --  WORK_EN on.  The final enable is what lets the hardware fire
         --  immediately when the target is already behind the count.  Runs
         --  under Enter_Kernel, so the sequence is not preempted locally.
         Systimer_Arm_Acquire;
         if Core = 0 then
            Systimer_Conf := Systimer_Conf and not Target0_Work_En;
            Systimer_Target0_Hi := Hi;
            Systimer_Target0_Lo := Lo;
            Systimer_Target0_Conf := 0;
            Systimer_Comp0_Load := 1;
            Systimer_Conf := Systimer_Conf or Target0_Work_En;
         else
            Systimer_Conf := Systimer_Conf and not Target1_Work_En;
            Systimer_Target1_Hi := Hi;
            Systimer_Target1_Lo := Lo;
            Systimer_Target1_Conf := 0;
            Systimer_Comp1_Load := 1;
            Systimer_Conf := Systimer_Conf or Target1_Work_En;
         end if;
         Systimer_Arm_Release;
      end Set_Alarm;

      -------------------------
      -- Clear_Alarm_Interrupt --
      -------------------------

      procedure Clear_Alarm_Interrupt is
         Core : constant Integer := Integer (Multiprocessors.Current_CPU) - 1;
      begin
         --  Ack this core's comparator (write-1-to-clear its INT_RAW).  The
         --  one-shot has already fired and will not re-latch until the next
         --  Set_Alarm re-loads a target (Alarm_Handler calls us then re-arms).
         if Core = 0 then
            Systimer_Int_Clr := 16#1#;   --  TARGET0_INT_CLR (bit 0)
         else
            Systimer_Int_Clr := 16#2#;   --  TARGET1_INT_CLR (bit 1)
         end if;
      end Clear_Alarm_Interrupt;

      ---------------------------
      -- Install_Alarm_Handler --
      ---------------------------

      procedure Install_Alarm_Handler
        (Handler : System.BB.Interrupts.Interrupt_Handler)
      is
      begin
         --  Alarm is now CPU_INT 21 (level 2), so its priority is the level-2
         --  priority ('Last - 3), not 'Last (L5) as when it was CPU_INT 26.
         System.BB.Interrupts.Attach_Handler
           (Handler, Alarm_Interrupt_ID, Interrupt_Priority'Last - 3);
         Native_Setup_Systimer_Core0;   --  route/enable core 0's TARGET0 alarm
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
         --  Only Xtensa levels 2 and 3 have a native dispatcher
         --  (Level2_Dispatch / Level3_Dispatch); levels 4 and 5 do not
         --  (level 5 parks -- highint5.S).  Priority_Of_Interrupt maps a
         --  dispatched level to at most Interrupt_Priority'Last - 2; any
         --  higher value means this CPU interrupt would fire into an
         --  unhandled vector and crash.  Fail loudly at elaboration, not
         --  silently in the field the first time it asserts -- the class
         --  of trap the RGB-LCD level-3 promotion sprang on the ceiling.
         if Priority_Of_Interrupt (Interrupt)
           > Interrupt_Priority'Last - 2
         then
            raise Program_Error with "interrupt level has no dispatcher";
         end if;

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
         Native_Setup_Poke_Core1;      --  enable poke (int 31)
         Native_Setup_Systimer_Core1;  --  route/enable core 1's TARGET1 alarm
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
