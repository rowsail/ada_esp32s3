with System;
with FTP_Client;

--  Library-level (closure-free) FTP data sinks for the demo.  FTP_Client's
--  Data_Sink is a library-level access type, so the callbacks it points at must
--  be library level too (No_Implicit_Dynamic_Code) -- they cannot be nested in
--  Main.

package FTP_Sinks is

   --  Counting sink: total bytes received (for a download you don't want to
   --  print -- compare the count to the file's SIZE as a sanity check).
   procedure Reset_Count;
   function Bytes_Seen return Natural;
   procedure Count_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array);

   --  Printing sink: echo each chunk to the console as text (for a directory
   --  listing).
   procedure Put_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array);

end FTP_Sinks;
