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
      W   : constant Unsigned_16 := Unsigned_16 (Code);
      Msb : constant Unsigned_8 := Unsigned_8 (Shift_Right (W, 8) and 16#0F#);
      Lsb : constant Unsigned_8 := Unsigned_8 (W and 16#FF#);
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
      D : constant Unsigned_8 := (if On then 1 else 0);
   begin
      case Unit is
         when ADC1 =>
            I2C (16#7#, 5, 5, D);

         when ADC2 =>
            I2C (16#7#, 7, 7, D);
      end case;
   end Set_Encal_Gnd;

   ---------------------------------------------------------------------------
   --  Low-level digital one-shot conversion (atten + channel + start + read).
   ---------------------------------------------------------------------------

   function Convert (Unit : ADC_Unit; Ch : Channel_Index; Atten : Attenuation) return Natural is
      Shift    : constant Natural := Natural (Ch) * 2;
      One_Hot  : constant Unsigned_16 := Shift_Left (Unsigned_16 (1), Natural (Ch));
      A_Val    : constant UInt32 := Shift_Left (UInt32 (Attenuation'Pos (Atten)), Shift);
      A_Mask   : constant UInt32 := Shift_Left (UInt32 (3), Shift);
      --  Wall-clock bound on the conversion-done poll (a conversion is a few
      --  microseconds).  A real-time deadline stays correct under -O2, where an
      --  iteration count would expire long before DONE could assert.
      use type Ada.Real_Time.Time;
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (10);
   begin
      case Unit is
         when ADC1 =>
            SENS_Periph.SAR_ATTEN1 := (SENS_Periph.SAR_ATTEN1 and not A_Mask) or A_Val;
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
            SENS_Periph.SAR_ATTEN2 := (SENS_Periph.SAR_ATTEN2 and not A_Mask) or A_Val;
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
      Code_H  : Natural := 4096;
      Code_L  : Natural := 0;
      Chk     : Natural := 2048;
      Reading : Natural;
   begin
      Set_Bias (Unit);
      Set_Encal_Gnd (Unit, True);
      Set_Init_Code (Unit, Chk);
      Reading := Convert (Unit, 0, Atten);
      while Code_H - Code_L > 1 loop
         if Reading = 0 then
            Code_H := Chk;
         else
            Code_L := Chk;
         end if;
         Chk := (Code_H + Code_L) / 2;
         Set_Init_Code (Unit, Chk);
         Reading := Convert (Unit, 0, Atten);
      end loop;
      Set_Encal_Gnd (Unit, False);
      Set_Init_Code (Unit, Chk);          --  leave the calibrated code in place
      Cal_Codes (Unit, Atten) := Chk;
   end Calibrate;

   --------------------------------------------------------------------------
   --  Unit-ownership pool (one-time analog + digital bring-up).
   --------------------------------------------------------------------------

   type Use_Map is array (ADC_Unit) of Boolean;

   protected Pool is
      procedure Claim (Unit : ADC_Unit; Ok : out Boolean);
      procedure Release (Unit : ADC_Unit);
   private
      In_Use : Use_Map := (others => False);
      Inited : Boolean := False;
   end Pool;

   protected body Pool is
      procedure Claim (Unit : ADC_Unit; Ok : out Boolean) is
         use ESP32S3_Registers.SYSTEM;
         use ESP32S3_Registers.APB_SARADC;
      begin
         if not Inited then
            SYSTEM_Periph.PERIP_CLK_EN0.APB_SARADC_CLK_EN := True;
            --  Gate the SAR ADC clock on in the SENS domain (the actual SAR
            --  conversion clock -- sibling of the temp sensor's TSENS_CLK_EN).
            SENS_Periph.SAR_PERI_CLK_GATE_CONF.SARADC_CLK_EN := True;
            --  Power the SAR on (digital XPD force + clock gate + RTC-side xpd).
            APB_SARADC_Periph.CTRL.SARADC_XPD_SAR_FORCE := 3;
            APB_SARADC_Periph.CTRL.SARADC_SAR_CLK_GATED := True;
            SENS_Periph.SAR_POWER_XPD_SAR.FORCE_XPD_SAR := 3;
            --  Enable the SARADC clock module (APB source) -- without it the SAR
            --  reader has no clock and a conversion never completes.
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
            --  Open the REGI2C bus to the SAR-ADC analog block, then calibrate
            --  both units at full range (the init code makes conversions valid).
            ANA_Config := ANA_Config or 16#3FF00#;
            ANA_Config := ANA_Config and not (UInt32'(2)**18);
            ANA_Config2 := ANA_Config2 or (UInt32'(2)**16);
            --  Calibrate BOTH units at EVERY attenuation (one-time), so a Read at
            --  any atten programs a code that was actually measured for it.
            for A in Attenuation loop
               Calibrate (ADC1, A);
               Calibrate (ADC2, A);
            end loop;
            Inited := True;
         end if;
         Ok := not In_Use (Unit);
         if Ok then
            In_Use (Unit) := True;
         end if;
      end Claim;

      procedure Release (Unit : ADC_Unit) is
      begin
         In_Use (Unit) := False;
      end Release;
   end Pool;

   -----------
   -- Claim --
   -----------

   procedure Claim (R : in out Reader; Unit : ADC_Unit) is
      Ok : Boolean;
   begin
      Release (R);
      Pool.Claim (Unit, Ok);
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
