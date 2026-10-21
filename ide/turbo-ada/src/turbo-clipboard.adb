with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with GNAT.OS_Lib;
with Turbo.Term;

package body Turbo.Clipboard is

   use Ada.Strings.Unbounded;
   use Ada.Strings.Wide_Wide_Unbounded;

   Content : Unbounded_Wide_Wide_String;

   Copy_Cmd, Paste_Cmd : Unbounded_String;   --  "": none
   Broken              : Boolean := False;   --  a copy failed: use Content

   function Base64 (S : String) return String is
      Alphabet : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      Result : String (1 .. ((S'Length + 2) / 3) * 4);
      R      : Positive := 1;
      I      : Positive := S'First;
      N      : Natural;
   begin
      while I <= S'Last loop
         N := Character'Pos (S (I)) * 65536;
         if I + 1 <= S'Last then
            N := N + Character'Pos (S (I + 1)) * 256;
         end if;
         if I + 2 <= S'Last then
            N := N + Character'Pos (S (I + 2));
         end if;
         Result (R) := Alphabet (N / 262144 + 1);
         Result (R + 1) := Alphabet ((N / 4096) mod 64 + 1);
         Result (R + 2) :=
           (if I + 1 <= S'Last then Alphabet ((N / 64) mod 64 + 1) else '=');
         Result (R + 3) :=
           (if I + 2 <= S'Last then Alphabet (N mod 64 + 1) else '=');
         R := R + 4;
         I := I + 3;
      end loop;
      return Result;
   end Base64;

   --  The helpers

   function On_Path (Program : String) return Boolean is
      use type GNAT.OS_Lib.String_Access;
      P : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path (Program);
   begin
      return Found : constant Boolean := P /= null do
         GNAT.OS_Lib.Free (P);
      end return;
   end On_Path;

   function Env (Name : String) return String is
     (if Ada.Environment_Variables.Exists (Name)
      then Ada.Environment_Variables.Value (Name) else "");

   --  No '$' in these, so they mean the same to sh and to cmd.exe.
   PS_Copy : constant String :=
     " -NoProfile -Command ""[Console]::InputEncoding=[Text.Encoding]::UTF8;"
     & " Set-Clipboard -Value ([Console]::In.ReadToEnd())""";
   PS_Paste : constant String :=
     " -NoProfile -Command ""[Console]::OutputEncoding=[Text.Encoding]::UTF8;"
     & " [Console]::Out.Write((Get-Clipboard -Raw))""";

   procedure Detect (Copy, Paste : out Unbounded_String) is
      procedure Use_Pair (C, P : String) is
      begin
         Copy := To_Unbounded_String (C);
         Paste := To_Unbounded_String (P);
      end Use_Pair;
   begin
      if Term.Is_Windows then
         Use_Pair ("powershell" & PS_Copy, "powershell" & PS_Paste);
      elsif Env ("WAYLAND_DISPLAY") /= "" and then On_Path ("wl-copy") then
         Use_Pair ("wl-copy", "wl-paste --no-newline");
      elsif Env ("DISPLAY") /= "" and then On_Path ("xclip") then
         Use_Pair ("xclip -selection clipboard -in", "xclip -selection clipboard -out");
      elsif Env ("DISPLAY") /= "" and then On_Path ("xsel") then
         Use_Pair ("xsel --clipboard --input", "xsel --clipboard --output");
      elsif On_Path ("pbcopy") then
         Use_Pair ("pbcopy", "pbpaste");
      elsif On_Path ("powershell.exe") then             --  WSL
         Use_Pair ("powershell.exe" & PS_Copy, "powershell.exe" & PS_Paste);
      else
         Use_Pair ("", "");
      end if;
   end Detect;

   procedure Configure (Copy_Command, Paste_Command : String) is
      Auto_Copy, Auto_Paste : Unbounded_String;
      function Pick (Given : String; Auto : Unbounded_String) return Unbounded_String is
        (if Given = "none" then Null_Unbounded_String
         elsif Given /= "" and then Given /= "auto" then To_Unbounded_String (Given)
         elsif Term.Is_Virtual then Null_Unbounded_String
         else Auto);
   begin
      if not Term.Is_Virtual then
         Detect (Auto_Copy, Auto_Paste);
      end if;
      Copy_Cmd := Pick (Copy_Command, Auto_Copy);
      Paste_Cmd := Pick (Paste_Command, Auto_Paste);
      Broken := False;
   end Configure;

   function Run (Command : String; Input_File, Output_File : String) return Boolean is
   --  Command through the shell, its standard input from Input_File, its
   --  standard output to Output_File, at most 2 s where timeout(1) is.
   --  The files are passed as arguments, so nothing needs quoting.
      use GNAT.OS_Lib;
      Windows : constant Boolean := Term.Is_Windows;
      Shell   : GNAT.OS_Lib.String_Access :=
        Locate_Exec_On_Path (if Windows then "cmd.exe" else "sh");
      Args    : Argument_List :=
        (if Windows
         then [new String'("/c"),
               new String'(Command & " < """ & Input_File & """ > """
                           & Output_File & """ 2> NUL")]
         else [new String'("-c"),
               new String'("T=; command -v timeout > /dev/null && T='timeout 2'; "
                           & "exec $T /bin/sh -c ""$0"" < ""$1"" > ""$2"" 2> /dev/null"),
               new String'(Command), new String'(Input_File),
               new String'(Output_File)]);
      Code    : Integer := -1;
   begin
      if Shell /= null then
         Code := Spawn (Shell.all, Args);
      end if;
      Free (Shell);
      for A of Args loop
         Free (A);
      end loop;
      return Code = 0;
   end Run;

   Null_File : constant String := (if Term.Is_Windows then "NUL" else "/dev/null");

   function Temp_File (Contents : String) return String is
   --  A new temporary file holding Contents; "" if one cannot be made.
      use GNAT.OS_Lib;
      FD   : File_Descriptor;
      Name : GNAT.OS_Lib.String_Access;
   begin
      Create_Temp_File (FD, Name);
      if FD = Invalid_FD then
         return "";
      end if;
      declare
         N : constant Integer :=
           (if Contents'Length = 0 then 0
            else Write (FD, Contents'Address, Contents'Length));
         S  : constant String := Name.all;
         Ok : Boolean;
      begin
         Close (FD);
         Free (Name);
         if N /= Contents'Length then
            Delete_File (S, Ok);
            return "";
         end if;
         return S;
      end;
   end Temp_File;

   function Read_And_Delete (Name : String) return String is
      use GNAT.OS_Lib;
      FD : constant File_Descriptor := Open_Read (Name, Binary);
      Ok : Boolean;
   begin
      if FD = Invalid_FD then
         return "";
      end if;
      declare
         S : String (1 .. Integer (File_Length (FD)));
         N : constant Integer := (if S'Length = 0 then 0 else Read (FD, S'Address, S'Length));
      begin
         Close (FD);
         Delete_File (Name, Ok);
         return S (1 .. Integer'Max (N, 0));
      end;
   end Read_And_Delete;

   function Decode (UTF8 : String) return Wide_Wide_String is
   --  UTF-8 (Latin-1 if it is not valid), with CR LF and lone CRs as LF.
      Raw : Unbounded_Wide_Wide_String;
      R   : Unbounded_Wide_Wide_String;
   begin
      begin
         Raw := To_Unbounded_Wide_Wide_String
           (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (UTF8));
      exception
         when others =>
            for C of UTF8 loop
               Append (Raw, Wide_Wide_Character'Val (Character'Pos (C)));
            end loop;
      end;
      declare
         S  : constant Wide_Wide_String := To_Wide_Wide_String (Raw);
         CR : constant Wide_Wide_Character := Wide_Wide_Character'Val (13);
         LF : constant Wide_Wide_Character := Wide_Wide_Character'Val (10);
      begin
         for I in S'Range loop
            if S (I) /= CR then
               Append (R, S (I));
            elsif I = S'Last or else S (I + 1) /= LF then
               Append (R, LF);
            end if;
         end loop;
      end;
      return To_Wide_Wide_String (R);
   end Decode;

   --  The clipboard

   procedure Set (Text : Wide_Wide_String) is
      UTF8 : constant String :=
        Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text);
   begin
      Content := To_Unbounded_Wide_Wide_String (Text);
      if Copy_Cmd /= Null_Unbounded_String and then not Broken then
         declare
            Input : constant String := Temp_File (UTF8);
            Ok    : Boolean;
         begin
            if Input /= "" then
               --  xclip and wl-copy have read it all before they go into
               --  the background, so the file can go at once.
               Broken := not Run (To_String (Copy_Cmd), Input, Null_File);
               GNAT.OS_Lib.Delete_File (Input, Ok);
            end if;
         end;
      end if;
      --  Terminals cap OSC 52 payloads (often around 100 kB); past that the
      --  other two still work.
      if UTF8'Length <= 64 * 1024 and then Term.Is_Active then
         Term.Write (Character'Val (27) & "]52;c;" & Base64 (UTF8)
                     & Character'Val (7));
      end if;
   end Set;

   function Get return Wide_Wide_String is
   begin
      if Paste_Cmd /= Null_Unbounded_String and then not Broken then
         declare
            Output : constant String := Temp_File ("");
         begin
            if Output /= "" then
               declare
                  Ok   : constant Boolean := Run (To_String (Paste_Cmd), Null_File, Output);
                  Text : constant String := Read_And_Delete (Output);
               begin
                  --  (wl-paste fails on an empty clipboard: then Content.)
                  if Ok and then Text'Length > 0 then
                     return Decode (Text);
                  end if;
               end;
            end if;
         end;
      end if;
      return To_Wide_Wide_String (Content);
   end Get;

   function Is_Empty return Boolean is
     (Length (Content) = 0
      and then (Paste_Cmd = Null_Unbounded_String or else Broken));

   function Helper return String is
      C     : constant String := To_String (Copy_Cmd);
      Blank : constant Natural := Ada.Strings.Fixed.Index (C, " ");
   begin
      return (if Blank = 0 then C else C (C'First .. Blank - 1));
   end Helper;

end Turbo.Clipboard;
