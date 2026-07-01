--  PCF85063A real-time clock on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)
--  =========================================================================
--  What it demonstrates:  the reusable HAL RTC driver (ESP32S3.PCF85063A) driving
--  a real NXP PCF85063A on the I2C bus, end to end on silicon:
--    probe      address the chip (Get_Time): ACK => present, NACK => absent.
--    reset      software-reset to a known register state.
--    set-time   load a known calendar (writing seconds clears the chip's
--               oscillator-stop flag, so the clock-integrity flag reads OK).
--    set-alarm  arm a seconds-match alarm 5 s out (enables the INT output too).
--    watch      print the time once a second; when the alarm flag (AF) latches,
--               report it and acknowledge it (which releases INT).
--
--  Build & run:  ./x run esp32s3_pcf85063a
--    The driver uses the controlled I2C Session (finalization), so this runs on
--    the embedded profile (build.sh sets ESP32S3_RTS_PROFILE=embedded), not the
--    default light-tasking.
--  Output:  a banner, "OK" on each of the four bus steps (probe/reset/set-time/
--    set-alarm), one calendar line per second, then "*** ALARM fired ***" once
--    the seconds-match latches, then "[rtc] done.".  If the chip does not ACK,
--    the run prints "no PCF85063A ACK at 0x51" instead and idles.
--  Hardware:  a PCF85063A on the I2C bus -- SDA=IO8, SCL=IO7 (Rtc_Sda / Rtc_Scl
--    below), VDD=3V3, plus its VBAT backup-battery cell that keeps the clock
--    running across power loss.  The driver hard-codes no pins; the wiring is
--    stated here and handed to Setup.  This board has no INT line wired, so
--    Rtc_Int is No_Pin and the alarm is found by polling AF over I2C.  Point
--    Rtc_Int at the GPIO the INT line is wired to (active-low, open-drain) to arm
--    the hardware interrupt instead -- the falling-edge ISR then latches
--    Alarm_IRQ.Fired.
--
--  Report goes through the buffered ESP32S3.Text_IO console; the Ada driver does
--  all the I2C/register work.
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.PCF85063A;
with ESP32S3.PCF85063A.Interrupts;
with ESP32S3.Text_IO;  use ESP32S3.Text_IO;   --  buffered console (no rom-printf)
with Alarm_IRQ;

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the demo runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package RTC renames ESP32S3.PCF85063A;
   use type RTC.Status;

   --  Board wiring for THIS example (the driver hard-codes none).  The
   --  PCF85063A on this board has no INT line, so its pin is No_Pin and the
   --  alarm is found by polling AF over I2C.  Point it at a real GPIO (and the
   --  Attach below arms the hardware interrupt) if INT is wired.
   Rtc_Sda : constant ESP32S3.GPIO.Pin_Id       := 8;   --  I2C data  -> IO8
   Rtc_Scl : constant ESP32S3.GPIO.Pin_Id       := 7;   --  I2C clock -> IO7
   Rtc_Int : constant ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;

   --  Console reporters, formerly esp_rom_printf natives in glue.c, now pure Ada
   --  over the buffered ESP32S3.Text_IO console.

   --  Zero-padded decimal, at least Width digits (like C "%0Nd").
   procedure Put_Dec0 (V : Natural; Width : Positive) is
      S : String (1 .. 12);
      P : Natural := S'Last;
      X : Natural := V;
   begin
      loop
         S (P) := Character'Val (Character'Pos ('0') + X mod 10);
         X := X / 10;
         exit when X = 0;
         P := P - 1;
      end loop;
      while S'Last - P + 1 < Width loop
         P := P - 1;
         S (P) := '0';
      end loop;
      Put (S (P .. S'Last));
   end Put_Dec0;

   Dow : constant array (0 .. 6) of String (1 .. 3) :=
     ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");

   procedure Banner is
   begin
      Put_Line ("[rtc] PCF85063A RTC driver demo (SDA=IO8  SCL=IO7  INT=none)");
   end Banner;

   --  One bus step: a left-justified 9-char name (like C "%-9s") + OK/FAIL.
   procedure Step (Name : String; Ok : Boolean) is
   begin
      Put ("[rtc] ");
      Put (Name);
      for J in 1 .. 9 - Name'Length loop Put (' '); end loop;
      Put_Line (" : " & (if Ok then "OK" else "FAIL"));
   end Step;

   procedure No_Device is
   begin
      Put_Line ("[rtc] no PCF85063A ACK at 0x51 -- check wiring/power.");
   end No_Device;

   procedure Alarm (By_Int : Boolean) is
   begin
      Put_Line ("[rtc] *** ALARM fired ***  (detected via "
                & (if By_Int then "INT interrupt" else "I2C poll") & ")");
   end Alarm;

   procedure Done is
   begin
      Put_Line ("[rtc] done.");
   end Done;

   Clock_Dev    : RTC.Device;        --  the RTC chip + its recorded wiring
   Reading      : RTC.Time;          --  the calendar read back from the chip
   Integrity_Ok : Boolean;           --  chip's clock-integrity flag (oscillator
                                     --  did not stop since the last set)
   Result       : RTC.Status;        --  outcome of the last driver call

   --  2026-06-22 is a Monday.
   Initial : constant RTC.Time :=
     (Year   => 2026, Month  => 6, Day    => 22, Day_Of_Week => RTC.Monday,
      Hour   => 14,   Minute => 30, Second => 0);

   --  One calendar reading:  "[rtc] Mon 2026-06-22 14:30:00  (integrity OK)".
   procedure Print (When_T : RTC.Time; Integrity : Boolean) is
   begin
      Put ("[rtc] ");
      Put (Dow (RTC.Weekday'Pos (When_T.Day_Of_Week)));  Put (" ");
      Put_Dec0 (Natural (When_T.Year),   4);  Put ("-");
      Put_Dec0 (Natural (When_T.Month),  2);  Put ("-");
      Put_Dec0 (Natural (When_T.Day),    2);  Put (" ");
      Put_Dec0 (Natural (When_T.Hour),   2);  Put (":");
      Put_Dec0 (Natural (When_T.Minute), 2);  Put (":");
      Put_Dec0 (Natural (When_T.Second), 2);
      Put_Line ("  (integrity " & (if Integrity then "OK" else "LOST") & ")");
   end Print;

begin
   delay until Clock + Milliseconds (200);   --  let the console settle
   Banner;

   --  State the wiring; the device remembers it.  Attach arms the INT interrupt
   --  on the stored pin -- a no-op here since Rtc_Int is No_Pin.
   RTC.Setup (Clock_Dev, Sda => Rtc_Sda, Scl => Rtc_Scl, Int_Pin => Rtc_Int);
   RTC.Interrupts.Attach (Clock_Dev, Alarm_IRQ.Handler'Access);

   --  probe: does the chip ACK its address?
   RTC.Get_Time (Clock_Dev, Reading, Integrity_Ok, Result);
   Step ("probe", Result = RTC.OK);
   if Result /= RTC.OK then
      No_Device;
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   --  reset -> set-time -> read back.
   RTC.Reset (Clock_Dev, Result);
   Step ("reset", Result = RTC.OK);

   RTC.Set_Time (Clock_Dev, Initial, Result);
   Step ("set-time", Result = RTC.OK);

   RTC.Get_Time (Clock_Dev, Reading, Integrity_Ok, Result);
   if Result = RTC.OK then
      Print (Reading, Integrity_Ok);
   end if;

   --  arm a seconds-match alarm 5 s out (the time was just set to :00).
   RTC.Set_Alarm
     (Clock_Dev, (Use_Second => True, Second => 5, others => <>), Result);
   Step ("set-alarm", Result = RTC.OK);

   --  watch the clock tick; stop when the alarm flag latches.
   for Tick in 1 .. 10 loop
      delay until Clock + Seconds (1);

      RTC.Get_Time (Clock_Dev, Reading, Integrity_Ok, Result);
      if Result = RTC.OK then
         Print (Reading, Integrity_Ok);
      end if;

      declare
         Fired : Boolean;
      begin
         RTC.Alarm_Triggered (Clock_Dev, Fired, Result);   --  read AF over I2C
         if Result = RTC.OK and then Fired then
            --  Report how it was detected: the INT ISR latched the flag (a pin
            --  was wired and fired) or the I2C poll above found it.
            Alarm (Alarm_IRQ.Fired);
            RTC.Acknowledge_Alarm (Clock_Dev, Result);       --  release INT
            exit;
         end if;
      end;
   end loop;

   Done;

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
