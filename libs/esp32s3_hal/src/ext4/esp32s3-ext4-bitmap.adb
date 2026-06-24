with Interfaces; use Interfaces;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Group_Desc;

package body ESP32S3.Ext4.Bitmap is

   --  TRIPWIRE counter (see the spec): frees that hit an already-clear bit.
   Phantom_Frees : Natural := 0;

   function  Phantom_Free_Count return Natural is (Phantom_Frees);
   procedure Reset_Phantom_Free_Count is
   begin
      Phantom_Frees := 0;
   end Reset_Phantom_Free_Count;

   --  Find the first 0 bit (0 .. Count-1) in bitmap block Bmp; set it; return its
   --  index, or -1 if the group is full.  One byte at a time -> no big buffer.
   function Claim_Bit (V : in out Volume.Context; Bmp : Block_Number; Count : U32)
      return Integer
   is
      Byte : Byte_Array (0 .. 0);
   begin
      for I in 0 .. Integer (Count) - 1 loop
         declare
            Byte_Idx : constant Natural := I / 8;
            Bit      : constant Natural := I mod 8;
         begin
            ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Bmp, Byte_Idx, Byte);
            if (Byte (0) and Shift_Left (U8 (1), Bit)) = 0 then
               Byte (0) := Byte (0) or Shift_Left (U8 (1), Bit);
               ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Bmp, Byte_Idx, Byte);
               return I;
            end if;
         end;
      end loop;
      return -1;
   end Claim_Bit;

   -----------------
   -- Alloc_Block --
   -----------------

   function Alloc_Block (V : in out Volume.Context) return Block_Number is
      GD  : Group_Desc.Desc;
      Bit : Integer;
   begin
      for G in 0 .. V.SB.Groups_Count - 1 loop
         Group_Desc.Read (V, G, GD);
         if GD.Free_Blocks > 0 then
            Bit := Claim_Bit (V, GD.Block_Bitmap, V.SB.Blocks_Per_Group);
            if Bit >= 0 then
               GD.Free_Blocks := GD.Free_Blocks - 1;
               Group_Desc.Write (V, G, GD);
               V.SB.Free_Blocks := V.SB.Free_Blocks - 1;
               return Block_Number (V.SB.First_Data_Block)
                      + Block_Number (G) * Block_Number (V.SB.Blocks_Per_Group)
                      + Block_Number (Bit);
            end if;
         end if;
      end loop;
      raise No_Space with "no free blocks";
   end Alloc_Block;

   -----------------
   -- Alloc_Inode --
   -----------------

   function Alloc_Inode (V : in out Volume.Context; As_Dir : Boolean)
      return Inode_Number
   is
      GD  : Group_Desc.Desc;
      Bit : Integer;
   begin
      for G in 0 .. V.SB.Groups_Count - 1 loop
         Group_Desc.Read (V, G, GD);
         if GD.Free_Inodes > 0 then
            Bit := Claim_Bit (V, GD.Inode_Bitmap, V.SB.Inodes_Per_Group);
            if Bit >= 0 then
               GD.Free_Inodes := GD.Free_Inodes - 1;
               if As_Dir then
                  GD.Used_Dirs := GD.Used_Dirs + 1;
               end if;
               Group_Desc.Write (V, G, GD);
               V.SB.Free_Inodes := V.SB.Free_Inodes - 1;
               --  Inode numbers are 1-based.
               return Inode_Number (G * V.SB.Inodes_Per_Group + U32 (Bit) + 1);
            end if;
         end if;
      end loop;
      raise No_Space with "no free inodes";
   end Alloc_Inode;

   --  Clear bit Index in bitmap block Bmp.  Returns True iff the bit was SET (a
   --  real free); on an ALREADY-clear bit it leaves the block untouched and
   --  returns False, so a double/phantom free becomes a no-op rather than a
   --  count corruption.  (Clear_Bit already reads the byte, so the test is free.)
   function Clear_Bit (V : in out Volume.Context; Bmp : Block_Number; Index : Natural)
      return Boolean
   is
      Byte_Idx : constant Natural := Index / 8;
      Bit      : constant Natural := Index mod 8;
      Mask     : constant U8 := Shift_Left (U8 (1), Bit);
      Byte     : Byte_Array (0 .. 0);
   begin
      ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Bmp, Byte_Idx, Byte);
      if (Byte (0) and Mask) = 0 then
         return False;                        --  already clear -> no-op
      end if;
      Byte (0) := Byte (0) and not Mask;
      ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Bmp, Byte_Idx, Byte);
      return True;
   end Clear_Bit;

   ----------------
   -- Free_Block --
   ----------------

   procedure Free_Block (V : in out Volume.Context; B : Block_Number) is
      Rel   : constant U64 := U64 (B) - U64 (V.SB.First_Data_Block);
      Group : constant U32 := U32 (Rel / U64 (V.SB.Blocks_Per_Group));
      Index : constant Natural := Natural (Rel mod U64 (V.SB.Blocks_Per_Group));
      GD    : Group_Desc.Desc;
   begin
      Group_Desc.Read (V, Group, GD);
      if Clear_Bit (V, GD.Block_Bitmap, Index) then
         GD.Free_Blocks := GD.Free_Blocks + 1;
         Group_Desc.Write (V, Group, GD);
         V.SB.Free_Blocks := V.SB.Free_Blocks + 1;
      else
         Phantom_Frees := Phantom_Frees + 1;   --  already free: no drift, but flag it
      end if;
   end Free_Block;

   ----------------
   -- Free_Inode --
   ----------------

   procedure Free_Inode (V : in out Volume.Context; N : Inode_Number;
                         Was_Dir : Boolean) is
      Idx0  : constant U32 := U32 (N) - 1;
      Group : constant U32 := Idx0 / V.SB.Inodes_Per_Group;
      Index : constant Natural := Natural (Idx0 mod V.SB.Inodes_Per_Group);
      GD    : Group_Desc.Desc;
   begin
      Group_Desc.Read (V, Group, GD);
      if Clear_Bit (V, GD.Inode_Bitmap, Index) then
         GD.Free_Inodes := GD.Free_Inodes + 1;
         if Was_Dir and then GD.Used_Dirs > 0 then
            GD.Used_Dirs := GD.Used_Dirs - 1;
         end if;
         Group_Desc.Write (V, Group, GD);
         V.SB.Free_Inodes := V.SB.Free_Inodes + 1;
      else
         Phantom_Frees := Phantom_Frees + 1;   --  already free: no drift, but flag it
      end if;
   end Free_Inode;

end ESP32S3.Ext4.Bitmap;
