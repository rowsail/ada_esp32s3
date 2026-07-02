with ESP32S3.Block_Dev;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Superblock;

--  The mounted-volume context shared by the operation packages (Inode, Dir,
--  Block_Map, Path, File).  Kept low in the dependency graph so those packages
--  can `with` it without a cycle through the FS facade.

package ESP32S3.Ext4.Volume is

   type Context is limited record
      Dev       : ESP32S3.Block_Dev.Device;
      Cache     : ESP32S3.Ext4.Block_Cache.Cache;
      SB        : ESP32S3.Ext4.Superblock.Info;
      Read_Only : Boolean := True;
   end record;

   --  Block size of the mounted volume, in bytes.
   function Block_Size (V : Context) return Natural
   is (V.SB.Block_Size);

end ESP32S3.Ext4.Volume;
