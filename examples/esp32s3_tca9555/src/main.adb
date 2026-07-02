--  What it demonstrates
--  ---------------------
--  The reusable HAL driver ESP32S3.TCA9555 -- a 16-bit I2C GPIO expander --
--  driven against a real part at 0x20 on the bare-metal ESP32-S3 (no FreeRTOS,
--  no IDF).  It holds ONE Session for the whole test, so the expander is
--  protected against other tasks the entire time, while each register read /
--  write below locks the I2C host only for its own transaction and frees it
--  again (the two-level locking this driver is built around).
--
--  This board's expander pins are wired to external circuitry (the input port
--  reads a fixed pattern), so the demo deliberately NEVER drives a pin: it
--  leaves every pin an input and proves the driver another way --
--    probe     read the input port (comms check; shows the external levels).
--    out-reg   write the output REGISTER and read it back (it stores the value
--              even while the pins stay inputs, so nothing is driven).
--    pin       per-pin read-modify-write of the output register (the RMW path
--              the held Session protects).
--    pol-reg   write the polarity-inversion register and read it back.
--  To actually drive outputs (e.g. LEDs on free pins), call Set_Directions to
--  make them outputs and Write_Port / Write_Pin -- omitted here on purpose.
--  (Note: on this board's part the polarity register accepts writes but the chip
--  does not actually invert the input -- a quirk of the part, not the driver.)
--
--  Build & run
--  -----------
--    ./x run esp32s3_tca9555
--  Needs the embedded profile (the controlled Session uses finalization);
--  build.sh sets ESP32S3_RTS_PROFILE=embedded.
--
--  Output
--  ------
--  One report line per step; "PASS" on every round-trip is the good outcome:
--    [gpio] TCA9555 16-bit I2C GPIO expander demo (0x20, SDA=IO8 SCL=IO7)
--    [gpio] probe   : inputs=0xff77  (present)
--    [gpio] out-reg : wrote=0xa55a read=0xa55a  PASS
--    [gpio] out-reg : wrote=0x5aa5 read=0x5aa5  PASS
--    [gpio] pin 5   : set=1  out-bit=1  PASS
--    [gpio] pin 5   : set=0  out-bit=0  PASS
--    [gpio] pol-reg : wrote=0xa55a read=0xa55a  PASS
--    [gpio] done.
--  The "(no ACK!)" / "check wiring/power" line appears only if the part does
--  not answer on the bus.  Report goes through ESP32S3.Log; the Ada driver does
--  all the I2C work.
--
--  Hardware
--  --------
--  A TCA9555 on I2C0 at address 0x20 (A2/A1/A0 strapped to ground):
--    SDA -> IO8,  SCL -> IO7.
--  The expander's own 16 IO pins stay inputs here (the demo never drives them);
--  on this board they read the fixed external pattern 0xff77.  Wire LEDs to free
--  expander pins and call Set_Directions + Write_Pin to light them.
with Interfaces;    use Interfaces;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.Log; use ESP32S3.Log;
with ESP32S3.TCA9555;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package TCA9555 renames ESP32S3.TCA9555;
   use type TCA9555.Status;
   use type TCA9555.Port_Value;

   --  Wiring + strap (see the header).  Addr is the A2/A1/A0 strap value 0..7,
   --  which the part maps to bus address 0x20 + Addr -- here 0 -> 0x20.
   Strap_Address    : constant := 0;
   Serial_Data_Pin  : constant := 8;    --  SDA -> IO8
   Serial_Clock_Pin : constant := 7;    --  SCL -> IO7

   --  Set_Directions takes a 1 bit = input mask; all-ones makes every pin an
   --  input -- a known, non-driving state so nothing fights the external wiring.
   All_Pins_Input : constant TCA9555.Port_Value := 16#FFFF#;

   --  Bit mask for the single pin the per-pin RMW step toggles (pin 5).
   Toggle_Pin      : constant TCA9555.Pin_Number := 5;
   Toggle_Pin_Mask : constant TCA9555.Port_Value := 2**5;

   --  Polarity-inversion register value written then read back (an arbitrary
   --  walking pattern); the step restores 0 (normal polarity) afterwards.
   Polarity_Pattern : constant TCA9555.Port_Value := 16#A55A#;
   Polarity_Normal  : constant TCA9555.Port_Value := 0;

   --  Two output-register patterns written + read back, one per round-trip.
   Output_Patterns : constant array (1 .. 2) of TCA9555.Port_Value := (16#A55A#, 16#5AA5#);

   --  Low 16 bits of a port value as an Unsigned_32, for the "0x%04x" hex
   --  output (Put_Hex takes an Unsigned_32).
   function Low_16_Bits (Value : TCA9555.Port_Value) return Unsigned_32
   is (Unsigned_32 (Value) and 16#FFFF#);

   --  "[gpio] probe   : inputs=0x%04x  %s" (ok ? "(present)" : "(no ACK!)").
   procedure Report_Probe (Inputs : TCA9555.Port_Value; Present : Boolean) is
   begin
      Put ("[gpio] probe   : inputs=0x");
      Put_Hex (Low_16_Bits (Inputs), 4);
      Put ("  ");
      Put_Line (if Present then "(present)" else "(no ACK!)");
   end Report_Probe;

   --  "[gpio] %-7s : wrote=0x%04x read=0x%04x  %s" for out-reg / pol-reg
   --  (Name is "out-reg" or "pol-reg", both 7 chars so no padding is needed).
   procedure Report_Register (Name : String; Wrote, Read_Back : TCA9555.Port_Value; Pass : Boolean)
   is
   begin
      Put ("[gpio] ");
      Put (Name);
      Put (" : wrote=0x");
      Put_Hex (Low_16_Bits (Wrote), 4);
      Put (" read=0x");
      Put_Hex (Low_16_Bits (Read_Back), 4);
      Put ("  ");
      Put_Line (if Pass then "PASS" else "FAIL");
   end Report_Register;

   --  "[gpio] pin %-2d  : set=%d  out-bit=%d  %s" (pin left-justified to width
   --  2, so a single-digit pin gets one trailing space).
   procedure Report_Pin (Pin, Set_Value, Output_Bit : Integer; Pass : Boolean) is
   begin
      Put ("[gpio] pin ");
      Put (Pin);
      if Pin in 0 .. 9 then
         Put (" ");
      end if;
      Put ("  : set=");
      Put (Set_Value);
      Put ("  out-bit=");
      Put (Output_Bit);
      Put ("  ");
      Put_Line (if Pass then "PASS" else "FAIL");
   end Report_Pin;

   Expander         : TCA9555.Device;
   Expander_Session : TCA9555.Session;
   Expander_Status  : TCA9555.Status;
   Read_Value       : TCA9555.Port_Value;
   Input_Levels     : TCA9555.Port_Value;

   --  Let the console FIFO drain between report lines.
   procedure Drain_Console is
   begin
      delay until Clock + Milliseconds (30);
   end Drain_Console;

begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[gpio] TCA9555 16-bit I2C GPIO expander demo " & "(0x20, SDA=IO8 SCL=IO7)");

   TCA9555.Setup
     (Expander, Addr => Strap_Address, Sda => Serial_Data_Pin, Scl => Serial_Clock_Pin);
   TCA9555.Acquire (Expander_Session, Expander);   --  hold the expander for the test

   --  Force every pin to an input -- a known, non-driving state (independent of
   --  whatever the registers held before) so nothing fights the external wiring.
   TCA9555.Set_Directions (Expander_Session, Inputs => All_Pins_Input, Result => Expander_Status);

   --  probe: read the input port.
   TCA9555.Read_Port (Expander_Session, Input_Levels, Expander_Status);
   Drain_Console;
   Report_Probe (Input_Levels, Expander_Status = TCA9555.OK);
   if Expander_Status /= TCA9555.OK then
      Put_Line ("[gpio] no TCA9555 found at 0x20 -- check wiring/power.");
      loop
         delay until Clock + Seconds (3600);
      end loop;
   end if;

   --  out-reg round-trip: write the output register, read it back.  Pins stay
   --  inputs, so nothing is driven -- this checks the write + read path only.
   for Pattern of Output_Patterns loop
      TCA9555.Write_Port (Expander_Session, Pattern, Expander_Status);
      if Expander_Status = TCA9555.OK then
         TCA9555.Read_Outputs (Expander_Session, Read_Value, Expander_Status);
      end if;
      Drain_Console;
      Report_Register
        ("out-reg",
         Pattern,
         Read_Value,
         Expander_Status = TCA9555.OK and then Read_Value = Pattern);
   end loop;

   --  per-pin RMW of the output register: drive the bit high, read it back.
   TCA9555.Write_Pin (Expander_Session, Toggle_Pin, TCA9555.High, Expander_Status);
   TCA9555.Read_Outputs (Expander_Session, Read_Value, Expander_Status);
   Drain_Console;
   Report_Pin
     (Integer (Toggle_Pin),
      1,
      Boolean'Pos ((Read_Value and Toggle_Pin_Mask) /= 0),
      Expander_Status = TCA9555.OK and then (Read_Value and Toggle_Pin_Mask) /= 0);

   TCA9555.Write_Pin (Expander_Session, Toggle_Pin, TCA9555.Low, Expander_Status);
   TCA9555.Read_Outputs (Expander_Session, Read_Value, Expander_Status);
   Drain_Console;
   Report_Pin
     (Integer (Toggle_Pin),
      0,
      Boolean'Pos ((Read_Value and Toggle_Pin_Mask) /= 0),
      Expander_Status = TCA9555.OK and then (Read_Value and Toggle_Pin_Mask) = 0);

   --  polarity-inversion register round-trip (write then read back).
   TCA9555.Set_Polarity (Expander_Session, Polarity_Pattern, Expander_Status);
   if Expander_Status = TCA9555.OK then
      TCA9555.Read_Polarity (Expander_Session, Read_Value, Expander_Status);
   end if;
   Drain_Console;
   Report_Register
     ("pol-reg",
      Polarity_Pattern,
      Read_Value,
      Expander_Status = TCA9555.OK and then Read_Value = Polarity_Pattern);
   TCA9555.Set_Polarity
     (Expander_Session, Polarity_Normal, Expander_Status);   --  restore normal polarity

   TCA9555.Release (Expander_Session);
   Drain_Console;
   Put_Line ("[gpio] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
