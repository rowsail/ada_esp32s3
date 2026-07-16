with Interfaces;

package body ESP32S3.Ext4.Mkfs.Math
  with SPARK_Mode => On
is
   use type Interfaces.Unsigned_32;   --  U32 arithmetic/comparison operators

   --------------------
   -- Compute_Layout --
   --------------------

   function Compute_Layout (Total_Blocks : U32; Journal : Boolean) return Layout is
      --  Inode count: ~one per 16 KiB (mkfs default), rounded up to a whole
      --  inode-table block, at least IPB.  Total_Blocks <= BPG (the Pre) keeps
      --  every term small: Total_Blocks / 4 <= 8192, so no modular wrap.
      Raw_I : constant U32 := U32'Max (IPB, Total_Blocks / 4);
      I     : constant U32 := ((Raw_I + IPB - 1) / IPB) * IPB;   --  multiple of IPB
      IT    : constant U32 := I / IPB;                           --  inode-table blocks

      Root  : constant U32 := ITbl_Blk + IT;   --  root directory data
      LPF   : constant U32 := Root + 1;         --  lost+found data
      J_Frst : constant U32 := LPF + 1;          --  journal block 0 (its superblock)
      J_I    : constant U32 := J_Frst + J_Blocks;  --  journal single-indirect block
      J_Tot  : constant U32 := (if Journal then J_Blocks + 1 else 0);  --  + indirect
      Used   : constant U32 := (if Journal then J_Frst + J_Tot else LPF + 1);
   begin
      return
        (Inodes      => I,
         Inode_Table => IT,
         Root_Blk    => Root,
         LPF_Blk     => LPF,
         J_First     => J_Frst,
         J_Ind       => J_I,
         Used_Blks   => Used);
   end Compute_Layout;

   -----------------
   -- Free_Blocks --
   -----------------

   function Free_Blocks (L : Layout; Total_Blocks : U32) return U32 is
   begin
      return Total_Blocks - L.Used_Blks;
   end Free_Blocks;

   -----------------
   -- Free_Inodes --
   -----------------

   function Free_Inodes (L : Layout) return U32 is
   begin
      return L.Inodes - Used_Inodes;
   end Free_Inodes;

end ESP32S3.Ext4.Mkfs.Math;
