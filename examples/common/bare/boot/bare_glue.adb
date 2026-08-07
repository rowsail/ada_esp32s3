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

   --------------------------
   -- Bbpll_480M_Configure --
   --------------------------

   --  Ported from the IDF's rtc_clk_bbpll_configure / clk_ll_bbpll_* for the
   --  ESP32-S3 (480 MHz VCO from a 40 MHz crystal).  Only the 40 MHz XTAL case
   --  is covered: every board this bare boot supports uses one, and start.S's
   --  240 MHz target assumes it.
   procedure Bbpll_480M_Configure is

      --  ---- registers ------------------------------------------------------
      Rtc_Options0 : constant := 16#6000_8000#;   --  RTC_CNTL_OPTIONS0
      Ana_Conf0    : constant := 16#6000_E040#;   --  I2C_MST_ANA_CONF0
      Cpu_Per_Conf : constant := 16#600C_0010#;   --  SYSTEM_CPU_PER_CONF

      Bb_I2C_Force_Pd       : constant := 2 ** 6;    --  OPTIONS0
      Bbpll_I2C_Force_Pd    : constant := 2 ** 8;
      Bbpll_Force_Pd        : constant := 2 ** 10;
      Bbpll_Stop_Force_High : constant := 2 ** 2;    --  ANA_CONF0
      Bbpll_Stop_Force_Low  : constant := 2 ** 3;
      Bbpll_Cal_Done        : constant := 2 ** 24;
      Pll_Freq_Sel_480      : constant := 2 ** 2;    --  CPU_PER_CONF

      --  ---- regi2c: BBPLL block, and the register indices we program -------
      Bbpll_Block   : constant Unsigned_8 := 16#66#;
      Bbpll_Host    : constant Unsigned_8 := 1;
      Reg_Ref_Div   : constant Unsigned_8 := 2;   --  I2C_BBPLL_OC_REF_DIV
      Reg_Div_7_0   : constant Unsigned_8 := 3;   --  I2C_BBPLL_OC_DIV_7_0
      Reg_Mode_Hf   : constant Unsigned_8 := 4;   --  I2C_BBPLL_MODE_HF
      Reg_Dr1_Dr3   : constant Unsigned_8 := 5;   --  I2C_BBPLL_OC_DR1 / _DR3
      Reg_Dcur      : constant Unsigned_8 := 6;   --  I2C_BBPLL_OC_DCUR
      Reg_Vco_Dbias : constant Unsigned_8 := 9;   --  I2C_BBPLL_OC_VCO_DBIAS

      --  480 MHz from 40 MHz: div_ref = 0, div7_0 = 8, dr1 = dr3 = 0,
      --  dchgp = 5, dcur = 3, dbias = 3 (IDF clk_ll_bbpll_set_config).
      Mode_Hf_480 : constant Unsigned_8 := 16#6B#;
      Ref_Div_Val : constant Unsigned_8 := 16#50#;  --  dchgp(5) << 4 | div_ref(0)
      Div_7_0_Val : constant Unsigned_8 := 8;
      Dcur_Val    : constant Unsigned_8 := 16#73#;  --  dlref(1)<<6 | dhref(3)<<4 | dcur(3)
      Dbias_Val   : constant Unsigned_8 := 3;

      procedure Regi2c_Write (Block, Host, Reg, Data : Unsigned_8)
      with Import, Convention => C, External_Name => "esp_rom_regi2c_write";
      procedure Regi2c_Write_Mask
        (Block, Host, Reg, Msb, Lsb, Data : Unsigned_8)
      with Import, Convention => C, External_Name => "esp_rom_regi2c_write_mask";
      procedure Ets_Delay_Us (Us : Unsigned_32)
      with Import, Convention => C, External_Name => "ets_delay_us";

      procedure Poke (Addr, Val : Unsigned_32) is
         R : Unsigned_32
         with Import, Volatile, Address => To_Address (Integer_Address (Addr));
      begin
         R := Val;
      end Poke;

      function Peek (Addr : Unsigned_32) return Unsigned_32 is
         R : Unsigned_32
         with Import, Volatile, Address => To_Address (Integer_Address (Addr));
      begin
         return R;
      end Peek;

   begin
      --  1. Power up the BBPLL and its regi2c master (clearing the force-PD
      --     bits is a no-op on a ROM that already brought them up).
      Poke (Rtc_Options0,
            Peek (Rtc_Options0)
              and not (Bb_I2C_Force_Pd or Bbpll_I2C_Force_Pd or Bbpll_Force_Pd));

      --  2. Digital part: select the 480 MHz VCO.
      Poke (Cpu_Per_Conf, Peek (Cpu_Per_Conf) or Pll_Freq_Sel_480);

      --  3. Start calibration, program the analog part, wait for CAL_DONE.
      Poke (Ana_Conf0, Peek (Ana_Conf0) and not Bbpll_Stop_Force_High);
      Poke (Ana_Conf0, Peek (Ana_Conf0) or Bbpll_Stop_Force_Low);

      Regi2c_Write (Bbpll_Block, Bbpll_Host, Reg_Mode_Hf, Mode_Hf_480);
      Regi2c_Write (Bbpll_Block, Bbpll_Host, Reg_Ref_Div, Ref_Div_Val);
      Regi2c_Write (Bbpll_Block, Bbpll_Host, Reg_Div_7_0, Div_7_0_Val);
      Regi2c_Write_Mask (Bbpll_Block, Bbpll_Host, Reg_Dr1_Dr3, 2, 0, 0);  --  DR1
      Regi2c_Write_Mask (Bbpll_Block, Bbpll_Host, Reg_Dr1_Dr3, 6, 4, 0);  --  DR3
      Regi2c_Write (Bbpll_Block, Bbpll_Host, Reg_Dcur, Dcur_Val);
      Regi2c_Write_Mask
        (Bbpll_Block, Bbpll_Host, Reg_Vco_Dbias, 1, 0, Dbias_Val);

      while (Peek (Ana_Conf0) and Bbpll_Cal_Done) = 0 loop
         null;
      end loop;
      Ets_Delay_Us (10);

      --  4. Stop calibration; the VCO is now locked and safe to clock from.
      Poke (Ana_Conf0, Peek (Ana_Conf0) and not Bbpll_Stop_Force_Low);
      Poke (Ana_Conf0, Peek (Ana_Conf0) or Bbpll_Stop_Force_High);
   end Bbpll_480M_Configure;

   -----------------------------
   -- Cpu_240M_Raise_Voltage --
   -----------------------------

   procedure Cpu_240M_Raise_Voltage is
      Rtc_Date_Reg : constant := 16#6000_81FC#;   --  RTC_CNTL_DATE
      Slave_Pd_Mask  : constant := 16#3F#;
      Slave_Pd_Shift : constant := 13;

      Dig_Block : constant Unsigned_8 := 16#6D#;  --  I2C_DIG_REG
      Dig_Host  : constant Unsigned_8 := 1;
      Reg_Rtc_Dreg : constant Unsigned_8 := 4;    --  I2C_DIG_REG_EXT_RTC_DREG
      Reg_Dig_Dreg : constant Unsigned_8 := 6;    --  I2C_DIG_REG_EXT_DIG_DREG
      Dreg_Msb : constant Unsigned_8 := 4;
      Dreg_Lsb : constant Unsigned_8 := 0;

      --  IDF rtc_init.c: g_rtc_dbias_pvt_240m = g_dig_dbias_pvt_240m = 28.
      --  (The IDF may refine these from the PVT calibration eFuses; 28 is the
      --  uncalibrated default and is what this bare boot uses.)
      Dbias_240M : constant Unsigned_8 := 28;

      --  DEFAULT_LDO_SLAVE (0x7) >> (240 / 80) -- open the LDO slaves for the
      --  240 MHz load, which damps the voltage step as the frequency rises.
      Ldo_Slave_240M : constant Unsigned_32 := 16#7# / 2 ** 3;

      procedure Regi2c_Write_Mask
        (Block, Host, Reg, Msb, Lsb, Data : Unsigned_8)
      with Import, Convention => C, External_Name => "esp_rom_regi2c_write_mask";
      procedure Ets_Delay_Us (Us : Unsigned_32)
      with Import, Convention => C, External_Name => "ets_delay_us";

      procedure Poke (Addr, Val : Unsigned_32) is
         R : Unsigned_32
         with Import, Volatile, Address => To_Address (Integer_Address (Addr));
      begin
         R := Val;
      end Poke;

      function Peek (Addr : Unsigned_32) return Unsigned_32 is
         R : Unsigned_32
         with Import, Volatile, Address => To_Address (Integer_Address (Addr));
      begin
         return R;
      end Peek;

   begin
      Regi2c_Write_Mask
        (Dig_Block, Dig_Host, Reg_Rtc_Dreg, Dreg_Msb, Dreg_Lsb, Dbias_240M);
      Regi2c_Write_Mask
        (Dig_Block, Dig_Host, Reg_Dig_Dreg, Dreg_Msb, Dreg_Lsb, Dbias_240M);
      Ets_Delay_Us (40);   --  let the regulators settle before the step up

      Poke (Rtc_Date_Reg,
            (Peek (Rtc_Date_Reg)
               and not Unsigned_32 (Slave_Pd_Mask * 2 ** Slave_Pd_Shift))
            or (Ldo_Slave_240M * 2 ** Slave_Pd_Shift));
   end Cpu_240M_Raise_Voltage;

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

   Stack_Ovf_Redzone : constant := 2048;
   --  Headroom below the watchpoint: after it fires, the Storage_Error
   --  raise and the ZCX unwinder's phase-1/2 machinery run on the faulting
   --  task's stack BELOW the watched line, and an interrupt arriving before
   --  the unwind completes still deposits an XT_STK frame there (the bulk
   --  of ISR execution moves to the interrupt stack).  512 was not enough
   --  for the unwinder alone.

   --  __gnat_running_stack_bounds(void **low, void **high): weak; every GNARL
   --  profile's s-bbthre exports it.  Absent (no tasking runtime linked) -> the
   --  arming is a no-op.
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
