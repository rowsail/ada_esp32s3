with System;
with FTP_Client;

--  A library-level (closure-free) FTP data sink that prints each received chunk
--  to the console as text.  FTP_Client.Data_Sink is a library-level access type,
--  so the callback it points at must be library level too (No_Implicit_Dynamic_
--  Code) -- it cannot be nested in Main.
package FTP_Print is
   procedure Put_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array);
end FTP_Print;
