with Turbo.Events;
with Turbo.Screen;
with Turbo.Theme;

package body Turbo.Menus is

   use Turbo.Events;
   use Turbo.Screen;

   type Text is access constant String;
   function "+" (S : String) return Text is (new String'(S));

   type Item is record
      Label : Text;              --  null: a separator line
      Keys  : Text;
      Cmd   : Command;
   end record;

   Sep : constant Item := (null, null, Cmd_None);

   function I (Label : String; Cmd : Command; Keys : String := "") return Item is
     ((+Label, +Keys, Cmd));

   type Item_List is array (Positive range <>) of Item;
   type Item_List_Access is access constant Item_List;

   type Menu is record
      Title : Text;
      Items : Item_List_Access;
   end record;

   System_Items : aliased constant Item_List :=
     [I ("~A~bout...", Cmd_About),
      I ("~R~epaint desktop", Cmd_Repaint)];

   File_Items : aliased constant Item_List :=
     [I ("~N~ew", Cmd_New),
      I ("~O~pen...", Cmd_Open, "F3"),
      I ("~S~ave", Cmd_Save, "F2"),
      I ("Save ~a~s...", Cmd_Save_As),
      I ("Save a~l~l", Cmd_Save_All),
      Sep,
      I ("~C~hange dir...", Cmd_Change_Dir),
      I ("OS s~h~ell", Cmd_Shell),
      Sep,
      I ("E~x~it", Cmd_Quit, "Alt-X")];

   Edit_Items : aliased constant Item_List :=
     [I ("~U~ndo", Cmd_Undo, "Alt-BkSp"),
      I ("~R~edo", Cmd_Redo, "Shift-Alt-BkSp"),
      Sep,
      I ("Cu~t~", Cmd_Cut, "Shift-Del"),
      I ("~C~opy", Cmd_Copy, "Ctrl-Ins"),
      I ("~P~aste", Cmd_Paste, "Shift-Ins"),
      I ("C~l~ear", Cmd_Clear, "Ctrl-Del"),
      I ("~S~elect all", Cmd_Select_All, "Ctrl-A"),
      I ("~F~ormat", Cmd_Format),
      Sep,
      I ("Complete ~w~ord", Cmd_Complete, "Ctrl-Space"),
      I ("S~h~ow clipboard", Cmd_Show_Clipboard)];

   Search_Items : aliased constant Item_List :=
     [I ("~F~ind...", Cmd_Find, "Ctrl-Q F"),
      I ("~R~eplace...", Cmd_Replace, "Ctrl-Q A"),
      I ("~S~earch again", Cmd_Search_Again, "Ctrl-L"),
      Sep,
      I ("~G~o to line number...", Cmd_Goto_Line, "Ctrl-G"),
      I ("~P~revious error", Cmd_Prev_Msg, "Alt-F7"),
      I ("~N~ext error", Cmd_Next_Msg, "Alt-F8"),
      Sep,
      I ("Go to ~d~efinition", Cmd_Definition, "F12"),
      I ("Find ~u~ses", Cmd_References, "Shift-F12"),
      I ("S~y~mbol list...", Cmd_Symbols, "Ctrl-F12"),
      I ("Go ~b~ack", Cmd_Go_Back, "Alt-F12"),
      I ("Rena~m~e symbol...", Cmd_Rename),
      I ("D~i~agnostics", Cmd_Diagnostics),
      Sep,
      I ("Spec/b~o~dy", Cmd_Find_Spec_Body, "Ctrl-F6"),
      I ("Gr~e~p word in project", Cmd_Grep)];

   Run_Items : aliased constant Item_List :=
     [I ("~R~un", Cmd_Run, "Ctrl-F9"),
      I ("~P~rogram reset", Cmd_Program_Reset, "Ctrl-F2"),
      I ("P~a~use output", Cmd_Pause_Output, "Shift-F2"),
      I ("~G~o to cursor", Cmd_Go_To_Cursor, "F4"),
      I ("~T~race into", Cmd_Trace_Into, "F7"),
      I ("~S~tep over", Cmd_Step_Over, "F8"),
      Sep,
      I ("~F~lash", Cmd_Flash, "Shift-F9"),
      I ("~M~onitor", Cmd_Monitor),
      I ("GDB ~c~onsole", Cmd_Debug),
      I ("~K~ill OpenOCD", Cmd_Kill_OpenOCD),
      Sep,
      I ("~U~ser screen", Cmd_User_Screen, "Alt-F5")];

   Debug_Items : aliased constant Item_List :=
     [I ("~I~nspect...", Cmd_Inspect, "Alt-F4"),
      I ("~E~valuate/modify...", Cmd_Evaluate, "Ctrl-F4"),
      I ("~C~all stack...", Cmd_Call_Stack, "Ctrl-F3"),
      Sep,
      I ("~A~dd watch...", Cmd_Add_Watch, "Ctrl-F7"),
      I ("~D~elete watch", Cmd_Delete_Watch),
      I ("Ed~i~t watch...", Cmd_Edit_Watch),
      I ("~R~emove all watches", Cmd_Delete_All_Watches),
      Sep,
      I ("~T~oggle breakpoint", Cmd_Toggle_Breakpoint, "Ctrl-F8"),
      I ("~B~reakpoints...", Cmd_Breakpoints),
      I ("De~l~ete all breakpoints", Cmd_Delete_All_Breakpoints)];

   Compile_Items : aliased constant Item_List :=
     [I ("~C~ompile", Cmd_Check_File, "Alt-F9"),
      I ("~M~ake", Cmd_Make, "F9"),
      I ("~B~uild all", Cmd_Build_All),
      I ("C~l~ean", Cmd_Clean),
      Sep,
      I ("M~e~mory usage", Cmd_Memory),
      I ("~S~tack usage", Cmd_Stack),
      I ("~A~nalyze", Cmd_Analyze),
      I ("~T~est", Cmd_Test)];

   Project_Items : aliased constant Item_List :=
     [I ("~O~pen project...", Cmd_Open_Project),
      I ("~N~ew project...", Cmd_New_Project),
      Sep,
      I ("Edit ~m~anifest (alire.toml)", Cmd_Edit_Manifest),
      I ("Edit G~P~R file", Cmd_Edit_Gpr),
      I ("~B~oard (flash/PSRAM)", Cmd_Board_Config),
      Sep,
      --  Alire (on the bar until the Debug menu needed the room)
      I ("~S~earch crates...", Cmd_Alr_Search),
      I ("~G~et crate...", Cmd_Alr_Get),
      I ("Install ~t~ool...", Cmd_Alr_Install),
      I ("~A~dd dependency...", Cmd_Alr_Add),
      I ("~D~ependencies", Cmd_Alr_Deps),
      I ("~U~pdate dependencies", Cmd_Alr_Update),
      I ("Sho~w~ crate", Cmd_Alr_Show),
      I ("~F~etch Alire (alr)...", Cmd_Alr_Fetch),
      I ("Set up ~E~SP32-S3 toolchain", Cmd_Setup_Toolchain),
      Sep,
      I ("~I~nformation...", Cmd_Project_Info)];

   Options_Items : aliased constant Item_List :=
     [I ("~T~arget (port, profile)...", Cmd_Opt_Target),
      I ("~C~ommands...", Cmd_Opt_Commands),
      I ("~E~ditor...", Cmd_Opt_Editor),
      I ("~L~anguage server...", Cmd_Opt_Server),
      Sep,
      I ("~S~ave options", Cmd_Opt_Save)];

   Window_Items : aliased constant Item_List :=
     [I ("~S~ize/Move", Cmd_Size_Move, "Ctrl-F5"),
      I ("~Z~oom", Cmd_Zoom, "F5"),
      I ("~T~ile", Cmd_Tile),
      I ("C~a~scade", Cmd_Cascade),
      I ("~N~ext", Cmd_Next_Window, "F6"),
      I ("~P~revious", Cmd_Prev_Window, "Shift-F6"),
      I ("~C~lose", Cmd_Close, "Alt-F3"),
      I ("Close a~l~l", Cmd_Close_All),
      Sep,
      I ("~M~essage", Cmd_Message_Window),
      I ("~O~utput", Cmd_Output_Window),
      I ("~W~atch", Cmd_Watch_Window),
      I ("~L~ist...", Cmd_Window_List, "Alt-0")];

   Help_Items : aliased constant Item_List :=
     [I ("~C~ontents", Cmd_Help_Contents, "F1"),
      I ("~K~eyboard", Cmd_Help_Keys),
      I ("~P~roject commands", Cmd_Help_Project),
      I ("~T~opic search", Cmd_Hover, "Ctrl-F1"),
      Sep,
      I ("~A~bout...", Cmd_About)];

   Bar : constant array (Positive range <>) of Menu :=
     [(+(" ~" & Character'Val (0) & "~ "), System_Items'Access),
      (+" ~F~ile ", File_Items'Access),
      (+" ~E~dit ", Edit_Items'Access),
      (+" ~S~earch ", Search_Items'Access),
      (+" ~R~un ", Run_Items'Access),
      (+" ~C~ompile ", Compile_Items'Access),
      (+" ~D~ebug ", Debug_Items'Access),
      (+" ~P~roject ", Project_Items'Access),
      (+" ~O~ptions ", Options_Items'Access),
      (+" ~W~indow ", Window_Items'Access),
      (+" ~H~elp ", Help_Items'Access)];
   --  The system menu's title is the "≡"; NUL stands in for it here and is
   --  drawn specially.

   Is_Enabled : Enabled_Func;
   Background : Redraw_Proc;

   procedure Set_Hooks (Enabled : Enabled_Func; Background : Redraw_Proc) is
   begin
      Is_Enabled := Enabled;
      Turbo.Menus.Background := Background;
   end Set_Hooks;

   function Enabled (C : Command) return Boolean is
     (Is_Enabled = null or else Is_Enabled (C));

   function Menu_Count return Positive is (Bar'Length);

   function Title_X (M : Positive) return Integer is
      X : Integer := 2;
   begin
      for K in Bar'First .. M - 1 loop
         X := X + Hot_Length (Bar (K).Title.all);
      end loop;
      return X;
   end Title_X;

   procedure Draw_Title (M : Positive; Selected : Boolean) is
      T  : constant String := Bar (M).Title.all;
      X  : constant Integer := Title_X (M);
      N  : constant Attribute := (if Selected then Theme.Menu_Selected else Theme.Menu_Normal);
      H  : constant Attribute := (if Selected then Theme.Menu_Sel_Hot else Theme.Menu_Hot);
   begin
      if M = Bar'First then
         Put (X, 1, " ", N);
         Put (X + 1, 1, Triple_Bar, N);
         Put (X + 2, 1, " ", N);
      else
         Put_Hot (X, 1, T, N, H);
      end if;
   end Draw_Title;

   procedure Draw_Bar (Selected : Natural := 0) is
   begin
      Fill (1, 1, Width, 1, ' ', Theme.Menu_Normal);
      for M in Bar'Range loop
         Draw_Title (M, M = Selected);
      end loop;
   end Draw_Bar;

   function Menu_For_Alt (Ch : Wide_Wide_Character) return Natural is
   begin
      if Ch = ' ' then
         return Bar'First;
      end if;
      for M in Bar'First + 1 .. Bar'Last loop
         if Wide_Wide_Character'Val (Character'Pos (Hot_Key (Bar (M).Title.all)))
           = Ch
         then
            return M;
         end if;
      end loop;
      return 0;
   end Menu_For_Alt;

   function Menu_At (X : Integer) return Natural is
   begin
      for M in Bar'Range loop
         if X >= Title_X (M)
           and then X < Title_X (M) + Hot_Length (Bar (M).Title.all)
         then
            return M;
         end if;
      end loop;
      return 0;
   end Menu_At;

   function Key_Text (C : Command) return String is
   begin
      for M of Bar loop
         for It of M.Items.all loop
            if It.Label /= null and then It.Cmd = C then
               return It.Keys.all;
            end if;
         end loop;
      end loop;
      return "";
   end Key_Text;

   --  Drop-down geometry

   type Box is record
      X, Y, W, H : Integer;
   end record;

   function Box_Of (M : Positive) return Box is
      Items : constant Item_List := Bar (M).Items.all;
      Label_W, Keys_W : Natural := 0;
      B : Box;
   begin
      for It of Items loop
         if It.Label /= null then
            Label_W := Natural'Max (Label_W, Hot_Length (It.Label.all));
            Keys_W := Natural'Max (Keys_W, It.Keys.all'Length);
         end if;
      end loop;
      B.W := Label_W + (if Keys_W > 0 then Keys_W + 3 else 0) + 4;
      B.H := Items'Length + 2;
      B.X := Integer'Max (1, Integer'Min (Title_X (M) - 1, Width - B.W - 1));
      B.Y := 2;
      return B;
   end Box_Of;

   procedure Draw_Drop (M : Positive; Current : Natural) is
      Items : constant Item_List := Bar (M).Items.all;
      B     : constant Box := Box_Of (M);
   begin
      Fill (B.X, B.Y, B.W, B.H, ' ', Theme.Menu_Normal);
      Frame (B.X, B.Y, B.W, B.H, Theme.Menu_Normal, Double => False);
      Shadow (B.X + B.W, B.Y + 1, 2, B.H);
      Shadow (B.X + 2, B.Y + B.H, B.W, 1);
      for K in Items'Range loop
         declare
            It  : constant Item := Items (K);
            Y   : constant Integer := B.Y + K;
         begin
            if It.Label = null then
               Put (B.X, Y, L_Tee, Theme.Menu_Normal);
               Fill (B.X + 1, Y, B.W - 2, 1, H_Single, Theme.Menu_Normal);
               Put (B.X + B.W - 1, Y, R_Tee, Theme.Menu_Normal);
            else
               declare
                  On  : constant Boolean := Enabled (It.Cmd);
                  Sel : constant Boolean := K = Current;
                  N   : constant Attribute :=
                    (if not On then (if Sel then Dark_Gray / Green else Theme.Menu_Disabled)
                     elsif Sel then Theme.Menu_Selected else Theme.Menu_Normal);
                  H   : constant Attribute :=
                    (if not On then N
                     elsif Sel then Theme.Menu_Sel_Hot else Theme.Menu_Hot);
               begin
                  Fill (B.X + 1, Y, B.W - 2, 1, ' ', N);
                  Put_Hot (B.X + 2, Y, It.Label.all, N, H);
                  Put (B.X + B.W - 2 - It.Keys.all'Length, Y, It.Keys.all, N);
               end;
            end if;
         end;
      end loop;
   end Draw_Drop;

   function First_Item (M : Positive) return Natural is
   begin
      for K in Bar (M).Items'Range loop
         if Bar (M).Items (K).Label /= null then
            return K;
         end if;
      end loop;
      return 0;
   end First_Item;

   function Step (M : Positive; From : Natural; Down : Boolean) return Natural is
      Items : constant Item_List := Bar (M).Items.all;
      K     : Integer := From;
   begin
      for Tries in Items'Range loop
         K := (if Down then K + 1 else K - 1);
         if K > Items'Last then
            K := Items'First;
         elsif K < Items'First then
            K := Items'Last;
         end if;
         if Items (K).Label /= null then
            return K;
         end if;
      end loop;
      return From;
   end Step;

   function Execute (Start : Positive; Open : Boolean;
                     Mouse_Down : Boolean := False) return Command
   is
      Cur      : Positive := Start;
      Is_Open  : Boolean := Open;
      Item_K   : Natural := First_Item (Start);
      Dragging : Boolean := Mouse_Down;
      E        : Event;

      function Choose (K : Natural) return Command is
      begin
         if K /= 0 and then Bar (Cur).Items (K).Label /= null
           and then Enabled (Bar (Cur).Items (K).Cmd)
         then
            return Bar (Cur).Items (K).Cmd;
         end if;
         return Cmd_None;
      end Choose;

      function Item_At (X, Y : Integer) return Natural is
         B : constant Box := Box_Of (Cur);
      begin
         if Is_Open and then X > B.X and then X < B.X + B.W - 1
           and then Y > B.Y and then Y < B.Y + B.H - 1
         then
            return Y - B.Y;
         end if;
         return 0;
      end Item_At;

   begin
      loop
         if Background /= null then
            Background.all;
         end if;
         Draw_Bar (Cur);
         if Is_Open then
            Draw_Drop (Cur, Item_K);
         end if;
         Hide_Cursor;
         Flush;

         E := Events.Get (-1);
         case E.Kind is
            when Resize =>
               Screen.Init;
            when Mouse =>
               declare
                  Over_Bar  : constant Natural := (if E.Y = 1 then Menu_At (E.X) else 0);
                  Over_Item : constant Natural := Item_At (E.X, E.Y);
               begin
                  case E.Action is
                     when Press | Drag =>
                        if E.Action = Press then
                           Dragging := True;
                        end if;
                        if Over_Bar /= 0 then
                           if Over_Bar /= Cur or else not Is_Open then
                              Cur := Over_Bar;
                              Is_Open := True;
                              Item_K := First_Item (Cur);
                           end if;
                        elsif Over_Item /= 0 then
                           if Bar (Cur).Items (Over_Item).Label /= null then
                              Item_K := Over_Item;
                           end if;
                        elsif E.Action = Press then
                           return Cmd_None;      --  a click outside closes
                        end if;
                     when Release =>
                        if Dragging and then Over_Item /= 0 then
                           declare
                              C : constant Command := Choose (Over_Item);
                           begin
                              if C /= Cmd_None then
                                 return C;
                              end if;
                           end;
                        end if;
                        Dragging := False;
                     when others =>
                        null;
                  end case;
               end;
            when Key =>
               if E.Alt and then E.Code = Char_Key then
                  declare
                     M : constant Natural := Menu_For_Alt (E.Ch);
                  begin
                     if M /= 0 then
                        Cur := M;
                        Is_Open := True;
                        Item_K := First_Item (Cur);
                     elsif E.Ch = 'x' then
                        return Cmd_Quit;
                     end if;
                  end;
               else
                  case E.Code is
                     when Escape =>
                        if Is_Open and then not Open then
                           Is_Open := False;
                        else
                           return Cmd_None;
                        end if;
                     when F10 =>
                        return Cmd_None;
                     when Left =>
                        Cur := (if Cur = Bar'First then Bar'Last else Cur - 1);
                        Item_K := First_Item (Cur);
                     when Right =>
                        Cur := (if Cur = Bar'Last then Bar'First else Cur + 1);
                        Item_K := First_Item (Cur);
                     when Down =>
                        if Is_Open then
                           Item_K := Step (Cur, Item_K, True);
                        else
                           Is_Open := True;
                           Item_K := First_Item (Cur);
                        end if;
                     when Up =>
                        if Is_Open then
                           Item_K := Step (Cur, Item_K, False);
                        end if;
                     when Home =>
                        Item_K := First_Item (Cur);
                     when End_Key =>
                        Item_K := Step (Cur, First_Item (Cur), False);
                     when Enter =>
                        if Is_Open then
                           declare
                              C : constant Command := Choose (Item_K);
                           begin
                              if C /= Cmd_None then
                                 return C;
                              end if;
                           end;
                        else
                           Is_Open := True;
                           Item_K := First_Item (Cur);
                        end if;
                     when Char_Key =>
                        if not E.Ctrl then
                           declare
                              Ch : Wide_Wide_Character := E.Ch;
                           begin
                              if Ch in 'A' .. 'Z' then
                                 Ch := Wide_Wide_Character'Val
                                   (Wide_Wide_Character'Pos (Ch) + 32);
                              end if;
                              if Is_Open then
                                 for K in Bar (Cur).Items'Range loop
                                    declare
                                       It : constant Item := Bar (Cur).Items (K);
                                    begin
                                       if It.Label /= null
                                         and then Wide_Wide_Character'Val
                                           (Character'Pos (Hot_Key (It.Label.all))) = Ch
                                       then
                                          Item_K := K;
                                          declare
                                             C : constant Command := Choose (K);
                                          begin
                                             if C /= Cmd_None then
                                                return C;
                                             end if;
                                          end;
                                       end if;
                                    end;
                                 end loop;
                              else
                                 declare
                                    M : constant Natural := Menu_For_Alt (Ch);
                                 begin
                                    if M /= 0 then
                                       Cur := M;
                                       Is_Open := True;
                                       Item_K := First_Item (Cur);
                                    end if;
                                 end;
                              end if;
                           end;
                        end if;
                     when F1 .. F9 | F11 | F12 =>
                        --  A short-cut key closes the menu and still works.
                        Push_Back (E);
                        return Cmd_None;
                     when others =>
                        null;
                  end case;
               end if;
            when others =>
               null;
         end case;
      end loop;
   end Execute;

end Turbo.Menus;
