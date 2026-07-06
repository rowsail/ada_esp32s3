with ESP32S3.Ext4.Volume;
with ESP32S3.Ext4.Inode;

--  Reading a regular file's data by byte offset, mapping logical to physical
--  blocks through ESP32S3.Ext4.Block_Map and pulling bytes from the cache.
--  Sparse holes read as zeros.  (Write/Truncate + an RAII File handle arrive in
--  Phase 3.)

package ESP32S3.Ext4.File is

   --  Read up to Into'Length bytes of file I starting at byte Offset; Last is
   --  the number actually read (0 at or past end of file).
   procedure Read
     (V      : in out Volume.Context;
      I      : Inode.Info;
      Offset : U64;
      Into   : out Byte_Array;
      Last   : out Natural)
   with Post => Last <= Into'Length;

end ESP32S3.Ext4.File;
