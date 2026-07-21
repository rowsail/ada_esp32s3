package body FB is

   procedure Test_Pattern is
      --  RGB565 colours: R at bits 11..15, G at 5..10, B at 0..4.
      Bars : constant array (0 .. 7) of Unsigned_16 :=
        (16#F800#,    --  red
         16#07E0#,    --  green
         16#001F#,    --  blue
         16#FFFF#,    --  white
         16#FFE0#,    --  yellow
         16#07FF#,    --  cyan
         16#F81F#,    --  magenta
         16#0000#);   --  black
      Bar_W : constant := Width / 8;
   begin
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            declare
               C   : constant Unsigned_16 := Bars (X / Bar_W);
               Off : constant Natural := (Y * Width + X) * 2;
            begin
               FB0 (Off)     := Unsigned_8 (C and 16#FF#);          --  low byte
               FB0 (Off + 1) := Unsigned_8 (Shift_Right (C, 8));    --  high byte
            end;
         end loop;
      end loop;
   end Test_Pattern;

   Bars  : constant array (0 .. 7) of Unsigned_16 :=
     (16#F800#, 16#07E0#, 16#001F#, 16#FFFF#,
      16#FFE0#, 16#07FF#, 16#F81F#, 16#0000#);
   Bar_W : constant := Width / 8;

   ---------------
   -- Draw_Bars --
   ---------------

   procedure Draw_Bars (Buf : System.Address) is
      --  RGB565 pixels, native little-endian -- matches the LCD's byte order.
      Pix : array (0 .. Width * Height - 1) of Unsigned_16
        with Import, Address => Buf;
   begin
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            Pix (Y * Width + X) := Bars (X / Bar_W);
         end loop;
      end loop;
   end Draw_Bars;

   ---------------
   -- Paint_Box --
   ---------------

   procedure Paint_Box (Buf : System.Address; X, Y : Natural; White : Boolean) is
      Pix : array (0 .. Width * Height - 1) of Unsigned_16
        with Import, Address => Buf;
      X1  : constant Natural := Natural'Min (X + Box, Width);
      Y1  : constant Natural := Natural'Min (Y + Box, Height);
   begin
      for Row in Y .. Y1 - 1 loop
         for Col in X .. X1 - 1 loop
            Pix (Row * Width + Col) :=
              (if White then 16#FFFF# else Bars (Col / Bar_W));
         end loop;
      end loop;
   end Paint_Box;

   -----------------
   -- Draw_Border --
   -----------------

   procedure Draw_Border (Buf : System.Address) is
      Pix : array (0 .. Width * Height - 1) of Unsigned_16
        with Import, Address => Buf;
      T   : constant := 4;   --  border thickness in pixels
   begin
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            if X < T or else X >= Width - T
              or else Y < T or else Y >= Height - T
            then
               Pix (Y * Width + X) := 16#FFFF#;
            end if;
         end loop;
      end loop;
   end Draw_Border;

end FB;
