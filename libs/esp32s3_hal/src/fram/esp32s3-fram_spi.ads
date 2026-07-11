with Interfaces;

--  The SPI FRAM families -- Fujitsu MB85RS, Cypress/Infineon FM25 -- the
--  catalogue.  Like the I2C FRAM, these are non-volatile RAM: byte-writable, no
--  page boundary, and NO program cycle (a WRITE is committed as it is clocked in).
--  They speak the standard SPI-memory command set: WREN (0x06) before a write,
--  WRITE (0x02) and READ (0x03) with a big-endian address, and RDID (0x9F) for a
--  JEDEC-style identity.
--
--  The SPI read/write protocol is IDENTICAL across manufacturers, so parts are
--  keyed here by DENSITY, not by part number:
--
--     with ESP32S3.FRAM_SPI.Kbit_256;
--     ...
--     Ram : ESP32S3.FRAM_SPI.Kbit_256.Device;
--     ESP32S3.FRAM_SPI.Kbit_256.Setup (Ram, Sclk => 1, Mosi => 4, Miso => 45,
--                                       CS_Pin => 12);
--
--  Which part maps to which density (each instance's banner lists its parts):
--    Kbit_4    FM25040B | FM25L04B
--    Kbit_16   MB85RS16
--    Kbit_64   MB85RS64 | FM25CL64B
--    Kbit_128  MB85RS128B | FM25V01
--    Kbit_256  MB85RS256B | FM25V02A | FM25W256
--    Kbit_512  FM25V05
--    Mbit_1    FM25V10
--    Mbit_2    MB85RS2MT | FM25V20
--    Mbit_4    MB85RS4MT
--  The I2C FRAM parts (MB85RC*, FM24*) are ESP32S3.FRAM_I2C.  The parallel-bus
--  parts are not supported (no parallel memory bus on this board).
--
--  Only the memory READ/WRITE is manufacturer-independent; the RDID reply length
--  and layout differ by vendor (Driver.Read_Device_ID returns the raw bytes).
--
--  Address-width note: 16 Kbit .. 512 Kbit use two address bytes; 1 Mbit uses
--  three; the 4 Kbit parts use ONE address byte with the ninth address bit (A8)
--  carried in bit 3 of the opcode (the legacy 25040 convention, Opcode_High_Bit).
--
--  STATUS: none run against real silicon yet.  Datasheet-derived.

package ESP32S3.FRAM_SPI is

   type Byte_Array is array (Natural range <>) of Interfaces.Unsigned_8;

   type Verification is (Verified, Untested);

   type Geometry is record
      --  Array size in bytes: a power of two.
      Capacity_Bytes : Positive;

      --  Address bytes in a READ/WRITE frame: 1, 2, or 3.
      Address_Bytes : Positive;

      --  4 Kbit legacy style: one address byte, A8 in bit 3 of the opcode.
      Opcode_High_Bit : Boolean := False;

      --  Bit clock the driver uses by default (Setup can override).  20 MHz is safe
      --  across the SPI FRAM family; many parts run to 40 MHz.
      Max_Clock_Hz : Positive := 20_000_000;

      Tested : Verification := Untested;
   end record;

   --  One entry per unique density (= geometry).
   Kbit_4_Part   : constant Geometry :=
     (Capacity_Bytes => 512,     Address_Bytes => 1, Opcode_High_Bit => True, others => <>);
   Kbit_16_Part  : constant Geometry :=
     (Capacity_Bytes => 2_048,   Address_Bytes => 2, others => <>);
   Kbit_64_Part  : constant Geometry :=
     (Capacity_Bytes => 8_192,   Address_Bytes => 2, others => <>);
   Kbit_128_Part : constant Geometry :=
     (Capacity_Bytes => 16_384,  Address_Bytes => 2, others => <>);
   Kbit_256_Part : constant Geometry :=
     (Capacity_Bytes => 32_768,  Address_Bytes => 2, others => <>);
   Kbit_512_Part : constant Geometry :=
     (Capacity_Bytes => 65_536,  Address_Bytes => 2, others => <>);
   Mbit_1_Part   : constant Geometry :=
     (Capacity_Bytes => 131_072, Address_Bytes => 3, others => <>);
   --  2 Mbit and 4 Mbit: still three address bytes (18/19-bit).
   Mbit_2_Part   : constant Geometry :=
     (Capacity_Bytes => 262_144, Address_Bytes => 3, others => <>);
   Mbit_4_Part   : constant Geometry :=
     (Capacity_Bytes => 524_288, Address_Bytes => 3, others => <>);

end ESP32S3.FRAM_SPI;
