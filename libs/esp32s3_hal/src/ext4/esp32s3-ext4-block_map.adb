with Interfaces; use Interfaces;
with ESP32S3.Ext4.Block_Cache;

package body ESP32S3.Ext4.Block_Map is

   --  Read the Index-th 32-bit block pointer from pointer-block Blk.
   function Ptr_At (V : in out Volume.Context; Blk : Block_Number; Index : U64)
      return Block_Number
   is
      T : Byte_Array (0 .. 3);
   begin
      if Blk = 0 then
         return 0;                       --  hole: the whole subtree is absent
      end if;
      ESP32S3.Ext4.Block_Cache.Read_At
        (V.Cache, Blk, Natural (Index) * 4, T);
      return Block_Number (Get_U32 (T, 0));
   end Ptr_At;

   --  Classic 12-direct + single/double/triple-indirect mapping.
   function Indirect (V : in out Volume.Context; I : Inode.Info; L_Block : U64)
      return Block_Number
   is
      PPB : constant U64 := U64 (V.SB.Block_Size) / 4;   --  pointers per block
      L   : U64 := L_Block;
   begin
      if L < 12 then
         return Block_Number (Get_U32 (I.I_Block, Natural (L) * 4));
      end if;
      L := L - 12;

      if L < PPB then                                    --  single indirect
         return Ptr_At (V, Block_Number (Get_U32 (I.I_Block, 12 * 4)), L);
      end if;
      L := L - PPB;

      if L < PPB * PPB then                              --  double indirect
         declare
            D1  : constant Block_Number := Block_Number (Get_U32 (I.I_Block, 13 * 4));
            Mid : constant Block_Number := Ptr_At (V, D1, L / PPB);
         begin
            return Ptr_At (V, Mid, L mod PPB);
         end;
      end if;
      L := L - PPB * PPB;

      declare                                            --  triple indirect
         T1 : constant Block_Number := Block_Number (Get_U32 (I.I_Block, 14 * 4));
         A  : constant Block_Number := Ptr_At (V, T1, L / (PPB * PPB));
         B  : constant Block_Number := Ptr_At (V, A, (L / PPB) mod PPB);
      begin
         return Ptr_At (V, B, L mod PPB);
      end;
   end Indirect;

   --  ext4 extent-tree mapping.  The root header+entries live in the inode's
   --  60-byte i_block; interior/leaf nodes are full blocks read from the cache.
   Extent_Magic : constant U16 := 16#F30A#;

   function Extents (V : in out Volume.Context; I : Inode.Info; L_Block : U64)
      return Block_Number
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

      BS   : constant Natural := V.SB.Block_Size;
      Node : Block_Number := 0;             --  0 => the inode's i_block root
      Hdr  : Byte_Array (0 .. 11);
      Ent  : Byte_Array (0 .. 11);
      Prev_Depth : Integer := -1;           --  depth of the node we descended from
   begin
      loop
         Node_Bytes (Node, 0, Hdr);
         if Get_U16 (Hdr, 0) /= Extent_Magic then
            raise Corrupt with "bad extent-tree magic";
         end if;
         declare
            Entries : constant Natural := Natural (Get_U16 (Hdr, 2));
            Depth   : constant Natural := Natural (Get_U16 (Hdr, 6));
            --  Entry capacity: the root lives in the 60-byte i_block (4 entries
            --  max); an interior/leaf node fills a whole block.  A larger count is
            --  corrupt -- and on the root would overrun the 60-byte i_block slice.
            Max_Ent : constant Natural :=
                        (if Node = 0 then (60 - 12) / 12 else (BS - 12) / 12);
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
                     EE_Block : constant U64 := U64 (Get_U32 (Ent, 0));
                     Len_Raw  : constant U16 := Get_U16 (Ent, 4);
                     Len      : constant U64 :=
                                  U64 (if Len_Raw > 32768 then Len_Raw - 32768
                                       else Len_Raw);
                     Start    : constant U64 :=
                                  U64 (Get_U32 (Ent, 8))
                                  or Shift_Left (U64 (Get_U16 (Ent, 6)), 32);
                  begin
                     if L_Block >= EE_Block and then L_Block < EE_Block + Len then
                        return Block_Number (Start + (L_Block - EE_Block));
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
                        EI_Block : constant U64 := U64 (Get_U32 (Ent, 0));
                        Leaf     : constant U64 :=
                                     U64 (Get_U32 (Ent, 4))
                                     or Shift_Left (U64 (Get_U16 (Ent, 8)), 32);
                     begin
                        if EI_Block <= L_Block then
                           Child := Block_Number (Leaf);
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
     (V : in out Volume.Context; I : Inode.Info; L_Block : U64)
      return Block_Number is
   begin
      if Inode.Uses_Extents (I) then
         return Extents (V, I, L_Block);
      end if;
      return Indirect (V, I, L_Block);
   end Logical_To_Physical;

end ESP32S3.Ext4.Block_Map;
