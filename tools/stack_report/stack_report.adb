--  Static stack-usage report for a bare-metal Ada/ESP32-S3 example -- the native
--  host counterpart to the GCC switches -fstack-usage (obj/*.su, per-frame sizes)
--  and -fcallgraph-info (obj/*.ci, the call graph).  Two analyses:
--    1. Per-frame  -- biggest single frames, plus every DYNAMIC/BOUNDED frame
--                     (a VLA/alloca whose size is not a compile-time constant,
--                     which defeats static bounding).
--    2. Worst-case -- the deepest stack-summed call chain from each entry root.
--                     Ravenscar/Jorvik forbids recursion, so the call graph is a
--                     DAG and the longest path is a real bound on the application's
--                     own frames (the pinned runtime is prebuilt without these
--                     switches, so calls into it show as '+ext' and are excluded;
--                     the runtime watermark, `x stack --run`, measures those).
--    Recursion on a chain is flagged !!RECURSIVE: a recursive depth cannot be
--    bounded statically, so its figure is only a lower bound.
--
--  Usage: stack_report <obj-dir> [--top N]
with Ada.Command_Line;            use Ada.Command_Line;
with Ada.Text_IO;                 use Ada.Text_IO;
with Ada.Directories;            use Ada.Directories;
with Ada.Strings;                use Ada.Strings;
with Ada.Strings.Fixed;          use Ada.Strings.Fixed;
with Ada.Strings.Unbounded;      use Ada.Strings.Unbounded;
with Ada.Strings.Hash;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
use Ada.Containers;

procedure Stack_Report is

   function U (S : String) return Unbounded_String renames To_Unbounded_String;

   package Nat_Maps is new Indefinite_Hashed_Maps
     (String, Natural, Ada.Strings.Hash, "=");
   package Str_Maps is new Indefinite_Hashed_Maps
     (String, String, Ada.Strings.Hash, "=", "=");
   package Str_Sets is new Indefinite_Hashed_Sets
     (String, Ada.Strings.Hash, "=");

   type Frame is record
      Name, Src, Qual : Unbounded_String;
      Bytes : Natural := 0;
   end record;
   package Frame_Vectors is new Vectors (Positive, Frame);

   type Edge_T is record Src, Dst : Unbounded_String; end record;
   package Edge_Vectors is new Vectors (Positive, Edge_T);

   --  Result of the longest-path walk from one node.
   type WC is record
      Total     : Natural := 0;
      Chain     : Unbounded_String := Null_Unbounded_String;  --  labels, " -> "
      Unknown   : Boolean := False;   --  chain reaches a runtime/external node
      Recursive : Boolean := False;   --  chain hit a cycle
   end record;
   package WC_Maps is new Indefinite_Hashed_Maps
     (String, WC, Ada.Strings.Hash, "=");

   Stack_Of : Nat_Maps.Map;     --  node -> frame bytes (only nodes with a size)
   Label_Of : Str_Maps.Map;     --  node -> pretty (source) name
   Edges    : Edge_Vectors.Vector;
   Frames   : Frame_Vectors.Vector;

   --------------------------------------------------------------------------
   --  Small string helpers
   --------------------------------------------------------------------------

   --  The value of  <Key><value>"  in Line, e.g. Quoted (L, "title: ") -> the
   --  text between the quotes after  title: " .  "" if Key or quote is absent.
   function Quoted (Line, Key : String) return String is
      K : constant Natural := Index (Line, Key);
   begin
      if K = 0 then
         return "";
      end if;
      declare
         Start : constant Natural := K + Key'Length;   --  just past the opening "
         Stop  : constant Natural := Index (Line (Start .. Line'Last), """");
      begin
         if Stop = 0 then
            return "";
         end if;
         return Line (Start .. Stop - 1);
      end;
   end Quoted;

   --  Group a number with thin spaces:  6512 -> "6 512".
   function Human (N : Natural) return String is
      Raw : constant String := Trim (Natural'Image (N), Left);
      Out_S : Unbounded_String;
      Count : Natural := 0;
   begin
      for I in reverse Raw'Range loop
         Out_S := Raw (I) & Out_S;
         Count := Count + 1;
         if Count mod 3 = 0 and then I /= Raw'First then
            Out_S := " " & Out_S;
         end if;
      end loop;
      return To_String (Out_S);
   end Human;

   function Pad (S : String; Width : Positive) return String is
     (if S'Length >= Width then S else (Width - S'Length) * ' ' & S);

   --------------------------------------------------------------------------
   --  Parse one .su line:  <path>:<line>:<col>:<label> <TAB> <bytes> <TAB> <qual>
   --------------------------------------------------------------------------

   Tab : constant String := [1 => ASCII.HT];

   procedure Load_SU_Line (Line : String) is
      T1 : constant Natural := Index (Line, Tab);
      T2 : constant Natural :=
        (if T1 = 0 then 0 else Index (Line (T1 + 1 .. Line'Last), Tab));
   begin
      if T1 = 0 or else T2 = 0 then
         return;
      end if;
      declare
         Loc   : constant String := Line (Line'First .. T1 - 1);  --  path:line:col:label
         Bytes : constant String := Trim (Line (T1 + 1 .. T2 - 1), Both);
         Qual  : constant String := Trim (Line (T2 + 1 .. Line'Last), Both);
         --  label has no ':' (source names use '.'), so peel three from the right.
         P3 : constant Natural := Index (Loc, ":", Going => Backward);
         P2 : constant Natural :=
           (if P3 = 0 then 0 else Index (Loc (Loc'First .. P3 - 1), ":", Going => Backward));
         P1 : constant Natural :=
           (if P2 = 0 then 0 else Index (Loc (Loc'First .. P2 - 1), ":", Going => Backward));
      begin
         if P1 = 0 then
            return;
         end if;
         declare
            Path  : constant String := Loc (Loc'First .. P1 - 1);
            Line_No : constant String := Loc (P1 + 1 .. P2 - 1);
            Label : constant String := Loc (P3 + 1 .. Loc'Last);
            Slash : constant Natural := Index (Path, "/", Going => Backward);
            Base  : constant String := Path (Slash + 1 .. Path'Last);
            F     : Frame;
         begin
            F.Name := U (Label);
            F.Src  := U (Base & ":" & Line_No);
            F.Qual := U (Qual);
            F.Bytes := Natural'Value (Bytes);
            Frames.Append (F);
         exception
            when Constraint_Error => null;   --  unparsable bytes -> skip
         end;
      end;
   end Load_SU_Line;

   --------------------------------------------------------------------------
   --  Parse one .ci line (VCG): node:{ title label }  or  edge:{ src dst }
   --------------------------------------------------------------------------

   procedure Load_CI_Line (Line : String) is
   begin
      if Index (Line, "node:") > 0 and then Index (Line, "title:") > 0 then
         declare
            Name : constant String := Quoted (Line, "title: """);
            Lbl  : constant String := Quoted (Line, "label: """);
            NL   : constant Natural := Index (Lbl, "\n");        --  literal backslash-n
            Pretty : constant String :=
              (if NL = 0 then Lbl else Lbl (Lbl'First .. NL - 1));
            B    : constant Natural := Index (Lbl, " bytes (");
         begin
            if Name = "" then
               return;
            end if;
            if not Label_Of.Contains (Name) then
               Label_Of.Insert (Name, Pretty);
            end if;
            if B > 0 then
               --  digits run leftwards from the space before "bytes"
               declare
                  E : constant Natural := B - 1;   --  last digit
                  S : Natural := E;
               begin
                  while S > Lbl'First and then Lbl (S - 1) in '0' .. '9' loop
                     S := S - 1;
                  end loop;
                  declare
                     Val : constant Natural := Natural'Value (Lbl (S .. E));
                  begin
                     --  keep the largest seen (a node may recur across units)
                     if (not Stack_Of.Contains (Name))
                       or else Val >= Stack_Of.Element (Name)
                     then
                        Stack_Of.Include (Name, Val);
                     end if;
                  end;
               exception
                  when Constraint_Error => null;
               end;
            end if;
         end;
      elsif Index (Line, "edge:") > 0 then
         declare
            S : constant String := Quoted (Line, "sourcename: """);
            T : constant String := Quoted (Line, "targetname: """);
         begin
            if S /= "" and then T /= "" then
               Edges.Append (Edge_T'(Src => U (S), Dst => U (T)));
            end if;
         end;
      end if;
   end Load_CI_Line;

   --------------------------------------------------------------------------
   --  File / directory loading
   --------------------------------------------------------------------------

   procedure Load_File (Path : String; CI : Boolean) is
      F : File_Type;
   begin
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            Line : constant String := Get_Line (F);
         begin
            if CI then Load_CI_Line (Line); else Load_SU_Line (Line); end if;
         end;
      end loop;
      Close (F);
   end Load_File;

   procedure Load_Dir (Dir, Pattern : String; CI : Boolean) is
      Srch : Search_Type;
      Ent  : Directory_Entry_Type;
   begin
      Start_Search (Srch, Dir, Pattern);
      while More_Entries (Srch) loop
         Get_Next_Entry (Srch, Ent);
         Load_File (Full_Name (Ent), CI);
      end loop;
      End_Search (Srch);
   end Load_Dir;

   --------------------------------------------------------------------------
   --  Worst-case longest path from a root (fresh memo + stack per root, so each
   --  root is computed independently -- matches a per-root DFS exactly).
   --------------------------------------------------------------------------

   function Analyze_Root (Root : String) return WC is
      Memo     : WC_Maps.Map;
      On_Stack : Str_Sets.Set;

      function DFS (Name : String) return WC is
         Has        : constant Boolean := Stack_Of.Contains (Name);
         Own        : constant Natural := (if Has then Stack_Of.Element (Name) else 0);
         Best_Total : Natural := 0;
         Best_Chain : Unbounded_String := Null_Unbounded_String;
         Unknown    : Boolean := not Has;
         Recursive  : Boolean := False;
         Res        : WC;
      begin
         if On_Stack.Contains (Name) then           --  back-edge -> recursion
            return (0, Null_Unbounded_String, False, True);
         end if;
         if Memo.Contains (Name) then
            return Memo.Element (Name);
         end if;
         On_Stack.Insert (Name);
         for E of Edges loop
            if E.Src = U (Name) then
               declare
                  R : constant WC := DFS (To_String (E.Dst));
               begin
                  Unknown   := Unknown or R.Unknown;
                  Recursive := Recursive or R.Recursive;
                  if R.Total > Best_Total then
                     Best_Total := R.Total;
                     Best_Chain := R.Chain;
                  end if;
               end;
            end if;
         end loop;
         On_Stack.Delete (Name);

         declare
            My : constant String :=
              (if Label_Of.Contains (Name) then Label_Of.Element (Name) else Name);
         begin
            if Has then
               Res.Chain := U (My);
               if Length (Best_Chain) > 0 then
                  Res.Chain := Res.Chain & " -> " & Best_Chain;
               end if;
            else
               Res.Chain := Best_Chain;     --  external node: drop it from the chain
            end if;
         end;
         Res.Total     := Own + Best_Total;
         Res.Unknown   := Unknown;
         Res.Recursive := Recursive;
         Memo.Insert (Name, Res);
         return Res;
      end DFS;
   begin
      return DFS (Root);
   end Analyze_Root;

   --------------------------------------------------------------------------
   --  Reporting
   --------------------------------------------------------------------------

   type Row is record
      Total : Natural;
      Root  : Unbounded_String;
      W     : WC;
   end record;
   package Row_Vectors is new Vectors (Positive, Row);

   --  Descending sorts (biggest first): "<" means "comes earlier" == "is bigger".
   function Row_Bigger   (A, B : Row)   return Boolean is (A.Total > B.Total);
   function Frame_Bigger (A, B : Frame) return Boolean is (A.Bytes > B.Bytes);

   package Row_Sorting   is new Row_Vectors.Generic_Sorting   ("<" => Row_Bigger);
   package Frame_Sorting is new Frame_Vectors.Generic_Sorting ("<" => Frame_Bigger);

   Top : Positive := 12;

   procedure Report is
      Total_All : Natural := 0;
      Targeted  : Str_Sets.Set;
      Roots     : Str_Sets.Set;
      Rows      : Row_Vectors.Vector;
      Any_Rec   : Boolean := False;
      Dyn_Count : Natural := 0;
   begin
      ---------------------------- per-frame ----------------------------------
      for F of Frames loop
         Total_All := Total_All + F.Bytes;
         if F.Qual /= U ("static") then
            Dyn_Count := Dyn_Count + 1;
         end if;
      end loop;
      Frame_Sorting.Sort (Frames);

      Put_Line ("== Per-frame stack usage (application units) ==");
      Put_Line ("   " & Trim (Frames.Length'Image, Left) & " frames; total of all"
                & " frames = " & Human (Total_All) & " B (NOT a depth -- see"
                & " worst-case below)");
      New_Line;
      Put_Line ("   " & Pad ("bytes", 8) & "  qualifier        location / subprogram");
      declare
         Shown : Natural := 0;
      begin
         for F of Frames loop
            exit when Shown >= Top;
            Put_Line ("   " & Pad (Human (F.Bytes), 8) & "  "
                      & Head (To_String (F.Qual), 16) & " "
                      & To_String (F.Src) & "  " & To_String (F.Name));
            Shown := Shown + 1;
         end loop;
      end;
      New_Line;
      if Dyn_Count > 0 then
         Put_Line ("   !!" & Dyn_Count'Image & " DYNAMIC/BOUNDED frame(s) -- static"
                   & " depth is NOT guaranteed for paths through these:");
         for F of Frames loop
            if F.Qual /= U ("static") then
               Put_Line ("      " & Pad (Human (F.Bytes), 8) & "  "
                         & Head (To_String (F.Qual), 16) & " "
                         & To_String (F.Src) & "  " & To_String (F.Name));
            end if;
         end loop;
      else
         Put_Line ("   All frames are STATIC (compile-time constant) -- good:"
                   & " worst-case below is a real bound.");
      end if;

      ---------------------------- worst-case ---------------------------------
      for E of Edges loop
         Targeted.Include (To_String (E.Dst));
      end loop;
      for C in Stack_Of.Iterate loop
         if not Targeted.Contains (Nat_Maps.Key (C)) then
            Roots.Include (Nat_Maps.Key (C));
         end if;
      end loop;
      if Stack_Of.Contains ("_ada_main") then
         Roots.Include ("_ada_main");
      end if;

      for R of Roots loop
         declare
            W : constant WC := Analyze_Root (R);
         begin
            Rows.Append (Row'(Total => W.Total, Root => U (R), W => W));
            Any_Rec := Any_Rec or W.Recursive;
         end;
      end loop;
      Row_Sorting.Sort (Rows);

      New_Line;
      Put_Line ("== Worst-case call-chain depth per entry root ==");
      Put_Line ("   (application frames only; '+ext' = chain also calls the"
                & " prebuilt runtime, whose");
      Put_Line ("    frames are not counted here -- use the runtime watermark for"
                & " the true figure)");
      New_Line;
      declare
         Shown : Natural := 0;
      begin
         for Rw of Rows loop
            --  keep the top N, but never hide a recursive chain
            if Shown < Top or else Rw.W.Recursive then
               declare
                  Name : constant String :=
                    (if Label_Of.Contains (To_String (Rw.Root))
                     then Label_Of.Element (To_String (Rw.Root))
                     else To_String (Rw.Root));
                  Tag  : constant String :=
                    (if Rw.W.Recursive then "  !!RECURSIVE"
                     elsif Rw.W.Unknown then " +ext" else "");
               begin
                  Put_Line ("   " & Pad (Human (Rw.Total), 8) & " B"
                            & Head (Tag, 13) & " " & Name);
                  if Length (Rw.W.Chain) > 0 then
                     Put_Line ("            " & To_String (Rw.W.Chain));
                  end if;
               end;
               Shown := Shown + 1;
            end if;
         end loop;
      end;
      if Any_Rec then
         New_Line;
         Put_Line ("   !! RECURSION detected on a marked chain -- its figure is a"
                   & " LOWER bound, not a");
         Put_Line ("      guarantee.  Ravenscar/Jorvik forbids recursion in task"
                   & " code; size such a");
         Put_Line ("      stack by reasoning about the maximum depth, then verify"
                   & " with the watermark.");
      end if;
      New_Line;
   end Report;

begin
   if Argument_Count < 1 then
      Put_Line (Standard_Error, "usage: stack_report <obj-dir> [--top N]");
      Set_Exit_Status (2);
      return;
   end if;
   declare
      Dir : constant String := Argument (1);
   begin
      for I in 2 .. Argument_Count loop
         if Argument (I) = "--top" and then I < Argument_Count then
            begin
               Top := Positive'Value (Argument (I + 1));
            exception
               when Constraint_Error => null;
            end;
         end if;
      end loop;
      if not Exists (Dir) or else Kind (Dir) /= Directory then
         Put_Line (Standard_Error, "stack_report: no such dir " & Dir);
         Set_Exit_Status (2);
         return;
      end if;
      Load_Dir (Dir, "*.su", CI => False);
      if Frames.Is_Empty then
         Put_Line (Standard_Error,
                   "stack_report: no *.su files -- build with STACK_ANALYSIS=1 first");
         Set_Exit_Status (2);
         return;
      end if;
      Load_Dir (Dir, "*.ci", CI => True);
      Report;
   end;
end Stack_Report;
