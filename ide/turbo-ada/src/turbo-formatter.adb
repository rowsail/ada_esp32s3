with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with GNAT.OS_Lib;

package body Turbo.Formatter is

   use Ada.Strings.Unbounded;
   use Ada.Strings.Wide_Wide_Unbounded;

   function Located (Name : String) return String is
      use type GNAT.OS_Lib.String_Access;
      P : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Locate_Exec_On_Path (Name);
   begin
      if P = null then
         return "";
      end if;
      return S : constant String := P.all do
         GNAT.OS_Lib.Free (P);
      end return;
   end Located;

   function Shell return String is (Located ("sh"));

   function Program return String is
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME") else "");
      Found : constant String := Located ("gnatformat");
   begin
      if Shell = "" then
         return "";
      elsif Found /= "" then
         return Found;
      elsif Home /= "" and then GNAT.OS_Lib.Is_Executable_File (Home & "/.alire/bin/gnatformat") then
         return Home & "/.alire/bin/gnatformat";
      end if;
      return "";
   end Program;

   function Img (N : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left));

   procedure Write_File (Name, Contents : String) is
      use Ada.Streams.Stream_IO;
      F : File_Type;
   begin
      Create (F, Out_File, Name);
      String'Write (Stream (F), Contents);
      Close (F);
   end Write_File;

   function Read_File (Name : String) return String is
      use Ada.Streams.Stream_IO;
      F : File_Type;
   begin
      if not Ada.Directories.Exists (Name) then
         return "";
      end if;
      Open (F, In_File, Name);
      declare
         S : String (1 .. Natural (Size (F)));
      begin
         String'Read (Stream (F), S);
         Close (F);
         return S;
      end;
   end Read_File;

   function Decode (S : String) return Wide_Wide_String is
   begin
      return Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (S);
   exception
      when others =>
         declare
            R : Wide_Wide_String (S'Range);
         begin
            for I in S'Range loop
               R (I) := Wide_Wide_Character'Val (Character'Pos (S (I)));
            end loop;
            return R;
         end;
   end Decode;

   function Parse_Range (Header : String; From, To : out Turbo.Buffers.Position) return Boolean is
   --  "file(<Node ... >) - L1:C1-L2:C2": the span the new text replaces.
      use Ada.Strings.Fixed;
      Dash : constant Natural := Index (Header, " - ", Ada.Strings.Backward);
      N    : array (1 .. 4) of Natural := [others => 0];
      K    : Positive := 1;
   begin
      if Dash = 0 then
         return False;
      end if;
      for C of Header (Dash + 3 .. Header'Last) loop
         if C in '0' .. '9' then
            N (K) := N (K) * 10 + (Character'Pos (C) - Character'Pos ('0'));
         elsif (C = ':' or else C = '-') and then K < 4 then
            K := K + 1;
         end if;
      end loop;
      if K /= 4 or else (for some V of N => V = 0) then
         return False;
      end if;
      From := (N (1), N (2));
      To := (N (3), N (4));
      return True;
   end Parse_Range;

   Serial : Natural := 0;

   function Temp_Base return String is
     (if Ada.Environment_Variables.Exists ("TMPDIR")
        and then Ada.Directories.Exists (Ada.Environment_Variables.Value ("TMPDIR"))
      then Ada.Environment_Variables.Value ("TMPDIR") else "/tmp");

   function Without (S, Part : String) return String is
   --  S with every occurrence of Part taken out (the temporary directory
   --  from gnatformat's messages).
      I : constant Natural := Ada.Strings.Fixed.Index (S, Part);
   begin
      return (if I = 0 then S
              else S (S'First .. I - 1) & Without (S (I + Part'Length .. S'Last), Part));
   end Without;

   procedure Format
     (Name     : String;
      Text     : Wide_Wide_String;
      Whole    : Boolean;
      From, To : Turbo.Buffers.Position;
      R        : out Result)
   is
      use GNAT.OS_Lib;
      LF   : constant Character := Character'Val (10);
      Exe  : constant String := Program;
   begin
      R := (others => <>);
      if Exe = "" then
         R.Error := To_Unbounded_String ("gnatformat is not installed");
         return;
      end if;
      Serial := Serial + 1;
      declare
         --  A directory of our own (not in the project), so the file can
         --  keep its name.
         Dir  : constant String :=
           Temp_Base & "/tada-format-"
           & Img (Pid_To_Integer (Current_Process_Id)) & "-" & Img (Serial);
         Src  : constant String := Dir & "/" & Name;
         Out_F : constant String := Dir & "/out";
         Err_F : constant String := Dir & "/err";
         Code : Integer;
      begin
         if Ada.Directories.Exists (Dir) then
            Ada.Directories.Delete_Tree (Dir);
         end if;
         Ada.Directories.Create_Directory (Dir);
         Write_File (Src, Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text));
         --  Through sh for the redirections: its stderr must not reach the
         --  screen the IDE is drawing.
         declare
            Args : Argument_List :=
              [new String'("-c"),
               new String'("o=$1; e=$2; shift 2; exec ""$0"" ""$@"" > ""$o"" 2> ""$e"""),
               new String'(Exe), new String'(Out_F), new String'(Err_F),
               new String'("--pipe"), new String'("--no-project"),
               new String'("--charset"), new String'("utf-8")]
              & (if Whole then []
                 else [new String'("--range-format"),
                       new String'("-SL"), new String'(Img (From.Line)),
                       new String'("-SC"), new String'(Img (From.Col)),
                       new String'("-EL"), new String'(Img (To.Line)),
                       new String'("-EC"), new String'(Img (To.Col))])
              & [new String'(Src)];
         begin
            Code := Spawn (Shell, Args);
            for A of Args loop
               Free (A);
            end loop;
         end;
         declare
            Output : constant String := Read_File (Out_F);
            Errors : constant String := Read_File (Err_F);
         begin
            Ada.Directories.Delete_Tree (Dir);
            if Code /= 0 then
               R.Error := To_Unbounded_String
                 (if Errors /= "" then Without (Errors, Dir & "/")
                  else "gnatformat failed (status" & Code'Image & ")");
               return;
            end if;
            if Whole then
               --  --pipe adds a line feed after the file's own.
               R.From := (1, 1);
               R.To := (Positive'Last, Positive'Last);   --  the end: the caller clamps
               R.Text := To_Unbounded_Wide_Wide_String
                 (Decode (if Output'Length > 0 and then Output (Output'Last) = LF
                          then Output (Output'First .. Output'Last - 1) else Output));
               R.Ok := True;
               return;
            end if;
            --  Range mode: the header, "^" on a line of its own, the new
            --  text, "$".
            declare
               use Ada.Strings.Fixed;
               Caret  : constant Natural := Index (Output, LF & "^" & LF);
               Dollar : constant Natural := Index (Output, "$", Ada.Strings.Backward);
            begin
               if Caret = 0 or else Dollar < Caret + 3
                 or else not Parse_Range (Output (Output'First .. Caret - 1), R.From, R.To)
               then
                  R.Error := To_Unbounded_String ("gnatformat's output was not understood");
                  return;
               end if;
               R.Text := To_Unbounded_Wide_Wide_String (Decode (Output (Caret + 3 .. Dollar - 1)));
               R.Ok := True;
            end;
         end;
      end;
   exception
      when others =>
         R.Ok := False;
         if Length (R.Error) = 0 then
            R.Error := To_Unbounded_String ("gnatformat could not be run");
         end if;
   end Format;

end Turbo.Formatter;
