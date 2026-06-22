------------------------------------------------------------------------------
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--               S Y S T E M . B B . C P U _ S P E C I F I C                --
--                                  S p e c                                 --
--                                                                          --
--  Xtensa LX6 / LX7 (ESP32 / ESP32-S3) port skeleton.                      --
--  Part of the native Ada (Jorvik) RTS replacing the FreeRTOS-backed       --
--  GNARL.  See bb/README.md.                                               --
------------------------------------------------------------------------------

--  Processor-dependent definitions for the Xtensa CPU.

pragma Restrictions (No_Elaboration_Code);

package System.BB.CPU_Specific is
   pragma Preelaborate;

   ------------------------
   -- Context management --
   ------------------------

   --  Xtensa uses the *windowed* ABI on ESP32/ESP32-S3 (confirmed:
   --  __XTENSA_WINDOWED_ABI__, 32 address registers, 4 windows).
   --
   --  A synchronous context switch first spills all live register windows to
   --  the running thread's stack (see Context_Switch).  Once spilled, nearly
   --  all task state lives on that stack, so the per-task saved context is
   --  deliberately small: the stack pointer plus the few special registers
   --  needed to resume.  Register windows are reloaded lazily through
   --  WINDOWUNDERFLOW exceptions as the resumed thread returns up its call
   --  chain -- this is the key difference from the flat ARM/RISC-V ports and
   --  is closest in spirit to the SPARC (LEON) windowed port.

   --  Field order/offsets are relied upon by xtensa/context_switch.S:
   --  SP @ 0, PC @ 4, PS @ 8, A0 @ 12.

   type Context_Buffer is record
      SP        : System.Address;
      --  a1 -- task stack pointer (top of the spilled frame)

      PC        : System.Address;
      --  Resume jump target: a one-instruction 'retw' stub for an existing
      --  task (the switch jumps here after loading SP/PS/A0), or the
      --  __gnat_start_thread trampoline for a never-yet-run task.

      PS        : System.Address;
      --  Processor State register: INTLEVEL, UM, WOE, CALLINC, OWB, ...

      A0        : System.Address;
      --  a0 -- windowed return address an existing task resumes to (the
      --  'retw' stub returns here, reloading its caller via window underflow).

      THREADPTR : System.Address;
      --  THREADPTR special register (thread-local storage base), if used

      CP_State  : System.Address;
      --  Pointer to this task's lazily-saved coprocessor / FPU save area.
      --  Coprocessor state is NOT saved eagerly here; it is saved on first
      --  use via CPENABLE trapping (ESP32-S3 has a single-precision FPU).

      SAR       : System.Address;
      --  SAR (shift amount register) -- volatile across a preemptive switch.

      LBEG      : System.Address;
      LEND      : System.Address;
      LCOUNT    : System.Address;
      --  Xtensa zero-overhead LOOP registers.  MUST be saved/restored across
      --  a context switch (see context_switch.S): a thread preempted mid-LOOP
      --  has LCOUNT /= 0, so resuming a thread with a stale LEND makes the
      --  hardware spuriously loop -> wild control flow.

      Frame_Kind : System.Address;
      --  How this thread's saved state is encoded (context_switch.S Option A
      --  dual-format dispatch): 0 = SOLICITED (cooperative yield; resume via
      --  'retw'); 1 = INTERRUPT (preempted; full state in an XT_STK frame at
      --  SP, resume via _xt_context_restore + 'rfe').
   end record;

   Stack_Alignment : constant := 16;
   --  Stack alignment required by the Xtensa ABI

end System.BB.CPU_Specific;
