--  Generate a HAL API reference (Markdown -> PDF) from the Ada spec files.
--
--  A native (host) tool: for every .ads under <hal>/src it emits the package's
--  header doc-comment (as prose, keeping indented examples/lists verbatim)
--  followed by the public part of the spec.  The generated svd/ register layer
--  is summarised, not dumped.  Finally it spawns `pandoc` to render the PDF.
--
--  Usage:  gen_reference [<hal-dir>]      (default ".", i.e. libs/esp32s3_hal)
--          writes <hal>/docs/HAL_Reference.md and .pdf
with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Strings.Unbounded;   use Ada.Strings.Unbounded;
with Ada.Directories;         use Ada.Directories;
with Ada.Characters.Handling; use Ada.Characters.Handling;
with Ada.Command_Line;        use Ada.Command_Line;
with Ada.Containers.Vectors;
with GNAT.OS_Lib;

procedure Gen_Reference is

   function "+" (S : String) return Unbounded_String
     renames To_Unbounded_String;

   package Line_Vec is new Ada.Containers.Vectors (Positive, Unbounded_String);
   use Line_Vec;

   type Spec is record
      Name, Relpath  : Unbounded_String;
      Priv           : Boolean := False;
      Header, Public : Line_Vec.Vector;
   end record;
   package Spec_Vec is new Ada.Containers.Vectors (Positive, Spec);

   ---------------------------------------------------------------------------
   --  String helpers (all return 1-based, comparable slices).
   ---------------------------------------------------------------------------

   function One_Based (S : String) return String is
      R : constant String (1 .. S'Length) := S;
   begin
      return R;
   end One_Based;

   function L_Strip (S : String) return String is
      F : Natural := S'First;
   begin
      while F <= S'Last and then S (F) = ' ' loop
         F := F + 1;
      end loop;
      return One_Based (S (F .. S'Last));
   end L_Strip;

   function Trim_Both (S : String) return String is
      F : Natural := S'First;
      L : Natural := S'Last;
   begin
      while F <= L and then S (F) = ' ' loop
         F := F + 1;
      end loop;
      while L >= F and then S (L) = ' ' loop
         L := L - 1;
      end loop;
      return One_Based (S (F .. L));
   end Trim_Both;

   function Starts_With (S, Prefix : String) return Boolean is
     (S'Length >= Prefix'Length
      and then S (S'First .. S'First + Prefix'Length - 1) = Prefix);

   function Find (S, Pat : String) return Natural is
   begin
      if Pat'Length = 0 or else Pat'Length > S'Length then
         return 0;
      end if;
      for I in S'First .. S'Last - Pat'Length + 1 loop
         if S (I .. I + Pat'Length - 1) = Pat then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   function Ends_With (S, Suffix : String) return Boolean is
     (S'Length >= Suffix'Length
      and then S (S'Last - Suffix'Length + 1 .. S'Last) = Suffix);

   --  '--  text' -> 'text': drop the marker and the 2-space base offset, keep
   --  any deeper indentation (so examples/lists stay aligned).
   function Strip_Comment (Line : String) return String is
      T : constant String := L_Strip (Line);          --  starts with "--"
      B : constant String := One_Based (T (3 .. T'Last));
   begin
      if B'Length >= 2 and then B (1 .. 2) = "  " then
         return One_Based (B (3 .. B'Last));
      elsif B'Length >= 1 and then B (1) = ' ' then
         return One_Based (B (2 .. B'Last));
      else
         return B;
      end if;
   end Strip_Comment;

   ---------------------------------------------------------------------------
   --  Configuration / output.
   ---------------------------------------------------------------------------

   HAL     : constant String :=
     (if Argument_Count >= 1 then Argument (1) else ".");
   Src_Dir : constant String := HAL & "/src";
   Svd_Dir : constant String := HAL & "/svd";
   Out_Md  : constant String := HAL & "/docs/HAL_Reference.md";
   Out_Pdf : constant String := HAL & "/docs/HAL_Reference.pdf";

   Doc : File_Type;

   procedure P (S : String) is
   begin
      Put_Line (Doc, S);
   end P;

   procedure P (S : Unbounded_String) is
   begin
      Put_Line (Doc, To_String (S));
   end P;

   ---------------------------------------------------------------------------
   --  Read a file into a vector of lines (trailing CR stripped).
   ---------------------------------------------------------------------------

   function Read_Lines (Path : String) return Line_Vec.Vector is
      F : File_Type;
      V : Line_Vec.Vector;
   begin
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            S : constant String := Get_Line (F);
         begin
            if S'Length > 0 and then S (S'Last) = ASCII.CR then
               V.Append (+S (S'First .. S'Last - 1));
            else
               V.Append (+S);
            end if;
         end;
      end loop;
      Close (F);
      return V;
   end Read_Lines;

   ---------------------------------------------------------------------------
   --  Parse one .ads: package name, private?, header block, public part.
   ---------------------------------------------------------------------------

   procedure Parse (Lines : Line_Vec.Vector; S : out Spec; Ok : out Boolean) is
      Pkg_I : Natural := 0;
   begin
      S.Header.Clear;
      S.Public.Clear;
      S.Priv := False;
      Ok := False;

      for I in Lines.First_Index .. Lines.Last_Index loop
         declare
            T : constant String := L_Strip (To_String (Lines (I)));
         begin
            if (Starts_With (T, "package ")
                or else Starts_With (T, "private package "))
              and then Find (T, " is") > 0
            then
               Pkg_I := I;
               S.Priv := Starts_With (T, "private package ");
               declare
                  Kw : constant Natural := (if S.Priv then 17 else 9);  --  1st char of name
                  Is_Pos : constant Natural := Find (T, " is");
               begin
                  S.Name := +T (Kw .. Is_Pos - 1);
               end;
               exit;
            end if;
         end;
      end loop;
      if Pkg_I = 0 then
         return;
      end if;

      --  Header: the contiguous comment block just above the package line.
      declare
         Rev : Line_Vec.Vector;
         I   : Integer := Pkg_I - 1;
      begin
         while I >= Lines.First_Index loop
            declare
               T : constant String := L_Strip (To_String (Lines (I)));
            begin
               if Starts_With (T, "--") then
                  Rev.Append (+Strip_Comment (To_String (Lines (I))));
               elsif T = "" then
                  exit when not Rev.Is_Empty;
               else
                  exit;
               end if;
            end;
            I := I - 1;
         end loop;
         for K in reverse Rev.First_Index .. Rev.Last_Index loop
            S.Header.Append (Rev (K));
         end loop;
      end;

      --  Public part: package line + 1 .. the 'private' or 'end' line.
      for I in Pkg_I + 1 .. Lines.Last_Index loop
         declare
            T : constant String := L_Strip (To_String (Lines (I)));
         begin
            exit when Starts_With (T, "private") or else Starts_With (T, "end ");
            S.Public.Append (Lines (I));
         end;
      end loop;
      while not S.Public.Is_Empty
        and then Trim_Both (To_String (S.Public.First_Element)) = ""
      loop
         S.Public.Delete_First;
      end loop;
      while not S.Public.Is_Empty
        and then Trim_Both (To_String (S.Public.Last_Element)) = ""
      loop
         S.Public.Delete_Last;
      end loop;

      Ok := True;
   end Parse;

   ---------------------------------------------------------------------------
   --  Render a header block: prose paragraphs, but any paragraph containing an
   --  indented line is emitted verbatim (examples, lists, tables).
   ---------------------------------------------------------------------------

   procedure Render_Header (H : Line_Vec.Vector) is
      Para : Line_Vec.Vector;

      procedure Flush is
         Pre : Boolean := False;
         Acc : Unbounded_String;
      begin
         if Para.Is_Empty then
            return;
         end if;
         for Ln of Para loop
            declare
               Str : constant String := To_String (Ln);
            begin
               if Str'Length > 0 and then Str (Str'First) = ' ' then
                  Pre := True;
               end if;
            end;
         end loop;
         if Pre then
            P ("```");
            for Ln of Para loop
               P (Ln);
            end loop;
            P ("```");
         else
            for Ln of Para loop
               if Length (Acc) > 0 then
                  Append (Acc, " ");
               end if;
               Append (Acc, Trim_Both (To_String (Ln)));
            end loop;
            P (Acc);
         end if;
         P ("");
         Para.Clear;
      end Flush;

   begin
      for Ln of H loop
         if Trim_Both (To_String (Ln)) = "" then
            Flush;
         else
            Para.Append (Ln);
         end if;
      end loop;
      Flush;
   end Render_Header;

   ---------------------------------------------------------------------------
   --  Recursively collect *.ads paths under Dir.
   ---------------------------------------------------------------------------

   procedure Collect (Dir : String; Into : in out Line_Vec.Vector) is
      Srch : Search_Type;
      Ent  : Directory_Entry_Type;
   begin
      Start_Search (Srch, Dir, "");
      while More_Entries (Srch) loop
         Get_Next_Entry (Srch, Ent);
         declare
            Nm : constant String := Simple_Name (Ent);
         begin
            if Kind (Ent) = Directory then
               if Nm /= "." and then Nm /= ".." then
                  Collect (Dir & "/" & Nm, Into);
               end if;
            elsif Ends_With (Nm, ".ads") then
               Into.Append (+(Dir & "/" & Nm));
            end if;
         end;
      end loop;
      End_Search (Srch);
   end Collect;

   --  Relpath of Path relative to the HAL directory.
   function Rel (Path : String) return String is
      Pre : constant String := HAL & "/";
   begin
      if Starts_With (Path, Pre) then
         return Path (Path'First + Pre'Length .. Path'Last);
      else
         return Path;
      end if;
   end Rel;

   function Lower (U : Unbounded_String) return String is
     (To_Lower (To_String (U)));

   function Spec_Less (L, R : Spec) return Boolean is
     (Lower (L.Name) < Lower (R.Name));

   package Sorting is new Spec_Vec.Generic_Sorting ("<" => Spec_Less);

   ---------------------------------------------------------------------------
   --  Driver.
   ---------------------------------------------------------------------------

   Paths : Line_Vec.Vector;
   Top   : Spec_Vec.Vector;
   Ext4  : Spec_Vec.Vector;

begin
   Collect (Src_Dir, Paths);

   for Path of Paths loop
      declare
         S  : Spec;
         Ok : Boolean;
      begin
         Parse (Read_Lines (To_String (Path)), S, Ok);
         if Ok then
            S.Relpath := +Rel (To_String (Path));
            if Find (To_String (S.Relpath), "ext4/") > 0 then
               Ext4.Append (S);
            else
               Top.Append (S);
            end if;
         end if;
      end;
   end loop;

   Sorting.Sort (Top);
   Sorting.Sort (Ext4);

   Create (Doc, Out_File, Out_Md);

   P ("% ESP32-S3 HAL --- Reference Manual");
   P ("% Generated from the Ada package specifications");
   P ("");
   P ("This reference is generated from the package specifications under "
      & "`libs/esp32s3_hal/`.  For each driver it shows the package's header "
      & "documentation and its public API (types and operations).  The "
      & "generated register layer (`svd/`) is summarised at the end.");
   P ("");

   declare
      procedure Emit (Group : Spec_Vec.Vector; Title : String) is
      begin
         P ("# " & Title);
         P ("");
         for S of Group loop
            P ("## " & To_String (S.Name)
               & (if S.Priv then "  *(internal)*" else ""));
            P ("");
            P ("*Source: `" & To_String (S.Relpath) & "`*");
            P ("");
            Render_Header (S.Header);
            if not S.Public.Is_Empty then
               P ("### Public API");
               P ("");
               P ("```ada");
               for Ln of S.Public loop
                  P (Ln);
               end loop;
               P ("```");
               P ("");
            end if;
         end loop;
      end Emit;
   begin
      Emit (Top, "Peripheral & device drivers (`src/`)");
      Emit (Ext4, "ext4 filesystem (`src/ext4/`)");
   end;

   --  svd summary.
   declare
      Svd : Line_Vec.Vector;
      Acc : Unbounded_String;
      N   : Natural := 0;
   begin
      Collect (Svd_Dir, Svd);
      Sorting_Svd :
      declare
         package L_Sort is new Line_Vec.Generic_Sorting ("<" => "<");
      begin
         L_Sort.Sort (Svd);
      end Sorting_Svd;
      P ("# Generated register layer (`svd/`)");
      P ("");
      for Path of Svd loop
         declare
            Nm : constant String := Simple_Name (To_String (Path));
            Base : constant String := Nm (Nm'First .. Nm'Last - 4);   --  drop .ads
         begin
            N := N + 1;
            if Length (Acc) > 0 then
               Append (Acc, ", ");
            end if;
            Append (Acc, "`" & Base & "`");
         end;
      end loop;
      P ("The `svd/` directory holds" & Natural'Image (N) & " machine-generated "
         & "packages (svd2ada from a CMSIS-SVD file; do not hand-edit).  They "
         & "provide the typed, bit-field register records --- root "
         & "`ESP32S3_Registers` --- that the hand-written drivers above wrap.  "
         & "Regenerate with `./regenerate.sh`.  The packages are:");
      P ("");
      P (Acc);
      P ("");
   end;

   Close (Doc);
   Put_Line ("[gen] wrote " & Out_Md
             & "  (" & Natural'Image (Natural (Top.Length)) & " drivers,"
             & Natural'Image (Natural (Ext4.Length)) & " ext4 units)");

   --  Render the PDF with pandoc.
   declare
      use type GNAT.OS_Lib.String_Access;
      Pandoc  : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("pandoc");
      Success : Boolean;
      Args    : constant GNAT.OS_Lib.Argument_List :=
        [new String'(Out_Md),
         new String'("-o"), new String'(Out_Pdf),
         new String'("--toc"), new String'("--toc-depth=2"),
         new String'("--pdf-engine=pdflatex"),
         new String'("-V"), new String'("geometry:margin=1in"),
         new String'("-V"), new String'("colorlinks=true"),
         new String'("-V"), new String'("documentclass=report"),
         new String'("--highlight-style=tango")];
   begin
      if Pandoc = null then
         Put_Line ("[gen] pandoc not found on PATH -- wrote Markdown only");
         return;
      end if;
      GNAT.OS_Lib.Spawn (Pandoc.all, Args, Success);
      GNAT.OS_Lib.Free (Pandoc);
      if Success then
         Put_Line ("[gen] wrote " & Out_Pdf);
      else
         Put_Line ("[gen] pandoc failed");
         Set_Exit_Status (1);
      end if;
   end;
end Gen_Reference;
