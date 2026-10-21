with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Wide_Wide_Fixed;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Unchecked_Deallocation;
with Turbo.Buffers;
with Turbo.Clipboard;
with Turbo.Commands;
with Turbo.Desktop;
with Turbo.Editors;
with Turbo.Events;
with Turbo.Help;
with Turbo.Jobs;
with Turbo.Menus;
with Turbo.Messages;
with Turbo.Projects;
with Turbo.Screen;
with Turbo.Settings;
with Turbo.Syntax;
with Turbo.Term;
with Turbo.Theme;
with Turbo.Viewers;
with Turbo.Windows;

package body Turbo.App is

   use Ada.Strings.Unbounded;
   use Turbo.Commands;
   use Turbo.Events;
   use Turbo.Windows;
   use type Turbo.Projects.Project_Kind;
   use type Turbo.Editors.Editor_Access;
   use type Turbo.Viewers.Viewer_Access;
   use type Turbo.Dialogs.Answer;
   use type Turbo.Syntax.Language;
   use type Ada.Directories.File_Kind;

   package Dlg renames Turbo.Dialogs;
   package Prj renames Turbo.Projects;

   subtype String_List is Dlg.String_List;

   Msg_Win      : Messages.Message_Window_Access;
   Help_Win     : Viewers.Viewer_Access;
   Untitled_N   : Natural := 0;
   Find_Opt     : Dlg.Find_Options;
   Have_Search  : Boolean := False;
   Quit         : Boolean := False;

   --  Strings

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

   function Encode (S : Wide_Wide_String) return String is
     (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (S));

   function Img (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

   function Simple (Path : String) return String is
   begin
      return Ada.Directories.Simple_Name (Path);
   exception
      when others => return Path;
   end Simple;

   --  Windows

   function Active_Editor return Editors.Editor_Access is
      W : constant Window_Access := Desktop.Active;
   begin
      if W /= null and then W.all in Editors.Editor'Class then
         return Editors.Editor_Access (W);
      end if;
      return null;
   end Active_Editor;

   function In_Desktop (W : Window_Access) return Boolean is
   begin
      for K in 1 .. Desktop.Count loop
         if Desktop.Nth (K) = W then
            return True;
         end if;
      end loop;
      return False;
   end In_Desktop;

   function Message_Bounds return Rect is
      A : constant Rect := Desktop.Area;
      H : constant Integer := Integer'Max (5, Integer'Min (9, A.H / 3));
   begin
      return (A.X, A.Y + A.H - H, A.W, H);
   end Message_Bounds;

   procedure Show_Message_Window (Activate : Boolean) is
      W : constant Window_Access := Window_Access (Msg_Win);
   begin
      if not In_Desktop (W) then
         Msg_Win.Bounds := Message_Bounds;
         Desktop.Add (W);
      end if;
      if Activate then
         Desktop.Activate (W);
      end if;
   end Show_Message_Window;

   procedure Show_Help (Title, Text : String) is
      A : constant Rect := Desktop.Area;
   begin
      if Help_Win /= null and then In_Desktop (Window_Access (Help_Win)) then
         Desktop.Remove (Window_Access (Help_Win));
      end if;
      Help_Win := Viewers.Create (Title, Text);
      if not In_Desktop (Window_Access (Help_Win)) then
         Help_Win.Bounds :=
           (A.X + Integer'Max (0, (A.W - 72) / 2), A.Y + 1,
            Integer'Min (A.W, 72), Integer'Max (8, A.H - 2));
         Desktop.Add (Window_Access (Help_Win));
      end if;
      Desktop.Activate (Window_Access (Help_Win));
   end Show_Help;

   function Find_Editor (Path : String) return Editors.Editor_Access is
   begin
      for K in 1 .. Desktop.Count loop
         if Desktop.Nth (K).all in Editors.Editor'Class then
            declare
               E : constant Editors.Editor_Access :=
                 Editors.Editor_Access (Desktop.Nth (K));
            begin
               if E.Path = Path then
                  return E;
               end if;
            end;
         end if;
      end loop;
      return null;
   end Find_Editor;

   function Open_File (Path : String; Activate : Boolean := True)
                       return Editors.Editor_Access
   is
      Full : constant String :=
        (if Path = "" then "" else Ada.Directories.Full_Name (Path));
      E    : Editors.Editor_Access := (if Full = "" then null else Find_Editor (Full));
   begin
      if E = null then
         if Full = "" then
            E := Editors.Create ("", Untitled_N);
            Untitled_N := Untitled_N + 1;
         else
            E := Editors.Create (Full, 0);
            if E.Load_Failed then
               Dlg.Message_Box ("Error", "Cannot read " & Full);
            end if;
         end if;
         declare
            A : constant Rect := Desktop.Area;
            K : constant Natural := Desktop.Count mod 8;
         begin
            --  Unzoomed, a window is a little smaller and stepped down from
            --  the last; it opens zoomed, as Turbo C++'s did.
            E.Normal := (A.X + K, A.Y + K, Integer'Max (24, A.W - 8),
                         Integer'Max (6, A.H - 8));
            E.Bounds := A;
            E.Zoomed := True;
            if In_Desktop (Window_Access (Msg_Win)) then
               --  Leave the message window showing.
               E.Bounds.H := Integer'Max (6, Msg_Win.Bounds.Y - E.Bounds.Y);
               E.Zoomed := False;
               E.Normal := E.Bounds;
            end if;
         end;
         Desktop.Add (Window_Access (E));
      end if;
      if Activate then
         Desktop.Activate (Window_Access (E));
      end if;
      return E;
   end Open_File;

   procedure Open_File (Path : String) is
      Ignore : constant Editors.Editor_Access := Open_File (Path);
   begin
      null;
   end Open_File;

   procedure Free is new Ada.Unchecked_Deallocation
     (Editors.Editor'Class, Editors.Editor_Access);

   --  Saving

   function Save_As (E : Editors.Editor_Access) return Boolean is
      Name : Unbounded_String :=
        To_Unbounded_String
          (if E.Is_Untitled
           then Ada.Directories.Compose (Prj.Dir, Encode (E.Title))
           else E.Path);
      Ok   : Boolean;
   begin
      if not Dlg.Input_Box ("Save File As", "~N~ame", Name, 56) then
         return False;
      end if;
      declare
         Target : constant String :=
           Ada.Directories.Full_Name (To_String (Name));
      begin
         if Ada.Directories.Exists (Target) and then Target /= E.Path then
            if Dlg.Message_Box ("Confirm", Simple (Target)
                                & " already exists. Overwrite?",
                                Dlg.Yes_No) /= Dlg.Ans_Yes
            then
               return False;
            end if;
         end if;
         E.Save_As (Target, Ok);
         if not Ok then
            Dlg.Message_Box ("Error", "Cannot write " & Target);
         end if;
         return Ok;
      end;
   end Save_As;

   function Save (E : Editors.Editor_Access) return Boolean is
      Ok : Boolean;
   begin
      if E.Is_Untitled then
         return Save_As (E);
      end if;
      E.Save (Ok);
      if not Ok then
         Dlg.Message_Box ("Error", "Cannot write " & E.Path);
      end if;
      return Ok;
   end Save;

   procedure Save_All is
   begin
      for K in 1 .. Desktop.Count loop
         if Desktop.Nth (K).all in Editors.Editor'Class then
            declare
               E : constant Editors.Editor_Access :=
                 Editors.Editor_Access (Desktop.Nth (K));
               Ignore : Boolean;
            begin
               if E.Modified and then not E.Is_Untitled then
                  Ignore := Save (E);
               end if;
            end;
         end if;
      end loop;
   end Save_All;

   function Close_Window (W : Window_Access) return Boolean is
   --  False when the user cancelled.
   begin
      if W.all in Editors.Editor'Class then
         declare
            E : Editors.Editor_Access := Editors.Editor_Access (W);
         begin
            if E.Modified then
               Desktop.Activate (W);
               case Dlg.Message_Box
                 ("Information",
                  Simple (Encode (E.Title)) & " has been modified. Save?",
                  Dlg.Yes_No_Cancel)
               is
                  when Dlg.Ans_Yes =>
                     if not Save (E) then
                        return False;
                     end if;
                  when Dlg.Ans_No =>
                     null;
                  when others =>
                     return False;
               end case;
            end if;
            Desktop.Remove (W);
            Free (E);
         end;
      else
         Desktop.Remove (W);
      end if;
      return True;
   end Close_Window;

   function Close_All return Boolean is
   begin
      while Desktop.Count > 0 loop
         if not Close_Window (Desktop.Active) then
            return False;
         end if;
      end loop;
      return True;
   end Close_All;

   function Open_Files_List return String_List is
      L : String_List;
   begin
      for K in 1 .. Desktop.Count loop
         if Desktop.Nth (K).all in Editors.Editor'Class then
            declare
               E : constant Editors.Editor_Access :=
                 Editors.Editor_Access (Desktop.Nth (K));
            begin
               if not E.Is_Untitled then
                  L.Append (E.Path & ":" & Img (E.Cursor.Line) & ":"
                            & Img (E.Cursor.Col));
               end if;
            end;
         end if;
      end loop;
      return L;
   end Open_Files_List;

   --  The status line

   type Status_Context is (Ctx_None, Ctx_Editor, Ctx_Message, Ctx_Other);
   Shown_Context : Status_Context := Ctx_Other;
   Shown_Right   : Unbounded_String := To_Unbounded_String ("?");

   function "+" (S : String) return Desktop.Label_Access is (new String'(S));

   procedure Update_Status is
      W   : constant Window_Access := Desktop.Active;
      Ctx : constant Status_Context :=
        (if W = null then Ctx_None
         elsif W.all in Editors.Editor'Class then Ctx_Editor
         elsif W = Window_Access (Msg_Win) then Ctx_Message
         else Ctx_Other);
      Right : constant String :=
        (if Active_Editor /= null and then Active_Editor.Status_Hint /= ""
         then Active_Editor.Status_Hint & "  "
         else "")
        & (if Prj.Kind = Prj.No_Project then ""
           else Prj.Name
             & (if Prj.Kind = Prj.SDK_Example and then Prj.Example /= ""
                then " (" & (if Prj.Profile /= "" then Prj.Profile
                             else Prj.Example_Profile (Prj.Example)) & ")"
                else "")
             & " ");
   begin
      if Ctx /= Shown_Context then
         Shown_Context := Ctx;
         case Ctx is
            when Ctx_Editor =>
               Desktop.Set_Status
                 ([(+"~F1~ Help", Cmd_Help_Contents), (+"~F2~ Save", Cmd_Save),
                   (+"~F3~ Open", Cmd_Open), (+"~F9~ Make", Cmd_Make),
                   (+"~Ctrl-F9~ Run", Cmd_Run), (+"~Alt-F9~ Monitor", Cmd_Monitor),
                   (+"~F10~ Menu", Cmd_None)]);
            when Ctx_Message =>
               Desktop.Set_Status
                 ([(+"~F1~ Help", Cmd_Help_Contents),
                   (+"~Enter~ Edit source", Cmd_None),
                   (+"~Space~ Track", Cmd_None),
                   (+"~Alt-F8~ Next msg", Cmd_Next_Msg),
                   (+"~F10~ Menu", Cmd_None)]);
            when others =>
               Desktop.Set_Status
                 ([(+"~F1~ Help", Cmd_Help_Contents), (+"~F3~ Open", Cmd_Open),
                   (+"~F9~ Make", Cmd_Make), (+"~F10~ Menu", Cmd_None),
                   (+"~Alt-X~ Exit", Cmd_Quit)]);
         end case;
      end if;
      if Right /= To_String (Shown_Right) then
         Shown_Right := To_Unbounded_String (Right);
         Desktop.Set_Status_Right (Right);
      end if;
   end Update_Status;

   procedure Redraw is
   begin
      Update_Status;
      Desktop.Draw;
      Screen.Flush;
   end Redraw;

   procedure Background is
   begin
      Desktop.Draw_Background_Only;
   end Background;

   --  Which commands can run now (the grayed-out menu items)

   function Can_Run (A : Prj.Action) return Boolean is
     (Prj.Command_For (A) /= "");

   function Enabled (C : Command) return Boolean is
      E : constant Editors.Editor_Access := Active_Editor;
   begin
      case C is
         when Cmd_Save | Cmd_Save_As | Cmd_Find | Cmd_Replace | Cmd_Goto_Line
            | Cmd_Select_All | Cmd_Find_Spec_Body | Cmd_Grep
         =>
            return E /= null;
         when Cmd_Search_Again =>
            return E /= null and then Have_Search;
         when Cmd_Undo => return E /= null and then E.Can_Undo;
         when Cmd_Redo => return E /= null and then E.Can_Redo;
         when Cmd_Cut | Cmd_Copy | Cmd_Clear =>
            return E /= null and then E.Has_Selection;
         when Cmd_Paste => return E /= null and then not Clipboard.Is_Empty;
         when Cmd_Make | Cmd_Build_All => return Can_Run (Prj.Act_Build);
         when Cmd_Run => return Can_Run (Prj.Act_Run);
         when Cmd_Flash => return Can_Run (Prj.Act_Flash);
         when Cmd_Monitor => return Can_Run (Prj.Act_Monitor);
         when Cmd_Debug => return Can_Run (Prj.Act_Debug);
         when Cmd_Kill_OpenOCD => return Can_Run (Prj.Act_Kill_OpenOCD);
         when Cmd_Clean => return Can_Run (Prj.Act_Clean);
         when Cmd_Memory => return Can_Run (Prj.Act_Memory);
         when Cmd_Stack => return Can_Run (Prj.Act_Stack);
         when Cmd_Analyze => return Can_Run (Prj.Act_Analyze);
         when Cmd_Test => return Can_Run (Prj.Act_Test);
         when Cmd_Board_Config => return Can_Run (Prj.Act_Board);
         when Cmd_Alr_Update => return Can_Run (Prj.Act_Alr_Update) and then Prj.Manifest /= "";
         when Cmd_Alr_Show => return Can_Run (Prj.Act_Alr_Show) and then Prj.Manifest /= "";
         when Cmd_Alr_Deps => return Can_Run (Prj.Act_Alr_Deps) and then Prj.Manifest /= "";
         when Cmd_Edit_Manifest => return Prj.Manifest /= "";
         when Cmd_Edit_Gpr => return Prj.Gpr_File /= "";
         when Cmd_Zoom | Cmd_Close | Cmd_Size_Move | Cmd_Close_All =>
            return Desktop.Active /= null;
         when Cmd_Next_Window | Cmd_Prev_Window | Cmd_Tile | Cmd_Cascade =>
            return Desktop.Count > 0;
         when Cmd_Prev_Msg | Cmd_Next_Msg =>
            return Msg_Win.Line_Count > 0;
         when Cmd_Show_Clipboard => return not Clipboard.Is_Empty;
         when others =>
            return True;
      end case;
   end Enabled;

   --  Jobs: the "Compiling" box

   function Doing (Line : String) return String is
   --  What gprbuild says it is working on: "[Ada]  main.adb" -> "main.adb".
      use Ada.Strings.Fixed;
      L : constant String := Trim (Line, Ada.Strings.Both);
   begin
      if L'Length > 2 and then L (L'First) = '[' then
         declare
            Close : constant Natural := Index (L, "]");
         begin
            if Close > 0 and then Close < L'Last then
               return Trim (L (Close + 1 .. L'Last), Ada.Strings.Both);
            end if;
         end;
      end if;
      return "";
   end Doing;

   procedure Draw_Job_Box
     (Title, Command, Current : String;
      Lines, Warnings, Errors  : Natural;
      Footer                   : String)
   is
      use Turbo.Screen;
      W  : constant Integer := Integer'Min (Width - 4, 60);
      H  : constant := 13;
      X  : constant Integer := (Width - W) / 2 + 1;
      Y  : constant Integer := Integer'Max (2, (Height - H) / 2);
      Secs : constant Duration := Jobs.Elapsed;
      Tenths : constant Integer := Integer (Secs * 10.0);

      function Fit (S : String; N : Integer) return String is
        (if S'Length <= N or else N < 4 then S
         else "..." & S (S'Last - N + 4 .. S'Last));
   begin
      Fill (X, Y, W, H, ' ', Theme.Dialog_Text);
      Frame (X, Y, W, H, Theme.Dialog_Frame, Double => True);
      Put (X + (W - Title'Length - 2) / 2, Y, " " & Title & " ", Theme.Dialog_Frame);
      Shadow (X + W, Y + 1, 2, H);
      Shadow (X + 2, Y + H, W, 1);
      Put (X + 3, Y + 2, "Main file:", Theme.Dialog_Text);
      Put (X + 15, Y + 2, Fit (Prj.Name, W - 18), Theme.Label_Focused);
      Put (X + 3, Y + 3, "Command:", Theme.Dialog_Text);
      Put (X + 15, Y + 3, Fit (Command, W - 18), Theme.Dialog_Text);
      Put (X + 3, Y + 4, "Compiling:", Theme.Dialog_Text);
      Put (X + 15, Y + 4, Fit (Current, W - 18), Theme.Dialog_Text);
      Put (X + 22, Y + 6, "Total", Theme.Dialog_Text);
      Put (X + 3, Y + 7, "Lines output:", Theme.Dialog_Text);
      Put (X + 22, Y + 7, Img (Lines), Theme.Dialog_Text);
      Put (X + 3, Y + 8, "    Warnings:", Theme.Dialog_Text);
      Put (X + 22, Y + 8, Img (Warnings), Theme.Dialog_Text);
      Put (X + 3, Y + 9, "      Errors:", Theme.Dialog_Text);
      Put (X + 22, Y + 9, Img (Errors),
           (if Errors > 0 then Red / Light_Gray else Theme.Dialog_Text));
      Put (X + 34, Y + 7, "Elapsed:", Theme.Dialog_Text);
      Put (X + 43, Y + 7, Img (Tenths / 10) & "." & Img (Tenths mod 10) & " s",
           Theme.Dialog_Text);
      Fill (X + 2, Y + 11, W - 4, 1, ' ', Theme.Dialog_Text);
      Put (X + (W - Footer'Length) / 2, Y + 11, Footer, Theme.Label_Focused);
      Hide_Cursor;
   end Draw_Job_Box;

   procedure Run_Job
     (A         : Prj.Action;
      Title     : String;
      Success   : out Boolean;
      Wait_Key  : Boolean := True;
      Is_Build  : Boolean := True)
   is
      Cmd       : constant String :=
        Prj.Command_For (A, (if Active_Editor /= null then Active_Editor.Path else ""));
      Lines     : String_List;
      Finished  : Boolean := False;
      Cancelled : Boolean := False;
      Current   : Unbounded_String;
      Count     : Natural := 0;
      Ok        : Boolean;
      E         : Event;
   begin
      Success := False;
      if Cmd = "" then
         Dlg.Message_Box
           ("Information",
            "There is no " & Prj.Label (A) & " command for this project"
            & Character'Val (10)
            & (if Prj.Kind = Prj.SDK_Example and then Prj.Example = ""
               then "(choose an example: Project | Open project)."
               else "(see Options | Commands)."));
         return;
      end if;
      if Is_Build then
         Save_All;
      end if;

      Msg_Win.Clear;
      Msg_Win.Add (Messages.Header, Title & ": " & Cmd);
      Show_Message_Window (Activate => False);

      Jobs.Start (Cmd, Prj.Working_Dir (A), Ok);
      if not Ok then
         Dlg.Message_Box ("Error", "Cannot start: " & Cmd);
         return;
      end if;

      loop
         Jobs.Poll (Lines, Finished);
         for L of Lines loop
            Msg_Win.Add_Line (L);
            Count := Count + 1;
            if Doing (L) /= "" then
               Current := To_Unbounded_String (Doing (L));
            elsif Current = Null_Unbounded_String
              and then Ada.Strings.Fixed.Trim (L, Ada.Strings.Both) /= ""
            then
               Current := To_Unbounded_String (Ada.Strings.Fixed.Trim (L, Ada.Strings.Both));
            end if;
         end loop;
         Msg_Win.Follow_Tail;
         Update_Status;
         Desktop.Draw;
         Draw_Job_Box (Title, Cmd, To_String (Current), Count,
                       Msg_Win.Warnings, Msg_Win.Errors,
                       (if Cancelled then "Cancelling..."
                        else "Working...   Esc cancels"));
         Screen.Flush;
         exit when Finished;
         E := Get (100);
         if E.Kind = Resize then
            Screen.Init;
         elsif Is_Key (E, Escape) or else Is_Ctrl (E, 'c') or else Is_Ctrl (E, 'b')
         then
            Jobs.Cancel;
            Cancelled := True;
         end if;
      end loop;

      Success := Jobs.Succeeded and then not Cancelled;
      Msg_Win.Add (Messages.Header,
                   (if Cancelled then "Cancelled."
                    elsif Success then "Success."
                    else "Failed.")
                   & "  " & Img (Msg_Win.Errors) & " error(s), "
                   & Img (Msg_Win.Warnings) & " warning(s).");
      Msg_Win.Follow_Tail;

      if Wait_Key or else not Success then
         Update_Status;
         Desktop.Draw;
         Draw_Job_Box (Title, Cmd, To_String (Current), Count,
                       Msg_Win.Warnings, Msg_Win.Errors,
                       (if Cancelled then "Cancelled   :   Press any key"
                        elsif Success and then Msg_Win.Warnings = 0
                        then "Success   :   Press any key"
                        elsif Success then "Warnings   :   Press any key"
                        else "Errors   :   Press any key"));
         Screen.Flush;
         loop
            E := Get (-1);
            exit when E.Kind = Key
              or else (E.Kind = Mouse and then E.Action = Press);
         end loop;
      end if;

      if not Success and then Msg_Win.First_Error then
         Show_Message_Window (Activate => True);
      elsif not Success or else not Is_Build then
         Show_Message_Window (Activate => True);
      end if;
   end Run_Job;

   procedure Run_Interactive (A : Prj.Action) is
      Cmd : constant String := Prj.Command_For (A);
      Ok  : Boolean;
   begin
      if Cmd = "" then
         Dlg.Message_Box ("Information",
                          "There is no " & Prj.Label (A) & " command for this project.");
         return;
      end if;
      Jobs.Run_Foreground (Cmd, Prj.Working_Dir (A), Ok);
      Screen.Init;
      Screen.Invalidate;
   end Run_Interactive;

   --  Jump from the message window

   procedure On_Jump (File : String; Line, Col : Positive; Focus : Boolean) is
      Path : constant String := Prj.Locate_Source (File);
      E    : Editors.Editor_Access;
   begin
      if Path = "" then
         Desktop.Set_Status_Message ("Cannot find " & File & " in the project");
         Redraw;
         delay 1.0;
         Desktop.Set_Status_Message ("");
         return;
      end if;
      E := Open_File (Path, Activate => True);
      if In_Desktop (Window_Access (Msg_Win))
        and then E.Bounds.Y + E.Bounds.H > Msg_Win.Bounds.Y
        and then Msg_Win.Bounds.Y - E.Bounds.Y >= 6
      then
         --  Keep the message window in sight while working through errors.
         if E.Zoomed then
            E.Zoomed := False;
         end if;
         E.Bounds.H := Msg_Win.Bounds.Y - E.Bounds.Y;
      end if;
      E.Go_To (Line, Col, Mark_Error => True);
      if not Focus then
         Desktop.Activate (Window_Access (Msg_Win));
      end if;
   end On_Jump;

   --  Search

   procedure Do_Search (First : Boolean) is
      E     : constant Editors.Editor_Access := Active_Editor;
      Pat   : constant Wide_Wide_String :=
        Ada.Strings.Wide_Wide_Unbounded.To_Wide_Wide_String (Find_Opt.Text);
   begin
      if E = null then
         return;
      end if;
      if not E.Find_Next (Pat, Find_Opt.Match_Case, Find_Opt.Whole_Word,
                          Find_Opt.Backward, From_Top => First and then Find_Opt.From_Top)
      then
         Dlg.Message_Box ("Information", "Search string not found.");
      end if;
   end Do_Search;

   procedure Do_Replace (First : Boolean) is
      E      : constant Editors.Editor_Access := Active_Editor;
      Pat    : constant Wide_Wide_String :=
        Ada.Strings.Wide_Wide_Unbounded.To_Wide_Wide_String (Find_Opt.Text);
      By     : constant Wide_Wide_String :=
        Ada.Strings.Wide_Wide_Unbounded.To_Wide_Wide_String (Find_Opt.New_Text);
      Top    : Boolean := First and then Find_Opt.From_Top;
      Done   : Natural := 0;
      Grouped : constant Boolean := Find_Opt.Change_All and then not Find_Opt.Prompt;
   begin
      if E = null then
         return;
      end if;
      if Grouped then
         E.Begin_Edit_Group;
      end if;
      loop
         exit when not E.Find_Next (Pat, Find_Opt.Match_Case, Find_Opt.Whole_Word,
                                    Find_Opt.Backward, From_Top => Top);
         Top := False;
         declare
            Start : constant Buffers.Position :=
              (E.Cursor.Line, E.Cursor.Col - Pat'Length);
            Answer : Dlg.Answer := Dlg.Ans_Yes;
         begin
            if Find_Opt.Prompt then
               Redraw;
               Answer := Dlg.Message_Box ("Information", "Replace this occurrence?",
                                          Dlg.Yes_No_Cancel);
            end if;
            exit when Answer = Dlg.Ans_Cancel;
            if Answer = Dlg.Ans_Yes then
               E.Replace_Selection (By);
               Done := Done + 1;
               if Find_Opt.Backward then
                  E.Go_To (Start.Line, Start.Col);
               end if;
            end if;
         end;
         exit when not Find_Opt.Change_All or else Done > 100_000;
      end loop;
      if Grouped then
         E.End_Edit_Group;
      end if;
      if Done = 0 then
         Dlg.Message_Box ("Information", "Search string not found.");
      elsif Find_Opt.Change_All then
         Desktop.Set_Status_Message (Img (Done) & " occurrence(s) replaced.");
         Redraw;
         delay 0.8;
         Desktop.Set_Status_Message ("");
      end if;
   end Do_Replace;

   procedure Grep (Word : Wide_Wide_String) is
   --  Every whole-word occurrence of Word in the project's Ada sources,
   --  into the message window (Turbo C++ had GREP on its system menu).
      use Ada.Directories;
      Limit : constant := 2000;
      Found : Natural := 0;

      procedure Scan_File (Path : String) is
         B    : Buffers.Buffer;
         Ok   : Boolean;
         P    : Buffers.Position;
         From : Buffers.Position := (1, 1);
      begin
         B.Load (Path, Ok);
         while Ok and then Found < Limit
           and then B.Find (Word, From, True, False, True, P)
         loop
            Found := Found + 1;
            Msg_Win.Add_Location
              (Path, P.Line, P.Col,
               Ada.Strings.Wide_Wide_Fixed.Trim (B.Line (P.Line), Ada.Strings.Left));
            exit when P.Line = B.Line_Count;
            From := (P.Line + 1, 1);
         end loop;
      end Scan_File;

      procedure Scan (Dir : String; Depth : Natural) is
         S   : Search_Type;
         Ent : Directory_Entry_Type;
      begin
         if Depth > 10 or else Found >= Limit then
            return;
         end if;
         Start_Search (S, Dir, "");
         while More_Entries (S) loop
            Get_Next_Entry (S, Ent);
            declare
               N : constant String := Simple_Name (Ent);
            begin
               if N (N'First) = '.' then
                  null;
               elsif Kind (Ent) = Directory then
                  if N /= "obj" and then N /= "alire" and then N /= "build"
                    and then N /= "bb-runtimes"
                  then
                     Scan (Full_Name (Ent), Depth + 1);
                  end if;
               elsif Syntax.Language_Of (N) = Syntax.Ada_Lang then
                  Scan_File (Full_Name (Ent));
               end if;
            end;
         end loop;
         End_Search (S);
      exception
         when others => null;
      end Scan;

   begin
      Msg_Win.Clear;
      Msg_Win.Add (Messages.Header, "Grep " & Encode (Word) & " in " & Prj.Dir);
      Scan (Prj.Dir, 0);
      if Prj.Root /= Prj.Dir then
         Scan (Compose (Prj.Root, "libs"), 0);
      end if;
      Msg_Win.Add (Messages.Header,
                   Img (Found) & " match(es)" & (if Found >= Limit then " (stopped)" else "")
                   & ".");
      Show_Message_Window (Activate => True);
   end Grep;

   --  Dialog-driven commands

   procedure Open_Dialog is
      Result : Unbounded_String;
      Start  : constant String :=
        (if Active_Editor /= null and then not Active_Editor.Is_Untitled
         then Ada.Directories.Containing_Directory (Active_Editor.Path)
         else Ada.Directories.Current_Directory);
   begin
      if Dlg.Open_File_Dialog ("Open a File", Start, Result) then
         Open_File (To_String (Result));
      end if;
   end Open_Dialog;

   procedure Goto_Line is
      E : constant Editors.Editor_Access := Active_Editor;
      V : Unbounded_String;
   begin
      if E = null then
         return;
      end if;
      if Dlg.Input_Box ("Go to Line Number", "~E~nter new line number", V, 20) then
         begin
            E.Go_To (Positive'Value (To_String (V)), 1);
         exception
            when others => null;
         end;
      end if;
   end Goto_Line;

   procedure Spec_Body is
      E : constant Editors.Editor_Access := Active_Editor;
   begin
      if E = null or else E.Is_Untitled then
         return;
      end if;
      declare
         use Ada.Characters.Handling;
         P    : constant String := E.Path;
         Ext  : constant String := To_Lower (Ada.Directories.Extension (P));
         Base : constant String := P (P'First .. P'Last - Ext'Length);
         Other_Ext : constant String :=
           (if Ext = "adb" then "ads" elsif Ext = "ads" then "adb" else "");
      begin
         if Other_Ext = "" then
            Dlg.Message_Box ("Information", "Not an Ada spec or body.");
            return;
         end if;
         if Ada.Directories.Exists (Base & Other_Ext) then
            Open_File (Base & Other_Ext);
         else
            declare
               Found : constant String :=
                 Prj.Locate_Source (Ada.Directories.Base_Name (P) & "." & Other_Ext);
            begin
               if Found /= "" then
                  Open_File (Found);
               elsif Dlg.Message_Box ("Information",
                                      Simple (Base & Other_Ext)
                                      & " does not exist. Create it?",
                                      Dlg.Yes_No) = Dlg.Ans_Yes
               then
                  Open_File (Base & Other_Ext);
               end if;
            end;
         end if;
      end;
   end Spec_Body;

   procedure Change_Dir is
      V : Unbounded_String := To_Unbounded_String (Ada.Directories.Current_Directory);
   begin
      if Dlg.Input_Box ("Change Directory", "~D~irectory name", V, 56) then
         begin
            Ada.Directories.Set_Directory (To_String (V));
            Prj.Detect (Ada.Directories.Current_Directory);
            Shown_Context := Ctx_Other;
         exception
            when others =>
               Dlg.Message_Box ("Error", "No such directory: " & To_String (V));
         end;
      end if;
   end Change_Dir;

   procedure Open_Project is
   begin
      if Prj.Kind = Prj.SDK_Example then
         declare
            Names : constant String_List := Prj.Examples;
            Shown : String_List;
            Index : Positive := 1;
         begin
            for K in 1 .. Natural (Names.Length) loop
               declare
                  N : constant String := Names (K);
               begin
                  Shown.Append (N & (1 .. Integer'Max (1, 30 - N'Length) => ' ')
                                & Prj.Example_Profile (N));
                  if N = Prj.Example then
                     Index := K;
                  end if;
               end;
            end loop;
            if Dlg.Choose ("Open Project", "~E~xamples", Shown, Index, 46, "~O~pen")
            then
               Prj.Set_Example (Names (Index));
               if Prj.Main_Source /= "" then
                  Open_File (Prj.Main_Source);
               end if;
            end if;
         end;
      else
         declare
            V : Unbounded_String := To_Unbounded_String (Prj.Dir);
         begin
            if Dlg.Input_Box ("Open Project", "Project ~d~irectory", V, 56) then
               if Ada.Directories.Exists (To_String (V)) then
                  Prj.Open_Directory (To_String (V));
                  Ada.Directories.Set_Directory (Prj.Dir);
               else
                  Dlg.Message_Box ("Error", "No such directory: " & To_String (V));
               end if;
            end if;
         end;
      end if;
      Shown_Context := Ctx_Other;
   end Open_Project;

   procedure New_Project is
      D      : Dlg.Dialog;
      Name_Id, Kind_Id : Positive;
      In_SDK : constant Boolean := Prj.Kind = Prj.SDK_Example;
   begin
      D.Init ("New Project", 64, 13);
      Name_Id := D.Add_Input (3, 3, 58,
                              (if In_SDK then "my_app"
                               else Ada.Directories.Compose
                                      (Ada.Directories.Current_Directory, "my_app")));
      D.Add_Label (2, 2, (if In_SDK then "~N~ame (under examples/)" else "~D~irectory"),
                   Name_Id);
      Kind_Id := D.Add_Radio
        (3, 5, 58,
         (if In_SDK then "SDK example (./x new)|Alire binary crate (alr init --bin)"
          else "ESP32-S3 bare-metal (esp32-ada init)|Alire binary crate (alr init --bin)"),
         1);
      D.Add_Button (16, 9, 12, "~O~K", 1, Default => True);
      D.Add_Button (34, 9, 12, "Cancel", Dlg.Cancel_Code);
      if D.Run /= 1 then
         return;
      end if;
      declare
         Given  : constant String := Ada.Strings.Fixed.Trim (D.Value (Name_Id), Ada.Strings.Both);
         Target : constant String :=
           (if In_SDK and then D.Radio_Value (Kind_Id) = 1
            then Ada.Directories.Compose (Ada.Directories.Compose (Prj.Root, "examples"), Given)
            elsif In_SDK then Ada.Directories.Compose (Ada.Directories.Compose (Prj.Root, "examples"), Given)
            else Ada.Directories.Full_Name (Given));
         Parent : constant String := Ada.Directories.Containing_Directory (Target);
         Leaf   : constant String := Ada.Directories.Simple_Name (Target);
         Cmd    : constant String :=
           (if D.Radio_Value (Kind_Id) = 2 then "alr -n init --bin " & Leaf
            elsif In_SDK then "./x new " & Given
            else Prj.Esp32_Ada & " init " & Leaf);
         Where  : constant String :=
           (if In_SDK and then D.Radio_Value (Kind_Id) = 1 then Prj.Root else Parent);
         Ok     : Boolean;
      begin
         if Given = "" then
            return;
         end if;
         Jobs.Run_Foreground (Cmd, Where, Ok);
         Screen.Init;
         Screen.Invalidate;
         if Ok then
            Prj.Detect (Target);
            Ada.Directories.Set_Directory (Prj.Dir);
            Shown_Context := Ctx_Other;
            if Prj.Main_Source /= "" then
               Open_File (Prj.Main_Source);
            end if;
         end if;
      end;
   exception
      when others =>
         Dlg.Message_Box ("Error", "Cannot create that project.");
   end New_Project;

   procedure Project_Info is
      LF : constant Character := Character'Val (10);
      T  : Unbounded_String;
   begin
      Append (T, "# Project" & LF);
      Append (T, "  Kind:      {" & Prj.Kind_Image & "}" & LF);
      Append (T, "  Name:      " & Prj.Name & LF);
      Append (T, "  Directory: " & Prj.Dir & LF);
      if Prj.Root /= Prj.Dir then
         Append (T, "  SDK root:  " & Prj.Root & LF);
      end if;
      if Prj.Kind = Prj.SDK_Example and then Prj.Example /= "" then
         Append (T, "  Profile:   " & (if Prj.Profile = "" then Prj.Example_Profile (Prj.Example)
                                       & " (the example's own)" else Prj.Profile) & LF);
      end if;
      Append (T, "  Port:      " & (if Prj.Port = "" then "(the tool's default)" else Prj.Port) & LF);
      Append (T, "  Manifest:  " & (if Prj.Manifest = "" then "-" else Prj.Manifest) & LF);
      Append (T, "  GPR file:  " & (if Prj.Gpr_File = "" then "-" else Prj.Gpr_File) & LF);
      Append (T, "  Options:   " & Prj.Options_File & LF);
      Append (T, LF & "# Commands" & LF);
      for A in Prj.Action loop
         declare
            C : constant String := Prj.Command_For (A);
            L : constant String := Prj.Label (A);
         begin
            Append (T, "  {" & L & "}" & (1 .. 14 - L'Length => ' ')
                    & (if C = "" then "-" else C) & LF);
         end;
      end loop;
      Show_Help ("Project Information", To_String (T));
   end Project_Info;

   procedure Target_Options is
      D : Dlg.Dialog;
      Port_Id, Prof_Id : Positive;
      Profiles : constant array (1 .. 4) of Desktop.Label_Access :=
        [+"", +"light-tasking", +"embedded", +"full"];
      Cur : Positive := 1;
   begin
      for K in Profiles'Range loop
         if Profiles (K).all = Prj.Profile then
            Cur := K;
         end if;
      end loop;
      D.Init ("Target", 56, 14);
      Port_Id := D.Add_Input (3, 3, 30, Prj.Port);
      D.Add_Label (2, 2, "Serial ~p~ort (empty: $ESPPORT or /dev/ttyACM0)", Port_Id);
      Prof_Id := D.Add_Radio (3, 6, 40,
        "~P~roject default|~L~ight-tasking (Jorvik)|~E~mbedded|~F~ull", Cur);
      D.Add_Label (2, 5, "Runtime ~r~rofile", Prof_Id);
      D.Add_Button (12, 11, 12, "~O~K", 1, Default => True);
      D.Add_Button (30, 11, 12, "Cancel", Dlg.Cancel_Code);
      if D.Run = 1 then
         Prj.Set_Port (D.Value (Port_Id));
         Prj.Set_Profile (Profiles (D.Radio_Value (Prof_Id)).all);
         Shown_Right := To_Unbounded_String ("?");
      end if;
   end Target_Options;

   procedure Command_Options is
      D   : Dlg.Dialog;
      Ids : array (Prj.Action) of Positive;
      Row : Natural := 2;
      W   : constant Positive := Positive'Min (Screen.Width - 4, 76);
      Code : Integer;
   begin
      D.Init ("Commands", W, Prj.Action'Range_Length + 7);
      for A in Prj.Action loop
         Ids (A) := D.Add_Input (16, Row, W - 19, Prj.Template (A));
         D.Add_Label (2, Row, Prj.Label (A), Ids (A));
         Row := Row + 1;
      end loop;
      D.Add_Text (2, Row + 1, "{example} {port_opt} {profile_opt} {port} {profile} {dir} {root} {file}");
      D.Add_Button (W / 2 - 22, Row + 3, 12, "~O~K", 1, Default => True);
      D.Add_Button (W / 2 - 6, Row + 3, 12, "~D~efaults", 2);
      D.Add_Button (W / 2 + 10, Row + 3, 12, "Cancel", Dlg.Cancel_Code);
      loop
         Code := D.Run;
         exit when Code /= 2;
         for A in Prj.Action loop
            D.Set_Value (Ids (A), Prj.Default_Template (A));
         end loop;
      end loop;
      if Code = 1 then
         for A in Prj.Action loop
            Prj.Set_Template (A, D.Value (Ids (A)));
         end loop;
      end if;
   end Command_Options;

   procedure Apply_Editor_Options is
      function Num (Key : String; Default : Positive) return Positive is
      begin
         return Positive'Value (Prj.Get_Option (Key, Img (Default)));
      exception
         when others => return Default;
      end Num;
      function Flag (Key : String; Default : Boolean) return Boolean is
        (Prj.Get_Option (Key, (if Default then "1" else "0")) = "1");
   begin
      Settings.Tab_Size := Num ("editor.tab_size", Settings.Tab_Size);
      Settings.Indent_Size := Num ("editor.indent", Settings.Indent_Size);
      Settings.Auto_Indent := Flag ("editor.auto_indent", Settings.Auto_Indent);
      Settings.Backup_Files := Flag ("editor.backup", Settings.Backup_Files);
      Settings.Trim_Trailing := Flag ("editor.trim_trailing", Settings.Trim_Trailing);
      Settings.Show_Shadows := Flag ("screen.shadows", Settings.Show_Shadows);
      Screen.Set_True_Color (Flag ("screen.true_color", Screen.True_Color));
   end Apply_Editor_Options;

   procedure Store_Editor_Options is
      function B (V : Boolean) return String is (if V then "1" else "0");
   begin
      Prj.Set_Option ("editor.tab_size", Img (Settings.Tab_Size));
      Prj.Set_Option ("editor.indent", Img (Settings.Indent_Size));
      Prj.Set_Option ("editor.auto_indent", B (Settings.Auto_Indent));
      Prj.Set_Option ("editor.backup", B (Settings.Backup_Files));
      Prj.Set_Option ("editor.trim_trailing", B (Settings.Trim_Trailing));
      Prj.Set_Option ("screen.shadows", B (Settings.Show_Shadows));
   end Store_Editor_Options;

   procedure Editor_Options is
      D : Dlg.Dialog;
      Tab_Id, Ind_Id, Auto_Id, Bak_Id, Trim_Id, Color_Id, Shadow_Id : Positive;
   begin
      D.Init ("Editor Options", 52, 17);
      Tab_Id := D.Add_Input (22, 2, 6, Img (Settings.Tab_Size));
      D.Add_Label (2, 2, "~T~ab size", Tab_Id);
      Ind_Id := D.Add_Input (22, 3, 6, Img (Settings.Indent_Size));
      D.Add_Label (2, 3, "~I~ndent width", Ind_Id);
      Auto_Id := D.Add_Check (3, 5, 44, "~A~uto indent", Settings.Auto_Indent);
      Trim_Id := D.Add_Check (3, 6, 44, "T~r~im trailing blanks on save",
                              Settings.Trim_Trailing);
      Bak_Id := D.Add_Check (3, 7, 44, "Create ~b~ackup files (.bak)",
                             Settings.Backup_Files);
      Color_Id := D.Add_Check (3, 9, 44, "~E~xact CGA colours (24-bit)",
                               Screen.True_Color);
      Shadow_Id := D.Add_Check (3, 10, 44, "Window ~s~hadows", Settings.Show_Shadows);
      D.Add_Button (10, 13, 12, "~O~K", 1, Default => True);
      D.Add_Button (28, 13, 12, "Cancel", Dlg.Cancel_Code);
      if D.Run = 1 then
         begin
            Settings.Tab_Size := Positive'Max (1, Positive'Min (16, Positive'Value (D.Value (Tab_Id))));
         exception
            when others => null;
         end;
         begin
            Settings.Indent_Size := Positive'Max (1, Positive'Min (16, Positive'Value (D.Value (Ind_Id))));
         exception
            when others => null;
         end;
         Settings.Auto_Indent := D.Checked (Auto_Id);
         Settings.Trim_Trailing := D.Checked (Trim_Id);
         Settings.Backup_Files := D.Checked (Bak_Id);
         Settings.Show_Shadows := D.Checked (Shadow_Id);
         if D.Checked (Color_Id) /= Screen.True_Color then
            --  Only an explicit choice is remembered; otherwise the
            --  terminal's COLORTERM decides each time.
            Prj.Set_Option ("screen.true_color", (if D.Checked (Color_Id) then "1" else "0"));
         end if;
         Screen.Set_True_Color (D.Checked (Color_Id));
         Store_Editor_Options;
      end if;
   end Editor_Options;

   procedure Window_List is
      Items : String_List;
      Wins  : array (1 .. Desktop.Count) of Window_Access;
      Index : Positive := 1;
      N     : Natural := 0;
   begin
      for K in reverse 1 .. Desktop.Count loop
         N := N + 1;
         Wins (N) := Desktop.Nth (K);
         Items.Append ((if Wins (N).Number in 1 .. 9 then Img (Wins (N).Number) else " ")
                       & "  " & Encode (Wins (N).Title));
      end loop;
      if N > 0 and then Dlg.Choose ("Window List", "~W~indows", Items, Index, 60, "~G~o to")
      then
         Desktop.Activate (Wins (Index));
      end if;
   end Window_List;

   --  Moving and sizing windows

   procedure Drag_Window (W : Window_Access; Sizing : Boolean; X0, Y0 : Integer) is
      B0 : constant Rect := W.Bounds;
      E  : Event;
   begin
      loop
         E := Get (-1);
         exit when E.Kind = Key;
         if E.Kind = Mouse then
            if E.Action = Drag then
               W.Zoomed := False;
               if Sizing then
                  W.Move_To ((B0.X, B0.Y, B0.W + E.X - X0, B0.H + E.Y - Y0));
               else
                  W.Move_To ((B0.X + E.X - X0, B0.Y + E.Y - Y0, B0.W, B0.H));
               end if;
               Redraw;
            elsif E.Action = Release then
               exit;
            end if;
         elsif E.Kind = Resize then
            Screen.Init;
            Redraw;
         end if;
      end loop;
   end Drag_Window;

   procedure Size_Move is
      W : constant Window_Access := Desktop.Active;
      E : Event;
   begin
      if W = null then
         return;
      end if;
      Desktop.Set_Status_Message ("Arrows: move   Shift+arrows: size   Enter: done");
      loop
         Redraw;
         E := Get (-1);
         exit when E.Kind = Key and then E.Code in Enter | Escape;
         if E.Kind = Key then
            declare
               B  : constant Rect := W.Bounds;
               DX : constant Integer := (case E.Code is when Left => -1, when Right => 1, when others => 0);
               DY : constant Integer := (case E.Code is when Up => -1, when Down => 1, when others => 0);
            begin
               W.Zoomed := False;
               if E.Shift then
                  W.Move_To ((B.X, B.Y, B.W + DX, B.H + DY));
               else
                  W.Move_To ((B.X + DX, B.Y + DY, B.W, B.H));
               end if;
            end;
         elsif E.Kind = Resize then
            Screen.Init;
         end if;
      end loop;
      Desktop.Set_Status_Message ("");
   end Size_Move;

   procedure Fit_Windows is
   --  After a terminal resize: zoomed windows fill the new desktop, the
   --  rest are kept on it.
      A : constant Rect := Desktop.Area;
   begin
      for K in 1 .. Desktop.Count loop
         declare
            W : constant Window_Access := Desktop.Nth (K);
         begin
            if W.Zoomed then
               W.Bounds := A;
            else
               W.Move_To ((W.Bounds.X, W.Bounds.Y,
                           Integer'Min (W.Bounds.W, A.W),
                           Integer'Min (W.Bounds.H, A.H)));
            end if;
         end;
      end loop;
   end Fit_Windows;

   --  Exit

   procedure Save_Desktop is
   begin
      if Prj.Kind /= Prj.No_Project then
         Store_Editor_Options;
         Prj.Save_Options (Open_Files_List);
      end if;
   end Save_Desktop;

   procedure Do_Quit is
      Files : constant String_List := Open_Files_List;
   begin
      for K in reverse 1 .. Desktop.Count loop
         if Desktop.Nth (K).all in Editors.Editor'Class then
            declare
               E : constant Editors.Editor_Access := Editors.Editor_Access (Desktop.Nth (K));
            begin
               if E.Modified then
                  Desktop.Activate (Window_Access (E));
                  Redraw;
                  case Dlg.Message_Box
                    ("Information",
                     Simple (Encode (E.Title)) & " has been modified. Save?",
                     Dlg.Yes_No_Cancel)
                  is
                     when Dlg.Ans_Yes =>
                        if not Save (E) then
                           return;
                        end if;
                     when Dlg.Ans_No => null;
                     when others => return;
                  end case;
               end if;
            end;
         end if;
      end loop;
      if Prj.Kind /= Prj.No_Project then
         Store_Editor_Options;
         Prj.Save_Options (Files);
      end if;
      Quit := True;
   end Do_Quit;

   --  The dispatcher

   procedure Execute (C : Command) is
      E  : constant Editors.Editor_Access := Active_Editor;
      Ok : Boolean;
   begin
      if C /= Cmd_None and then not Enabled (C) then
         return;
      end if;
      case C is
         when Cmd_None => null;

         when Cmd_About =>
            Dlg.Message_Box ("About", Help.About);
         when Cmd_Repaint =>
            Screen.Init;
            Screen.Invalidate;
         when Cmd_Alr_Update => Run_Job (Prj.Act_Alr_Update, "alr update", Ok, False, False);
         when Cmd_Alr_Show => Run_Job (Prj.Act_Alr_Show, "alr show", Ok, False, False);
         when Cmd_Alr_Deps => Run_Job (Prj.Act_Alr_Deps, "alr with", Ok, False, False);

         when Cmd_New => Open_File ("");
         when Cmd_Open => Open_Dialog;
         when Cmd_Save => Ok := Save (E);
         when Cmd_Save_As => Ok := Save_As (E);
         when Cmd_Save_All => Save_All;
         when Cmd_Change_Dir => Change_Dir;
         when Cmd_Shell =>
            declare
               Sh : constant String :=
                 (if Term.Is_Windows then "cmd.exe"
                  elsif Ada.Environment_Variables.Exists ("SHELL")
                  then Ada.Environment_Variables.Value ("SHELL")
                  else "/bin/sh");
            begin
               Jobs.Run_Foreground
                 ((if Term.Is_Windows then "" else "echo 'Type EXIT to return to Turbo Ada...'; ")
                  & Sh, Ada.Directories.Current_Directory, Ok);
               Screen.Init;
               Screen.Invalidate;
            end;
         when Cmd_Quit => Do_Quit;

         when Cmd_Undo => E.Undo;
         when Cmd_Redo => E.Redo;
         when Cmd_Cut => E.Cut;
         when Cmd_Copy => E.Copy;
         when Cmd_Paste => E.Paste;
         when Cmd_Clear => E.Clear;
         when Cmd_Select_All => E.Select_All;
         when Cmd_Show_Clipboard =>
            Show_Help ("Clipboard", Encode (Clipboard.Get));

         when Cmd_Find =>
            if E.Has_Selection or else E.Word_At_Cursor /= "" then
               Find_Opt.Text := Ada.Strings.Wide_Wide_Unbounded.To_Unbounded_Wide_Wide_String
                 (E.Word_At_Cursor);
            end if;
            if Dlg.Find_Dialog (Find_Opt, Replace => False) then
               Have_Search := True;
               Do_Search (First => True);
            end if;
         when Cmd_Replace =>
            if Dlg.Find_Dialog (Find_Opt, Replace => True) then
               Have_Search := True;
               Do_Replace (First => True);
            end if;
         when Cmd_Search_Again =>
            if Find_Opt.Replacing then
               Do_Replace (First => False);
            else
               Do_Search (First => False);
            end if;
         when Cmd_Goto_Line => Goto_Line;
         when Cmd_Prev_Msg =>
            if not Msg_Win.Step (Forward => False) then
               Desktop.Set_Status_Message ("No previous message.");
               Redraw;
               delay 0.6;
               Desktop.Set_Status_Message ("");
            end if;
         when Cmd_Next_Msg =>
            if not Msg_Win.Step (Forward => True) then
               Desktop.Set_Status_Message ("No more messages.");
               Redraw;
               delay 0.6;
               Desktop.Set_Status_Message ("");
            end if;
         when Cmd_Find_Spec_Body => Spec_Body;
         when Cmd_Grep =>
            declare
               Word : constant Wide_Wide_String := E.Word_At_Cursor;
               V    : Unbounded_String := To_Unbounded_String (Encode (Word));
            begin
               if Dlg.Input_Box ("Grep", "~W~ord to find in the project", V, 40)
                 and then Length (V) > 0
               then
                  Dlg.Show_Busy ("Grep", "Searching " & Prj.Dir & "...");
                  Grep (Decode (To_String (V)));
               end if;
            end;

         when Cmd_Run =>
            --  Make first; the box only waits for a key if it failed.
            Run_Job (Prj.Act_Build, "Make", Ok, Wait_Key => False);
            if Ok then
               Run_Interactive (Prj.Act_Run);
            end if;
         when Cmd_Flash => Run_Job (Prj.Act_Flash, "Flash", Ok, True, True);
         when Cmd_Monitor => Run_Interactive (Prj.Act_Monitor);
         when Cmd_Debug => Run_Interactive (Prj.Act_Debug);
         when Cmd_Kill_OpenOCD => Run_Job (Prj.Act_Kill_OpenOCD, "Kill OpenOCD", Ok, False, False);
         when Cmd_User_Screen =>
            Term.Show_User_Screen;
            Screen.Invalidate;

         when Cmd_Make => Run_Job (Prj.Act_Build, "Make", Ok);
         when Cmd_Build_All =>
            Run_Job (Prj.Act_Clean, "Clean", Ok, False, True);
            Run_Job (Prj.Act_Build, "Build all", Ok);
         when Cmd_Clean => Run_Job (Prj.Act_Clean, "Clean", Ok, False, False);
         when Cmd_Memory => Run_Job (Prj.Act_Memory, "Memory usage", Ok, False, False);
         when Cmd_Stack => Run_Job (Prj.Act_Stack, "Stack usage", Ok, False, False);
         when Cmd_Analyze => Run_Job (Prj.Act_Analyze, "Analyze", Ok, True, False);
         when Cmd_Test => Run_Job (Prj.Act_Test, "Test", Ok, True, False);

         when Cmd_Open_Project => Open_Project;
         when Cmd_New_Project => New_Project;
         when Cmd_Project_Info => Project_Info;
         when Cmd_Edit_Manifest => Open_File (Prj.Manifest);
         when Cmd_Edit_Gpr => Open_File (Prj.Gpr_File);
         when Cmd_Board_Config => Run_Job (Prj.Act_Board, "Board", Ok, False, False);

         when Cmd_Opt_Target => Target_Options;
         when Cmd_Opt_Commands => Command_Options;
         when Cmd_Opt_Editor => Editor_Options;
         when Cmd_Opt_Save =>
            if Prj.Kind = Prj.No_Project then
               Dlg.Message_Box ("Information", "No project here to save options for.");
            else
               Save_Desktop;
               Desktop.Set_Status_Message ("Options saved to " & Prj.Options_File);
               Redraw;
               delay 0.8;
               Desktop.Set_Status_Message ("");
            end if;

         when Cmd_Zoom => Desktop.Active.Toggle_Zoom (Desktop.Area);
         when Cmd_Tile => Desktop.Tile;
         when Cmd_Cascade => Desktop.Cascade;
         when Cmd_Next_Window => Desktop.Next_Window;
         when Cmd_Prev_Window => Desktop.Prev_Window;
         when Cmd_Close =>
            declare
               Ignore : constant Boolean := Close_Window (Desktop.Active);
            begin
               null;
            end;
         when Cmd_Close_All =>
            declare
               Ignore : constant Boolean := Close_All;
            begin
               null;
            end;
         when Cmd_Size_Move => Size_Move;
         when Cmd_Message_Window => Show_Message_Window (Activate => True);
         when Cmd_Window_List => Window_List;

         when Cmd_Help_Contents => Show_Help ("Help", Help.Contents);
         when Cmd_Help_Keys => Show_Help ("Keyboard", Help.Keys);
         when Cmd_Help_Project => Show_Help ("Project Commands", Help.Project_Commands);
      end case;
   end Execute;

   --  Keys that work everywhere

   function Global_Command (E : Event) return Command is
   begin
      if E.Kind /= Key then
         return Cmd_None;
      end if;
      if E.Code in F1 .. F12 then
         declare
            S : constant Boolean := E.Shift;
            C : constant Boolean := E.Ctrl;
            A : constant Boolean := E.Alt;
            Plain : constant Boolean := not S and then not C and then not A;
         begin
            case E.Code is
               when F1 =>
                  if Plain then return Cmd_Help_Contents;
                  elsif C then return Cmd_Grep; end if;
               when F2 => if Plain then return Cmd_Save; end if;
               when F3 =>
                  if Plain then return Cmd_Open;
                  elsif A then return Cmd_Close; end if;
               when F5 =>
                  if Plain then return Cmd_Zoom;
                  elsif C then return Cmd_Size_Move;
                  elsif A then return Cmd_User_Screen; end if;
               when F6 =>
                  if Plain then return Cmd_Next_Window;
                  elsif S then return Cmd_Prev_Window;
                  elsif C then return Cmd_Find_Spec_Body; end if;
               when F7 => if A then return Cmd_Prev_Msg; end if;
               when F8 =>
                  if A then return Cmd_Next_Msg;
                  elsif C then return Cmd_Debug; end if;
               when F9 =>
                  if Plain then return Cmd_Make;
                  elsif C then return Cmd_Run;
                  elsif S then return Cmd_Flash;
                  elsif A then return Cmd_Monitor; end if;
               when others => null;
            end case;
         end;
         return Cmd_None;
      end if;
      if E.Code = Char_Key and then E.Alt and then not E.Ctrl then
         if E.Ch = 'x' then
            return Cmd_Quit;
         end if;
      end if;
      return Cmd_None;
   end Global_Command;

   function Late_Command (E : Event) return Command is
   --  Keys the active window may use first (Ctrl letters).
   begin
      if Is_Ctrl (E, 'f') then return Cmd_Find;
      elsif Is_Ctrl (E, 'r') then return Cmd_Replace;
      elsif Is_Ctrl (E, 'l') then return Cmd_Search_Again;
      elsif Is_Ctrl (E, 'g') then return Cmd_Goto_Line;
      elsif Is_Ctrl (E, 's') then return Cmd_Save;
      elsif Is_Ctrl (E, 'o') then return Cmd_Open;
      elsif Is_Ctrl (E, 'n') then return Cmd_New;
      elsif Is_Ctrl (E, 'w') then return Cmd_Close;
      end if;
      return Cmd_None;
   end Late_Command;

   procedure Handle_Mouse (E : Event) is
   begin
      if E.Y = 1 then
         if E.Action = Press then
            declare
               M : constant Natural := Menus.Menu_At (E.X);
            begin
               if M /= 0 then
                  Execute (Menus.Execute (M, Open => True, Mouse_Down => True));
               end if;
            end;
         end if;
         return;
      elsif E.Y = Screen.Height then
         if E.Action = Press then
            declare
               C : constant Command := Desktop.Status_Command_At (E.X);
            begin
               if C /= Cmd_None then
                  Execute (C);
               elsif E.X < 12 then
                  null;
               end if;
            end;
         end if;
         return;
      end if;

      declare
         W : constant Window_Access := Desktop.Window_At (E.X, E.Y);
         Handled : Boolean;
      begin
         if W = null then
            return;
         end if;
         if E.Action in Wheel_Up | Wheel_Down then
            W.Handle_Event (E, Handled);
            return;
         end if;
         if E.Action = Press and then W /= Desktop.Active then
            Desktop.Activate (W);
         end if;
         if E.Action = Press then
            case Hit (W.all, E.X, E.Y) is
               when Close_Box =>
                  declare
                     Ignore : constant Boolean := Close_Window (W);
                  begin
                     null;
                  end;
                  return;
               when Zoom_Box =>
                  W.Toggle_Zoom (Desktop.Area);
                  return;
               when Title_Bar =>
                  Drag_Window (W, Sizing => False, X0 => E.X, Y0 => E.Y);
                  return;
               when Resize_Corner =>
                  Drag_Window (W, Sizing => True, X0 => E.X, Y0 => E.Y);
                  return;
               when others =>
                  null;
            end case;
         end if;
         if W = Desktop.Active then
            W.Handle_Event (E, Handled);
         end if;
      end;
   end Handle_Mouse;

   procedure Handle_Key (E : Event) is
      C       : Command := Global_Command (E);
      Handled : Boolean := False;
   begin
      if C /= Cmd_None then
         Execute (C);
         return;
      end if;

      --  The menu bar.
      if Is_Key (E, F10) then
         Execute (Menus.Execute (2, Open => False));
         return;
      elsif E.Code = Char_Key and then E.Alt and then not E.Ctrl then
         if E.Ch in '1' .. '9' then
            declare
               W : constant Window_Access :=
                 Desktop.With_Number (Wide_Wide_Character'Pos (E.Ch) - Character'Pos ('0'));
            begin
               if W /= null then
                  Desktop.Activate (W);
               end if;
            end;
            return;
         elsif E.Ch = '0' then
            Execute (Cmd_Window_List);
            return;
         end if;
         declare
            M : constant Natural := Menus.Menu_For_Alt (E.Ch);
         begin
            if M /= 0 then
               Execute (Menus.Execute (M, Open => True));
               return;
            end if;
         end;
      end if;

      if Desktop.Active /= null then
         Desktop.Active.Handle_Event (E, Handled);
         if Active_Editor /= null then
            declare
               R : constant Command := Active_Editor.Take_Request;
            begin
               if R /= Cmd_None then
                  Execute (R);
                  return;
               end if;
            end;
         end if;
      end if;

      if not Handled then
         C := Late_Command (E);
         if C /= Cmd_None then
            Execute (C);
         elsif Is_Key (E, Escape) and then Desktop.Active /= null
           and then Desktop.Active.all in Viewers.Viewer'Class
         then
            Desktop.Remove (Desktop.Active);       --  Esc closes help
         end if;
      end if;
   end Handle_Key;

   procedure Dispatch (E : Event) is
   begin
      case E.Kind is
         when Resize =>
            Screen.Init;
            Fit_Windows;
         when Mouse =>
            Handle_Mouse (E);
         when Key =>
            Handle_Key (E);
         when Paste =>
            if Desktop.Active /= null then
               declare
                  Ignore : Boolean;
               begin
                  Desktop.Active.Handle_Event (E, Ignore);
               end;
            end if;
         when None =>
            null;
      end case;
   end Dispatch;

   --  Start-up

   procedure Restore_Desktop is
      Saved : constant String_List := Prj.Saved_Desktop;
   begin
      for Entry_Text of Saved loop
         declare
            use Ada.Strings.Fixed;
            --  path:line:col -- the path itself may contain colons.
            C2 : constant Natural := Index (Entry_Text, ":", Ada.Strings.Backward);
            C1 : constant Natural :=
              (if C2 > Entry_Text'First
               then Index (Entry_Text (Entry_Text'First .. C2 - 1), ":", Ada.Strings.Backward)
               else 0);
         begin
            if C1 > 0 then
               declare
                  Path : constant String := Entry_Text (Entry_Text'First .. C1 - 1);
               begin
                  if Ada.Directories.Exists (Path) then
                     Open_File (Path).Go_To
                       (Positive'Value (Entry_Text (C1 + 1 .. C2 - 1)),
                        Positive'Value (Entry_Text (C2 + 1 .. Entry_Text'Last)));
                  end if;
               end;
            end if;
         exception
            when others => null;
         end;
      end loop;
   end Restore_Desktop;

   function Wants_True_Color return Boolean is
      use Ada.Environment_Variables;
      use Ada.Strings.Fixed;
   begin
      if Exists ("COLORTERM") then
         return Index (Value ("COLORTERM"), "truecolor") > 0
           or else Index (Value ("COLORTERM"), "24bit") > 0;
      end if;
      return Exists ("WT_SESSION");          --  Windows Terminal
   end Wants_True_Color;

   procedure Run (Files : String_List; Start_Dir : String) is
      E : Event;
   begin
      Prj.Detect (Start_Dir);
      Screen.Set_True_Color (Wants_True_Color);
      Apply_Editor_Options;

      Msg_Win := Messages.Create;
      Msg_Win.Set_Jump_Handler (On_Jump'Access);
      Menus.Set_Hooks (Enabled'Access, Background'Access);

      Term.Start;
      Screen.Init;

      if not Files.Is_Empty then
         for F of Files loop
            Open_File (F);
         end loop;
      else
         Restore_Desktop;
         if Desktop.Count = 0 then
            if Prj.Kind /= Prj.No_Project and then Prj.Main_Source /= "" then
               Open_File (Prj.Main_Source);
            else
               Open_File ("");
            end if;
         end if;
      end if;

      while not Quit loop
         Redraw;
         E := Get (-1);
         begin
            Dispatch (E);
         exception
            when X : others =>
               --  Never let a bug in a command take the open files with it.
               Dlg.Message_Box
                 ("Internal Error",
                  Ada.Exceptions.Exception_Name (X) & Character'Val (10)
                  & Ada.Exceptions.Exception_Message (X) & Character'Val (10)
                  & "Your files are still open: save them (F2) and report this.");
         end;
      end loop;

      Term.Stop;
   exception
      when others =>
         Term.Stop;
         raise;
   end Run;

end Turbo.App;
