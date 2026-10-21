with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Turbo.Screen;
with Turbo.Theme;

package body Turbo.Watches is

   use Turbo.Commands;
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

   function Create return Watch_Window_Access is (new Watch_Window);

   overriding function Title (W : Watch_Window) return Wide_Wide_String is
      pragma Unreferenced (W);
   begin
      return "Watch";
   end Title;

   function Count (W : Watch_Window) return Natural is (Natural (W.Exprs.Length));
   function Expression (W : Watch_Window; K : Positive) return String is (W.Exprs (K));
   function Selected (W : Watch_Window) return Natural is (W.Sel);

   procedure Add (W : in out Watch_Window; Expression : String) is
   begin
      W.Exprs.Append (Expression);
      W.Values.Append ("");
      W.Sel := Count (W);
   end Add;

   procedure Replace (W : in out Watch_Window; K : Positive; Expression : String) is
   begin
      W.Exprs.Replace_Element (K, Expression);
      W.Values.Replace_Element (K, "");
   end Replace;

   procedure Delete (W : in out Watch_Window; K : Positive) is
   begin
      W.Exprs.Delete (K);
      W.Values.Delete (K);
      W.Sel := Natural'Min (W.Sel, Count (W));
      W.Top := Positive'Min (W.Top, Positive'Max (1, Count (W)));
   end Delete;

   procedure Delete_All (W : in out Watch_Window) is
   begin
      W.Exprs.Clear;
      W.Values.Clear;
      W.Sel := 0;
      W.Top := 1;
   end Delete_All;

   procedure Set_Value (W : in out Watch_Window; K : Positive; Value : String) is
      V : String := Value;
   begin
      for C of V loop
         if C = ASCII.LF or else C = ASCII.CR or else C = ASCII.HT then
            C := ' ';
         end if;
      end loop;
      W.Values.Replace_Element (K, V);
   end Set_Value;

   function Take_Request (W : in out Watch_Window) return Command is
      R : constant Command := W.Request;
   begin
      W.Request := Cmd_None;
      return R;
   end Take_Request;

   overriding procedure Draw (W : in out Watch_Window; Active : Boolean) is
      I : constant Rect := Interior (W);
      N : constant Natural := Count (W);
   begin
      Fill (I.X, I.Y, I.W, I.H, ' ', Theme.Msg_Text);
      Set_Clip (I.X, I.Y, I.X + I.W - 1, I.Y + I.H - 1);
      for Row in 0 .. I.H - 1 loop
         declare
            K : constant Positive := W.Top + Row;
         begin
            exit when K > N;
            declare
               T : constant Wide_Wide_String :=
                 Decode (W.Exprs (K) & ": " & W.Values (K));
               A : constant Attribute :=
                 (if K = W.Sel and then Active then Theme.Msg_Selected else Theme.Msg_Text);
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
                  V_Pos => (if W.Sel > 0 then W.Sel - 1 else 0),
                  V_Total => Natural'Max (N, 1), V_Page => I.H,
                  H_Pos => W.Left, H_Total => 200, H_Page => I.W);
      if Active then
         Hide_Cursor;
      end if;
   end Draw;

   overriding procedure Handle_Event
     (W : in out Watch_Window; E : Event; Handled : out Boolean)
   is
      I : constant Rect := Interior (W);
      N : constant Natural := Count (W);
      procedure Select_Line (K : Integer) is
      begin
         if N > 0 then
            W.Sel := Natural (Integer'Max (1, Integer'Min (K, N)));
            if W.Sel < W.Top then
               W.Top := W.Sel;
            elsif W.Sel >= W.Top + I.H then
               W.Top := W.Sel - I.H + 1;
            end if;
         end if;
      end Select_Line;
   begin
      Handled := True;
      if E.Kind = Mouse then
         if E.Action = Press and then Hit (W, E.X, E.Y) = Inside then
            declare
               K : constant Integer := W.Top + (E.Y - I.Y);
            begin
               if K = W.Sel then
                  W.Request := Cmd_Edit_Watch;
               else
                  Select_Line (K);
               end if;
            end;
         elsif E.Action = Wheel_Up then
            Select_Line (W.Sel - 3);
         elsif E.Action = Wheel_Down then
            Select_Line (W.Sel + 3);
         else
            Handled := False;
         end if;
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
         when Enter => W.Request := (if W.Sel = 0 then Cmd_Add_Watch else Cmd_Edit_Watch);
         when Insert => W.Request := Cmd_Add_Watch;
         when Delete =>
            if W.Sel > 0 then
               W.Request := Cmd_Delete_Watch;
            end if;
         when others => Handled := False;
      end case;
   end Handle_Event;

end Turbo.Watches;
