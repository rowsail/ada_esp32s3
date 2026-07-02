with ESP32S3.Text_IO; use ESP32S3.Text_IO;

package body FS_Glue is

   use type ESP32S3.Ext4.U8;

   package Nat_IO is new Integer_IO (Natural);

   --  Decimal, no field padding (like C "%d").
   procedure Put_Dec (V : Natural) is
   begin
      Nat_IO.Put (V, Width => 1);
   end Put_Dec;

   --  Left-justified decimal in a field of Width (like C "%-Nd").
   procedure Put_Dec_LJ (V : Natural; Width : Natural) is
      S : String (1 .. 16);
      P : Natural := S'First;
   begin
      Nat_IO.Put (S, V);                                   --  right-justified
      while P < S'Last and then S (P) = ' ' loop
         P := P + 1;
      end loop;
      Put (S (P .. S'Last));                               --  the digits
      for J in 1 .. Width - (S'Last - P + 1) loop
         Put (' ');
      end loop;
   end Put_Dec_LJ;

   --  Left-justified string in a field of Width (like C "%-Ns").
   procedure Put_Str_LJ (S : String; Width : Natural) is
   begin
      Put (S);
      for J in 1 .. Width - S'Length loop
         Put (' ');
      end loop;
   end Put_Str_LJ;

   function Clean (Str : String) return String is
      Result : String (1 .. Str'Length);
   begin
      for I in Result'Range loop
         declare
            Char : constant Character := Str (Str'First + I - 1);
         begin
            Result (I) := (if Character'Pos (Char) in 32 .. 126 then Char else '.');
         end;
      end loop;
      return Result;
   end Clean;

   procedure Banner is
   begin
      Put_Line ("[ext4] pure-Ada ext4 over SDMMC (DAT3 via CH422G IO4), read-only");
   end Banner;

   procedure Card_R (Ok : Boolean) is
   begin
      Put_Line ("[ext4] SD init: " & (if Ok then "OK" else "FAILED"));
   end Card_R;

   procedure Mount_R (Ok : Boolean; Block_Size : Natural) is
   begin
      Put ("[ext4] mount: " & (if Ok then "OK" else "FAILED") & "   block size = ");
      Put_Dec (Block_Size);
      New_Line;
   end Mount_R;

   function Ftype_Name (T : ESP32S3.Ext4.U8) return String
   is (if T = 1 then "file" elsif T = 2 then "dir" elsif T = 7 then "link" else "?");

   --  One directory entry:  "[ext4]   %-4s ino=%-6d %s".
   procedure Entry_R (Name : String; Ino : Natural; Ftype : ESP32S3.Ext4.U8) is
   begin
      Put ("[ext4]   ");
      Put_Str_LJ (Ftype_Name (Ftype), 4);
      Put (" ino=");
      Put_Dec_LJ (Ino, 6);
      Put (" ");
      Put_Line (Name);
   end Entry_R;

   procedure File_R (Ok : Boolean; Size : Natural; Preview : String) is
   begin
      if not Ok then
         Put_Line ("[ext4] /hello.txt: not found");
         return;
      end if;
      Put ("[ext4] /hello.txt: ");
      Put_Dec (Size);
      Put (" bytes = """);
      Put (Preview);
      Put_Line ("""");
   end File_R;

   procedure Err_R (Stage : String) is
   begin
      Put_Line ("[ext4] ERROR: " & Stage);
   end Err_R;

   procedure Done is
   begin
      Put_Line ("[ext4] done.");
   end Done;

   procedure Visit (Name : String; Ino : ESP32S3.Ext4.Inode_Number; File_Type : ESP32S3.Ext4.U8) is
   begin
      Entry_R (Clean (Name), Natural (Ino), File_Type);
   end Visit;

end FS_Glue;
