with ESP32S3.GPIO;

--  The one driver behind every part in the catalogue.  Instantiate it with a
--  Geometry from the parent -- see ESP32S3.EEPROM_24C.M24C64 and its siblings,
--  which is how you should normally reach it:
--
--     package My_Part is new ESP32S3.EEPROM_24C.Driver (M24C64_Part);
--
--  Read and Write take an arbitrary Byte_Array at an arbitrary address, and hide
--  the part's sharp edges: writes split on page boundaries (the part wraps within
--  a page rather than advancing), each page's ~5 ms program cycle is ACK-polled
--  rather than blindly slept, and a read is the datasheet's random read -- word
--  address, repeated START, data -- in one transaction of any length.
--
--  A Read holds the I2C host for the whole transfer; a Write holds it across
--  every page and its program cycle, so a multi-page Write is atomic with respect
--  to other tasks on the bus.
--
--  Note the WC (ST) / WP (everyone else) pin is wiring, not software: HIGH
--  inhibits writes on every part in the family.  Tie it low to allow them.
--
--  Uses the controlled I2C Session (finalization) => embedded / full profiles.

generic
   Part : Geometry;
package ESP32S3.EEPROM_24C.Driver is

   --  The part's geometry, re-exported: a generic formal object is not visible
   --  through the instance, and a caller wants Capacity (say, to address the last
   --  cell) without naming the catalogue entry a second time.
   Capacity      : constant Positive := Part.Capacity_Bytes;
   Page_Size     : constant Positive := Part.Page_Bytes;
   Address_Bytes : constant Positive := Part.Word_Address_Bytes;

   Base_Address : constant ESP32S3.I2C.Slave_Address := Part.Base_Slave_Address;

   --  False for a geometry transcribed from a datasheet but never run against
   --  silicon.  See the catalogue's header.
   Hardware_Verified : constant Boolean := Part.Tested = Verified;

   subtype Memory_Address is Natural range 0 .. Capacity - 1;

   --  Level strapped on a chip-enable pin (tied to VCC or VSS on the board).
   type Pin_State is (Low, High);

   --  Bytes reachable by the word address alone (256 or 65536), and how many such
   --  blocks the array spans.  Blocks > 1 means the part folds log2 (Blocks) high
   --  address bits into its device-select byte, so it answers to that many
   --  consecutive slave addresses -- and each folded bit costs a chip-enable pin.
   Word_Span   : constant Positive := 2 ** (8 * Address_Bytes);
   Blocks      : constant Positive := (Capacity + Word_Span - 1) / Word_Span;
   Max_Devices : constant Positive := 8 / Blocks;

   --  The slave address of block 0 for the given straps.  A part that folds
   --  address bits also answers on the Blocks-1 addresses above this one; the
   --  driver picks the right one per access.
   function Device_Address
     (A0 : Pin_State; A1 : Pin_State; A2 : Pin_State) return ESP32S3.I2C.Slave_Address
   is (Base_Address
       + (if A0 = High then 1 else 0)
       + (if A1 = High then 2 else 0)
       + (if A2 = High then 4 else 0));

   --  Result of a memory operation.  Bus_Error: the part did not ACK (absent,
   --  mis-strapped, or write-protected via WC/WP).  Write_Timeout: it never came
   --  back from an internal program cycle.
   type Status is (OK, Bus_Error, Write_Timeout);

   type Device is limited private;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once per device at startup.
   ----------------------------------------------------------------------------

   --  Record the wiring and the chip-enable straps, then bring the I2C host up.
   --  A0/A1/A2 must match how the pins are tied on the board; all-Low is the
   --  single-chip default.  A strap the part has swallowed for a high address bit
   --  (E0 first) does not exist as a pin, and must be left Low -- the
   --  precondition says so, per instance.  No pin defaults for Sda/Scl.
   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      A0       : Pin_State := Low;
      A1       : Pin_State := Low;
      A2       : Pin_State := Low;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := 400_000)
   with Pre => (if Blocks >= 2 then A0 = Low)
               and then (if Blocks >= 4 then A1 = Low)
               and then (if Blocks >= 8 then A2 = Low);

   --  The 7-bit slave address of Dev's block 0 (see Device_Address).
   function Address (Dev : Device) return ESP32S3.I2C.Slave_Address;

   --  True if the part ACKs an address-only probe: present, powered, strapped as
   --  configured, and not mid-program-cycle.
   function Is_Present (Dev : Device) return Boolean;

   ----------------------------------------------------------------------------
   --  Memory access.
   ----------------------------------------------------------------------------

   --  Read Data'Length bytes starting at From.  A zero-length read is a no-op.
   procedure Read
     (Dev : Device; From : Memory_Address; Data : out ESP32S3.I2C.Byte_Array; Result : out Status)
   with Pre => Data'Length <= Capacity - From;

   --  Write Data at To, splitting on page boundaries and waiting out each program
   --  cycle.  A zero-length write is a no-op.  On Bus_Error or Write_Timeout the
   --  pages before the failure are already committed.
   procedure Write
     (Dev : Device; To : Memory_Address; Data : ESP32S3.I2C.Byte_Array; Result : out Status)
   with Pre => Data'Length <= Capacity - To;

   procedure Read_Byte
     (Dev : Device; From : Memory_Address; Value : out ESP32S3.I2C.Byte; Result : out Status);

   procedure Write_Byte
     (Dev : Device; To : Memory_Address; Value : ESP32S3.I2C.Byte; Result : out Status);

private
   type Device is record
      Host  : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Strap : Natural range 0 .. 7 := 0;   --  E2*4 + E1*2 + E0, as strapped
   end record;

   function Address (Dev : Device) return ESP32S3.I2C.Slave_Address
   is (Base_Address + Dev.Strap);

end ESP32S3.EEPROM_24C.Driver;
