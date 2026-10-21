with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Containers.Generic_Array_Sort;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Calendar.Formatting;
with Turbo.Desktop;
with Turbo.Events;
with Turbo.Screen;
with Turbo.Theme;

package body Turbo.Dialogs is

   use Ada.Strings.Unbounded;
   use Ada.Strings.Wide_Wide_Unbounded;
   use Turbo.Events;
   use Turbo.Screen;

   type Dialog_Access is access all Dialog'Class;
   Open_Dialogs : array (1 .. 8) of Dialog_Access;
   Open_Count   : Natural := 0;

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

   function Lower (C : Wide_Wide_Character) return Wide_Wide_Character is
     (if C in 'A' .. 'Z'
      then Wide_Wide_Character'Val (Wide_Wide_Character'Pos (C) + 32) else C);

   function Hot (S : String) return Wide_Wide_Character is
     (Wide_Wide_Character'Val (Character'Pos (Hot_Key (S))));

   --  The '|'-separated pieces of a radio label.

   function Piece_Count (S : String) return Positive is
     (1 + Ada.Strings.Fixed.Count (S, "|"));

   function Piece (S : String; N : Positive) return String is
      K     : Positive := 1;
      Start : Positive := S'First;
   begin
      for I in S'Range loop
         if S (I) = '|' then
            if K = N then
               return S (Start .. I - 1);
            end if;
            K := K + 1;
            Start := I + 1;
         end if;
      end loop;
      return S (Start .. S'Last);
   end Piece;

   --  Building

   procedure Init (D : in out Dialog; Title : String; W, H : Positive) is
   begin
      D.Title := To_Unbounded_String (Title);
      D.W := Positive'Min (W, Width);
      D.H := Positive'Min (H, Height);
      D.X := (Width - D.W) / 2 + 1;
      D.Y := Integer'Max (2, (Height - D.H) / 2 + 1);
      D.Controls.Clear;
      D.Focus := 0;
   end Init;

   function Add (D : in out Dialog; C : Control) return Positive is
   begin
      D.Controls.Append (C);
      if D.Focus = 0 and then C.Kind in Input | Check | Radio | Button | List then
         D.Focus := Positive (D.Controls.Length);
      end if;
      return Positive (D.Controls.Length);
   end Add;

   procedure Add_Text (D : in out Dialog; X, Y : Natural; Text : String) is
      C : Control;
      Ignore : Positive;
   begin
      C.Kind := Static;
      C.X := X;
      C.Y := Y;
      C.Text := To_Unbounded_String (Text);
      Ignore := Add (D, C);
   end Add_Text;

   procedure Add_Label
     (D : in out Dialog; X, Y : Natural; Text : String; For_Control : Positive)
   is
      C : Control;
      Ignore : Positive;
   begin
      C.Kind := Label;
      C.X := X;
      C.Y := Y;
      C.Text := To_Unbounded_String (Text);
      C.Target := For_Control;
      Ignore := Add (D, C);
   end Add_Label;

   function Add_Input
     (D : in out Dialog; X, Y : Natural; W : Positive; Value : String)
      return Positive
   is
      C : Control;
   begin
      C.Kind := Input;
      C.X := X;
      C.Y := Y;
      C.W := W;
      C.Value := To_Unbounded_Wide_Wide_String (Decode (Value));
      C.Cur := Length (C.Value) + 1;
      C.Select_All := Length (C.Value) > 0;
      return Add (D, C);
   end Add_Input;

   function Add_Check
     (D : in out Dialog; X, Y : Natural; W : Positive; Label : String;
      Checked : Boolean) return Positive
   is
      C : Control;
   begin
      C.Kind := Check;
      C.X := X;
      C.Y := Y;
      C.W := W;
      C.Text := To_Unbounded_String (Label);
      C.On := Checked;
      return Add (D, C);
   end Add_Check;

   function Add_Radio
     (D : in out Dialog; X, Y : Natural; W : Positive; Labels : String;
      Selected : Positive) return Positive
   is
      C : Control;
   begin
      C.Kind := Radio;
      C.X := X;
      C.Y := Y;
      C.W := W;
      C.H := Piece_Count (Labels);
      C.Text := To_Unbounded_String (Labels);
      C.Cur := Positive'Min (Selected, C.H);
      return Add (D, C);
   end Add_Radio;

   function Add_Button
     (D : in out Dialog; X, Y : Natural; W : Positive; Label : String;
      Code : Integer; Default : Boolean := False) return Positive
   is
      C : Control;
   begin
      C.Kind := Button;
      C.X := X;
      C.Y := Y;
      C.W := W;
      C.Text := To_Unbounded_String (Label);
      C.Code := Code;
      C.Default := Default;
      return Add (D, C);
   end Add_Button;

   procedure Add_Button
     (D : in out Dialog; X, Y : Natural; W : Positive; Label : String;
      Code : Integer; Default : Boolean := False)
   is
      Ignore : constant Positive := Add_Button (D, X, Y, W, Label, Code, Default);
   begin
      null;
   end Add_Button;

   function Add_List
     (D : in out Dialog; X, Y : Natural; W, H : Positive;
      Notify : Boolean := False) return Positive
   is
      C : Control;
   begin
      C.Kind := List;
      C.X := X;
      C.Y := Y;
      C.W := W;
      C.H := H;
      C.Notify := Notify;
      return Add (D, C);
   end Add_List;

   procedure Update (D : in out Dialog; Id : Positive; C : Control) is
   begin
      D.Controls.Replace_Element (Id, C);
   end Update;

   procedure Set_Items (D : in out Dialog; Id : Positive; Items : String_List) is
      C : Control := D.Controls (Id);
   begin
      C.Items := Items;
      C.Cur := 1;
      C.Scroll := 0;
      Update (D, Id, C);
   end Set_Items;

   procedure Keep_List_Visible (C : in out Control) is
   begin
      if C.Cur - 1 < C.Scroll then
         C.Scroll := C.Cur - 1;
      elsif C.Cur - 1 >= C.Scroll + C.H then
         C.Scroll := C.Cur - C.H;
      end if;
   end Keep_List_Visible;

   procedure Set_List_Index (D : in out Dialog; Id : Positive; Index : Natural) is
      C : Control := D.Controls (Id);
   begin
      if Index in 1 .. Natural (C.Items.Length) then
         C.Cur := Index;
         Keep_List_Visible (C);
         Update (D, Id, C);
      end if;
   end Set_List_Index;

   procedure Set_Value (D : in out Dialog; Id : Positive; Value : String) is
      C : Control := D.Controls (Id);
   begin
      if C.Kind = Input then
         C.Value := To_Unbounded_Wide_Wide_String (Decode (Value));
         C.Cur := Length (C.Value) + 1;
         C.Scroll := 0;
         C.Select_All := Length (C.Value) > 0;
      else
         C.Text := To_Unbounded_String (Value);
      end if;
      Update (D, Id, C);
   end Set_Value;

   procedure Focus (D : in out Dialog; Id : Positive) is
   begin
      D.Focus := Id;
   end Focus;

   function Value (D : Dialog; Id : Positive) return String is
     (Encode (To_Wide_Wide_String (D.Controls (Id).Value)));

   function Checked (D : Dialog; Id : Positive) return Boolean is
     (D.Controls (Id).On);

   function Radio_Value (D : Dialog; Id : Positive) return Positive is
     (D.Controls (Id).Cur);

   function List_Index (D : Dialog; Id : Positive) return Natural is
     (if D.Controls (Id).Items.Is_Empty then 0 else D.Controls (Id).Cur);

   function List_Item (D : Dialog; Id : Positive) return String is
     (if List_Index (D, Id) = 0 then ""
      else D.Controls (Id).Items (D.Controls (Id).Cur));

   function Focused (D : Dialog) return Natural is (D.Focus);

   --  Drawing

   procedure Draw_Control (D : Dialog; Id : Positive) is
      C   : constant Control := D.Controls (Id);
      X   : constant Integer := D.X + C.X;
      Y   : constant Integer := D.Y + C.Y;
      Foc : constant Boolean := D.Focus = Id;
   begin
      case C.Kind is
         when Static =>
            declare
               T   : constant String := To_String (C.Text);
               Row : Integer := Y;
               From : Positive := T'First;
            begin
               for I in T'Range loop
                  if T (I) = Character'Val (10) then
                     Put_Wide (X, Row, Decode (T (From .. I - 1)), Theme.Dialog_Text);
                     Row := Row + 1;
                     From := I + 1;
                  end if;
               end loop;
               if From <= T'Last then
                  Put_Wide (X, Row, Decode (T (From .. T'Last)), Theme.Dialog_Text);
               end if;
            end;

         when Label =>
            Put_Hot (X, Y, To_String (C.Text),
                     (if D.Focus = C.Target then Theme.Label_Focused
                      else Theme.Label_Normal),
                     Theme.Label_Hot);

         when Input =>
            declare
               V      : constant Wide_Wide_String := To_Wide_Wide_String (C.Value);
               Inner  : constant Natural := Natural'Max (C.W - 2, 1);
               Shown  : constant Wide_Wide_String :=
                 (if C.Scroll >= V'Length then ""
                  else V (V'First + C.Scroll ..
                          Integer'Min (V'Last, V'First + C.Scroll + Inner - 1)));
            begin
               Fill (X, Y, C.W, 1, ' ', Theme.Input_Normal);
               Put_Wide (X + 1, Y, Shown,
                         (if Foc and then C.Select_All then Theme.Input_Selected
                          else Theme.Input_Normal));
               if C.Scroll > 0 then
                  Put (X, Y, Arrow_Lt, Theme.Input_Arrow);
               end if;
               if V'Length - C.Scroll > Inner then
                  Put (X + C.W - 1, Y, Arrow_Rt, Theme.Input_Arrow);
               end if;
               if Foc then
                  Set_Cursor (X + 1 + (C.Cur - 1 - C.Scroll), Y);
               end if;
            end;

         when Check =>
            Fill (X, Y, C.W, 1, ' ', Theme.Cluster_Normal);
            Put (X + 1, Y, (if C.On then "[X]" else "[ ]"),
                 (if Foc then Theme.Cluster_Focused else Theme.Cluster_Normal));
            Put_Hot (X + 5, Y, To_String (C.Text),
                     (if Foc then Theme.Cluster_Focused else Theme.Cluster_Normal),
                     Theme.Cluster_Hot);
            if Foc then
               Set_Cursor (X + 2, Y);
            end if;

         when Radio =>
            declare
               T : constant String := To_String (C.Text);
            begin
               for K in 1 .. C.H loop
                  declare
                     A : constant Attribute :=
                       (if Foc and then K = C.Cur then Theme.Cluster_Focused
                        else Theme.Cluster_Normal);
                  begin
                     Fill (X, Y + K - 1, C.W, 1, ' ', Theme.Cluster_Normal);
                     Put (X + 1, Y + K - 1, "( )", A);
                     if K = C.Cur then
                        Put (X + 2, Y + K - 1, Bullet, A);
                     end if;
                     Put_Hot (X + 5, Y + K - 1, Piece (T, K), A, Theme.Cluster_Hot);
                  end;
               end loop;
               if Foc then
                  Set_Cursor (X + 2, Y + C.Cur - 1);
               end if;
            end;

         when Button =>
            declare
               T     : constant String := To_String (C.Text);
               Any_Button_Focused : constant Boolean :=
                 D.Focus /= 0 and then D.Controls (D.Focus).Kind = Button;
               A     : constant Attribute :=
                 (if Foc then Theme.Button_Focused
                  elsif C.Default and then not Any_Button_Focused then Theme.Button_Default
                  else Theme.Button_Normal);
               LX    : constant Integer := X + (C.W - Hot_Length (T)) / 2;
            begin
               Fill (X, Y, C.W, 1, ' ', A);
               Put_Hot (LX, Y, T, A, Theme.Button_Hot);
               Put (X + C.W, Y, Lower_Half, Theme.Button_Shadow);
               Fill (X + 1, Y + 1, C.W, 1, Upper_Half, Theme.Button_Shadow);
               if Foc then
                  Hide_Cursor;
               end if;
            end;

         when List =>
            declare
               N : constant Natural := Natural (C.Items.Length);
            begin
               Fill (X, Y, C.W, C.H, ' ', Theme.List_Normal);
               for Row in 0 .. C.H - 1 loop
                  declare
                     K : constant Positive := C.Scroll + Row + 1;
                  begin
                     exit when K > N;
                     declare
                        Item : constant Wide_Wide_String := Decode (C.Items (K));
                        A    : constant Attribute :=
                          (if K = C.Cur then
                             (if Foc then Theme.List_Focused else Theme.List_Selected)
                           else Theme.List_Normal);
                        Room : constant Natural := C.W - 2;
                     begin
                        if K = C.Cur then
                           Fill (X, Y + Row, C.W - 1, 1, ' ', A);
                        end if;
                        Put_Wide (X + 1, Y + Row,
                                  (if Item'Length > Room
                                   then Item (Item'First .. Item'First + Room - 1)
                                   else Item), A);
                     end;
                  end;
               end loop;
               --  Scroll bar.
               Put (X + C.W - 1, Y, Arrow_Up, Theme.List_Divider);
               Put (X + C.W - 1, Y + C.H - 1, Arrow_Dn, Theme.List_Divider);
               for Row in 1 .. C.H - 2 loop
                  Put (X + C.W - 1, Y + Row, Shade_1, Theme.List_Divider);
               end loop;
               if N > 1 and then C.H > 2 then
                  Put (X + C.W - 1,
                       Y + 1 + ((C.Cur - 1) * (C.H - 3)) / (N - 1),
                       Square, Theme.List_Divider);
               end if;
               if Foc then
                  Hide_Cursor;
               end if;
            end;
      end case;
   end Draw_Control;

   procedure Draw_Dialog (D : Dialog) is
      T : constant String := " " & To_String (D.Title) & " ";
   begin
      Fill (D.X, D.Y, D.W, D.H, ' ', Theme.Dialog_Text);
      Frame (D.X, D.Y, D.W, D.H, Theme.Dialog_Frame, Double => True);
      Put (D.X + (D.W - T'Length) / 2, D.Y, T, Theme.Dialog_Frame);
      Put (D.X + 2, D.Y, "[", Theme.Dialog_Frame);
      Put (D.X + 3, D.Y, Square, Theme.Dialog_Icon);
      Put (D.X + 4, D.Y, "]", Theme.Dialog_Frame);
      Shadow (D.X + D.W, D.Y + 1, 2, D.H);
      Shadow (D.X + 2, D.Y + D.H, D.W, 1);
      Hide_Cursor;
      for Id in 1 .. Natural (D.Controls.Length) loop
         if Id /= D.Focus then
            Draw_Control (D, Id);
         end if;
      end loop;
      --  The focused control last: it owns the cursor.
      if D.Focus /= 0 then
         Draw_Control (D, D.Focus);
      end if;
   end Draw_Dialog;

   procedure Draw_All is
   begin
      Desktop.Draw_Background_Only;
      for K in 1 .. Open_Count loop
         Draw_Dialog (Dialog (Open_Dialogs (K).all));
      end loop;
   end Draw_All;

   --  Behaviour

   function Focusable (C : Control) return Boolean is
     (C.Kind in Input | Check | Radio | Button | List);

   procedure Move_Focus (D : in out Dialog; Forward : Boolean) is
      N : constant Natural := Natural (D.Controls.Length);
      K : Natural := D.Focus;
   begin
      for Tries in 1 .. N loop
         if Forward then
            K := (if K >= N then 1 else K + 1);
         else
            K := (if K <= 1 then N else K - 1);
         end if;
         if Focusable (D.Controls (K)) then
            D.Focus := K;
            return;
         end if;
      end loop;
   end Move_Focus;

   function Default_Code (D : Dialog; Found : out Boolean) return Integer is
   begin
      for C of D.Controls loop
         if C.Kind = Button and then C.Default then
            Found := True;
            return C.Code;
         end if;
      end loop;
      Found := False;
      return 0;
   end Default_Code;

   procedure Input_Key (C : in out Control; E : Event) is
      V : Unbounded_Wide_Wide_String renames C.Value;
   begin
      if E.Kind = Paste then
         declare
            P   : constant Wide_Wide_String := To_Wide_Wide_String (E.Text);
            Cut : Natural := P'Last;
         begin
            for I in P'Range loop
               if P (I) = Wide_Wide_Character'Val (10) then
                  Cut := I - 1;
                  exit;
               end if;
            end loop;
            if C.Select_All then
               V := Null_Unbounded_Wide_Wide_String;
               C.Cur := 1;
               C.Select_All := False;
            end if;
            Insert (V, C.Cur, P (P'First .. Cut));
            C.Cur := C.Cur + (Cut - P'First + 1);
         end;
      else
         case E.Code is
            when Left =>
               C.Select_All := False;
               if C.Cur > 1 then
                  C.Cur := C.Cur - 1;
               end if;
            when Right =>
               C.Select_All := False;
               if C.Cur <= Length (V) then
                  C.Cur := C.Cur + 1;
               end if;
            when Home =>
               C.Select_All := False;
               C.Cur := 1;
            when End_Key =>
               C.Select_All := False;
               C.Cur := Length (V) + 1;
            when Backspace =>
               if C.Select_All then
                  V := Null_Unbounded_Wide_Wide_String;
                  C.Cur := 1;
               elsif C.Cur > 1 then
                  Delete (V, C.Cur - 1, C.Cur - 1);
                  C.Cur := C.Cur - 1;
               end if;
               C.Select_All := False;
            when Delete =>
               if C.Select_All then
                  V := Null_Unbounded_Wide_Wide_String;
                  C.Cur := 1;
               elsif C.Cur <= Length (V) then
                  Delete (V, C.Cur, C.Cur);
               end if;
               C.Select_All := False;
            when Char_Key =>
               if E.Ctrl and then E.Ch = 'y' then
                  V := Null_Unbounded_Wide_Wide_String;
                  C.Cur := 1;
                  C.Select_All := False;
               elsif Is_Plain_Char (E) then
                  if C.Select_All then
                     V := Null_Unbounded_Wide_Wide_String;
                     C.Cur := 1;
                     C.Select_All := False;
                  end if;
                  Insert (V, C.Cur, (1 => E.Ch));
                  C.Cur := C.Cur + 1;
               end if;
            when others =>
               null;
         end case;
      end if;
      --  Keep the cursor inside the visible part.
      declare
         Inner : constant Positive := Positive'Max (C.W - 2, 1);
      begin
         if C.Cur - 1 < C.Scroll then
            C.Scroll := C.Cur - 1;
         elsif C.Cur - 1 - C.Scroll >= Inner then
            C.Scroll := C.Cur - Inner;
         end if;
      end;
   end Input_Key;

   function List_Key (C : in out Control; E : Event) return Boolean is
   --  True when the choice moved.
      N   : constant Natural := Natural (C.Items.Length);
      Old : constant Positive := C.Cur;
   begin
      if N = 0 then
         return False;
      end if;
      case E.Code is
         when Up => C.Cur := Positive'Max (1, C.Cur - 1);
         when Down => C.Cur := Positive'Min (N, C.Cur + 1);
         when Page_Up => C.Cur := Positive'Max (1, C.Cur - C.H);
         when Page_Down => C.Cur := Positive'Min (N, C.Cur + C.H);
         when Home => C.Cur := 1;
         when End_Key => C.Cur := N;
         when Char_Key =>
            --  Incremental search: the letters typed within a second of
            --  each other make a prefix, and the first item with that
            --  prefix is chosen.
            if Is_Plain_Char (E) then
               declare
                  Now : constant Duration := Ada.Calendar.Seconds (Ada.Calendar.Clock);
               begin
                  if Now - C.Typed_At > 1.0 or else Now < C.Typed_At then
                     C.Value := Null_Unbounded_Wide_Wide_String;
                  end if;
                  C.Typed_At := Now;
                  Append (C.Value, Lower (E.Ch));
                  declare
                     P : constant Wide_Wide_String := To_Wide_Wide_String (C.Value);
                  begin
                     for K in 1 .. N loop
                        declare
                           Item : constant Wide_Wide_String := Decode (C.Items (K));
                           Low  : Wide_Wide_String := Item;
                        begin
                           for I in Low'Range loop
                              Low (I) := Lower (Low (I));
                           end loop;
                           if Low'Length >= P'Length
                             and then Low (Low'First .. Low'First + P'Length - 1) = P
                           then
                              C.Cur := K;
                              exit;
                           end if;
                        end;
                     end loop;
                  end;
               end;
            end if;
         when others => null;
      end case;
      Keep_List_Visible (C);
      return C.Cur /= Old;
   end List_Key;

   function Hot_Target (D : Dialog; Ch : Wide_Wide_Character;
                        Radio_Item : out Natural) return Natural is
   --  The control a hot letter belongs to (and, for a radio cluster, which
   --  of its items).
   begin
      Radio_Item := 0;
      for Id in 1 .. Natural (D.Controls.Length) loop
         declare
            C : constant Control := D.Controls (Id);
         begin
            case C.Kind is
               when Button | Check =>
                  if Hot (To_String (C.Text)) = Ch then
                     return Id;
                  end if;
               when Label =>
                  if Hot (To_String (C.Text)) = Ch then
                     return C.Target;
                  end if;
               when Radio =>
                  for K in 1 .. C.H loop
                     if Hot (Piece (To_String (C.Text), K)) = Ch then
                        Radio_Item := K;
                        return Id;
                     end if;
                  end loop;
               when others =>
                  null;
            end case;
         end;
      end loop;
      return 0;
   end Hot_Target;

   function Control_At (D : Dialog; X, Y : Integer) return Natural is
   begin
      for Id in reverse 1 .. Natural (D.Controls.Length) loop
         declare
            C  : constant Control := D.Controls (Id);
            CX : constant Integer := D.X + C.X;
            CY : constant Integer := D.Y + C.Y;
         begin
            if Focusable (C) and then X >= CX and then X < CX + C.W
              and then Y >= CY and then Y < CY + C.H
            then
               return Id;
            end if;
         end;
      end loop;
      return 0;
   end Control_At;

   function Run (D : in out Dialog) return Integer is
      E      : Event;
      Result : Integer;
      Done   : Boolean := False;

      procedure Finish (Code : Integer) is
      begin
         Result := Code;
         Done := True;
      end Finish;

      procedure Activate (Id : Positive; Radio_Item : Natural := 0) is
         C : Control := D.Controls (Id);
      begin
         D.Focus := Id;
         case C.Kind is
            when Button =>
               Finish (C.Code);
            when Check =>
               C.On := not C.On;
            when Radio =>
               if Radio_Item /= 0 then
                  C.Cur := Radio_Item;
               end if;
            when others =>
               null;
         end case;
         Update (D, Id, C);
      end Activate;

   begin
      Open_Count := Open_Count + 1;
      Open_Dialogs (Open_Count) := D'Unchecked_Access;
      Result := Cancel_Code;

      while not Done loop
         Draw_All;
         Flush;
         E := Get (-1);

         case E.Kind is
            when Resize =>
               Screen.Init;
               D.X := (Width - D.W) / 2 + 1;
               D.Y := Integer'Max (2, (Height - D.H) / 2 + 1);

            when Paste =>
               if D.Focus /= 0 and then D.Controls (D.Focus).Kind = Input then
                  declare
                     C : Control := D.Controls (D.Focus);
                  begin
                     Input_Key (C, E);
                     Update (D, D.Focus, C);
                  end;
               end if;

            when Mouse =>
               if E.Action = Press then
                  if E.Y = D.Y and then E.X in D.X + 2 .. D.X + 4 then
                     Finish (Cancel_Code);
                  else
                     declare
                        Id : constant Natural := Control_At (D, E.X, E.Y);
                     begin
                        if Id /= 0 then
                           declare
                              C : Control := D.Controls (Id);
                           begin
                              D.Focus := Id;
                              case C.Kind is
                                 when Button | Check =>
                                    Activate (Id);
                                 when Radio =>
                                    Activate (Id, E.Y - (D.Y + C.Y) + 1);
                                 when Input =>
                                    C.Select_All := False;
                                    C.Cur := Positive'Min
                                      (Length (C.Value) + 1,
                                       Positive'Max (1, E.X - (D.X + C.X) + C.Scroll));
                                    Update (D, Id, C);
                                 when List =>
                                    if E.X = D.X + C.X + C.W - 1 then
                                       --  The scroll bar.
                                       declare
                                          Dummy : Boolean;
                                          K : Event;
                                       begin
                                          K.Kind := Key;
                                          K.Code :=
                                            (if E.Y = D.Y + C.Y then Up
                                             elsif E.Y = D.Y + C.Y + C.H - 1 then Down
                                             elsif E.Y < D.Y + C.Y + C.H / 2 then Page_Up
                                             else Page_Down);
                                          Dummy := List_Key (C, K);
                                          Update (D, Id, C);
                                       end;
                                    else
                                       declare
                                          K : constant Integer :=
                                            C.Scroll + (E.Y - (D.Y + C.Y)) + 1;
                                          Now : constant Duration :=
                                            Ada.Calendar.Seconds (Ada.Calendar.Clock);
                                       begin
                                          if K <= Natural (C.Items.Length) then
                                             if K = D.Last_Click_Item
                                               and then Now - D.Last_Click_Time < 0.4
                                             then
                                                Finish (List_Activated);
                                             elsif K /= C.Cur then
                                                C.Cur := K;
                                                Update (D, Id, C);
                                                if C.Notify then
                                                   Finish (List_Changed);
                                                end if;
                                             end if;
                                             D.Last_Click_Item := K;
                                             D.Last_Click_Time := Now;
                                          end if;
                                       end;
                                    end if;
                                 when others =>
                                    null;
                              end case;
                           end;
                        end if;
                     end;
                  end if;
               elsif E.Action in Wheel_Up | Wheel_Down
                 and then D.Focus /= 0 and then D.Controls (D.Focus).Kind = List
               then
                  declare
                     C : Control := D.Controls (D.Focus);
                     K : Event;
                  begin
                     K.Kind := Key;
                     K.Code := (if E.Action = Wheel_Up then Up else Down);
                     if List_Key (C, K) then
                        Update (D, D.Focus, C);
                        if C.Notify then
                           Finish (List_Changed);
                        end if;
                     end if;
                  end;
               end if;

            when Key =>
               declare
                  In_Input : constant Boolean :=
                    D.Focus /= 0 and then D.Controls (D.Focus).Kind = Input;
                  Radio_Item : Natural;
                  Target     : Natural := 0;
                  In_List : constant Boolean :=
                    D.Focus /= 0 and then D.Controls (D.Focus).Kind = List;
               begin
                  if E.Code = Char_Key and then not E.Ctrl
                    and then (E.Alt or else not (In_Input or else In_List))
                  then
                     Target := Hot_Target (D, Lower (E.Ch), Radio_Item);
                  end if;

                  if Target /= 0 then
                     Activate (Target, Radio_Item);
                  elsif E.Code = Escape then
                     Finish (Cancel_Code);
                  elsif E.Code = Tab then
                     Move_Focus (D, Forward => not E.Shift);
                  elsif E.Code = Enter then
                     if D.Focus /= 0 and then D.Controls (D.Focus).Kind = Button then
                        Finish (D.Controls (D.Focus).Code);
                     elsif D.Focus /= 0 and then D.Controls (D.Focus).Kind = List then
                        Finish (List_Activated);
                     else
                        declare
                           Found : Boolean;
                           Code  : constant Integer := Default_Code (D, Found);
                        begin
                           if Found then
                              Finish (Code);
                           end if;
                        end;
                     end if;
                  elsif D.Focus /= 0 then
                     declare
                        C : Control := D.Controls (D.Focus);
                     begin
                        case C.Kind is
                           when Input =>
                              if E.Code in Up | Down then
                                 Move_Focus (D, Forward => E.Code = Down);
                              else
                                 Input_Key (C, E);
                              end if;
                           when Check =>
                              if E.Code = Char_Key and then E.Ch = ' ' then
                                 C.On := not C.On;
                              elsif E.Code in Up | Left then
                                 Move_Focus (D, False);
                              elsif E.Code in Down | Right then
                                 Move_Focus (D, True);
                              end if;
                           when Radio =>
                              if E.Code in Up | Left then
                                 C.Cur := (if C.Cur = 1 then C.H else C.Cur - 1);
                              elsif E.Code in Down | Right then
                                 C.Cur := (if C.Cur = C.H then 1 else C.Cur + 1);
                              end if;
                           when Button =>
                              if E.Code = Char_Key and then E.Ch = ' ' then
                                 Finish (C.Code);
                              elsif E.Code in Left | Up then
                                 Move_Focus (D, False);
                              elsif E.Code in Right | Down then
                                 Move_Focus (D, True);
                              end if;
                           when List =>
                              if List_Key (C, E) and then C.Notify then
                                 Update (D, D.Focus, C);
                                 Finish (List_Changed);
                              end if;
                           when others =>
                              null;
                        end case;
                        if not Done or else C.Kind = List then
                           Update (D, D.Focus, C);
                        end if;
                     end;
                  end if;
               end;

            when None =>
               null;
         end case;
      end loop;

      Open_Count := Open_Count - 1;
      return Result;
   end Run;

   --  Stock dialogs

   function Message_Box
     (Title, Text : String; Kind : Buttons := OK_Only) return Answer
   is
      D       : Dialog;
      Lines   : Natural := 1;
      Longest : Natural := 0;
      Run_Len : Natural := 0;
      Labels  : constant String :=
        (case Kind is
            when OK_Only       => "~O~K",
            when OK_Cancel     => "~O~K|Cancel",
            when Yes_No        => "~Y~es|~N~o",
            when Yes_No_Cancel => "~Y~es|~N~o|Cancel");
      N_Btn   : constant Positive := Piece_Count (Labels);
      Btn_W   : constant := 10;
   begin
      for C of Text loop
         if C = Character'Val (10) then
            Lines := Lines + 1;
            Run_Len := 0;
         else
            Run_Len := Run_Len + 1;
            Longest := Natural'Max (Longest, Run_Len);
         end if;
      end loop;
      declare
         W : constant Positive :=
           Positive'Max (Longest + 6, Positive'Max (N_Btn * (Btn_W + 2) + 6, 34));
         H : constant Positive := Lines + 6;
      begin
         Init (D, Title, W, H);
         Add_Text (D, 3, 2, Text);
         for K in 1 .. N_Btn loop
            declare
               P    : constant String := Piece (Labels, K);
               Code : constant Integer :=
                 (if P = "~O~K" then Answer'Pos (Ans_OK)
                  elsif P = "~Y~es" then Answer'Pos (Ans_Yes)
                  elsif P = "~N~o" then Answer'Pos (Ans_No)
                  else Answer'Pos (Ans_Cancel));
               X0   : constant Natural := (W - N_Btn * (Btn_W + 2)) / 2;
            begin
               Add_Button (D, X0 + (K - 1) * (Btn_W + 2), H - 3, Btn_W, P, Code,
                           Default => K = 1);
            end;
         end loop;
         declare
            Code : constant Integer := Run (D);
         begin
            if Code = Cancel_Code then
               return (if Kind = Yes_No then Ans_No else Ans_Cancel);
            end if;
            return Answer'Val (Code);
         end;
      end;
   end Message_Box;

   procedure Message_Box (Title, Text : String) is
      Ignore : constant Answer := Message_Box (Title, Text, OK_Only);
   begin
      null;
   end Message_Box;

   function Input_Box
     (Title, Label : String;
      Value        : in out Unbounded_String;
      Width        : Positive := 40) return Boolean
   is
      D  : Dialog;
      Id : Positive;
   begin
      Init (D, Title, Width + 6, 9);
      Id := Add_Input (D, 3, 3, Width, To_String (Value));
      Add_Label (D, 2, 2, Label, Id);
      Add_Button (D, Width / 2 - 9, 5, 10, "~O~K", 1, Default => True);
      Add_Button (D, Width / 2 + 3, 5, 10, "Cancel", Cancel_Code);
      if Run (D) = 1 then
         Value := To_Unbounded_String (Dialogs.Value (D, Id));
         return True;
      end if;
      return False;
   end Input_Box;

   function Find_Dialog (Opt : in out Find_Options; Replace : Boolean)
                         return Boolean
   is
      D : Dialog;
      Text_Id, New_Id, Case_Id, Word_Id, Prompt_Id, Dir_Id, Origin_Id : Positive;
      Y0 : constant Natural := (if Replace then 2 else 0);
      Code : Integer;
   begin
      Init (D, (if Replace then "Replace" else "Find"), 58, (if Replace then 18 else 15));
      Text_Id := Add_Input (D, 17, 2, 38,
                            Encode (To_Wide_Wide_String (Opt.Text)));
      Add_Label (D, 2, 2, "~T~ext to find", Text_Id);
      New_Id := Text_Id;
      if Replace then
         New_Id := Add_Input (D, 17, 4, 38,
                              Encode (To_Wide_Wide_String (Opt.New_Text)));
         Add_Label (D, 2, 4, "~N~ew text", New_Id);
      end if;
      Add_Text (D, 3, 4 + Y0, "Options");
      Case_Id := Add_Check (D, 3, 5 + Y0, 24, "~C~ase sensitive", Opt.Match_Case);
      Word_Id := Add_Check (D, 3, 6 + Y0, 24, "~W~hole words only", Opt.Whole_Word);
      Prompt_Id := Word_Id;
      if Replace then
         Prompt_Id := Add_Check (D, 3, 7 + Y0, 24, "~P~rompt on replace", Opt.Prompt);
      end if;
      Add_Text (D, 31, 4 + Y0, "Direction");
      Dir_Id := Add_Radio (D, 31, 5 + Y0, 24, "Forwar~d~|~B~ackward",
                           (if Opt.Backward then 2 else 1));
      Add_Text (D, 31, 8 + Y0, "Origin");
      Origin_Id := Add_Radio (D, 31, 9 + Y0, 24, "~F~rom cursor|~E~ntire scope",
                              (if Opt.From_Top then 2 else 1));
      if Replace then
         Add_Button (D, 6, 12 + Y0, 12, "~O~K", 1, Default => True);
         Add_Button (D, 22, 12 + Y0, 14, "Change ~a~ll", 2);
         Add_Button (D, 40, 12 + Y0, 12, "Cancel", Cancel_Code);
      else
         Add_Button (D, 14, 12, 12, "~O~K", 1, Default => True);
         Add_Button (D, 32, 12, 12, "Cancel", Cancel_Code);
      end if;
      Focus (D, Text_Id);

      Code := Run (D);
      if Code = Cancel_Code then
         return False;
      end if;
      Opt.Text := To_Unbounded_Wide_Wide_String (Decode (Value (D, Text_Id)));
      if Replace then
         Opt.New_Text := To_Unbounded_Wide_Wide_String (Decode (Value (D, New_Id)));
         Opt.Prompt := Checked (D, Prompt_Id);
      end if;
      Opt.Match_Case := Checked (D, Case_Id);
      Opt.Whole_Word := Checked (D, Word_Id);
      Opt.Backward := Radio_Value (D, Dir_Id) = 2;
      Opt.From_Top := Radio_Value (D, Origin_Id) = 2;
      Opt.Change_All := Code = 2;
      Opt.Replacing := Replace;
      return Length (Opt.Text) > 0;
   end Find_Dialog;

   --  The file dialog

   type Name_Array is array (Positive range <>) of Unbounded_String;

   function Less (A, B : Unbounded_String) return Boolean is
     (Ada.Characters.Handling.To_Lower (To_String (A))
      < Ada.Characters.Handling.To_Lower (To_String (B)));

   procedure Sort is new Ada.Containers.Generic_Array_Sort
     (Positive, Unbounded_String, Name_Array, Less);

   function Has_Wild (S : String) return Boolean is
     (Ada.Strings.Fixed.Index (S, "*") > 0
      or else Ada.Strings.Fixed.Index (S, "?") > 0);

   function Is_Absolute (S : String) return Boolean is
     (S'Length > 0
      and then (S (S'First) = '/' or else S (S'First) = '\'
                or else (S'Length > 1 and then S (S'First + 1) = ':')));

   function Listing (Dir, Pattern : String) return String_List is
      use Ada.Directories;
      Files : Name_Array (1 .. 4096);
      Dirs  : Name_Array (1 .. 4096);
      NF, ND : Natural := 0;
      S : Search_Type;
      Ent : Directory_Entry_Type;
      Result : String_List;
   begin
      begin
         Start_Search (S, Dir, Pattern, [Ordinary_File => True, others => False]);
         while More_Entries (S) and then NF < Files'Last loop
            Get_Next_Entry (S, Ent);
            NF := NF + 1;
            Files (NF) := To_Unbounded_String (Simple_Name (Ent));
         end loop;
         End_Search (S);
      exception
         when others => null;
      end;
      begin
         Start_Search (S, Dir, "", [Directory => True, others => False]);
         while More_Entries (S) and then ND < Dirs'Last loop
            Get_Next_Entry (S, Ent);
            declare
               N : constant String := Simple_Name (Ent);
            begin
               if N /= "." and then N /= ".." then
                  ND := ND + 1;
                  Dirs (ND) := To_Unbounded_String (N);
               end if;
            end;
         end loop;
         End_Search (S);
      exception
         when others => null;
      end;
      Sort (Files (1 .. NF));
      Sort (Dirs (1 .. ND));
      for K in 1 .. NF loop
         Result.Append (To_String (Files (K)));
      end loop;
      for K in 1 .. ND loop
         Result.Append (To_String (Dirs (K)) & "/");
      end loop;
      Result.Append ("../");
      return Result;
   end Listing;

   function Info_Line (Dir, Item : String) return String is
      use Ada.Directories;
   begin
      if Item = "" or else Item (Item'Last) = '/' then
         return Item;
      end if;
      declare
         Full : constant String := Compose (Dir, Item);
         Img  : constant String := File_Size'Image (Size (Full));
      begin
         return Item & "  " & Img (Img'First + 1 .. Img'Last) & " bytes  "
           & Ada.Calendar.Formatting.Image (Modification_Time (Full))
             (1 .. 16);
      end;
   exception
      when others => return Item;
   end Info_Line;

   function Open_File_Dialog
     (Title    : String;
      Start    : String;
      Result   : out Unbounded_String;
      Wildcard : String := "*.ad?") return Boolean
   is
      use Ada.Directories;
      D        : Dialog;
      Name_Id, List_Id, Path_Id, Info_Id : Positive;
      Dir      : Unbounded_String := To_Unbounded_String (Full_Name (Start));
      Pattern  : Unbounded_String := To_Unbounded_String (Wildcard);
      W        : constant Positive := Positive'Min (Width - 4, 66);
      H        : constant Positive := Positive'Min (Height - 2, 21);
      List_H   : constant Positive := Positive'Max (H - 11, 3);

      procedure Refresh is
      begin
         Set_Items (D, List_Id, Listing (To_String (Dir), To_String (Pattern)));
         Set_Value (D, Path_Id, Compose (To_String (Dir), To_String (Pattern)));
         Set_Value (D, Info_Id, Info_Line (To_String (Dir), List_Item (D, List_Id)));
      end Refresh;

      procedure Go_Into (Sub : String) is
         Clean : constant String :=
           (if Sub'Length > 0 and then Sub (Sub'Last) = '/'
            then Sub (Sub'First .. Sub'Last - 1) else Sub);
      begin
         if Clean = ".." then
            Dir := To_Unbounded_String (Containing_Directory (To_String (Dir)));
         elsif Is_Absolute (Clean) then
            Dir := To_Unbounded_String (Full_Name (Clean));
         else
            Dir := To_Unbounded_String (Full_Name (Compose (To_String (Dir), Clean)));
         end if;
         Refresh;
         Set_Value (D, Name_Id, To_String (Pattern));
      exception
         when others => null;
      end Go_Into;

   begin
      Result := Null_Unbounded_String;
      Init (D, Title, W, H);
      Name_Id := Add_Input (D, 3, 3, W - 20, Wildcard);
      Add_Label (D, 2, 2, "~N~ame", Name_Id);
      List_Id := Add_List (D, 3, 6, W - 20, List_H, Notify => True);
      Add_Label (D, 2, 5, "~F~iles", List_Id);
      Add_Button (D, W - 14, 3, 11, "~O~pen", 1, Default => True);
      Add_Button (D, W - 14, 6, 11, "Cancel", Cancel_Code);
      Add_Text (D, 2, H - 4, "");
      Path_Id := Positive (D.Controls.Length);
      Add_Text (D, 2, H - 3, "");
      Info_Id := Positive (D.Controls.Length);
      Focus (D, Name_Id);
      Refresh;

      loop
         declare
            Code : constant Integer := Run (D);
         begin
            if Code = Cancel_Code then
               return False;
            elsif Code = List_Changed then
               declare
                  Item : constant String := List_Item (D, List_Id);
               begin
                  Set_Value (D, Info_Id, Info_Line (To_String (Dir), Item));
                  Set_Value (D, Name_Id, Item);
               end;
            elsif Code = List_Activated then
               declare
                  Item : constant String := List_Item (D, List_Id);
               begin
                  if Item'Length > 0 and then Item (Item'Last) = '/' then
                     Go_Into (Item);
                  elsif Item'Length > 0 then
                     Result := To_Unbounded_String (Compose (To_String (Dir), Item));
                     return True;
                  end if;
               end;
            else
               declare
                  Typed : constant String :=
                    Ada.Strings.Fixed.Trim (Value (D, Name_Id),
                                            Ada.Strings.Both);
                  Full  : constant String :=
                    (if Typed = "" then To_String (Dir)
                     elsif Is_Absolute (Typed) then Typed
                     else To_String (Dir) & "/" & Typed);
               begin
                  if Typed = "" then
                     null;
                  elsif Has_Wild (Typed) then
                     declare
                        Slash : constant Natural :=
                          Ada.Strings.Fixed.Index (Full, "/", Ada.Strings.Backward);
                     begin
                        if Slash > 0 then
                           Dir := To_Unbounded_String
                             (Full_Name (Full (Full'First .. Slash - 1)
                                         & (if Slash = Full'First then "/" else "")));
                           Pattern := To_Unbounded_String (Full (Slash + 1 .. Full'Last));
                        else
                           Pattern := To_Unbounded_String (Typed);
                        end if;
                        Refresh;
                     exception
                        when others => null;
                     end;
                  elsif Exists (Full) and then Kind (Full) = Directory then
                     Go_Into (Full);
                  else
                     Result := To_Unbounded_String (Full);
                     return True;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Open_File_Dialog;

   function Choose
     (Title, Label : String;
      Items        : String_List;
      Index        : in out Positive;
      Width        : Positive := 50;
      Ok_Label     : String := "~O~K") return Boolean
   is
      D       : Dialog;
      List_Id : Positive;
      List_H  : constant Positive :=
        Positive'Max (3, Positive'Min (Natural (Items.Length) + 1, Height - 10));
   begin
      Init (D, Title, Width + 18, List_H + 5);
      List_Id := Add_List (D, 3, 3, Width, List_H);
      Add_Label (D, 2, 2, Label, List_Id);
      Add_Button (D, Width + 5, 3, 11, Ok_Label, 1, Default => True);
      Add_Button (D, Width + 5, 6, 11, "Cancel", Cancel_Code);
      Set_Items (D, List_Id, Items);
      Set_List_Index (D, List_Id, Index);
      Focus (D, List_Id);
      declare
         Code : constant Integer := Run (D);
      begin
         if Code = Cancel_Code or else Items.Is_Empty then
            return False;
         end if;
         Index := Positive'Max (1, List_Index (D, List_Id));
         return True;
      end;
   end Choose;

   procedure Show_Busy (Title, Text : String) is
      W : constant Positive := Positive'Max (Text'Length + 6, Title'Length + 8);
      X : constant Integer := (Width - W) / 2 + 1;
      Y : constant Integer := Height / 2 - 2;
   begin
      Fill (X, Y, W, 5, ' ', Theme.Dialog_Text);
      Frame (X, Y, W, 5, Theme.Dialog_Frame, Double => True);
      Put (X + (W - Title'Length - 2) / 2, Y, " " & Title & " ", Theme.Dialog_Frame);
      Put_Wide (X + 3, Y + 2, Decode (Text), Theme.Dialog_Text);
      Shadow (X + W, Y + 1, 2, 5);
      Shadow (X + 2, Y + 5, W, 1);
      Hide_Cursor;
      Flush;
   end Show_Busy;

end Turbo.Dialogs;
