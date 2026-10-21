with Ada.Strings.Unbounded;
with Turbo.Term;

package body Turbo.Screen is

   use Ada.Strings.Unbounded;

   type Grid is array (Positive range <>, Positive range <>) of Cell;
   type Grid_Access is access Grid;

   Cur  : Grid_Access;              --  being drawn
   Prev : Grid_Access;              --  what the terminal shows
   W    : Positive := 80;
   H    : Positive := 25;

   Clip_X1, Clip_Y1 : Integer := 1;
   Clip_X2, Clip_Y2 : Integer := 80;

   Use_True_Color : Boolean := False;

   Cursor_X, Cursor_Y : Integer := 1;
   Cursor_On          : Boolean := False;
   Cursor_Block       : Boolean := False;

   Full_Repaint : Boolean := True;

   procedure Free_Grids is
   begin
      --  The grids are small and resizes rare: let them go (no
      --  Unchecked_Deallocation, so no dangling-pointer risk).
      Cur := null;
      Prev := null;
   end Free_Grids;

   procedure Init is
      Rows, Cols : Positive;
   begin
      Term.Size (Rows, Cols);
      if Cur = null or else Rows /= H or else Cols /= W then
         Free_Grids;
         W := Cols;
         H := Rows;
         Cur := new Grid (1 .. H, 1 .. W);
         Prev := new Grid (1 .. H, 1 .. W);
      end if;
      Reset_Clip;
      Full_Repaint := True;
   end Init;

   function Width return Positive is (W);
   function Height return Positive is (H);

   procedure Set_True_Color (On : Boolean) is
   begin
      if On /= Use_True_Color then
         Use_True_Color := On;
         Full_Repaint := True;
      end if;
   end Set_True_Color;

   function True_Color return Boolean is (Use_True_Color);

   procedure Set_Clip (X1, Y1, X2, Y2 : Integer) is
   begin
      Clip_X1 := Integer'Max (X1, 1);
      Clip_Y1 := Integer'Max (Y1, 1);
      Clip_X2 := Integer'Min (X2, W);
      Clip_Y2 := Integer'Min (Y2, H);
   end Set_Clip;

   procedure Reset_Clip is
   begin
      Set_Clip (1, 1, W, H);
   end Reset_Clip;

   function Visible (X, Y : Integer) return Boolean is
     (X >= Clip_X1 and then X <= Clip_X2 and then Y >= Clip_Y1
      and then Y <= Clip_Y2);

   procedure Put (X, Y : Integer; C : Wide_Wide_Character; A : Attribute) is
      Shown : Wide_Wide_Character := C;
   begin
      if Visible (X, Y) then
         if Wide_Wide_Character'Pos (C) < 32
           or else Wide_Wide_Character'Pos (C) in 127 .. 159
         then
            Shown := Middle_Dot;
         end if;
         Cur (Y, X) := (Shown, A);
      end if;
   end Put;

   procedure Put_Wide (X, Y : Integer; S : Wide_Wide_String; A : Attribute) is
   begin
      for I in S'Range loop
         Put (X + (I - S'First), Y, S (I), A);
      end loop;
   end Put_Wide;

   procedure Put (X, Y : Integer; S : String; A : Attribute) is
   begin
      for I in S'Range loop
         Put (X + (I - S'First), Y,
              Wide_Wide_Character'Val (Character'Pos (S (I))), A);
      end loop;
   end Put;

   procedure Put_Hot (X, Y : Integer; S : String; Normal, Hot : Attribute) is
      Col : Integer := X;
      On  : Boolean := False;
   begin
      for C of S loop
         if C = '~' then
            On := not On;
         else
            Put (Col, Y, Wide_Wide_Character'Val (Character'Pos (C)),
                 (if On then Hot else Normal));
            Col := Col + 1;
         end if;
      end loop;
   end Put_Hot;

   function Hot_Length (S : String) return Natural is
      N : Natural := 0;
   begin
      for C of S loop
         if C /= '~' then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Hot_Length;

   function Hot_Key (S : String) return Character is
   begin
      for I in S'First .. S'Last - 1 loop
         if S (I) = '~' then
            if S (I + 1) in 'A' .. 'Z' then
               return Character'Val (Character'Pos (S (I + 1)) + 32);
            end if;
            return S (I + 1);
         end if;
      end loop;
      return Character'Val (0);
   end Hot_Key;

   procedure Fill
     (X, Y, W, H : Integer; C : Wide_Wide_Character; A : Attribute) is
   begin
      for Row in Y .. Y + H - 1 loop
         for Col in X .. X + W - 1 loop
            Put (Col, Row, C, A);
         end loop;
      end loop;
   end Fill;

   procedure Paint (X, Y, W, H : Integer; A : Attribute) is
   begin
      for Row in Y .. Y + H - 1 loop
         for Col in X .. X + W - 1 loop
            if Visible (Col, Row) then
               Cur (Row, Col).A := A;
            end if;
         end loop;
      end loop;
   end Paint;

   procedure Shadow (X, Y, W, H : Integer) is
   begin
      Paint (X, Y, W, H, Dark_Gray / Black);
   end Shadow;

   procedure Frame
     (X, Y, W, H : Integer; A : Attribute; Double : Boolean)
   is
      Hz : constant Wide_Wide_Character := (if Double then H_Double else H_Single);
      Vt : constant Wide_Wide_Character := (if Double then V_Double else V_Single);
   begin
      Put (X, Y, (if Double then TL_Double else TL_Single), A);
      Put (X + W - 1, Y, (if Double then TR_Double else TR_Single), A);
      Put (X, Y + H - 1, (if Double then BL_Double else BL_Single), A);
      Put (X + W - 1, Y + H - 1, (if Double then BR_Double else BR_Single), A);
      for Col in X + 1 .. X + W - 2 loop
         Put (Col, Y, Hz, A);
         Put (Col, Y + H - 1, Hz, A);
      end loop;
      for Row in Y + 1 .. Y + H - 2 loop
         Put (X, Row, Vt, A);
         Put (X + W - 1, Row, Vt, A);
      end loop;
   end Frame;

   function Get (X, Y : Integer) return Cell is
   begin
      if X in 1 .. W and then Y in 1 .. H then
         return Cur (Y, X);
      end if;
      return (others => <>);
   end Get;

   procedure Set_Cursor (X, Y : Integer; Block : Boolean := False) is
   begin
      Cursor_X := X;
      Cursor_Y := Y;
      Cursor_On := X in 1 .. W and then Y in 1 .. H;
      Cursor_Block := Block;
   end Set_Cursor;

   procedure Hide_Cursor is
   begin
      Cursor_On := False;
   end Hide_Cursor;

   procedure Invalidate is
   begin
      Full_Repaint := True;
   end Invalidate;

   --  Output

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   type RGB is record
      R, G, B : Natural;
   end record;

   CGA : constant array (Color) of RGB :=
     [Black => (0, 0, 0),             Blue => (0, 0, 170),
      Green => (0, 170, 0),           Cyan => (0, 170, 170),
      Red => (170, 0, 0),             Magenta => (170, 0, 170),
      Brown => (170, 85, 0),          Light_Gray => (170, 170, 170),
      Dark_Gray => (85, 85, 85),      Light_Blue => (85, 85, 255),
      Light_Green => (85, 255, 85),   Light_Cyan => (85, 255, 255),
      Light_Red => (255, 85, 85),     Light_Magenta => (255, 85, 255),
      Yellow => (255, 255, 85),       White => (255, 255, 255)];

   --  CGA order to ANSI order (ANSI swaps blue/red and cyan/brown).
   ANSI : constant array (Color range Black .. Light_Gray) of Natural :=
     [Black => 0, Blue => 4, Green => 2, Cyan => 6, Red => 1, Magenta => 5,
      Brown => 3, Light_Gray => 7];

   function SGR (A : Attribute) return String is
   begin
      if Use_True_Color then
         declare
            F : constant RGB := CGA (A.Fg);
            B : constant RGB := CGA (A.Bg);
         begin
            return Character'Val (27) & "[38;2;" & Img (F.R) & ";" & Img (F.G)
              & ";" & Img (F.B) & ";48;2;" & Img (B.R) & ";" & Img (B.G) & ";"
              & Img (B.B) & "m";
         end;
      else
         declare
            Fg : constant Natural :=
              (if A.Fg <= Light_Gray then 30 + ANSI (A.Fg)
               else 90 + ANSI (Color'Val (Color'Pos (A.Fg) - 8)));
            Bg : constant Natural :=
              (if A.Bg <= Light_Gray then 40 + ANSI (A.Bg)
               else 100 + ANSI (Color'Val (Color'Pos (A.Bg) - 8)));
         begin
            return Character'Val (27) & "[0;" & Img (Fg) & ";" & Img (Bg) & "m";
         end;
      end if;
   end SGR;

   procedure Append_UTF8 (Out_S : in out Unbounded_String; C : Wide_Wide_Character)
   is
      P : constant Natural := Wide_Wide_Character'Pos (C);
   begin
      if P < 16#80# then
         Append (Out_S, Character'Val (P));
      elsif P < 16#800# then
         Append (Out_S, Character'Val (16#C0# + P / 64));
         Append (Out_S, Character'Val (16#80# + P mod 64));
      elsif P < 16#10000# then
         Append (Out_S, Character'Val (16#E0# + P / 4096));
         Append (Out_S, Character'Val (16#80# + (P / 64) mod 64));
         Append (Out_S, Character'Val (16#80# + P mod 64));
      else
         Append (Out_S, Character'Val (16#F0# + P / 262144));
         Append (Out_S, Character'Val (16#80# + (P / 4096) mod 64));
         Append (Out_S, Character'Val (16#80# + (P / 64) mod 64));
         Append (Out_S, Character'Val (16#80# + P mod 64));
      end if;
   end Append_UTF8;

   procedure Flush is
      ESC     : constant Character := Character'Val (27);
      O       : Unbounded_String;
      Last_A  : Attribute;
      Have_A  : Boolean := False;
      At_X    : Integer := -1;
      At_Y    : Integer := -1;
   begin
      if Cur = null then
         return;
      end if;
      Append (O, ESC & "[?25l");                    --  no flicker while drawing
      if Full_Repaint then
         Append (O, ESC & "[0m" & ESC & "[2J");
      end if;
      for Y in 1 .. H loop
         for X in 1 .. W loop
            if Full_Repaint or else Cur (Y, X) /= Prev (Y, X) then
               if Y /= At_Y or else X /= At_X then
                  Append (O, ESC & "[" & Img (Y) & ";" & Img (X) & "H");
               end if;
               if not Have_A or else Cur (Y, X).A /= Last_A then
                  Append (O, SGR (Cur (Y, X).A));
                  Last_A := Cur (Y, X).A;
                  Have_A := True;
               end if;
               Append_UTF8 (O, Cur (Y, X).Ch);
               Prev (Y, X) := Cur (Y, X);
               At_X := X + 1;
               At_Y := Y;
               if At_X > W then
                  At_X := -1;        --  the terminal may or may not wrap
               end if;
            end if;
         end loop;
      end loop;
      Full_Repaint := False;
      if Cursor_On then
         Append (O, ESC & "[" & Img (Cursor_Y) & ";" & Img (Cursor_X) & "H");
         Append (O, ESC & (if Cursor_Block then "[1 q" else "[3 q"));
         Append (O, ESC & "[?25h");
      end if;
      Term.Write (To_String (O));
   end Flush;

end Turbo.Screen;
