with System;
with ESP32S3.GPIO;
with ESP32S3.SPI;

--  The one driver behind every part in the SPI FRAM catalogue.  Instantiate it
--  with a Geometry from the parent -- see ESP32S3.FRAM_SPI.MB85RS256B and its
--  siblings:
--
--     package My_Ram is new ESP32S3.FRAM_SPI.Driver (MB85RS256B_Part);
--
--  Read and Write take an arbitrary Byte_Array at an arbitrary address.  A Read
--  is opcode 0x03 + address then a stream of clocks (the chip auto-increments);
--  a Write is WREN (0x06) then opcode 0x02 + address + the whole payload -- no
--  page boundary and no BUSY poll, because FRAM commits as it clocks in.  Long
--  transfers are bounced through internal-SRAM DMA scratch and streamed with the
--  chip held selected, so any length works.
--
--  The chip select is APPLICATION-DRIVEN, like the W25Q flash: give Setup a CS_Pin
--  (a plain GPIO the SPI driver toggles) OR a CS_CB callback (for a decoder / I/O
--  expander line).  FRAM is SPI mode 0.
--
--  Uses the controlled SPI Session (finalization) => embedded / full profiles.

generic
   Part : Geometry;
package ESP32S3.FRAM_SPI.Driver is

   Capacity      : constant Positive := Part.Capacity_Bytes;
   Address_Bytes : constant Positive := Part.Address_Bytes;

   --  The geometry's default bit clock (Setup's Clock_Hz defaults to this).
   Max_Clock     : constant Positive := Part.Max_Clock_Hz;

   Hardware_Verified : constant Boolean := Part.Tested = Verified;

   subtype Memory_Address is Natural range 0 .. Capacity - 1;

   type Device is limited private;

   ----------------------------------------------------------------------------
   --  One-time configuration.  Brings the SPI host up and records how this
   --  device's chip select is driven.  Set CS_Pin for a plain GPIO select, or
   --  leave it No_Pin and pass CS_CB + Ctx for a non-GPIO select.
   ----------------------------------------------------------------------------
   procedure Setup
     (Dev              : out Device;
      Sclk, Mosi, Miso : ESP32S3.GPIO.Pin_Id;
      CS_Pin           : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      CS_CB            : ESP32S3.SPI.CS_Select := null;
      Ctx              : System.Address := System.Null_Address;
      Host             : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      Clock_Hz         : Positive := Max_Clock);

   ----------------------------------------------------------------------------
   --  Identity / presence.  RDID (0x9F) returns a JEDEC-style manufacturer +
   --  product identity.  There is no bus ACK on SPI, so presence is inferred
   --  from a plausible (not all-0x00 / all-0xFF) ID.
   ----------------------------------------------------------------------------
   type Device_ID is array (0 .. 3) of Interfaces.Unsigned_8;

   procedure Read_Device_ID (Dev : Device; ID : out Device_ID);
   function Is_Present (Dev : Device) return Boolean;

   --  Classify the responding part by the manufacturer byte in its RDID reply.
   --  INFORMATIONAL only (identify / log); the geometry is fixed at compile time by
   --  the chosen instance, not probed or verified.
   Fujitsu_Manufacturer : constant := 16#04#;
   Cypress_Manufacturer : constant := 16#C2#;
   type Vendor is (Fujitsu, Cypress, Unknown);
   function Identify (Dev : Device) return Vendor;

   ----------------------------------------------------------------------------
   --  Memory access.  No Status: SPI FRAM has no per-transaction ACK, and no
   --  program cycle to fail -- an absent chip shows up as a bad Device_ID, not
   --  as a failed Read/Write.
   ----------------------------------------------------------------------------
   procedure Read (Dev : Device; From : Memory_Address; Data : out Byte_Array)
   with Pre => Data'Length <= Capacity - From;

   procedure Write (Dev : Device; To : Memory_Address; Data : Byte_Array)
   with Pre => Data'Length <= Capacity - To;

   function Read_Byte (Dev : Device; From : Memory_Address) return Interfaces.Unsigned_8;
   procedure Write_Byte (Dev : Device; To : Memory_Address; Value : Interfaces.Unsigned_8);

private
   type Device is record
      Host     : ESP32S3.SPI.SPI_Host := ESP32S3.SPI.SPI2;
      CS_Pin   : ESP32S3.GPIO.Optional_Pin := ESP32S3.GPIO.No_Pin;
      CS_CB    : ESP32S3.SPI.CS_Select := null;
      Ctx      : System.Address := System.Null_Address;
      Clock_Hz : Positive := 20_000_000;
   end record;

end ESP32S3.FRAM_SPI.Driver;
