with System;
with FTP_Client;

--  Library-level (closure-free) FTP callbacks.  FTP_Client's Data_Sink /
--  Data_Source are library-level access types, so the callbacks they point at
--  must be library level too (No_Implicit_Dynamic_Code) -- they cannot be nested
--  in Main.

package FTP_Print is

   --  Print sink: echo each received chunk to the console as text (text files,
   --  directory listings).
   procedure Put_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array);

   --  Upload SOURCE: supply Upload_Bytes of a deterministic test pattern, once
   --  (for the STOR send test).  Streamed in chunks, so the size needs no buffer.
   Upload_Bytes : constant := 1_048_576;     --  1 MiB
   procedure Reset_Source;
   procedure Test_Source
     (Ctx : System.Address; Buf : out FTP_Client.Byte_Array; Last : out Natural);

   --  Verify sink: check a download matches the Test_Source pattern (so the
   --  uploaded file can be read back and confirmed byte-exact, on the board).
   procedure Reset_Verify;
   procedure Verify_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array);
   function Verify_Count return Natural;     --  bytes checked so far
   function Verify_OK return Boolean;     --  all bytes matched the pattern

end FTP_Print;
