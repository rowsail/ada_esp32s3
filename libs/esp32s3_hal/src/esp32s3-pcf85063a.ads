with ESP32S3.I2C;
with ESP32S3.GPIO;

--  NXP PCF85063A / PCF85063TP I2C real-time clock + calendar driver.
--
--  A small, fixed-address (0x51) RTC: seconds .. years in BCD, a programmable
--  alarm (second / minute / hour / day / weekday, any subset), an oscillator-
--  stop flag that reports whether time was kept across a power loss, and an
--  active-low open-drain INT line (the alarm asserts it).  Up to 400 kHz I2C.
--
--  This layers the chip's register protocol over the task-safe ESP32S3.I2C
--  master.  The driver hard-codes NO board wiring: you tell Setup which host and
--  which SDA / SCL (and, optionally, which INT) pins the part is wired to, and
--  the Device remembers them.  Each operation then opens a short-lived I2C
--  Session (a controlled type) for one complete transaction and lets it release
--  the host automatically on scope exit -- so concurrent callers serialise and a
--  fault between acquire and release can't leak the bus.  Needs the controlled
--  Session => embedded / full profiles only (excluded from light-tasking, like
--  the other Session drivers).
--
--  Register reads use the chip's auto-incrementing address pointer: a 1-byte
--  write sets the pointer, a following read streams from it (the pointer
--  survives the STOP between the two transactions).
--
--  Typical use:
--     declare
--        RTC : ESP32S3.PCF85063A.Device;
--        T   : ESP32S3.PCF85063A.Time;
--        Ok  : Boolean;
--        St  : ESP32S3.PCF85063A.Status;
--     begin
--        --  state the wiring once -- here SDA = IO8, SCL = IO7, no INT line.
--        ESP32S3.PCF85063A.Setup (RTC, Sda => 8, Scl => 7);
--        ESP32S3.PCF85063A.Set_Time (RTC, (Year => 2026, Month => 6, Day => 22,
--           Day_Of_Week => ESP32S3.PCF85063A.Monday,
--           Hour => 14, Minute => 30, Second => 0), St);
--        ESP32S3.PCF85063A.Get_Time (RTC, T, Ok, St);   --  Ok = clock integrity
--     end;

