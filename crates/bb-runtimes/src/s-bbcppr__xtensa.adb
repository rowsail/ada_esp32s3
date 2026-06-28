------------------------------------------------------------------------------
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--               S Y S T E M . B B . C P U _ P R I M I T I V E S            --
--                                  B o d y                                 --
--                                                                          --
--  Xtensa LX6 / LX7 (ESP32 / ESP32-S3) port SKELETON.                      --
--                                                                          --
--  Initialize_Context / Initialize_Stack are implemented; Context_Switch    --
--  and the interrupt/trap routines remain documented STUBS.  TODOs anchor   --
--  each to the vendored FreeRTOS Xtensa reference (reference/freertos-      --
--  xtensa/, esp-idf v5.4.4):                                                --
--    * components/xtensa/xtensa_context.S  (_xt_context_save/_restore)     --
--    * components/xtensa/xtensa_vectors.S  (window over/underflow, vectors)--
--    * components/freertos/.../portable/xtensa/port.c  (pxPortInitialise-  --
--      Stack: the initial frame this Initialize_Context mirrors)           --
--  The SPARC/LEON port (s-bbcppr__sparc.adb) is the closest existing       --
--  windowed-register analogue in bb-runtimes.                              --
------------------------------------------------------------------------------

pragma Restrictions (No_Elaboration_Code);

with System.Machine_Code;            use System.Machine_Code;
with Interfaces;                      use type Interfaces.Unsigned_32;
with System.Multiprocessors;
with System.BB.Threads.Queues;
with System.BB.Board_Support;

