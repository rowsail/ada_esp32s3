with ESP32S3.Log;

package body FTP_Sinks is

   Count : Natural := 0;       --  bytes seen by Count_Chunk

   procedure Reset_Count is
   begin
      Count := 0;
   end Reset_Count;

   function Bytes_Seen return Natural
   is (Count);

   procedure Count_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array) is
      pragma Unreferenced (Ctx);
   begin
      Count := Count + Chunk'Length;
   end Count_Chunk;

   procedure Put_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array) is
      pragma Unreferenced (Ctx);
   begin
      for B of Chunk loop
         ESP32S3.Log.Put (Character'Val (Natural (B)));
      end loop;
   end Put_Chunk;

end FTP_Sinks;
