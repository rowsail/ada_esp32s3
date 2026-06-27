with ESP32S3.W25Q;

--  Adapter: present an initialised W25Q SPI NOR flash as a Block_Dev.Device,
--  mapping the filesystem's 512-byte sectors directly onto flash byte addresses
--  (LBA N  <->  byte N * 512).
--
--  NOR semantics are handled here, behind the plain Read/Write vtable:
--    * Read  is a plain random read.
--    * Write is WRITE-THROUGH and erase-aware.  Flash programming can only clear
--      1->0 bits, so when the new bytes only clear bits of what is already there
--      (the common case: writing into freshly-erased 0xFF space) it programs in
--      place; otherwise it read-modify-writes the whole 4 KB erase block
--      (read 4 KB, splice in the sector, erase, reprogram).
--  Because every Write_Sector is durable on the medium before it returns (no
--  hidden write-back cache), this works with the flush-less Block_Dev vtable.
--
--  This is the DIRECT mapping with NO wear leveling -- a hot 4 KB block is erased
--  in place every time it is rewritten.  The Option B wear-leveling FTL layers on
--  top of this later.
--
--  The Flash must already be Setup + Initialize'd (4-byte address mode), the
--  Source must be Configure'd, and the Source must outlive the returned Device.
--  Single-threaded use (one Source feeds one filesystem), like the ext4 stack
--  itself.  (Embedded/full only -- pulls in the finalization-based SPI stack.)
package ESP32S3.Block_Dev.W25Q_Source is

   --  512-byte block-device sectors per 4 KB flash erase sector.
   Sectors_Per_Erase : constant := ESP32S3.W25Q.Sector_Size / Sector'Length;  -- 8

   --  Backing state for one flash-backed block device: the flash handle, the
   --  usable sector count, and a 4 KB scratch block for read-modify-write.
   --  Declare one (aliased), Configure it, then Make a Device from it.
   type Source is limited private;

   --  Bind Src to Flash and set the usable size to Capacity_Bytes (rounded down
   --  to a whole 512-byte sector).  Capacity_Bytes must not exceed the chip.
   --
   --  Capacity_Bytes => 0 (the default) AUTO-DETECTS the size from the chip's
   --  JEDEC id (see ESP32S3.W25Q.Capacity_Bytes), so the whole stack -- this
   --  source, Block_Dev.WL, the filesystem -- sizes itself to whatever part is
   --  fitted.  Raises Unknown_Capacity if the chip's density code is not
   --  recognised (absent / mis-wired / non-standard part).
   procedure Configure (Src            : in out Source;
                        Flash          : ESP32S3.W25Q.Flash;
                        Capacity_Bytes : ESP32S3.W25Q.Address := 0);

   --  Auto-detect could not determine the chip size.
   Unknown_Capacity : exception;

   --  A Device whose Ctx is Src; Src must outlive it.
   function Make (Src : not null access Source) return Device;

private
   subtype Block_Buffer is
     ESP32S3.W25Q.Byte_Array (0 .. ESP32S3.W25Q.Sector_Size - 1);

   type Source is limited record
      Flash : ESP32S3.W25Q.Flash;
      Count : Sector_Index := 0;                     --  total 512-byte sectors
      Buf   : Block_Buffer := (others => 16#FF#);    --  4 KB read-modify-write scratch
   end record;
end ESP32S3.Block_Dev.W25Q_Source;
