with Interfaces;             use Interfaces;
with ESP32S3_Registers;      use ESP32S3_Registers;
with ESP32S3_Registers.TIMG; use ESP32S3_Registers.TIMG;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.Timer is

   Src_Hz : constant := 80_000_000;             --  APB clock feeds the timers

   type Periph_Ref is access all TIMG_Peripheral;

   function Regs_Of (Idx : Timer_Index) return Periph_Ref
   is (case Idx is
         when 0 => TIMG0_Periph'Access,
         when 1 => TIMG1_Periph'Access);

   --------------------------------------------------------------------------
   --  Timer-ownership pool (ensures the group clocks are on).
   --------------------------------------------------------------------------

   type Use_Map is array (Timer_Index) of Boolean;

   protected Pool is
      procedure Claim (Index : Timer_Index; Ok : out Boolean);
      procedure Release (Index : Timer_Index);
   private
      In_Use : Use_Map := (others => False);
      Inited : Boolean := False;
   end Pool;

   protected body Pool is
      procedure Claim (Index : Timer_Index; Ok : out Boolean) is
         use ESP32S3_Registers.SYSTEM;
      begin
         if not Inited then
            --  Both timer-group clocks default on; make sure (don't reset the
            --  group -- that would disturb the watchdogs).
            SYSTEM_Periph.PERIP_CLK_EN0.TIMERGROUP_CLK_EN := True;
            SYSTEM_Periph.PERIP_CLK_EN0.TIMERGROUP1_CLK_EN := True;
            Inited := True;
         end if;
         Ok := not In_Use (Index);
         if Ok then
            In_Use (Index) := True;
         end if;
      end Claim;

      procedure Release (Index : Timer_Index) is
      begin
         In_Use (Index) := False;
      end Release;
   end Pool;

   -----------
   -- Claim --
   -----------

   procedure Claim (T : in out Timer; Index : Timer_Index) is
      Ok : Boolean;
   begin
      Release (T);
      Pool.Claim (Index, Ok);
      if Ok then
         T.Idx := Index;
         T.Held := True;
      end if;
   end Claim;

   function Is_Valid (T : Timer) return Boolean
   is (T.Held);

   procedure Release (T : in out Timer) is
   begin
      if T.Held then
         Regs_Of (T.Idx).TCONFIG0.EN := False;     --  stop the counter
         Pool.Release (T.Idx);
         T.Held := False;
      end if;
   end Release;

   overriding
   procedure Finalize (T : in out Timer) is
   begin
      Release (T);
   end Finalize;

   ---------------
   -- Configure --
   ---------------

   procedure Configure (T : in out Timer; Tick_Hz : Positive := 1_000_000) is
      R   : constant Periph_Ref := Regs_Of (T.Idx);
      Div : constant Natural :=
        Natural'Max (1, Natural'Min (65_535, Src_Hz / Tick_Hz));
   begin
      if not T.Held then
         return;
      end if;
      R.TCONFIG0 :=
        (EN         => False,
         INCREASE   => True,
         AUTORELOAD => False,
         USE_XTAL   => False,
         ALARM_EN   => False,
         DIVIDER    => TCONFIG_DIVIDER_Field (Div),
         others     => <>);
      Reset (T);
   end Configure;

   -----------
   -- Start --
   -----------

   procedure Start (T : Timer) is
   begin
      if T.Held then
         Regs_Of (T.Idx).TCONFIG0.EN := True;
      end if;
   end Start;

   procedure Stop (T : Timer) is
   begin
      if T.Held then
         Regs_Of (T.Idx).TCONFIG0.EN := False;
      end if;
   end Stop;

   -----------
   -- Reset --
   -----------

   procedure Reset (T : Timer) is
      R : constant Periph_Ref := Regs_Of (T.Idx);
   begin
      if T.Held then
         R.TLOADLO0 := 0;
         R.TLOADHI0 := (LOAD_HI => 0, others => <>);
         R.TLOAD0 :=
           1;                  --  any write loads TLOADLO/HI -> counter

      end if;
   end Reset;

   -----------
   -- Value --
   -----------

   function Value (T : Timer) return Ticks is
      R : constant Periph_Ref := Regs_Of (T.Idx);
   begin
      if not T.Held then
         return 0;
      end if;
      R.TUPDATE0 := (UPDATE => True, others => <>);   --  latch the live count
      return
        Ticks (Unsigned_64 (R.THI0.HI)) * 2**32 + Ticks (Unsigned_64 (R.TLO0));
   end Value;

   ---------------
   -- Set_Alarm --
   ---------------

   procedure Set_Alarm (T : Timer; At_Ticks : Ticks) is
      R : constant Periph_Ref := Regs_Of (T.Idx);
      V : constant Unsigned_64 := Unsigned_64 (At_Ticks);
   begin
      if not T.Held then
         return;
      end if;
      R.TALARMLO0 := UInt32 (V and 16#FFFF_FFFF#);
      R.TALARMHI0 :=
        (ALARM_HI =>
           TALARMHI_ALARM_HI_Field (Shift_Right (V, 32) and 16#3F_FFFF#),
         others   => <>);
      R.INT_CLR_TIMERS.T0_INT_CLR := True;            --  clear any stale flag
      R.TCONFIG0.ALARM_EN := True;
   end Set_Alarm;

   function Alarm_Fired (T : Timer) return Boolean is
   begin
      if not T.Held then
         return False;
      end if;
      return Regs_Of (T.Idx).INT_RAW_TIMERS.T0_INT_RAW;
   end Alarm_Fired;

   procedure Clear_Alarm (T : Timer) is
   begin
      if T.Held then
         Regs_Of (T.Idx).INT_CLR_TIMERS.T0_INT_CLR := True;
      end if;
   end Clear_Alarm;

end ESP32S3.Timer;
