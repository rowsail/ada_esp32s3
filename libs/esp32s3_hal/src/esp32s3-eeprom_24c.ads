with ESP32S3.GPIO;
with ESP32S3.I2C;

--  The 24C family of I2C serial EEPROMs (ST M24Cxx, Microchip 24AAxx/24LCxx,
--  Atmel AT24Cxx, onsemi CAT24Cxx).  Instantiate it for a part; see
--  ESP32S3.M24C64 for the worked example.
--
--  Every part in the family speaks the same protocol -- device-type code 1010, a
--  big-endian word address, page writes that WRAP inside the page instead of
--  advancing, a ~5 ms program cycle that NACKs everything until it finishes, and
--  a random read that writes the word address and turns the bus around on a
--  repeated START.  All of that is handled here, so Read and Write take an
--  arbitrary Byte_Array at an arbitrary address.
--
--  What differs between parts is exactly three things, which is what the generic
--  formals capture:
--
--    * ADDRESS_BYTES -- one word-address byte up to 16 Kbit, two from 32 Kbit up.
--    * PAGE_SIZE     -- 8 (Microchip/Atmel 1K-2K), 16 (ST 1K-2K, all 4K-16K),
--                       32 (32K-64K), 64 (128K-256K), 128 (512K), 256 (1M-2M).
--    * The high memory-address bits that do not fit in the word address, which
--      the part folds into the LOW bits of its own device-select byte, eating a
--      chip-enable pin each (E0 first, then E1, then E2).  A 24C16 folds three
--      (A10..A8) and therefore has NO usable strap: only one can sit on a bus.
--      Derived below as Blocks / Max_Devices -- do not pass it in.
--
--  Sample instantiations (Capacity, Page_Size, Address_Bytes):
--
--     24C02  (2 Kbit)   :  256, ST 16 / Microchip 8, 1      -- 8 devices
--     24C16  (16 Kbit)  : 2048,           16,        1      -- 1 device
--     24C64  (64 Kbit)  : 8192,           32,        2      -- 8 devices
--     24C256 (256 Kbit) : 32768,          64,        2      -- 8 devices
--     M24M01 (1 Mbit)   : 131072,        256,        2      -- 4 devices (A16 eats E0)
--     M24M02 (2 Mbit)   : 262144,        256,        2      -- 2 devices (A17,A16)
--
--  Max_Read_Span exists for the ONE part family that restricts sequential reads:
--  Microchip's 24LC1025/24LC1026 cannot read across their 512-Kbit block
--  boundary ("It is not possible to sequentially read across device
--  boundaries"), so those instantiate with Max_Read_Span => 65_536 and Read
--  splits there.  Everywhere else the read pointer spans the whole array and the
--  default (0 = no limit) is right -- a 24C16 does read straight across its
--  256-byte block boundaries.  Those parts differ in control-byte layout too and
--  are NOT interchangeable with each other; check the datasheet before assuming.
--
--  Note the WC (ST) / WP (everyone else) pin is wiring, not software: HIGH
--  inhibits writes on every part in the family.  Tie it low to allow them.
--
--  Uses the controlled I2C Session (finalization) => embedded / full profiles.

generic
   --  Array size in bytes, a power of two, and a whole number of pages.
   Capacity_Bytes : Positive;

   --  Page-write granularity in bytes.  A write may not cross this boundary.
   Page_Bytes : Positive;

   --  Word-address bytes the part expects before the data: 1 or 2.
   Word_Address_Bytes : Positive;

   --  Device-type code 1010 -> 0x50 for the memory array on every part.  (ST's
   --  "-D"/"E" variants put an Identification Page at 1011 -> 0x58.)
   Base_Slave_Address : ESP32S3.I2C.Slave_Address := 16#50#;

   --  Longest run a sequential read may cross, or 0 for "the whole array".
   Max_Read_Span : Natural := 0;

package ESP32S3.EEPROM_24C is

   --  The formals, re-exported: a generic formal object is not visible through
   --  the instance, and a caller wants the part's geometry (see the demo's
   --  "boot counter in the last cell", Capacity - 1).
   Capacity      : constant Positive := Capacity_Bytes;
   Page_Size     : constant Positive := Page_Bytes;
   Address_Bytes : constant Positive := Word_Address_Bytes;

   Base_Address : constant ESP32S3.I2C.Slave_Address := Base_Slave_Address;

   subtype Memory_Address is Natural range 0 .. Capacity - 1;

   --  Level strapped on a chip-enable pin (tied to VCC or VSS on the board).
   type Pin_State is (Low, High);

   --  Bytes reachable by the word address alone (256 or 65536), and how many such
   --  blocks the array spans.  Blocks > 1 means the part folds log2(Blocks) high
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

end ESP32S3.EEPROM_24C;
