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

end FB;
