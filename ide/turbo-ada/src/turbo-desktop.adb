with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Turbo.Menus;
with Turbo.Screen;
with Turbo.Settings;
with Turbo.Theme;

package body Turbo.Desktop is

   use Ada.Strings.Unbounded;
   use Turbo.Screen;
   use type Turbo.Commands.Command;

   package Window_Vectors is new Ada.Containers.Vectors (Positive, Window_Access);

   Stack : Window_Vectors.Vector;

   type Item_Array_Access is access Status_Items;
   Items   : Item_Array_Access;
   Message : Unbounded_String;
   Is_Busy : Boolean := False;
   Right   : Unbounded_String;

   function Area return Rect is ((1, 2, Width, Height - 2));

   function Lowest_Free_Number return Natural is
   begin
      for N in 1 .. 9 loop
         if With_Number (N) = null then
            return N;
         end if;
      end loop;
      return 0;
   end Lowest_Free_Number;

   procedure Add (W : Window_Access) is
   begin
      if W.Number = 0 then
         W.Number := Lowest_Free_Number;
      end if;
      Stack.Append (W);
   end Add;

   procedure Remove (W : Window_Access) is
      C : Window_Vectors.Cursor := Stack.Find (W);
   begin
      if Window_Vectors.Has_Element (C) then
         Stack.Delete (C);
      end if;
   end Remove;

   procedure Activate (W : Window_Access) is
   begin
      Remove (W);
      Stack.Append (W);
   end Activate;

   function Active return Window_Access is
     (if Stack.Is_Empty then null else Stack.Last_Element);

   function Count return Natural is (Natural (Stack.Length));

   function Nth (N : Positive) return Window_Access is (Stack (N));

   function Window_At (X, Y : Integer) return Window_Access is
   begin
      for K in reverse 1 .. Count loop
         if Hit (Stack (K).all, X, Y) /= Outside then
            return Stack (K);
         end if;
      end loop;
      return null;
   end Window_At;

   function With_Number (N : Positive) return Window_Access is
   begin
      for W of Stack loop
         if W.Number = N then
            return W;
         end if;
      end loop;
      return null;
   end With_Number;

   procedure Next_Window is
   begin
      --  The bottom window comes to the top (Turbo's F6 order).
      if Count > 1 then
         Activate (Stack.First_Element);
      end if;
   end Next_Window;

   procedure Prev_Window is
      W : Window_Access;
   begin
      if Count > 1 then
         W := Stack.Last_Element;
         Stack.Delete_Last;
         Stack.Prepend (W);
      end if;
   end Prev_Window;

   procedure Tile is
      A    : constant Rect := Area;
      N    : constant Natural := Count;
      Cols : Positive := 1;
      Rows : Positive;
   begin
      if N = 0 then
         return;
      end if;
      while Cols * Cols < N loop
         Cols := Cols + 1;
      end loop;
      Rows := (N + Cols - 1) / Cols;
      for K in 1 .. N loop
         declare
            Idx : constant Natural := K - 1;
            C   : constant Natural := Idx mod Cols;
            R   : constant Natural := Idx / Cols;
            --  The last row may have fewer windows; stretch them.
            In_Row : constant Positive :=
              (if R = Rows - 1 then N - (Rows - 1) * Cols else Cols);
            X0  : constant Integer := A.X + (C * A.W) / In_Row;
            X1  : constant Integer := A.X + ((C + 1) * A.W) / In_Row;
            Y0  : constant Integer := A.Y + (R * A.H) / Rows;
            Y1  : constant Integer := A.Y + ((R + 1) * A.H) / Rows;
         begin
            Stack (K).Zoomed := False;
            Stack (K).Bounds := (X0, Y0, X1 - X0, Y1 - Y0);
         end;
      end loop;
   end Tile;

   procedure Cascade is
      A : constant Rect := Area;
      N : constant Natural := Count;
   begin
      for K in 1 .. N loop
         Stack (K).Zoomed := False;
         Stack (K).Bounds :=
           (A.X + (K - 1), A.Y + (K - 1),
            Integer'Max (24, A.W - (N - 1)), Integer'Max (6, A.H - (N - 1)));
      end loop;
   end Cascade;

   procedure Draw_Status is
      Y : constant Integer := Height;
      X : Integer := 2;
   begin
      Fill (1, Y, Width, 1, ' ',
            (if Is_Busy then Theme.Status_Busy else Theme.Status_Normal));
      if Message /= Null_Unbounded_String then
         Put (2, Y, To_String (Message),
              (if Is_Busy then Theme.Status_Busy else Theme.Status_Normal));
         return;
      end if;
      if Items /= null then
         for It of Items.all loop
            Put_Hot (X, Y, It.Label.all, Theme.Status_Normal, Theme.Status_Hot);
            X := X + Hot_Length (It.Label.all) + 2;
         end loop;
      end if;
      if Length (Right) > 0 and then X + Length (Right) < Width then
         Put (Width - Length (Right), Y, To_String (Right), Theme.Status_Normal);
      end if;
   end Draw_Status;

   procedure Draw_Windows is
   begin
      for K in 1 .. Count loop
         declare
            W : constant Window_Access := Stack (K);
            B : constant Rect := W.Bounds;
         begin
            W.Draw (Active => K = Count);
            if Settings.Show_Shadows then
               Shadow (B.X + B.W, B.Y + 1, 2, B.H);
               Shadow (B.X + 2, B.Y + B.H, B.W, 1);
            end if;
         end;
      end loop;
      --  Shadows never cover the bar or the status line.
   end Draw_Windows;

   procedure Draw_Background_Only is
      A : constant Rect := Area;
   begin
      Reset_Clip;
      Hide_Cursor;
      Fill (A.X, A.Y, A.W, A.H, Shade_1, Theme.Desktop);
      Set_Clip (A.X, A.Y, A.X + A.W - 1, A.Y + A.H - 1);
      Draw_Windows;
      Reset_Clip;
      Menus.Draw_Bar;
      Draw_Status;
   end Draw_Background_Only;

   procedure Draw is
   begin
      --  Only the active window sets the cursor, and it is drawn last.
      Draw_Background_Only;
   end Draw;

   procedure Set_Status_Right (Text : String) is
   begin
      Right := To_Unbounded_String (Text);
   end Set_Status_Right;

   procedure Set_Status (Items : Status_Items) is
   begin
      Desktop.Items := new Status_Items'(Items);
   end Set_Status;

   procedure Set_Status_Message (Text : String; Busy : Boolean := False) is
   begin
      Message := To_Unbounded_String (Text);
      Is_Busy := Busy and then Text /= "";
   end Set_Status_Message;

   function Status_Command_At (X : Integer) return Turbo.Commands.Command is
      Pos : Integer := 2;
   begin
      if Items = null or else Message /= Null_Unbounded_String then
         return Turbo.Commands.Cmd_None;
      end if;
      for It of Items.all loop
         if X >= Pos and then X < Pos + Hot_Length (It.Label.all) then
            return It.Cmd;
         end if;
         Pos := Pos + Hot_Length (It.Label.all) + 2;
      end loop;
      return Turbo.Commands.Cmd_None;
   end Status_Command_At;

end Turbo.Desktop;
