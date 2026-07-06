with Interfaces; use Interfaces;
with ESP32S3.Ext4.Block_Cache;

package body ESP32S3.Ext4.Group_Desc with SPARK_Mode => On is

   --  Pure buffer<->record serialization, split out of Read/Write so the offset
   --  arithmetic is SPARK-proved; the block-device I/O stays in the Off callers.
   --  A descriptor is 32 or 64 bytes (DSz); the hi halves exist only when 64-bit.
   function Decode (Raw : Byte_Array; DSz : Natural) return Desc
     with Pre => Raw'Length >= 64
   is
      --  Assemble a 64-bit pointer / 32-bit count from lo (at Lo_Off) and, when
      --  the descriptor is 64-bit, hi (at Hi_Off).
      function Ptr (Lo_Off, Hi_Off : Natural) return Block_Number
        with Pre => Lo_Off <= Raw'Length - 4 and then Hi_Off <= Raw'Length - 4
      is
         V64 : U64 := U64 (Get_U32 (Raw, Lo_Off));
      begin
         if DSz >= 64 then
            V64 := V64 or Shift_Left (U64 (Get_U32 (Raw, Hi_Off)), 32);
         end if;
         return Block_Number (V64);
      end Ptr;

      function Cnt (Lo_Off, Hi_Off : Natural) return U32
        with Pre => Lo_Off <= Raw'Length - 2 and then Hi_Off <= Raw'Length - 2
      is
         V32 : U32 := U32 (Get_U16 (Raw, Lo_Off));
      begin
         if DSz >= 64 then
            V32 := V32 or Shift_Left (U32 (Get_U16 (Raw, Hi_Off)), 16);
         end if;
         return V32;
      end Cnt;

      D : Desc;
   begin
      D.Block_Bitmap := Ptr (16#00#, 16#20#);
      D.Inode_Bitmap := Ptr (16#04#, 16#24#);
      D.Inode_Table := Ptr (16#08#, 16#28#);
      D.Free_Blocks := Cnt (16#0C#, 16#2C#);
      D.Free_Inodes := Cnt (16#0E#, 16#2E#);
      D.Used_Dirs := Cnt (16#10#, 16#30#);
      return D;
   end Decode;

   procedure Encode (D : Desc; DSz : Natural; Raw : in out Byte_Array)
     with Pre => Raw'Length >= 64
   is
   begin
      Put_U16 (Raw, 16#0C#, U16 (D.Free_Blocks and 16#FFFF#));
      Put_U16 (Raw, 16#0E#, U16 (D.Free_Inodes and 16#FFFF#));
      Put_U16 (Raw, 16#10#, U16 (D.Used_Dirs and 16#FFFF#));
      if DSz >= 64 then
         Put_U16 (Raw, 16#2C#, U16 (Shift_Right (D.Free_Blocks, 16) and 16#FFFF#));
         Put_U16 (Raw, 16#2E#, U16 (Shift_Right (D.Free_Inodes, 16) and 16#FFFF#));
         Put_U16 (Raw, 16#30#, U16 (Shift_Right (D.Used_Dirs, 16) and 16#FFFF#));
      end if;
   end Encode;

   procedure Read (V : in out Volume.Context; Group : U32; D : out Desc)
     with SPARK_Mode => Off
   is
      BS   : constant Natural := V.SB.Block_Size;
      DSz  : constant Natural := V.SB.Desc_Size;
      Byte : constant U64 := U64 (Group) * U64 (DSz);
      Blk  : constant Block_Number := Table_Start (V) + Block_Number (Byte / U64 (BS));
      Off  : constant Natural := Natural (Byte mod U64 (BS));
      Raw  : Byte_Array (0 .. 63);
   begin
      ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Blk, Off, Raw (0 .. DSz - 1));
      D := Decode (Raw, DSz);
   end Read;

   --  Geometry of group G's descriptor (block + offset within it).
   procedure Locate (V : Volume.Context; Group : U32; Blk : out Block_Number; Off : out Natural)
     with SPARK_Mode => Off is
      BS   : constant Natural := V.SB.Block_Size;
      Byte : constant U64 := U64 (Group) * U64 (V.SB.Desc_Size);
   begin
      Blk := Table_Start (V) + Block_Number (Byte / U64 (BS));
      Off := Natural (Byte mod U64 (BS));
   end Locate;

   procedure Write (V : in out Volume.Context; Group : U32; D : Desc)
     with SPARK_Mode => Off is
      DSz : constant Natural := V.SB.Desc_Size;
      Blk : Block_Number;
      Off : Natural;
      Raw : Byte_Array (0 .. 63);
   begin
      Locate (V, Group, Blk, Off);
      ESP32S3.Ext4.Block_Cache.Read_At (V.Cache, Blk, Off, Raw (0 .. DSz - 1));

      Encode (D, DSz, Raw);

      ESP32S3.Ext4.Block_Cache.Write_At (V.Cache, Blk, Off, Raw (0 .. DSz - 1));
   end Write;

end ESP32S3.Ext4.Group_Desc;
