with System;
with Interfaces;   use Interfaces;
with ESP32S3.SPI;
with ESP32S3.GPIO;

--  Winbond W25Q-series SPI NOR flash driver (bare-metal, task-safe).
--
--  Targets the W25Q256FV (32 MB / 256 Mbit, JEDEC ID EF 40 19) but the command
--  set is the Winbond family standard.  The chip sits on a general-purpose SPI
--  host (ESP32S3.SPI), and its chip select is APPLICATION-DRIVEN through the
--  SPI driver's CS callback -- so the flash can share one bus with other devices
--  (e.g. a W5500 on the host's hardware CS0) and its select can be a single
--  GPIO, several GPIOs into a 3:8 decoder, an I/O-expander line, etc.
--
--  Because the part is larger than 16 MB it must be addressed with 4 bytes.
--  Initialize puts the chip in 4-byte ADDRESS MODE (opcode 0xB7) once at start;
--  every command then carries a 4-byte address and reaches the full 32 MB.  (We
--  use the standard opcodes -- Read 0x03, Page-Program 0x02, Sector-Erase 0x20 --
--  which is what the W25Q256FV datasheet prescribes: in 4-byte mode those very
--  opcodes take 4 address bytes.  The FV has NO dedicated 4-byte program/erase
--  opcodes (the 0x12/0x21/0xDC set is a later W25Q256JV addition), so attempting
--  them here is silently ignored.)
--  4-byte mode is volatile, so call Initialize after every power-on.
--
--  Each public operation takes the host for just its own duration (Acquire ..
--  Release around one command group), so it cooperates with other owners of a
--  shared bus rather than holding it for the flash's whole lifetime.  Requires a
--  tasking runtime (the SPI Session is controlled) -- embedded/full profile.
package ESP32S3.W25Q is

   --  Geometry of the Winbond family parts this driver speaks to.
   Page_Size   : constant := 256;     --  program granularity (one Page-Program)
   Sector_Size : constant := 4096;    --  smallest erase unit (Sector-Erase 0x21)
   Block_Size  : constant := 65536;   --  64 KB erase block (Block-Erase 0xDC)

   --  Flat byte address into the array (0 .. chip_size-1).  The W25Q256FV is
   --  32 MB, so a 32-bit address covers it with room to spare.
   subtype Address is Unsigned_32;

   type Byte_Array is array (Natural range <>) of Unsigned_8;

   --  The three JEDEC identification bytes (opcode 0x9F).  For a W25Q256FV:
   --  Manufacturer = EF (Winbond), Memory_Type = 40, Capacity = 19 (256 Mbit).
   --  An absent or mis-wired chip reads all-00 or all-FF.
   type JEDEC_ID is record
      Manufacturer : Unsigned_8;
      Memory_Type  : Unsigned_8;
      Capacity     : Unsigned_8;
   end record;

   --  A flash device: which SPI host it lives on, and how to drive its chip
   --  select.  CS / Ctx are passed straight to ESP32S3.SPI.Acquire on every
   --  operation (see that package for the callback's library-level / closure-
   --  free / non-raising contract).  For the common "select is one active-low
   --  GPIO" case use GPIO_Select below; for a decoder or expander supply your
   --  own CS callback and point Ctx at its state.
   type Flash is record
      Host : ESP32S3.SPI.SPI_Host;
      CS   : ESP32S3.SPI.CS_Select  := null;
      Ctx  : System.Address         := System.Null_Address;
   end record;

   ----------------------------------------------------------------------------
   --  Ready-made single-GPIO chip select (the common case)
   --
   --  When the flash's select is a single active-low GPIO, point the Flash's Ctx
   --  at an aliased Pin_Cell holding the pad and use GPIO_Select as the CS
   --  callback.  Call Init_Pin once at startup to configure the pad as an output
   --  and leave it deselected (high) before the first transfer.
   ----------------------------------------------------------------------------

   --  Per-device state for GPIO_Select: just the select pad.  Declare one
   --  aliased Pin_Cell per flash and hand its 'Address to Flash.Ctx.
   type Pin_Cell is record
      Pin : ESP32S3.GPIO.Pin_Id;
   end record;

   --  Configure the select pad as a strong output and drive it high (deselected).
   procedure Init_Pin (Cell : Pin_Cell);

   --  CS callback for a single active-low GPIO: Active drives the pad low
   --  (selected), not-Active drives it high.  Library-level and non-raising, as
   --  the SPI driver requires.  Ctx must point at a Pin_Cell.
   procedure GPIO_Select (Ctx : System.Address; Active : Boolean);

   ----------------------------------------------------------------------------
   --  Operations
   ----------------------------------------------------------------------------

   --  Put the chip into 4-byte address mode (opcode 0xB7) and confirm it took:
   --  OK is True when status register 3 reports ADS = 1.  Call once at startup,
   --  before any Read / Erase_Sector / Program_Page (those assume 4-byte mode).
   procedure Initialize (Dev : Flash; OK : out Boolean);

   --  Read the JEDEC identification (opcode 0x9F).  Independent of address mode,
   --  so it may be called before Initialize.
   procedure Read_Identification (Dev : Flash; ID : out JEDEC_ID);

   --  Total chip size in bytes, decoded from the JEDEC capacity byte: the
   --  SPI-NOR convention encodes density as a power of two (2 ** Capacity), so a
   --  W25Q256 (0x19) is 32 MB, a W25Q128 (0x18) 16 MB, a W25Q64 (0x17) 8 MB, and
   --  so on.  Returns 0 for a capacity byte outside the recognised 64 KB .. 64 MB
   --  range -- an absent/mis-wired chip (0x00 or 0xFF) or a part using a
   --  non-standard density code -- so callers can detect "unknown size".
   function Capacity_Bytes (ID : JEDEC_ID) return Address;

   --  Read Data'Length bytes starting at Addr (opcode 0x13, continuous read).
   --  Any length is allowed: the read streams across as many SPI transfers as
   --  needed with the chip held selected throughout.
   procedure Read (Dev : Flash; Addr : Address; Data : out Byte_Array);

   --  Erase the 4 KB sector containing Addr (opcode 0x21); blocks until the chip
   --  reports not-busy.  Erased bytes read back as 0xFF.  (Issues Write-Enable
   --  first and polls the status register's BUSY bit after.)
   procedure Erase_Sector (Dev : Flash; Addr : Address);

   --  Program Data (1 .. 256 bytes, must not cross a 256-byte page boundary) at
   --  Addr (opcode 0x12); blocks until not-busy.  Programming only clears 1->0
   --  bits, so the target must have been erased first.  Data longer than a page,
   --  or that would cross a page boundary, is rejected (Constraint_Error) rather
   --  than silently wrapping.
   procedure Program_Page (Dev : Flash; Addr : Address; Data : Byte_Array);

end ESP32S3.W25Q;
