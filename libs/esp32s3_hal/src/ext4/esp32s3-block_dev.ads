with System;
with Interfaces;

--  The one block-device abstraction the filesystem talks to.  A record of
--  access-to-subprogram + an opaque context (mirrors lwext4's ext4_blockdev
--  vtable): no tagging, no finalization, swappable at run time.  Behind it sit
--  thin adapters -- ESP32S3.Block_Dev.SD_SPI_Source / SDMMC_Source on target,
--  a file-backed device in the host test harness.
--
--  512-byte sectors (the SD logical sector).  The filesystem layers its own
--  (1 KiB .. 64 KiB) block size on top via ESP32S3.Ext4.Block_Cache.
--
--  The primitive Read/Write may RAISE Ada.IO_Exceptions.Device_Error on a
--  hardware/IO failure (the adapters convert the SD driver's Status enum to a
--  raise); the convenience wrappers below also raise on a null/oversize access.

package ESP32S3.Block_Dev is

   type Sector is array (0 .. 511) of Interfaces.Unsigned_8;
   type Sector_Index is new Interfaces.Unsigned_64;

   type Read_Proc is
     access procedure
       (Ctx : System.Address; LBA : Sector_Index; Data : out Sector);
   type Write_Proc is
     access procedure
       (Ctx : System.Address; LBA : Sector_Index; Data : Sector);
   type Count_Func is
     access function (Ctx : System.Address) return Sector_Index;

   --  OPTIONAL capability: discard/erase the run of sectors [First, First+Count).
   --  Best-effort -- where the medium has an erase unit (a NOR flash 4 KB
   --  sector) the run becomes erased; a device that cannot do this leaves Erase
   --  null and Erase_Sectors is a no-op.  First and Count should be aligned to
   --  the device's erase unit.  ESP32S3.Block_Dev.WL uses it to clear a block
   --  before rewriting it whole, so the rewrite programs into erased space (one
   --  erase) instead of a read-modify-write per sector.
   type Erase_Proc is
     access procedure
       (Ctx : System.Address; First : Sector_Index; Count : Sector_Index);

   --  A configured backend.  Write = null marks a read-only device; Erase = null
   --  a device with no block-erase capability (the common case).
   type Device is record
      Ctx   : System.Address := System.Null_Address;
      Read  : Read_Proc := null;
      Write : Write_Proc := null;
      Count : Count_Func := null;
      Erase : Erase_Proc := null;
   end record;

   --  True if the device can be written.
   function Writable (Dev : Device) return Boolean
   is (Dev.Write /= null);

   --  True if the device exposes a block-erase capability.
   function Can_Erase (Dev : Device) return Boolean
   is (Dev.Erase /= null);

   --  Total number of 512-byte sectors.
   function Sector_Count (Dev : Device) return Sector_Index;

   --  Read / write one sector; raise Device_Error on a missing primitive or an
   --  out-of-range index (Read_Sector) / a read-only device (Write_Sector).
   procedure Read_Sector (Dev : Device; LBA : Sector_Index; Data : out Sector);
   procedure Write_Sector (Dev : Device; LBA : Sector_Index; Data : Sector);

   --  Best-effort erase of [First, First+Count); a no-op if the device has no
   --  Erase capability (so callers may invoke it unconditionally).
   procedure Erase_Sectors (Dev : Device; First, Count : Sector_Index);

end ESP32S3.Block_Dev;
