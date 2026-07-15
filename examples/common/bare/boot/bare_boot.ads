--  Bare_Boot: the IDF-free boot-support shims the bare examples need -- the C
--  entry start_c() that start.S jumps to, the few ESP-IDF esp_cpu.h symbols
--  bare_glue.c calls, and the SYSTIMER clock source the GNARL runtime reads.
--
--  Rewritten from the former stubs.c over the svd-derived ESP32S3_Registers, so
--  the register accesses are NAMED + TYPED (Periph.Reg.Field) instead of
--  hand-written addresses with magic bit shifts.  Compiled ZFP-style -- no
--  binder, no runtime, no elaboration -- so start_c can run before adainit (see
--  bare_boot.gpr).  Symbols keep their C names so start.S / bare_glue.c / the
--  runtime link unchanged.
with Interfaces; use Interfaces;
with System;

package Bare_Boot is

   --  ESP-IDF esp_cpu.h stand-ins (called from bare_glue.c).

   procedure Esp_Cpu_Intr_Enable (Mask : Unsigned_32)
   with Export, Convention => C, External_Name => "esp_cpu_intr_enable";

   procedure Esp_Cpu_Stall (Core : Integer_32)
   with Export, Convention => C, External_Name => "esp_cpu_stall";

   procedure Esp_Cpu_Unstall (Core : Integer_32)
   with Export, Convention => C, External_Name => "esp_cpu_unstall";

   procedure Esp_Cpu_Reset (Core : Integer_32)
   with Export, Convention => C, External_Name => "esp_cpu_reset";

   function Esp_Clk_Cpu_Freq return Integer_32
   with Export, Convention => C, External_Name => "esp_clk_cpu_freq";

   procedure Esp_Restart
   with Export, Convention => C, External_Name => "esp_restart";

   --  Cold-start the APP_CPU (core 1).
   procedure Native_Start_Core1
   with Export, Convention => C, External_Name => "native_start_core1";

   --  Route the cross-core IPI poke (FROM_CPU_INTR_2 on core 0, FROM_CPU_INTR_3
   --  on core 1) to its CPU interrupt.  core 1 also enables the CCOMPARE2 tick.
   procedure Native_Setup_Poke_Core0
   with Export, Convention => C, External_Name => "native_setup_poke_core0";

   procedure Native_Setup_Poke_Core1
   with Export, Convention => C, External_Name => "native_setup_poke_core1";

   --  Route each core's SYSTIMER UNIT0 comparator interrupt (TARGET0 on core 0,
   --  TARGET1 on core 1) to CPU_INT 26 (level 5), enable the comparator + its
   --  interrupt, and unmask the CPU int.  The systimer keeps counting while the
   --  CPU idles in waiti, so unlike CCOMPARE2 this alarm wakes a fully-idle core.
   procedure Native_Setup_Systimer_Core0
   with Export, Convention => C, External_Name => "native_setup_systimer_core0";

   procedure Native_Setup_Systimer_Core1
   with Export, Convention => C, External_Name => "native_setup_systimer_core1";

   --  Xtensa CPU special registers (rsr/wsr): the core id (PRID), the cycle
   --  counter (CCOUNT), and the exception vector base (VECBASE).  These are not
   --  memory-mapped, so System.Machine_Code asm rather than svd.  (The one-shot
   --  VECBASE *write* on core 1 stays inline in bare_glue.c -- it must precede
   --  any windowed call, before VECBASE is established.)
   function Native_Core_Id return Integer_32
   with Export, Convention => C, External_Name => "native_core_id";

   function Native_Get_Ccount return Unsigned_32
   with Export, Convention => C, External_Name => "native_get_ccount";

   procedure Native_Set_Ccount (Count : Unsigned_32)
   with Export, Convention => C, External_Name => "native_set_ccount";

   function Native_Get_Vecbase return Unsigned_32
   with Export, Convention => C, External_Name => "native_get_vecbase";

   --  Ungate the SYSTIMER; read its UNIT0 count (the runtime's Read_Clock base).
   procedure Native_Enable_Systimer
   with Export, Convention => C, External_Name => "native_enable_systimer";

   function Native_Systimer_Count return Unsigned_64
   with Export, Convention => C, External_Name => "native_systimer_count";

   --  C entry from start.S: disable the boot watchdogs, ungate the clock, run
   --  the Ada environment task (never returns).
   procedure Start_C
   with Export, Convention => C, External_Name => "start_c";

   --  Data symbol the vendored coproc hook references (unused on this path).
   Frxt_Task_Coproc_State : System.Address
   with Export, Convention => C, External_Name => "_frxt_task_coproc_state";

end Bare_Boot;
