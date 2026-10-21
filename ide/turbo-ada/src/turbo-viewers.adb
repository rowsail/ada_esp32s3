with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Turbo.Screen;
with Turbo.Theme;

package body Turbo.Viewers is

   use Ada.Strings.Unbounded;
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

   procedure Set_Text (V : in out Viewer; Text : String) is
      From : Positive := Text'First;
   begin
      V.Lines.Clear;
      for I in Text'Range loop
         if Text (I) = Character'Val (10) then
            V.Lines.Append (Decode (Text (From .. I - 1)));
            From := I + 1;
         end if;
      end loop;
      if From <= Text'Last then
         V.Lines.Append (Decode (Text (From .. Text'Last)));
      end if;
      V.Top := 1;
      V.Left := 0;
   end Set_Text;

   function Create (Title : String; Text : String) return Viewer_Access is
      V : constant Viewer_Access := new Viewer;
   begin
      V.Name := To_Unbounded_String (Title);
      V.Set_Text (Text);
      return V;
   end Create;

   overriding function Title (V : Viewer) return Wide_Wide_String is
     (Decode (To_String (V.Name)));

   overriding procedure Draw (V : in out Viewer; Active : Boolean) is
      I : constant Rect := Interior (V);
      N : constant Natural := Natural (V.Lines.Length);
   begin
      Fill (I.X, I.Y, I.W, I.H, ' ', Theme.Msg_Text);
      Set_Clip (I.X, I.Y, I.X + I.W - 1, I.Y + I.H - 1);
      for Row in 0 .. I.H - 1 loop
         exit when V.Top + Row > N;
         declare
            L    : constant Wide_Wide_String := V.Lines (V.Top + Row);
            X    : Integer := I.X + 1 - V.Left;
            A    : Attribute := Theme.Msg_Text;
         begin
            if L'Length >= 2 and then L (L'First .. L'First + 1) = "# " then
               Put_Wide (X, I.Y + Row, L (L'First + 2 .. L'Last), Theme.Help_Heading);
            else
               declare
                  K : Positive := L'First;
               begin
                  while K <= L'Last loop
                     if (L (K) = '{' or else L (K) = '}') and then K < L'Last
                       and then L (K + 1) = L (K)
                     then
                        --  {{ and }} are the braces themselves.
                        Put (X, I.Y + Row, L (K), A);
                        X := X + 1;
                        K := K + 1;
                     elsif L (K) = '{' then
                        A := Theme.Help_Keyword;
                     elsif L (K) = '}' then
                        A := Theme.Msg_Text;
                     else
                        Put (X, I.Y + Row, L (K), A);
                        X := X + 1;
                     end if;
                     K := K + 1;
                  end loop;
               end;
            end if;
         end;
      end loop;
      Reset_Clip;
      Draw_Frame (V, Active, Colors,
                  V_Pos => V.Top - 1, V_Total => Natural'Max (N, 1),
                  V_Page => I.H);
      if Active then
         Hide_Cursor;
      end if;
   end Draw;

   overriding procedure Handle_Event
     (V : in out Viewer; E : Event; Handled : out Boolean)
   is
      I   : constant Rect := Interior (V);
      N   : constant Natural := Natural (V.Lines.Length);
      Max : constant Positive := Positive (Integer'Max (1, N - I.H + 1));
      procedure Scroll (D : Integer) is
      begin
         V.Top := Positive (Integer'Max (1, Integer'Min (V.Top + D, Max)));
      end Scroll;
   begin
      Handled := True;
      if E.Kind = Mouse then
         case E.Action is
            when Wheel_Up => Scroll (-3);
            when Wheel_Down => Scroll (3);
            when Press =>
               case Hit (V, E.X, E.Y) is
                  when V_Scroll_Up => Scroll (-1);
                  when V_Scroll_Down => Scroll (1);
                  when V_Scroll_Page_Up => Scroll (-I.H);
                  when V_Scroll_Page_Down => Scroll (I.H);
                  when others => Handled := False;
               end case;
            when others => Handled := False;
         end case;
         return;
      elsif E.Kind /= Key then
         Handled := False;
         return;
      end if;
      case E.Code is
         when Up => Scroll (-1);
         when Down => Scroll (1);
         when Page_Up => Scroll (-I.H);
         when Page_Down => Scroll (I.H);
         when Home => V.Top := 1;
         when End_Key => V.Top := Max;
         when Left => V.Left := Natural'Max (0, V.Left - 4);
         when Right => V.Left := V.Left + 4;
         when others => Handled := False;
      end case;
   end Handle_Event;

end Turbo.Viewers;
