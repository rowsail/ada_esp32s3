with Interfaces; use Interfaces;
with ESP32S3.Ext4.CRC32C;

package body ESP32S3.Ext4.Superblock with SPARK_Mode => On is

   Magic : constant U16 := 16#EF53#;

   procedure Read (Dev : ESP32S3.Block_Dev.Device; SB : out Info)
     with SPARK_Mode => Off is
      --  The superblock lives at byte offset 1024 = sectors 2 and 3.
      Buf : Byte_Array (0 .. 1023);
      Sec : ESP32S3.Block_Dev.Sector;
      Rev : U32;
      Log : U32;
      DSz : U16;
   begin
      ESP32S3.Block_Dev.Read_Sector (Dev, 2, Sec);
      Buf (0 .. 511) := Byte_Array (Sec);
      ESP32S3.Block_Dev.Read_Sector (Dev, 3, Sec);
      Buf (512 .. 1023) := Byte_Array (Sec);

      if Get_U16 (Buf, 16#38#) /= Magic then
         raise Corrupt with "not an ext2/3/4 filesystem (bad superblock magic)";
      end if;

      Log := Get_U32 (Buf, 16#18#);
      if Log > 6 then
         --  ext4 block size is 1 KiB .. 64 KiB (log 0..6);
         raise Corrupt          --  a larger shift would wrap Block_Size to 0 (then
           with "ext4 superblock: unsupported block size (s_log_block_size > 6)";
      end if;                   --  divide-by-zero) or overflow the Natural below
      SB.Block_Size := Natural (Shift_Left (U32 (1024), Natural (Log)));
      SB.First_Data_Block := Get_U32 (Buf, 16#14#);
      SB.Blocks_Per_Group := Get_U32 (Buf, 16#20#);
      SB.Inodes_Per_Group := Get_U32 (Buf, 16#28#);
      if SB.Blocks_Per_Group = 0 or else SB.Inodes_Per_Group = 0 then
         raise Corrupt with "ext4 superblock: zero blocks/inodes per group";
      end if;
      SB.Inodes_Count := Get_U32 (Buf, 16#00#);
      SB.Blocks_Count := U64 (Get_U32 (Buf, 16#04#));
      SB.Free_Blocks := U64 (Get_U32 (Buf, 16#0C#));
      SB.Free_Inodes := Get_U32 (Buf, 16#10#);
      SB.Feature_Compat := Get_U32 (Buf, 16#5C#);
      SB.Feature_Incompat := Get_U32 (Buf, 16#60#);
      SB.Feature_RO_Compat := Get_U32 (Buf, 16#64#);

      Rev := Get_U32 (Buf, 16#4C#);
      if Rev >= 1 then
         SB.Inode_Size := Natural (Get_U16 (Buf, 16#58#));
      else
         SB.Inode_Size := 128;
      end if;
      --  Inode size: a power of two, 128 .. block size (Inode.Read sizes its
      --  buffer from this and divides by Inodes_Per_Group with it).
      if SB.Inode_Size < 128
        or else SB.Inode_Size > SB.Block_Size
        or else (U32 (SB.Inode_Size) and (U32 (SB.Inode_Size) - 1)) /= 0
      then
         raise Corrupt with "ext4 superblock: bad inode size";
      end if;

      if Is_64Bit (SB) then
         SB.Blocks_Count := SB.Blocks_Count or Shift_Left (U64 (Get_U32 (Buf, 16#150#)), 32);
         SB.Free_Blocks := SB.Free_Blocks or Shift_Left (U64 (Get_U32 (Buf, 16#158#)), 32);
         DSz := Get_U16 (Buf, 16#FE#);
         SB.Desc_Size := (if DSz = 0 then 32 else Natural (DSz));
      else
         SB.Desc_Size := 32;
      end if;
      --  Group_Desc.Read decodes a 32- or 64-byte descriptor into a fixed buffer;
      --  reject any other size rather than overrun / silently short-read it.
      if SB.Desc_Size /= 32 and then SB.Desc_Size /= 64 then
         raise Corrupt with "ext4 superblock: unsupported group-descriptor size";
      end if;

      --  Number of block groups = ceil((blocks - first_data_block) / per_group).
      if SB.Blocks_Count <= U64 (SB.First_Data_Block) then
         raise Corrupt with "ext4 superblock: blocks_count <= first_data_block";
      end if;
      declare
         Span : constant U64 := SB.Blocks_Count - U64 (SB.First_Data_Block);
         Per  : constant U64 := U64 (SB.Blocks_Per_Group);   --  /= 0 (checked above)
      begin
         SB.Groups_Count := U32 ((Span + Per - 1) / Per);
      end;

      --  metadata_csum: validate the superblock checksum and derive the per-fs
      --  seed used to verify group descriptors, inodes, extents and dir tails.
      SB.Has_Csum := Has_Metadata_Csum (SB);
      if SB.Has_Csum then
         declare
            Stored : constant U32 := Get_U32 (Buf, 16#3FC#);
            Calc   : constant U32 := CRC32C.Update (16#FFFF_FFFF#, Buf (0 .. 16#3FB#));
         begin
            if Calc /= Stored then
               raise Bad_Checksum with "superblock checksum mismatch";
            end if;
         end;

         if (SB.Feature_Incompat and Incompat_Csum_Seed) /= 0 then
            SB.Csum_Seed := Get_U32 (Buf, 16#270#);       --  s_checksum_seed

         else
            SB.Csum_Seed :=                                --  crc32c(~0, uuid)
              CRC32C
                .Update (16#FFFF_FFFF#, Buf (16#68# .. 16#77#));
         end if;
      end if;
   end Read;

   procedure Encode (SB : Info; Buf : in out Byte_Array; Base : Natural) is
   begin
      Put_U32 (Buf, Base + 16#0C#, U32 (SB.Free_Blocks and 16#FFFF_FFFF#));
      Put_U32 (Buf, Base + 16#10#, SB.Free_Inodes);
      Put_U32 (Buf, Base + 16#60#, SB.Feature_Incompat);
      if Is_64Bit (SB) then
         Put_U32 (Buf, Base + 16#158#, U32 (Shift_Right (SB.Free_Blocks, 32)));
      end if;
      if SB.Has_Csum then
         Put_U32
           (Buf, Base + 16#3FC#,
            CRC32C.Update
              (16#FFFF_FFFF#, Buf (Buf'First + Base .. Buf'First + Base + 16#3FB#)));
      end if;
   end Encode;

   procedure Sync (Dev : ESP32S3.Block_Dev.Device; SB : Info)
     with SPARK_Mode => Off is
      Buf : Byte_Array (0 .. 1023);
      Sec : ESP32S3.Block_Dev.Sector;
   begin
      ESP32S3.Block_Dev.Read_Sector (Dev, 2, Sec);
      Buf (0 .. 511) := Byte_Array (Sec);
      ESP32S3.Block_Dev.Read_Sector (Dev, 3, Sec);
      Buf (512 .. 1023) := Byte_Array (Sec);

      Encode (SB, Buf, 0);

      Sec := ESP32S3.Block_Dev.Sector (Buf (0 .. 511));
      ESP32S3.Block_Dev.Write_Sector (Dev, 2, Sec);
      Sec := ESP32S3.Block_Dev.Sector (Buf (512 .. 1023));
      ESP32S3.Block_Dev.Write_Sector (Dev, 3, Sec);
   end Sync;

   procedure Require_Supported (SB : Info; Handled : U32)
     with SPARK_Mode => Off is
   begin
      if (SB.Feature_Incompat and not Handled) /= 0 then
         raise Unsupported_Feature
           with
             "ext incompat feature bit(s) not implemented:"
             & U32'Image (SB.Feature_Incompat and not Handled);
      end if;
   end Require_Supported;

end ESP32S3.Ext4.Superblock;
