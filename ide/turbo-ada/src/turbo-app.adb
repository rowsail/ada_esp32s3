with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Fixed;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Unchecked_Deallocation;
with Ada.Wide_Wide_Characters.Handling;
with Turbo.Alire;
with Turbo.Buffers;
with Turbo.Clipboard;
with Turbo.Commands;
with Turbo.Desktop;
with Turbo.Editors;
with Turbo.Events;
with Turbo.Help;
with Turbo.JSON;
with Turbo.Jobs;
with Turbo.LSP;
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
   use type Turbo.Projects.Target_Kind;
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

   --  Language server state (see "The language server" below)

   Server_Wanted : Boolean := True;
   Server_Path   : Unbounded_String;          --  "" = find it
   Tried_For     : Unbounded_String;          --  the project last tried
   Server_Note   : Unbounded_String;          --  why it is not running
   Last_Input    : Ada.Calendar.Time := Ada.Calendar.Clock;

   type Place is record
      Path : Unbounded_String;
      Pos  : Buffers.Position;
   end record;
   package Place_Vectors is new Ada.Containers.Vectors (Positive, Place);
   History : Place_Vectors.Vector;

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
         if not E.Is_Untitled and then E.Path /= Target then
            LSP.Close_Document (E.Path);    --  it will be opened under the new name
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
      else
         LSP.Save_Document (E.Path);
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
            if not E.Is_Untitled then
               LSP.Close_Document (E.Path);
            end if;
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
   Diag_Shown    : Boolean := False;   --  a diagnostic is on the status line

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
                             else Prj.Example_Profile (Prj.Example)) & ", ESP32-S3)"
                elsif Prj.Kind = Prj.Standalone then " (ESP32-S3)"
                else " (native)")
             & " ")
        & (if LSP.Status_Text = "" then "" else "| " & LSP.Status_Text & " ");
      Diag  : constant String :=
        (if Active_Editor /= null then Active_Editor.Diagnostic_At_Cursor else "");
   begin
      --  On a diagnostic, its text takes the status line (Turbo C++ showed
      --  the message for the error under the cursor the same way).
      if Diag /= "" then
         Desktop.Set_Status_Message (" " & Diag);
         Diag_Shown := True;
      elsif Diag_Shown then
         Desktop.Set_Status_Message ("");
         Diag_Shown := False;
      end if;
      if Ctx /= Shown_Context then
         Shown_Context := Ctx;
         case Ctx is
            when Ctx_Editor =>
               Desktop.Set_Status
                 ([(+"~F1~ Help", Cmd_Help_Contents), (+"~F2~ Save", Cmd_Save),
                   (+"~F3~ Open", Cmd_Open), (+"~F9~ Make", Cmd_Make),
                   (+"~Ctrl-F9~ Run", Cmd_Run), (+"~Alt-F9~ Compile", Cmd_Check_File),
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
         when Cmd_Definition | Cmd_References | Cmd_Symbols | Cmd_Rename | Cmd_Complete
            | Cmd_Hover
         =>
            return E /= null and then Server_Wanted;
         when Cmd_Check_File => return E /= null and then Prj.Template (Prj.Act_Check) /= "" and then Prj.Kind /= Prj.No_Project;
         when Cmd_Go_Back => return not History.Is_Empty;
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
         when Cmd_Alr_Add => return Prj.Manifest /= "";
         when Cmd_Setup_Toolchain => return Prj.Setup_Command /= "";
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
   --  What the build says it is working on: "@x stage 2/4 link" (from
   --  --machine) -> "2/4 link"; gprbuild's "[Ada]  main.adb" -> "main.adb".
      use Ada.Strings.Fixed;
      L : constant String := Trim (Line, Ada.Strings.Both);
   begin
      if Messages.Stage_Of (Line) /= "" then
         return Messages.Stage_Of (Line);
      elsif L'Length > 3 and then L (L'First .. L'First + 2) = "@x " then
         return "";
      end if;
      if L'Length > 2 and then L (L'First) = '[' then
         declare
            Close : constant Natural := Index (L, "]");
            Tag   : constant String :=
              (if Close > 0 then L (L'First + 1 .. Close - 1) else "");
         begin
            --  gprbuild's own tags only, not the scripts' "[bare]", "[sdk]".
            if Close > 0 and then Close < L'Last
              and then (Tag = "Ada" or else Tag = "C" or else Tag = "Asm"
                        or else Tag = "Asm_Cpp" or else Tag = "link"
                        or else Tag = "archive" or else Tag = "gprbind"
                        or else Tag = "bind" or else Tag = "index")
            then
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

   function Capture (Cmd, Dir, What : String; Lines : out String_List) return Boolean is
   --  Run Cmd in the background, collecting its output, behind a small
   --  "please wait" box (Esc cancels).  True when it exited with status 0.
      Got      : String_List;
      Finished : Boolean := False;
      Ok       : Boolean;
      E        : Event;
   begin
      Lines.Clear;
      Jobs.Start (Cmd, Dir, Ok);
      if not Ok then
         return False;
      end if;
      loop
         Jobs.Poll (Got, Finished);
         for L of Got loop
            Lines.Append (L);
         end loop;
         exit when Finished;
         Update_Status;
         Desktop.Draw;
         Dlg.Show_Busy (What, Cmd & "   (Esc cancels)");
         E := Get (100);
         if Is_Key (E, Escape) then
            Jobs.Cancel;
         elsif E.Kind = Resize then
            Screen.Init;
         end if;
      end loop;
      return Jobs.Succeeded;
   end Capture;

   function Ensure_Environment return Boolean is
   --  The project's compile environment (Act_Env), fetched once per project
   --  and profile.
      Cmd   : constant String := Prj.Command_For (Prj.Act_Env);
      Lines : String_List;
   begin
      if Prj.Environment_Loaded then
         return True;
      end if;
      if Cmd = "" then
         Prj.Set_Environment (Lines);    --  nothing to add
         return True;
      end if;
      if Alire.Needs_Alr (Cmd) and then not Alire.Use_Found then
         return False;                   --  Make offers to fetch it
      end if;
      if Capture (Cmd, Prj.Working_Dir (Prj.Act_Env), "Preparing the environment", Lines)
      then
         Prj.Set_Environment (Lines);
         return True;
      end if;
      Msg_Win.Clear;
      Msg_Win.Add (Messages.Header, "Environment: " & Cmd & "  (failed)");
      for L of Lines loop
         Msg_Win.Add_Line (L);
      end loop;
      Show_Message_Window (Activate => True);
      return False;
   end Ensure_Environment;

   procedure Run_Command
     (Cmd       : String;
      Dir       : String;
      Title     : String;
      Success   : out Boolean;
      Wait_Key  : Boolean := True;
      Is_Build  : Boolean := True;
      With_Env  : Boolean := False;
      Shown     : String := "")
   --  Run Cmd in Dir with the "Compiling" box over it and its output in the
   --  message window; Shown stands for Cmd there when it is a script.
   is
      Display   : constant String := (if Shown = "" then Cmd else Shown);
      Lines     : String_List;
      Finished  : Boolean := False;
      Cancelled : Boolean := False;
      Current   : Unbounded_String;
      Count     : Natural := 0;
      Ok        : Boolean;
      E         : Event;
   begin
      Success := False;
      if Is_Build then
         Save_All;
      end if;

      Msg_Win.Clear;
      Msg_Win.Add (Messages.Header, Title & ": " & Display);
      Show_Message_Window (Activate => False);

      if With_Env then
         if not Ensure_Environment then
            return;
         end if;
         Prj.Push_Environment;
      end if;
      Jobs.Start (Cmd, Dir, Ok);
      if With_Env then
         Prj.Pop_Environment;
      end if;
      if not Ok then
         Dlg.Message_Box ("Error", "Cannot start: " & Display);
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
              and then (L'Length < 3 or else L (L'First .. L'First + 2) /= "@x ")
            then
               Current := To_Unbounded_String (Ada.Strings.Fixed.Trim (L, Ada.Strings.Both));
            end if;
         end loop;
         Msg_Win.Follow_Tail;
         Update_Status;
         Desktop.Draw;
         Draw_Job_Box (Title, Display, To_String (Current), Count,
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
         Draw_Job_Box (Title, Display, To_String (Current), Count,
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
   end Run_Command;

   --  Alire: alr itself, fetched when it is missing

   function Tilde (Path : String) return String is
   --  Path with the home directory shown as ~, for a dialog.
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME") else "");
   begin
      if Home /= "" and then Path'Length > Home'Length
        and then Path (Path'First .. Path'First + Home'Length - 1) = Home
        and then Path (Path'First + Home'Length) = '/'
      then
         return "~" & Path (Path'First + Home'Length .. Path'Last);
      end if;
      return Path;
   end Tilde;

   function Fetch_Alire return Boolean is
      Cmd : constant String := Alire.Fetch_Command;
      Ok  : Boolean;
   begin
      if Cmd = "" then
         Dlg.Message_Box
           ("Alire",
            "Download alr from https://alire.ada.dev" & Character'Val (10)
            & "and put it on PATH, then try again.");
         return False;
      end if;
      Run_Command (Cmd, Ada.Directories.Current_Directory, "Fetching Alire", Ok,
                   Wait_Key => True, Is_Build => False,
                   Shown => "download alr into " & Tilde (Alire.Home_Dir));
      return Ok and then Alire.Use_Found;
   end Fetch_Alire;

   function Ensure_Alr return Boolean is
   --  True when there is an alr to run, after offering to fetch one.
   begin
      if Alire.Use_Found then
         return True;
      end if;
      if Dlg.Message_Box
           ("Alire",
            "This needs Alire (alr), and there is none" & Character'Val (10)
            & "on PATH.  Download the latest release" & Character'Val (10)
            & "from GitHub into" & Character'Val (10)
            & Tilde (Alire.Home_Dir) & "?",
            Dlg.Yes_No) /= Dlg.Ans_Yes
      then
         return False;
      end if;
      return Fetch_Alire;
   end Ensure_Alr;

   --  The SDK's toolchain: the compilers, gprbuild and the xtensa-dynconfig
   --  plugin, set up once (./x setup-toolchain) and checked before the first
   --  build of each SDK.

   Toolchain_Ok_For : Unbounded_String;    --  the root it was found ready for

   procedure Restart_Server;
   --  Below, with the rest of the language-server plumbing.

   procedure Setup_Toolchain (Success : out Boolean) is
      Check : constant String := Prj.Setup_Command (Check_Only => True);
      Lines : String_List;
   begin
      Success := False;
      if Check = "" then
         Dlg.Message_Box ("Information",
                          "This project is not built with the ESP32-S3 SDK.");
         return;
      end if;
      --  alr is only needed to download a compiler or gprbuild; the
      --  dynconfig plugin is built from source in the SDK.
      if not Capture (Check, Prj.Root, "Checking the toolchain", Lines)
        and then (for some L of Lines =>
                    Ada.Strings.Fixed.Index (L, "missing") > 0
                    and then Ada.Strings.Fixed.Index (L, "dynconfig") = 0)
        and then not Alire.Use_Found and then not Ensure_Alr
      then
         return;
      end if;
      Run_Command (Prj.Setup_Command, Prj.Root, "Toolchain set-up", Success,
                   Wait_Key => True, Is_Build => False);
      if Success then
         Toolchain_Ok_For := To_Unbounded_String (Prj.Root);
         Prj.Forget_Environment;
         Restart_Server;
      end if;
   end Setup_Toolchain;

   function Toolchain_Ready return Boolean is
   --  Before a build: True to go ahead (ready, set up now, or the user
   --  would rather see the build fail).
      Check : constant String := Prj.Setup_Command (Check_Only => True);
      Lines : String_List;
      Text  : Unbounded_String;
      Ok    : Boolean;
   begin
      if Check = "" or else To_String (Toolchain_Ok_For) = Prj.Root then
         return True;
      end if;
      if Capture (Check, Prj.Root, "Checking the toolchain", Lines) then
         Toolchain_Ok_For := To_Unbounded_String (Prj.Root);
         return True;
      end if;
      for L of Lines loop
         if Ada.Strings.Fixed.Index (L, "missing") > 0 then
            Append (Text, Ada.Strings.Fixed.Trim
                      (L (L'First + (if L'Length > 8 and then L (L'First .. L'First + 7) = "[setup] "
                                     then 8 else 0) .. L'Last), Ada.Strings.Both)
                    & Character'Val (10));
         end if;
      end loop;
      if Dlg.Message_Box
           ("Toolchain",
            "The ESP32-S3 toolchain is not set up:" & Character'Val (10)
            & To_String (Text)
            & "Set it up now (Alire | Set up ESP32-S3 toolchain)?",
            Dlg.Yes_No) /= Dlg.Ans_Yes
      then
         return True;
      end if;
      Setup_Toolchain (Ok);
      return Ok;
   end Toolchain_Ready;

   procedure Run_Job
     (A         : Prj.Action;
      Title     : String;
      Success   : out Boolean;
      Wait_Key  : Boolean := True;
      Is_Build  : Boolean := True;
      With_Env  : Boolean := False)
   is
      Cmd : constant String :=
        Prj.Command_For (A, (if Active_Editor /= null then Active_Editor.Path else ""));
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
      if Alire.Needs_Alr (Cmd) and then not Ensure_Alr then
         return;
      end if;
      if A in Prj.Act_Build | Prj.Act_Flash | Prj.Act_Check | Prj.Act_Test
        and then not Toolchain_Ready
      then
         return;
      end if;
      Run_Command (Cmd, Prj.Working_Dir (A), Title, Success, Wait_Key, Is_Build, With_Env);
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
      if Alire.Needs_Alr (Cmd) and then not Ensure_Alr then
         return;
      end if;
      if A in Prj.Act_Run | Prj.Act_Debug and then not Toolchain_Ready then
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

   --  The language server
   --
   --  Started at an idle moment once there is a project with a .gpr (for
   --  the SDK: once an example is chosen), with the environment Act_Env
   --  printed; restarted when the project, example or profile changes.
   --  Ada editors are kept in step with it (didOpen, then didChange a
   --  moment after typing stops), and its diagnostics are drawn in them.


   function Project_Key return String is
     (Prj.Dir & "|" & Prj.Example & "|" & Prj.Profile);

   function Is_Ada_Source (Path : String) return Boolean is
     (Path /= "" and then Syntax.Language_Of (Path) = Syntax.Ada_Lang
      and then Ada.Characters.Handling.To_Lower (Ada.Directories.Extension (Path)) /= "gpr");

   function Escape_Pressed return Boolean is
      E : constant Event := Get (0);
   begin
      return Is_Key (E, Escape);
   end Escape_Pressed;

   procedure Sync_Documents (Force : Boolean) is
   --  Open new Ada editors in the server; send changed text once typing
   --  has paused (or now, when Force).
      use type Ada.Calendar.Time;
      Idle : constant Boolean := Ada.Calendar.Clock - Last_Input >= 0.35;
   begin
      if not LSP.Is_Running then
         return;
      end if;
      for K in 1 .. Desktop.Count loop
         if Desktop.Nth (K).all in Editors.Editor'Class then
            declare
               E : constant Editors.Editor_Access := Editors.Editor_Access (Desktop.Nth (K));
            begin
               if not E.Is_Untitled and then Is_Ada_Source (E.Path) then
                  if not LSP.Is_Open (E.Path) then
                     LSP.Open_Document (E.Path, E.Version, Encode (E.Text));
                  elsif LSP.Sent_Version (E.Path) /= E.Version and then (Force or else Idle)
                  then
                     LSP.Change_Document (E.Path, E.Version, Encode (E.Text));
                  end if;
               end if;
            end;
         end if;
      end loop;
   end Sync_Documents;

   procedure Apply_Diagnostics is
   begin
      if not LSP.Diagnostics_Changed then
         return;
      end if;
      for K in 1 .. Desktop.Count loop
         if Desktop.Nth (K).all in Editors.Editor'Class then
            declare
               E    : constant Editors.Editor_Access := Editors.Editor_Access (Desktop.Nth (K));
               List : Editors.Diagnostic_Vectors.Vector;
            begin
               if not E.Is_Untitled then
                  for D of LSP.Diagnostics_For (E.Path) loop
                     declare
                        L1 : constant Positive := Positive'Min (D.Line + 1, E.Line_Count);
                        L2 : constant Positive := Positive'Min (D.End_Line + 1, E.Line_Count);
                     begin
                        List.Append
                          (Editors.Diagnostic'(From    => (L1, LSP.To_Col (E.Line_Text (L1), D.Char)),
                            To      => (L2, LSP.To_Col (E.Line_Text (L2), D.End_Char)),
                            Level   => (case D.Severity is
                                           when 1 => Editors.Sev_Error,
                                           when 2 => Editors.Sev_Warning,
                                           when others => Editors.Sev_Info),
                            Message => D.Message));
                     end;
                  end loop;
                  E.Set_Diagnostics (List);
               end if;
            end;
         end if;
      end loop;
   end Apply_Diagnostics;

   procedure Restart_Server is
   begin
      LSP.Stop;
      Tried_For := Null_Unbounded_String;
      for K in 1 .. Desktop.Count loop
         if Desktop.Nth (K).all in Editors.Editor'Class then
            Editors.Editor_Access (Desktop.Nth (K)).Set_Diagnostics
              (Editors.Diagnostic_Vectors.Empty_Vector);
         end if;
      end loop;
   end Restart_Server;

   procedure Start_Server is
   --  At an idle moment: start the server for this project if it should
   --  run and has not been tried for it yet.
      Ok : Boolean;
   begin
      Server_Wanted := Prj.Get_Option ("lsp.enabled", "1") = "1";
      Server_Path := To_Unbounded_String (Prj.Get_Option ("lsp.path"));
      if LSP.Is_Running and then To_String (Tried_For) /= Project_Key then
         --  The project, example or profile changed under it.
         Restart_Server;
      end if;
      if not Server_Wanted or else LSP.Is_Running
        or else To_String (Tried_For) = Project_Key
        or else Prj.Kind = Prj.No_Project
        or else (Prj.Kind = Prj.SDK_Example and then Prj.Example = ""
                 and then Prj.Suite = "")
      then
         return;
      end if;
      Tried_For := To_Unbounded_String (Project_Key);
      declare
         Exe : constant String := LSP.Find_Server (To_String (Server_Path));
      begin
         if Exe = "" then
            Server_Note := To_Unbounded_String
              ("no ada_language_server found (Alire | Install tool)");
            return;
         end if;
         if not Ensure_Environment then
            Server_Note := To_Unbounded_String ("the project environment failed");
            return;
         end if;
         if Prj.Main_Gpr = "" then
            Server_Note := To_Unbounded_String ("no .gpr project file");
            return;
         end if;
         Desktop.Set_Status_Message ("Starting the Ada Language Server...");
         Redraw;
         Prj.Push_Environment;
         LSP.Start (Exe, Prj.Main_Gpr, Prj.Dir, Ok);
         Prj.Pop_Environment;
         Desktop.Set_Status_Message ("");
         Server_Note := To_Unbounded_String (if Ok then "" else LSP.Last_Error);
         if Ok then
            Sync_Documents (Force => True);
         end if;
      end;
   end Start_Server;

   function Server_Ready return Boolean is
   --  For a command that needs the server: say why not, if not.
   begin
      if not LSP.Is_Running then
         Start_Server;
      end if;
      if LSP.Is_Running then
         Sync_Documents (Force => True);
         return True;
      end if;
      Dlg.Message_Box
        ("Language Server",
         "The Ada Language Server is not running"
         & (if Length (Server_Note) > 0 then ":" & Character'Val (10) & To_String (Server_Note)
            elsif not Server_Wanted then " (Options | Language server)."
            else "."));
      return False;
   end Server_Ready;

   procedure Ask (Method, Params : String; R : in out LSP.Response) is
   begin
      Desktop.Set_Status_Message ("Asking the language server...   (Esc cancels)");
      Redraw;
      LSP.Request (Method, Params, R, Escape_Pressed'Access);
      Desktop.Set_Status_Message ("");
   end Ask;

   --  Locations from the server, as editor positions.

   type Buffer_Access is access Buffers.Buffer;
   Cached_Path : Unbounded_String;
   Cached_Buf  : constant Buffer_Access := new Buffers.Buffer;

   function Line_Of (Path : String; Line0 : Natural) return Wide_Wide_String is
   --  Line Line0 (0-based) of Path, from its editor or else from disk.
      E : constant Editors.Editor_Access := Find_Editor (Path);
      Ok : Boolean;
   begin
      if E /= null then
         return E.Line_Text (Line0 + 1);
      end if;
      if To_String (Cached_Path) /= Path then
         Cached_Buf.Load (Path, Ok);
         Cached_Path := To_Unbounded_String (Path);
      end if;
      return Cached_Buf.Line (Positive'Min (Line0 + 1, Cached_Buf.Line_Count));
   end Line_Of;

   function To_Position (Path : String; Line0, Char : Natural) return Buffers.Position is
     ((Line0 + 1, LSP.To_Col (Line_Of (Path, Line0), Char)));

   type Location is record
      Path        : Unbounded_String;
      Line, Char  : Natural := 0;
   end record;
   package Location_Vectors is new Ada.Containers.Vectors (Positive, Location);

   function Locations (R : LSP.Response) return Location_Vectors.Vector is
   --  Location | Location[] | LocationLink[] -> a list.
      use Turbo.JSON;
      Result : Location_Vectors.Vector;
      procedure Add (V : Value) is
         Uri : constant Value :=
           (if Is_Present (Get (R.Doc, V, "targetUri")) then Get (R.Doc, V, "targetUri")
            else Get (R.Doc, V, "uri"));
         Rng : constant Value :=
           (if Is_Present (Get (R.Doc, V, "targetSelectionRange"))
            then Get (R.Doc, V, "targetSelectionRange") else Get (R.Doc, V, "range"));
      begin
         if Is_Present (Uri) then
            Result.Append
              (Location'(To_Unbounded_String (LSP.Path_Of (To_String (R.Doc, Uri))),
                To_Integer (R.Doc, Path (R.Doc, Rng, "start.line")),
                To_Integer (R.Doc, Path (R.Doc, Rng, "start.character"))));
         end if;
      end Add;
      V : Value;
   begin
      if Kind_Of (R.Doc, R.Result) = J_Array then
         V := First_Member (R.Doc, R.Result);
         while Is_Present (V) loop
            Add (V);
            V := Next_Member (R.Doc, V);
         end loop;
      elsif Kind_Of (R.Doc, R.Result) = J_Object then
         Add (R.Result);
      end if;
      return Result;
   end Locations;

   procedure Remember_Place is
      E : constant Editors.Editor_Access := Active_Editor;
   begin
      if E /= null and then not E.Is_Untitled then
         History.Append (Place'(To_Unbounded_String (E.Path), E.Cursor));
         if Natural (History.Length) > 50 then
            History.Delete_First;
         end if;
      end if;
   end Remember_Place;

   procedure Go_To_Location (L : Location) is
      Path : constant String := To_String (L.Path);
      P    : Buffers.Position;
   begin
      if not Ada.Directories.Exists (Path) then
         Dlg.Message_Box ("Information", "Cannot open " & Path);
         return;
      end if;
      P := To_Position (Path, L.Line, L.Char);
      Remember_Place;
      Open_File (Path).Go_To (P.Line, P.Col);
   end Go_To_Location;

   function Describe (L : Location) return String is
     (Simple (To_String (L.Path)) & ":" & Img (L.Line + 1) & "  "
      & Encode (Ada.Strings.Wide_Wide_Fixed.Trim
                  (Line_Of (To_String (L.Path), L.Line), Ada.Strings.Both)));

   function Here (E : Editors.Editor_Access) return String is
     (LSP.Position_Params (E.Path, E.Cursor.Line - 1,
                           LSP.To_Char (E.Line_Text (E.Cursor.Line), E.Cursor.Col)));

   function Usable_Editor return Editors.Editor_Access is
      E : constant Editors.Editor_Access := Active_Editor;
   begin
      if E = null or else E.Is_Untitled or else not Is_Ada_Source (E.Path) then
         Dlg.Message_Box ("Information", "This works on a saved Ada source file.");
         return null;
      end if;
      return E;
   end Usable_Editor;

   procedure Go_To_Definition is
      E : constant Editors.Editor_Access := Usable_Editor;
      R : LSP.Response;
   begin
      if E = null or else not Server_Ready then
         return;
      end if;
      Ask ("textDocument/definition", Here (E), R);
      if not R.Ok then
         Dlg.Message_Box ("Language Server", To_String (R.Error));
         return;
      end if;
      declare
         L : constant Location_Vectors.Vector := Locations (R);
      begin
         if L.Is_Empty then
            Dlg.Message_Box ("Information", "No definition found for '"
                             & Encode (E.Word_At_Cursor) & "'.");
         elsif Natural (L.Length) = 1 then
            Go_To_Location (L.First_Element);
         else
            declare
               Items : String_List;
               Index : Positive := 1;
            begin
               for X of L loop
                  Items.Append (Describe (X));
               end loop;
               if Dlg.Choose ("Go to Definition", "~D~efinitions", Items, Index, 60, "~G~o to")
               then
                  Go_To_Location (L (Index));
               end if;
            end;
         end if;
      end;
   end Go_To_Definition;

   procedure Go_Back is
   begin
      if History.Is_Empty then
         return;
      end if;
      declare
         P : constant Place := History.Last_Element;
      begin
         History.Delete_Last;
         if Ada.Directories.Exists (To_String (P.Path)) then
            Open_File (To_String (P.Path)).Go_To (P.Pos.Line, P.Pos.Col);
         end if;
      end;
   end Go_Back;

   procedure Find_References is
      E : constant Editors.Editor_Access := Usable_Editor;
      R : LSP.Response;
   begin
      if E = null or else not Server_Ready then
         return;
      end if;
      declare
         Word : constant String := Encode (E.Word_At_Cursor);
         P    : constant String := Here (E);
      begin
         Ask ("textDocument/references",
              P (P'First .. P'Last - 1) & ",""context"":{""includeDeclaration"":true}}", R);
         if not R.Ok then
            Dlg.Message_Box ("Language Server", To_String (R.Error));
            return;
         end if;
         Msg_Win.Clear;
         Msg_Win.Add (Messages.Header, "Uses of " & Word);
         for L of Locations (R) loop
            declare
               Pos : constant Buffers.Position :=
                 To_Position (To_String (L.Path), L.Line, L.Char);
            begin
               Msg_Win.Add_Location
                 (To_String (L.Path), Pos.Line, Pos.Col,
                  Ada.Strings.Wide_Wide_Fixed.Trim
                    (Line_Of (To_String (L.Path), L.Line), Ada.Strings.Both));
            end;
         end loop;
         Msg_Win.Add (Messages.Header, Img (Msg_Win.Line_Count - 1) & " use(s).");
         Show_Message_Window (Activate => True);
      end;
   end Find_References;

   procedure Symbol_List is
      use Turbo.JSON;
      E      : constant Editors.Editor_Access := Usable_Editor;
      R      : LSP.Response;
      Items  : String_List;
      Places : Location_Vectors.Vector;
      Index  : Positive := 1;

      function Kind_Name (K : Integer) return String is
        (case K is
            when 2 | 6 | 12 => "function",   --  method, constructor, function
            when 3 => "namespace",
            when 4 => "package",
            when 5 => "type",
            when 9 => "constructor",
            when 10 => "enum",
            when 11 => "interface",
            when 13 => "variable",
            when 14 => "constant",
            when 22 => "literal",
            when 23 => "record",
            when 26 => "type param",
            when others => "");

      procedure Walk (V : Value; Depth : Natural) is
         C : Value := First_Member (R.Doc, V);
      begin
         while Is_Present (C) loop
            declare
               Name : constant String := To_String (R.Doc, Get (R.Doc, C, "name"));
               Sel  : constant Value :=
                 (if Is_Present (Get (R.Doc, C, "selectionRange"))
                  then Get (R.Doc, C, "selectionRange")
                  else Path (R.Doc, C, "location.range"));
               K    : constant String := Kind_Name (To_Integer (R.Doc, Get (R.Doc, C, "kind")));
               Line : constant Natural := To_Integer (R.Doc, Path (R.Doc, Sel, "start.line"));
            begin
               Items.Append ((1 .. 2 * Depth => ' ') & Name
                             & (if K = "" then "" else "  (" & K & ")")
                             & "  :" & Img (Line + 1));
               Places.Append (Location'(To_Unbounded_String (E.Path), Line,
                               To_Integer (R.Doc, Path (R.Doc, Sel, "start.character"))));
               if Is_Present (Get (R.Doc, C, "children")) then
                  Walk (Get (R.Doc, C, "children"), Depth + 1);
               end if;
            end;
            C := Next_Member (R.Doc, C);
         end loop;
      end Walk;
   begin
      if E = null or else not Server_Ready then
         return;
      end if;
      Ask ("textDocument/documentSymbol", "{""textDocument"":" & LSP.Text_Document (E.Path) & "}", R);
      if not R.Ok then
         Dlg.Message_Box ("Language Server", To_String (R.Error));
         return;
      end if;
      Walk (R.Result, 0);
      if Items.Is_Empty then
         Dlg.Message_Box ("Information", "No symbols in this file.");
      elsif Dlg.Choose ("Symbol List", "~S~ymbols in " & Simple (E.Path), Items, Index, 60,
                        "~G~o to")
      then
         Go_To_Location (Places (Index));
      end if;
   end Symbol_List;

   procedure Hover is
      use Turbo.JSON;
      E    : constant Editors.Editor_Access := Usable_Editor;
      R    : LSP.Response;
      Text : Unbounded_String;
      LF   : constant Character := Character'Val (10);

      procedure Add (V : Value) is
      begin
         case Kind_Of (R.Doc, V) is
            when J_String =>
               Append (Text, To_String (R.Doc, V) & LF);
            when J_Object =>
               Append (Text, To_String (R.Doc, Get (R.Doc, V, "value")) & LF);
            when J_Array =>
               declare
                  C : Value := First_Member (R.Doc, V);
               begin
                  while Is_Present (C) loop
                     Add (C);
                     C := Next_Member (R.Doc, C);
                  end loop;
               end;
            when others => null;
         end case;
      end Add;
   begin
      if E = null or else not Server_Ready then
         return;
      end if;
      Ask ("textDocument/hover", Here (E), R);
      if not R.Ok then
         Dlg.Message_Box ("Language Server", To_String (R.Error));
         return;
      end if;
      Add (Get (R.Doc, R.Result, "contents"));
      if Length (Text) = 0 then
         Dlg.Message_Box ("Information", "No help on '" & Encode (E.Word_At_Cursor) & "'.");
      else
         Show_Help ("Help on " & Encode (E.Word_At_Cursor),
                    "# " & Encode (E.Word_At_Cursor) & LF & LF & To_String (Text));
      end if;
   end Hover;

   procedure Rename is
      use Turbo.JSON;
      E     : constant Editors.Editor_Access := Usable_Editor;
      R     : LSP.Response;
      Name  : Unbounded_String;
      Edits : Natural := 0;
      Files : Natural := 0;

      procedure Apply (File : String; List : Value) is
      --  The edits for one file, last first so earlier positions hold.
         type Edit is record
            From, To : Buffers.Position;
            Text     : Unbounded_String;
         end record;
         function "<" (A, B : Edit) return Boolean is (Buffers."<" (B.From, A.From));
         package Edit_Vectors is new Ada.Containers.Vectors (Positive, Edit);
         package Sorting is new Edit_Vectors.Generic_Sorting;
         All_Edits : Edit_Vectors.Vector;
         Target    : Editors.Editor_Access;
         C         : Value := First_Member (R.Doc, List);
      begin
         if not Ada.Directories.Exists (File) then
            return;
         end if;
         Target := Open_File (File, Activate => False);
         while Is_Present (C) loop
            declare
               Rng : constant Value := Get (R.Doc, C, "range");
            begin
               All_Edits.Append
                 (Edit'(From => To_Position (File, To_Integer (R.Doc, Path (R.Doc, Rng, "start.line")),
                                        To_Integer (R.Doc, Path (R.Doc, Rng, "start.character"))),
                   To   => To_Position (File, To_Integer (R.Doc, Path (R.Doc, Rng, "end.line")),
                                        To_Integer (R.Doc, Path (R.Doc, Rng, "end.character"))),
                   Text => To_Unbounded_String (To_String (R.Doc, Get (R.Doc, C, "newText")))));
            end;
            C := Next_Member (R.Doc, C);
         end loop;
         Sorting.Sort (All_Edits);
         Target.Begin_Edit_Group;
         for X of All_Edits loop
            Target.Replace_Range (X.From, X.To, Decode (To_String (X.Text)));
            Edits := Edits + 1;
         end loop;
         Target.End_Edit_Group;
         Files := Files + 1;
      end Apply;
   begin
      if E = null or else not Server_Ready then
         return;
      end if;
      Name := To_Unbounded_String (Encode (E.Word_At_Cursor));
      if Length (Name) = 0 then
         return;
      end if;
      declare
         Old : constant String := To_String (Name);
         P   : constant String := Here (E);
      begin
         if not Dlg.Input_Box ("Rename Symbol", "~N~ew name for " & Old, Name, 40)
           or else To_String (Name) = Old or else Length (Name) = 0
         then
            return;
         end if;
         Ask ("textDocument/rename",
              P (P'First .. P'Last - 1) & ",""newName"":" & Quote (To_String (Name)) & "}", R);
      end;
      if not R.Ok then
         Dlg.Message_Box ("Language Server", To_String (R.Error));
         return;
      end if;
      declare
         Changes : constant Value := Get (R.Doc, R.Result, "changes");
         Doc_Ch  : constant Value := Get (R.Doc, R.Result, "documentChanges");
         C       : Value;
      begin
         if Is_Present (Changes) then
            C := First_Member (R.Doc, Changes);
            while Is_Present (C) loop
               Apply (LSP.Path_Of (Key (R.Doc, C)), C);
               C := Next_Member (R.Doc, C);
            end loop;
         elsif Is_Present (Doc_Ch) then
            C := First_Member (R.Doc, Doc_Ch);
            while Is_Present (C) loop
               Apply (LSP.Path_Of (To_String (R.Doc, Path (R.Doc, C, "textDocument.uri"))),
                      Get (R.Doc, C, "edits"));
               C := Next_Member (R.Doc, C);
            end loop;
         end if;
      end;
      Desktop.Activate (Window_Access (E));
      Sync_Documents (Force => True);
      Dlg.Message_Box ("Rename Symbol",
                       Img (Edits) & " change(s) in" & Natural'Image (Files) & " file(s)."
                       & (if Files > 1 then Character'Val (10) & "Save them with File | Save all."
                          else ""));
   end Rename;

   procedure Diagnostics_List is
   begin
      Msg_Win.Clear;
      Msg_Win.Add (Messages.Header, "Diagnostics from the language server");
      for C in LSP.All_Diagnostics.Iterate loop
         declare
            File : constant String := LSP.Path_Maps.Key (C);
         begin
            if Is_Ada_Source (File) then
               for D of LSP.Path_Maps.Element (C) loop
                  declare
                     P : constant Buffers.Position := To_Position (File, D.Line, D.Char);
                  begin
                     Msg_Win.Add_Location
                       (File, P.Line, P.Col, Decode (To_String (D.Message)),
                        (case D.Severity is
                            when 1 => Messages.Error,
                            when 2 => Messages.Warning,
                            when others => Messages.Note));
                  end;
               end loop;
            end if;
         end;
      end loop;
      if Msg_Win.Line_Count = 1 then
         Msg_Win.Add (Messages.Info,
                      (if LSP.Is_Running then "None." else "The language server is not running."));
      end if;
      Show_Message_Window (Activate => True);
   end Diagnostics_List;

   procedure Complete is
   --  Ctrl-Space: a Turbo-style pick list under the cursor.  Typing goes on
   --  into the editor and narrows the list; Enter or Tab takes the choice.
      use Turbo.JSON;
      E : constant Editors.Editor_Access := Usable_Editor;

      type Item is record
         Label : Unbounded_String;
         Text  : Unbounded_String;     --  what to insert
         Kind  : Integer := 0;
         Sort  : Unbounded_String;
      end record;
      package Item_Vectors is new Ada.Containers.Vectors (Positive, Item);
      All_Items : Item_Vectors.Vector;
      Shown     : Item_Vectors.Vector;
      Sel       : Positive := 1;
      Top       : Positive := 1;
      R         : LSP.Response;

      function Prefix return String is
         S : constant Buffers.Position := E.Word_Start;
      begin
         return Ada.Characters.Handling.To_Lower
           (Encode (E.Line_Text (S.Line) (S.Col .. E.Cursor.Col - 1)));
      end Prefix;

      procedure Narrow is
      --  The items starting with what has been typed, without repeats.
      --  The server also offers names that are not visible here, marked
      --  "(invisible)"; they are shown only when nothing visible matches.
         P : constant String := Prefix;
      begin
         for Pass in 1 .. 2 loop
            Shown.Clear;
            for It of All_Items loop
               declare
                  L : constant String := Ada.Characters.Handling.To_Lower (To_String (It.Label));
                  Hidden : constant Boolean := Ada.Strings.Fixed.Index (L, "(invisible)") > 0;
                  Seen   : Boolean := False;
               begin
                  if L'Length >= P'Length and then L (L'First .. L'First + P'Length - 1) = P
                    and then (Pass = 2 or else not Hidden)
                  then
                     for Other of Shown loop
                        if Other.Label = It.Label and then Other.Kind = It.Kind then
                           Seen := True;
                        end if;
                     end loop;
                     if not Seen then
                        Shown.Append (It);
                     end if;
                  end if;
               end;
            end loop;
            exit when not Shown.Is_Empty;
         end loop;
         Sel := 1;
         Top := 1;
      end Narrow;

      function Tag (K : Integer) return String is
        (case K is
            when 2 | 3 | 4 => "func",
            when 5 | 10 => "field",
            when 6 => "var",
            when 7 | 22 => "type",
            when 9 => "pkg",
            when 13 | 20 => "enum",
            when 14 => "kw",
            when 21 => "const",
            when others => "");

      procedure Draw_List is
         use Turbo.Screen;
         X, Y   : Integer;
         Rows   : constant Integer := Integer'Min (10, Natural (Shown.Length));
         Box_W : Integer := 16;
      begin
         E.Cursor_Screen (X, Y);
         for It of Shown loop
            Box_W := Integer'Max (Box_W, Length (It.Label) + 9);
         end loop;
         Box_W := Integer'Min (Box_W, 50);
         X := Integer'Max (1, Integer'Min (X - 1, Screen.Width - Box_W - 1));
         if Y + Rows + 2 > Screen.Height - 1 then
            Y := Y - Rows - 2;          --  no room below: above the line
         else
            Y := Y + 1;
         end if;
         Fill (X, Y, Box_W, Rows + 2, ' ', Theme.List_Normal);
         Frame (X, Y, Box_W, Rows + 2, Theme.List_Normal, Double => False);
         Shadow (X + Box_W, Y + 1, 2, Rows + 2);
         Shadow (X + 2, Y + Rows + 2, Box_W, 1);
         if Sel < Top then
            Top := Sel;
         elsif Sel >= Top + Rows then
            Top := Sel - Rows + 1;
         end if;
         for K in 0 .. Rows - 1 loop
            declare
               N  : constant Positive := Top + K;
               It : constant Item := Shown (N);
               A  : constant Attribute :=
                 (if N = Sel then Theme.List_Focused else Theme.List_Normal);
               L  : constant String := To_String (It.Label);
               T  : constant String := Tag (It.Kind);
            begin
               Fill (X + 1, Y + 1 + K, Box_W - 2, 1, ' ', A);
               Put_Wide (X + 2, Y + 1 + K,
                         Decode (if L'Length > Box_W - 9 then L (L'First .. L'First + Box_W - 10)
                                 else L), A);
               Put (X + Box_W - 2 - T'Length, Y + 1 + K, T,
                    (if N = Sel then A else Theme.List_Divider));
            end;
         end loop;
      end Draw_List;

      procedure Accept_Item is
         T   : constant String := To_String (Shown (Sel).Text);
         Cut : constant Natural := Ada.Strings.Fixed.Index (T, " (invisible)");
      begin
         E.Replace_Range (E.Word_Start, E.Cursor,
                          Decode (if Cut > 0 then T (T'First .. Cut - 1) else T));
      end Accept_Item;

      Ev      : Event;
      Handled : Boolean;
   begin
      if E = null or else not Server_Ready then
         return;
      end if;
      Ask ("textDocument/completion", Here (E), R);
      if not R.Ok then
         Dlg.Message_Box ("Language Server", To_String (R.Error));
         return;
      end if;
      declare
         List : constant Value :=
           (if Kind_Of (R.Doc, R.Result) = J_Array then R.Result
            else Get (R.Doc, R.Result, "items"));
         C    : Value := First_Member (R.Doc, List);
      begin
         while Is_Present (C) loop
            declare
               Label : constant String := To_String (R.Doc, Get (R.Doc, C, "label"));
               Ins   : constant String :=
                 To_String (R.Doc, Path (R.Doc, C, "textEdit.newText"),
                            To_String (R.Doc, Get (R.Doc, C, "insertText"), Label));
               It    : Item;
               Pos   : Natural := Item_Vectors.No_Index;
            begin
               It := (To_Unbounded_String (Label), To_Unbounded_String (Ins),
                      To_Integer (R.Doc, Get (R.Doc, C, "kind")),
                      To_Unbounded_String (To_String (R.Doc, Get (R.Doc, C, "sortText"), Label)));
               --  Keep the server's order (its sortText).
               for K in 1 .. Natural (All_Items.Length) loop
                  if It.Sort < All_Items (K).Sort then
                     Pos := K;
                     exit;
                  end if;
               end loop;
               if Pos = Item_Vectors.No_Index then
                  All_Items.Append (It);
               else
                  All_Items.Insert (Pos, It);
               end if;
            end;
            C := Next_Member (R.Doc, C);
         end loop;
      end;
      Narrow;
      if Shown.Is_Empty then
         Desktop.Set_Status_Message ("No completions here.");
         Redraw;
         delay 0.6;
         Desktop.Set_Status_Message ("");
         return;
      elsif Natural (Shown.Length) = 1 then
         Accept_Item;
         return;
      end if;
      loop
         Update_Status;
         Desktop.Draw;
         Draw_List;
         Screen.Flush;
         Ev := Get (-1);
         if Ev.Kind = Key then
            case Ev.Code is
               when Escape => exit;
               when Up => Sel := (if Sel = 1 then Natural (Shown.Length) else Sel - 1);
               when Down => Sel := (if Sel = Natural (Shown.Length) then 1 else Sel + 1);
               when Page_Up => Sel := Positive'Max (1, Sel - 10);
               when Page_Down => Sel := Positive'Min (Natural (Shown.Length), Sel + 10);
               when Enter | Tab =>
                  Accept_Item;
                  exit;
               when Backspace | Char_Key =>
                  if Ev.Code = Char_Key
                    and then not (Is_Plain_Char (Ev)
                                  and then (Ada.Wide_Wide_Characters.Handling.Is_Alphanumeric (Ev.Ch)
                                            or else Ev.Ch = '_'))
                  then
                     --  Anything else ends completion and still happens.
                     Push_Back (Ev);
                     exit;
                  end if;
                  E.Handle_Event (Ev, Handled);
                  exit when E.Cursor.Col <= E.Word_Start.Col and then Ev.Code = Backspace;
                  Narrow;
                  exit when Shown.Is_Empty;
               when others =>
                  Push_Back (Ev);
                  exit;
            end case;
         elsif Ev.Kind = Mouse and then Ev.Action = Press then
            exit;
         elsif Ev.Kind = Resize then
            Screen.Init;
         end if;
      end loop;
   end Complete;

   procedure Server_Options is
      D : Dlg.Dialog;
      Use_Id, Path_Id : Positive;
      Found : constant String := LSP.Find_Server (To_String (Server_Path));
      Code  : Integer;
   begin
      D.Init ("Language Server", 64, 14);
      Use_Id := D.Add_Check (3, 2, 56, "~U~se the Ada Language Server", Server_Wanted);
      Path_Id := D.Add_Input (3, 5, 58, To_String (Server_Path));
      D.Add_Label (2, 4, "~P~rogram (empty: find ada_language_server)", Path_Id);
      D.Add_Text (3, 7, (if Found = "" then "Not found.  alr install ada_language_server"
                         else "Using " & Found));
      D.Add_Text (3, 8, "State: " & (case LSP.State is
                                        when LSP.Off => "not running"
                                                        & (if Length (Server_Note) > 0
                                                           then " -- " & To_String (Server_Note) else ""),
                                        when LSP.Running => "running",
                                        when LSP.Failed => "failed -- " & LSP.Last_Error));
      D.Add_Button (6, 10, 12, "~O~K", 1, Default => True);
      D.Add_Button (24, 10, 14, "~R~estart", 2);
      D.Add_Button (44, 10, 12, "Cancel", Dlg.Cancel_Code);
      Code := D.Run;
      if Code = 1 or else Code = 2 then
         declare
            New_Path : constant String := Ada.Strings.Fixed.Trim (D.Value (Path_Id), Ada.Strings.Both);
            Changed  : constant Boolean :=
              D.Checked (Use_Id) /= Server_Wanted or else New_Path /= To_String (Server_Path);
         begin
            Server_Wanted := D.Checked (Use_Id);
            Server_Path := To_Unbounded_String (New_Path);
            Prj.Set_Option ("lsp.enabled", (if Server_Wanted then "1" else "0"));
            Prj.Set_Option ("lsp.path", New_Path);
            if Changed or else Code = 2 then
               Restart_Server;
               if Server_Wanted then
                  Start_Server;
               end if;
            end if;
         end;
      end if;
   end Server_Options;

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
            --  The examples (built for the ESP32-S3), then the libraries'
            --  host test suites (built natively).
            Names  : constant String_List := Prj.Examples;
            Suites : constant String_List := Prj.Host_Suites;
            Shown  : String_List;
            Index  : Positive := 1;
            function Pad (N : String) return String is
              (N & (1 .. Integer'Max (1, 26 - N'Length) => ' '));
         begin
            for K in 1 .. Natural (Names.Length) loop
               declare
                  N : constant String := Names (K);
               begin
                  Shown.Append (Pad (N) & "ESP32-S3, " & Prj.Example_Profile (N));
                  if N = Prj.Example then
                     Index := K;
                  end if;
               end;
            end loop;
            for K in 1 .. Natural (Suites.Length) loop
               Shown.Append (Pad (Suites (K)) & "native (host test)");
               if Suites (K) = Prj.Suite then
                  Index := Natural (Names.Length) + K;
               end if;
            end loop;
            if Dlg.Choose ("Open Project", "~E~xamples and host tests", Shown, Index, 50,
                           "~O~pen")
            then
               if Index <= Natural (Names.Length) then
                  Prj.Set_Example (Names (Index));
               else
                  Prj.Set_Suite (Suites (Index - Natural (Names.Length)));
               end if;
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
         if Given = "" or else (Alire.Needs_Alr (Cmd) and then not Ensure_Alr) then
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
      Append (T, "  Target:    " & Prj.Target_Image & LF);
      Append (T, "  Name:      " & Prj.Name & LF);
      Append (T, "  Directory: " & Prj.Dir & LF);
      if Prj.Root /= Prj.Dir then
         Append (T, "  SDK root:  " & Prj.Root & LF);
      end if;
      if Prj.Kind = Prj.SDK_Example and then Prj.Example /= "" then
         Append (T, "  Profile:   " & (if Prj.Profile = "" then Prj.Example_Profile (Prj.Example)
                                       & " (the example's own)" else Prj.Profile) & LF);
      end if;
      Append (T, "  Port:      " & (if Prj.Port = "" then "(found by USB id)" else Prj.Port) & LF);
      Append (T, "  Console:   " & (if Prj.Console = "" then "(the USB/JTAG port)" else Prj.Console) & LF);
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

   type Board_Port is record
      Role, Path, Serial, Product : Unbounded_String;
   end record;
   package Board_Port_Vectors is new Ada.Containers.Vectors (Positive, Board_Port);

   function Board_Ports (Flash, Console : out Unbounded_String)
                         return Board_Port_Vectors.Vector is
   --  What the SDK finds (./x ports --json): every board port, and the
   --  flash and console ports it would use now ("" when it cannot choose).
      Cmd   : constant String := Prj.Ports_Command;
      Lines : String_List;
      Text  : Unbounded_String;
      Doc   : JSON.Document;
      Ok    : Boolean;
      R     : Board_Port_Vectors.Vector;
   begin
      Flash := Null_Unbounded_String;
      Console := Null_Unbounded_String;
      if Cmd = "" or else not Capture (Cmd, Prj.Root, "Looking for boards", Lines) then
         return R;
      end if;
      for L of Lines loop
         Append (Text, L);
      end loop;
      Doc.Parse (To_String (Text), Ok);
      if not Ok then
         return R;
      end if;
      declare
         Root : constant JSON.Value := Doc.Root;
         List : constant JSON.Value := Doc.Get (Root, "ports");
      begin
         Flash := To_Unbounded_String (Doc.To_String (Doc.Get (Root, "flash")));
         Console := To_Unbounded_String (Doc.To_String (Doc.Get (Root, "console")));
         for N in 1 .. Doc.Length (List) loop
            declare
               E : constant JSON.Value := Doc.Element (List, N);
            begin
               R.Append (Board_Port'(Role    => To_Unbounded_String (Doc.To_String (Doc.Get (E, "role"))),
                          Path    => To_Unbounded_String (Doc.To_String (Doc.Get (E, "path"))),
                          Serial  => To_Unbounded_String (Doc.To_String (Doc.Get (E, "serial"))),
                          Product => To_Unbounded_String (Doc.To_String (Doc.Get (E, "product")))));
            end;
         end loop;
      end;
      return R;
   end Board_Ports;

   procedure Target_Options is
      D : Dlg.Dialog;
      Port_Id, Con_Id, Prof_Id : Positive;
      Profiles : constant array (1 .. 4) of Desktop.Label_Access :=
        [+"", +"light-tasking", +"embedded", +"full"];
      Cur   : Positive := 1;
      Code  : Integer;
      Flash, Console : Unbounded_String;
      Ports : Board_Port_Vectors.Vector;

      function Count (Role : String) return Natural is
         N : Natural := 0;
      begin
         for P of Ports loop
            if To_String (P.Role) = Role then
               N := N + 1;
            end if;
         end loop;
         return N;
      end Count;

      function Found return String is
        (if Ports.Is_Empty then "No board found (USB/JTAG or USB-UART)."
         else "Now: flash " & (if Flash = Null_Unbounded_String then "? (several)"
                               else To_String (Flash))
              & ", console " & (if Console = Null_Unbounded_String then "? (several)"
                                else To_String (Console)));
   begin
      if Prj.Target = Prj.Target_Native then
         Dlg.Message_Box ("Target", Prj.Name & " builds natively, for this machine:"
                          & Character'Val (10)
                          & "there is no serial port or runtime profile to set.");
         return;
      end if;
      for K in Profiles'Range loop
         if Profiles (K).all = Prj.Profile then
            Cur := K;
         end if;
      end loop;
      Ports := Board_Ports (Flash, Console);
      D.Init ("Target", 64, 18);
      Port_Id := D.Add_Input (3, 3, 30, Prj.Port);
      D.Add_Label (2, 2, "USB/JTAG ~p~ort: flash, debug (empty: found by USB id)", Port_Id);
      Con_Id := D.Add_Input (3, 6, 30, Prj.Console);
      D.Add_Label (2, 5, "~C~onsole: empty = the USB/JTAG port, uart = the bridge", Con_Id);
      D.Add_Text (3, 8, Found);
      Prof_Id := D.Add_Radio (3, 11, 40,
        "~P~roject default|~L~ight-tasking (Jorvik)|~E~mbedded|~F~ull", Cur);
      D.Add_Label (2, 10, "Runtime p~r~ofile", Prof_Id);
      D.Add_Button (6, 15, 12, "~O~K", 1, Default => True);
      D.Add_Button (24, 15, 14, "~D~etect...", 2);
      D.Add_Button (44, 15, 12, "Cancel", Dlg.Cancel_Code);
      loop
         Code := D.Run;
         exit when Code /= 2;
         --  Detect: list the board ports; choosing one fills the field for
         --  its role -- by name only when there is more than one to tell apart.
         Ports := Board_Ports (Flash, Console);
         if Ports.Is_Empty then
            Dlg.Message_Box ("Detect", "No ESP32-S3 USB/JTAG port or USB-UART bridge"
                             & Character'Val (10) & "is plugged in.");
         else
            declare
               Items : String_List;
               Index : Positive := 1;
            begin
               for P of Ports loop
                  Items.Append ((if To_String (P.Role) = "jtag" then "USB/JTAG " else "UART     ")
                                & To_String (P.Path) & "  " & To_String (P.Serial)
                                & "  " & To_String (P.Product));
               end loop;
               if Dlg.Choose ("Detect", "~B~oard ports", Items, Index, 60, "~U~se") then
                  declare
                     P : constant Board_Port := Ports (Index);
                  begin
                     if To_String (P.Role) = "jtag" then
                        D.Set_Value (Port_Id, (if Count ("jtag") = 1 then "" else To_String (P.Path)));
                     else
                        D.Set_Value (Con_Id, (if Count ("uart") = 1 then "uart" else To_String (P.Path)));
                     end if;
                  end;
               end if;
            end;
         end if;
      end loop;
      if Code = 1 then
         Prj.Set_Port (D.Value (Port_Id));
         Prj.Set_Console (D.Value (Con_Id));
         if Profiles (D.Radio_Value (Prof_Id)).all /= Prj.Profile then
            Prj.Set_Profile (Profiles (D.Radio_Value (Prof_Id)).all);
            Restart_Server;      --  a new profile is a new runtime to index
         end if;
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
      D.Add_Text (2, Row, "{example} {port[_opt]} {profile[_opt]} {gpr} {file} {dir} {root} {tmp}");
      D.Add_Button (W / 2 - 22, Row + 2, 12, "~O~K", 1, Default => True);
      D.Add_Button (W / 2 - 6, Row + 2, 12, "~D~efaults", 2);
      D.Add_Button (W / 2 + 10, Row + 2, 12, "Cancel", Dlg.Cancel_Code);
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
      LSP.Stop;
      Quit := True;
   end Do_Quit;

   --  The Alire menu

   procedure Dependencies_Changed is
   --  New crates mean new source directories: fetch the environment again
   --  and let the language server re-index.
   begin
      Prj.Forget_Environment;
      Restart_Server;
   end Dependencies_Changed;

   function Ask_Crate (Title, Label, Default : String; Spec : out Unbounded_String)
                       return Boolean is
   begin
      Spec := To_Unbounded_String (Default);
      loop
         if not Dlg.Input_Box (Title, Label, Spec, 40) then
            return False;
         end if;
         Spec := To_Unbounded_String
           (Ada.Strings.Fixed.Trim (To_String (Spec), Ada.Strings.Both));
         exit when Alire.Valid_Crate (To_String (Spec));
         Dlg.Message_Box
           ("Alire",
            "Give a crate name, optionally with a version:" & Character'Val (10)
            & "aunit, aunit=24.0.0, aunit^24, aunit>=23");
      end loop;
      return True;
   end Ask_Crate;

   function Subdirectories (Dir : String) return String_List is
      use Ada.Directories;
      S : Search_Type;
      D : Directory_Entry_Type;
      R : String_List;
   begin
      Start_Search (S, Dir, "", [Directory => True, others => False]);
      while More_Entries (S) loop
         Get_Next_Entry (S, D);
         R.Append (Simple_Name (D));
      end loop;
      End_Search (S);
      return R;
   exception
      when others =>
         return R;
   end Subdirectories;

   procedure Enter_Project (Dir : String) is
   begin
      Prj.Detect (Dir);
      Ada.Directories.Set_Directory (Prj.Dir);
      Shown_Context := Ctx_Other;
      if Prj.Main_Source /= "" then
         Open_File (Prj.Main_Source);
      end if;
   end Enter_Project;

   procedure Alr_Fetch is
      Have : constant String := Alire.Find;
   begin
      if Have /= ""
        and then Dlg.Message_Box
          ("Alire",
           "alr is " & Tilde (Have) & Character'Val (10)
           & "Download the latest release from GitHub" & Character'Val (10)
           & "into " & Tilde (Alire.Home_Dir) & " and use that?",
           Dlg.Yes_No) /= Dlg.Ans_Yes
      then
         return;
      end if;
      if Fetch_Alire then
         Dependencies_Changed;
      end if;
   end Alr_Fetch;

   procedure Alr_Search is
      V  : Unbounded_String;
      Ok : Boolean;
   begin
      if not Dlg.Input_Box ("Search Crates", "~T~ext (empty: list every crate)", V, 40)
        or else not Ensure_Alr
      then
         return;
      end if;
      declare
         T : constant String := Ada.Strings.Fixed.Trim (To_String (V), Ada.Strings.Both);
      begin
         Run_Command ((if T = "" then "alr -n search --crates --list"
                       else "alr -n search --crates " & Alire.Quote (T)),
                      Ada.Directories.Current_Directory, "Search crates", Ok,
                      Wait_Key => False, Is_Build => False);
      end;
   end Alr_Search;

   procedure Alr_Get is
      use Ada.Directories;
      D : Dlg.Dialog;
      Crate_Id, Dir_Id : Positive;
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME") else Current_Directory);
   begin
      D.Init ("Get Crate", 64, 11);
      Crate_Id := D.Add_Input (3, 3, 58, "");
      D.Add_Label (2, 2, "~C~rate (name, or name=version)", Crate_Id);
      Dir_Id := D.Add_Input
        (3, 6, 58,
         (if Prj.Kind in Prj.Alire_Crate | Prj.Standalone
          then Containing_Directory (Prj.Dir) else Home));
      D.Add_Label (2, 5, "~I~nto directory", Dir_Id);
      D.Add_Button (16, 8, 12, "~O~K", 1, Default => True);
      D.Add_Button (34, 8, 12, "Cancel", Dlg.Cancel_Code);
      if D.Run /= 1 then
         return;
      end if;
      declare
         Spec  : constant String := Ada.Strings.Fixed.Trim (D.Value (Crate_Id), Ada.Strings.Both);
         Where : constant String := Ada.Strings.Fixed.Trim (D.Value (Dir_Id), Ada.Strings.Both);
         Ok    : Boolean;
      begin
         if not Alire.Valid_Crate (Spec) then
            Dlg.Message_Box ("Alire", "Not a crate name: " & Spec);
            return;
         elsif not Exists (Where) or else Kind (Where) /= Directory then
            Dlg.Message_Box ("Error", "No such directory: " & Where);
            return;
         elsif not Ensure_Alr then
            return;
         end if;
         declare
            Before : constant String_List := Subdirectories (Where);
         begin
            Run_Command ("alr -n get " & Alire.Quote (Spec), Full_Name (Where),
                         "Get crate", Ok, Wait_Key => True, Is_Build => False);
            if not Ok then
               return;
            end if;
            for New_Dir of Subdirectories (Where) loop
               if not Before.Contains (New_Dir) then
                  if Dlg.Message_Box
                       ("Alire", "Open " & New_Dir & " as the project?", Dlg.Yes_No)
                     = Dlg.Ans_Yes
                  then
                     Enter_Project (Compose (Full_Name (Where), New_Dir));
                  end if;
                  return;
               end if;
            end loop;
         end;
      end;
   end Alr_Get;

   procedure Alr_Install is
      Spec : Unbounded_String;
      Ok   : Boolean;
   begin
      if not Ask_Crate ("Install Tool", "~C~rate (goes in $HOME/.alire/bin)",
                        "ada_language_server", Spec)
        or else not Ensure_Alr
      then
         return;
      end if;
      Run_Command ("alr -n install " & Alire.Quote (To_String (Spec)),
                   Ada.Directories.Current_Directory, "Install tool", Ok,
                   Wait_Key => True, Is_Build => False);
      if Ok then
         Restart_Server;           --  it may be the language server
      end if;
   end Alr_Install;

   procedure Alr_Add is
      Spec : Unbounded_String;
      Ok   : Boolean;
   begin
      if not Ask_Crate ("Add Dependency", "~C~rate (name, or name^version)", "", Spec)
        or else not Ensure_Alr
      then
         return;
      end if;
      Run_Command ("alr -n with " & Alire.Quote (To_String (Spec)),
                   Ada.Directories.Containing_Directory (Prj.Manifest),
                   "Add dependency", Ok, Wait_Key => True, Is_Build => False);
      if Ok then
         Dependencies_Changed;
      end if;
   end Alr_Add;

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
         when Cmd_Definition => Go_To_Definition;
         when Cmd_References => Find_References;
         when Cmd_Symbols => Symbol_List;
         when Cmd_Go_Back => Go_Back;
         when Cmd_Rename => Rename;
         when Cmd_Complete => Complete;
         when Cmd_Hover => Hover;
         when Cmd_Diagnostics => Diagnostics_List;
         when Cmd_Opt_Server => Server_Options;
         when Cmd_Check_File =>
            if E.Is_Untitled or else not Is_Ada_Source (E.Path) then
               Dlg.Message_Box ("Information", "Compile works on a saved Ada source file.");
            elsif Save (E) then
               Run_Job (Prj.Act_Check, "Compiling", Ok, Wait_Key => True, Is_Build => False,
                        With_Env => True);
            end if;
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

         when Cmd_Alr_Search => Alr_Search;
         when Cmd_Alr_Get => Alr_Get;
         when Cmd_Alr_Install => Alr_Install;
         when Cmd_Alr_Add => Alr_Add;
         when Cmd_Alr_Deps => Run_Job (Prj.Act_Alr_Deps, "alr with", Ok, False, False);
         when Cmd_Alr_Update =>
            Run_Job (Prj.Act_Alr_Update, "alr update", Ok, False, False);
            if Ok then
               Dependencies_Changed;
            end if;
         when Cmd_Alr_Show => Run_Job (Prj.Act_Alr_Show, "alr show", Ok, False, False);
         when Cmd_Alr_Fetch => Alr_Fetch;
         when Cmd_Setup_Toolchain => Setup_Toolchain (Ok);

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
                  elsif C then return Cmd_Hover; end if;
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
                  elsif A then return Cmd_Check_File; end if;
               when F12 =>
                  if Plain then return Cmd_Definition;
                  elsif S then return Cmd_References;
                  elsif C then return Cmd_Symbols;
                  elsif A then return Cmd_Go_Back; end if;
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
      elsif Is_Ctrl (E, ' ') then return Cmd_Complete;
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
      Alire.Use_Found;          --  none: offered when something needs it
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
         LSP.Poll;
         Sync_Documents (Force => False);
         Apply_Diagnostics;
         Redraw;
         --  Wake up now and then while the language server has things to
         --  say or a start is due; otherwise sleep until a key.
         E := Get ((if LSP.Is_Running
                       or else (Server_Wanted and then To_String (Tried_For) /= Project_Key)
                    then 150 else -1));
         begin
            if E.Kind = None then
               Start_Server;
            else
               Last_Input := Ada.Calendar.Clock;
            end if;
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

      LSP.Stop;
      Term.Stop;
   exception
      when others =>
         LSP.Stop;
         Term.Stop;
         raise;
   end Run;

end Turbo.App;
