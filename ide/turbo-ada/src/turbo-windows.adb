with Turbo.Screen;

package body Turbo.Windows is

   use Turbo.Screen;

   function Interior (W : Window'Class) return Rect is
     ((W.Bounds.X + 1, W.Bounds.Y + 1, W.Bounds.W - 2, W.Bounds.H - 2));

   function Hit (W : Window'Class; X, Y : Integer) return Hit_Kind is
      B : constant Rect := W.Bounds;
      Right  : constant Integer := B.X + B.W - 1;
      Bottom : constant Integer := B.Y + B.H - 1;
   begin
      if X < B.X or else X > Right or else Y < B.Y or else Y > Bottom then
         return Outside;
      elsif Y = B.Y then
         if X in B.X + 2 .. B.X + 4 then
            return Close_Box;
         elsif X in Right - 4 .. Right - 2 then
            return Zoom_Box;
         end if;
         return Title_Bar;
      elsif Y = Bottom and then X >= Right - 1 then
         return Resize_Corner;
      elsif X = Right and then Y > B.Y and then Y < Bottom then
         if Y = B.Y + 1 then
            return V_Scroll_Up;
         elsif Y = Bottom - 1 then
            return V_Scroll_Down;
         elsif Y < B.Y + B.H / 2 then
            return V_Scroll_Page_Up;
         else
            return V_Scroll_Page_Down;
         end if;
      elsif Y = Bottom then
         --  The horizontal bar starts after the indicator (see Draw_Frame).
         declare
            Bar_Left : constant Integer := B.X + 15;
         begin
            if X = Bar_Left then
               return H_Scroll_Left;
            elsif X = Right - 2 then
               return H_Scroll_Right;
            elsif X > Bar_Left and then X < Right - 2 then
               return (if X < (Bar_Left + Right) / 2 then H_Scroll_Page_Left
                       else H_Scroll_Page_Right);
            end if;
         end;
         return Border;
      elsif X = B.X then
         return Border;
      end if;
      return Inside;
   end Hit;

   procedure Draw_Frame
     (W        : Window'Class;
      Active   : Boolean;
      Colors   : Frame_Colors;
      V_Pos, V_Total, V_Page : Natural := 0;
      H_Pos, H_Total, H_Page : Natural := 0;
      Indicator : Wide_Wide_String := "")
   is
      B      : constant Rect := W.Bounds;
      Right  : constant Integer := B.X + B.W - 1;
      Bottom : constant Integer := B.Y + B.H - 1;
      FA     : constant Attribute := (if Active then Colors.Frame else Colors.Frame_Idle);
      T      : constant Wide_Wide_String := W.Title;
      Room   : constant Integer := B.W - 18;
      --  Between "[■]" on the left and the number and "[↑]" on the right.
   begin
      Frame (B.X, B.Y, B.W, B.H, FA, Double => Active);

      --  Title, centred, cut to fit between the close and zoom boxes.
      if Room > 2 then
         declare
            Shown : constant Wide_Wide_String :=
              (if T'Length <= Room then T
               else ".." & T (T'Last - Room + 3 .. T'Last));
            Text  : constant Wide_Wide_String := ' ' & Shown & ' ';
            TX    : constant Integer :=
              Integer'Max (B.X + 6, B.X + (B.W - Text'Length) / 2);
         begin
            Put_Wide (TX, B.Y, Text, FA);
         end;
      end if;

      if W.Number in 1 .. 9 then
         Put (Right - 7, B.Y,
              Wide_Wide_Character'Val (Character'Pos ('0') + W.Number), FA);
      end if;

      if not Active then
         return;
      end if;

      --  [■] and [↑] (or [↕] when zoomed)
      Put (B.X + 2, B.Y, "[", FA);
      Put (B.X + 3, B.Y, Square, Colors.Icon);
      Put (B.X + 4, B.Y, "]", FA);
      Put (Right - 4, B.Y, "[", FA);
      Put (Right - 3, B.Y, (if W.Zoomed then Up_Down else Up_Arrow), Colors.Icon);
      Put (Right - 2, B.Y, "]", FA);

      --  Vertical scroll bar on the right edge.
      if V_Total > 0 and then B.H >= 5 then
         declare
            Track : constant Integer := B.H - 4;
            Thumb : Integer;
         begin
            Put (Right, B.Y + 1, Arrow_Up, Colors.Scroll);
            Put (Right, Bottom - 1, Arrow_Dn, Colors.Scroll);
            for Y in B.Y + 2 .. Bottom - 2 loop
               Put (Right, Y, Shade_1, Colors.Scroll);
            end loop;
            if Track > 0 then
               if V_Total <= V_Page or else V_Total <= 1 then
                  Thumb := 0;
               else
                  Thumb := (V_Pos * (Track - 1)) / Integer'Max (V_Total - 1, 1);
               end if;
               Put (Right, B.Y + 2 + Integer'Min (Thumb, Track - 1), Square,
                    Colors.Scroll);
            end if;
         end;
      end if;

      --  Indicator and horizontal scroll bar on the bottom edge.
      if Indicator'Length > 0 then
         Put_Wide (B.X + 2, Bottom, Indicator, FA);
      end if;
      if H_Total > 0 and then B.W >= 24 then
         declare
            Left  : constant Integer := B.X + 15;
            Track : constant Integer := Right - 2 - Left - 1;
            Thumb : Integer;
         begin
            Put (Left, Bottom, Arrow_Lt, Colors.Scroll);
            Put (Right - 2, Bottom, Arrow_Rt, Colors.Scroll);
            for X in Left + 1 .. Right - 3 loop
               Put (X, Bottom, Shade_1, Colors.Scroll);
            end loop;
            if Track > 0 then
               Thumb := (if H_Total <= 1 then 0
                         else (Integer'Min (H_Pos, H_Total) * (Track - 1))
                                / Integer'Max (H_Total - 1, 1));
               Put (Left + 1 + Integer'Min (Thumb, Track - 1), Bottom, Square,
                    Colors.Scroll);
            end if;
         end;
      end if;
      pragma Unreferenced (H_Page);

      --  The resize grip.
      Put (Right - 1, Bottom, H_Single, FA);
      Put (Right, Bottom, BR_Single, FA);
   end Draw_Frame;

   procedure Move_To (W : in out Window'Class; R : Rect) is
      N : Rect := R;
      Desk_W : constant Integer := Screen.Width;
      Desk_Top : constant Integer := 2;
      Desk_Bottom : constant Integer := Screen.Height - 1;
   begin
      N.W := Integer'Max (N.W, W.Min_Width);
      N.H := Integer'Max (N.H, W.Min_Height);
      N.W := Integer'Min (N.W, Desk_W);
      N.H := Integer'Min (N.H, Desk_Bottom - Desk_Top + 1);
      --  Keep the title bar reachable.
      N.Y := Integer'Max (Desk_Top, Integer'Min (N.Y, Desk_Bottom - 1));
      N.X := Integer'Max (2 - N.W + 8, Integer'Min (N.X, Desk_W - 8));
      W.Bounds := N;
   end Move_To;

   procedure Toggle_Zoom (W : in out Window'Class; Desk : Rect) is
   begin
      if W.Zoomed then
         W.Bounds := W.Normal;
         W.Zoomed := False;
      else
         W.Normal := W.Bounds;
         W.Bounds := Desk;
         W.Zoomed := True;
      end if;
   end Toggle_Zoom;

end Turbo.Windows;
