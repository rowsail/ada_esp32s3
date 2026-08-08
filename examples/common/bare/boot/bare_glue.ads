--  IDF-free bare-boot glue, in Ada -- the pure-Ada replacement for the former
--  bare_glue.c.  It owns the dual-core bring-up that runs the GNARL Ada runtime
--  with FreeRTOS never present: core 0 runs the Ada environment task; core 1 is
--  cold-started into the GNARL slave scheduler.
--
--  Reached from the assembly trampolines in ../start.S (which stay asm: register-
--  window and vector setup): _start -> start_c (Bare_Boot) -> app_main (here);
--  __gnat_enter_env -> ada_env_body (here); core1_start -> core1_bare_main (here).
--  Every entry point keeps its C name so start.S / the runtime link unchanged.
--
--  Compiled ZFP-style by bare_boot.gpr (no binder, no elaboration): it runs before
--  and around adainit.  Build-time knobs the old C took as -D macros are gone:
--    * the Ada main is reached through "ada_env_main" (bare_build.sh --defsym's it
--      to the example's _ada_<unit>), so this unit is example-independent;
--    * the env-task / core-1 stacks are reserved by the linker (vendor/sections.ld,
--      ada_env_stack sized by __env_stack_size), not a sized C array;
--    * the recoverable-stack-overflow arming is always present but inert unless the
--      full runtime calls it (it weak-imports the running-thread bounds).

with Interfaces;

package Bare_Glue is

   --  The Ada environment-task body: board init, elaborate, release the slave
   --  CPUs, run the Ada main.  Entered as the OUTERMOST window frame via
   --  __gnat_enter_env (start.S names this symbol).  Never returns.
   procedure Ada_Env_Body
   with Export, Convention => C, External_Name => "ada_env_body", No_Return;

   --  Core-0 bring-up, called directly by start_c (Bare_Boot).  Cold-starts core
   --  1, hands the runtime both cores, enters the env task.  Never returns.
   procedure App_Main
   with Export, Convention => C, External_Name => "app_main", No_Return;

   --  APP_CPU (core 1) entry, reached from core1_start (start.S) after we reset
   --  core 1.  Runs from IRAM (no flash-XIP dependency during cold-start).  Never
   --  returns (enters the GNARL slave scheduler).
   procedure Core1_Bare_Main
   with Export, Convention => C, External_Name => "core1_bare_main", No_Return,
        Linker_Section => ".iram1.core1";

   --  Configure + calibrate the 480 MHz BBPLL, called from start.S immediately
   --  BEFORE the CPU clock source is switched to it.  Runs from IRAM: it is
   --  reached while the CPU is still on the ROM default clock and before the
   --  first flash-XIP fetch.
   --
   --  start.S used to switch straight to the PLL on the assumption that the ROM
   --  had already brought it up for the 80 MHz flash MSPI.  That is not true on
   --  every board -- a chip whose ROM leaves the flash on the XTAL path never
   --  configures the PLL, so SOC_CLK_SEL=PLL then clocked the CPU from an
   --  uncalibrated VCO and the first instruction fetched from flash decoded as
   --  garbage (double exception before any application code ran).  Configuring
   --  it explicitly is correct on both kinds of board: the sequence below is
   --  what the PLL needs regardless of what the ROM did or did not do.
   procedure Bbpll_480M_Configure
   with Export, Convention => C, External_Name => "bbpll_480m_configure",
        Linker_Section => ".iram1.bbpll";

   --  Bring the CPU to its target clock: PLL bring-up, then core voltage, then
   --  frequency.  Called from start.S in place of the open-coded register
   --  writes, so that ONE place owns the target frequency and everything that
   --  must track it.  Runs from IRAM, before the first flash-XIP fetch.
   --
   --  The ordering is not cosmetic.  Core voltage must be raised BEFORE the
   --  frequency: 240 MHz is a special case in the IDF
   --  (rtc_clk_cpu_freq_to_pll_mhz) -- "cpu_frequency < 240M: dbias =
   --  pvt-dig + 2; cpu_frequency = 240M: dbias = pvt-dig + 3".  start.S used to
   --  switch at whatever dbias the ROM left, and a part that needs the higher
   --  voltage then executes garbage from the first flash fetch onward.
   --  Verified on an ESP32-S3FN8 (rev v0.2): 160 MHz ran fine at the ROM
   --  default dbias, 240 MHz did not.
   --
   --  The dbias VALUES come from the chip's own PVT calibration eFuses where
   --  they are burned (as the IDF's rtc_set_stored_dbias does), falling back to
   --  the IDF's uncalibrated constant 28 where they are not -- a hardcoded 28
   --  over-volts a calibrated part.
   procedure Cpu_Clock_Init
   with Export, Convention => C, External_Name => "cpu_clock_init",
        Linker_Section => ".iram1.bbpll";

   --  GNARL Start_All_CPUs calls this to release core 1 past its spin.
   procedure Native_Release_Core1
   with Export, Convention => C, External_Name => "native_release_core1";

   --  Board imports the runtime needs.
   procedure Native_Enable_Tick
   with Export, Convention => C, External_Name => "native_enable_tick";

   procedure Native_Enable_Cpu_Int (N : Integer)
   with Export, Convention => C, External_Name => "native_enable_cpu_int";

   function Native_Cpu_Freq_Hz return Interfaces.Unsigned_32
   with Export, Convention => C, External_Name => "native_cpu_freq_hz";

   procedure Native_Freq_Panic (Expected, Actual : Interfaces.Unsigned_32)
   with Export, Convention => C, External_Name => "native_freq_panic", No_Return;

   --  Recoverable stack overflow: arm a HW data-watchpoint a redzone above the
   --  running thread's stack limit (each runtime's s-taprop calls this from
   --  Initialize and Enter_Task, in the task's own context).  Inert unless the
   --  runtime provides the running-thread bounds (weak-imported) -- so it is
   --  safe to always link.
   procedure Gnat_Arm_Stack_Watchpoint
   with Export, Convention => C, External_Name => "__gnat_arm_stack_watchpoint";

end Bare_Glue;
