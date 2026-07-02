--  QMI8658C 6-axis IMU driver demo (bare-metal ESP32-S3, no FreeRTOS, no IDF)
--  =========================================================================
--
--  What it demonstrates
--  --------------------
--  The reusable HAL IMU driver (ESP32S3.QMI8658C) talking to a real QST
--  QMI8658C 6-axis accelerometer/gyroscope over the task-safe ESP32S3.I2C
--  master.  End to end on silicon it:
--    probe      reads WHO_AM_I; tries both SA0 addresses (0x6B, 0x6A).
--    reset      soft-resets to a known register state, then waits ~15 ms.
--    configure  sets accelerometer / gyroscope full scale + output rate and
--               enables both sensors (6DOF).
--    sample     reads accel + gyro + temperature once every 250 ms and prints
--               them in milli-g / milli-dps / centi-degC using integer math
--               only, so the ROM printf console needs no float support.
--  The wiring is stated HERE (the driver hard-codes no pins) and handed to
--  Setup.
--
--  Build & run
--  -----------
--  `./x run esp32s3_qmi8658c` -- needs the embedded runtime profile, which the
--  example's build.sh selects (ESP32S3_RTS_PROFILE=embedded), because the
--  driver uses a controlled I2C Session (finalization).
--
--  Output
--  ------
--  Goes through ESP32S3.Log over the ROM USB-Serial-JTAG printf; the Ada
--  driver does all the I2C/register work.  After the probe line it prints one
--  setup-step line each for reset/configure, a temperature line, a one-line
--  legend, then ten sample lines (one per 250 ms) and "[imu] done.".  Sitting
--  flat, Z should read about +925 mg and |a| about 9.1 m/s2 (a ~7% shortfall
--  on an uncalibrated part).  "no QMI8658C found" means a wiring/power problem.
--
--  Hardware / wiring
--  -----------------
--    QMI8658C on I2C0: SDA = IO8, SCL = IO7 (internal pull-ups for bring-up).
--    The 7-bit address is set by SA0: 0x6B (SA0=GND) or 0x6A (SA0=VDDIO).
--    This board does not wire the QMI8658C INT line, so Interrupt_Pin is No_Pin
--    and the demo polls; point it at the GPIO an INT line (INT1/INT2) is wired
--    to instead, to arm the data-ready interrupt.
with Interfaces;    use Interfaces;
with ESP32S3.Log;   use ESP32S3.Log;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.I2C;
with ESP32S3.QMI8658C;
with ESP32S3.QMI8658C.Interrupts;
with IMU_IRQ;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the demo runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package IMU renames ESP32S3.QMI8658C;
   use type IMU.Status;

   --  Board wiring for THIS example (the driver hard-codes none).  This board
   --  does not wire the QMI8658C INT line, so Interrupt_Pin is No_Pin and the
   --  demo polls; point it at a real GPIO to arm the data-ready interrupt.
   IMU_SDA       : constant ESP32S3.GPIO.Pin_Id := 8;
   IMU_SCL       : constant ESP32S3.GPIO.Pin_Id := 7;
   Interrupt_Pin : constant ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;

   --  The two possible SA0 addresses; the probe below tries each in turn.
   Address_Candidates : constant array (1 .. 2) of ESP32S3.I2C.Slave_Address :=
     (IMU.Address_SA0_Low, IMU.Address_SA0_High);

   --  Spacing for one setup-step line, e.g. "[imu] reset     : OK": the step
   --  name is padded out to this many characters (the old "%-9s" width).
   Step_Name_Width : constant := 9;

   --  Raw counts scale to milli-units (raw * 1000 fits in 32-bit integer math).
   Milli_Per_Unit : constant := 1000;

   --  Temperature register: 256 LSB per degree Celsius (QMI8658C datasheet);
   --  the example prints centi-degC, so it multiplies by 100 before dividing.
   Temp_LSB_Per_Deg_C : constant := 256;
   Centi_Per_Unit     : constant := 100;   --  hundredths, for Put_Fixed scaling

   --  Convert a milli-g magnitude to centi-m/s2: 1000 mg = 1 g = 9.81 m/s2,
   --  so multiply by 981 and divide by 1000 (the result is in hundredths).
   Milli_G_Per_G    : constant := 1000;
   Centi_Mps2_Per_G : constant := 981;

   --  One setup-step line, e.g. "[imu] reset     : OK" (name left-justified).
   procedure Put_Step (Name : String; Ok : Boolean) is
   begin
      Put ("[imu] ");
      Put (Name);
      for I in Name'Length + 1 .. Step_Name_Width loop
         Put (" ");
      end loop;
      Put (" : ");
      Put_Line (if Ok then "OK" else "FAIL");
   end Put_Step;

   Device   : IMU.Device;
   Result   : IMU.Status;
   Who_Am_I : Unsigned_8;
   Found    : Boolean := False;
   Address  : ESP32S3.I2C.Slave_Address := IMU.Address_SA0_Low;

   --  Raw counts -> milli-units, in 32-bit integer math (raw * 1000 fits).
   function Milli_Units (Raw : Integer_16; LSB_Per_Unit : Positive) return Integer
   is (Integer (Raw) * Milli_Per_Unit / LSB_Per_Unit);

   --  Integer floor(sqrt(N)) -- the accel magnitude needs no float library.
   function Integer_Sqrt (N : Integer) return Integer is
      Estimate : Integer;
      Next     : Integer;
   begin
      if N <= 0 then
         return 0;
      end if;
      Estimate := N;
      Next := (Estimate + 1) / 2;
      while Next < Estimate loop
         Estimate := Next;
         Next := (Estimate + N / Estimate) / 2;
      end loop;
      return Estimate;
   end Integer_Sqrt;

