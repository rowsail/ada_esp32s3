with Interfaces;              use Interfaces;
with System;                  use System;
with System.Machine_Code;     use System.Machine_Code;
with System.Storage_Elements; use System.Storage_Elements;

package body Bare_Glue is

   --  Note: strings passed to esp_rom_printf MUST be static (compile-time, in
   --  .rodata) -- this unit is ZFP / No_Elaboration, so a String that needs
   --  elaboration to build would stay empty.  Concatenating ASCII.* character
   --  literals keeps them static (aggregates like (1 => ASCII.LF) do not).

   ---------------------------------------------------------------------------
   --  Cross-core hand-off state (was file-static in bare_glue.c).  core 0 and
   --  core 1 poll these; Volatile keeps every access a real load/store and the
   --  `memw` barriers below order them.
   ---------------------------------------------------------------------------
   Core1_Go      : Integer      := 0 with Volatile;  --  GNARL released core 1
   Core1_Alive   : Integer      := 0 with Volatile;  --  core 1 reached its entry
   Sync_Go       : Integer      := 0 with Volatile;  --  core 0 published a CCOUNT
   Sync_Ccount   : Unsigned_32  := 0 with Volatile;
   Saved_Vecbase : Unsigned_32  := 0 with Volatile;  --  core 0 VECBASE, for core 1

   ---------------------------------------------------------------------------
   --  Imports: the ROM, the GNARL runtime, the start.S trampolines, and the
   --  Bare_Boot esp_cpu.h stand-ins.
   ---------------------------------------------------------------------------

   --  ROM.
   procedure Esp_Rom_Printf (Fmt : System.Address)
   with Import, Convention => C, External_Name => "esp_rom_printf";
   procedure Esp_Rom_Printf2 (Fmt : System.Address; A, B : Unsigned_32)
   with Import, Convention => C, External_Name => "esp_rom_printf";
   procedure Ets_Set_Appcpu_Boot_Addr (Addr : Unsigned_32)
   with Import, Convention => C, External_Name => "ets_set_appcpu_boot_addr";

   --  Bare_Boot (esp_cpu.h stand-ins + CPU special-register access).
   procedure Esp_Cpu_Intr_Enable (Mask : Unsigned_32)
   with Import, Convention => C, External_Name => "esp_cpu_intr_enable";
   function Esp_Clk_Cpu_Freq return Integer_32
   with Import, Convention => C, External_Name => "esp_clk_cpu_freq";
   procedure Native_Start_Core1
   with Import, Convention => C, External_Name => "native_start_core1";
   function Native_Get_Ccount return Unsigned_32
   with Import, Convention => C, External_Name => "native_get_ccount";
   procedure Native_Set_Ccount (Count : Unsigned_32)
   with Import, Convention => C, External_Name => "native_set_ccount";
   function Native_Get_Vecbase return Unsigned_32
   with Import, Convention => C, External_Name => "native_get_vecbase";

   --  GNARL runtime + binder.
   procedure Adainit
   with Import, Convention => C, External_Name => "adainit";
   procedure Gnat_Start_Slave_Cpus
   with Import, Convention => C, External_Name => "__gnat_start_slave_cpus";
   procedure Gnat_Esp32s3_Core1_Entry
   with Import, Convention => C, External_Name => "__gnat_esp32s3_core1_entry";

   --  start.S trampolines.
   procedure Gnat_Enter_Env
   with Import, Convention => C, External_Name => "__gnat_enter_env", No_Return;
   procedure Core1_Start
   with Import, Convention => C, External_Name => "core1_start";

   --  The example's Ada main.  bare_build.sh --defsym's "ada_env_main" to the
   --  example's _ada_<unit>, so this unit needs no per-example macro.
   procedure Ada_Env_Main
   with Import, Convention => C, External_Name => "ada_env_main";

   --  Force-link the level-5 vector (highint5.S) by referencing its marker.
   Gnat_Hi5_Marker : Integer
   with Import, Volatile, Convention => C, External_Name => "gnat_hi5_marker";

   --  Weak, may be absent -- null-checked before the call (the idiom the C used
   --  for adafinal).  bare_board_init: strong in an example's glue (e.g. PSRAM).
   --  bare_register_eh_frames: strong in bare_crt (embedded/full).  adafinal /
   --  __run_library_finalizers: emitted only by the finalizing binders.
   procedure Bare_Board_Init
   with Import, Convention => C, External_Name => "bare_board_init";
   pragma Weak_External (Bare_Board_Init);
   procedure Bare_Register_Eh_Frames
   with Import, Convention => C, External_Name => "bare_register_eh_frames";
   pragma Weak_External (Bare_Register_Eh_Frames);
   procedure Adafinal
   with Import, Convention => C, External_Name => "adafinal";
   pragma Weak_External (Adafinal);
   procedure Run_Library_Finalizers
   with Import, Convention => C, External_Name => "__run_library_finalizers";
   pragma Weak_External (Run_Library_Finalizers);

   --------------------------
   -- Native_Release_Core1 --
   --------------------------

   procedure Native_Release_Core1 is
   begin
      Core1_Go := 1;
   end Native_Release_Core1;

   -----------------------
   -- Native_Enable_Tick --
   -----------------------

   procedure Native_Enable_Tick is
   begin
      Esp_Cpu_Intr_Enable (Shift_Left (1, 16));   --  CCOMPARE2 tick
   end Native_Enable_Tick;

   --------------------------
   -- Native_Enable_Cpu_Int --
   --------------------------

   procedure Native_Enable_Cpu_Int (N : Integer) is
   begin
      Esp_Cpu_Intr_Enable (Shift_Left (1, N));
   end Native_Enable_Cpu_Int;

   -----------------------
   -- Native_Cpu_Freq_Hz --
   -----------------------

   function Native_Cpu_Freq_Hz return Unsigned_32
   is (Unsigned_32 (Esp_Clk_Cpu_Freq));

   ----------------------
   -- Native_Freq_Panic --
   ----------------------

   Panic_Msg : constant String :=
     "[boot] FATAL: CPU %u Hz != runtime %u Hz" & ASCII.LF & ASCII.NUL;

   procedure Native_Freq_Panic (Expected, Actual : Unsigned_32) is
   begin
      Esp_Rom_Printf2 (Panic_Msg'Address, Actual, Expected);
      loop
         null;
      end loop;
   end Native_Freq_Panic;

   -------------------
   -- Ada_Env_Body --
   -------------------

   procedure Ada_Env_Body is
   begin
      if Bare_Board_Init'Address /= System.Null_Address then
         Bare_Board_Init;               --  e.g. bring up + map external PSRAM
      end if;
      if Bare_Register_Eh_Frames'Address /= System.Null_Address then
         Bare_Register_Eh_Frames;       --  register .eh_frame before any raise
      end if;
      Adainit;                          --  elaborate + activate tasks (core 0)
      Gnat_Start_Slave_Cpus;            --  -> Native_Release_Core1 -> Core1_Go
      Ada_Env_Main;                     --  the Ada main (batch runner loops; a
                                        --  test-as-main returns here)
      if Adafinal'Address /= System.Null_Address then
         Adafinal;                      --  await library tasks + finalize (RM 7.6.1)
      end if;
      if Run_Library_Finalizers'Address /= System.Null_Address then
         Run_Library_Finalizers;        --  ACATS: library-object Finalize grades
      end if;
      loop
         null;
      end loop;
   end Ada_Env_Body;

   --------------------
   -- Core1_Bare_Main --
   --------------------

   --  VECBASE must be established before ANY windowed call (a windowed call
   --  could itself fault into an unset vector base), so the wsr.vecbase is this
   --  procedure's first act -- inline asm, reached only by the entry prologue's
   --  window rotation and a plain load of Saved_Vecbase (no call).
   procedure Core1_Bare_Main is
   begin
      Asm ("wsr.vecbase %0" & ASCII.LF & ASCII.HT & "rsync",
           Inputs   => Unsigned_32'Asm_Input ("r", Saved_Vecbase),
           Volatile => True);
      Core1_Alive := 1;                 --  tell core 0 we are up
      while Sync_Go = 0 loop            --  wait for a fresh core-0 CCOUNT
         null;
      end loop;
      Asm ("memw", Volatile => True);
      Native_Set_Ccount (Sync_Ccount + 32);   --  align to core 0 (240 MHz; tuned)
      while Core1_Go = 0 loop           --  wait for GNARL Start_All_CPUs release
         null;
      end loop;
      Gnat_Esp32s3_Core1_Entry;         --  enter slave scheduler; never returns
      loop
         null;
      end loop;
   end Core1_Bare_Main;

   --------------
   -- App_Main --
   --------------

   Up_Msg : constant String :=
     ASCII.LF & "[boot] Ada runtime up on both cores" & ASCII.LF & ASCII.NUL;

   procedure App_Main is
   begin
      Gnat_Hi5_Marker := 1;
      Esp_Rom_Printf (Up_Msg'Address);

      Saved_Vecbase := Native_Get_Vecbase;   --  core 0's VECBASE (_vector_table)

      --  Start core 1 from cold: point the APP_CPU at our bare entry, then
      --  un-gate its clock + pulse its reset (Native_Start_Core1 in Bare_Boot).
      Ets_Set_Appcpu_Boot_Addr (Unsigned_32 (To_Integer (Core1_Start'Address)));
      Native_Start_Core1;

      while Core1_Alive = 0 loop         --  core 1 reached Core1_Bare_Main
         null;
      end loop;
      Sync_Ccount := Native_Get_Ccount;  --  fresh core-0 CCOUNT for alignment
      Asm ("memw", Volatile => True);
      Sync_Go := 1;                      --  release core 1's CCOUNT alignment

      Gnat_Enter_Env;                    --  enter Ada_Env_Body as outermost frame
   end App_Main;

   ------------------------------
   -- Gnat_Arm_Stack_Watchpoint --
   ------------------------------

   Stack_Ovf_Redzone : constant := 512;

   --  __gnat_running_stack_bounds(void **low, void **high): weak, present only in
   --  the full runtime.  Absent -> the arming is a no-op (never actually reached
   --  outside full, whose s-taprop is the sole caller of this procedure).
   procedure Gnat_Running_Stack_Bounds (Low_Ptr, High_Ptr : System.Address)
   with Import, Convention => C, External_Name => "__gnat_running_stack_bounds";
   pragma Weak_External (Gnat_Running_Stack_Bounds);

   procedure Gnat_Arm_Stack_Watchpoint is
      Low, High : System.Address := System.Null_Address;
      Addr, Dbc : Unsigned_32;
   begin
      if Gnat_Running_Stack_Bounds'Address = System.Null_Address then
         return;
      end if;
      Gnat_Running_Stack_Bounds (Low'Address, High'Address);
      if Low = System.Null_Address then
         return;                         --  no running thread / unknown
      end if;
      --  A store data-breakpoint (data break #1) a redzone above the limit, on a
      --  64-byte window: DBREAKA1 = watched addr, DBREAKC1 = StoreBreak | mask 0x3F.
      Addr := (Unsigned_32 (To_Integer (Low)) + Stack_Ovf_Redzone) and not 63;
      Dbc  := 16#8000_0000# or 16#3F#;
      Asm ("wsr.dbreaka1 %0" & ASCII.LF & ASCII.HT
           & "wsr.dbreakc1 %1" & ASCII.LF & ASCII.HT & "dsync",
           Inputs   => (Unsigned_32'Asm_Input ("r", Addr),
                        Unsigned_32'Asm_Input ("r", Dbc)),
           Volatile => True);
   end Gnat_Arm_Stack_Watchpoint;

end Bare_Glue;
