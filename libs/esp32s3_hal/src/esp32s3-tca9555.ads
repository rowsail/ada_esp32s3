with Interfaces;
with Ada.Finalization;
with ESP32S3.I2C;
with ESP32S3.GPIO;

--  Texas Instruments TCA9555 16-bit I2C GPIO expander driver.
--
--  Two 8-bit ports (P0 = pins 0..7, P1 = pins 8..15).  The 7-bit address is
--  0x20 + the A2/A1/A0 strap value, so up to 8 parts share one bus.
--
--  Locking -- TWO levels, which is the point of this driver:
--    * A Session is an exclusive, RAII hold on ONE expander (acquire it like the
--      RTC's host).  Hold it across as many operations as you like; it keeps
--      other tasks off THAT chip (so a per-pin read-modify-write is safe) while
--      it is held.  Two Sessions for the same physical chip (same host+address)
--      serialise; different chips do not.
--    * The I2C HOST is locked only INSIDE each read / write, then released -- so
--      while you hold an expander's Session the bus is free between your
--      transactions, and another task can drive a different chip (or the RTC /
--      IMU / SHT41) in the gaps.
--
--  The per-device locks are a fixed library-level array keyed by (host, strap
--  value) -- the same shape as ESP32S3.I2C's per-host guards -- so no protected
--  object lives in a Device (which would be a forbidden local PO).
--
--  Uses controlled Sessions (finalization) => embedded / full profiles only.
--
--  Typical use:
--     declare
--        Exp : ESP32S3.TCA9555.Device;
--        S   : ESP32S3.TCA9555.Session;
--        St  : ESP32S3.TCA9555.Status;
--        V   : ESP32S3.TCA9555.Port_Value;
--     begin
--        ESP32S3.TCA9555.Setup (Exp, Addr => 0, Sda => 8, Scl => 7);
--        ESP32S3.TCA9555.Acquire (S, Exp);                  --  protect this chip
--        ESP32S3.TCA9555.Set_Directions (S, Inputs => 16#FF00#, Result => St);
--        ESP32S3.TCA9555.Write_Port (S, 16#00A5#, St);      --  bus free between
--        ESP32S3.TCA9555.Read_Port  (S, V, St);             --  these two
--     end;                                                  --  Session auto-released
package ESP32S3.TCA9555 is

   --  Base address and the A2/A1/A0 strap value (0 .. 7) -> 0x20 .. 0x27.
   Base_Address : constant ESP32S3.I2C.Slave_Address := 16#20#;
   subtype Hardware_Address is Natural range 0 .. 7;

   --  16 I/O pins: 0 .. 7 = Port 0, 8 .. 15 = Port 1.
   type Pin_Number is range 0 .. 15;

   --  A whole-expander value: bit i corresponds to Pin_Number i.
   type Port_Value is mod 2 ** 16;

   type Direction is (Output, Input);
   type Pin_State is (Low, High);

   --  Result of a bus operation.  Bus_Error: the expander did not ACK.
   type Status is (OK, Bus_Error);

   --  A configured expander (host + address).  Holds no lock itself.
   type Device is limited private;

   --  An exclusive, RAII hold on one expander.  Limited + controlled: releases
   --  the device on scope exit (including on exception), like the RTC Session.
   type Session is limited private;

   --  Raised by Acquire if the Device was never Setup.
   Not_Initialized : exception;
   --  Raised by an operation whose Session does not currently hold a device.
   Not_Owned : exception;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once per device at startup.
   ----------------------------------------------------------------------------

   --  Record the wiring + strap address (Addr 0..7 -> 0x20+Addr) and bring the
   --  I2C host up.  Int_Pin is the GPIO the active-low INT output is wired to, or
   --  No_Pin (this board: not connected); arming it is the job of the
   --  ESP32S3.TCA9555.Interrupts child.  No pin defaults for Sda/Scl.
   procedure Setup
     (Dev      : out Device;
      Addr     : Hardware_Address;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Int_Pin  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Host     : ESP32S3.I2C.I2C_Host      := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive                  := 400_000);

   --  The INT pin Dev was set up with (No_Pin if none).
   function Interrupt_Pin (Dev : Device) return ESP32S3.GPIO.Optional_Pin;

   ----------------------------------------------------------------------------
   --  Take / release exclusive ownership of the expander.
   ----------------------------------------------------------------------------

   --  Suspend until no other Session holds this device, then own it.  Raises
   --  Not_Initialized if Dev was never Setup.
   procedure Acquire (S : in out Session; Dev : Device);

   --  Hand the device back early (idempotent; also happens on scope exit).
   procedure Release (S : in out Session);

   ----------------------------------------------------------------------------
   --  Operations -- each takes the held Session and locks the I2C host only for
   --  its own transaction(s).  Raise Not_Owned unless S currently holds a device.
   ----------------------------------------------------------------------------

   --  Pin direction.  In Inputs, a 1 bit makes that pin an input (the chip's
   --  power-on default), a 0 bit an output.  One transaction.
   procedure Set_Directions
     (S : Session; Inputs : Port_Value; Result : out Status);
   procedure Set_Direction
     (S : Session; Pin : Pin_Number; Dir : Direction; Result : out Status);

   --  Drive the output register.  Write_Pin is a read-modify-write (two bus
   --  transactions, safe because the Session is held).
   procedure Write_Port (S : Session; Value : Port_Value; Result : out Status);
   procedure Write_Pin
     (S : Session; Pin : Pin_Number; State : Pin_State; Result : out Status);

   --  Read back the direction (config) and output registers (what was last set).
   procedure Read_Directions
     (S : Session; Inputs : out Port_Value; Result : out Status);
   procedure Read_Outputs
     (S : Session; Value : out Port_Value; Result : out Status);
   procedure Read_Polarity
     (S : Session; Inverted : out Port_Value; Result : out Status);

   --  Sample the input register (the actual pin levels, including driven outputs).
   procedure Read_Port (S : Session; Value : out Port_Value; Result : out Status);
   procedure Read_Pin
     (S : Session; Pin : Pin_Number; State : out Pin_State; Result : out Status);

   --  Input polarity inversion: a 1 bit inverts that input's reported level.
   procedure Set_Polarity
     (S : Session; Inverted : Port_Value; Result : out Status);

private
   type Device is record
      Host       : ESP32S3.I2C.I2C_Host      := ESP32S3.I2C.I2C0;
      Addr       : Hardware_Address          := 0;
      Address    : ESP32S3.I2C.Slave_Address := Base_Address;
      Int_Pin    : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Configured : Boolean                   := False;
   end record;

   type Session is new Ada.Finalization.Limited_Controlled with record
      Active  : Boolean                   := False;
      Host    : ESP32S3.I2C.I2C_Host      := ESP32S3.I2C.I2C0;
      Addr    : Hardware_Address          := 0;
      Address : ESP32S3.I2C.Slave_Address := Base_Address;
   end record;
   overriding procedure Finalize (S : in out Session);  --  auto-release the device
end ESP32S3.TCA9555;
