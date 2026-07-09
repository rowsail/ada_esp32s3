with ESP32S3.I2C;

--  The 24C family of I2C serial EEPROMs (ST M24Cxx, Microchip 24AAxx/24LCxx,
--  Atmel AT24Cxx, onsemi CAT24Cxx) -- the catalogue.
--
--  Every part in the family speaks the same protocol: device-type code 1010, a
--  big-endian word address, page writes that WRAP inside the page instead of
--  advancing, a ~5 ms program cycle that NACKs everything until it finishes, and
--  a random read that writes the word address and turns the bus around on a
--  repeated START.  ESP32S3.EEPROM_24C.Driver implements all of that once.
--
--  A part is therefore nothing but a Geometry, and this package holds them all.
--  Each is instantiated as a child unit -- ESP32S3.EEPROM_24C.M24C64,
--  ESP32S3.EEPROM_24C.M24M01, ... -- so `with`ing one part costs you one part,
--  not the whole catalogue.
--
--     with ESP32S3.EEPROM_24C.M24C64;
--     ...
--     Rom : ESP32S3.EEPROM_24C.M24C64.Device;
--     ESP32S3.EEPROM_24C.M24C64.Setup (Rom, Sda => 41, Scl => 40);
--
--  TESTED vs UNTESTED: only the parts marked Verified below have been exercised
--  against real silicon.  The rest are transcribed from datasheets -- the
--  protocol is shared, so they are very likely right, but nobody has watched them
--  on a scope.  Each instance re-exports its status as Hardware_Verified, and its
--  spec says so in a banner.  Please flip a part to Verified (and say on what
--  board) once you have run it.
--
--  Two traps worth knowing before you add a part:
--
--   * PAGE SIZE VARIES BY VENDOR at the low end.  ST's M24C01/M24C02 have a
--     16-byte page; Atmel's and Microchip's 1K/2K parts have 8.  Guessing wrong
--     does not fail loudly -- the part wraps within the page and silently
--     overwrites what you just wrote.  Hence separate AT24C01 / AT24C02 entries.
--
--   * THE HIGH ADDRESS BITS EAT CHIP-ENABLE PINS.  A part whose array outruns its
--     word address folds the surplus address bits into the LOW bits of its own
--     device-select byte (b1 first, then b2, then b3), so each one costs a strap:
--     E0, then E1, then E2.  A 24C16 folds three (A10..A8) and has no strap left
--     -- only one can sit on a bus.  The Driver derives this from Capacity_Bytes
--     and Word_Address_Bytes; do not encode it here.
--
--     Microchip's 24LC1025 is the family's one part that does NOT follow that
--     rule -- its block bit sits in the HIGH position (1010 B0 A1 A0) rather than
--     the low one, and pin A2 is strapped to Vcc.  The Driver's addressing model
--     cannot express it, so it is deliberately absent below.  Its sibling the
--     24LC1026 (1010 A2 A1 B0) does fit, and is present.

