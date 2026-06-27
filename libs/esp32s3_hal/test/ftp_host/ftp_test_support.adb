package body FTP_Test_Support is

   Max_Acc     : constant := 65536;
   Acc_Data    : FTP_Client.Byte_Array (0 .. Max_Acc - 1);
   Acc_Len     : Natural := 0;
   Upload_Done : Boolean := False;

   procedure Reset_Acc is
   begin
      Acc_Len := 0;
   end Reset_Acc;

   procedure Append_Sink (Ctx : System.Address; Chunk : FTP_Client.Byte_Array) is
      pragma Unreferenced (Ctx);
   begin
      for B of Chunk loop
         if Acc_Len < Max_Acc then
            Acc_Data (Acc_Len) := B;
            Acc_Len := Acc_Len + 1;
         end if;
      end loop;
   end Append_Sink;

   function Acc_String return String is
      R : String (1 .. Acc_Len);
   begin
      for I in 0 .. Acc_Len - 1 loop
         R (I + 1) := Character'Val (Natural (Acc_Data (I)));
      end loop;
      return R;
   end Acc_String;

   procedure Reset_Upload is
   begin
      Upload_Done := False;
   end Reset_Upload;

   procedure Upload_Source (Ctx  : System.Address;
                            Buf  : out FTP_Client.Byte_Array;
                            Last : out Natural) is
      pragma Unreferenced (Ctx);
   begin
      Last := 0;
      if not Upload_Done then
         for I in Upload_Text'Range loop
            exit when Last >= Buf'Length;
            Buf (Buf'First + Last) := Character'Pos (Upload_Text (I));
            Last := Last + 1;
         end loop;
         Upload_Done := True;
      end if;
   end Upload_Source;

end FTP_Test_Support;
