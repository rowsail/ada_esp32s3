with Interfaces;
with ESP32S3.Block_Dev;

use type Interfaces.Unsigned_32;

--  The ext2/3/4 superblock (1024 bytes at byte offset 1024).  Read raw from the
--  device before the block cache exists (the cache needs the block size from
--  here).  Owns the on-disk `ext4_super_block`.

package ESP32S3.Ext4.Superblock is

   type Info is record
      Block_Size        : Natural := 1024;
      First_Data_Block  : U32 := 1;
      Blocks_Per_Group  : U32 := 0;
      Inodes_Per_Group  : U32 := 0;
      Inode_Size        : Natural := 128;
      Inodes_Count      : U32 := 0;
      Blocks_Count      : U64 := 0;
      Free_Blocks       : U64 := 0;
      Free_Inodes       : U32 := 0;
      Desc_Size         : Natural := 32;
      Groups_Count      : U32 := 0;
      Feature_Compat    : U32 := 0;
      Feature_Incompat  : U32 := 0;
      Feature_RO_Compat : U32 := 0;
      Has_Csum          : Boolean := False;   --  metadata_csum in effect
      Csum_Seed         : U32 := 0;        --  per-fs CRC32c seed
   end record;

   --  INCOMPAT feature bits.
   Incompat_Filetype    : constant U32 :=
     16#0000_0002#;   --  dir entries carry a type
   Incompat_Recover     : constant U32 :=
     16#0000_0004#;   --  journal needs recovery
   Incompat_Journal_Dev : constant U32 := 16#0000_0008#;
   Incompat_Meta_BG     : constant U32 := 16#0000_0010#;
   Incompat_Extents     : constant U32 :=
     16#0000_0040#;   --  inodes use extent trees
   Incompat_64Bit       : constant U32 := 16#0000_0080#;
   Incompat_Flex_BG     : constant U32 :=
     16#0000_0200#;   --  relocated metadata groups
   Incompat_Csum_Seed   : constant U32 := 16#0000_2000#;
   Incompat_Inline_Data : constant U32 := 16#0001_0000#;

   --  COMPAT bits we care about.
   Compat_Has_Journal : constant U32 := 16#0000_0004#;

   --  RO_COMPAT bits we care about.
   RO_Compat_Metadata_Csum : constant U32 := 16#0000_0400#;

   function Has_Filetype (SB : Info) return Boolean
   is ((SB.Feature_Incompat and Incompat_Filetype) /= 0);

   function Is_64Bit (SB : Info) return Boolean
   is ((SB.Feature_Incompat and Incompat_64Bit) /= 0);

   function Has_Metadata_Csum (SB : Info) return Boolean
   is ((SB.Feature_RO_Compat and RO_Compat_Metadata_Csum) /= 0);

   --  True when the volume carries a JBD2 journal (mkfs default).  When false
   --  (mkfs -O ^has_journal) the FS commits by flushing the cache + superblock
   --  directly instead of journaling -- see ESP32S3.Ext4.FS.Commit.
   function Has_Journal (SB : Info) return Boolean
   is ((SB.Feature_Compat and Compat_Has_Journal) /= 0);

   --  Read + validate the superblock from Dev (raises Corrupt on a bad magic).
   procedure Read (Dev : ESP32S3.Block_Dev.Device; SB : out Info);

   --  Write SB's free-block / free-inode counts back to the on-disk superblock
   --  (and refresh its checksum when metadata_csum is in effect).
   procedure Sync (Dev : ESP32S3.Block_Dev.Device; SB : Info);

   --  The filesystem block that holds the superblock, and the SB's offset within
   --  it (the SB lives at byte 1024: block 1 for 1 KiB blocks, else block 0).
   function SB_Block (Block_Size : Natural) return Block_Number
   is (if Block_Size = 1024 then 1 else 0);
   function SB_Offset (Block_Size : Natural) return Natural
   is (if Block_Size = 1024 then 0 else 1024);

   --  Patch SB's mutable fields (free counts, feature_incompat) into Buf at byte
   --  Base, refreshing the SB checksum -- for journaling the SB as a block.  Buf
   --  must already hold the current on-disk superblock at [Base .. Base+1023].
   procedure Encode (SB : Info; Buf : in out Byte_Array; Base : Natural);

   --  Raise Unsupported_Feature for any INCOMPAT bit outside Handled.
   procedure Require_Supported (SB : Info; Handled : U32);

end ESP32S3.Ext4.Superblock;
