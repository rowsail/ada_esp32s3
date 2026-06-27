with ESP32S3.Log;

package body FTP_Print is

   procedure Put_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array) is
      pragma Unreferenced (Ctx);
   begin
      for B of Chunk loop
         ESP32S3.Log.Put (Character'Val (Natural (B)));
      end loop;
   end Put_Chunk;

end FTP_Print;
