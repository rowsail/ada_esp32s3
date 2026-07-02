--  SHT41 temperature/humidity sensor driver demo on the bare-metal ESP32-S3 (no
--  FreeRTOS, no IDF)
--  ====================================================================
--  What it demonstrates:  the reusable HAL sensor driver (ESP32S3.SHT41)
--  against a real Sensirion SHT41 on the I2C bus.  Two operations:
--    probe   read the sensor's 32-bit serial number -- doubles as a comms /
--            presence check (the part must ACK and the words must pass CRC).
--    sample  trigger a high-precision measurement once a second and print the
--            temperature and relative humidity.
--  No interrupt: the sensor is simply read on request.  Report goes through the
--  ROM printf glue (ESP32S3.Log); the Ada driver does all the I2C work.
--
--  Build & run:  ./x run esp32s3_sht41
--    The driver uses the controlled I2C Session (finalization), so this runs on
--    the embedded profile (build.sh sets ESP32S3_RTS_PROFILE=embedded), not the
--    default light-tasking.
--  Output:  a banner, the serial number with "(SHT41 present)", then one
--    "[sht] T=.. C  RH=.. %" line per second for 15 s, then "[sht] done.".  If
--    the sensor does not ACK, the line reads "(no ACK!)" and the demo stops with
--    "[sht] no SHT41 found at 0x44 -- check wiring/power.".
--  Hardware:  one Sensirion SHT41 on I2C0 -- SDA = IO8, SCL = IO7, VDD/VSS to
--    3V3/GND.  The SHT41-AD1B answers at I2C address 0x44 (the driver default).
with Interfaces;
use type Interfaces.Unsigned_32;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.SHT41;
with ESP32S3.Log; use ESP32S3.Log;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the demo runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package SHT41 renames ESP32S3.SHT41;
   use type SHT41.Status;

   --  Board wiring of the SHT41 on I2C0 (handed to Setup; the driver hard-codes
   --  no pins).
   Sensor_Sda_Pin : constant := 8;   --  IO8 = I2C0 data
   Sensor_Scl_Pin : constant := 7;   --  IO7 = I2C0 clock

   --  Let the console settle before the first line so the banner is not eaten by
   --  boot chatter.
   Console_Settle : constant Time_Span := Milliseconds (200);

   --  Sampling schedule: one reading per second, fifteen readings then stop.
   Sample_Interval : constant Time_Span := Seconds (1);
   Sample_Count    : constant := 15;

   --  Parking delay for the idle loops once the demo has nothing left to do.
   Idle_Park : constant Time_Span := Seconds (3600);

   --  Measurement.Temperature / .Humidity arrive in integer milli-units (so no
   --  float library is needed): divide by 1000 to get whole units, and print to
   --  this many decimal places.
   Milli_Per_Unit : constant := 1000;
   Decimal_Places : constant := 2;

   Sensor        : SHT41.Device;
   Result_Status : SHT41.Status;
   Serial_Number : Interfaces.Unsigned_32;
begin
   delay until Clock + Console_Settle;
   Put_Line ("[sht] SHT41 temperature/humidity driver demo (SDA=IO8 SCL=IO7)");

   SHT41.Setup (Sensor, Sda => Sensor_Sda_Pin, Scl => Sensor_Scl_Pin);

   --  probe: the serial number doubles as a presence check.
   SHT41.Read_Serial_Number (Sensor, Serial_Number, Result_Status);
   Put ("[sht] serial : 0x");
   Put_Hex (Serial_Number, 8);
   Put ("  ");
   Put_Line (if Result_Status = SHT41.OK then "(SHT41 present)" else "(no ACK!)");
   if Result_Status /= SHT41.OK then
      Put_Line ("[sht] no SHT41 found at 0x44 -- check wiring/power.");
      loop
         delay until Clock + Idle_Park;
      end loop;
   end if;

   --  sample once a second.
   for Tick in 1 .. Sample_Count loop
      delay until Clock + Sample_Interval;
      declare
         Reading : SHT41.Measurement;
      begin
         SHT41.Measure (Sensor, Reading, Result_Status);
         exit when Result_Status /= SHT41.OK;
         Put ("[sht] T=");
         Put_Fixed (Integer (Reading.Temperature), Milli_Per_Unit, Decimal_Places);
         Put (" C  RH=");
         Put_Fixed (Integer (Reading.Humidity), Milli_Per_Unit, Decimal_Places);
         Put_Line (" %");
      end;
   end loop;

   Put_Line ("[sht] done.");

   loop
      delay until Clock + Idle_Park;
   end loop;
end Main;
