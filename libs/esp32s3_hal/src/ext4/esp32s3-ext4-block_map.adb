with Interfaces; use Interfaces;
with ESP32S3.Ext4.Block_Cache;

package body ESP32S3.Ext4.Block_Map with SPARK_Mode => On is

   --  ==== Pure, SPARK-proved decode helpers ================================
   --  The classic block-map and extent-tree field decoding, split out of the
   --  I/O ops below so their fixed-offset byte arithmetic is proved in-bounds
   --  and overflow-free; the block-device reads and `raise Corrupt` stay in
   --  the Off callers.

   --  One of the inode's 15 block-map pointer slots (0..11 direct, 12/13/14
   --  the single/double/triple indirect roots) from the 60-byte i_block.
   function Root_Ptr (I_Block : Byte_Array; K : Natural) return U32
   is (Get_U32 (I_Block, K * 4))
   with Pre => I_Block'Length >= 60 and then K <= 14;

   --  ext4 extent-node header (ext4_extent_header, 12 bytes; we read 8).
   type Extent_Header is record
      Magic   : U16;
      Entries : Natural;      --  eh_entries
      Depth   : Natural;      --  eh_depth (0 => leaf)
   end record;

   function Decode_Header (Raw : Byte_Array) return Extent_Header
   is (Extent_Header'(Magic   => Get_U16 (Raw, 0),
                      Entries => Natural (Get_U16 (Raw, 2)),
                      Depth   => Natural (Get_U16 (Raw, 6))))
   with Pre => Raw'Length >= 8;

   --  Entry capacity of a node: the root lives in the 60-byte i_block, an
   --  interior/leaf node fills a whole block.  A larger eh_entries is corrupt
   --  and, on the root, would overrun the i_block slice.
   function Max_Entries (Is_Root : Boolean; Block_Size : Natural) return Natural
   is (if Is_Root then (60 - 12) / 12 else (Block_Size - 12) / 12)
   with Pre => Block_Size >= 12;

   --  A leaf extent (ext4_extent, 12 bytes).
   type Leaf_Extent is record
      First_Block : U64;      --  ee_block: first file block this extent covers
      Length      : U64;      --  ee_len (top bit = "uninitialised" flag stripped)
      Start       : U64;      --  ee_start_hi:ee_start_lo physical start
   end record;

   function Decode_Leaf (Raw : Byte_Array) return Leaf_Extent
   is (Leaf_Extent'(
         First_Block => U64 (Get_U32 (Raw, 0)),
         Length      => U64 (if Get_U16 (Raw, 4) > 32768
                             then Get_U16 (Raw, 4) - 32768
                             else Get_U16 (Raw, 4)),
         Start       => U64 (Get_U32 (Raw, 8))
                        or Shift_Left (U64 (Get_U16 (Raw, 6)), 32)))
   with Pre => Raw'Length >= 12;

   --  An interior index entry (ext4_extent_idx, 12 bytes).
   type Index_Extent is record
      First_Block : U64;      --  ei_block
      Child       : U64;      --  ei_leaf_hi:ei_leaf_lo child node block
   end record;

   function Decode_Index (Raw : Byte_Array) return Index_Extent
   is (Index_Extent'(
         First_Block => U64 (Get_U32 (Raw, 0)),
         Child       => U64 (Get_U32 (Raw, 4))
                        or Shift_Left (U64 (Get_U16 (Raw, 8)), 32)))
   with Pre => Raw'Length >= 12;

   --  ==== I/O ops (out of SPARK: Block_Cache reads + raise Corrupt) ========
   --  Forward declarations carrying SPARK_Mode => Off: each is a function with
   --  an in-out parameter (legal Ada, outside the SPARK subset), so an explicit
   --  Off declaration keeps it out of analysis.
   function Ptr_At (V : in out Volume.Context; Blk : Block_Number; Index : U64) return Block_Number
   with SPARK_Mode => Off;
   function Indirect (V : in out Volume.Context; I : Inode.Info; L_Block : U64) return Block_Number
   with SPARK_Mode => Off;
   function Extents (V : in out Volume.Context; I : Inode.Info; L_Block : U64) return Block_Number
   with SPARK_Mode => Off;

   --  Read the Index-th 32-bit block pointer from pointer-block Blk.
   function Ptr_At (V : in out Volume.Context; Blk : Block_Number; Index : U64) return Block_Number
   with SPARK_Mode => Off
   is
      T : Byte_Array (0 .. 3);
   begin
      if Blk = 0 then
         return 0;                       --  hole: the whole subtree is absent

      end if;
      ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Blk, Natural (Index) * 4, T);
      return Block_Number (Get_U32 (T, 0));
   end Ptr_At;

   --  Classic 12-direct + single/double/triple-indirect mapping.
   function Indirect (V : in out Volume.Context; I : Inode.Info; L_Block : U64) return Block_Number
   with SPARK_Mode => Off
   is
      PPB : constant U64 := U64 (V.SB.Block_Size) / 4;   --  pointers per block
      L   : U64 := L_Block;
   begin
      if L < 12 then
         return Block_Number (Root_Ptr (I.I_Block, Natural (L)));
      end if;
      L := L - 12;

      if L < PPB then
         --  single indirect
         return Ptr_At (V, Block_Number (Root_Ptr (I.I_Block, 12)), L);
      end if;
      L := L - PPB;

      if L < PPB * PPB then
         --  double indirect
         declare
            D1  : constant Block_Number := Block_Number (Root_Ptr (I.I_Block, 13));
            Mid : constant Block_Number := Ptr_At (V, D1, L / PPB);
         begin
            return Ptr_At (V, Mid, L mod PPB);
         end;
      end if;
      L := L - PPB * PPB;

      declare
         --  triple indirect
         T1 : constant Block_Number := Block_Number (Root_Ptr (I.I_Block, 14));
         A  : constant Block_Number := Ptr_At (V, T1, L / (PPB * PPB));
         B  : constant Block_Number := Ptr_At (V, A, (L / PPB) mod PPB);
      begin
         return Ptr_At (V, B, L mod PPB);
      end;
   end Indirect;

   --  ext4 extent-tree mapping.  The root header+entries live in the inode's
   --  60-byte i_block; interior/leaf nodes are full blocks read from the cache.
   Extent_Magic : constant U16 := 16#F30A#;

   function Extents (V : in out Volume.Context; I : Inode.Info; L_Block : U64) return Block_Number
   with SPARK_Mode => Off
   is
      --  Read Into'Length bytes at Off of the current node (root = inode bytes).
      procedure Node_Bytes (Node : Block_Number; Off : Natural; Into : out Byte_Array) is
      begin
         if Node = 0 then
            Into := I.I_Block (Off .. Off + Into'Length - 1);
         else
            ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Node, Off, Into);
         end if;
      end Node_Bytes;

      BS         : constant Natural := V.SB.Block_Size;
      Node       : Block_Number := 0;             --  0 => the inode's i_block root
      Hdr        : Byte_Array (0 .. 11);
      Ent        : Byte_Array (0 .. 11);
      Prev_Depth : Integer := -1;           --  depth of the node we descended from
   begin
      loop
         Node_Bytes (Node, 0, Hdr);
         if Decode_Header (Hdr).Magic /= Extent_Magic then
            raise Corrupt with "bad extent-tree magic";
         end if;
         declare
            Entries : constant Natural := Decode_Header (Hdr).Entries;
            Depth   : constant Natural := Decode_Header (Hdr).Depth;
            Max_Ent : constant Natural := Max_Entries (Node = 0, BS);
         begin
            --  ext4 extent trees are at most 5 levels deep, and each descent must
            --  strip exactly one level: this makes the loop provably terminate, so
            --  a cyclic or over-deep tree raises Corrupt instead of hanging.
            if Depth > 5 or else Entries > Max_Ent then
               raise Corrupt with "extent node: bad depth/entry count";
            end if;
            if Prev_Depth >= 0 and then Depth /= Prev_Depth - 1 then
               raise Corrupt with "extent tree: depth not strictly decreasing";
            end if;
            if Depth = 0 then
               --  Leaf: find the extent covering L_Block.
               for E in 0 .. Entries - 1 loop
                  Node_Bytes (Node, 12 + E * 12, Ent);
                  declare
                     LE : constant Leaf_Extent := Decode_Leaf (Ent);
                  begin
                     if L_Block >= LE.First_Block
                       and then L_Block < LE.First_Block + LE.Length
                     then
                        return Block_Number (LE.Start + (L_Block - LE.First_Block));
                     end if;
                  end;
               end loop;
               return 0;                    --  not covered: sparse hole

            else
               --  Interior: descend into the last index whose ei_block <= L_Block.
               declare
                  Child : Block_Number := 0;
                  Found : Boolean := False;
               begin
                  for E in 0 .. Entries - 1 loop
                     Node_Bytes (Node, 12 + E * 12, Ent);
                     declare
                        IE : constant Index_Extent := Decode_Index (Ent);
                     begin
                        if IE.First_Block <= L_Block then
                           Child := Block_Number (IE.Child);
                           Found := True;
                        end if;
                     end;
                  end loop;
                  if not Found then
                     return 0;
                  end if;
                  Prev_Depth := Depth;       --  next node must be Depth-1
                  Node := Child;             --  loop down a level
               end;
            end if;
         end;
      end loop;
   end Extents;

   function Logical_To_Physical
     (V : in out Volume.Context; I : Inode.Info; L_Block : U64) return Block_Number
   with SPARK_Mode => Off is
   begin
      if Inode.Uses_Extents (I) then
         return Extents (V, I, L_Block);
      end if;
      return Indirect (V, I, L_Block);
   end Logical_To_Physical;

end ESP32S3.Ext4.Block_Map;
