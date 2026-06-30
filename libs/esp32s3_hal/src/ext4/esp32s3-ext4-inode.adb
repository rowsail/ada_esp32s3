with Interfaces; use Interfaces;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Group_Desc;
with ESP32S3.Ext4.CRC32C;

package body ESP32S3.Ext4.Inode is

   --  Block + offset of inode N within its group's inode table.
   procedure Locate (V : in out Volume.Context; N : Inode_Number;
                     Blk : out Block_Number; Off : out Natural)
   is
      BS     : constant Natural := V.SB.Block_Size;
      ISz    : constant Natural := V.SB.Inode_Size;
      Idx0   : constant U32     := U32 (N) - 1;
      Group  : constant U32     := Idx0 / V.SB.Inodes_Per_Group;
      In_Grp : constant U32     := Idx0 mod V.SB.Inodes_Per_Group;
      GD     : Group_Desc.Desc;
      By_Off : U64;
   begin
      if N < 1 then
         raise Corrupt with "inode number 0";
      end if;
      Group_Desc.Read (V, Group, GD);
      By_Off := U64 (In_Grp) * U64 (ISz);
      Blk    := GD.Inode_Table + Block_Number (By_Off / U64 (BS));
      Off    := Natural (By_Off mod U64 (BS));
   end Locate;

   --  metadata_csum over inode N's raw bytes: crc32c(fs_seed, le32(num),
   --  le32(generation), inode-with-csum-fields-zeroed).  Returns the 32-bit CRC.
   function Compute_Csum (V : Volume.Context; N : Inode_Number;
                          Raw : Byte_Array; ISz : Natural) return U32
   is
      Tmp : Byte_Array (0 .. ISz - 1) := Raw (Raw'First .. Raw'First + ISz - 1);
      Nb  : Byte_Array (0 .. 3);
      Gb  : Byte_Array (0 .. 3);
      Crc : U32;
   begin
      Put_U32 (Nb, 0, U32 (N));
      Put_U32 (Gb, 0, Get_U32 (Raw, 16#64#));
      Put_U16 (Tmp, 16#7C#, 0);
      if ISz > 128 then
         Put_U16 (Tmp, 16#82#, 0);
      end if;
      Crc := CRC32C.Update (V.SB.Csum_Seed, Nb);
      Crc := CRC32C.Update (Crc, Gb);
      Crc := CRC32C.Update (Crc, Tmp);
      return Crc;
   end Compute_Csum;

   function Has_Csum_Hi (ISz : Natural; Raw : Byte_Array) return Boolean is
     (ISz > 128 and then Get_U16 (Raw, 16#80#) >= 4);

   procedure Verify_Csum (V : Volume.Context; N : Inode_Number;
                          Raw : Byte_Array; ISz : Natural)
   is
      Crc    : constant U32 := Compute_Csum (V, N, Raw, ISz);
      Stored : U32 := U32 (Get_U16 (Raw, 16#7C#));
   begin
      if Has_Csum_Hi (ISz, Raw) then
         Stored := Stored or Shift_Left (U32 (Get_U16 (Raw, 16#82#)), 16);
         if Crc /= Stored then
            raise Bad_Checksum with "inode checksum mismatch";
         end if;
      elsif (Crc and 16#FFFF#) /= Stored then
         raise Bad_Checksum with "inode checksum mismatch";
      end if;
   end Verify_Csum;

   ----------
   -- Read --
   ----------

   procedure Read (V : in out Volume.Context; N : Inode_Number; I : out Info) is
      ISz : constant Natural := V.SB.Inode_Size;
      Blk : Block_Number;
      Off : Natural;
      Raw : Byte_Array (0 .. ISz - 1);   --  size to the actual inode (128..1024),
   begin                                 --  matching Write/Mark_Deleted
      Locate (V, N, Blk, Off);
      ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Blk, Off, Raw);

      I.Mode       := Get_U16 (Raw, 16#00#);
      I.Links      := Get_U16 (Raw, 16#1A#);
      I.Blocks_512 := U64 (Get_U32 (Raw, 16#1C#));
      I.Flags      := Get_U32 (Raw, 16#20#);
      I.I_Block    := Raw (16#28# .. 16#28# + 59);

      I.Size := U64 (Get_U32 (Raw, 16#04#));
      if (I.Mode and 16#F000#) = 16#8000# then
         I.Size := I.Size or Shift_Left (U64 (Get_U32 (Raw, 16#6C#)), 32);
      end if;

      if V.SB.Has_Csum then
         Verify_Csum (V, N, Raw, ISz);
      end if;
   end Read;

   -----------
   -- Write --
   -----------

   procedure Write (V     : in out Volume.Context;
                    N     : Inode_Number;
                    I     : Info;
                    Fresh : Boolean := False)
   is
      ISz : constant Natural := V.SB.Inode_Size;
      Blk : Block_Number;
      Off : Natural;
      Raw : Byte_Array (0 .. ISz - 1);
   begin
      Locate (V, N, Blk, Off);

      if Fresh then
         Raw := [others => 0];
         if ISz > 128 then
            Put_U16 (Raw, 16#80#, 32);          --  i_extra_isize
         end if;
      else
         ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Blk, Off, Raw);
      end if;

      Put_U16 (Raw, 16#00#, I.Mode);
      Put_U16 (Raw, 16#1A#, I.Links);
      Put_U32 (Raw, 16#1C#, U32 (I.Blocks_512 and 16#FFFF_FFFF#));
      Put_U32 (Raw, 16#20#, I.Flags);
      Put_U32 (Raw, 16#04#, U32 (I.Size and 16#FFFF_FFFF#));
      if (I.Mode and 16#F000#) = 16#8000# then
         Put_U32 (Raw, 16#6C#, U32 (Shift_Right (I.Size, 32)));
      end if;
      Raw (16#28# .. 16#28# + 59) := I.I_Block;

      if V.SB.Has_Csum then
         declare
            Crc : constant U32 := Compute_Csum (V, N, Raw, ISz);
         begin
            Put_U16 (Raw, 16#7C#, U16 (Crc and 16#FFFF#));
            if Has_Csum_Hi (ISz, Raw) then
               Put_U16 (Raw, 16#82#, U16 (Shift_Right (Crc, 16) and 16#FFFF#));
            end if;
         end;
      end if;

      ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Blk, Off, Raw);
   end Write;

   ------------------
   -- Mark_Deleted --
   ------------------

   procedure Mark_Deleted (V : in out Volume.Context; N : Inode_Number) is
      ISz : constant Natural := V.SB.Inode_Size;
      Blk : Block_Number;
      Off : Natural;
      Raw : Byte_Array (0 .. ISz - 1);
   begin
      Locate (V, N, Blk, Off);
      ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Blk, Off, Raw);
      Put_U16 (Raw, 16#1A#, 0);          --  i_links_count := 0
      --  i_dtime: a plausible timestamp, NOT a small value -- e2fsck reads a
      --  small i_dtime on a links=0 inode as an orphan-list next-inode pointer.
      Put_U32 (Raw, 16#14#, 16#6500_0000#);
      --  Blocks are already freed in the bitmap; a deleted inode must own none
      --  (otherwise e2fsck treats it as an orphan awaiting truncation).
      Put_U32 (Raw, 16#1C#, 0);          --  i_blocks_lo := 0
      Put_U32 (Raw, 16#04#, 0);          --  i_size_lo := 0
      Put_U32 (Raw, 16#6C#, 0);          --  i_size_high := 0
      for K in 0 .. 14 loop
         Put_U32 (Raw, 16#28# + K * 4, 0);   --  clear i_block[]
      end loop;
      if V.SB.Has_Csum then
         declare
            Crc : constant U32 := Compute_Csum (V, N, Raw, ISz);
         begin
            Put_U16 (Raw, 16#7C#, U16 (Crc and 16#FFFF#));
            if Has_Csum_Hi (ISz, Raw) then
               Put_U16 (Raw, 16#82#, U16 (Shift_Right (Crc, 16) and 16#FFFF#));
            end if;
         end;
      end if;
      ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Blk, Off, Raw);
   end Mark_Deleted;

end ESP32S3.Ext4.Inode;
