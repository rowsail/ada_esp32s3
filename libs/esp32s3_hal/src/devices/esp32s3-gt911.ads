with Interfaces;
with ESP32S3.I2C;
with ESP32S3.GPIO;

--  Goodix GT911 5-point capacitive touch controller (I2C).
--
--  Same shape as ESP32S3.QMI8658C: the driver hard-codes no board wiring -- you
--  tell Setup which host and which SDA / SCL (and, optionally, which INT) pins
--  the part is wired to, plus the I2C address, and the Device remembers them.
--  Each operation then opens a short-lived I2C Session (a controlled type) for
--  one complete transaction and lets it release the host automatically on scope
--  exit -- so concurrent callers serialise and a fault between acquire and
--  release can't leak the bus.  Needs the controlled Session => embedded / full
--  profiles only (excluded from light-tasking).
--
--  The GT911 is a 16-bit-register device: every transaction sends the register
--  address MSB-first, then reads or writes a run of bytes from the chip's
--  auto-incrementing pointer.  Multi-byte VALUES inside the map (coordinates,
--  firmware version, output range) are little-endian.
--
--  RESET / ADDRESS.  The chip latches its I2C address from the INT level while
--  RST is released: INT low gives 0x5D (the usual module strapping), INT high
--  gives 0x14.  This driver never drives INT or RST -- many boards route RST
--  through an I/O expander (the Waveshare ESP32-S3-Touch-LCD-7 puts it on a
--  CH422G IO pin, with INT weakly low), so releasing reset is board wiring the
--  caller does once at startup (see ESP32S3.CH422G), before touching the chip.
--
--  REPORTS.  The chip scans the panel continuously and latches one coordinate
--  report per scan cycle: a status register with a buffer-ready flag + point
--  count, then up to 5 track-id/X/Y/size point records.  Read_Touches drains
--  one report and re-arms the latch (writes the flag back to 0).  The INT line
--  pulses on every fresh report -- attach a handler with the .Interrupts child
--  and call Read_Touches from a task it wakes, or simply poll.
--
--  Typical use:
--     declare
--        Touch : ESP32S3.GT911.Device;
--        State : ESP32S3.GT911.Touch_State;
--        St    : ESP32S3.GT911.Status;
--     begin
--        ESP32S3.GT911.Setup (Touch, Sda => 8, Scl => 9, Int_Pin => 4);
--        --  (release the chip's RST line first -- board wiring, see above)
--        loop
--           ESP32S3.GT911.Read_Touches (Touch, State, St);
--           --  State.Fresh: a new report was latched; State.Count points valid
--        end loop;
--     end;

package ESP32S3.GT911 is

   --  7-bit I2C address, latched from the INT level while RST releases:
   --  INT low -> 0x5D (the common module strapping), INT high -> 0x14.
   Address_Int_Low  : constant ESP32S3.I2C.Slave_Address := 16#5D#;
   Address_Int_High : constant ESP32S3.I2C.Slave_Address := 16#14#;

   --  Product ID (registers 0x8140..0x8143) of every GT911: "911" + NUL.
   Product_Id_Value : constant String := '9' & '1' & '1' & Character'Val (0);

   --  The chip tracks at most 5 simultaneous touches.
   Max_Points : constant := 5;

   type Point_Index is range 1 .. Max_Points;
   type Point_Count is range 0 .. Max_Points;

   --  One touch.  X / Y are panel coordinates in the chip's configured output
   --  range (Read_Resolution; pixels on a sanely-configured module).  Id is the
   --  chip's track id -- stable for as long as that finger stays down, so a
   --  two-finger gesture keeps its fingers apart across reports.  Size is the
   --  touch contact area (relative units).
   type Touch_Point is record
      Id   : Interfaces.Unsigned_8 := 0;
      X, Y : Interfaces.Unsigned_16 := 0;
      Size : Interfaces.Unsigned_16 := 0;
   end record;

   type Point_Array is array (Point_Index) of Touch_Point;

   --  One coordinate report.  Fresh distinguishes "the chip latched a NEW
   --  report" (Count and Points valid -- Count = 0 then means all fingers
   --  lifted) from "no new report since the last read" (Count forced to 0;
   --  keep using the previous state).
   type Touch_State is record
      Fresh  : Boolean := False;
      Count  : Point_Count := 0;
      Points : Point_Array := (others => <>);
   end record;

   --  Result of a bus operation.  Bus_Error means the chip did not ACK its
   --  address or a data byte (absent / still in reset / wrong address / stuck
   --  bus).
   type Status is (OK, Bus_Error);

   --  A single GT911.  Limited (non-copyable: it owns the wiring + address it
   --  was set up with).  Holds no finalizable resource itself -- the short-lived
   --  I2C Session each operation opens does the locking and auto-release.
   type Device is limited private;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once at startup (single-threaded).
   ----------------------------------------------------------------------------

   --  Record the wiring + address and bring the bus up: store Host / Address /
   --  Sda / Scl / Int_Pin in Dev, set the I2C host to a master at Clock_Hz, and
   --  route SDA/SCL.  No pin defaults -- the caller states the board wiring.
   --  Int_Pin is the GPIO the chip's INT line is wired to, or No_Pin if none
   --  (arming it is the job of the ESP32S3.GT911.Interrupts child).  Setup does
   --  not touch the chip -- release its RST line (board wiring), then talk.
   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      Int_Pin  : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Address  : ESP32S3.I2C.Slave_Address := Address_Int_Low;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := 400_000);

   --  The INT pin Dev was set up with (No_Pin if none).
   function Interrupt_Pin (Dev : Device) return ESP32S3.GPIO.Optional_Pin;

   ----------------------------------------------------------------------------
   --  Identification.
   ----------------------------------------------------------------------------

   subtype Product_Id is String (1 .. 4);

   --  Read the product ID (0x8140..0x8143).  Id = Product_Id_Value ("911" +
   --  NUL) confirms a GT911 is present and the address is right.
   procedure Read_Product_Id (Dev : Device; Id : out Product_Id; Result : out Status);

   --  Read the firmware version (0x8144, little-endian).
   procedure Read_Firmware_Version
     (Dev : Device; Version : out Interfaces.Unsigned_16; Result : out Status);

   --  Read the configured output range (config 0x8048 / 0x804A): the maximum
   --  X / Y the chip will ever report.  On a factory-configured module this is
   --  the panel size in pixels (800 x 480 on the Waveshare 7-inch).
   procedure Read_Resolution
     (Dev : Device; Width, Height : out Interfaces.Unsigned_16; Result : out Status);

   ----------------------------------------------------------------------------
   --  Touch reports.
   ----------------------------------------------------------------------------

   --  Drain one coordinate report: read the status register; if no new report
   --  is latched, return State.Fresh = False (Count 0) WITHOUT disturbing the
   --  chip.  Otherwise read the latched points, re-arm the latch (write the
   --  buffer flag back to 0), and return them with Fresh = True.  One I2C
   --  Session covers the whole status-read/points-read/re-arm sequence, so
   --  concurrent readers cannot interleave mid-report.
   procedure Read_Touches (Dev : Device; State : out Touch_State; Result : out Status);

private
   type Device is record
      Host    : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Address : ESP32S3.I2C.Slave_Address := Address_Int_Low;
      Sda     : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Scl     : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      Int_Pin : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
   end record;
end ESP32S3.GT911;
