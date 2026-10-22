with Ada.Containers.Indefinite_Ordered_Sets;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Turbo.Screen;
with Turbo.Theme;

package body Turbo.Project_View is

   use Ada.Strings.Unbounded;
   use Turbo.Events;
   use Turbo.Screen;
   use Turbo.Windows;

   Colors : constant Frame_Colors :=
     (Frame      => Theme.Msg_Frame,
      Frame_Idle => Theme.Msg_Frame_Idle,
      Icon       => Theme.Msg_Icon,
      Scroll     => Theme.Msg_Scroll);

   package Name_Sets is new Ada.Containers.Indefinite_Ordered_Sets (String);

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

   function Create return Project_Window_Access is
     (new Project_Window);

   overriding function Title (W : Project_Window) return Wide_Wide_String is
     (case W.Current is
         when Folders => "Folders",
         when Sources => "Sources");

   procedure Set_Open_Handler (W : in out Project_Window; H : Open_Handler) is
   begin
      W.Open := H;
   end Set_Open_Handler;

   function View (W : Project_Window) return View_Kind is (W.Current);

   --  The tree, as a list of the lines shown

   function Children_Of_Folder (Dir : String; Depth : Natural) return Node_Vectors.Vector is
   --  Folders first, then files, each by name; dot files left out.
      use Ada.Directories;
      Dirs, Files : Name_Sets.Set;
      S : Search_Type;
      E : Directory_Entry_Type;
      R : Node_Vectors.Vector;
   begin
      begin
         Start_Search (S, Dir, "");
         while More_Entries (S) loop
            Get_Next_Entry (S, E);
            declare
               N : constant String := Simple_Name (E);
            begin
               if N'Length > 0 and then N (N'First) /= '.' then
                  case Kind (E) is
                     when Directory     => Dirs.Include (N);
                     when Ordinary_File => Files.Include (N);
                     when others        => null;
                  end case;
               end if;
            end;
         end loop;
         End_Search (S);
      exception
         when others => null;     --  unreadable: shown empty
      end;
      for N of Dirs loop
         R.Append (Node'(Kind => Folder, Text => To_Unbounded_String (N),
                    Path => To_Unbounded_String (Compose (Dir, N)),
                    Depth => Depth, Expanded => False));
      end loop;
      for N of Files loop
         R.Append (Node'(Kind => File, Text => To_Unbounded_String (N),
                    Path => To_Unbounded_String (Compose (Dir, N)),
                    Depth => Depth, Expanded => False));
      end loop;
      return R;
   end Children_Of_Folder;

   function Relative (Path, Dir : String) return String is
     (if Dir'Length > 0 and then Path'Length > Dir'Length + 1
        and then Path (Path'First .. Path'First + Dir'Length - 1) = Dir
        and then Path (Path'First + Dir'Length) in '/' | '\'
      then Path (Path'First + Dir'Length + 1 .. Path'Last)
      else Path);

   function Children_Of_Group (W : Project_Window; Dir : String; Depth : Natural)
     return Node_Vectors.Vector
   is
      R : Node_Vectors.Vector;
   begin
      for G of W.Groups loop
         if To_String (G.Dir) = Dir then
            for F of G.Files loop
               R.Append (Node'(Kind => File, Text => To_Unbounded_String (Relative (F, Dir)),
                          Path => To_Unbounded_String (F), Depth => Depth,
                          Expanded => False));
            end loop;
            exit;
         end if;
      end loop;
      return R;
   end Children_Of_Group;

   procedure Expand (W : in out Project_Window; K : Positive) is
      V : View_State renames W.Views (W.Current);
      N : Node := V.Nodes (K);
      Kids : Node_Vectors.Vector;
   begin
      if N.Expanded or else N.Kind not in Folder | Group then
         return;
      end if;
      Kids := (if N.Kind = Folder then Children_Of_Folder (To_String (N.Path), N.Depth + 1)
               else Children_Of_Group (W, To_String (N.Path), N.Depth + 1));
      N.Expanded := True;
      V.Nodes.Replace_Element (K, N);
      if K = Natural (V.Nodes.Length) then
         V.Nodes.Append_Vector (Kids);
      else
         V.Nodes.Insert_Vector (K + 1, Kids);
      end if;
   end Expand;

   procedure Collapse (W : in out Project_Window; K : Positive) is
      V : View_State renames W.Views (W.Current);
      N : Node := V.Nodes (K);
      Last : Natural := K;
   begin
      if not N.Expanded then
         return;
      end if;
      while Last < Natural (V.Nodes.Length) and then V.Nodes (Last + 1).Depth > N.Depth loop
         Last := Last + 1;
      end loop;
      if Last > K then
         V.Nodes.Delete (K + 1, Ada.Containers.Count_Type (Last - K));
      end if;
      N.Expanded := False;
      V.Nodes.Replace_Element (K, N);
   end Collapse;

   procedure Fill_Folders (W : in out Project_Window; Open_Paths : Name_Sets.Set) is
   --  From the root, opening again the folders that were open.
      V : View_State renames W.Views (Folders);
      K : Positive := 1;
   begin
      V.Nodes := Children_Of_Folder (To_String (W.Root), 0);
      while K <= Natural (V.Nodes.Length) loop
         if V.Nodes (K).Kind = Folder and then Open_Paths.Contains (To_String (V.Nodes (K).Path)) then
            declare
               Saved : constant View_Kind := W.Current;
            begin
               W.Current := Folders;
               Expand (W, K);
               W.Current := Saved;
            end;
         end if;
         K := K + 1;
      end loop;
      if V.Sel > Natural (V.Nodes.Length) then
         V.Sel := Natural (V.Nodes.Length);
      end if;
      if V.Sel = 0 and then not V.Nodes.Is_Empty then
         V.Sel := 1;
      end if;
   end Fill_Folders;

   function Open_Folders (W : Project_Window) return Name_Sets.Set is
      R : Name_Sets.Set;
   begin
      for N of W.Views (Folders).Nodes loop
         if N.Kind = Folder and then N.Expanded then
            R.Include (To_String (N.Path));
         end if;
      end loop;
      return R;
   end Open_Folders;

   procedure Set_Root (W : in out Project_Window; Dir : String) is
   begin
      if To_String (W.Root) = Dir and then not W.Views (Folders).Nodes.Is_Empty then
         return;
      end if;
      W.Root := To_Unbounded_String (Dir);
      W.Views (Folders) := (others => <>);
      Fill_Folders (W, Name_Sets.Empty_Set);
      W.Views (Sources) := (others => <>);
      W.Groups.Clear;
      W.Have_Sources := False;
      W.Want_Sources := W.Current = Sources;
   end Set_Root;

   procedure Set_View (W : in out Project_Window; V : View_Kind) is
   begin
      W.Current := V;
      if V = Sources and then not W.Have_Sources then
         W.Want_Sources := True;
      end if;
   end Set_View;

   function Short (W : Project_Window; Dir : String) return String is
   --  Dir for a heading: from the project directory ("../../libs/x" when
   --  it is a sibling's), or from ~.
      Root : constant String := To_String (W.Root);
      Home : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME")
         then Ada.Environment_Variables.Value ("HOME") else "");
      Up   : Unbounded_String;
      Base : Unbounded_String := To_Unbounded_String (Root);
   begin
      if Dir = Root then
         return ".";
      end if;
      --  Up to two levels up from the project, as an SDK example's
      --  libraries are.
      for Level in 1 .. 3 loop
         declare
            B : constant String := To_String (Base);
         begin
            if Dir'Length > B'Length and then Dir (Dir'First .. Dir'First + B'Length - 1) = B
              and then Dir (Dir'First + B'Length) in '/' | '\'
            then
               return To_String (Up) & Dir (Dir'First + B'Length + 1 .. Dir'Last);
            end if;
            exit when Level = 3 or else B = "/" or else B'Length < 2;
            Base := To_Unbounded_String (Ada.Directories.Containing_Directory (B));
            Append (Up, "../");
         end;
      end loop;
      if Home /= "" and then Dir'Length > Home'Length
        and then Dir (Dir'First .. Dir'First + Home'Length - 1) = Home
      then
         return "~" & Dir (Dir'First + Home'Length .. Dir'Last);
      end if;
      return Dir;
   exception
      when others => return Dir;
   end Short;

   procedure Set_Sources
     (W : in out Project_Window; Groups : Group_Vectors.Vector; Note : String)
   is
      V : View_State renames W.Views (Sources);
   begin
      W.Groups := Groups;
      W.Have_Sources := True;
      V := (others => <>);
      V.Nodes.Append (Node'(Kind => Node_Kind'(Project_View.Note), Text => To_Unbounded_String (Note), Path => <>,
                       Depth => 0, Expanded => False));
      for G of Groups loop
         V.Nodes.Append
           (Node'(Kind => Group,
             Text => To_Unbounded_String
               (To_String (G.Name) & " ("
                & Ada.Containers.Count_Type'Image (G.Files.Length)
                    (2 .. Ada.Containers.Count_Type'Image (G.Files.Length)'Last)
                & ")  " & Short (W, To_String (G.Dir))),
             Path => G.Dir, Depth => 0, Expanded => False));
      end loop;
      --  The root project's own sources open, the rest closed.
      declare
         Saved : constant View_Kind := W.Current;
      begin
         W.Current := Sources;
         if Natural (V.Nodes.Length) >= 2 then
            Expand (W, 2);
            V.Sel := 2;
         else
            V.Sel := 1;
         end if;
         W.Current := Saved;
      end;
   end Set_Sources;

   function Take_Sources_Request (W : in out Project_Window) return Boolean is
   begin
      return R : constant Boolean := W.Want_Sources do
         W.Want_Sources := False;
      end return;
   end Take_Sources_Request;

   procedure Refresh (W : in out Project_Window) is
   begin
      Fill_Folders (W, Open_Folders (W));
      W.Have_Sources := False;
      W.Want_Sources := W.Current = Sources;
   end Refresh;

   --  Drawing

   overriding procedure Draw (W : in out Project_Window; Active : Boolean) is
      I : constant Rect := Interior (W);
      V : View_State renames W.Views (W.Current);
      N : constant Natural := Natural (V.Nodes.Length);
   begin
      Fill (I.X, I.Y, I.W, I.H, ' ', Theme.Msg_Text);
      Set_Clip (I.X, I.Y, I.X + I.W - 1, I.Y + I.H - 1);
      for Row in 0 .. I.H - 1 loop
         declare
            K : constant Positive := V.Top + Row;
         begin
            exit when K > N;
            declare
               Nd : constant Node := V.Nodes (K);
               --  Not literals: the sources are read as Latin-1.
               Open_Mark   : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#25BE#);  --  ▾
               Closed_Mark : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#25B8#);  --  ▸
               Ellipsis    : constant Wide_Wide_Character := Wide_Wide_Character'Val (16#2026#);  --  …
               Mark : constant Wide_Wide_String :=
                 (case Nd.Kind is
                     when Folder | Group => (if Nd.Expanded then Open_Mark else Closed_Mark) & " ",
                     when File           => "  ",
                     when Note           => "");
               Full : constant Wide_Wide_String :=
                 [1 .. 2 * Nd.Depth => ' '] & Mark & Decode (To_String (Nd.Text))
                 & (if Nd.Kind = Folder then "/" else "");
               --  A line wider than the window ends in an ellipsis.
               T : constant Wide_Wide_String :=
                 (if Full'Length <= I.W then Full
                  else Full (Full'First .. Full'First + I.W - 2) & Ellipsis);
               A : constant Attribute :=
                 (if K = V.Sel and then Active then Theme.Msg_Selected
                  elsif Nd.Kind in Note | Group then Theme.Help_Heading
                  else Theme.Msg_Text);
            begin
               if K = V.Sel and then Active then
                  Fill (I.X, I.Y + Row, I.W, 1, ' ', A);
               end if;
               Put_Wide (I.X, I.Y + Row, T, A);
            end;
         end;
      end loop;
      Reset_Clip;
      Draw_Frame (W, Active, Colors,
                  V_Pos => (if V.Sel > 0 then V.Sel - 1 else V.Top - 1),
                  V_Total => Natural'Max (N, 1), V_Page => I.H);
      if Active then
         Hide_Cursor;
      end if;
   end Draw;

   --  Keys and the mouse

   procedure Show_Sel (W : in out Project_Window) is
      I : constant Rect := Interior (W);
      V : View_State renames W.Views (W.Current);
   begin
      if V.Sel = 0 then
         return;
      end if;
      if V.Sel < V.Top then
         V.Top := V.Sel;
      elsif V.Sel >= V.Top + I.H then
         V.Top := V.Sel - I.H + 1;
      end if;
   end Show_Sel;

   procedure Act (W : in out Project_Window) is
   --  Enter: a folder or group opens or closes, a file opens in an editor.
      V : View_State renames W.Views (W.Current);
   begin
      if V.Sel not in 1 .. Natural (V.Nodes.Length) then
         return;
      end if;
      declare
         Nd : constant Node := V.Nodes (V.Sel);
      begin
         case Nd.Kind is
            when Folder | Group =>
               if Nd.Expanded then
                  Collapse (W, V.Sel);
               else
                  Expand (W, V.Sel);
               end if;
            when File =>
               if W.Open /= null then
                  W.Open (To_String (Nd.Path));
               end if;
            when Note =>
               null;
         end case;
      end;
   end Act;

   overriding procedure Handle_Event
     (W : in out Project_Window; E : Event; Handled : out Boolean)
   is
      I : constant Rect := Interior (W);
      V : View_State renames W.Views (W.Current);
      N : constant Natural := Natural (V.Nodes.Length);

      procedure Select_Line (K : Integer) is
      begin
         if N > 0 then
            V.Sel := Natural (Integer'Max (1, Integer'Min (K, N)));
            Show_Sel (W);
         end if;
      end Select_Line;

      procedure To_Parent is
      begin
         if V.Sel in 1 .. N and then V.Nodes (V.Sel).Depth > 0 then
            for K in reverse 1 .. V.Sel - 1 loop
               if V.Nodes (K).Depth < V.Nodes (V.Sel).Depth then
                  Select_Line (K);
                  return;
               end if;
            end loop;
         end if;
      end To_Parent;
   begin
      Handled := True;
      if E.Kind = Mouse then
         case E.Action is
            when Wheel_Up =>
               V.Top := Positive (Integer'Max (1, V.Top - 3));
            when Wheel_Down =>
               V.Top := Positive (Integer'Max (1, Integer'Min (V.Top + 3, N - I.H + 1)));
            when Press =>
               case Hit (W, E.X, E.Y) is
                  when Inside =>
                     declare
                        K : constant Integer := V.Top + (E.Y - I.Y);
                     begin
                        if K = V.Sel then
                           Act (W);
                        elsif K in 1 .. N then
                           Select_Line (K);
                        end if;
                     end;
                  when V_Scroll_Up => Select_Line (V.Sel - 1);
                  when V_Scroll_Down => Select_Line (V.Sel + 1);
                  when V_Scroll_Page_Up => Select_Line (V.Sel - I.H);
                  when V_Scroll_Page_Down => Select_Line (V.Sel + I.H);
                  when others => Handled := False;
               end case;
            when others =>
               null;
         end case;
         return;
      end if;

      if E.Kind /= Key then
         Handled := False;
         return;
      end if;
      if Is_Ctrl (E, 'r') then
         Refresh (W);
         return;
      end if;
      case E.Code is
         when Up => Select_Line (V.Sel - 1);
         when Down => Select_Line (V.Sel + 1);
         when Page_Up => Select_Line (V.Sel - I.H);
         when Page_Down => Select_Line (V.Sel + I.H);
         when Home => Select_Line (1);
         when End_Key => Select_Line (N);
         when Enter => Act (W);
         when Right =>
            if V.Sel in 1 .. N and then V.Nodes (V.Sel).Kind in Folder | Group
              and then not V.Nodes (V.Sel).Expanded
            then
               Expand (W, V.Sel);
            else
               Select_Line (V.Sel + 1);
            end if;
         when Left =>
            if V.Sel in 1 .. N and then V.Nodes (V.Sel).Expanded then
               Collapse (W, V.Sel);
            else
               To_Parent;
            end if;
         when Tab =>
            Set_View (W, (if W.Current = Folders then Sources else Folders));
         when others => Handled := False;
      end case;
   end Handle_Event;

end Turbo.Project_View;
