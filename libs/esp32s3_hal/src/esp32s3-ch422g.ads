with Ada.Finalization;
with ESP32S3.I2C;
with ESP32S3.GPIO;

--  WCH CH422G I2C I/O expander: 8 bidirectional pins (IO0..IO7) + 4 output-only
--  pins (OC0..OC3).  Same two-level-locking shape as ESP32S3.TCA9555 -- acquire
--  the device like the RTC, while the I2C host is locked only for each
--  transaction -- but the chip itself is quite different:
--
--    * It is NOT a register-pointer device.  Each operation is a single-byte
--      transaction to a FIXED, function-specific I2C address: 0x24 set system
--      config (WR-SET), 0x23 write OC outputs (WR-OC), 0x38 write IO outputs
--      (WR-IO), 0x26 read IO inputs (RD-IO).  So there is one CH422G per bus and
--      no address straps -- Setup takes no address.
--    * IO direction is GLOBAL: one IO_OE bit makes ALL of IO0..IO7 inputs or ALL
--      outputs (no per-pin direction).  OC0..OC3 are output-only, globally
--      push-pull or open-drain (OD_EN).
--    * The config / OC / IO-output registers cannot be read back (only the IO
--      pins read back, via RD-IO), so the driver keeps a shadow of them,
--      initialised to the datasheet power-on defaults (IO = inputs, OC = high,
--      push-pull).
--    * The chip has NO interrupt output -> no .Interrupts child.
--
--  Uses a controlled Session (finalization) => embedded / full profiles only.
package ESP32S3.CH422G is

   --  IO0..IO7 as one byte (bit i = IOi); OC0..OC3 as the low nibble.
   type IO_Value is mod 2 ** 8;
   type OC_Value is mod 2 ** 4;

   type IO_Pin is range 0 .. 7;
   type OC_Pin is range 0 .. 3;

   type Pin_State is (Low, High);

   --  GLOBAL settings (the chip has no per-pin direction / drive).
   type IO_Direction is (Inputs, Outputs);     --  all of IO0..IO7
   type OC_Drive     is (Push_Pull, Open_Drain);  --  all of OC0..OC3

   --  Bus_Error: the chip did not ACK (absent / wrong bus / stuck).
   type Status is (OK, Bus_Error);

   type Device  is limited private;
   type Session is limited private;

   --  Raised by Acquire on an un-Setup Device; by an operation whose Session
   --  does not currently hold the device.
   Not_Initialized : exception;
   Not_Owned       : exception;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once at startup (single-threaded).  Records
   --  the wiring and brings the I2C host up; does NOT touch the chip (it powers
   --  up as IO-inputs / OC-high / I/O-expansion).  No address -- the CH422G uses
   --  fixed command addresses.
   ----------------------------------------------------------------------------
   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive             := 400_000);

   ----------------------------------------------------------------------------
   --  Take / release exclusive ownership of the device.
   ----------------------------------------------------------------------------
   procedure Acquire (S : in out Session; Dev : Device);
   procedure Release (S : in out Session);

   --  Address-only probe of the config command address: True iff the chip ACKs.
   function Present (S : Session) return Boolean;

   ----------------------------------------------------------------------------
   --  Operations -- each takes the held Session and locks the I2C host only for
   --  its own transaction.  Raise Not_Owned unless S currently holds the device.
   ----------------------------------------------------------------------------

   --  System config (WR-SET): IO direction (all 8) + OC drive (all 4).  Keeps
   --  the current sleep state; holds A_SCAN = 0 (I/O-expansion mode).  Does not
   --  change any pin's output value.
   procedure Configure
     (S       : Session;
      IO_Dir  : IO_Direction := Inputs;
      OC_Mode : OC_Drive     := Push_Pull;
      Result  : out Status);

   --  Low-power sleep (woken by an IO level change or the next command).
   procedure Sleep (S : Session; On : Boolean; Result : out Status);

   --  IO0..IO7 outputs (WR-IO) -- effective only after Configure (Outputs).
   procedure Write_IO (S : Session; Value : IO_Value; Result : out Status);
   procedure Write_IO_Pin
     (S : Session; Pin : IO_Pin; State : Pin_State; Result : out Status);

   --  IO0..IO7 current pin state (RD-IO).
   procedure Read_IO (S : Session; Value : out IO_Value; Result : out Status);
   procedure Read_IO_Pin
     (S : Session; Pin : IO_Pin; State : out Pin_State; Result : out Status);

   --  OC0..OC3 outputs (WR-OC).  1 = high (push-pull) / not-driven (open-drain),
   --  0 = low.
   procedure Write_OC (S : Session; Value : OC_Value; Result : out Status);
   procedure Write_OC_Pin
     (S : Session; Pin : OC_Pin; State : Pin_State; Result : out Status);

private
   type Device is record
      Host       : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Configured : Boolean              := False;
   end record;

   type Session is new Ada.Finalization.Limited_Controlled with record
      Active : Boolean              := False;
      Host   : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
   end record;
   overriding procedure Finalize (S : in out Session);  --  auto-release
end ESP32S3.CH422G;
