with ESP32S3.GPIO;

--  The one driver behind every part in the I2C FRAM catalogue.  Instantiate it
--  with a Geometry from the parent -- see ESP32S3.FRAM_I2C.MB85RC256V and its
--  siblings, which is how you should normally reach it:
--
--     package My_Ram is new ESP32S3.FRAM_I2C.Driver (MB85RC256V_Part);
--
--  Read and Write take an arbitrary Byte_Array at an arbitrary address.  Because
--  FRAM has no page boundary and no program cycle, a Write is just a word address
--  followed by the whole payload in one bus transaction -- no page splitting, no
--  ACK-polling a write cycle -- and a Read is the datasheet's random read.  The
--  only splitting the driver still does is at a block boundary on the small parts
--  that fold high address bits into the device-select byte.
--
--  A Read or Write holds the I2C host for the whole transfer, so a multi-block
--  transfer is atomic with respect to other tasks on the bus.
--
--  Note the WP pin is wiring, not software: HIGH inhibits writes.  Tie it low to
--  allow them.
--
--  Uses the controlled I2C Session (finalization) => embedded / full profiles.

generic
   Part : Geometry;
package ESP32S3.FRAM_I2C.Driver is

   --  The part's geometry, re-exported (a generic formal object is not visible
   --  through the instance).
   Capacity      : constant Positive := Part.Capacity_Bytes;
   Address_Bytes : constant Positive := Part.Word_Address_Bytes;

   --  The geometry's default bus clock (Setup's Clock_Hz defaults to this).
   Max_Clock     : constant Positive := Part.Max_Clock_Hz;

   Base_Address : constant ESP32S3.I2C.Slave_Address := Part.Base_Slave_Address;

   --  False for a geometry transcribed from a datasheet but never run against
   --  silicon.  See the catalogue's header.
   Hardware_Verified : constant Boolean := Part.Tested = Verified;

   subtype Memory_Address is Natural range 0 .. Capacity - 1;

   --  Level strapped on a chip-enable pin (tied to VCC or VSS on the board).
   type Pin_State is (Low, High);

   --  Bytes reachable by the word address alone (256 or 65536), and how many such
   --  blocks the array spans.  Blocks > 1 means the part folds log2 (Blocks) high
   --  address bits into its device-select byte -- and each folded bit costs a
   --  chip-enable pin.
   Word_Span   : constant Positive := 2 ** (8 * Address_Bytes);
   Blocks      : constant Positive := (Capacity + Word_Span - 1) / Word_Span;
   Max_Devices : constant Positive := 8 / Blocks;

   function Device_Address
     (A0 : Pin_State; A1 : Pin_State; A2 : Pin_State) return ESP32S3.I2C.Slave_Address
   is (Base_Address
       + (if A0 = High then 1 else 0)
       + (if A1 = High then 2 else 0)
       + (if A2 = High then 4 else 0));

   --  Result of a memory operation.  Bus_Error: the part did not ACK (absent,
   --  mis-strapped, or write-protected via WP).
   type Status is (OK, Bus_Error);

   type Device is limited private;

   ----------------------------------------------------------------------------
   --  One-time configuration -- call once per device at startup.
   ----------------------------------------------------------------------------

   --  Record the wiring and the chip-enable straps, then bring the I2C host up.
   --  A0/A1/A2 must match how the pins are tied on the board; all-Low is the
   --  single-chip default.  A strap the part has swallowed for a high address bit
   --  (E0 first) does not exist as a pin, and must be left Low.
   procedure Setup
     (Dev      : out Device;
      Sda      : ESP32S3.GPIO.Pin_Id;
      Scl      : ESP32S3.GPIO.Pin_Id;
      A0       : Pin_State := Low;
      A1       : Pin_State := Low;
      A2       : Pin_State := Low;
      Host     : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Clock_Hz : Positive := Max_Clock)
   with Pre => (if Blocks >= 2 then A0 = Low)
               and then (if Blocks >= 4 then A1 = Low)
               and then (if Blocks >= 8 then A2 = Low);

   --  The 7-bit slave address of Dev's block 0.
   function Address (Dev : Device) return ESP32S3.I2C.Slave_Address;

   --  True if the part ACKs an address-only probe: present, powered, strapped as
   --  configured.  (FRAM has no program cycle, so a probe never NACKs for being
   --  "busy" -- a NACK means absent or mis-strapped.)
   function Is_Present (Dev : Device) return Boolean;

   ----------------------------------------------------------------------------
   --  Memory access.
   ----------------------------------------------------------------------------

   --  Read Data'Length bytes starting at From.  A zero-length read is a no-op.
   procedure Read
     (Dev : Device; From : Memory_Address; Data : out ESP32S3.I2C.Byte_Array; Result : out Status)
   with Pre => Data'Length <= Capacity - From;

   --  Write Data at To.  No page splitting and no write-cycle wait -- FRAM commits
   --  the whole payload as it is clocked in.  A zero-length write is a no-op.  On
   --  Bus_Error the blocks before the failure are already committed.
   procedure Write
     (Dev : Device; To : Memory_Address; Data : ESP32S3.I2C.Byte_Array; Result : out Status)
   with Pre => Data'Length <= Capacity - To;

   procedure Read_Byte
     (Dev : Device; From : Memory_Address; Value : out ESP32S3.I2C.Byte; Result : out Status);

   procedure Write_Byte
     (Dev : Device; To : Memory_Address; Value : ESP32S3.I2C.Byte; Result : out Status);

   ----------------------------------------------------------------------------
   --  Device ID -- the self-report the 24C EEPROMs lack.
   --
   --  The FRAM answers the reserved slave address 0xF8 with a 3-byte identity:
   --  a 12-bit Manufacturer ID (Fujitsu = 0x00A; Cypress/Ramtron = 0x004), a
   --  4-bit Density code, and an 8-bit Product ID.  Use it to confirm the part is
   --  present and is the one you configured.  (The density code's byte mapping is
   --  vendor-specific, so it is returned raw rather than decoded.)
   ----------------------------------------------------------------------------
   type Device_ID is record
      Manufacturer : Natural := 0;   --  12-bit manufacturer code
      Density      : Natural := 0;   --  4-bit density code (vendor-specific)
      Product      : Natural := 0;   --  8-bit product code
   end record;

   Fujitsu_Manufacturer : constant := 16#00A#;
   Cypress_Manufacturer : constant := 16#004#;

   procedure Read_Device_ID (Dev : Device; ID : out Device_ID; Result : out Status);

   --  Classify the responding part by its Device-ID manufacturer code.  This is
   --  INFORMATIONAL only (identify / log): the Device ID is not implemented on most
   --  FRAM parts -- the 4/16/64/128 Kbit MB85RC parts carry none -- so it returns
   --  Unknown for them.  The geometry is fixed at compile time by the chosen
   --  instance; it is not probed or verified.
   type Vendor is (Fujitsu, Cypress, Unknown);
   function Identify (Dev : Device) return Vendor;

private
   type Device is record
      Host  : ESP32S3.I2C.I2C_Host := ESP32S3.I2C.I2C0;
      Strap : Natural range 0 .. 7 := 0;   --  E2*4 + E1*2 + E0, as strapped
   end record;

   function Address (Dev : Device) return ESP32S3.I2C.Slave_Address
   is (Base_Address + Dev.Strap);

end ESP32S3.FRAM_I2C.Driver;
