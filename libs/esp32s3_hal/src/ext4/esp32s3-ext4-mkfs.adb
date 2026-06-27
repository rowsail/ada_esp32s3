with Interfaces; use Interfaces;

package body ESP32S3.Ext4.Mkfs is

   use type ESP32S3.Block_Dev.Sector_Index;

   BS   : constant := 4096;          --  block size
   SPB  : constant := BS / 512;      --  512-byte sectors per block = 8
   ISz  : constant := 256;           --  inode size
   IPB  : constant := BS / ISz;      --  inodes per inode-table block = 16
   BPG  : constant := 8 * BS;        --  blocks per group = 32768 (one bitmap block)

   Magic        : constant U16 := 16#EF53#;
   Feat_Incompat : constant U32 := 16#0000_0002#;  --  INCOMPAT_FILETYPE only
   FT_Dir       : constant U8  := 2;       --  ext4_dir_entry file type: directory
   First_Ino    : constant := 11;          --  first non-reserved inode
   Root_Ino     : constant := 2;
   LPF_Ino      : constant := 11;          --  lost+found
   Used_Inodes  : constant := 11;          --  reserved 1..10 + lost+found (11)

   subtype Block is Byte_Array (0 .. BS - 1);

   --  Write one 4 KiB block as eight 512-byte sectors.
   procedure Write_Block (Dev : ESP32S3.Block_Dev.Device; Num : U32; B : Block) is
      Sec : ESP32S3.Block_Dev.Sector;
   begin
      for S in 0 .. SPB - 1 loop
         for I in 0 .. 511 loop
            Sec (I) := B (S * 512 + I);
         end loop;
         ESP32S3.Block_Dev.Write_Sector
           (Dev, ESP32S3.Block_Dev.Sector_Index (U64 (Num) * SPB + U64 (S)), Sec);
      end loop;
   end Write_Block;

   --  Set bits First .. Last (inclusive) in a little-endian bitmap block.
   procedure Set_Bits (B : in out Block; First, Last : Natural) is
   begin
      for N in First .. Last loop
         B (N / 8) := B (N / 8) or U8 (Shift_Left (Unsigned_32 (1), N mod 8));
      end loop;
   end Set_Bits;

   --  Encode one classic-mapped inode into Tbl at its in-table offset.
   procedure Put_Inode (Tbl   : in out Block;
                        Off   : Natural;
                        Mode  : U16;
                        Links : U16;
                        Size  : U32;
                        Blk0  : U32)
   is
   begin
      Put_U16 (Tbl, Off + 16#00#, Mode);
      Put_U32 (Tbl, Off + 16#04#, Size);                  --  i_size_lo
      Put_U16 (Tbl, Off + 16#1A#, Links);                 --  i_links_count
      Put_U32 (Tbl, Off + 16#1C#, U32 (BS / 512));        --  i_blocks_lo (one block)
      Put_U32 (Tbl, Off + 16#20#, 0);                     --  i_flags: classic map
      Put_U32 (Tbl, Off + 16#28#, Blk0);                  --  i_block[0]
      Put_U16 (Tbl, Off + 16#80#, 32);                    --  i_extra_isize
   end Put_Inode;

   --  Write a directory entry; Rec_Len is the on-disk record length.
   procedure Put_Dirent (B       : in out Block;
                         Off     : Natural;
                         Ino     : U32;
                         Rec_Len : U16;
                         Name    : String) is
   begin
      Put_U32 (B, Off + 0, Ino);
      Put_U16 (B, Off + 4, Rec_Len);
      Put_U8  (B, Off + 6, U8 (Name'Length));
      Put_U8  (B, Off + 7, FT_Dir);
      for I in Name'Range loop
         B (Off + 8 + (I - Name'First)) := U8 (Character'Pos (Name (I)));
      end loop;
   end Put_Dirent;

   ------------
   -- Format --
   ------------

   procedure Format (Dev          : ESP32S3.Block_Dev.Device;
                     Total_Blocks : U32    := 0;
                     Volume_Label : String := "")
   is
      Dev_Blocks : constant U64 :=
        U64 (ESP32S3.Block_Dev.Sector_Count (Dev)) / SPB;
      T : constant U32 :=
        (if Total_Blocks /= 0 then Total_Blocks else U32 (Dev_Blocks));

      --  Inode count: ~one per 16 KiB (mkfs default), rounded to a whole
      --  inode-table block, at least 16.
      Raw_I : constant U32 := U32'Max (16, T / 4);
      I     : constant U32 := ((Raw_I + IPB - 1) / IPB) * IPB;   --  multiple of 16
      IT    : constant U32 := I / IPB;                           --  inode-table blocks

      --  Fixed single-group block layout (first_data_block = 0 for BS > 1024):
      GDT_Blk   : constant U32 := 1;
      BBmp_Blk  : constant U32 := 2;
      IBmp_Blk  : constant U32 := 3;
      ITbl_Blk  : constant U32 := 4;
      Root_Blk  : constant U32 := ITbl_Blk + IT;     --  root directory data
      LPF_Blk   : constant U32 := Root_Blk + 1;      --  lost+found data
      Used_Blks : constant U32 := LPF_Blk + 1;       --  blocks 0 .. LPF_Blk

      Free_Blocks : constant U32 := T - Used_Blks;
      Free_Inodes : constant U32 := I - Used_Inodes;

      B : Block;
   begin
      if Total_Blocks = 0 and then Dev_Blocks = 0 then
         raise Unknown_Size with "mkfs: device size unknown, pass Total_Blocks";
      elsif T > BPG then
         raise Too_Large with "mkfs: > 1 block group not supported";
      elsif T <= Used_Blks then
         raise Too_Small with "mkfs: device too small for the metadata";
      end if;

      ----------------------------------------------------------------------
      --  Block 0: padding (0 .. 1023) then the superblock at offset 1024.
      ----------------------------------------------------------------------
      B := [others => 0];
      declare
         O : constant Natural := 1024;     --  superblock base within block 0
      begin
         Put_U32 (B, O + 16#00#, I);                   --  s_inodes_count
         Put_U32 (B, O + 16#04#, T);                   --  s_blocks_count_lo
         Put_U32 (B, O + 16#08#, 0);                   --  s_r_blocks_count_lo
         Put_U32 (B, O + 16#0C#, Free_Blocks);         --  s_free_blocks_count_lo
         Put_U32 (B, O + 16#10#, Free_Inodes);         --  s_free_inodes_count
         Put_U32 (B, O + 16#14#, 0);                   --  s_first_data_block
         Put_U32 (B, O + 16#18#, 2);                   --  s_log_block_size (4 KiB)
         Put_U32 (B, O + 16#1C#, 2);                   --  s_log_cluster_size
         Put_U32 (B, O + 16#20#, BPG);                 --  s_blocks_per_group
         Put_U32 (B, O + 16#24#, BPG);                 --  s_clusters_per_group
         Put_U32 (B, O + 16#28#, I);                   --  s_inodes_per_group
         Put_U16 (B, O + 16#34#, 0);                   --  s_mnt_count
         Put_U16 (B, O + 16#36#, 16#FFFF#);            --  s_max_mnt_count (-1)
         Put_U16 (B, O + 16#38#, Magic);               --  s_magic
         Put_U16 (B, O + 16#3A#, 1);                   --  s_state = clean
         Put_U16 (B, O + 16#3C#, 1);                   --  s_errors = continue
         Put_U32 (B, O + 16#4C#, 1);                   --  s_rev_level = dynamic
         Put_U32 (B, O + 16#54#, First_Ino);           --  s_first_ino
         Put_U16 (B, O + 16#58#, ISz);                 --  s_inode_size
         Put_U16 (B, O + 16#5A#, 0);                   --  s_block_group_nr
         Put_U32 (B, O + 16#5C#, 0);                   --  s_feature_compat
         Put_U32 (B, O + 16#60#, Feat_Incompat);       --  s_feature_incompat
         Put_U32 (B, O + 16#64#, 0);                   --  s_feature_ro_compat
         --  s_uuid (0x68 .. 0x77): a fixed, nonzero id (value is not validated).
         for K in 0 .. 15 loop
            Put_U8 (B, O + 16#68# + K, U8 (16#A0# + K));
         end loop;
         --  s_volume_name (0x78 .. 0x87)
         for K in 0 .. Natural'Min (Volume_Label'Length, 16) - 1 loop
            B (O + 16#78# + K) :=
              U8 (Character'Pos (Volume_Label (Volume_Label'First + K)));
         end loop;
      end;
      Write_Block (Dev, 0, B);

      ----------------------------------------------------------------------
      --  Block 1: the group descriptor table (one 32-byte descriptor).
      ----------------------------------------------------------------------
      B := [others => 0];
      Put_U32 (B, 16#00#, BBmp_Blk);                   --  bg_block_bitmap_lo
      Put_U32 (B, 16#04#, IBmp_Blk);                   --  bg_inode_bitmap_lo
      Put_U32 (B, 16#08#, ITbl_Blk);                   --  bg_inode_table_lo
      Put_U16 (B, 16#0C#, U16 (Free_Blocks and 16#FFFF#));   --  bg_free_blocks_count_lo
      Put_U16 (B, 16#0E#, U16 (Free_Inodes and 16#FFFF#));   --  bg_free_inodes_count_lo
      Put_U16 (B, 16#10#, 2);                          --  bg_used_dirs_count_lo (/, l+f)
      Write_Block (Dev, GDT_Blk, B);

      ----------------------------------------------------------------------
      --  Block 2: block bitmap.  Used: blocks 0 .. Used_Blks-1; padding:
      --  blocks T .. BPG-1 (do not exist).  The rest are free.
      ----------------------------------------------------------------------
      B := [others => 0];
      Set_Bits (B, 0, Natural (Used_Blks) - 1);
      Set_Bits (B, Natural (T), BPG - 1);
      Write_Block (Dev, BBmp_Blk, B);

      ----------------------------------------------------------------------
      --  Block 3: inode bitmap.  Used: inodes 1 .. 11 (bits 0 .. 10);
      --  padding: inodes I+1 .. BPG (bits I .. BPG-1).
      ----------------------------------------------------------------------
      B := [others => 0];
      Set_Bits (B, 0, Used_Inodes - 1);
      Set_Bits (B, Natural (I), BPG - 1);
      Write_Block (Dev, IBmp_Blk, B);

      ----------------------------------------------------------------------
      --  Inode table.  Block 0 of it holds inodes 1 .. 16: root (2) and
      --  lost+found (11) are real, the reserved ones stay zeroed.  The rest of
      --  the table is all-free (zero).
      ----------------------------------------------------------------------
      B := [others => 0];
      --  root: dir, 0755, links = 2 (".","..") + 1 subdir (lost+found)
      Put_Inode (B, (Root_Ino - 1) * ISz,
                 Mode => 16#41ED#, Links => 3, Size => BS, Blk0 => Root_Blk);
      --  lost+found: dir, 0700, links = 2 (".", entry in root)
      Put_Inode (B, (LPF_Ino - 1) * ISz,
                 Mode => 16#41C0#, Links => 2, Size => BS, Blk0 => LPF_Blk);
      Write_Block (Dev, ITbl_Blk, B);
      B := [others => 0];
      for K in 1 .. IT - 1 loop
         Write_Block (Dev, ITbl_Blk + K, B);
      end loop;

      ----------------------------------------------------------------------
      --  Root directory block: ".", "..", "lost+found".
      ----------------------------------------------------------------------
      B := [others => 0];
      Put_Dirent (B, 0,  Root_Ino, 12, ".");
      Put_Dirent (B, 12, Root_Ino, 12, "..");
      Put_Dirent (B, 24, LPF_Ino, U16 (BS - 24), "lost+found");
      Write_Block (Dev, Root_Blk, B);

      ----------------------------------------------------------------------
      --  lost+found directory block: ".", "..".
      ----------------------------------------------------------------------
      B := [others => 0];
      Put_Dirent (B, 0,  LPF_Ino, 12, ".");
      Put_Dirent (B, 12, Root_Ino, U16 (BS - 12), "..");
      Write_Block (Dev, LPF_Blk, B);
   end Format;

end ESP32S3.Ext4.Mkfs;
