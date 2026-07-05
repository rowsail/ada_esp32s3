with Interfaces;             use Interfaces;
with System;
with Ada.Real_Time;
with Ada.Unchecked_Conversion;
with ESP32S3.GPIO;
with ESP32S3_Registers;      use ESP32S3_Registers;
with ESP32S3_Registers.SENS; use ESP32S3_Registers.SENS;
with ESP32S3_Registers.APB_SARADC;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.ADC is

   function Channel_Pin (Unit : ADC_Unit; Ch : Channel_Index) return ESP32S3.GPIO.Pin_Id
   is (case Unit is
         when ADC1 => ESP32S3.GPIO.Pin_Id (1 + Natural (Ch)),
         when ADC2 => ESP32S3.GPIO.Pin_Id (11 + Natural (Ch)));

   ---------------------------------------------------------------------------
   --  REGI2C (analog trim) access via the boot ROM, exactly as the temperature
   --  sensor does: the SAR ADC's bias/calibration live in analog registers
   --  reached over an internal I2C bus, and the S3 returns 0 from every
   --  conversion until they are set.  rom_i2c_writeReg_Mask writes a bit field.
   ---------------------------------------------------------------------------

   type Rom_I2C_Write_Fn is access procedure (Block, Host, Reg, Msb, Lsb, Data : Unsigned_8)
   with Convention => C;
   function To_Fn is new Ada.Unchecked_Conversion (System.Address, Rom_I2C_Write_Fn);
   Rom_I2C_Write : constant Rom_I2C_Write_Fn := To_Fn (System'To_Address (16#4000_5D6C#));

   ANA_Config  : UInt32
   with Volatile, Import, Address => System'To_Address (16#6000_E044#);
   ANA_Config2 : UInt32
   with Volatile, Import, Address => System'To_Address (16#6000_E048#);

   I2C_SAR_ADC      : constant Unsigned_8 := 16#69#;   --  REGI2C block (SAR ADC)
   I2C_SAR_ADC_HOST : constant Unsigned_8 := 1;

   --  The SAR self-calibration init code is attenuation-DEPENDENT (each atten has
   --  its own analog gain), so keep one per (unit, attenuation) and program the
   --  matching one before each conversion -- calibrating at a single atten and
   --  reusing that code at the others skews every non-calibrated-atten reading.
   Cal_Codes : array (ADC_Unit, Attenuation) of Natural := (others => (others => 0));
   Done_Flag : Boolean := False;

   procedure I2C (Reg, Msb, Lsb, Data : Unsigned_8) is
   begin
      Rom_I2C_Write (I2C_SAR_ADC, I2C_SAR_ADC_HOST, Reg, Msb, Lsb, Data);
   end I2C;

   --  Set the SAR's reference (DREF=4) and sample cycle, per unit.
   procedure Set_Bias (Unit : ADC_Unit) is
   begin
      case Unit is
         when ADC1 =>
            I2C (16#2#, 6, 4, 4);
            I2C (16#2#, 2, 0, 2);  --  DREF, sample

         when ADC2 =>
            I2C (16#5#, 6, 4, 4);
      end case;
   end Set_Bias;

   --  Program the 12-bit calibration "initial code", per unit.
   procedure Set_Init_Code (Unit : ADC_Unit; Code : Natural) is
      Code_Word : constant Unsigned_16 := Unsigned_16 (Code);
      --  Msb/Lsb: most/least-significant byte of the 12-bit init code.
      Msb       : constant Unsigned_8 := Unsigned_8 (Shift_Right (Code_Word, 8) and 16#0F#);
      Lsb       : constant Unsigned_8 := Unsigned_8 (Code_Word and 16#FF#);
   begin
      case Unit is
         when ADC1 =>
            I2C (16#1#, 3, 0, Msb);
            I2C (16#0#, 7, 0, Lsb);

         when ADC2 =>
            I2C (16#4#, 3, 0, Msb);
            I2C (16#3#, 7, 0, Lsb);
      end case;
   end Set_Init_Code;

   --  Connect the SAR input to the internal ground (for self-calibration).
   procedure Set_Encal_Gnd (Unit : ADC_Unit; On : Boolean) is
      Enable_Bit : constant Unsigned_8 := (if On then 1 else 0);
   begin
      case Unit is
         when ADC1 =>
            I2C (16#7#, 5, 5, Enable_Bit);

         when ADC2 =>
            I2C (16#7#, 7, 7, Enable_Bit);
      end case;
   end Set_Encal_Gnd;

   ---------------------------------------------------------------------------
   --  Low-level digital one-shot conversion (atten + channel + start + read).
   ---------------------------------------------------------------------------

   function Convert (Unit : ADC_Unit; Ch : Channel_Index; Atten : Attenuation) return Natural is
      Shift       : constant Natural := Natural (Ch) * 2;
      One_Hot     : constant Unsigned_16 := Shift_Left (Unsigned_16 (1), Natural (Ch));
      Atten_Value : constant UInt32 := Shift_Left (UInt32 (Attenuation'Pos (Atten)), Shift);
      Atten_Mask  : constant UInt32 := Shift_Left (UInt32 (3), Shift);
      --  Wall-clock bound on the conversion-done poll (a conversion is a few
      --  microseconds).  A real-time deadline stays correct under -O2, where an
      --  iteration count would expire long before DONE could assert.
      use type Ada.Real_Time.Time;
      Deadline    : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (10);
   begin
      case Unit is
         when ADC1 =>
            SENS_Periph.SAR_ATTEN1 := (SENS_Periph.SAR_ATTEN1 and not Atten_Mask) or Atten_Value;
            SENS_Periph.SAR_MEAS1_CTRL2.SAR1_EN_PAD := SAR_MEAS1_CTRL2_SAR1_EN_PAD_Field (One_Hot);
            SENS_Periph.SAR_MEAS1_CTRL2.MEAS1_START_SAR := False;
            SENS_Periph.SAR_MEAS1_CTRL2.MEAS1_START_SAR := True;
            while not SENS_Periph.SAR_MEAS1_CTRL2.MEAS1_DONE_SAR
              and then Ada.Real_Time.Clock < Deadline
            loop
               null;
            end loop;
            Done_Flag := SENS_Periph.SAR_MEAS1_CTRL2.MEAS1_DONE_SAR;
            return Natural (SENS_Periph.SAR_MEAS1_CTRL2.MEAS1_DATA_SAR and 16#0FFF#);

         when ADC2 =>
            SENS_Periph.SAR_ATTEN2 := (SENS_Periph.SAR_ATTEN2 and not Atten_Mask) or Atten_Value;
            SENS_Periph.SAR_MEAS2_CTRL2.SAR2_EN_PAD := SAR_MEAS2_CTRL2_SAR2_EN_PAD_Field (One_Hot);
            SENS_Periph.SAR_MEAS2_CTRL2.MEAS2_START_SAR := False;
            SENS_Periph.SAR_MEAS2_CTRL2.MEAS2_START_SAR := True;
            while not SENS_Periph.SAR_MEAS2_CTRL2.MEAS2_DONE_SAR
              and then Ada.Real_Time.Clock < Deadline
            loop
               null;
            end loop;
            Done_Flag := SENS_Periph.SAR_MEAS2_CTRL2.MEAS2_DONE_SAR;
            return Natural (SENS_Periph.SAR_MEAS2_CTRL2.MEAS2_DATA_SAR and 16#0FFF#);
      end case;
   end Convert;

   --  Self-calibrate a unit at the given attenuation: with the input grounded,
   --  binary-search the initial code for the value that just reads zero, and
   --  leave that code programmed (esp-idf adc_hal_self_calibration, single pass).
   procedure Calibrate (Unit : ADC_Unit; Atten : Attenuation) is
      Code_H     : Natural := 4096;
      Code_L     : Natural := 0;
      Trial_Code : Natural := 2048;
      Reading    : Natural;
   begin
      Set_Bias (Unit);
      Set_Encal_Gnd (Unit, True);
      Set_Init_Code (Unit, Trial_Code);
      Reading := Convert (Unit, 0, Atten);
      while Code_H - Code_L > 1 loop
         if Reading = 0 then
            Code_H := Trial_Code;
         else
            Code_L := Trial_Code;
         end if;
         Trial_Code := (Code_H + Code_L) / 2;
         Set_Init_Code (Unit, Trial_Code);
         Reading := Convert (Unit, 0, Atten);
      end loop;
      Set_Encal_Gnd (Unit, False);
      Set_Init_Code (Unit, Trial_Code);   --  leave the calibrated code in place
      Cal_Codes (Unit, Atten) := Trial_Code;
   end Calibrate;

   --------------------------------------------------------------------------
   --  Unit-ownership pool (one-time analog + digital bring-up).
   --------------------------------------------------------------------------

   type Use_Map is array (ADC_Unit) of Boolean;

   --  One-time analog + digital bring-up: gate clocks, power the SAR on, and
   --  calibrate both units at every attenuation.  This runs at TASK level (from
   --  Claim), NOT inside a protected action -- the calibration is dozens of
   --  conversions, each busy-polling up to 10 ms, and doing that under the Pool
   --  lock at its ceiling priority would stall every other task for the duration.
   procedure Bring_Up is
      use ESP32S3_Registers.SYSTEM;
      use ESP32S3_Registers.APB_SARADC;
   begin
      SYSTEM_Periph.PERIP_CLK_EN0.APB_SARADC_CLK_EN := True;
      --  Gate the SAR ADC clock on in the SENS domain (the actual SAR conversion
      --  clock -- sibling of the temp sensor's TSENS_CLK_EN).
      SENS_Periph.SAR_PERI_CLK_GATE_CONF.SARADC_CLK_EN := True;
      --  Power the SAR on (digital XPD force + clock gate + RTC-side xpd).
      APB_SARADC_Periph.CTRL.SARADC_XPD_SAR_FORCE := 3;
      APB_SARADC_Periph.CTRL.SARADC_SAR_CLK_GATED := True;
      SENS_Periph.SAR_POWER_XPD_SAR.FORCE_XPD_SAR := 3;
      --  Enable the SARADC clock module (APB source) -- without it the SAR reader
      --  has no clock and a conversion never completes.
      APB_SARADC_Periph.CLKM_CONF.CLK_SEL := 2;        --  APB clock
      APB_SARADC_Periph.CLKM_CONF.CLK_EN := True;
      SENS_Periph.SAR_READER1_CTRL.SAR_SAR1_CLK_DIV := 2;
      SENS_Periph.SAR_READER2_CTRL.SAR_SAR2_CLK_DIV := 2;
      --  Software (RTC) control of both units: SW start + SW bit-map.
      SENS_Periph.SAR_MEAS1_MUX.SAR1_DIG_FORCE := False;
      SENS_Periph.SAR_MEAS1_CTRL2.MEAS1_START_FORCE := True;
      SENS_Periph.SAR_MEAS1_CTRL2.SAR1_EN_PAD_FORCE := True;
      SENS_Periph.SAR_MEAS2_CTRL2.MEAS2_START_FORCE := True;
      SENS_Periph.SAR_MEAS2_CTRL2.SAR2_EN_PAD_FORCE := True;
      --  Open the REGI2C bus to the SAR-ADC analog block, then calibrate both
      --  units at full range (the init code makes conversions valid).
      ANA_Config := ANA_Config or 16#3FF00#;
      ANA_Config := ANA_Config and not (UInt32'(2)**18);
      ANA_Config2 := ANA_Config2 or (UInt32'(2)**16);
      --  Calibrate BOTH units at EVERY attenuation (one-time), so a Read at any
      --  atten programs a code that was actually measured for it.
      for Atten in Attenuation loop
         Calibrate (ADC1, Atten);
         Calibrate (ADC2, Atten);
      end loop;
   end Bring_Up;

   protected Pool is
      --  Claim the unit AND elect exactly one task to run Bring_Up (Do_Init).
      procedure Claim (Unit : ADC_Unit; Ok : out Boolean; Do_Init : out Boolean);
      procedure Mark_Inited;
      function Is_Inited return Boolean;
      procedure Release (Unit : ADC_Unit);
   private
      In_Use       : Use_Map := (others => False);
      Init_Started : Boolean := False;   --  a task has taken responsibility to init
      Inited       : Boolean := False;   --  Bring_Up has finished
   end Pool;

   protected body Pool is
      procedure Claim (Unit : ADC_Unit; Ok : out Boolean; Do_Init : out Boolean) is
      begin
         Do_Init := not Init_Started;
         if Do_Init then
            Init_Started := True;        --  this caller will run Bring_Up (outside)
         end if;
         Ok := not In_Use (Unit);
         if Ok then
            In_Use (Unit) := True;
         end if;
      end Claim;

      procedure Mark_Inited is
      begin
         Inited := True;
      end Mark_Inited;

      function Is_Inited return Boolean
      is (Inited);

      procedure Release (Unit : ADC_Unit) is
      begin
         In_Use (Unit) := False;
      end Release;
   end Pool;

   -----------
   -- Claim --
   -----------

   procedure Claim (R : in out Reader; Unit : ADC_Unit) is
      use type Ada.Real_Time.Time;
      Ok, Do_Init : Boolean;
   begin
      Release (R);
      Pool.Claim (Unit, Ok, Do_Init);
      if Do_Init then
         Bring_Up;                 --  run the one-time init/calibration at task level
         Pool.Mark_Inited;
      else
         --  Another task is bringing the ADC up; wait for it before using it.
         while not Pool.Is_Inited loop
            delay until Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (1);
         end loop;
      end if;
      if Ok then
         R.Unit := Unit;
         R.Held := True;
      end if;
   end Claim;

   function Is_Valid (R : Reader) return Boolean
   is (R.Held);

   procedure Release (R : in out Reader) is
   begin
      if R.Held then
         Pool.Release (R.Unit);
         R.Held := False;
      end if;
   end Release;

   overriding
   procedure Finalize (R : in out Reader) is
   begin
      Release (R);
   end Finalize;

   ----------
   -- Read --
   ----------

   function Cal_Code (Unit : ADC_Unit) return Natural
   is (Cal_Codes (Unit, Db_12));
   function Last_Done return Boolean
   is (Done_Flag);

   function Read (R : Reader; Ch : Channel_Index; Atten : Attenuation := Db_12) return Raw_Value is
   begin
      if not R.Held then
         return 0;
      end if;
      --  Program the init code calibrated FOR THIS attenuation before converting.
      Set_Init_Code (R.Unit, Cal_Codes (R.Unit, Atten));
      return Raw_Value (Convert (R.Unit, Ch, Atten));
   end Read;

end ESP32S3.ADC;
