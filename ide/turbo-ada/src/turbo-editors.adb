with Ada.Directories;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Strings.Fixed;
with Ada.Strings.Wide_Wide_Fixed;
with Ada.Wide_Wide_Characters.Handling;
with Turbo.Clipboard;
with Turbo.Screen;
with Turbo.Settings;
with Turbo.Theme;

package body Turbo.Editors is

   use Ada.Strings.Unbounded;
   use Turbo.Events;
   use Turbo.Screen;
   use Turbo.Windows;
   use type Ada.Calendar.Time;
   use type Turbo.Syntax.Language;

   HT : constant Wide_Wide_Character := Wide_Wide_Character'Val (9);

   Colors : constant Frame_Colors :=
     (Frame      => Theme.Edit_Frame,
      Frame_Idle => Theme.Edit_Frame_Idle,
      Icon       => Theme.Edit_Icon,
      Scroll     => Theme.Edit_Scroll);

   function Is_Word_Char (C : Wide_Wide_Character) return Boolean is
     (Ada.Wide_Wide_Characters.Handling.Is_Alphanumeric (C) or else C = '_');

   function Is_Blank (C : Wide_Wide_Character) return Boolean is
     (C = ' ' or else C = HT);

   function Img (N : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left));

   function To_WW (S : String) return Wide_Wide_String is
      R : Wide_Wide_String (S'Range);
   begin
      for I in S'Range loop
         R (I) := Wide_Wide_Character'Val (Character'Pos (S (I)));
      end loop;
      return R;
   end To_WW;

   --  Visual columns (0-based) versus character indexes, through tabs.

   function VCol (Line : Wide_Wide_String; Col : Positive) return Natural is
      V : Natural := 0;
   begin
      for I in Line'First .. Integer'Min (Col - 1, Line'Last) loop
         if Line (I) = HT then
            V := (V / Settings.Tab_Size + 1) * Settings.Tab_Size;
         else
            V := V + 1;
         end if;
      end loop;
      return V;
   end VCol;

   function Col_At (Line : Wide_Wide_String; Target : Natural) return Positive is
      V    : Natural := 0;
      Next : Natural;
   begin
      for I in Line'Range loop
         Next := (if Line (I) = HT
                  then (V / Settings.Tab_Size + 1) * Settings.Tab_Size
                  else V + 1);
         if Target < Next then
            --  Inside this character: nearer its start or its end?
            return (if Target - V <= (Next - V) / 2 or else Line (I) /= HT
                    then I else I + 1);
         end if;
         V := Next;
      end loop;
      return Line'Length + 1;
   end Col_At;

   function Leading_Blanks (Line : Wide_Wide_String) return Natural is
      N : Natural := 0;
   begin
      for C of Line loop
         exit when not Is_Blank (C);
         N := N + 1;
      end loop;
      return N;
   end Leading_Blanks;

   --  Construction

   function Create (File_Name : String; Untitled_Index : Natural)
                    return Editor_Access
   is
      E  : constant Editor_Access := new Editor;
      Ok : Boolean;
   begin
      E.Buf.Clear;
      if File_Name = "" then
         E.Untitled := To_Unbounded_String
           ("NONAME" & (if Untitled_Index < 10 then "0" else "")
            & Img (Untitled_Index) & ".ADB");
         E.Lang := Syntax.Ada_Lang;
      else
         E.File_Name := To_Unbounded_String
           (Ada.Directories.Full_Name (File_Name));
         E.Lang := Syntax.Language_Of (File_Name);
         if Ada.Directories.Exists (File_Name) then
            E.Buf.Load (File_Name, Ok);
            E.Bad_Load := not Ok;
         end if;
      end if;
      return E;
   end Create;

   overriding function Title (E : Editor) return Wide_Wide_String is
   begin
      if E.File_Name = Null_Unbounded_String then
         return To_WW (To_String (E.Untitled));
      end if;
      return To_WW (To_String (E.File_Name));
   end Title;

   function Path (E : Editor) return String is (To_String (E.File_Name));

   function Is_Untitled (E : Editor) return Boolean is
     (E.File_Name = Null_Unbounded_String);

   function Modified (E : Editor) return Boolean is (E.Buf.Modified);

   function Load_Failed (E : Editor) return Boolean is (E.Bad_Load);

   function Cursor (E : Editor) return Position is (E.Cur);

   function Take_Request (E : in out Editor) return Turbo.Commands.Command is
      R : constant Turbo.Commands.Command := E.Request;
   begin
      E.Request := Turbo.Commands.Cmd_None;
      return R;
   end Take_Request;

   function Status_Hint (E : Editor) return String is
     (case E.Prefix is
         when 'k' => "^K",
         when 'q' => "^Q",
         when others => "");

   --  Selection

   function Sel_Start (E : Editor) return Position is
     (if E.Sel_A < E.Sel_B then E.Sel_A else E.Sel_B);

   function Sel_End (E : Editor) return Position is
     (if E.Sel_A < E.Sel_B then E.Sel_B else E.Sel_A);

   function Has_Selection (E : Editor) return Boolean is
     (E.Has_Sel and then E.Sel_A /= E.Sel_B);

   function Selected_Text (E : Editor) return Wide_Wide_String is
     (if Has_Selection (E) then E.Buf.Text (Sel_Start (E), Sel_End (E)) else "");

   procedure Drop_Selection (E : in out Editor) is
   begin
      E.Has_Sel := False;
      E.Persistent := False;
   end Drop_Selection;

   function In_Selection (E : Editor; P : Position) return Boolean is
     (Has_Selection (E) and then not (P < Sel_Start (E))
      and then P < Sel_End (E));

   --  Diagnostics

   type Diag_Mark is (No_Diag, Diag_Error, Diag_Other);

   function Covers (D : Diagnostic; P : Position) return Boolean is
     (if D.From = D.To then P = D.From
      else not (P < D.From) and then P < D.To);

   function Diag_Level (E : Editor; P : Position) return Diag_Mark is
      Found : Diag_Mark := No_Diag;
   begin
      for D of E.Diags loop
         if P.Line >= D.From.Line and then P.Line <= D.To.Line and then Covers (D, P) then
            if D.Level = Sev_Error then
               return Diag_Error;
            end if;
            Found := Diag_Other;
         end if;
      end loop;
      return Found;
   end Diag_Level;

   procedure Set_Diagnostics (E : in out Editor; List : Diagnostic_Vectors.Vector) is
   begin
      E.Diags := List;
   end Set_Diagnostics;

   procedure Set_Breakpoints (E : in out Editor; Lines : Line_Vectors.Vector) is
   begin
      E.Breaks := Lines;
   end Set_Breakpoints;

   procedure Set_Exec_Line (E : in out Editor; Line : Natural) is
   begin
      E.Exec := Line;
   end Set_Exec_Line;

   function Exec_Line (E : Editor) return Natural is (E.Exec);

   function Diagnostic_At_Cursor (E : Editor) return String is
   begin
      for D of E.Diags loop
         --  On it, or just past its end (where the cursor is after typing).
         if Covers (D, E.Cur)
           or else (E.Cur.Line = D.To.Line and then E.Cur.Col = D.To.Col
                    and then D.From /= D.To)
         then
            return (case D.Level is
                       when Sev_Error   => "Error: ",
                       when Sev_Warning => "Warning: ",
                       when Sev_Info    => "Note: ")
              & To_String (D.Message);
         end if;
      end loop;
      return "";
   end Diagnostic_At_Cursor;

   function Version (E : Editor) return Natural is (E.Buf.Edit_Count);
   function Text (E : Editor) return Wide_Wide_String is (E.Buf.All_Text);
   function Line_Count (E : Editor) return Positive is (E.Buf.Line_Count);
   function Line_Text (E : Editor; N : Positive) return Wide_Wide_String is
     (E.Buf.Line (Positive'Min (N, E.Buf.Line_Count)));
   function Language (E : Editor) return Turbo.Syntax.Language is (E.Lang);

   --  View

   function Page (E : Editor) return Positive is
     (Positive'Max (Interior (E).H, 1));

   procedure Ensure_Visible (E : in out Editor) is
      I  : constant Rect := Interior (E);
      VC : constant Natural := VCol (E.Buf.Line (E.Cur.Line), E.Cur.Col);
   begin
      if E.Cur.Line < E.Top then
         E.Top := E.Cur.Line;
      elsif E.Cur.Line >= E.Top + I.H then
         E.Top := E.Cur.Line - I.H + 1;
      end if;
      if VC < E.Left then
         E.Left := VC;
      elsif VC >= E.Left + I.W then
         E.Left := VC - I.W + 1;
      end if;
   end Ensure_Visible;

   procedure Moved (E : in out Editor; Keep_Want : Boolean := False) is
   begin
      E.Cur := E.Buf.Clamp (E.Cur);
      if not Keep_Want then
         E.Want_VCol := VCol (E.Buf.Line (E.Cur.Line), E.Cur.Col);
      end if;
      E.Error_Line := 0;
      E.Buf.Break_Typing;
      Ensure_Visible (E);
   end Moved;

   --  Drawing

   overriding procedure Draw (E : in out Editor; Active : Boolean) is
      I      : constant Rect := Interior (E);
      Indic  : constant Wide_Wide_String :=
        (if E.Buf.Modified then "*" else (1 => H_Double))
        & " " & To_WW (Img (E.Cur.Line) & ":"
                       & Img (VCol (E.Buf.Line (E.Cur.Line), E.Cur.Col) + 1))
        & " ";
   begin
      Fill (I.X, I.Y, I.W, I.H, ' ', Theme.Edit_Text);
      Set_Clip (I.X, I.Y, I.X + I.W - 1, I.Y + I.H - 1);
      for Row in 0 .. I.H - 1 loop
         declare
            N : constant Positive := E.Top + Row;
         begin
            exit when N > E.Buf.Line_Count;
            declare
               L       : constant Wide_Wide_String := E.Buf.Line (N);
               Classes : Syntax.Class_Array (L'Range);
               V       : Natural := 0;
               Width   : Natural;
               A       : Attribute;
               Y       : constant Integer := I.Y + Row;
               --  Turbo C++'s debugger lines: the execution bar over a
               --  breakpoint over a compile error, each the whole width.
               Bar     : constant Boolean := N = E.Exec;
               Break   : constant Boolean := E.Breaks.Contains (N);
               Whole   : constant Boolean := Bar or else Break or else N = E.Error_Line;
               Line_A  : constant Attribute :=
                 (if Bar then Theme.Edit_Exec_Line
                  elsif Break then Theme.Edit_Breakpoint
                  else Theme.Edit_Error_Line);
            begin
               Syntax.Classify (E.Lang, L, Classes);
               for C in L'Range loop
                  Width := (if L (C) = HT
                            then (V / Settings.Tab_Size + 1) * Settings.Tab_Size - V
                            else 1);
                  if Whole then
                     A := Line_A;
                  elsif In_Selection (E, (N, C)) then
                     A := Theme.Edit_Selected;
                  elsif Diag_Level (E, (N, C)) /= No_Diag then
                     A := (if Diag_Level (E, (N, C)) = Diag_Error
                           then Theme.Edit_Diag_Error else Theme.Edit_Diag_Warn);
                  else
                     A := (case Classes (C) is
                              when Syntax.Normal     => Theme.Edit_Text,
                              when Syntax.Keyword    => Theme.Edit_Keyword,
                              when Syntax.Comment    => Theme.Edit_Comment,
                              when Syntax.String_Lit => Theme.Edit_String,
                              when Syntax.Number     => Theme.Edit_Number,
                              when Syntax.Directive  => Theme.Edit_Pragma);
                  end if;
                  for K in 0 .. Width - 1 loop
                     if V + K >= E.Left then
                        Put (I.X + V + K - E.Left, Y,
                             (if L (C) = HT then ' ' else L (C)), A);
                     end if;
                  end loop;
                  V := V + Width;
                  exit when V >= E.Left + I.W;
               end loop;
               if Whole then
                  Paint (I.X, Y, I.W, 1, Line_A);
               elsif Has_Selection (E) and then N >= Sel_Start (E).Line
                 and then N < Sel_End (E).Line
                 and then V >= E.Left
               then
                  --  Show the selected line end as one selected blank.
                  Put (I.X + V - E.Left, Y, ' ', Theme.Edit_Selected);
               end if;
            end;
         end;
      end loop;
      Reset_Clip;

      Draw_Frame (E, Active, Colors,
                  V_Pos => E.Cur.Line - 1, V_Total => E.Buf.Line_Count,
                  V_Page => I.H,
                  H_Pos => E.Left, H_Total => Natural'Max (E.Left + I.W, 256),
                  H_Page => I.W,
                  Indicator => Indic);

      if Active then
         declare
            VC : constant Natural := VCol (E.Buf.Line (E.Cur.Line), E.Cur.Col);
            CX : constant Integer := I.X + VC - E.Left;
            CY : constant Integer := I.Y + E.Cur.Line - E.Top;
         begin
            if CX in I.X .. I.X + I.W - 1 and then CY in I.Y .. I.Y + I.H - 1 then
               Set_Cursor (CX, CY, Block => not Settings.Insert_Mode);
            else
               Hide_Cursor;
            end if;
         end;
      end if;
   end Draw;

   --  Primitive edits through the buffer, keeping the cursor right.

   procedure Delete_Selection (E : in out Editor) is
      S : constant Position := Sel_Start (E);
   begin
      if Has_Selection (E) then
         E.Buf.Delete (S, Sel_End (E));
         E.Cur := S;
      end if;
      Drop_Selection (E);
   end Delete_Selection;

   procedure Insert_Text (E : in out Editor; S : Wide_Wide_String) is
      After : Position;
   begin
      E.Buf.Insert (E.Cur, S, After);
      E.Cur := After;
   end Insert_Text;

   procedure Begin_Edit_Group (E : in out Editor) is
   begin
      E.Buf.Begin_Group (E.Cur);
   end Begin_Edit_Group;

   procedure End_Edit_Group (E : in out Editor) is
   begin
      E.Buf.End_Group;
   end End_Edit_Group;

   procedure Replace_Range (E : in out Editor; From, To : Position; Text : Wide_Wide_String) is
      F     : constant Position := E.Buf.Clamp (From);
      T     : constant Position := E.Buf.Clamp (To);
      After : Position;
   begin
      Drop_Selection (E);
      E.Buf.Begin_Group (E.Cur);
      if F < T then
         E.Buf.Delete (F, T);
      end if;
      E.Buf.Insert (F, Text, After);
      E.Buf.End_Group;
      E.Cur := After;
      Moved (E);
   end Replace_Range;

   function Word_Start (E : Editor) return Position is
      L : constant Wide_Wide_String := E.Buf.Line (E.Cur.Line);
      C : Positive := Positive'Min (E.Cur.Col, L'Length + 1);
   begin
      while C > 1 and then Is_Word_Char (L (C - 1)) loop
         C := C - 1;
      end loop;
      return (E.Cur.Line, C);
   end Word_Start;

   procedure Cursor_Screen (E : Editor; X, Y : out Integer) is
      I : constant Rect := Interior (E);
   begin
      X := I.X + VCol (E.Buf.Line (E.Cur.Line), E.Cur.Col) - E.Left;
      Y := I.Y + E.Cur.Line - E.Top;
   end Cursor_Screen;

   procedure Replace_Selection (E : in out Editor; Text : Wide_Wide_String) is
   begin
      E.Buf.Begin_Group (E.Cur);
      Delete_Selection (E);
      Insert_Text (E, Text);
      E.Buf.End_Group;
      Moved (E);
   end Replace_Selection;

   procedure Type_Char (E : in out Editor; C : Wide_Wide_Character) is
   begin
      if Has_Selection (E) and then not E.Persistent then
         E.Buf.Begin_Group (E.Cur);
         Delete_Selection (E);
         Insert_Text (E, (1 => C));
         E.Buf.End_Group;
      elsif not Settings.Insert_Mode
        and then E.Cur.Col <= E.Buf.Line_Length (E.Cur.Line)
      then
         E.Buf.Begin_Group (E.Cur);
         E.Buf.Delete (E.Cur, (E.Cur.Line, E.Cur.Col + 1));
         Insert_Text (E, (1 => C));
         E.Buf.End_Group;
      else
         if not E.Persistent then
            Drop_Selection (E);
         end if;
         Insert_Text (E, (1 => C));
      end if;
      E.Want_VCol := VCol (E.Buf.Line (E.Cur.Line), E.Cur.Col);
      E.Error_Line := 0;
      Ensure_Visible (E);
   end Type_Char;

   function Opens_Block (Line : Wide_Wide_String) return Boolean is
   --  Ada: does this line leave the next one indented one level deeper?
      use Ada.Wide_Wide_Characters.Handling;
      use Ada.Strings.Wide_Wide_Fixed;
      Code : Wide_Wide_String := Line;
      Last : Natural;
      function Ends_With (W : Wide_Wide_String) return Boolean is
        (Last >= W'Length
         and then Code (Last - W'Length + 1 .. Last) = W
         and then (Last = W'Length
                   or else not Is_Word_Char (Code (Last - W'Length))));
   begin
      --  Drop a trailing comment (not inside a string: good enough for the
      --  lines this is asked about).
      declare
         Dash : constant Natural := Index (Code, "--");
      begin
         if Dash > 0 then
            Code (Dash .. Code'Last) := [others => ' '];
         end if;
      end;
      Code := To_Lower (Code);
      Last := Code'Last;
      while Last >= Code'First and then Is_Blank (Code (Last)) loop
         Last := Last - 1;
      end loop;
      if Last < Code'First then
         return False;
      end if;
      return Ends_With ("is") or else Ends_With ("then")
        or else Ends_With ("loop") or else Ends_With ("begin")
        or else Ends_With ("else") or else Ends_With ("declare")
        or else Ends_With ("record") or else Ends_With ("do")
        or else Ends_With ("private") or else Ends_With ("select")
        or else Ends_With ("exception") or else Ends_With ("generic")
        or else Ends_With ("=>");
   end Opens_Block;

   procedure New_Line (E : in out Editor) is
      L      : constant Wide_Wide_String := E.Buf.Line (E.Cur.Line);
      Indent : Natural := 0;
   begin
      E.Buf.Begin_Group (E.Cur);
      if Has_Selection (E) and then not E.Persistent then
         Delete_Selection (E);
      end if;
      if Settings.Auto_Indent then
         Indent := VCol (L, Leading_Blanks (L) + 1);
         if E.Lang = Syntax.Ada_Lang and then E.Cur.Col > L'Length
           and then Opens_Block (L)
         then
            Indent := Indent + Settings.Indent_Size;
         end if;
         --  Splitting inside the indentation: do not indent past the cursor.
         if E.Cur.Col <= Leading_Blanks (L) then
            Indent := VCol (L, E.Cur.Col);
         end if;
      end if;
      --  A line left holding only blanks keeps none of them.
      if Settings.Auto_Indent and then E.Cur.Col > L'Length
        and then Leading_Blanks (L) = L'Length and then L'Length > 0
      then
         E.Buf.Delete ((E.Cur.Line, 1), (E.Cur.Line, L'Length + 1));
         E.Cur.Col := 1;
      end if;
      declare
         Rest : constant Wide_Wide_String :=
           E.Buf.Line (E.Cur.Line) (E.Cur.Col .. E.Buf.Line_Length (E.Cur.Line));
         Skip : constant Natural := Leading_Blanks (Rest);
      begin
         --  The text moved down loses its old leading blanks; it gets the
         --  computed indentation instead.
         if Skip > 0 and then Settings.Auto_Indent then
            E.Buf.Delete (E.Cur, (E.Cur.Line, E.Cur.Col + Skip));
         end if;
      end;
      Insert_Text (E, LF & (1 .. Indent => ' '));
      E.Buf.End_Group;
      Moved (E);
   end New_Line;

   procedure Backspace (E : in out Editor) is
   begin
      if Has_Selection (E) and then not E.Persistent then
         Delete_Selection (E);
      elsif E.Cur.Col > 1 then
         declare
            L : constant Wide_Wide_String := E.Buf.Line (E.Cur.Line);
         begin
            if Settings.Auto_Indent and then Leading_Blanks (L) >= E.Cur.Col - 1
              and then L (E.Cur.Col - 1) = ' '
            then
               --  In the indentation: back to the previous indent stop.
               declare
                  V      : constant Natural := VCol (L, E.Cur.Col);
                  Target : constant Natural :=
                    ((V - 1) / Settings.Indent_Size) * Settings.Indent_Size;
                  From   : Positive := E.Cur.Col;
               begin
                  while From > 1 and then L (From - 1) = ' '
                    and then VCol (L, From - 1) >= Target
                  loop
                     From := From - 1;
                  end loop;
                  E.Buf.Delete ((E.Cur.Line, From), E.Cur);
                  E.Cur.Col := From;
               end;
            else
               E.Buf.Delete ((E.Cur.Line, E.Cur.Col - 1), E.Cur);
               E.Cur.Col := E.Cur.Col - 1;
            end if;
         end;
      elsif E.Cur.Line > 1 then
         declare
            Prev_Len : constant Natural := E.Buf.Line_Length (E.Cur.Line - 1);
         begin
            E.Buf.Delete ((E.Cur.Line - 1, Prev_Len + 1), E.Cur);
            E.Cur := (E.Cur.Line - 1, Prev_Len + 1);
         end;
      end if;
      Moved (E);
   end Backspace;

   procedure Delete_Char (E : in out Editor) is
   begin
      if Has_Selection (E) and then not E.Persistent then
         Delete_Selection (E);
      elsif E.Cur.Col <= E.Buf.Line_Length (E.Cur.Line) then
         E.Buf.Delete (E.Cur, (E.Cur.Line, E.Cur.Col + 1));
      elsif E.Cur.Line < E.Buf.Line_Count then
         E.Buf.Delete (E.Cur, (E.Cur.Line + 1, 1));
      end if;
      Moved (E);
   end Delete_Char;

   procedure Delete_Line (E : in out Editor) is
   begin
      Drop_Selection (E);
      if E.Cur.Line < E.Buf.Line_Count then
         E.Buf.Delete ((E.Cur.Line, 1), (E.Cur.Line + 1, 1));
      else
         E.Buf.Delete ((E.Cur.Line, 1), (E.Cur.Line, E.Buf.Line_Length (E.Cur.Line) + 1));
      end if;
      E.Cur.Col := 1;
      Moved (E);
   end Delete_Line;

   function Word_Right (E : Editor; P : Position) return Position is
      L : constant Wide_Wide_String := E.Buf.Line (P.Line);
      C : Positive := P.Col;
   begin
      if C > L'Length then
         return (if P.Line < E.Buf.Line_Count then (P.Line + 1, 1) else P);
      end if;
      if Is_Word_Char (L (C)) then
         while C <= L'Length and then Is_Word_Char (L (C)) loop
            C := C + 1;
         end loop;
      else
         C := C + 1;
      end if;
      while C <= L'Length and then Is_Blank (L (C)) loop
         C := C + 1;
      end loop;
      return (P.Line, C);
   end Word_Right;

   function Word_Left (E : Editor; P : Position) return Position is
      C : Natural := P.Col;
   begin
      if C = 1 then
         return (if P.Line > 1 then (P.Line - 1, E.Buf.Line_Length (P.Line - 1) + 1)
                 else P);
      end if;
      declare
         L : constant Wide_Wide_String := E.Buf.Line (P.Line);
      begin
         while C > 1 and then Is_Blank (L (C - 1)) loop
            C := C - 1;
         end loop;
         if C > 1 and then Is_Word_Char (L (C - 1)) then
            while C > 1 and then Is_Word_Char (L (C - 1)) loop
               C := C - 1;
            end loop;
         elsif C > 1 then
            C := C - 1;
         end if;
      end;
      return (P.Line, Positive'Max (C, 1));
   end Word_Left;

   procedure Indent_Lines (E : in out Editor; Out_Dent : Boolean) is
      First : Positive := E.Cur.Line;
      Last  : Positive := E.Cur.Line;
   begin
      if Has_Selection (E) then
         First := Sel_Start (E).Line;
         Last := Sel_End (E).Line;
         if Sel_End (E).Col = 1 and then Last > First then
            Last := Last - 1;
         end if;
      end if;
      E.Buf.Begin_Group (E.Cur);
      for N in First .. Last loop
         if Out_Dent then
            declare
               L : constant Wide_Wide_String := E.Buf.Line (N);
               K : constant Natural :=
                 Natural'Min (Leading_Blanks (L), Settings.Indent_Size);
            begin
               if K > 0 then
                  E.Buf.Delete ((N, 1), (N, K + 1));
               end if;
            end;
         elsif E.Buf.Line_Length (N) > 0 then
            declare
               Ignore : Position;
            begin
               E.Buf.Insert ((N, 1), (1 .. Settings.Indent_Size => ' '), Ignore);
            end;
         end if;
      end loop;
      E.Buf.End_Group;
      if Has_Selection (E) then
         E.Sel_A := (First, 1);
         E.Sel_B := (Last + 1, 1);
         if Last + 1 > E.Buf.Line_Count then
            E.Sel_B := E.Buf.Last_Position;
         end if;
         E.Cur := E.Buf.Clamp (E.Sel_B);
      end if;
      E.Cur := E.Buf.Clamp (E.Cur);
      Moved (E);
   end Indent_Lines;

   procedure Tab_Key (E : in out Editor) is
   begin
      if Has_Selection (E) and then Sel_Start (E).Line /= Sel_End (E).Line then
         Indent_Lines (E, Out_Dent => False);
      else
         declare
            V    : constant Natural := VCol (E.Buf.Line (E.Cur.Line), E.Cur.Col);
            Stop : constant Natural :=
              (V / Settings.Indent_Size + 1) * Settings.Indent_Size;
         begin
            if Has_Selection (E) and then not E.Persistent then
               Delete_Selection (E);
            end if;
            Insert_Text (E, (1 .. Stop - V => ' '));
            Moved (E);
         end;
      end if;
   end Tab_Key;

   --  Cursor motion; Shift extends the selection.

   procedure Move (E : in out Editor; To : Position; Extend : Boolean;
                   Keep_Want : Boolean := False) is
   begin
      if Extend then
         if not E.Has_Sel or else E.Persistent then
            E.Sel_A := E.Cur;
            E.Persistent := False;
         end if;
         E.Has_Sel := True;
         E.Cur := E.Buf.Clamp (To);
         E.Sel_B := E.Cur;
      else
         if not E.Persistent then
            E.Has_Sel := False;
         end if;
         E.Cur := E.Buf.Clamp (To);
      end if;
      Moved (E, Keep_Want);
   end Move;

   function Vertical (E : Editor; Line : Integer) return Position is
      N : constant Positive :=
        Positive (Integer'Max (1, Integer'Min (Line, E.Buf.Line_Count)));
   begin
      return (N, Col_At (E.Buf.Line (N), E.Want_VCol));
   end Vertical;

   function Smart_Home (E : Editor) return Position is
   --  Home goes to the first non-blank, then to column 1.
      L : constant Wide_Wide_String := E.Buf.Line (E.Cur.Line);
      First : constant Positive := Leading_Blanks (L) + 1;
   begin
      return (E.Cur.Line, (if E.Cur.Col = First then 1 else First));
   end Smart_Home;

   function Position_At (E : Editor; X, Y : Integer) return Position is
      I : constant Rect := Interior (E);
      N : constant Integer :=
        Integer'Max (1, Integer'Min (E.Top + (Y - I.Y), E.Buf.Line_Count));
      V : constant Integer := Integer'Max (0, E.Left + (X - I.X));
   begin
      return (N, Col_At (E.Buf.Line (N), V));
   end Position_At;

   procedure Scroll_By (E : in out Editor; Lines : Integer) is
      Max_Top : constant Integer := Integer'Max (1, E.Buf.Line_Count - Page (E) + 1);
   begin
      E.Top := Positive (Integer'Max (1, Integer'Min (E.Top + Lines, Max_Top)));
   end Scroll_By;

   --  Edit menu

   procedure Undo (E : in out Editor) is
      P : Position;
   begin
      if E.Buf.Can_Undo then
         E.Buf.Undo (P);
         E.Cur := P;
         Drop_Selection (E);
         Moved (E);
      end if;
   end Undo;

   procedure Redo (E : in out Editor) is
      P : Position;
   begin
      if E.Buf.Can_Redo then
         E.Buf.Redo (P);
         E.Cur := P;
         Drop_Selection (E);
         Moved (E);
      end if;
   end Redo;

   procedure Copy (E : in out Editor) is
   begin
      if Has_Selection (E) then
         Clipboard.Set (Selected_Text (E));
      end if;
   end Copy;

   procedure Cut (E : in out Editor) is
   begin
      if Has_Selection (E) then
         Clipboard.Set (Selected_Text (E));
         Delete_Selection (E);
         Moved (E);
      end if;
   end Cut;

   procedure Paste_Text (E : in out Editor; S : Wide_Wide_String) is
   begin
      if S'Length = 0 then
         return;
      end if;
      E.Buf.Begin_Group (E.Cur);
      if Has_Selection (E) and then not E.Persistent then
         Delete_Selection (E);
      end if;
      Insert_Text (E, S);
      E.Buf.End_Group;
      Moved (E);
   end Paste_Text;

   procedure Paste (E : in out Editor) is
   begin
      Paste_Text (E, Clipboard.Get);
   end Paste;

   procedure Clear (E : in out Editor) is
   begin
      if Has_Selection (E) then
         Delete_Selection (E);
         Moved (E);
      end if;
   end Clear;

   procedure Select_All (E : in out Editor) is
   begin
      E.Sel_A := (1, 1);
      E.Sel_B := E.Buf.Last_Position;
      E.Has_Sel := True;
      E.Persistent := False;
      E.Cur := E.Sel_B;
      Moved (E);
   end Select_All;

   function Can_Undo (E : Editor) return Boolean is (E.Buf.Can_Undo);
   function Can_Redo (E : Editor) return Boolean is (E.Buf.Can_Redo);

   function Word_At_Cursor (E : Editor) return Wide_Wide_String is
      L : constant Wide_Wide_String := E.Buf.Line (E.Cur.Line);
      A : Positive := Positive'Min (E.Cur.Col, L'Length + 1);
      B : Natural;
   begin
      if Has_Selection (E) and then Sel_Start (E).Line = Sel_End (E).Line then
         return Selected_Text (E);
      end if;
      if A > L'Length or else not Is_Word_Char (L (A)) then
         if A > 1 and then A - 1 <= L'Length and then Is_Word_Char (L (A - 1)) then
            A := A - 1;
         else
            return "";
         end if;
      end if;
      while A > 1 and then Is_Word_Char (L (A - 1)) loop
         A := A - 1;
      end loop;
      B := A;
      while B < L'Length and then Is_Word_Char (L (B + 1)) loop
         B := B + 1;
      end loop;
      return L (A .. B);
   end Word_At_Cursor;

   procedure Select_Word_At (E : in out Editor; P : Position) is
      L : constant Wide_Wide_String := E.Buf.Line (P.Line);
      A : Positive := P.Col;
      B : Positive := P.Col;
   begin
      if A > L'Length or else not Is_Word_Char (L (A)) then
         return;
      end if;
      while A > 1 and then Is_Word_Char (L (A - 1)) loop
         A := A - 1;
      end loop;
      while B <= L'Length and then Is_Word_Char (L (B)) loop
         B := B + 1;
      end loop;
      E.Sel_A := (P.Line, A);
      E.Sel_B := (P.Line, B);
      E.Has_Sel := True;
      E.Persistent := False;
      E.Cur := E.Sel_B;
   end Select_Word_At;

   --  Files

   procedure Trim_Trailing (E : in out Editor) is
   begin
      E.Buf.Begin_Group (E.Cur);
      for N in 1 .. E.Buf.Line_Count loop
         declare
            L    : constant Wide_Wide_String := E.Buf.Line (N);
            Last : Natural := L'Last;
         begin
            while Last >= L'First and then Is_Blank (L (Last)) loop
               Last := Last - 1;
            end loop;
            if Last < L'Last and then not (N = E.Cur.Line and then E.Cur.Col > Last + 1)
            then
               E.Buf.Delete ((N, Last + 1), (N, L'Last + 1));
            end if;
         end;
      end loop;
      E.Buf.End_Group;
      E.Cur := E.Buf.Clamp (E.Cur);
   end Trim_Trailing;

   procedure Save (E : in out Editor; Ok : out Boolean) is
      Name : constant String := Path (E);
   begin
      Ok := False;
      if Name = "" then
         return;
      end if;
      if Settings.Trim_Trailing then
         Trim_Trailing (E);
      end if;
      if Settings.Backup_Files and then Ada.Directories.Exists (Name) then
         begin
            Ada.Directories.Copy_File (Name, Name & ".bak");
         exception
            when others => null;
         end;
      end if;
      E.Buf.Save (Name, Ok);
      if Ok then
         E.Bad_Load := False;
      end if;
   end Save;

   procedure Save_As (E : in out Editor; File_Name : String; Ok : out Boolean) is
      Old : constant Unbounded_String := E.File_Name;
   begin
      E.File_Name := To_Unbounded_String (Ada.Directories.Full_Name (File_Name));
      Save (E, Ok);
      if Ok then
         E.Lang := Syntax.Language_Of (File_Name);
      else
         E.File_Name := Old;
      end if;
   end Save_As;

   procedure Go_To (E : in out Editor; Line, Col : Positive;
                    Mark_Error : Boolean := False) is
   begin
      Drop_Selection (E);
      E.Cur := E.Buf.Clamp ((Line, Col));
      Moved (E);
      --  Centre the line, as Turbo C++ does when it jumps to an error.
      E.Top := Positive (Integer'Max (1, E.Cur.Line - Page (E) / 2));
      Ensure_Visible (E);
      E.Error_Line := (if Mark_Error then E.Cur.Line else 0);
   end Go_To;

   function Find_Next
     (E          : in out Editor;
      Pattern    : Wide_Wide_String;
      Match_Case : Boolean;
      Whole_Word : Boolean;
      Backward   : Boolean;
      From_Top   : Boolean := False) return Boolean
   is
      Start : Position;
      Found : Position;
   begin
      if From_Top then
         Start := (if Backward then E.Buf.Last_Position else (1, 1));
      elsif Has_Selection (E) then
         Start := (if Backward then Sel_Start (E)
                   else (Sel_Start (E).Line, Sel_Start (E).Col + 1));
      else
         Start := E.Cur;
      end if;
      if E.Buf.Find (Pattern, Start, not Backward, Match_Case, Whole_Word, Found)
      then
         E.Sel_A := Found;
         E.Sel_B := (Found.Line, Found.Col + Pattern'Length);
         E.Has_Sel := True;
         E.Persistent := False;
         E.Cur := E.Sel_B;
         Moved (E);
         return True;
      end if;
      return False;
   end Find_Next;

   --  Keys

   procedure Handle_Prefix (E : in out Editor; Ev : Event) is
   --  The second key of a Ctrl-K / Ctrl-Q pair (with or without Ctrl).
      P : constant Character := E.Prefix;
      C : Wide_Wide_Character := Ev.Ch;
   begin
      E.Prefix := ' ';
      if Ev.Kind /= Key or else Ev.Code /= Char_Key then
         return;
      end if;
      if C in 'A' .. 'Z' then
         C := Wide_Wide_Character'Val (Wide_Wide_Character'Pos (C) + 32);
      end if;
      if P = 'k' then
         case C is
            when 'b' =>
               E.Sel_A := E.Cur;
               if not E.Persistent then
                  E.Sel_B := E.Cur;
               end if;
               E.Has_Sel := True;
               E.Persistent := True;
            when 'k' =>
               if not E.Persistent then
                  E.Sel_A := E.Cur;
               end if;
               E.Sel_B := E.Cur;
               E.Has_Sel := True;
               E.Persistent := True;
            when 'h' =>
               Drop_Selection (E);
            when 'y' =>
               if Has_Selection (E) then
                  Delete_Selection (E);
                  Moved (E);
               end if;
            when 'c' | 'v' =>
               if Has_Selection (E) and then not In_Selection (E, E.Cur) then
                  declare
                     T     : constant Wide_Wide_String := Selected_Text (E);
                     S     : constant Position := Sel_Start (E);
                     F     : constant Position := Sel_End (E);
                     Start : Position := E.Cur;
                     After : Position;
                  begin
                     E.Buf.Begin_Group (E.Cur);
                     if C = 'v' then
                        E.Buf.Delete (S, F);
                        if F < Start or else F = Start then
                           --  The block was before the cursor: shift it back.
                           if Start.Line = F.Line then
                              Start := (S.Line, S.Col + (Start.Col - F.Col));
                           else
                              Start.Line := Start.Line - (F.Line - S.Line);
                           end if;
                        end if;
                     end if;
                     E.Buf.Insert (Start, T, After);
                     E.Buf.End_Group;
                     E.Sel_A := Start;
                     E.Sel_B := After;
                     E.Has_Sel := True;
                     E.Persistent := True;
                     E.Cur := Start;
                     Moved (E);
                  end;
               end if;
            when 'i' =>
               Indent_Lines (E, Out_Dent => False);
            when 'u' =>
               Indent_Lines (E, Out_Dent => True);
            when 's' | 'd' =>
               E.Request := Turbo.Commands.Cmd_Save;
            when others =>
               null;
         end case;
      else  --  'q'
         case C is
            when 'y' =>
               E.Buf.Delete (E.Cur, (E.Cur.Line, E.Buf.Line_Length (E.Cur.Line) + 1));
               Moved (E);
            when 'r' => Move (E, (1, 1), False);
            when 'c' => Move (E, E.Buf.Last_Position, False);
            when 's' => Move (E, (E.Cur.Line, 1), False);
            when 'd' => Move (E, (E.Cur.Line, E.Buf.Line_Length (E.Cur.Line) + 1), False);
            when 'e' => Move (E, (E.Top, E.Cur.Col), False);
            when 'x' => Move (E, (E.Top + Page (E) - 1, E.Cur.Col), False);
            when 'b' => if E.Has_Sel then Move (E, Sel_Start (E), False); end if;
            when 'k' => if E.Has_Sel then Move (E, Sel_End (E), False); end if;
            when 'f' => E.Request := Turbo.Commands.Cmd_Find;
            when 'a' => E.Request := Turbo.Commands.Cmd_Replace;
            when others => null;
         end case;
      end if;
   end Handle_Prefix;

   procedure Handle_Mouse (E : in out Editor; Ev : Event; Handled : out Boolean) is
      I : constant Rect := Interior (E);
      H : constant Hit_Kind := Hit (E, Ev.X, Ev.Y);
   begin
      Handled := True;
      case Ev.Action is
         when Wheel_Up =>
            Scroll_By (E, -3);
         when Wheel_Down =>
            Scroll_By (E, 3);
         when Press =>
            case H is
               when V_Scroll_Up => Scroll_By (E, -1);
               when V_Scroll_Down => Scroll_By (E, 1);
               when V_Scroll_Page_Up => Scroll_By (E, -Page (E));
               when V_Scroll_Page_Down => Scroll_By (E, Page (E));
               when H_Scroll_Left => E.Left := Natural'Max (0, E.Left - 1);
               when H_Scroll_Right => E.Left := E.Left + 1;
               when H_Scroll_Page_Left => E.Left := Natural'Max (0, E.Left - I.W / 2);
               when H_Scroll_Page_Right => E.Left := E.Left + I.W / 2;
               when Inside =>
                  declare
                     P   : constant Position := Position_At (E, Ev.X, Ev.Y);
                     Now : constant Ada.Calendar.Time := Ada.Calendar.Clock;
                  begin
                     E.Prefix := ' ';
                     if Ev.Shift then
                        Move (E, P, Extend => True);
                     elsif Now - E.Last_Click < 0.4 and then P = E.Last_Click_Pos then
                        Select_Word_At (E, P);
                        E.Mouse_Sel := False;
                     else
                        Drop_Selection (E);
                        E.Cur := P;
                        E.Sel_A := P;
                        E.Sel_B := P;
                        E.Mouse_Sel := True;
                        Moved (E);
                     end if;
                     E.Last_Click := Now;
                     E.Last_Click_Pos := P;
                  end;
               when others =>
                  Handled := False;
            end case;
         when Drag =>
            if E.Mouse_Sel then
               --  Dragging past the edge scrolls.
               if Ev.Y < I.Y then
                  Scroll_By (E, -1);
               elsif Ev.Y >= I.Y + I.H then
                  Scroll_By (E, 1);
               end if;
               E.Cur := Position_At
                 (E, Integer'Max (I.X, Integer'Min (Ev.X, I.X + I.W - 1)),
                  Integer'Max (I.Y, Integer'Min (Ev.Y, I.Y + I.H - 1)));
               E.Sel_B := E.Cur;
               E.Has_Sel := E.Sel_A /= E.Sel_B;
               E.Want_VCol := VCol (E.Buf.Line (E.Cur.Line), E.Cur.Col);
            else
               Handled := False;
            end if;
         when Release =>
            E.Mouse_Sel := False;
      end case;
   end Handle_Mouse;

   overriding procedure Handle_Event
     (E : in out Editor; E_In : Event; Handled : out Boolean)
   is
      Ev : Event renames E_In;
      S  : constant Boolean := Ev.Shift;
   begin
      Handled := True;

      if Ev.Kind = Mouse then
         Handle_Mouse (E, Ev, Handled);
         return;
      elsif Ev.Kind = Paste then
         Paste_Text (E, Ada.Strings.Wide_Wide_Unbounded.To_Wide_Wide_String (Ev.Text));
         return;
      elsif Ev.Kind /= Key then
         Handled := False;
         return;
      end if;

      if E.Prefix /= ' ' then
         Handle_Prefix (E, Ev);
         return;
      end if;

      case Ev.Code is
         when Up =>
            if Ev.Ctrl then
               Scroll_By (E, -1);
               if E.Cur.Line >= E.Top + Page (E) then
                  Move (E, Vertical (E, E.Top + Page (E) - 1), S, True);
               end if;
            else
               Move (E, Vertical (E, E.Cur.Line - 1), S, True);
            end if;
         when Down =>
            if Ev.Ctrl then
               Scroll_By (E, 1);
               if E.Cur.Line < E.Top then
                  Move (E, Vertical (E, E.Top), S, True);
               end if;
            else
               Move (E, Vertical (E, E.Cur.Line + 1), S, True);
            end if;
         when Left =>
            if Ev.Ctrl then
               Move (E, Word_Left (E, E.Cur), S);
            elsif E.Cur.Col > 1 then
               Move (E, (E.Cur.Line, E.Cur.Col - 1), S);
            elsif E.Cur.Line > 1 then
               Move (E, (E.Cur.Line - 1, E.Buf.Line_Length (E.Cur.Line - 1) + 1), S);
            end if;
         when Right =>
            if Ev.Ctrl then
               Move (E, Word_Right (E, E.Cur), S);
            elsif E.Cur.Col <= E.Buf.Line_Length (E.Cur.Line) then
               Move (E, (E.Cur.Line, E.Cur.Col + 1), S);
            elsif E.Cur.Line < E.Buf.Line_Count then
               Move (E, (E.Cur.Line + 1, 1), S);
            end if;
         when Home =>
            Move (E, (if Ev.Ctrl then (1, 1) else Smart_Home (E)), S);
         when End_Key =>
            Move (E, (if Ev.Ctrl then E.Buf.Last_Position
                      else (E.Cur.Line, E.Buf.Line_Length (E.Cur.Line) + 1)), S);
         when Page_Up =>
            if Ev.Ctrl then
               Move (E, (1, 1), S);
            else
               Scroll_By (E, -Page (E));
               Move (E, Vertical (E, E.Cur.Line - Page (E)), S, True);
            end if;
         when Page_Down =>
            if Ev.Ctrl then
               Move (E, E.Buf.Last_Position, S);
            else
               Scroll_By (E, Page (E));
               Move (E, Vertical (E, E.Cur.Line + Page (E)), S, True);
            end if;
         when Insert =>
            if Ev.Ctrl then
               Copy (E);
            elsif Ev.Shift then
               Paste (E);
            else
               Settings.Insert_Mode := not Settings.Insert_Mode;
            end if;
         when Delete =>
            if Ev.Shift then
               Cut (E);
            elsif Ev.Ctrl then
               Clear (E);
            else
               Delete_Char (E);
            end if;
         when Backspace =>
            if Ev.Alt then
               if Ev.Shift then
                  Redo (E);
               else
                  Undo (E);
               end if;
            elsif Ev.Ctrl then
               declare
                  P : constant Position := Word_Left (E, E.Cur);
               begin
                  E.Buf.Delete (P, E.Cur);
                  E.Cur := P;
                  Moved (E);
               end;
            else
               Backspace (E);
            end if;
         when Enter =>
            if Ev.Ctrl or else Ev.Alt then
               Handled := False;
            else
               New_Line (E);
            end if;
         when Tab =>
            if Ev.Ctrl or else Ev.Alt then
               Handled := False;
            elsif Ev.Shift then
               Indent_Lines (E, Out_Dent => True);
            else
               Tab_Key (E);
            end if;
         when Char_Key =>
            if Ev.Ctrl and then not Ev.Alt then
               case Ev.Ch is
                  when 'k' => E.Prefix := 'k';
                  when 'q' => E.Prefix := 'q';
                  when 'y' => Delete_Line (E);
                  when 't' =>
                     E.Buf.Delete (E.Cur, Word_Right (E, E.Cur));
                     Moved (E);
                  when 'z' => Undo (E);
                  when 'c' => Copy (E);
                  when 'x' => Cut (E);
                  when 'v' => Paste (E);
                  when 'a' => Select_All (E);
                  when others => Handled := False;
               end case;
            elsif Is_Plain_Char (Ev) then
               Type_Char (E, Ev.Ch);
            else
               Handled := False;
            end if;
         when others =>
            Handled := False;
      end case;
   end Handle_Event;

end Turbo.Editors;
