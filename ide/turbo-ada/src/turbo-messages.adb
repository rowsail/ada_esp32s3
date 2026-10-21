with Ada.Containers;
with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Turbo.Screen;
with Turbo.Theme;

package body Turbo.Messages is

   use Ada.Strings.Unbounded;
   use Ada.Strings.Wide_Wide_Unbounded;
   use Turbo.Events;
   use Turbo.Screen;
   use Turbo.Windows;

   Colors : constant Frame_Colors :=
     (Frame      => Theme.Msg_Frame,
      Frame_Idle => Theme.Msg_Frame_Idle,
      Icon       => Theme.Msg_Icon,
      Scroll     => Theme.Msg_Scroll);

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

   function Is_Digits (S : String) return Boolean is
     (S'Length > 0 and then (for all C of S => C in '0' .. '9'));

   function Source_Like (File : String) return Boolean is
   --  Only names that look like files a tool would point at.
      use Ada.Characters.Handling;
      Ext : constant String := To_Lower (Ada.Directories.Extension (File));
   begin
      return File'Length > 0
        and then Ada.Strings.Fixed.Index (File, " ") = 0
        and then (Ext = "adb" or else Ext = "ads" or else Ext = "ada"
                  or else Ext = "gpr" or else Ext = "c" or else Ext = "h"
                  or else Ext = "s" or else Ext = "ld" or else Ext = "toml"
                  or else Ext = "adc" or else Ext = "cpp");
   exception
      when others => return False;
   end Source_Like;

   function Parse (Raw : String) return Message is
      use Ada.Strings.Fixed;
      M : Message;
      Start : Positive := Raw'First;
   begin
      M.Text := To_Unbounded_Wide_Wide_String (Decode (Raw));
      if Raw'Length = 0 then
         return M;
      end if;
      --  Skip a Windows drive letter: "C:\x\y.adb:3:1: ...".
      if Raw'Length > 2 and then Raw (Raw'First + 1) = ':' then
         Start := Raw'First + 2;
      end if;
      for I in Start .. Raw'Last loop
         if Raw (I) = ':' and then I > Raw'First then
            declare
               File : constant String := Trim (Raw (Raw'First .. I - 1), Ada.Strings.Both);
               J    : Natural := I + 1;
               K    : Natural;
            begin
               --  file:LINE
               while J <= Raw'Last and then Raw (J) in '0' .. '9' loop
                  J := J + 1;
               end loop;
               if J > I + 1 and then J <= Raw'Last and then Raw (J) = ':'
                 and then Source_Like (File)
               then
                  M.File := To_Unbounded_String (File);
                  M.Line := Natural'Value (Raw (I + 1 .. J - 1));
                  M.Col := 1;
                  --  file:LINE:COL
                  K := J + 1;
                  while K <= Raw'Last and then Raw (K) in '0' .. '9' loop
                     K := K + 1;
                  end loop;
                  if K > J + 1 and then K <= Raw'Last and then Raw (K) = ':'
                    and then Is_Digits (Raw (J + 1 .. K - 1))
                  then
                     M.Col := Natural'Max (1, Natural'Value (Raw (J + 1 .. K - 1)));
                     J := K;
                  end if;
                  declare
                     Rest : constant String :=
                       Ada.Characters.Handling.To_Lower
                         (Trim (Raw (J + 1 .. Raw'Last), Ada.Strings.Left));
                     function Starts (P : String) return Boolean is
                       (Rest'Length >= P'Length
                        and then Rest (Rest'First .. Rest'First + P'Length - 1) = P);
                  begin
                     M.Text := To_Unbounded_Wide_Wide_String
                       (Decode (Trim (Raw (J + 1 .. Raw'Last), Ada.Strings.Left)));
                     if Starts ("warning") or else Starts ("(style)")
                       or else Starts ("medium") or else Starts ("high:")
                     then
                        M.Kind := Warning;
                     elsif Starts ("info") or else Starts ("note")
                       or else Starts ("low:") or else Starts ("instantiated")
                       or else Starts ("in instantiation")
                     then
                        M.Kind := Note;
                     else
                        --  GNAT before 13 printed errors with no "error:".
                        M.Kind := Error;
                     end if;
                  end;
                  return M;
               end if;
            end;
         end if;
      end loop;
      return M;
   end Parse;

   function Create (Title : String := "Message") return Message_Window_Access is
      W : constant Message_Window_Access := new Message_Window;
   begin
      W.Name := To_Unbounded_String (Title);
      return W;
   end Create;

   overriding function Title (W : Message_Window) return Wide_Wide_String is
     (Decode (To_String (W.Name)));

   function Img (N : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Left));

   function To_WW (S : String) return Wide_Wide_String is (Decode (S));

   function Display (M : Message) return Wide_Wide_String is
   begin
      if M.Line = 0 then
         return To_Wide_Wide_String (M.Text);
      end if;
      declare
         Word : constant String :=
           (case M.Kind is
               when Error   => "Error   ",
               when Warning => "Warning ",
               when Note    => "Note    ",
               when others  => "        ");
      begin
         return To_WW (Word & Ada.Directories.Simple_Name (To_String (M.File))
                       & " " & Img (M.Line) & ": ")
           & To_Wide_Wide_String (M.Text);
      end;
   exception
      when others =>
         return To_Wide_Wide_String (M.Text);
   end Display;

   overriding procedure Draw (W : in out Message_Window; Active : Boolean) is
      I : constant Rect := Interior (W);
      N : constant Natural := Natural (W.Items.Length);
   begin
      Fill (I.X, I.Y, I.W, I.H, ' ', Theme.Msg_Text);
      Set_Clip (I.X, I.Y, I.X + I.W - 1, I.Y + I.H - 1);
      for Row in 0 .. I.H - 1 loop
         declare
            K : constant Positive := W.Top + Row;
         begin
            exit when K > N;
            declare
               M : constant Message := W.Items (K);
               T : constant Wide_Wide_String := Display (M);
               A : constant Attribute :=
                 (if K = W.Sel and then Active then Theme.Msg_Selected
                  else (case M.Kind is
                           when Error   => Theme.Msg_Error,
                           when Warning => Theme.Msg_Warning,
                           when Header  => Theme.Help_Heading,
                           when others  => Theme.Msg_Text));
            begin
               if K = W.Sel and then Active then
                  Fill (I.X, I.Y + Row, I.W, 1, ' ', A);
               end if;
               if T'Length > W.Left then
                  Put_Wide (I.X, I.Y + Row, T (T'First + W.Left .. T'Last), A);
               end if;
            end;
         end;
      end loop;
      Reset_Clip;
      Draw_Frame (W, Active, Colors,
                  V_Pos => (if W.Sel > 0 then W.Sel - 1 else W.Top - 1),
                  V_Total => Natural'Max (N, 1), V_Page => I.H,
                  H_Pos => W.Left, H_Total => 200, H_Page => I.W);
      if Active then
         Hide_Cursor;
      end if;
   end Draw;

   procedure Show_Sel (W : in out Message_Window) is
      I : constant Rect := Interior (W);
   begin
      if W.Sel = 0 then
         return;
      end if;
      if W.Sel < W.Top then
         W.Top := W.Sel;
      elsif W.Sel >= W.Top + I.H then
         W.Top := W.Sel - I.H + 1;
      end if;
   end Show_Sel;

   procedure Jump_To (W : in out Message_Window; Focus : Boolean) is
   begin
      if W.Sel in 1 .. Natural (W.Items.Length) and then W.Jump /= null then
         declare
            M : constant Message := W.Items (W.Sel);
         begin
            if M.Line > 0 then
               W.Jump (To_String (M.File), M.Line, Positive'Max (1, M.Col), Focus);
            end if;
         end;
      end if;
   end Jump_To;

   overriding procedure Handle_Event
     (W : in out Message_Window; E : Event; Handled : out Boolean)
   is
      I : constant Rect := Interior (W);
      N : constant Natural := Natural (W.Items.Length);
      procedure Select_Line (K : Integer) is
      begin
         if N > 0 then
            W.Sel := Natural (Integer'Max (1, Integer'Min (K, N)));
            Show_Sel (W);
         end if;
      end Select_Line;
   begin
      Handled := True;
      if E.Kind = Mouse then
         case E.Action is
            when Wheel_Up =>
               W.Top := Positive (Integer'Max (1, W.Top - 3));
            when Wheel_Down =>
               W.Top := Positive (Integer'Max (1, Integer'Min (W.Top + 3, N - I.H + 1)));
            when Press =>
               case Hit (W, E.X, E.Y) is
                  when Inside =>
                     declare
                        K : constant Integer := W.Top + (E.Y - I.Y);
                     begin
                        if K = W.Sel then
                           Jump_To (W, Focus => True);
                        else
                           Select_Line (K);
                           Jump_To (W, Focus => False);
                        end if;
                     end;
                  when V_Scroll_Up => Select_Line (W.Sel - 1);
                  when V_Scroll_Down => Select_Line (W.Sel + 1);
                  when V_Scroll_Page_Up => Select_Line (W.Sel - I.H);
                  when V_Scroll_Page_Down => Select_Line (W.Sel + I.H);
                  when H_Scroll_Left | H_Scroll_Page_Left =>
                     W.Left := Natural'Max (0, W.Left - 8);
                  when H_Scroll_Right | H_Scroll_Page_Right =>
                     W.Left := W.Left + 8;
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
      case E.Code is
         when Up => Select_Line (W.Sel - 1);
         when Down => Select_Line (W.Sel + 1);
         when Page_Up => Select_Line (W.Sel - I.H);
         when Page_Down => Select_Line (W.Sel + I.H);
         when Home => Select_Line (1);
         when End_Key => Select_Line (N);
         when Left => W.Left := Natural'Max (0, W.Left - 8);
         when Right => W.Left := W.Left + 8;
         when Enter => Jump_To (W, Focus => True);
         when Char_Key =>
            if E.Ch = ' ' and then not E.Ctrl and then not E.Alt then
               Jump_To (W, Focus => False);     --  "track": look, stay here
            else
               Handled := False;
            end if;
         when others => Handled := False;
      end case;
   end Handle_Event;

   procedure Clear (W : in out Message_Window) is
   begin
      W.Items.Clear;
      W.Sel := 0;
      W.Top := 1;
      W.Left := 0;
      W.N_Errors := 0;
      W.N_Warn := 0;
   end Clear;

   function Machine_Line (Raw : String; M : out Message) return Boolean is
   --  "@x ..." lines from ./x --machine / esp32-ada --machine.  True when M
   --  is to be shown; protocol and result lines are not.
      use Ada.Strings.Fixed;
      Rest : constant String := Raw (Raw'First + 3 .. Raw'Last);
      Sp   : constant Natural := Index (Rest, " ");
      Verb : constant String := (if Sp = 0 then Rest else Rest (Rest'First .. Sp - 1));
      Args : constant String := (if Sp = 0 then "" else Rest (Sp + 1 .. Rest'Last));
   begin
      M := (others => <>);
      if Verb = "stage" then
         declare
            Sp2 : constant Natural := Index (Args, " ");
         begin
            M.Kind := Header;
            M.Text := To_Unbounded_Wide_Wide_String
              (Decode ((if Sp2 = 0 then Args
                        else "[" & Args (Args'First .. Sp2 - 1) & "] "
                             & Args (Sp2 + 1 .. Args'Last))));
         end;
         return True;
      elsif Verb = "diag" then
         declare
            Sp2 : constant Natural := Index (Args, " ");
            Sev : constant String := (if Sp2 = 0 then "error" else Args (Args'First .. Sp2 - 1));
         begin
            M := Parse ((if Sp2 = 0 then Args else Args (Sp2 + 1 .. Args'Last)));
            if M.Line > 0 then
               M.Kind := (if Sev = "warning" or else Sev = "style" then Warning
                          elsif Sev = "info" then Note else Error);
            end if;
         end;
         return True;
      elsif Verb = "artifact" then
         M.Kind := Info;
         M.Text := To_Unbounded_Wide_Wide_String (Decode ("Made " & Args));
         return True;
      end if;
      return False;
   end Machine_Line;

   function Stage_Of (Raw : String) return String is
   begin
      if Raw'Length > 9 and then Raw (Raw'First .. Raw'First + 8) = "@x stage " then
         return Raw (Raw'First + 9 .. Raw'Last);
      end if;
      return "";
   end Stage_Of;

   procedure Add_Line (W : in out Message_Window; Raw : String) is
      M : Message;
   begin
      if Raw'Length > 3 and then Raw (Raw'First .. Raw'First + 2) = "@x " then
         if not Machine_Line (Raw, M) then
            return;
         end if;
      else
         M := Parse (Raw);
      end if;
      case M.Kind is
         when Error => W.N_Errors := W.N_Errors + 1;
         when Warning => W.N_Warn := W.N_Warn + 1;
         when others => null;
      end case;
      W.Items.Append (M);
   end Add_Line;

   procedure Add (W : in out Message_Window; Kind : Msg_Kind; Text : String) is
      M : Message;
   begin
      M.Kind := Kind;
      M.Text := To_Unbounded_Wide_Wide_String (Decode (Text));
      W.Items.Append (M);
   end Add;

   procedure Add_Location
     (W : in out Message_Window; File : String; Line, Col : Positive;
      Text : Wide_Wide_String; Kind : Msg_Kind := Info)
   is
      M : Message;
   begin
      M.Kind := Kind;
      case Kind is
         when Error => W.N_Errors := W.N_Errors + 1;
         when Warning => W.N_Warn := W.N_Warn + 1;
         when others => null;
      end case;
      M.File := To_Unbounded_String (File);
      M.Line := Line;
      M.Col := Col;
      M.Text := To_Unbounded_Wide_Wide_String (Text);
      W.Items.Append (M);
   end Add_Location;

   function Errors (W : Message_Window) return Natural is (W.N_Errors);
   function Warnings (W : Message_Window) return Natural is (W.N_Warn);
   function Line_Count (W : Message_Window) return Natural is
     (Natural (W.Items.Length));

   procedure Set_Jump_Handler (W : in out Message_Window; H : Jump_Handler) is
   begin
      W.Jump := H;
   end Set_Jump_Handler;

   function Step (W : in out Message_Window; Forward : Boolean) return Boolean is
      N : constant Natural := Natural (W.Items.Length);
      K : Integer := W.Sel;
   begin
      loop
         K := (if Forward then K + 1 else K - 1);
         exit when K < 1 or else K > N;
         if W.Items (K).Line > 0 and then W.Items (K).Kind /= Note then
            W.Sel := K;
            Show_Sel (W);
            Jump_To (W, Focus => True);
            return True;
         end if;
      end loop;
      return False;
   end Step;

   function First_Error (W : in out Message_Window) return Boolean is
   begin
      for K in 1 .. Natural (W.Items.Length) loop
         if W.Items (K).Kind = Error and then W.Items (K).Line > 0 then
            W.Sel := K;
            Show_Sel (W);
            Jump_To (W, Focus => False);
            return True;
         end if;
      end loop;
      return False;
   end First_Error;

   procedure Follow_Tail (W : in out Message_Window) is
      I : constant Rect := Interior (W);
      N : constant Natural := Natural (W.Items.Length);
   begin
      if N > I.H then
         W.Top := N - I.H + 1;
      end if;
   end Follow_Tail;

   procedure Set_Title (W : in out Message_Window; Title : String) is
   begin
      W.Name := To_Unbounded_String (Title);
   end Set_Title;

   procedure Keep_Last (W : in out Message_Window; Count : Positive) is
      N    : constant Natural := Natural (W.Items.Length);
      Drop : constant Natural := (if N > Count then N - Count else 0);
   begin
      if Drop > 0 then
         W.Items.Delete_First (Ada.Containers.Count_Type (Drop));
         W.Top := Integer'Max (1, W.Top - Drop);
         W.Sel := (if W.Sel > Drop then W.Sel - Drop elsif W.Sel > 0 then 1 else 0);
      end if;
   end Keep_Last;

end Turbo.Messages;
