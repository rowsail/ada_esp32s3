with Interfaces; use Interfaces;
with ESP32S3.Ext4.Block_Cache;
with ESP32S3.Ext4.Block_Map;

package body ESP32S3.Ext4.File is

   procedure Read
     (V      : in out Volume.Context;
      I      : Inode.Info;
      Offset : U64;
      Into   : out Byte_Array;
      Last   : out Natural)
   is
      BS    : constant U64 := U64 (V.SB.Block_Size);
      Avail : U64;
      Want  : U64;
      Done  : U64 := 0;
      Pos   : U64 := Offset;
   begin
      if Offset >= I.Size then
         Last := 0;
         return;
      end if;
      Avail := I.Size - Offset;
      Want := U64'Min (U64 (Into'Length), Avail);

      while Done < Want loop
         declare
            L_Block : constant U64 := Pos / BS;
            B_Off   : constant Natural := Natural (Pos mod BS);
            Chunk   : constant Natural := Natural (U64'Min (BS - U64 (B_Off), Want - Done));
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
