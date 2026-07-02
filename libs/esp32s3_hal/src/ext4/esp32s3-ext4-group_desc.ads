with ESP32S3.Ext4.Volume;

--  Block-group descriptors -- the per-group table that locates each group's
--  block bitmap, inode bitmap and inode table.  32 bytes (ext2/3) or 64 bytes
--  (the ext4 "64bit" feature).  The table starts in the block right after the
--  superblock block (First_Data_Block + 1).

package ESP32S3.Ext4.Group_Desc is

   type Desc is record
      Block_Bitmap : Block_Number := 0;
      Inode_Bitmap : Block_Number := 0;
      Inode_Table  : Block_Number := 0;
      Free_Blocks  : U32 := 0;
      Free_Inodes  : U32 := 0;
      Used_Dirs    : U32 := 0;
   end record;

   --  Read group G's descriptor.
   procedure Read (V : in out Volume.Context; Group : U32; D : out Desc);

   --  Write group G's free counts + used-dirs back (locations are untouched).
   --  Only valid on a filesystem without metadata_csum (no bg_checksum recompute).
   procedure Write (V : in out Volume.Context; Group : U32; D : Desc);

   --  Block number at which the group-descriptor table starts.
   function Table_Start (V : Volume.Context) return Block_Number
   is (Block_Number (V.SB.First_Data_Block) + 1);

end ESP32S3.Ext4.Group_Desc;