begin
   delay until Clock + Milliseconds (200);   --  let the console settle
   Put_Line ("[imu] QMI8658C 6-axis IMU driver demo (SDA=IO8  SCL=IO7)");

   --  probe: try each SA0 address until WHO_AM_I answers Who_Am_I_Value (0x05).
   for I in Address_Candidates'Range loop
      Address := Address_Candidates (I);
      IMU.Setup
        (Device, Sda => IMU_SDA, Scl => IMU_SCL, Int_Pin => Interrupt_Pin, Address => Address);
      IMU.Read_Who_Am_I (Device, Who_Am_I, Result);
      if Result = IMU.OK and then Who_Am_I = IMU.Who_Am_I_Value then
         Found := True;
         exit;
      end if;
   end loop;

   Put ("[imu] who_am_i : 0x");
   Put_Hex (Unsigned_32 (Who_Am_I), 2);
   Put (" @ 0x");
   Put_Hex (Unsigned_32 (Address), 2);
   Put_Line (if Found then "  (QMI8658 present)" else "  (unexpected!)");
   if not Found then
      Put_Line ("[imu] no QMI8658C found at 0x6B or 0x6A -- check wiring/power.");
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   --  Arm the INT interrupt on the stored pin -- a no-op here (No_Pin).
   IMU.Interrupts.Attach (Device, IMU_IRQ.Handler'Access);

   --  reset -> (settle) -> configure.
   IMU.Reset (Device, Result);
   Put_Step ("reset", Result = IMU.OK);
   delay until Clock + Milliseconds (15);     --  reset settle time

   IMU.Configure
     (Device,
      Accel  => IMU.Range_8G,
      Gyro   => IMU.Range_512DPS,
      Rate   => IMU.ODR_235_Hz,
      Result => Result);
   Put_Step ("configure", Result = IMU.OK);
   if Result /= IMU.OK then
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   --  sample: read accel + gyro + temperature once a quarter second and print
   --  one line each (the glue builds the whole line and emits it with a single
   --  esp_rom_printf).
   declare
      Accel            : IMU.Axes;
      Gyro             : IMU.Axes;
      Temperature_Raw  : Integer_16;
      Accel_LSB_Per_G  : constant Positive := IMU.Accel_LSB_Per_G (Device);
      Gyro_LSB_Per_DPS : constant Positive := IMU.Gyro_LSB_Per_DPS (Device);
   begin
      --  one temperature reading up front (its own spaced line), then stream.
      delay until Clock + Milliseconds (250);
      IMU.Read_Temperature (Device, Temperature_Raw, Result);
      if Result = IMU.OK then
         Put ("[imu] temp[C]=");
         --  raw / 256 = degC; scaled to centi-degC for the 2-decimal print.
         Put_Fixed
           (Integer (Temperature_Raw) * Centi_Per_Unit / Temp_LSB_Per_Deg_C, Centi_Per_Unit, 2);
         New_Line;
      end if;

      delay until Clock + Milliseconds (250);
      Put_Line ("[imu] a=accel[mg]  |a|=total[m/s2]  g=gyro[mdps]");
      for Tick in 1 .. 10 loop
         delay until Clock + Milliseconds (250);

         IMU.Read_Accelerometer (Device, Accel, Result);
         exit when Result /= IMU.OK;
         IMU.Read_Gyroscope (Device, Gyro, Result);
         exit when Result /= IMU.OK;

         declare
            Accel_X_Mg : constant Integer := Milli_Units (Accel.X, Accel_LSB_Per_G);
            Accel_Y_Mg : constant Integer := Milli_Units (Accel.Y, Accel_LSB_Per_G);
            Accel_Z_Mg : constant Integer := Milli_Units (Accel.Z, Accel_LSB_Per_G);

            --  |a| in milli-g, then in centi-m/s2 (for the 2-decimal print).
            Magnitude_Mg         : constant Integer :=
              Integer_Sqrt
                (Accel_X_Mg * Accel_X_Mg + Accel_Y_Mg * Accel_Y_Mg + Accel_Z_Mg * Accel_Z_Mg);
            Magnitude_Centi_Mps2 : constant Integer :=
              Magnitude_Mg * Centi_Mps2_Per_G / Milli_G_Per_G;
         begin
            --  One compact line: a=<x><y><z>  |a|=<g.gg>  g=<x><y><z>
            Put ("[imu] a=");
            Put (Accel_X_Mg, Width => 6);
            Put (Accel_Y_Mg, Width => 6);
            Put (Accel_Z_Mg, Width => 6);
            Put (" |a|=");
            Put_Fixed (Magnitude_Centi_Mps2, Centi_Per_Unit, 2);
            Put (" g=");
            Put (Milli_Units (Gyro.X, Gyro_LSB_Per_DPS), Width => 7);
            Put (Milli_Units (Gyro.Y, Gyro_LSB_Per_DPS), Width => 7);
            Put (Milli_Units (Gyro.Z, Gyro_LSB_Per_DPS), Width => 7);
            New_Line;
         end;
      end loop;
   end;

   delay until Clock + Milliseconds (250);   --  let the last sample line drain
   Put_Line ("[imu] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