package body System.BB.CPU_Primitives is

   Initial_PS : constant := 16#0005_002F#;
   --  Initial PS (Processor State) for a task's first entry (windowed ABI):
   --    INTLEVEL = 15 (0x0F)    -- start masked; the runtime lowers it per
   --                               the task priority after the switch
   --                               (cf. SPARC starting with PIL = 15).
   --    UM       = 1  (0x20)    -- user vector mode.
   --    CALLINC  = 1  (1 << 16) -- entered as if 'call4'd.
   --    WOE      = 1  (1 << 18) -- window overflow detection enabled.
   --  EXCM is left clear: first entry is reached by a jump, not by 'rfe'.

   --  Initialize_Context leaves a 16-byte data slot at the very top of a new
   --  task's stack and sets the task SP 16 bytes below it (an ABI base save
   --  area sits between).  __gnat_start_thread therefore reads the task entry
   --  point at [SP + 16] and the argument at [SP + 20].

   --  Per-core flags shared with the BSP (s-bbbosu defines/exports them) and
   --  the interrupt vector (highint5.S).  When a context switch is requested
   --  from inside a native interrupt (In_Native_Int /= 0), Context_Switch
   --  records it in Switch_Pending and returns; the vector epilogue then
   --  dispatches to the next thread (__gnat_preempt_dispatch) from its clean
   --  single-window context.  This keeps the cooperative SPILL_ALL_WINDOWS out
   --  of interrupt context (ACATS CXD8002).

   type Core_Word_Array is array (0 .. 1) of Interfaces.Unsigned_32;
   pragma Volatile_Components (Core_Word_Array);

   In_Native_Int : Core_Word_Array;
   pragma Import (Asm, In_Native_Int, "__gnat_in_native_int");

   Switch_Pending : Core_Word_Array;
   pragma Import (Asm, Switch_Pending, "__gnat_switch_pending");

   --------------------
   -- Context_Switch --
   --------------------

   procedure Context_Switch is
      use System.BB.Threads.Queues;

      procedure Switch_Asm (Running_Slot, First_Slot : System.Address);
      pragma Import (Asm, Switch_Asm, "__gnat_context_switch");
      --  The windowed register switch itself, in xtensa/context_switch.S.
      --  Each argument is the address of a Thread_Table slot; the asm
      --  dereferences it to the thread descriptor, whose first field is the
      --  Context_Buffer.

      CPU_Id : constant System.Multiprocessors.CPU :=
                 Board_Support.Multiprocessors.Current_CPU;

      New_Priority : constant Integer :=
                       First_Thread_Table (CPU_Id).Active_Priority;
   begin
      --  If requested from inside a native interrupt, do NOT switch here:
      --  record it and let the interrupt vector epilogue dispatch from its
      --  clean single-window context (__gnat_preempt_dispatch).  Running the
      --  cooperative SPILL+retw switch from the ISR window chain corrupts the
      --  register windows (ACATS CXD8002).

      if In_Native_Int (Integer (CPU_Id) - 1) /= 0 then
         Switch_Pending (Integer (CPU_Id) - 1) := 1;
         return;
      end if;

      --  Set the board-level interrupt priority for the incoming thread
      --  (full CPU interrupt disabling is handled separately by the switch).
      --  Mirrors the RISC-V port.

      if New_Priority < Interrupt_Priority'Last then
         Board_Support.Interrupts.Set_Current_Priority (New_Priority);
      end if;

      --  Perform the register switch (also updates Running_Thread_Table).

      Switch_Asm
        (Running_Thread_Table (CPU_Id)'Address,
         First_Thread_Table (CPU_Id)'Address);
   end Context_Switch;

   ----------------------
   -- Initialize_Stack --
   ----------------------

   procedure Initialize_Stack
     (Base          : Address;
      Size          : Storage_Elements.Storage_Offset;
      Stack_Pointer : out Address)
   is
      use System.Storage_Elements;

      Top  : constant Integer_Address := To_Integer (Base + Size);
      Algn : constant Integer_Address := CPU_Specific.Stack_Alignment;
   begin
      --  Xtensa stacks grow downward; return the top of the region aligned
      --  down to the ABI stack alignment.  Initialize_Context lays the task's
      --  initial frame below this address.
      Stack_Pointer := To_Address ((Top / Algn) * Algn);
   end Initialize_Stack;

   ------------------------
   -- Initialize_Context --
   ------------------------

   procedure Initialize_Context
     (Buffer          : not null access Context_Buffer;
      Program_Counter : System.Address;
      Argument        : System.Address;
      Stack_Pointer   : System.Address)
   is
      use System.Storage_Elements;

      procedure Start_Thread_Asm;
      pragma Import (Asm, Start_Thread_Asm, "__gnat_start_thread");
      --  Trampoline the first Context_Switch resumes into: the windowed
      --  switch's 'retw' underflow-reloads the fabricated frame below, then
      --  Start_Thread_Asm calls the entry with the argument.

      Align : constant Integer_Address := CPU_Specific.Stack_Alignment;

      CP_Size : constant Integer_Address := 80;
      --  Per-thread FPU (CP0) save area: 72 bytes (f0..f15, FCR, FSR) rounded
      --  up to the 16-byte stack alignment.  Reserved at the very top of the
      --  task stack; the switch SP starts below it.

      Stack_Top : constant Integer_Address :=
              (To_Integer (Stack_Pointer) / Align) * Align;

      CP_Area : constant Integer_Address := Stack_Top - CP_Size;
      --  16-byte aligned FPU save area, [CP_Area .. Stack_Top).

      Top : constant Integer_Address := CP_Area;
      --  16-byte aligned top of the usable task stack (below the FPU area),
      --  used as the switch SP.

      Task_SP : constant Integer_Address := Top - 32;
      --  The trampoline window's own stack pointer (below the save area).

      --  WindowUnderflow4 reloads the resumed window's a0..a3 from
      --  [switch_SP - 16 .. switch_SP - 4], i.e. [Top-16 .. Top-4].
      --  Lay out a call4 frame so the trampoline starts cleanly:
      A0_Slot : System.Address;                  --  -> a0 = 0 (end backtrace)
      for A0_Slot'Address use To_Address (Top - 16);
      A1_Slot : System.Address;                  --  -> a1 = trampoline SP
      for A1_Slot'Address use To_Address (Top - 12);
      A2_Slot : System.Address;                  --  -> a2 = entry point
      for A2_Slot'Address use To_Address (Top - 8);
      A3_Slot : System.Address;                  --  -> a3 = argument
      for A3_Slot'Address use To_Address (Top - 4);

      FP_Area : Storage_Array (1 .. Storage_Offset (CP_Size))
        with Address => To_Address (CP_Area);
      --  Zero-initialise the FPU save area (f-registers 0.0, FCR/FSR default).

   begin
      FP_Area := (others => 0);

      --  The environment/idle tasks (Program_Counter = Null_Address) keep
      --  their live context; only record their FPU save area.

      if Program_Counter = Null_Address then
         Buffer.CP_State   := To_Address (CP_Area);
         Buffer.Frame_Kind := Null_Address;   --  solicited (Option A)
         return;
      end if;

      A0_Slot := Null_Address;
      A1_Slot := To_Address (Task_SP);
      A2_Slot := Program_Counter;
      A3_Slot := Argument;

      --  Resume state: SP = Top is the value 'retw' uses to find the frame
      --  above; A0 = trampoline address (a 0x4....... address whose top two
      --  bits already encode a call4 return, so 'retw' raises Underflow4).

      Buffer.all :=
        (SP        => To_Address (Top),
         PC        => Null_Address,
         PS        => To_Address (Initial_PS),
         A0        => Start_Thread_Asm'Address,
         THREADPTR => Null_Address,
         CP_State  => To_Address (CP_Area),
         --  A new thread starts with no active hardware loop and SAR = 0;
         --  LCOUNT = 0 is the critical one (see s-bbcpsp / context_switch.S).
         SAR       => Null_Address,
         LBEG      => Null_Address,
         LEND      => Null_Address,
         LCOUNT    => Null_Address,
         --  A new thread is resumed SOLICITED (its 'retw' lands in
         --  __gnat_start_thread); Option A dual-format dispatch.
         Frame_Kind => Null_Address);
   end Initialize_Context;

   ---------------------------
   -- Install_Error_Handlers --
   ---------------------------

   procedure Install_Error_Handlers is
   begin
      --  TODO Phase 3: point the Xtensa exception vectors at a handler that
      --  maps synchronous traps (IllegalInstruction, LoadStoreError,
      --  division-by-zero, ...) to the matching Ada exceptions.
      null;
   end Install_Error_Handlers;

   ------------------------
   -- Disable_Interrupts --
   ------------------------

   procedure Disable_Interrupts is
      Old : Integer;
   begin
      --  Raise PS.INTLEVEL to mask all maskable interrupts (level 15).
      Asm ("rsil %0, 15",
           Outputs  => Integer'Asm_Output ("=r", Old),
           Volatile => True);
   end Disable_Interrupts;

   -----------------------
   -- Enable_Interrupts --
   -----------------------

   --  The native kernel tick and cross-core poke run at Xtensa interrupt
   --  level 5 (CCOMPARE2 / CPU_INT 31; see s-bbbosu__esp32s3.adb).  That is
   --  the highest level the Ada runtime uses, so it is the hardware level of
   --  Interrupt_Priority'Last.  An Ada interrupt priority P thus maps to the
   --  Xtensa INTLEVEL  Kernel_Tick_Level - (Interrupt_Priority'Last - P),
   --  i.e. the top priority masks through level 5, each lower interrupt
   --  priority masks one level less.  (Under ESP-IDF coexistence levels 1-4
   --  are dispatched by ESP-IDF, so today level 5 is the only natively-owned
   --  level and there is a single Ada Interrupt_Priority; this mapping is
   --  written generally so it still holds once the full takeover frees the
   --  lower levels.)
   Kernel_Tick_Level : constant := 5;

   procedure Enable_Interrupts (Level : Integer) is
      Old : Integer;

      --  INTLEVEL to install: 0 for ordinary task priorities (no interrupt
      --  masked), otherwise the Xtensa level of the ceiling interrupt
      --  priority (capped at the kernel tick level).
      Intlevel : constant Integer :=
        (if Level < Interrupt_Priority'First then 0
         else Integer'Min
                (Kernel_Tick_Level,
                 Kernel_Tick_Level - (Interrupt_Priority'Last - Level)));
   begin
      --  rsil takes an immediate, so dispatch on the computed level.
      case Intlevel is
         when 1 =>
            Asm ("rsil %0, 1",
                 Outputs => Integer'Asm_Output ("=r", Old), Volatile => True);
         when 2 =>
            Asm ("rsil %0, 2",
                 Outputs => Integer'Asm_Output ("=r", Old), Volatile => True);
         when 3 =>
            Asm ("rsil %0, 3",
                 Outputs => Integer'Asm_Output ("=r", Old), Volatile => True);
         when 4 =>
            Asm ("rsil %0, 4",
                 Outputs => Integer'Asm_Output ("=r", Old), Volatile => True);
         when 5 =>
            Asm ("rsil %0, 5",
                 Outputs => Integer'Asm_Output ("=r", Old), Volatile => True);
         when others =>   --  level 0 (or below): enable all interrupts
            Asm ("rsil %0, 0",
                 Outputs => Integer'Asm_Output ("=r", Old), Volatile => True);
      end case;
   end Enable_Interrupts;

   --------------------
   -- Initialize_CPU --
   --------------------

   procedure Initialize_CPU is
   begin
      --  Enable coprocessor 0 (FPU) and coprocessor 3 ("cop_ai", the LX7
      --  PIE/SIMD unit): CPENABLE = 16#9# = XCHAL_CP_MASK.  CP0 is saved
      --  per task by __gnat_context_switch; CP3's q0-q7 are not, so any
      --  ESP32S3.SIMD use must stay within a single task.  Per core.
      Asm ("movi  a3, 9"        & ASCII.LF & ASCII.HT &
           "wsr.cpenable a3"    & ASCII.LF & ASCII.HT &
           "rsync",
           Clobber  => "a3",
           Volatile => True);
   end Initialize_CPU;

end System.BB.CPU_Primitives;
