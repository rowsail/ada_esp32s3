with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3.LEDC.Math;
with ESP32S3_Registers;      use ESP32S3_Registers;
with ESP32S3_Registers.LEDC; use ESP32S3_Registers.LEDC;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.LEDC is

   package GR renames ESP32S3_Registers.GPIO;   --  GPIO matrix register layer
   package G renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   type Timer_Index is range 0 .. 3;

   --  Channel uses timer (Index mod 4).
   function Timer_Of (Idx : Channel_Index) return Timer_Index
   is (Timer_Index (Natural (Idx) mod 4));

   ---------------------------------------------------------------------------
   --  Register overlays.  svd2ada flattened the eight identical channel blocks
   --  and four timer blocks into named fields; the hardware is a regular array
   --  (channel stride 0x14 from LEDC_Base; timer stride 0x08 from +0xA0), so we
   --  re-impose that here and index it with the runtime channel/timer number.
   ---------------------------------------------------------------------------

   type Chan_Regs is record
      CONF0  : CH_CONF_Register;
      HPOINT : CH_HPOINT_Register;
      DUTY   : CH_DUTY_Register;
      CONF1  : CH_CONF_Register_1;
      DUTY_R : CH_DUTY_R_Register;
   end record
   with Volatile;
   for Chan_Regs use
     record
       CONF0 at 16#00# range 0 .. 31;
       HPOINT at 16#04# range 0 .. 31;
       DUTY at 16#08# range 0 .. 31;
       CONF1 at 16#0C# range 0 .. 31;
       DUTY_R at 16#10# range 0 .. 31;
     end record;
   for Chan_Regs'Size use 16#14# * 8;
   for Chan_Regs'Object_Size use 16#14# * 8;

   type Chan_Array is array (Channel_Index) of Chan_Regs;
   Channels : Chan_Array
   with Import, Volatile, Address => LEDC_Periph.CH_CONF00'Address;

   type Timer_Regs is record
      CONF  : TIMER_CONF_Register;
      VALUE : TIMER_VALUE_Register;
   end record
   with Volatile;
   for Timer_Regs use
     record
       CONF at 16#0# range 0 .. 31;
       VALUE at 16#4# range 0 .. 31;
     end record;
   for Timer_Regs'Size use 16#8# * 8;
   for Timer_Regs'Object_Size use 16#8# * 8;

   type Timer_Array is array (Timer_Index) of Timer_Regs;
   Timers : Timer_Array
   with Import, Volatile, Address => LEDC_Periph.TIMER_CONF0'Address;

   --  GPIO-matrix output signal for a channel (LEDC_LS_SIG_OUT0 .. OUT7).
   function Out_Signal (Idx : Channel_Index) return Natural
   is (Sigs.LEDC_LS_SIG_OUT0 + Natural (Idx));

   procedure Drive_Out (Pin : G.Pin_Id; Sig : Natural) is
      Out_Cfg : GR.FUNC_OUT_SEL_CFG_Register := GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin));
   begin
      G.Configure (Pin, Mode => G.Output, Drive => G.Drive_Strong);
      Out_Cfg.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      Out_Cfg.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin)) := Out_Cfg;
   end Drive_Out;

   --------------------------------------------------------------------------
   --  Channel-ownership pool (also brings the module + global clock up once).
   --------------------------------------------------------------------------

   type Use_Map is array (Channel_Index) of Boolean;

   protected Pool is
      procedure Claim (Index : Channel_Index; Ok : out Boolean);
      procedure Release (Index : Channel_Index);
   private
      In_Use : Use_Map := (others => False);
      Inited : Boolean := False;
   end Pool;

   protected body Pool is

      procedure Claim (Index : Channel_Index; Ok : out Boolean) is
         use ESP32S3_Registers.SYSTEM;
      begin
         if not Inited then
            SYSTEM_Periph.PERIP_CLK_EN0.LEDC_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.LEDC_RST := True;
            SYSTEM_Periph.PERIP_RST_EN0.LEDC_RST := False;
            --  Global slow clock = APB (80 MHz), module clock gate on.
            LEDC_Periph.CONF := (APB_CLK_SEL => 1, CLK_EN => True, others => <>);
            Inited := True;
         end if;

         Ok := not In_Use (Index);
         if Ok then
            In_Use (Index) := True;
         end if;
      end Claim;

      procedure Release (Index : Channel_Index) is
      begin
         In_Use (Index) := False;
      end Release;

   end Pool;

   -----------
   -- Claim --
   -----------

   procedure Claim (C : in out Channel; Index : Channel_Index) is
      Ok : Boolean;
   begin
      Release (C);
      Pool.Claim (Index, Ok);
      if Ok then
         C.Idx := Index;
         C.Held := True;
      end if;
   end Claim;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (C : Channel) return Boolean
   is (C.Held);

   ----------
   -- Stop --
   ----------

   procedure Stop (C : Channel) is
   begin
      if C.Held then
         Channels (C.Idx).CONF0.SIG_OUT_EN := False;
         Channels (C.Idx).CONF0.PARA_UP := True;   --  commit

      end if;
   end Stop;

   -------------
   -- Release --
   -------------

   procedure Release (C : in out Channel) is
   begin
      if C.Held then
         Stop (C);
         Pool.Release (C.Idx);
         C.Held := False;
      end if;
   end Release;

   overriding
   procedure Finalize (C : in out Channel) is
   begin
      Release (C);
   end Finalize;

   ---------------
   -- Configure --
   ---------------

   procedure Configure
     (C : in out Channel; Freq : Positive; Pin : ESP32S3.GPIO.Pin_Id; Bits : Resolution := 10)
   is
      Timer_Num : constant Timer_Index := Timer_Of (C.Idx);
      --  CLK_DIV is Q10.8: div = Src / (Freq * 2**Bits), in 1/256ths, clamped to
      --  the field range.  The (proved) divider math lives in ESP32S3.LEDC.Math.
      Div       : constant Natural := Math.Clock_Divider (Freq, Bits);
   begin
      if not C.Held then
         return;
      end if;
      C.Bits := Bits;                        --  remembered for Set_Duty's scaling

      --  Timer: set divider + resolution, commit, then pulse reset to start it.
      Timers (Timer_Num).CONF :=
        (DUTY_RES => TIMER_CONF_DUTY_RES_Field (Bits),
         CLK_DIV  => TIMER_CONF_CLK_DIV_Field (Div),
         TICK_SEL => False,
         PAUSE    => False,
         RST      => True,
         PARA_UP  => True,
         others   => <>);
      Timers (Timer_Num).CONF.RST := False;          --  release reset -> counter runs

      --  Channel: hpoint 0, duty 0, bound to the timer, output enabled.
      Channels (C.Idx).HPOINT.HPOINT := 0;
      Channels (C.Idx).DUTY.DUTY := 0;
      Channels (C.Idx).CONF0 :=
        (TIMER_SEL  => CH_CONF_TIMER_SEL_Field (Timer_Num),
         SIG_OUT_EN => True,
         PARA_UP    => True,
         others     => <>);
      Channels (C.Idx).CONF1 :=
        (DUTY_START => True,
         DUTY_INC   => True,
         DUTY_NUM   => 0,
         DUTY_CYCLE => 1,
         DUTY_SCALE => 0,
         others     => <>);

      Drive_Out (Pin, Out_Signal (C.Idx));
   end Configure;

   --------------
   -- Set_Duty --
   --------------

   procedure Set_Duty (C : Channel; Percent : Duty_Percent) is
      --  The duty scaling (proved free of range error) lives in ESP32S3.LEDC.Math.
      Count : constant Natural := Math.Duty_Count (C.Bits, Percent);
   begin
      if not C.Held then
         return;
      end if;
      --  Duty register holds the count in its high bits (4 fractional bits).
      Channels (C.Idx).DUTY.DUTY := CH_DUTY_DUTY_Field (Count * 16);
      Channels (C.Idx).CONF1 :=
        (DUTY_START => True,
         DUTY_INC   => True,
         DUTY_NUM   => 0,
         DUTY_CYCLE => 1,
         DUTY_SCALE => 0,
         others     => <>);
      Channels (C.Idx).CONF0.PARA_UP := True;   --  latch the new duty
   end Set_Duty;

end ESP32S3.LEDC;
