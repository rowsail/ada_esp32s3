--  Pure single-block-group layout arithmetic extracted from ESP32S3.Ext4.Mkfs
--  (Format).  No registers, no I/O: just the geometry -- inode count, inode-table
--  size and the fixed metadata block positions -- split out so it can be formally
--  proved (see libs/esp32s3_hal/test/mkfs_math_prove).  Format runs its size
--  guards, then calls Compute_Layout and writes the returned positions itself;
--  a wrong geometry silently corrupts the filesystem, so proving it is bounded
--  and internally consistent is the point.

with Interfaces;

package ESP32S3.Ext4.Mkfs.Math
  with SPARK_Mode => On
is
   use type Interfaces.Unsigned_32;   --  U32 arithmetic/comparison operators

   --  Fixed on-disk geometry (4 KiB blocks, 256-byte inodes, one block group).
   BS  : constant := 4096;          --  block size
   ISz : constant := 256;           --  inode size
   IPB : constant := BS / ISz;      --  inodes per inode-table block = 16
   BPG : constant := 8 * BS;        --  blocks per group = 32768 (one bitmap block)

   Used_Inodes : constant := 11;    --  reserved 1 .. 10 + lost+found (11)
   Direct_Ptrs : constant := 12;    --  i_block[0 .. 11] are direct
   J_Blocks    : constant U32 := 1024;   --  journal length incl its superblock

   --  The fixed metadata block positions (first_data_block = 0 for BS > 1024):
   --  block 0 = superblock pad, then GDT / block bitmap / inode bitmap / inode
   --  table.  Everything after the inode table is placed by Compute_Layout.
   GDT_Blk  : constant U32 := 1;
   BBmp_Blk : constant U32 := 2;
   IBmp_Blk : constant U32 := 3;
   ITbl_Blk : constant U32 := 4;

   --  The computed single-group layout for a given device size.
   type Layout is record
      Inodes      : U32;   --  s_inodes_count (= s_inodes_per_group), multiple of IPB
      Inode_Table : U32;   --  inode-table length in blocks
      Root_Blk    : U32;   --  root directory data block
      LPF_Blk     : U32;   --  lost+found data block
      J_First     : U32;   --  journal block 0 (its superblock); valid iff Journal
      J_Ind       : U32;   --  journal single-indirect block; valid iff Journal
      Used_Blks    : U32;  --  metadata + directory (+ journal) blocks in use
   end record;

   --  Lay out a single-group ext4 of Total_Blocks 4 KiB blocks.  The caller must
   --  have already rejected an over-large device (Total_Blocks <= BPG), so every
   --  field stays small and provably bounded.  Journal adds the JBD2 log.
   function Compute_Layout (Total_Blocks : U32; Journal : Boolean) return Layout
     with
       Pre  => Total_Blocks <= BPG,
       Post =>
         --  Inode count: a whole number of inode-table blocks, at least one.
         Compute_Layout'Result.Inodes mod IPB = 0
         and then Compute_Layout'Result.Inodes in IPB .. BPG
         and then Compute_Layout'Result.Inode_Table
                  = Compute_Layout'Result.Inodes / IPB
         and then Compute_Layout'Result.Inode_Table in 1 .. BPG / IPB
         --  The data blocks follow the inode table, contiguously.
         and then Compute_Layout'Result.Root_Blk
                  = ITbl_Blk + Compute_Layout'Result.Inode_Table
         and then Compute_Layout'Result.LPF_Blk
                  = Compute_Layout'Result.Root_Blk + 1
         and then Compute_Layout'Result.J_First
                  = Compute_Layout'Result.LPF_Blk + 1
         and then Compute_Layout'Result.J_Ind
                  = Compute_Layout'Result.J_First + J_Blocks
         --  Used_Blks is bounded so the caller's Free = Total - Used is meaningful
         --  once its "device too small" guard (Total > Used_Blks) has passed.
         and then Compute_Layout'Result.Used_Blks
                  in (Compute_Layout'Result.LPF_Blk + 1)
                     .. (Compute_Layout'Result.J_First + J_Blocks + 1);

   --  Free block / inode counts, once the caller has passed the too-small guard.
   function Free_Blocks (L : Layout; Total_Blocks : U32) return U32
     with Pre  => Total_Blocks >= L.Used_Blks,
          Post => Free_Blocks'Result = Total_Blocks - L.Used_Blks;

   function Free_Inodes (L : Layout) return U32
     with Pre  => L.Inodes >= Used_Inodes,
          Post => Free_Inodes'Result = L.Inodes - Used_Inodes;

end ESP32S3.Ext4.Mkfs.Math;