package ESP32S3.PCF85063A is

   --  The PCF85063A has ONE fixed 7-bit bus address (no address pins).
   Bus_Address : constant ESP32S3.I2C.Slave_Address := 16#51#;

   ----------------------------------------------------------------------------
   --  The calendar value the chip stores (BCD on the wire; binary here).
   ----------------------------------------------------------------------------

   --  The chip keeps a 2-digit year (00..99); this driver anchors it to 2000.
   subtype Year_Number is Natural range 2000 .. 2099;
   subtype Month_Number is Natural range 1 .. 12;
   subtype Day_Number is Natural range 1 .. 31;
   subtype Hour_Number is Natural range 0 .. 23;   --  24-hour mode only
   subtype Minute_Number is Natural range 0 .. 59;
   subtype Second_Number is Natural range 0 .. 59;

   --  Day-of-week is just a free 0..6 counter in the chip; this naming is the
   --  driver's own convention (0 = Sunday) -- the hardware does not interpret it.
   type Weekday is
     (Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday);

   type Time is record
      Year        : Year_Number := 2000;
      Month       : Month_Number := 1;
      Day         : Day_Number := 1;
      Day_Of_Week : Weekday := Sunday;
      Hour        : Hour_Number := 0;
      Minute      : Minute_Number := 0;
      Second      : Second_Number := 0;
   end record;

   --  Result of a bus operation.  Bus_Error means the chip did not ACK its
   --  address or a data byte (absent device, wrong wiring, or a stuck bus).
   type Status is (OK, Bus_Error);

   --  A single PCF85063A.  Limited (non-copyable: it owns the wiring it was set
   --  up with).  Holds no finalizable resource itself -- the short-lived I2C
   --  Session each operation opens does the locking and auto-release.
   type Device is limited private;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once at startup (single-threaded), before
   --  any task contends for the device.
   ----------------------------------------------------------------------------

   --  Record the wiring and bring the bus up: store Host / Sda / Scl / Int_Pin
   --  in Dev, set the I2C host to a master at Clock_Hz, and route SDA/SCL.  No
   --  pin defaults -- the caller states the board wiring.  Int_Pin is the GPIO
   --  the active-low INT line is wired to, or No_Pin if there is none; arming the
   --  interrupt is the job of the ESP32S3.PCF85063A.Interrupts child, which reads
   --  the pin stored here.  Setup does not touch the chip -- call Reset for a
   --  known register state.
   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Int_Pin  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := 400_000);

   --  The INT pin Dev was set up with (No_Pin if none).
   function Interrupt_Pin (Dev : Device) return ESP32S3.GPIO.Optional_Pin;

   ----------------------------------------------------------------------------
   --  Time of day.
   ----------------------------------------------------------------------------

   --  Read the current calendar.  Valid is True iff the oscillator-stop (OS)
   --  flag is clear -- i.e. the clock has run continuously since the last
   --  Set_Time and the value is trustworthy.  Valid = False means power was lost
   --  (set the time afresh).  On Bus_Error, T is unchanged from its defaults.
   procedure Get_Time
     (Dev : Device; T : out Time; Valid : out Boolean; Result : out Status);

   --  Load the calendar.  Stops the clock around the write (datasheet 8.1) and
   --  restarts it -- all under one bus session -- and writing the seconds
   --  register also clears the OS flag, so a successful Set_Time marks the time
   --  as valid.
   procedure Set_Time (Dev : Device; T : Time; Result : out Status);

   --  Software reset: returns every register to its power-on default (stops the
   --  clock, clears alarms, sets OS).  Follow with Set_Time.
   procedure Reset (Dev : Device; Result : out Status);

   --  Halt / resume the time counters (the Control_1 STOP bit) without changing
   --  the loaded value.  Set_Time already brackets its write with these.
   procedure Stop_Clock (Dev : Device; Result : out Status);
   procedure Start_Clock (Dev : Device; Result : out Status);

   ----------------------------------------------------------------------------
   --  Alarm.  Any subset of the five fields can participate: only the enabled
   --  ones must match for the alarm to fire.  With none enabled the alarm never
   --  fires.  When it fires, the alarm flag (AF) latches and, with the interrupt
   --  enabled, the INT pin is pulled low until AF is cleared.
   ----------------------------------------------------------------------------

   type Alarm is record
      Use_Second  : Boolean := False;
      Second      : Second_Number := 0;
      Use_Minute  : Boolean := False;
      Minute      : Minute_Number := 0;
      Use_Hour    : Boolean := False;
      Hour        : Hour_Number := 0;
      Use_Day     : Boolean := False;
      Day         : Day_Number := 1;
      Use_Weekday : Boolean := False;
      Day_Of_Week : Weekday := Sunday;
   end record;

   --  Program the alarm match, enable the alarm interrupt (so INT asserts on a
   --  match), and clear any stale alarm flag.
   procedure Set_Alarm (Dev : Device; A : Alarm; Result : out Status);

   --  True iff the alarm flag is currently latched (the alarm has fired).
   procedure Alarm_Triggered
     (Dev : Device; Fired : out Boolean; Result : out Status);

   --  Clear the latched alarm flag (releases INT) but leave the alarm armed.
   --  Call this from the task woken by the INT interrupt.
   procedure Acknowledge_Alarm (Dev : Device; Result : out Status);

   --  Disarm completely: disable the interrupt, clear the flag, and disable all
   --  five match fields.
   procedure Clear_Alarm (Dev : Device; Result : out Status);

private
   type Device is record
      Host    : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Sda     : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Scl     : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Int_Pin : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
   end record;
end ESP32S3.PCF85063A;
