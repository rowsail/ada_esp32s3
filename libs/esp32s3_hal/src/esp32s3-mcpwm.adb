with Interfaces;            use Interfaces;
with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3_Registers;     use ESP32S3_Registers;
with ESP32S3_Registers.PWM; use ESP32S3_Registers.PWM;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.IO_MUX;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.MCPWM is

   package GR renames
     ESP32S3_Registers.GPIO;     --  GPIO matrix register layer
   package MX renames ESP32S3_Registers.IO_MUX;   --  IO_MUX (per-pad config)
   package G renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   --  PWM_clk source with CLK_CFG.CLK_PRESCALE = 0 (period 6.25 ns = 160 MHz).
   Src_Hz   : constant := 160_000_000;
   Max_Peak : constant :=
     65_536;                 --  timer period field is 16-bit

   type Periph_Ref is access all PWM_Peripheral;

   function Regs_Of (Unit : MCPWM_Unit) return Periph_Ref
   is (case Unit is
         when MCPWM0 => MCPWM0_Periph'Access,
         when MCPWM1 => MCPWM1_Periph'Access);

   --  Generator outputs OUTnA = base + 2n (OUTnB = +1); fault/capture inputs
   --  stride by 1.  Bases come from ESP32S3.GPIO_Signals (gpio_sig_map).
   function Out_Signal (Unit : MCPWM_Unit; Ch : Channel_Index) return Natural
   is ((if Unit = MCPWM0 then Sigs.PWM0_OUT0A else Sigs.PWM1_OUT0A)
       + 2 * Channel_Index'Pos (Ch));

   --  Route a generator output signal to Pin as a push-pull matrix output.
   procedure Route_Out (Pin : G.Pin_Id; Sig : Natural) is
      O : GR.FUNC_OUT_SEL_CFG_Register :=
        GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin));
   begin
      G.Configure (Pin, Mode => G.Output, Drive => G.Drive_Strong);
      O.OUT_SEL := GR.FUNC_OUT_SEL_CFG_OUT_SEL_Field (Sig);
      O.OEN_SEL := False;
      GR.GPIO_Periph.FUNC_OUT_SEL_CFG (Natural (Pin)) := O;
   end Route_Out;

   --  Route Pin into the matrix input signal Sig (input buffer on + pull), WITHOUT
   --  disabling the pad's output driver -- so a fault/capture input can read a pin
   --  that is also being driven (e.g. capturing a PWM output looped on one pad).
   procedure Route_In (Sig : Natural; Pin : G.Pin_Id; Pull : G.Pull_Mode) is
      use type G.Pull_Mode;
      Ix : constant Natural := Natural (Pin);
      P  : MX.GPIO_Register := MX.IO_MUX_Periph.GPIO (Ix);
   begin
      P.MCU_SEL := 1;
      P.FUN_IE := True;
      P.FUN_WPU := Pull = G.Pull_Up;
      P.FUN_WPD := Pull = G.Pull_Down;
      MX.IO_MUX_Periph.GPIO (Ix) := P;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (Sig) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Ix),
         SEL    => True,
         others => <>);
   end Route_In;

   --  Fault / capture matrix input-signal indices (gpio_sig_map).
   function Fault_Signal
     (Unit : MCPWM_Unit; Input : Fault_Input) return Natural
   is ((if Unit = MCPWM0 then Sigs.PWM0_F0_IN else Sigs.PWM1_F0_IN)
       + Fault_Input'Pos (Input));
   function Cap_Signal (Unit : MCPWM_Unit; Chan : Cap_Index) return Natural
   is ((if Unit = MCPWM0 then Sigs.PWM0_CAP0_IN else Sigs.PWM1_CAP0_IN)
       + Cap_Index'Pos (Chan));

   --  Per-channel period in timer ticks (= TIMER_PERIOD + 1), set by
   --  Configure_Channel and read by Set_Duty.  Plain reads/writes of a Natural
   --  are atomic on this target, and the owner is exclusive, so no lock is needed.
   Periods : array (MCPWM_Unit, Channel_Index) of Natural :=
     (others => (others => 1));

   --  Bring a unit's clock up (PWM clock = 160 MHz): clock-gate, pulse reset,
   --  and force the reg-file clock on.  Run lazily, once per unit, from inside
   --  the Pool on the first Claim of any of the unit's channels -- so claiming a
   --  second channel never resets a sibling that is already running.
   procedure Bring_Up_Unit (Unit : MCPWM_Unit) is
      use ESP32S3_Registers.SYSTEM;
      R : constant Periph_Ref := Regs_Of (Unit);
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

      R.CLK :=
        (EN => True, others => <>);          --  force the reg-file clock on
      R.CLK_CFG := (CLK_PRESCALE => 0, others => <>);   --  PWM_clk = 160 MHz
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
      procedure Claim_Channel
        (Unit : MCPWM_Unit; Index : Channel_Index; Ok : out Boolean);
      procedure Release_Channel (Unit : MCPWM_Unit; Index : Channel_Index);
      procedure Claim_Capture
        (Unit : MCPWM_Unit; Index : Cap_Index; Ok : out Boolean);
      procedure Release_Capture (Unit : MCPWM_Unit; Index : Cap_Index);
   private
      Ch_Use  : Ch_Use_Map := (others => (others => False));
      Cap_Use : Cap_Use_Map := (others => (others => False));
      Unit_Up : Unit_Map := (others => False);
   end Pool;

   protected body Pool is

      procedure Claim_Channel
        (Unit : MCPWM_Unit; Index : Channel_Index; Ok : out Boolean) is
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

      procedure Claim_Capture
        (Unit : MCPWM_Unit; Index : Cap_Index; Ok : out Boolean) is
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
      R : constant Periph_Ref := Regs_Of (Unit);
   begin
      case Ch is
         --  START = 0: stop at the next timer zero

         when Ch0 =>
            R.TIMER0_CFG1.TIMER0_START := 0;

         when Ch1 =>
            R.TIMER1_CFG1.TIMER1_START := 0;

         when Ch2 =>
            R.TIMER2_CFG1.TIMER2_START := 0;
      end case;
   end Do_Stop;

   -----------
   -- Claim --
   -----------

   procedure Claim
     (C : in out Channel; Unit : MCPWM_Unit; Index : Channel_Index)
   is
      Ok : Boolean;
   begin
      Release (C);                     --  free any channel C already held
      Pool.Claim_Channel
        (Unit, Index, Ok);   --  brings the unit up on first claim
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
         Do_Stop
           (C.U, C.Idx);         --  don't leave a freed channel driving a pad
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
      Unit  : constant MCPWM_Unit := C.U;
      Ch    : constant Channel_Index := C.Idx;
      R     : constant Periph_Ref := Regs_Of (Unit);
      Total : constant Natural :=
        Natural'Max (1, Src_Hz / Freq);  --  ticks / period
      --  Choose the smallest timer prescale so the period fits the 16-bit field.
      P1    : constant Natural :=
        Natural'Max (1, Natural'Min (256, (Total + Max_Peak - 1) / Max_Peak));
      Ticks : constant Natural :=
        Natural'Max
          (2, Natural'Min (Max_Peak, Total / P1));     --  = TIMER_PERIOD + 1
      Pre   : constant Natural := P1 - 1;
      Per   : constant Natural := Ticks - 1;
      --  Dead-time in PWM-clock (160 MHz) ticks = ns * 0.16, clamped to 16 bits.
      Has_B : constant Boolean := Complement_Pin /= ESP32S3.GPIO.No_Pin;
      DT    : constant Natural :=
        Natural'Min (65535, (Dead_Time_Ns * (Src_Hz / 1_000_000)) / 1000);
   begin
      if not C.Held then
         return;
      end if;
      Periods (Unit, Ch) := Ticks;

      --  Operator Ch is timed by timer Ch.
      case Ch is
         when Ch0 =>
            R.OPERATOR_TIMERSEL.OPERATOR0_TIMERSEL := 0;

         when Ch1 =>
            R.OPERATOR_TIMERSEL.OPERATOR1_TIMERSEL := 1;

         when Ch2 =>
            R.OPERATOR_TIMERSEL.OPERATOR2_TIMERSEL := 2;
      end case;

      --  Timer: up-count, given prescale + period, left stopped (START = 0).
      --  Comparator A: 0 % to start, reloaded at TEZ (glitch-free).
      --  Generator A: high at timer zero (UTEZ=2), low at compare-A up (UTEA=1).
      case Ch is
         when Ch0 =>
            R.TIMER0_CFG0 :=
              (TIMER0_PRESCALE => TIMER0_CFG0_TIMER0_PRESCALE_Field (Pre),
               TIMER0_PERIOD   => TIMER0_CFG0_TIMER0_PERIOD_Field (Per),
               others          => <>);
            R.TIMER0_CFG1 :=
              (TIMER0_MOD => 1, TIMER0_START => 0, others => <>);
            R.CMPR0_CFG := (CMPR0_A_UPMETHOD => 1, others => <>);  --  TEZ
            R.CMPR0_VALUE0 := (CMPR0_A => 0, others => <>);
            R.GEN0_CFG0 := (others => <>);
            R.GEN0_A := (UTEZ => 2, UTEA => 1, others => <>);
            if Has_B then
               R.DB0_CFG :=
                 (DB0_A_OUTBYPASS   => False,
                  DB0_B_OUTBYPASS   => False,
                  DB0_FED_OUTINVERT => True,
                  others            => <>);
               R.DB0_RED_CFG :=
                 (DB0_RED => DB0_RED_CFG_DB0_RED_Field (DT), others => <>);
               R.DB0_FED_CFG :=
                 (DB0_FED => DB0_FED_CFG_DB0_FED_Field (DT), others => <>);
            else
               R.DB0_CFG :=
                 (others => <>);     --  bypass (A/B_OUTBYPASS default True)
            end if;

         when Ch1 =>
            R.TIMER1_CFG0 :=
              (TIMER1_PRESCALE => TIMER1_CFG0_TIMER1_PRESCALE_Field (Pre),
               TIMER1_PERIOD   => TIMER1_CFG0_TIMER1_PERIOD_Field (Per),
               others          => <>);
            R.TIMER1_CFG1 :=
              (TIMER1_MOD => 1, TIMER1_START => 0, others => <>);
            R.CMPR1_CFG := (CMPR1_A_UPMETHOD => 1, others => <>);
            R.CMPR1_VALUE0 := (CMPR1_A => 0, others => <>);
            R.GEN1_CFG0 := (others => <>);
            R.GEN1_A := (UTEZ => 2, UTEA => 1, others => <>);
            if Has_B then
               R.DB1_CFG :=
                 (DB1_A_OUTBYPASS   => False,
                  DB1_B_OUTBYPASS   => False,
                  DB1_FED_OUTINVERT => True,
                  others            => <>);
               R.DB1_RED_CFG :=
                 (DB1_RED => DB1_RED_CFG_DB1_RED_Field (DT), others => <>);
               R.DB1_FED_CFG :=
                 (DB1_FED => DB1_FED_CFG_DB1_FED_Field (DT), others => <>);
            else
               R.DB1_CFG := (others => <>);
            end if;

         when Ch2 =>
            R.TIMER2_CFG0 :=
              (TIMER2_PRESCALE => TIMER2_CFG0_TIMER2_PRESCALE_Field (Pre),
               TIMER2_PERIOD   => TIMER2_CFG0_TIMER2_PERIOD_Field (Per),
               others          => <>);
            R.TIMER2_CFG1 :=
              (TIMER2_MOD => 1, TIMER2_START => 0, others => <>);
            R.CMPR2_CFG := (CMPR2_A_UPMETHOD => 1, others => <>);
            R.CMPR2_VALUE0 := (CMPR2_A => 0, others => <>);
            R.GEN2_CFG0 := (others => <>);
            R.GEN2_A := (UTEZ => 2, UTEA => 1, others => <>);
            if Has_B then
               R.DB2_CFG :=
                 (DB2_A_OUTBYPASS   => False,
                  DB2_B_OUTBYPASS   => False,
                  DB2_FED_OUTINVERT => True,
                  others            => <>);
               R.DB2_RED_CFG :=
                 (DB2_RED => DB2_RED_CFG_DB2_RED_Field (DT), others => <>);
               R.DB2_FED_CFG :=
                 (DB2_FED => DB2_FED_CFG_DB2_FED_Field (DT), others => <>);
            else
               R.DB2_CFG := (others => <>);
            end if;
      end case;

      --  Route generator A (and, for a complementary pair, the dead-time B
      --  output = A signal + 1) to their pads as push-pull matrix outputs.
      Route_Out (Pin, Out_Signal (Unit, Ch));
      if Has_B then
         Route_Out
           (ESP32S3.GPIO.Pin_Id (Complement_Pin), Out_Signal (Unit, Ch) + 1);
      end if;
   end Configure_Channel;

   -----------
   -- Start --
   -----------

   procedure Start (C : Channel) is
      R : constant Periph_Ref := Regs_Of (C.U);
   begin
      if not C.Held then
         return;
      end if;
      case C.Idx is
         --  START = 2: start and run continuously

         when Ch0 =>
            R.TIMER0_CFG1.TIMER0_START := 2;

         when Ch1 =>
            R.TIMER1_CFG1.TIMER1_START := 2;

         when Ch2 =>
            R.TIMER2_CFG1.TIMER2_START := 2;
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
      R   : constant Periph_Ref := Regs_Of (C.U);
      P   : constant Natural := Periods (C.U, C.Idx);
      --  The comparator field is 16-bit (max 65535), but a period can be the full
      --  Max_Peak = 65536 (Freq ~ 2441 Hz); at 100% duty Min(P,P) would be 65536
      --  and overflow the field -> Constraint_Error.  Cap at 65535 -- for every
      --  smaller period the comparator = P is unchanged and still yields 100%.
      Cmp : constant Natural :=
        Natural'Min
          (65535, Natural'Min (P, Natural (Float (P) * Percent / 100.0)));
   begin
      if not C.Held then
         return;
      end if;
      case C.Idx is
         --  single atomic write of the comparator

         when Ch0 =>
            R.CMPR0_VALUE0 :=
              (CMPR0_A => CMPR0_VALUE0_CMPR0_A_Field (Cmp), others => <>);

         when Ch1 =>
            R.CMPR1_VALUE0 :=
              (CMPR1_A => CMPR1_VALUE0_CMPR1_A_Field (Cmp), others => <>);

         when Ch2 =>
            R.CMPR2_VALUE0 :=
              (CMPR2_A => CMPR2_VALUE0_CMPR2_A_Field (Cmp), others => <>);
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
      R : constant Periph_Ref := Regs_Of (C.U);
   begin
      if not C.Held then
         return;
      end if;
      case C.Idx is
         when Ch0 =>
            R.CHOPPER0_CFG :=
              (CHOPPER0_EN       => Enable,
               CHOPPER0_PRESCALE =>
                 CHOPPER0_CFG_CHOPPER0_PRESCALE_Field (Prescale),
               CHOPPER0_DUTY     =>
                 CHOPPER0_CFG_CHOPPER0_DUTY_Field (Duty_Eighths),
               CHOPPER0_OSHTWTH  =>
                 CHOPPER0_CFG_CHOPPER0_OSHTWTH_Field (First_Pulse),
               others            => <>);

         when Ch1 =>
            R.CHOPPER1_CFG :=
              (CHOPPER1_EN       => Enable,
               CHOPPER1_PRESCALE =>
                 CHOPPER1_CFG_CHOPPER1_PRESCALE_Field (Prescale),
               CHOPPER1_DUTY     =>
                 CHOPPER1_CFG_CHOPPER1_DUTY_Field (Duty_Eighths),
               CHOPPER1_OSHTWTH  =>
                 CHOPPER1_CFG_CHOPPER1_OSHTWTH_Field (First_Pulse),
               others            => <>);

         when Ch2 =>
            R.CHOPPER2_CFG :=
              (CHOPPER2_EN       => Enable,
               CHOPPER2_PRESCALE =>
                 CHOPPER2_CFG_CHOPPER2_PRESCALE_Field (Prescale),
               CHOPPER2_DUTY     =>
                 CHOPPER2_CFG_CHOPPER2_DUTY_Field (Duty_Eighths),
               CHOPPER2_OSHTWTH  =>
                 CHOPPER2_CFG_CHOPPER2_OSHTWTH_Field (First_Pulse),
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
      R : constant Periph_Ref := Regs_Of (Unit);
   begin
      --  Pull the pad to the INACTIVE level so a disconnected input never faults.
      Route_In
        (Fault_Signal (Unit, Input),
         Pin,
         (if Active_High then G.Pull_Down else G.Pull_Up));
      case Input is
         when Fault0 =>
            R.FAULT_DETECT.F0_EN := True;
            R.FAULT_DETECT.F0_POLE := Active_High;

         when Fault1 =>
            R.FAULT_DETECT.F1_EN := True;
            R.FAULT_DETECT.F1_POLE := Active_High;

         when Fault2 =>
            R.FAULT_DETECT.F2_EN := True;
            R.FAULT_DETECT.F2_POLE := Active_High;
      end case;
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
      R   : constant Periph_Ref := Regs_Of (C.U);
      Act : constant Natural :=
        Trip_Action'Pos (Action);   --  0/1/2 = none/low/high
      OST : constant Boolean := Mode = One_Shot;
   begin
      if not C.Held then
         return;
      end if;
      --  Force A and B (on the up-count, used by edge-aligned PWM) and enable the
      --  selected fault source for this trip zone, in the chosen mode.
      case C.Idx is
         when Ch0 =>
            declare
               C2 : TZ0_CFG0_Register := R.TZ0_CFG0;
            begin
               if OST then
                  C2.TZ0_A_OST_U := TZ0_CFG0_TZ0_A_OST_U_Field (Act);
                  C2.TZ0_B_OST_U := TZ0_CFG0_TZ0_B_OST_U_Field (Act);
                  case Input is
                     when Fault0 =>
                        C2.TZ0_F0_OST := True;

                     when Fault1 =>
                        C2.TZ0_F1_OST := True;

                     when Fault2 =>
                        C2.TZ0_F2_OST := True;
                  end case;
               else
                  C2.TZ0_A_CBC_U := TZ0_CFG0_TZ0_A_CBC_U_Field (Act);
                  C2.TZ0_B_CBC_U := TZ0_CFG0_TZ0_B_CBC_U_Field (Act);
                  case Input is
                     when Fault0 =>
                        C2.TZ0_F0_CBC := True;

                     when Fault1 =>
                        C2.TZ0_F1_CBC := True;

                     when Fault2 =>
                        C2.TZ0_F2_CBC := True;
                  end case;
               end if;
               R.TZ0_CFG0 := C2;
            end;

         when Ch1 =>
            declare
               C2 : TZ1_CFG0_Register := R.TZ1_CFG0;
            begin
               if OST then
                  C2.TZ1_A_OST_U := TZ1_CFG0_TZ1_A_OST_U_Field (Act);
                  C2.TZ1_B_OST_U := TZ1_CFG0_TZ1_B_OST_U_Field (Act);
                  case Input is
                     when Fault0 =>
                        C2.TZ1_F0_OST := True;

                     when Fault1 =>
                        C2.TZ1_F1_OST := True;

                     when Fault2 =>
                        C2.TZ1_F2_OST := True;
                  end case;
               else
                  C2.TZ1_A_CBC_U := TZ1_CFG0_TZ1_A_CBC_U_Field (Act);
                  C2.TZ1_B_CBC_U := TZ1_CFG0_TZ1_B_CBC_U_Field (Act);
                  case Input is
                     when Fault0 =>
                        C2.TZ1_F0_CBC := True;

                     when Fault1 =>
                        C2.TZ1_F1_CBC := True;

                     when Fault2 =>
                        C2.TZ1_F2_CBC := True;
                  end case;
               end if;
               R.TZ1_CFG0 := C2;
            end;

         when Ch2 =>
            declare
               C2 : TZ2_CFG0_Register := R.TZ2_CFG0;
            begin
               if OST then
                  C2.TZ2_A_OST_U := TZ2_CFG0_TZ2_A_OST_U_Field (Act);
                  C2.TZ2_B_OST_U := TZ2_CFG0_TZ2_B_OST_U_Field (Act);
                  case Input is
                     when Fault0 =>
                        C2.TZ2_F0_OST := True;

                     when Fault1 =>
                        C2.TZ2_F1_OST := True;

                     when Fault2 =>
                        C2.TZ2_F2_OST := True;
                  end case;
               else
                  C2.TZ2_A_CBC_U := TZ2_CFG0_TZ2_A_CBC_U_Field (Act);
                  C2.TZ2_B_CBC_U := TZ2_CFG0_TZ2_B_CBC_U_Field (Act);
                  case Input is
                     when Fault0 =>
                        C2.TZ2_F0_CBC := True;

                     when Fault1 =>
                        C2.TZ2_F1_CBC := True;

                     when Fault2 =>
                        C2.TZ2_F2_CBC := True;
                  end case;
               end if;
               R.TZ2_CFG0 := C2;
            end;
      end case;
   end Protect_Channel;

   -----------------
   -- Clear_Fault --
   -----------------

   procedure Clear_Fault (C : Channel) is
      R : constant Periph_Ref := Regs_Of (C.U);
   begin
      if not C.Held then
         return;
      end if;
      case C.Idx is
         --  pulse CLR_OST to release a latched trip

         when Ch0 =>
            R.TZ0_CFG1.TZ0_CLR_OST := True;
            R.TZ0_CFG1.TZ0_CLR_OST := False;

         when Ch1 =>
            R.TZ1_CFG1.TZ1_CLR_OST := True;
            R.TZ1_CFG1.TZ1_CLR_OST := False;

         when Ch2 =>
            R.TZ2_CFG1.TZ2_CLR_OST := True;
            R.TZ2_CFG1.TZ2_CLR_OST := False;
      end case;
   end Clear_Fault;

   -------------
   -- Faulted --
   -------------

   function Faulted (C : Channel) return Boolean is
      R : constant Periph_Ref := Regs_Of (C.U);
   begin
      if not C.Held then
         return False;
      end if;
      case C.Idx is
         when Ch0 =>
            return R.TZ0_STATUS.TZ0_OST_ON or R.TZ0_STATUS.TZ0_CBC_ON;

         when Ch1 =>
            return R.TZ1_STATUS.TZ1_OST_ON or R.TZ1_STATUS.TZ1_CBC_ON;

         when Ch2 =>
            return R.TZ2_STATUS.TZ2_OST_ON or R.TZ2_STATUS.TZ2_CBC_ON;
      end case;
   end Faulted;

   ----------------------------------------------------------------------------
   --  Capture handle.
   ----------------------------------------------------------------------------

   procedure Claim (Cap : in out Capture; Unit : MCPWM_Unit; Index : Cap_Index)
   is
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
      R : constant Periph_Ref := Regs_Of (Cap.U);
   begin
      if Cap.Held then
         case Cap.Idx is
            --  disable the capture channel on release

            when Cap0 =>
               R.CAP_CH0_CFG.CAP0_EN := False;

            when Cap1 =>
               R.CAP_CH1_CFG.CAP1_EN := False;

            when Cap2 =>
               R.CAP_CH2_CFG.CAP2_EN := False;
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
      R    : constant Periph_Ref := Regs_Of (Unit);
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
      R.CAP_TIMER_CFG.CAP_TIMER_EN :=
        True;          --  run the capture timer (APB)
      Route_In (Cap_Signal (Unit, Chan), Pin, G.Pull_Up);
      case Chan is
         when Cap0 =>
            R.CAP_CH0_CFG :=
              (CAP0_EN => True, CAP0_MODE => Mode, others => <>);
            R.INT_CLR.CAP0_INT_CLR := True;

         when Cap1 =>
            R.CAP_CH1_CFG :=
              (CAP1_EN => True, CAP1_MODE => Mode, others => <>);
            R.INT_CLR.CAP1_INT_CLR := True;

         when Cap2 =>
            R.CAP_CH2_CFG :=
              (CAP2_EN => True, CAP2_MODE => Mode, others => <>);
            R.INT_CLR.CAP2_INT_CLR := True;
      end case;
   end Configure_Capture;

   ---------------------
   -- Capture_Pending --
   ---------------------

   function Capture_Pending (Cap : Capture) return Boolean is
      R : constant Periph_Ref := Regs_Of (Cap.U);
   begin
      if not Cap.Held then
         return False;
      end if;
      case Cap.Idx is
         when Cap0 =>
            return R.INT_RAW.CAP0_INT_RAW;

         when Cap1 =>
            return R.INT_RAW.CAP1_INT_RAW;

         when Cap2 =>
            return R.INT_RAW.CAP2_INT_RAW;
      end case;
   end Capture_Pending;

   ------------------
   -- Read_Capture --
   ------------------

   procedure Read_Capture
     (Cap : Capture; Value : out Interfaces.Unsigned_32; Falling : out Boolean)
   is
      R : constant Periph_Ref := Regs_Of (Cap.U);
   begin
      Value := 0;
      Falling := False;
      if not Cap.Held then
         return;
      end if;
      case Cap.Idx is
         when Cap0 =>
            Value := Unsigned_32 (R.CAP_CH0);
            Falling := R.CAP_STATUS.CAP0_EDGE;   --  True = negedge
            R.INT_CLR.CAP0_INT_CLR := True;

         when Cap1 =>
            Value := Unsigned_32 (R.CAP_CH1);
            Falling := R.CAP_STATUS.CAP1_EDGE;
            R.INT_CLR.CAP1_INT_CLR := True;

         when Cap2 =>
            Value := Unsigned_32 (R.CAP_CH2);
            Falling := R.CAP_STATUS.CAP2_EDGE;
            R.INT_CLR.CAP2_INT_CLR := True;
      end case;
   end Read_Capture;

end ESP32S3.MCPWM;
