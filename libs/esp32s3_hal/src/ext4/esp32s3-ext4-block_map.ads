with ESP32S3.Ext4.Volume;
with ESP32S3.Ext4.Inode;

--  Logical-to-physical block mapping for a file's data.  Dispatches on the
--  inode's EXTENTS_FL: classic indirect block pointers (ext2/3, implemented
--  here) or extent trees (ext4, Phase 2).  A result of 0 means a sparse hole
--  (the logical block reads as zeros).

package ESP32S3.Ext4.Block_Map is

   function Logical_To_Physical
     (V : in out Volume.Context; I : Inode.Info; L_Block : U64) return Block_Number;

end ESP32S3.Ext4.Block_Map;
