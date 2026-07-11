with ESP32S3.I2C;

--  The I2C FRAM families -- Fujitsu MB85RC, Cypress/Infineon FM24 -- the
--  catalogue.  FRAM (ferroelectric RAM) is non-volatile memory that behaves like
--  RAM: byte-writable, effectively unlimited endurance, and --- the two facts that
--  make its driver simpler than the 24C EEPROM's --- NO page-write boundary and NO
--  program cycle.  A write of any length lands in one bus transaction and is done
--  when the STOP completes.  What survives from the EEPROM model is the addressing:
--  device-type code 1010, a big-endian word address, and (on the small parts) high
--  address bits folded into the device-select byte.
--
--  The I2C read/write protocol is IDENTICAL across manufacturers, so a part is
--  nothing but a Geometry, and parts are keyed here by DENSITY, not by part number
--  (one instance covers every vendor's part of that density and package):
--
--     with ESP32S3.FRAM_I2C.Kbit_256;
--     ...
--     Ram : ESP32S3.FRAM_I2C.Kbit_256.Device;
--     ESP32S3.FRAM_I2C.Kbit_256.Setup (Ram, Sda => 41, Scl => 40);
--
--  Which part maps to which density (each instance's banner lists its parts):
--    Kbit_4    MB85RC04V | FM24C04B
--    Kbit_16   MB85RC16V | FM24C16B | FM24CL16B
--    Kbit_64   MB85RC64V | FM24C64B | FM24CL64B
--    Kbit_128  MB85RC128A | FM24V01
--    Kbit_256  MB85RC256V | FM24W256 | FM31256 (FRAM array only)
--    Kbit_512  MB85RC512T | FM24V05
--    Mbit_1    MB85RC1MT | FM24V10
--  The SPI FRAM parts (MB85RS*, FM25*) are ESP32S3.FRAM_SPI.  The parallel-bus
--  parts (FM28*, FM18*, FM22*) are not supported (no parallel bus on this board).
--
--  Only the memory READ/WRITE is manufacturer-independent; the Device-ID reply
--  differs by vendor (Driver.Read_Device_ID returns the raw manufacturer code).
--
--  STATUS: none run against real silicon yet (no FRAM fitted).  Datasheet-derived.

package ESP32S3.FRAM_I2C is

   type Verification is (Verified, Untested);

   type Geometry is record
      --  Array size in bytes: a power of two.
      Capacity_Bytes : Positive;

      --  Word-address bytes before the data: 1 up to 16 Kbit, 2 from 64 Kbit up.
      Word_Address_Bytes : Positive;

      --  Bus clock the driver uses by default (Setup can override).  FRAM I2C runs
      --  at Fast-mode Plus; 1 MHz is safe across the family, the bus may cap lower.
      Max_Clock_Hz : Positive := 1_000_000;

      --  Device-type code 1010 -> 0x50 for the memory array on every part.
      Base_Slave_Address : ESP32S3.I2C.Slave_Address := 16#50#;

      Tested : Verification := Untested;
   end record;

   --  One entry per unique density (= geometry).  Address bytes: 1 up to 16 Kbit,
   --  2 from 64 Kbit; the small parts fold high address bits into the select byte.
   Kbit_4_Part   : constant Geometry :=
     (Capacity_Bytes => 512,     Word_Address_Bytes => 1, others => <>);
   Kbit_16_Part  : constant Geometry :=
     (Capacity_Bytes => 2_048,   Word_Address_Bytes => 1, others => <>);
   Kbit_64_Part  : constant Geometry :=
     (Capacity_Bytes => 8_192,   Word_Address_Bytes => 2, others => <>);
   Kbit_128_Part : constant Geometry :=
     (Capacity_Bytes => 16_384,  Word_Address_Bytes => 2, others => <>);
   Kbit_256_Part : constant Geometry :=
     (Capacity_Bytes => 32_768,  Word_Address_Bytes => 2, others => <>);
   Kbit_512_Part : constant Geometry :=
     (Capacity_Bytes => 65_536,  Word_Address_Bytes => 2, others => <>);
   Mbit_1_Part   : constant Geometry :=
     (Capacity_Bytes => 131_072, Word_Address_Bytes => 2, others => <>);

end ESP32S3.FRAM_I2C;
