--  Lay down an empty FAT16 volume, so blank media comes up as a usable drive
--  the first time a PC sees it rather than as "you need to format this disk
--  before you can use it".
--
--  Two things drive the geometry this writes, and both matter:
--
--    * Windows expects a USB flash drive to carry a PARTITION TABLE, with the
--      filesystem inside partition 1 -- not a bare boot sector at LBA 0.  That
--      is the default here.
--    * The backing medium is NOR flash with a 4 KB erase unit.  Clusters are
--      4 KB and the data area is padded to START on an erase-unit boundary, so
--      a cluster never straddles two erase blocks and the block layer's
--      read-modify-write stays a single erase per cluster written.
--
--  Formatting is destructive and unconditional: it does not look at what is
--  already there.  The caller decides (a failed ESP32S3.Fat16.Mount is the
--  usual cue).

package ESP32S3.Fat16.Mkfs is

   --  Volume labels are the 8.3-era 11 characters, upper case.  A longer one
   --  is truncated, a shorter one padded.
   Max_Label_Length : constant := 11;

   procedure Format
     (Device               : ESP32S3.Block_Dev.Device;
      Status               : out Status_Kind;
      Label                : String := "NO NAME";
      Serial_Number        : Interfaces.Unsigned_32 := 16#4553_5033#;
      With_Partition_Table : Boolean := True);
   --  Status is Unsupported when the device cannot hold a FAT16 volume at all
   --  (fewer than ~4085 clusters at any cluster size, or more than 65524 at
   --  the largest), Device_Failed when a write is refused or raises.

end ESP32S3.Fat16.Mkfs;

