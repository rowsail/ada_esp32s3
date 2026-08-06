with Interfaces; use Interfaces;
with ESP32S3.Block_Dev;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Block_Map;

package body ESP32S3.Ext4.File is

   use type ESP32S3.Block_Dev.Sector_Index;

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
            Chunk   : Natural :=
              Natural (Chunk_Bytes (BS, U64 (B_Off), Want, Done));
            Dst_Lo  : constant Natural := Into'First + Natural (Done);
            Phys    : constant Block_Number := Block_Map.Logical_To_Physical (V, I, L_Block);
         begin
            if Phys = 0 then
               Into (Dst_Lo .. Dst_Lo + Chunk - 1) := [others => 0];
            elsif B_Off = 0 and then U64 (Chunk) = BS
              and then not Block_Cache.Resident (V.Cache, Phys)
            then
               --  A whole block that is not in the cache: stream it -- and
               --  every physically CONSECUTIVE whole block after it -- from
               --  the device in one command, bypassing the cache.  On SD one
               --  N-block read costs the card's access latency once; going
               --  through the cache costs it once per 4 KiB block (and
               --  evicts the metadata blocks a big file drags through an
               --  8-entry cache).  Resident blocks are excluded from runs so
               --  a dirty cached copy is never bypassed.
               declare
                  Run_Blocks : U64 := 1;
               begin
                  while (Run_Blocks + 1) * BS <= Want - Done loop
                     declare
                        Next : constant Block_Number :=
                          Block_Map.Logical_To_Physical (V, I, L_Block + Run_Blocks);
                     begin
                        exit when Next = 0
                          or else Next /= Phys + Block_Number (Run_Blocks)
                          or else Block_Cache.Resident (V.Cache, Next);
                        Run_Blocks := Run_Blocks + 1;
                     end;
                  end loop;
                  declare
                     Bytes : constant Natural := Natural (Run_Blocks * BS);
                     Run   : ESP32S3.Block_Dev.Sector_Run (0 .. Bytes - 1)
                       with Import, Address => Into (Dst_Lo)'Address;
                     First : constant ESP32S3.Block_Dev.Sector_Index :=
                       ESP32S3.Block_Dev.Sector_Index (Phys)
                       * ESP32S3.Block_Dev.Sector_Index (BS / 512);
                  begin
                     ESP32S3.Block_Dev.Read_Sectors (V.Dev, First, Run);
                     Chunk := Bytes;
                  exception
                     when others =>
                        --  A failed run read (e.g. the drain loop preempted
                        --  long enough to overrun the controller FIFO) is
                        --  retried one block at a time through the cache.
                        ESP32S3.Ext4.Block_Cache.Read_At
                          (V.Cache, Phys, 0, Into (Dst_Lo .. Dst_Lo + Chunk - 1));
                  end;
               end;
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
