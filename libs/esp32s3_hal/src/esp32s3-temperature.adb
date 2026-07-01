with System;
with Ada.Real_Time;
with Interfaces;             use Interfaces;
with Ada.Unchecked_Conversion;
with ESP32S3_Registers;      use ESP32S3_Registers;
with ESP32S3_Registers.SENS; use ESP32S3_Registers.SENS;

package body ESP32S3.Temperature is

   --  Conversion constants (esp-idf temperature_sensor_ll.h):
   --    T = 0.4386 * raw - 27.88 * offset - 20.52    (degrees C)
   --  In centi-degrees, with integer arithmetic:
   --    T_cC = (4386 * raw - 278800 * offset - 205200) / 100
   ADC_Factor    : constant := 4386;     --  0.4386 * 10000
   DAC_Factor    : constant := 278800;   --  27.88  * 10000
   Offset_Factor : constant := 205200;   --  20.52  * 10000

   --  Per-range DAC code (programmed over REGI2C) and its temperature offset.
   type Range_Attr is record
      DAC    : Unsigned_8;   --  I2C_SARADC_TSENS_DAC value
      Offset : Integer;      --  whole-degree offset in the formula above
   end record;

   function Attr_Of (Span : Measure_Range) return Range_Attr is
     (case Span is
         when Range_Minus10_80 => (DAC => 15, Offset =>  0),
         when Range_20_100     => (DAC =>  7, Offset => -1),
         when Range_50_125     => (DAC =>  5, Offset => -2),
         when Range_Minus30_50 => (DAC => 11, Offset =>  1),
         when Range_Minus40_20 => (DAC => 10, Offset =>  2));

   --  ESP32-S3 boot ROM: rom_i2c_writeReg_Mask -- writes a bit-field of an
   --  analog register over the internal REGI2C bus (sets the sensor's DAC
   --  range).  Args: block, host_id, reg, msb, lsb, data.
   type Rom_I2C_Write_Fn is access procedure
     (Block, Host, Reg, Msb, Lsb, Data : Unsigned_8) with Convention => C;
   function To_Fn is
     new Ada.Unchecked_Conversion (System.Address, Rom_I2C_Write_Fn);

   --  REGI2C SAR-ADC analog config (esp-idf regi2c_defs.h / regi2c_ctrl_ll.h).
   ANA_Config  : UInt32
     with Volatile, Import, Address => System'To_Address (16#6000_E044#);
   ANA_Config2 : UInt32
     with Volatile, Import, Address => System'To_Address (16#6000_E048#);

   I2C_SAR_ADC      : constant Unsigned_8 := 16#69#;  --  REGI2C block (SAR ADC)
   I2C_SAR_ADC_HOST : constant Unsigned_8 := 1;
   TSENS_DAC_Reg    : constant Unsigned_8 := 16#6#;   --  reg=6, bits [3..0]
   TSENS_DAC_Msb    : constant Unsigned_8 := 3;
   TSENS_DAC_Lsb    : constant Unsigned_8 := 0;

   --  Let the analog settle after power-up; not critical (the dump/ready
   --  handshake gates each reading), just bias settling time.  A wall-clock
   --  wait states the intended duration directly and, unlike an iteration
   --  count, cannot be optimised away or vary with CPU speed.
   procedure Settle is
      use type Ada.Real_Time.Time;
      Deadline : constant Ada.Real_Time.Time :=
        Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (5);
   begin
      while Ada.Real_Time.Clock < Deadline loop
         null;
      end loop;
   end Settle;

   --------------------------------------------------------------------------
   --  The sensor is a single shared resource and each sample is a multi-step
   --  dump-out / wait-ready / read handshake, so serialise it: a protected
   --  object owns the bring-up and every sample, making concurrent Read_* from
   --  different tasks safe.  Critical sections are short (a few register writes
   --  + a microsecond ready-spin); the one-time bring-up settle is the only
   --  longer hold, and only on the very first sample.
   --------------------------------------------------------------------------

   protected Sensor is
      procedure Configure (Span : Measure_Range);
      procedure Sample (Raw : out Byte; Centi : out Integer);
   private
      Inited : Boolean := False;
      Offset : Integer := 0;          --  offset of the configured range
   end Sensor;

   protected body Sensor is

      procedure Configure (Span : Measure_Range) is
         Attr          : constant Range_Attr := Attr_Of (Span);
         Rom_I2C_Write : constant Rom_I2C_Write_Fn :=
           To_Fn (System'To_Address (16#4000_5D6C#));
      begin
         --  1. Gate the SAR peripheral clock on.
         SENS_Periph.SAR_PERI_CLK_GATE_CONF.TSENS_CLK_EN := True;
         --  2. Pulse-reset the temperature-sensor sub-module.
         SENS_Periph.SAR_PERI_RESET_CONF.SAR_TSENS_RESET := True;
         SENS_Periph.SAR_PERI_RESET_CONF.SAR_TSENS_RESET := False;
         --  3. Open the REGI2C internal bus to the SAR-ADC block.
         ANA_Config  := ANA_Config or 16#3FF00#;
         ANA_Config  := ANA_Config and not (UInt32'(2) ** 18);
         ANA_Config2 := ANA_Config2 or (UInt32'(2) ** 16);
         --  4. Program the DAC range over REGI2C.
         Rom_I2C_Write (I2C_SAR_ADC, I2C_SAR_ADC_HOST,
                        TSENS_DAC_Reg, TSENS_DAC_Msb, TSENS_DAC_Lsb, Attr.DAC);
         Offset := Attr.Offset;
         --  5. Power the sensor up under software control.
         SENS_Periph.SAR_TSENS_CTRL.SAR_TSENS_POWER_UP_FORCE := True;
         SENS_Periph.SAR_TSENS_CTRL2.SAR_TSENS_XPD_FORCE     := 1;
         SENS_Periph.SAR_TSENS_CTRL.SAR_TSENS_CLK_DIV        := 6;
         SENS_Periph.SAR_TSENS_CTRL.SAR_TSENS_POWER_UP       := True;
         Settle;
         Inited := True;
      end Configure;

      procedure Sample (Raw : out Byte; Centi : out Integer) is
      begin
         if not Inited then
            Configure (Range_Minus10_80);     --  auto bring-up, default range
         end if;
         --  Latch a fresh conversion: dump_out=1, wait ready, dump_out=0.
         SENS_Periph.SAR_TSENS_CTRL.SAR_TSENS_DUMP_OUT := True;
         --  Ready arrives within microseconds; bound the poll so a stuck sensor
         --  cannot hang the (protected) sample forever.
         declare
            use type Ada.Real_Time.Time;
            Deadline : constant Ada.Real_Time.Time :=
              Ada.Real_Time.Clock + Ada.Real_Time.Milliseconds (10);
         begin
            while not SENS_Periph.SAR_TSENS_CTRL.SAR_TSENS_READY
              and then Ada.Real_Time.Clock < Deadline
            loop
               null;
            end loop;
         end;
         SENS_Periph.SAR_TSENS_CTRL.SAR_TSENS_DUMP_OUT := False;
         Raw   := SENS_Periph.SAR_TSENS_CTRL.SAR_TSENS_OUT;
         Centi := (ADC_Factor * Integer (Raw)
                   - DAC_Factor * Offset
                   - Offset_Factor) / 100;
      end Sample;

   end Sensor;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Span : Measure_Range := Range_Minus10_80) is
   begin
      Sensor.Configure (Span);
   end Initialize;

   --------------
   -- Read_Raw --
   --------------

   function Read_Raw return ESP32S3_Registers.Byte is
      Raw   : Byte;
      Centi : Integer;
   begin
      Sensor.Sample (Raw, Centi);
      return Raw;
   end Read_Raw;

   ------------------------
   -- Read_Centi_Celsius --
   ------------------------

   function Read_Centi_Celsius return Integer is
      Raw   : Byte;
      Centi : Integer;
   begin
      Sensor.Sample (Raw, Centi);
      return Centi;
   end Read_Centi_Celsius;

   ------------------
   -- Read_Celsius --
   ------------------

   function Read_Celsius return Integer is
   begin
      return Read_Centi_Celsius / 100;
   end Read_Celsius;

end ESP32S3.Temperature;