package ESP32S3.EEPROM_24C is

   --  Has this geometry been run against a real part on real hardware?
   type Verification is (Verified, Untested);

   type Geometry is record
      --  Array size in bytes: a power of two, and a whole number of pages.
      Capacity_Bytes : Positive;

      --  Page-write granularity.  A write may not cross this boundary.
      Page_Bytes : Positive;

      --  Word-address bytes the part expects before the data: 1 up to 16 Kbit,
      --  2 from 32 Kbit up.
      Word_Address_Bytes : Positive;

      --  Longest run a sequential read may cross, or 0 for "the whole array".
      --  Only Microchip's 24LC102x need this.
      Max_Read_Span : Natural := 0;

      --  Device-type code 1010 -> 0x50 for the memory array on every part.  (ST's
      --  "-D"/"E" variants put an Identification Page at 1011 -> 0x58.)
      Base_Slave_Address : ESP32S3.I2C.Slave_Address := 16#50#;

      Tested : Verification := Untested;
   end record;

   ---------------------------------------------------------------------------
   --  ST M24Cxx.  Straps: 3 usable up to M24C02, then one lost per folded
   --  address bit (M24C04 -> 2, M24C08 -> 1, M24C16 -> 0), 3 again from M24C32
   --  (two word-address bytes), down to 2 for M24M01 and 1 for M24M02.
   ---------------------------------------------------------------------------

   M24C01_Part : constant Geometry :=
     (Capacity_Bytes => 128, Page_Bytes => 16, Word_Address_Bytes => 1, others => <>);

   M24C02_Part : constant Geometry :=
     (Capacity_Bytes => 256, Page_Bytes => 16, Word_Address_Bytes => 1, others => <>);

   M24C04_Part : constant Geometry :=
     (Capacity_Bytes => 512, Page_Bytes => 16, Word_Address_Bytes => 1, others => <>);

   M24C08_Part : constant Geometry :=
     (Capacity_Bytes => 1_024, Page_Bytes => 16, Word_Address_Bytes => 1, others => <>);

   M24C16_Part : constant Geometry :=
     (Capacity_Bytes => 2_048, Page_Bytes => 16, Word_Address_Bytes => 1, others => <>);

   M24C32_Part : constant Geometry :=
     (Capacity_Bytes => 4_096, Page_Bytes => 32, Word_Address_Bytes => 2, others => <>);

   --  The one part this driver was written against: ST M24C64 on I2C0 of the
   --  esp32s3_m24c64 example board (SDA = IO41, SCL = IO40).
   M24C64_Part : constant Geometry :=
     (Capacity_Bytes     => 8_192,
      Page_Bytes         => 32,
      Word_Address_Bytes => 2,
      Tested             => Verified,
      others             => <>);

   M24128_Part : constant Geometry :=
     (Capacity_Bytes => 16_384, Page_Bytes => 64, Word_Address_Bytes => 2, others => <>);

   M24256_Part : constant Geometry :=
     (Capacity_Bytes => 32_768, Page_Bytes => 64, Word_Address_Bytes => 2, others => <>);

   M24512_Part : constant Geometry :=
     (Capacity_Bytes => 65_536, Page_Bytes => 128, Word_Address_Bytes => 2, others => <>);

   --  A16 folds into the select byte and costs E0: 4 devices per bus.
   M24M01_Part : constant Geometry :=
     (Capacity_Bytes => 131_072, Page_Bytes => 256, Word_Address_Bytes => 2, others => <>);

   --  A17,A16 fold in and cost E0 and E1: 2 devices per bus.
   M24M02_Part : constant Geometry :=
     (Capacity_Bytes => 262_144, Page_Bytes => 256, Word_Address_Bytes => 2, others => <>);

   ---------------------------------------------------------------------------
   --  Atmel / Microchip, where they differ from ST.
   --
   --  Only the 1K and 2K parts need their own entry: an 8-byte page instead of
   --  ST's 16.  From 4K up (24LC04B .. 24LC16B) the geometry matches ST's, so use
   --  the M24Cxx instances above; likewise 24LC32A/64/128/256/512 and AT24Cxx.
   ---------------------------------------------------------------------------

   AT24C01_Part : constant Geometry :=
     (Capacity_Bytes => 128, Page_Bytes => 8, Word_Address_Bytes => 1, others => <>);

   AT24C02_Part : constant Geometry :=
     (Capacity_Bytes => 256, Page_Bytes => 8, Word_Address_Bytes => 1, others => <>);

   --  Microchip 24LC1026: 1 Mbit, but its sequential read cannot cross the
   --  512-Kbit block boundary ("It is not possible to sequentially read across
   --  device boundaries"), so reads are split there.  Its select byte is
   --  1010 A2 A1 B0, which is the family's normal low-position fold.
   --  Its sibling 24LC1025 puts B0 in the HIGH position and is NOT supported.
   LC1026_Part : constant Geometry :=
     (Capacity_Bytes     => 131_072,
      Page_Bytes         => 128,
      Word_Address_Bytes => 2,
      Max_Read_Span      => 65_536,
      others             => <>);

end ESP32S3.EEPROM_24C;
