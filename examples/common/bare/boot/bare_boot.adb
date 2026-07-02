with System.Machine_Code;               use System.Machine_Code;
with ESP32S3_Registers.INTERRUPT_CORE0; use ESP32S3_Registers.INTERRUPT_CORE0;
with ESP32S3_Registers.INTERRUPT_CORE1; use ESP32S3_Registers.INTERRUPT_CORE1;
with ESP32S3_Registers.RTC_CNTL;        use ESP32S3_Registers.RTC_CNTL;
with ESP32S3_Registers.SYSTEM;          use ESP32S3_Registers.SYSTEM;
with ESP32S3_Registers.SYSTIMER;        use ESP32S3_Registers.SYSTIMER;

package body Bare_Boot is

   --  The CPU interrupt the cross-core IPI poke is routed to.
   POKE_CPU_INT : constant := 31;

   --  Vendored Xtensa asm: enable a set of interrupts (was the esp_cpu.h inline).
   procedure Xt_Ints_On (Mask : Unsigned_32)
   with Import, Convention => C, External_Name => "xt_ints_on";

   --  The Ada environment-task entry (bare_glue.c); never returns.
   procedure App_Main
   with Import, Convention => C, External_Name => "app_main";

   ---------------------------
   -- Esp_Cpu_Intr_Enable --
   ---------------------------

   procedure Esp_Cpu_Intr_Enable (Mask : Unsigned_32) is
   begin
      Xt_Ints_On (Mask);
   end Esp_Cpu_Intr_Enable;

   -------------------------------------------------------------------
   -- Core 1 (APP_CPU) stall / unstall: the RTC stall value 0x86 is --
   -- split across OPTIONS0[1:0] and SW_CPU_STALL[25:20].           --
   -------------------------------------------------------------------

   procedure Esp_Cpu_Stall (Core : Integer_32) is
   begin
      if Core = 0 then
         return;                                  --  never stall self (PRO_CPU)

      end if;
      RTC_CNTL_Periph.OPTIONS0.SW_STALL_APPCPU_C0 := 2#10#;
      RTC_CNTL_Periph.SW_CPU_STALL.SW_STALL_APPCPU_C1 := 16#21#;
   end Esp_Cpu_Stall;

   procedure Esp_Cpu_Unstall (Core : Integer_32) is
   begin
      if Core = 0 then
         return;
      end if;
      RTC_CNTL_Periph.OPTIONS0.SW_STALL_APPCPU_C0 := 0;
      RTC_CNTL_Periph.SW_CPU_STALL.SW_STALL_APPCPU_C1 := 0;
   end Esp_Cpu_Unstall;

   -------------------
   -- Esp_Cpu_Reset --
   -------------------

   procedure Esp_Cpu_Reset (Core : Integer_32) is
   begin
      if Core = 0 then
         RTC_CNTL_Periph.OPTIONS0.SW_PROCPU_RST := True;
      else
         RTC_CNTL_Periph.OPTIONS0.SW_APPCPU_RST := True;
      end if;
   end Esp_Cpu_Reset;

   ---------------------
   -- Esp_Clk_Cpu_Freq --
   ---------------------

   --  The runtime's Clock_Frequency is a compile-time 240 MHz constant.
   function Esp_Clk_Cpu_Freq return Integer_32
   is (240_000_000);

   -----------------
   -- Esp_Restart --
   -----------------

   procedure Esp_Restart is
   begin
      RTC_CNTL_Periph.OPTIONS0.SW_SYS_RST := True;   --  software system reset
      loop
         null;
      end loop;
   end Esp_Restart;

   -----------------------
   -- Native_Start_Core1 --
   -----------------------

   --  Start the APP_CPU from COLD.  The IDF-free bootloader only starts core 0,
   --  so core 1 is left clock-gated and in reset (the RTC SW-reset pokes above
   --  only work on an already-clocked core).  Replicate ESP-IDF's cpu_start.c:
   --  un-gate the APP_CPU clock, clear run-stall, pulse the core-1 reset -- then
   --  core 1 boots at the ets_set_appcpu_boot_addr target (core1_bare_main).
   procedure Native_Start_Core1 is
   begin
      SYSTEM_Periph.CORE_1_CONTROL_0.CONTROL_CORE_1_CLKGATE_EN := True;
      SYSTEM_Periph.CORE_1_CONTROL_0.CONTROL_CORE_1_RUNSTALL := False;
      SYSTEM_Periph.CORE_1_CONTROL_0.CONTROL_CORE_1_RESETING := True;
      SYSTEM_Periph.CORE_1_CONTROL_0.CONTROL_CORE_1_RESETING := False;
   end Native_Start_Core1;

   ---------------------------
   -- Native_Setup_Poke_Core0 --
   ---------------------------

   --  Route the FROM_CPU_INTR_2 source to CPU interrupt POKE_CPU_INT, then
   --  enable it (core 0's half of the cross-core IPI poke).
   procedure Native_Setup_Poke_Core0 is
   begin
      INTERRUPT_CORE0_Periph.CPU_INTR_FROM_CPU_2_MAP.CPU_INTR_FROM_CPU_2_MAP := POKE_CPU_INT;
      Esp_Cpu_Intr_Enable (Shift_Left (1, POKE_CPU_INT));
   end Native_Setup_Poke_Core0;

   ---------------------------
   -- Native_Setup_Poke_Core1 --
   ---------------------------

   --  core 1's half: route FROM_CPU_INTR_3, and also enable the CCOMPARE2 timer
   --  interrupt (int 16) that drives the GNARL tick on this core.
   procedure Native_Setup_Poke_Core1 is
   begin
      INTERRUPT_CORE1_Periph.CPU_INTR_FROM_CPU_3_MAP.CPU_INTR_FROM_CPU_3_MAP := POKE_CPU_INT;
      Esp_Cpu_Intr_Enable (Shift_Left (1, POKE_CPU_INT) or Shift_Left (1, 16));
   end Native_Setup_Poke_Core1;

   -------------------
   -- Native_Core_Id --
   -------------------

   --  PRID bit 13 is the core number (0 = PRO_CPU, 1 = APP_CPU).
   function Native_Core_Id return Integer_32 is
      P : Unsigned_32;
   begin
      Asm ("rsr.prid %0", Outputs => Unsigned_32'Asm_Output ("=r", P), Volatile => True);
      return Integer_32 (Shift_Right (P, 13) and 1);
   end Native_Core_Id;

   ----------------------
   -- Native_Get_Ccount --
   ----------------------

   function Native_Get_Ccount return Unsigned_32 is
      C : Unsigned_32;
   begin
      Asm ("rsr.ccount %0", Outputs => Unsigned_32'Asm_Output ("=r", C), Volatile => True);
      return C;
   end Native_Get_Ccount;

   ----------------------
   -- Native_Set_Ccount --
   ----------------------

   procedure Native_Set_Ccount (Count : Unsigned_32) is
   begin
      Asm
        ("wsr.ccount %0" & ASCII.LF & ASCII.HT & "isync",
         Inputs   => Unsigned_32'Asm_Input ("r", Count),
         Volatile => True);
   end Native_Set_Ccount;

   -----------------------
   -- Native_Get_Vecbase --
   -----------------------

   function Native_Get_Vecbase return Unsigned_32 is
      V : Unsigned_32;
   begin
      Asm ("rsr.vecbase %0", Outputs => Unsigned_32'Asm_Output ("=r", V), Volatile => True);
      return V;
   end Native_Get_Vecbase;

   ------------------
   -- Disable_WDTs --
   ------------------

   --  The RTC + super watchdogs ESP-IDF's app-init disables (else the RTC WDT,
   --  armed by the bootloader for the boot window, resets us during adainit).
   --  The *WPROTECT registers take an unlock key: write it, change config, relock.
   procedure Disable_WDTs is
   begin
      RTC_CNTL_Periph.WDTWPROTECT := 16#50D8_3AA1#;        --  unlock RTC WDT
      RTC_CNTL_Periph.WDTCONFIG0.WDT_EN := False;
      RTC_CNTL_Periph.WDTCONFIG0.WDT_FLASHBOOT_MOD_EN := False;
      RTC_CNTL_Periph.WDTWPROTECT := 0;                    --  relock

      RTC_CNTL_Periph.SWD_WPROTECT := 16#8F1D_312A#;       --  unlock super-WDT
      RTC_CNTL_Periph.SWD_CONF.SWD_AUTO_FEED_EN := True;   --  keep it fed
      RTC_CNTL_Periph.SWD_WPROTECT := 0;
   end Disable_WDTs;

   --------------------------
   -- Native_Enable_Systimer --
   --------------------------

   --  Ungate the SYSTIMER clock + UNIT0 counter.  The IDF-free bootloader leaves
   --  the SYSTIMER clock gated, so UNIT0 would not count -- and the runtime's
   --  Read_Clock reads UNIT0, so the Ada monotonic clock (every `delay`) would
   --  freeze.  Keep UNIT0 counting while a core is halted.
   procedure Native_Enable_Systimer is
   begin
      SYSTIMER_Periph.CONF.CLK_EN := True;
      SYSTIMER_Periph.CONF.TIMER_UNIT0_WORK_EN := True;
      SYSTIMER_Periph.CONF.TIMER_UNIT0_CORE0_STALL_EN := False;
      SYSTIMER_Periph.CONF.TIMER_UNIT0_CORE1_STALL_EN := False;
   end Native_Enable_Systimer;

   --------------------------
   -- Native_Systimer_Count --
   --------------------------

   function Native_Systimer_Count return Unsigned_64 is
   begin
      SYSTIMER_Periph.UNIT0_OP.TIMER_UNIT0_UPDATE := True;        --  latch UNIT0
      while not SYSTIMER_Periph.UNIT0_OP.TIMER_UNIT0_VALUE_VALID loop
         null;
      end loop;
      return
        Shift_Left (Unsigned_64 (SYSTIMER_Periph.UNIT0_VALUE_HI.TIMER_UNIT0_VALUE_HI), 32)
        or Unsigned_64 (SYSTIMER_Periph.UNIT0_VALUE_LO);
   end Native_Systimer_Count;

   -------------
   -- Start_C --
   -------------

   procedure Start_C is
   begin
      Disable_WDTs;
      Native_Enable_Systimer;   --  ungate the runtime's clock source
      App_Main;                 --  runs the Ada env task forever
      loop
         null;
      end loop;
   end Start_C;

end Bare_Boot;
