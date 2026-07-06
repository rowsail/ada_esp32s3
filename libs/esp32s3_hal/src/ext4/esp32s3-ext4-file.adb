with Interfaces; use Interfaces;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Block_Map;

package body ESP32S3.Ext4.File is

   --  Pure size/offset arithmetic, split out of Read so it is SPARK-proved
   --  underflow-free; the block-device I/O stays in Read below.  These two
   --  helpers carry SPARK_Mode => On individually (rather than the whole
   --  package) because Read's Post contract cannot coexist with SPARK_Mode =>
   --  Off on it under an On package -- so only the pure helpers opt in.

   --  Bytes readable starting at Offset: 0 at/after EOF, else the request
   --  clamped to what remains of the file.
   function Readable (Size, Offset, Request : U64) return U64
   is (if Offset >= Size then 0 else U64'Min (Request, Size - Offset))
   with SPARK_Mode => On;

   --  Bytes to copy this iteration: fill to the block boundary or to whatever
   --  of the request is still outstanding, whichever is smaller.
   function Chunk_Bytes (Block_Size, Block_Off, Want, Done : U64) return U64
   is (U64'Min (Block_Size - Block_Off, Want - Done))
   with Pre => Block_Off < Block_Size and then Done < Want, SPARK_Mode => On;

   procedure Read
     (V      : in out Volume.Context;
      I      : Inode.Info;
      Offset : U64;
      Into   : out Byte_Array;
      Last   : out Natural)
   is
      BS    : constant U64 := U64 (V.SB.Block_Size);
      Want  : constant U64 := Readable (I.Size, Offset, U64 (Into'Length));
      Done  : U64 := 0;
      Pos   : U64 := Offset;
   begin
      while Done < Want loop
         declare
            L_Block : constant U64 := Pos / BS;
            B_Off   : constant Natural := Natural (Pos mod BS);
            Chunk   : constant Natural :=
              Natural (Chunk_Bytes (BS, U64 (B_Off), Want, Done));
            Dst_Lo  : constant Natural := Into'First + Natural (Done);
            Phys    : constant Block_Number := Block_Map.Logical_To_Physical (V, I, L_Block);
         begin
            if Phys = 0 then
               Into (Dst_Lo .. Dst_Lo + Chunk - 1) := [others => 0];
            else
               ESP32S3.Ext4.Block_Cache.Read_At
                 (V.Cache, Phys, B_Off, Into (Dst_Lo .. Dst_Lo + Chunk - 1));
            end if;
            Done := Done + U64 (Chunk);
            Pos := Pos + U64 (Chunk);
         end;
      end loop;

      Last := Natural (Want);
   end Read;

end ESP32S3.Ext4.File;
