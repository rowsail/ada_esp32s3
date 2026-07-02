with Interfaces; use Interfaces;
with ESP32S3.Log;

package body FTP_Print is

   --  Deterministic, position-dependent test byte (so a round-trip is verifiable).
   function Pattern (I : Natural) return Unsigned_8
   is (Unsigned_8 (I mod 256));

   Sent    : Natural := 0;       --  bytes already supplied by Test_Source
   V_Count : Natural := 0;       --  bytes checked by Verify_Chunk
   V_OK    : Boolean := True;     --  all checked bytes matched

   procedure Put_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array) is
      pragma Unreferenced (Ctx);
   begin
      for B of Chunk loop
         ESP32S3.Log.Put (Character'Val (Natural (B)));
      end loop;
   end Put_Chunk;

   procedure Reset_Source is
   begin
      Sent := 0;
   end Reset_Source;

   procedure Test_Source
     (Ctx : System.Address; Buf : out FTP_Client.Byte_Array; Last : out Natural)
   is
      pragma Unreferenced (Ctx);
   begin
      Last := 0;
      while Sent < Upload_Bytes and then Last < Buf'Length loop
         Buf (Buf'First + Last) := Pattern (Sent);
         Sent := Sent + 1;
         Last := Last + 1;
      end loop;
   end Test_Source;

   procedure Reset_Verify is
   begin
      V_Count := 0;
      V_OK := True;
   end Reset_Verify;

   procedure Verify_Chunk (Ctx : System.Address; Chunk : FTP_Client.Byte_Array) is
      pragma Unreferenced (Ctx);
   begin
      for B of Chunk loop
         if B /= Pattern (V_Count) then
            V_OK := False;
         end if;
         V_Count := V_Count + 1;
      end loop;
   end Verify_Chunk;

   function Verify_Count return Natural
   is (V_Count);
   function Verify_OK return Boolean
   is (V_OK);

end FTP_Print;
