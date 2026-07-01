with Interfaces;
with Ada.Unchecked_Conversion;
with ESP32S3.GPIO;
with ESP32S3.GPIO_Signals;
with ESP32S3_Registers;          use ESP32S3_Registers;
with ESP32S3_Registers.PCNT;     use ESP32S3_Registers.PCNT;
with ESP32S3_Registers.GPIO;
with ESP32S3_Registers.IO_MUX;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.PCNT is

   package GR renames ESP32S3_Registers.GPIO;
   package MX renames ESP32S3_Registers.IO_MUX;
   package G    renames ESP32S3.GPIO;
   package Sigs renames ESP32S3.GPIO_Signals;

   --  Per-unit config block (CONF0/CONF1/CONF2), re-imposed as an array (the
   --  svd flattened it; stride 0x0C from U_CONF00).
   type U_Regs is record
      CONF0 : U_CONF_Register;
      CONF1 : U_CONF_Register_1;
      CONF2 : U_CONF_Register_2;
   end record with Volatile;
   for U_Regs use record
      CONF0 at 0 range 0 .. 31;
      CONF1 at 4 range 0 .. 31;
      CONF2 at 8 range 0 .. 31;
   end record;
   for U_Regs'Size use 12 * 8;
   for U_Regs'Object_Size use 12 * 8;
   type U_Array is array (Unit_Index) of U_Regs;
   Conf : U_Array
     with Import, Volatile, Address => PCNT_Periph.U_CONF00'Address;

   --  Input signal index for a unit's channel-0 SIG input (33, 37, 41, 45): each
   --  unit owns 4 matrix signals (sig/ctrl x ch0/ch1), so they stride by 4.
   PCNT_Sigs_Per_Unit : constant := 4;
   function Sig_In (Idx : Unit_Index) return Natural is
     (Sigs.PCNT_SIG_CH0_IN0 + PCNT_Sigs_Per_Unit * Natural (Idx));

   procedure Route_In (Sig : Natural; Pin : G.Pin_Id) is
      Ix : constant Natural := Natural (Pin);
      P  : MX.GPIO_Register := MX.IO_MUX_Periph.GPIO (Ix);
   begin
      P.MCU_SEL := 1;
      P.FUN_IE  := True;          --  input buffer on so PCNT reads the pad
      MX.IO_MUX_Periph.GPIO (Ix) := P;
      GR.GPIO_Periph.FUNC_IN_SEL_CFG (Sig) :=
        (IN_SEL => GR.FUNC_IN_SEL_CFG_IN_SEL_Field (Ix), SEL => True, others => <>);
   end Route_In;

   procedure Reset_Unit (Idx : Unit_Index) is
   begin
      case Idx is                  --  pulse the unit's CNT_RST
         when 0 => PCNT_Periph.CTRL.CNT_RST_U0 := True;
                   PCNT_Periph.CTRL.CNT_RST_U0 := False;
         when 1 => PCNT_Periph.CTRL.CNT_RST_U1 := True;
                   PCNT_Periph.CTRL.CNT_RST_U1 := False;
         when 2 => PCNT_Periph.CTRL.CNT_RST_U2 := True;
                   PCNT_Periph.CTRL.CNT_RST_U2 := False;
         when 3 => PCNT_Periph.CTRL.CNT_RST_U3 := True;
                   PCNT_Periph.CTRL.CNT_RST_U3 := False;
      end case;
   end Reset_Unit;

   procedure Set_Pause (Idx : Unit_Index; On : Boolean) is
   begin
      case Idx is
         when 0 => PCNT_Periph.CTRL.CNT_PAUSE_U0 := On;
         when 1 => PCNT_Periph.CTRL.CNT_PAUSE_U1 := On;
         when 2 => PCNT_Periph.CTRL.CNT_PAUSE_U2 := On;
         when 3 => PCNT_Periph.CTRL.CNT_PAUSE_U3 := On;
      end case;
   end Set_Pause;

   --------------------------------------------------------------------------
   --  Unit-ownership pool (brings the module up once).
   --------------------------------------------------------------------------

   type Use_Map is array (Unit_Index) of Boolean;

   protected Pool is
      procedure Claim (Index : Unit_Index; Ok : out Boolean);
      procedure Release (Index : Unit_Index);
   private
      In_Use : Use_Map := (others => False);
      Inited : Boolean := False;
   end Pool;

   protected body Pool is
      procedure Claim (Index : Unit_Index; Ok : out Boolean) is
         use ESP32S3_Registers.SYSTEM;
      begin
         if not Inited then
            SYSTEM_Periph.PERIP_CLK_EN0.PCNT_CLK_EN := True;
            SYSTEM_Periph.PERIP_RST_EN0.PCNT_RST    := True;
            SYSTEM_Periph.PERIP_RST_EN0.PCNT_RST    := False;
            PCNT_Periph.CTRL.CLK_EN := True;         --  register-clock gate
            Inited := True;
         end if;
         Ok := not In_Use (Index);
         if Ok then
            In_Use (Index) := True;
         end if;
      end Claim;

      procedure Release (Index : Unit_Index) is
      begin
         In_Use (Index) := False;
      end Release;
   end Pool;

   -----------
   -- Claim --
   -----------

   procedure Claim (U : in out Unit; Index : Unit_Index) is
      Ok : Boolean;
   begin
      Release (U);
      Pool.Claim (Index, Ok);
      if Ok then
         U.Idx := Index;  U.Held := True;
      end if;
   end Claim;

   function Is_Valid (U : Unit) return Boolean is (U.Held);

   procedure Release (U : in out Unit) is
   begin
      if U.Held then
         Set_Pause (U.Idx, True);
         Pool.Release (U.Idx);
         U.Held := False;
      end if;
   end Release;

   overriding procedure Finalize (U : in out Unit) is
   begin
      Release (U);
   end Finalize;

   ---------------
   -- Configure --
   ---------------

   procedure Configure (U : in out Unit;
                        Pin : ESP32S3.GPIO.Pin_Id;
                        Both_Edges : Boolean := False) is
   begin
      if not U.Held then
         return;
      end if;
      --  Channel 0: +1 on rising edge (and on falling too if Both_Edges); the
      --  control input is ignored (HCTRL/LCTRL = 0).  Threshold-event resets are
      --  disabled so the counter free-runs.  Glitch filter on, short threshold.
      Conf (U.Idx).CONF0 :=
        (CH0_POS_MODE => 1,                              --  increment on rising
         CH0_NEG_MODE => (if Both_Edges then 1 else 0),  --  increment on falling?
         CH0_HCTRL_MODE => 0, CH0_LCTRL_MODE => 0,
         THR_ZERO_EN => False, THR_H_LIM_EN => False, THR_L_LIM_EN => False,
         THR_THRES0_EN => False, THR_THRES1_EN => False,
         FILTER_EN => True, FILTER_THRES => 16,
         others => <>);

      Route_In (Sig_In (U.Idx), Pin);
      Reset_Unit (U.Idx);
      Set_Pause (U.Idx, False);
   end Configure;

   -----------
   -- Count --
   -----------

   --  Reinterpret the 16-bit counter field as a two's-complement signed value,
   --  letting the type system carry the sign instead of a hand >= 32768 test.
   function To_Signed is new Ada.Unchecked_Conversion
     (Interfaces.Unsigned_16, Interfaces.Integer_16);

   function Count (U : Unit) return Integer is
   begin
      if not U.Held then
         return 0;
      end if;
      return Integer (To_Signed (Interfaces.Unsigned_16
        (PCNT_Periph.U_CNT (Integer (U.Idx)).CNT)));
   end Count;

   -----------
   -- Clear --
   -----------

   procedure Clear (U : Unit) is
   begin
      if U.Held then
         Reset_Unit (U.Idx);
      end if;
   end Clear;

   procedure Pause (U : Unit) is
   begin
      if U.Held then
         Set_Pause (U.Idx, True);
      end if;
   end Pause;

   procedure Resume (U : Unit) is
   begin
      if U.Held then
         Set_Pause (U.Idx, False);
      end if;
   end Resume;

end ESP32S3.PCNT;
