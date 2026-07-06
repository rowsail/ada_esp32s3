with Interfaces;            use Interfaces;
with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3.MCPWM.Math;
with ESP32S3_Registers;     use ESP32S3_Registers;
with ESP32S3_Registers.PWM; use ESP32S3_Registers.PWM;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.IO_MUX;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.MCPWM is

   package GR renames ESP32S3_Registers.GPIO;     --  GPIO matrix register layer
   package MX renames ESP32S3_Registers.IO_MUX;   --  IO_MUX (per-pad config)
   package G renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   type Periph_Ref is access all PWM_Peripheral;

   function Regs_Of (Unit : MCPWM_Unit) return Periph_Ref
   is (case Unit is
         when MCPWM0 => MCPWM0_Periph'Access,
         when MCPWM1 => MCPWM1_Periph'Access);

   --  OPERATOR_TIMERSEL and FAULT_DETECT are per-unit registers written
   --  field-by-field (each a read-modify-write).  Two tasks configuring
   --  different channels / fault inputs of the SAME unit would lose each other's
   --  updates, so route those RMWs through a protected object.
   protected CTRL_Guard is
      procedure Select_Timer (Unit : MCPWM_Unit; Ch : Channel_Index);
      procedure Enable_Fault
        (Unit : MCPWM_Unit; Input : Fault_Input; Active_High : Boolean);
   end CTRL_Guard;

   protected body CTRL_Guard is
      procedure Select_Timer (Unit : MCPWM_Unit; Ch : Channel_Index) is
         Regs : constant Periph_Ref := Regs_Of (Unit);
      begin
         case Ch is
            when Ch0 => Regs.OPERATOR_TIMERSEL.OPERATOR0_TIMERSEL := 0;
            when Ch1 => Regs.OPERATOR_TIMERSEL.OPERATOR1_TIMERSEL := 1;
            when Ch2 => Regs.OPERATOR_TIMERSEL.OPERATOR2_TIMERSEL := 2;
         end case;
      end Select_Timer;

      procedure Enable_Fault
        (Unit : MCPWM_Unit; Input : Fault_Input; Active_High : Boolean)
      is
         Regs : constant Periph_Ref := Regs_Of (Unit);
      begin
         case Input is
            when Fault0 =>
               Regs.FAULT_DETECT.F0_EN := True;
               Regs.FAULT_DETECT.F0_POLE := Active_High;
            when Fault1 =>
               Regs.FAULT_DETECT.F1_EN := True;
               Regs.FAULT_DETECT.F1_POLE := Active_High;
            when Fault2 =>
               Regs.FAULT_DETECT.F2_EN := True;
               Regs.FAULT_DETECT.F2_POLE := Active_High;
         end case;
      end Enable_Fault;
   end CTRL_Guard;

   --  Generator outputs OUTnA = base + 2n (OUTnB = +1); fault/capture inputs
   --  stride by 1.  Bases come from ESP32S3.GPIO_Signals (gpio_sig_map).
   function Out_Signal (Unit : MCPWM_Unit; Ch : Channel_Index) return Natural
   is ((if Unit = MCPWM0 then Sigs.PWM0_OUT0A else Sigs.PWM1_OUT0A) + 2 * Channel_Index'Pos (Ch));

   --  Route a generator output signal to Pin as a push-pull matrix output.
   procedure Route_Out (Pin : G.Pin_Id; Sig : Natural) is
      Out_Cfg : GR.FUNC_OUT_SEL_CFG_Register := GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin));
   begin
      G.Configure (Pin, Mode => G.Output, Drive => G.Drive_Strong);
      Out_Cfg.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      Out_Cfg.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin)) := Out_Cfg;
   end Route_Out;

   --  Route Pin into the matrix input signal Sig (input buffer on + pull), WITHOUT
   --  disabling the pad's output driver -- so a fault/capture input can read a pin
   --  that is also being driven (e.g. capturing a PWM output looped on one pad).
   procedure Route_In (Sig : Natural; Pin : G.Pin_Id; Pull : G.Pull_Mode) is
      use type G.Pull_Mode;
      Pad_Index : constant Natural := Natural (Pin);
      Pad_Cfg   : MX.GPIO_Register := MX.IO_MUX_Periph.GPIO (Pad_Index);
   begin
      Pad_Cfg.MCU_SEL := 1;
      Pad_Cfg.FUN_IE := True;
      Pad_Cfg.FUN_WPU := Pull = G.Pull_Up;
      Pad_Cfg.FUN_WPD := Pull = G.Pull_Down;
      MX.IO_MUX_Periph.GPIO (Pad_Index) := Pad_Cfg;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (Sig) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Pad_Index), SEL => True, others => <>);
   end Route_In;

   --  Fault / capture matrix input-signal indices (gpio_sig_map).
   function Fault_Signal (Unit : MCPWM_Unit; Input : Fault_Input) return Natural
   is ((if Unit = MCPWM0 then Sigs.PWM0_F0_IN else Sigs.PWM1_F0_IN) + Fault_Input'Pos (Input));
   function Cap_Signal (Unit : MCPWM_Unit; Chan : Cap_Index) return Natural
   is ((if Unit = MCPWM0 then Sigs.PWM0_CAP0_IN else Sigs.PWM1_CAP0_IN) + Cap_Index'Pos (Chan));

   --  Per-channel period in timer ticks (= TIMER_PERIOD + 1), set by
   --  Configure_Channel and read by Set_Duty.  Plain reads/writes of a Natural
   --  are atomic on this target, and the owner is exclusive, so no lock is needed.
   Periods : array (MCPWM_Unit, Channel_Index) of Natural := (others => (others => 1));

   --  Bring a unit's clock up (PWM clock = 160 MHz): clock-gate, pulse reset,
   --  and force the reg-file clock on.  Run lazily, once per unit, from inside
   --  the Pool on the first Claim of any of the unit's channels -- so claiming a
   --  second channel never resets a sibling that is already running.
   procedure Bring_Up_Unit (Unit : MCPWM_Unit) is
      use ESP32S3_Registers.SYSTEM;
      Regs : constant Periph_Ref := Regs_Of (Unit);
   begin
      case Unit is
         when MCPWM0 =>
            SYSTEM_Periph.PERIP_CLK_EN0.PWM0_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.PWM0_RST := True;
            SYSTEM_Periph.PERIP_RST_EN0.PWM0_RST := False;

         when MCPWM1 =>
            SYSTEM_Periph.PERIP_CLK_EN0.PWM1_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.PWM1_RST := True;
            SYSTEM_Periph.PERIP_RST_EN0.PWM1_RST := False;
      end case;

      Regs.CLK := (EN => True, others => <>);          --  force the reg-file clock on
      Regs.CLK_CFG := (CLK_PRESCALE => 0, others => <>);   --  PWM_clk = 160 MHz
   end Bring_Up_Unit;

   --------------------------------------------------------------------------
   --  Channel / capture ownership pool.  A generator channel and a capture
   --  channel are shared resources; the pool serialises Claim / Release so two
   --  tasks can never be handed the same one, and brings a unit's clock up
   --  lazily on the first Claim of any of its channels.  Once claimed, only the
   --  holder touches that channel's registers -- the operations need no lock.
   --------------------------------------------------------------------------

   type Ch_Use_Map is array (MCPWM_Unit, Channel_Index) of Boolean;
   type Cap_Use_Map is array (MCPWM_Unit, Cap_Index) of Boolean;
   type Unit_Map is array (MCPWM_Unit) of Boolean;

   protected Pool is
      procedure Claim_Channel (Unit : MCPWM_Unit; Index : Channel_Index; Ok : out Boolean);
      procedure Release_Channel (Unit : MCPWM_Unit; Index : Channel_Index);
      procedure Claim_Capture (Unit : MCPWM_Unit; Index : Cap_Index; Ok : out Boolean);
      procedure Release_Capture (Unit : MCPWM_Unit; Index : Cap_Index);
   private
      Ch_Use  : Ch_Use_Map := (others => (others => False));
      Cap_Use : Cap_Use_Map := (others => (others => False));
      Unit_Up : Unit_Map := (others => False);
   end Pool;

   protected body Pool is

      procedure Claim_Channel (Unit : MCPWM_Unit; Index : Channel_Index; Ok : out Boolean) is
      begin
         Ok := not Ch_Use (Unit, Index);
         if Ok then
            if not Unit_Up (Unit) then
               --  lazy, once per unit
               Bring_Up_Unit (Unit);
               Unit_Up (Unit) := True;
            end if;
            Ch_Use (Unit, Index) := True;
         end if;
      end Claim_Channel;

      procedure Release_Channel (Unit : MCPWM_Unit; Index : Channel_Index) is
      begin
         Ch_Use (Unit, Index) := False;
      end Release_Channel;

      procedure Claim_Capture (Unit : MCPWM_Unit; Index : Cap_Index; Ok : out Boolean) is
      begin
         Ok := not Cap_Use (Unit, Index);
         if Ok then
            if not Unit_Up (Unit) then
               --  lazy, once per unit
               Bring_Up_Unit (Unit);
               Unit_Up (Unit) := True;
            end if;
            Cap_Use (Unit, Index) := True;
         end if;
      end Claim_Capture;

      procedure Release_Capture (Unit : MCPWM_Unit; Index : Cap_Index) is
      begin
         Cap_Use (Unit, Index) := False;
      end Release_Capture;

   end Pool;

   --  Stop a generator timer (internal; shared by Stop and Release).
   procedure Do_Stop (Unit : MCPWM_Unit; Ch : Channel_Index) is
      Regs : constant Periph_Ref := Regs_Of (Unit);
   begin
      case Ch is
         --  START = 0: stop at the next timer zero

         when Ch0 =>
            Regs.TIMER0_CFG1.TIMER0_START := 0;

         when Ch1 =>
            Regs.TIMER1_CFG1.TIMER1_START := 0;

         when Ch2 =>
            Regs.TIMER2_CFG1.TIMER2_START := 0;
      end case;
   end Do_Stop;

   -----------
   -- Claim --
   -----------

   procedure Claim (C : in out Channel; Unit : MCPWM_Unit; Index : Channel_Index) is
      Ok : Boolean;
   begin
      Release (C);                     --  free any channel C already held
      Pool.Claim_Channel (Unit, Index, Ok);   --  brings the unit up on first claim
      if Ok then
         C.U := Unit;
         C.Idx := Index;
         C.Held := True;
      end if;
   end Claim;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (C : Channel) return Boolean
   is (C.Held);

   -------------
   -- Release --
   -------------

   procedure Release (C : in out Channel) is
   begin
      if C.Held then
         Do_Stop (C.U, C.Idx);         --  don't leave a freed channel driving a pad
         Pool.Release_Channel (C.U, C.Idx);
         C.Held := False;
      end if;
   end Release;

   --  Scope-exit / exception-unwind cleanup: return the channel if still held.
   overriding
   procedure Finalize (C : in out Channel) is
   begin
      Release (C);
   end Finalize;

   -----------------------
   -- Configure_Channel --
   -----------------------

   procedure Configure_Channel
     (C              : Channel;
      Freq           : Positive;
      Pin            : ESP32S3.GPIO.Pin_Id;
      Complement_Pin : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Dead_Time_Ns   : Natural := 0)
   is
      use type ESP32S3.GPIO.Pad_Number;
      Unit       : constant MCPWM_Unit := C.U;
      Ch         : constant Channel_Index := C.Idx;
      Regs       : constant Periph_Ref := Regs_Of (Unit);
      --  The (proved) period / prescaler / dead-time math lives in
      --  ESP32S3.MCPWM.Math; the register writes stay here.
      Total      : constant Natural := Math.Period_Total (Freq);       --  ticks / period
      Divider    : constant Natural := Math.Prescale_Divider (Total);  --  smallest fitting
      Ticks      : constant Natural := Math.Period_Ticks (Total, Divider);  --  TIMER_PERIOD + 1
      Prescaler  : constant Natural := Divider - 1;
      Period     : constant Natural := Ticks - 1;
      Has_B      : constant Boolean := Complement_Pin /= ESP32S3.GPIO.No_Pin;
      Dead_Ticks : constant Natural := Math.Dead_Time_Ticks (Dead_Time_Ns);
   begin
      if not C.Held then
         return;
      end if;
      Periods (Unit, Ch) := Ticks;

      --  Operator Ch is timed by timer Ch (RMW of the shared OPERATOR_TIMERSEL).
      CTRL_Guard.Select_Timer (Unit, Ch);

      --  Timer: up-count, given prescale + period, left stopped (START = 0).
      --  Comparator A: 0 % to start, reloaded at TEZ (glitch-free).
      --  Generator A: high at timer zero (UTEZ=2), low at compare-A up (UTEA=1).
      case Ch is
         when Ch0 =>
            Regs.TIMER0_CFG0 :=
              (TIMER0_PRESCALE => TIMER0_CFG0_TIMER0_PRESCALE_Field (Prescaler),
               TIMER0_PERIOD   => TIMER0_CFG0_TIMER0_PERIOD_Field (Period),
               others          => <>);
            Regs.TIMER0_CFG1 := (TIMER0_MOD => 1, TIMER0_START => 0, others => <>);
            Regs.CMPR0_CFG := (CMPR0_A_UPMETHOD => 1, others => <>);  --  TEZ
            Regs.CMPR0_VALUE0 := (CMPR0_A => 0, others => <>);
            Regs.GEN0_CFG0 := (others => <>);
            Regs.GEN0_A := (UTEZ => 2, UTEA => 1, others => <>);
            if Has_B then
               Regs.DB0_CFG :=
                 (DB0_A_OUTBYPASS   => False,
                  DB0_B_OUTBYPASS   => False,
                  DB0_FED_OUTINVERT => True,
                  others            => <>);
               Regs.DB0_RED_CFG :=
                 (DB0_RED => DB0_RED_CFG_DB0_RED_Field (Dead_Ticks), others => <>);
               Regs.DB0_FED_CFG :=
                 (DB0_FED => DB0_FED_CFG_DB0_FED_Field (Dead_Ticks), others => <>);
            else
               Regs.DB0_CFG := (others => <>);     --  bypass (A/B_OUTBYPASS default True)
            end if;

         when Ch1 =>
            Regs.TIMER1_CFG0 :=
              (TIMER1_PRESCALE => TIMER1_CFG0_TIMER1_PRESCALE_Field (Prescaler),
               TIMER1_PERIOD   => TIMER1_CFG0_TIMER1_PERIOD_Field (Period),
               others          => <>);
            Regs.TIMER1_CFG1 := (TIMER1_MOD => 1, TIMER1_START => 0, others => <>);
            Regs.CMPR1_CFG := (CMPR1_A_UPMETHOD => 1, others => <>);
            Regs.CMPR1_VALUE0 := (CMPR1_A => 0, others => <>);
            Regs.GEN1_CFG0 := (others => <>);
            Regs.GEN1_A := (UTEZ => 2, UTEA => 1, others => <>);
            if Has_B then
               Regs.DB1_CFG :=
                 (DB1_A_OUTBYPASS   => False,
                  DB1_B_OUTBYPASS   => False,
                  DB1_FED_OUTINVERT => True,
                  others            => <>);
               Regs.DB1_RED_CFG :=
                 (DB1_RED => DB1_RED_CFG_DB1_RED_Field (Dead_Ticks), others => <>);
               Regs.DB1_FED_CFG :=
                 (DB1_FED => DB1_FED_CFG_DB1_FED_Field (Dead_Ticks), others => <>);
            else
               Regs.DB1_CFG := (others => <>);
            end if;

         when Ch2 =>
            Regs.TIMER2_CFG0 :=
              (TIMER2_PRESCALE => TIMER2_CFG0_TIMER2_PRESCALE_Field (Prescaler),
               TIMER2_PERIOD   => TIMER2_CFG0_TIMER2_PERIOD_Field (Period),
               others          => <>);
            Regs.TIMER2_CFG1 := (TIMER2_MOD => 1, TIMER2_START => 0, others => <>);
            Regs.CMPR2_CFG := (CMPR2_A_UPMETHOD => 1, others => <>);
            Regs.CMPR2_VALUE0 := (CMPR2_A => 0, others => <>);
            Regs.GEN2_CFG0 := (others => <>);
            Regs.GEN2_A := (UTEZ => 2, UTEA => 1, others => <>);
            if Has_B then
               Regs.DB2_CFG :=
                 (DB2_A_OUTBYPASS   => False,
                  DB2_B_OUTBYPASS   => False,
                  DB2_FED_OUTINVERT => True,
                  others            => <>);
               Regs.DB2_RED_CFG :=
                 (DB2_RED => DB2_RED_CFG_DB2_RED_Field (Dead_Ticks), others => <>);
               Regs.DB2_FED_CFG :=
                 (DB2_FED => DB2_FED_CFG_DB2_FED_Field (Dead_Ticks), others => <>);
            else
               Regs.DB2_CFG := (others => <>);
            end if;
      end case;

      --  Route generator A (and, for a complementary pair, the dead-time B
      --  output = A signal + 1) to their pads as push-pull matrix outputs.
      Route_Out (Pin, Out_Signal (Unit, Ch));
      if Has_B then
         Route_Out (ESP32S3.GPIO.Pin_Id (Complement_Pin), Out_Signal (Unit, Ch) + 1);
      end if;
   end Configure_Channel;

   -----------
   -- Start --
   -----------

   procedure Start (C : Channel) is
      Regs : constant Periph_Ref := Regs_Of (C.U);
   begin
      if not C.Held then
         return;
      end if;
      case C.Idx is
         --  START = 2: start and run continuously

         when Ch0 =>
            Regs.TIMER0_CFG1.TIMER0_START := 2;

         when Ch1 =>
            Regs.TIMER1_CFG1.TIMER1_START := 2;

         when Ch2 =>
            Regs.TIMER2_CFG1.TIMER2_START := 2;
      end case;
   end Start;

   ----------
   -- Stop --
   ----------

   procedure Stop (C : Channel) is
   begin
      if C.Held then
         Do_Stop (C.U, C.Idx);
      end if;
   end Stop;

   --------------
   -- Set_Duty --
   --------------

   procedure Set_Duty (C : Channel; Percent : Duty_Percent) is
      Regs    : constant Periph_Ref := Regs_Of (C.U);
      Period  : constant Natural := Periods (C.U, C.Idx);
      --  The comparator field is 16-bit (max 65535), but a period can be the full
      --  Max_Peak = 65536 (Freq ~ 2441 Hz); at 100% duty Min(Period,Period) would be 65536
      --  and overflow the field -> Constraint_Error.  Cap at 65535 -- for every
      --  smaller period the comparator = Period is unchanged and still yields 100%.
      Compare : constant Natural :=
        Natural'Min (65535, Natural'Min (Period, Natural (Float (Period) * Percent / 100.0)));
   begin
      if not C.Held then
         return;
      end if;
      case C.Idx is
         --  single atomic write of the comparator

         when Ch0 =>
            Regs.CMPR0_VALUE0 := (CMPR0_A => CMPR0_VALUE0_CMPR0_A_Field (Compare), others => <>);

         when Ch1 =>
            Regs.CMPR1_VALUE0 := (CMPR1_A => CMPR1_VALUE0_CMPR1_A_Field (Compare), others => <>);

         when Ch2 =>
            Regs.CMPR2_VALUE0 := (CMPR2_A => CMPR2_VALUE0_CMPR2_A_Field (Compare), others => <>);
      end case;
   end Set_Duty;

   -----------------
   -- Set_Carrier --
   -----------------

   procedure Set_Carrier
     (C            : Channel;
      Enable       : Boolean := True;
      Prescale     : Carrier_Prescale := 0;
      Duty_Eighths : Carrier_Duty := 4;
      First_Pulse  : Carrier_Pulse := 1)
   is
      Regs : constant Periph_Ref := Regs_Of (C.U);
   begin
      if not C.Held then
         return;
      end if;
      case C.Idx is
         when Ch0 =>
            Regs.CHOPPER0_CFG :=
              (CHOPPER0_EN       => Enable,
               CHOPPER0_PRESCALE => CHOPPER0_CFG_CHOPPER0_PRESCALE_Field (Prescale),
               CHOPPER0_DUTY     => CHOPPER0_CFG_CHOPPER0_DUTY_Field (Duty_Eighths),
               CHOPPER0_OSHTWTH  => CHOPPER0_CFG_CHOPPER0_OSHTWTH_Field (First_Pulse),
               others            => <>);

         when Ch1 =>
            Regs.CHOPPER1_CFG :=
              (CHOPPER1_EN       => Enable,
               CHOPPER1_PRESCALE => CHOPPER1_CFG_CHOPPER1_PRESCALE_Field (Prescale),
               CHOPPER1_DUTY     => CHOPPER1_CFG_CHOPPER1_DUTY_Field (Duty_Eighths),
               CHOPPER1_OSHTWTH  => CHOPPER1_CFG_CHOPPER1_OSHTWTH_Field (First_Pulse),
               others            => <>);

         when Ch2 =>
            Regs.CHOPPER2_CFG :=
              (CHOPPER2_EN       => Enable,
               CHOPPER2_PRESCALE => CHOPPER2_CFG_CHOPPER2_PRESCALE_Field (Prescale),
               CHOPPER2_DUTY     => CHOPPER2_CFG_CHOPPER2_DUTY_Field (Duty_Eighths),
               CHOPPER2_OSHTWTH  => CHOPPER2_CFG_CHOPPER2_OSHTWTH_Field (First_Pulse),
               others            => <>);
      end case;
   end Set_Carrier;

   ---------------------
   -- Configure_Fault --
   ---------------------

   procedure Configure_Fault
     (Unit        : MCPWM_Unit;
      Input       : Fault_Input;
      Pin         : ESP32S3.GPIO.Pin_Id;
      Active_High : Boolean := True)
   is
      Regs : constant Periph_Ref := Regs_Of (Unit);
   begin
      --  Pull the pad to the INACTIVE level so a disconnected input never faults.
      Route_In (Fault_Signal (Unit, Input), Pin, (if Active_High then G.Pull_Down else G.Pull_Up));
      CTRL_Guard.Enable_Fault (Unit, Input, Active_High);   --  RMW of FAULT_DETECT
   end Configure_Fault;

   ---------------------
   -- Protect_Channel --
   ---------------------

   procedure Protect_Channel
     (C      : Channel;
      Input  : Fault_Input;
      Mode   : Fault_Mode := One_Shot;
      Action : Trip_Action := Force_Low)
   is
      Regs        : constant Periph_Ref := Regs_Of (C.U);
      Action_Code : constant Natural := Trip_Action'Pos (Action);   --  0/1/2 = none/low/high
      Is_One_Shot : constant Boolean := Mode = One_Shot;
   begin
      if not C.Held then
         return;
      end if;
      --  Force A and B (on the up-count, used by edge-aligned PWM) and enable the
      --  selected fault source for this trip zone, in the chosen mode.
      case C.Idx is
         when Ch0 =>
            declare
               Trip_Cfg : TZ0_CFG0_Register := Regs.TZ0_CFG0;
            begin
               if Is_One_Shot then
                  Trip_Cfg.TZ0_A_OST_U := TZ0_CFG0_TZ0_A_OST_U_Field (Action_Code);
                  Trip_Cfg.TZ0_B_OST_U := TZ0_CFG0_TZ0_B_OST_U_Field (Action_Code);
                  case Input is
                     when Fault0 =>
                        Trip_Cfg.TZ0_F0_OST := True;

                     when Fault1 =>
                        Trip_Cfg.TZ0_F1_OST := True;

                     when Fault2 =>
                        Trip_Cfg.TZ0_F2_OST := True;
                  end case;
               else
                  Trip_Cfg.TZ0_A_CBC_U := TZ0_CFG0_TZ0_A_CBC_U_Field (Action_Code);
                  Trip_Cfg.TZ0_B_CBC_U := TZ0_CFG0_TZ0_B_CBC_U_Field (Action_Code);
                  case Input is
                     when Fault0 =>
                        Trip_Cfg.TZ0_F0_CBC := True;

                     when Fault1 =>
                        Trip_Cfg.TZ0_F1_CBC := True;

                     when Fault2 =>
                        Trip_Cfg.TZ0_F2_CBC := True;
                  end case;
               end if;
               Regs.TZ0_CFG0 := Trip_Cfg;
            end;

         when Ch1 =>
            declare
               Trip_Cfg : TZ1_CFG0_Register := Regs.TZ1_CFG0;
            begin
               if Is_One_Shot then
                  Trip_Cfg.TZ1_A_OST_U := TZ1_CFG0_TZ1_A_OST_U_Field (Action_Code);
                  Trip_Cfg.TZ1_B_OST_U := TZ1_CFG0_TZ1_B_OST_U_Field (Action_Code);
                  case Input is
                     when Fault0 =>
                        Trip_Cfg.TZ1_F0_OST := True;

                     when Fault1 =>
                        Trip_Cfg.TZ1_F1_OST := True;

                     when Fault2 =>
                        Trip_Cfg.TZ1_F2_OST := True;
                  end case;
               else
                  Trip_Cfg.TZ1_A_CBC_U := TZ1_CFG0_TZ1_A_CBC_U_Field (Action_Code);
                  Trip_Cfg.TZ1_B_CBC_U := TZ1_CFG0_TZ1_B_CBC_U_Field (Action_Code);
                  case Input is
                     when Fault0 =>
                        Trip_Cfg.TZ1_F0_CBC := True;

                     when Fault1 =>
                        Trip_Cfg.TZ1_F1_CBC := True;

                     when Fault2 =>
                        Trip_Cfg.TZ1_F2_CBC := True;
                  end case;
               end if;
               Regs.TZ1_CFG0 := Trip_Cfg;
            end;

         when Ch2 =>
            declare
               Trip_Cfg : TZ2_CFG0_Register := Regs.TZ2_CFG0;
            begin
               if Is_One_Shot then
                  Trip_Cfg.TZ2_A_OST_U := TZ2_CFG0_TZ2_A_OST_U_Field (Action_Code);
                  Trip_Cfg.TZ2_B_OST_U := TZ2_CFG0_TZ2_B_OST_U_Field (Action_Code);
                  case Input is
                     when Fault0 =>
                        Trip_Cfg.TZ2_F0_OST := True;

                     when Fault1 =>
                        Trip_Cfg.TZ2_F1_OST := True;

                     when Fault2 =>
                        Trip_Cfg.TZ2_F2_OST := True;
                  end case;
               else
                  Trip_Cfg.TZ2_A_CBC_U := TZ2_CFG0_TZ2_A_CBC_U_Field (Action_Code);
                  Trip_Cfg.TZ2_B_CBC_U := TZ2_CFG0_TZ2_B_CBC_U_Field (Action_Code);
                  case Input is
                     when Fault0 =>
                        Trip_Cfg.TZ2_F0_CBC := True;

                     when Fault1 =>
                        Trip_Cfg.TZ2_F1_CBC := True;

                     when Fault2 =>
                        Trip_Cfg.TZ2_F2_CBC := True;
                  end case;
               end if;
               Regs.TZ2_CFG0 := Trip_Cfg;
            end;
      end case;
   end Protect_Channel;

   -----------------
   -- Clear_Fault --
   -----------------

   procedure Clear_Fault (C : Channel) is
      Regs : constant Periph_Ref := Regs_Of (C.U);
   begin
      if not C.Held then
         return;
      end if;
      case C.Idx is
         --  pulse CLR_OST to release a latched trip

         when Ch0 =>
            Regs.TZ0_CFG1.TZ0_CLR_OST := True;
            Regs.TZ0_CFG1.TZ0_CLR_OST := False;

         when Ch1 =>
            Regs.TZ1_CFG1.TZ1_CLR_OST := True;
            Regs.TZ1_CFG1.TZ1_CLR_OST := False;

         when Ch2 =>
            Regs.TZ2_CFG1.TZ2_CLR_OST := True;
            Regs.TZ2_CFG1.TZ2_CLR_OST := False;
      end case;
   end Clear_Fault;

   -------------
   -- Faulted --
   -------------

   function Faulted (C : Channel) return Boolean is
      Regs : constant Periph_Ref := Regs_Of (C.U);
   begin
      if not C.Held then
         return False;
      end if;
      case C.Idx is
         when Ch0 =>
            return Regs.TZ0_STATUS.TZ0_OST_ON or Regs.TZ0_STATUS.TZ0_CBC_ON;

         when Ch1 =>
            return Regs.TZ1_STATUS.TZ1_OST_ON or Regs.TZ1_STATUS.TZ1_CBC_ON;

         when Ch2 =>
            return Regs.TZ2_STATUS.TZ2_OST_ON or Regs.TZ2_STATUS.TZ2_CBC_ON;
      end case;
   end Faulted;

   ----------------------------------------------------------------------------
   --  Capture handle.
   ----------------------------------------------------------------------------

   procedure Claim (Cap : in out Capture; Unit : MCPWM_Unit; Index : Cap_Index) is
      Ok : Boolean;
   begin
      Release (Cap);
      Pool.Claim_Capture (Unit, Index, Ok);
      if Ok then
         Cap.U := Unit;
         Cap.Idx := Index;
         Cap.Held := True;
      end if;
   end Claim;

   function Is_Valid (Cap : Capture) return Boolean
   is (Cap.Held);

   procedure Release (Cap : in out Capture) is
      Regs : constant Periph_Ref := Regs_Of (Cap.U);
   begin
      if Cap.Held then
         case Cap.Idx is
            --  disable the capture channel on release

            when Cap0 =>
               Regs.CAP_CH0_CFG.CAP0_EN := False;

            when Cap1 =>
               Regs.CAP_CH1_CFG.CAP1_EN := False;

            when Cap2 =>
               Regs.CAP_CH2_CFG.CAP2_EN := False;
         end case;
         Pool.Release_Capture (Cap.U, Cap.Idx);
         Cap.Held := False;
      end if;
   end Release;

   overriding
   procedure Finalize (Cap : in out Capture) is
   begin
      Release (Cap);
   end Finalize;

   -----------------------
   -- Configure_Capture --
   -----------------------

   procedure Configure_Capture
     (Cap : Capture; Pin : ESP32S3.GPIO.Pin_Id; Edge : Cap_Edge := Both_Edges)
   is
      Unit : constant MCPWM_Unit := Cap.U;
      Chan : constant Cap_Index := Cap.Idx;
      Regs : constant Periph_Ref := Regs_Of (Unit);
      --  CAPn_MODE: bit0 = negedge, bit1 = posedge.
      Mode : constant CAP_CH0_CFG_CAP0_MODE_Field :=
        (case Edge is
           when Rising     => 2,
           when Falling    => 1,
           when Both_Edges => 3);
   begin
      if not Cap.Held then
         return;
      end if;
      Regs.CAP_TIMER_CFG.CAP_TIMER_EN := True;          --  run the capture timer (APB)
      Route_In (Cap_Signal (Unit, Chan), Pin, G.Pull_Up);
      case Chan is
         when Cap0 =>
            Regs.CAP_CH0_CFG := (CAP0_EN => True, CAP0_MODE => Mode, others => <>);
            Regs.INT_CLR.CAP0_INT_CLR := True;

         when Cap1 =>
            Regs.CAP_CH1_CFG := (CAP1_EN => True, CAP1_MODE => Mode, others => <>);
            Regs.INT_CLR.CAP1_INT_CLR := True;

         when Cap2 =>
            Regs.CAP_CH2_CFG := (CAP2_EN => True, CAP2_MODE => Mode, others => <>);
            Regs.INT_CLR.CAP2_INT_CLR := True;
      end case;
   end Configure_Capture;

   ---------------------
   -- Capture_Pending --
   ---------------------

   function Capture_Pending (Cap : Capture) return Boolean is
      Regs : constant Periph_Ref := Regs_Of (Cap.U);
   begin
      if not Cap.Held then
         return False;
      end if;
      case Cap.Idx is
         when Cap0 =>
            return Regs.INT_RAW.CAP0_INT_RAW;

         when Cap1 =>
            return Regs.INT_RAW.CAP1_INT_RAW;

         when Cap2 =>
            return Regs.INT_RAW.CAP2_INT_RAW;
      end case;
   end Capture_Pending;

   ------------------
   -- Read_Capture --
   ------------------

   procedure Read_Capture
     (Cap : Capture; Value : out Interfaces.Unsigned_32; Falling : out Boolean)
   is
      Regs : constant Periph_Ref := Regs_Of (Cap.U);
   begin
      Value := 0;
      Falling := False;
      if not Cap.Held then
         return;
      end if;
      case Cap.Idx is
         when Cap0 =>
            Value := Unsigned_32 (Regs.CAP_CH0);
            Falling := Regs.CAP_STATUS.CAP0_EDGE;   --  True = negedge
            Regs.INT_CLR.CAP0_INT_CLR := True;

         when Cap1 =>
            Value := Unsigned_32 (Regs.CAP_CH1);
            Falling := Regs.CAP_STATUS.CAP1_EDGE;
            Regs.INT_CLR.CAP1_INT_CLR := True;

         when Cap2 =>
            Value := Unsigned_32 (Regs.CAP_CH2);
            Falling := Regs.CAP_STATUS.CAP2_EDGE;
            Regs.INT_CLR.CAP2_INT_CLR := True;
      end case;
   end Read_Capture;

end ESP32S3.MCPWM;
