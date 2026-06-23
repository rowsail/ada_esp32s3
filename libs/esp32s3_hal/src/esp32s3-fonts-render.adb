package body ESP32S3.Fonts.Render is

   type Ramp16 is array (0 .. 15) of Color;

   --  16-step FG<-BG ramp built from the 8-bit-per-channel endpoints.
   function Make_Ramp (FG, BG : ESP32S3.Fonts.RGB) return Ramp16 is
      R : Ramp16;
   begin
      for K in Ramp16'Range loop
         R (K) := To_Color (BG.R + (FG.R - BG.R) * K / 15,
                            BG.G + (FG.G - BG.G) * K / 15,
                            BG.B + (FG.B - BG.B) * K / 15);
      end loop;
      return R;
   end Make_Ramp;

   --  Rasterise glyph G (its inked box top-left at (X0, Y0)) and blit it.
   procedure Emit
     (S : Surface; F : ESP32S3.Fonts.Font; G : Natural; X0, Y0 : Integer;
      Ramp : Ramp16)
   is
      W : constant Natural := ESP32S3.Fonts.Glyph_W (F, G);
      H : constant Natural := ESP32S3.Fonts.Glyph_H (F, G);
   begin
      if W = 0 or else H = 0 or else X0 < 0 or else Y0 < 0 then
         return;
      end if;
      declare
         Cell : Color_Array (0 .. W * H - 1);
      begin
         for I in Cell'Range loop
            Cell (I) := Ramp (ESP32S3.Fonts.Coverage (F, G, I));
         end loop;
         Blit (S, X0, Y0, W, H, Cell);
      end;
   end Emit;

   ---------------
   -- Draw_Char --
   ---------------

   procedure Draw_Char
     (S        : Surface;
      F        : ESP32S3.Fonts.Font;
      X        : Integer;
      Baseline : Integer;
      Ch       : Character;
      FG, BG   : ESP32S3.Fonts.RGB)
   is
      Code : constant Natural := Character'Pos (Ch);
   begin
      if ESP32S3.Fonts.Has_Glyph (F, Code) then
         declare
            G : constant Natural := Code - F.First;
         begin
            Emit (S, F, G,
                  X + ESP32S3.Fonts.Glyph_XOff (F, G),
                  Baseline + ESP32S3.Fonts.Glyph_YOff (F, G),
                  Make_Ramp (FG, BG));
         end;
      end if;
   end Draw_Char;

   ---------------
   -- Draw_Text --
   ---------------

   procedure Draw_Text
     (S        : Surface;
      F        : ESP32S3.Fonts.Font;
      X        : Integer;
      Baseline : Integer;
      Str      : String;
      FG, BG   : ESP32S3.Fonts.RGB)
   is
      Ramp : constant Ramp16 := Make_Ramp (FG, BG);
      Pen  : Integer := X;
   begin
      for Ch of Str loop
         declare
            Code : constant Natural := Character'Pos (Ch);
         begin
            if ESP32S3.Fonts.Has_Glyph (F, Code) then
               declare
                  G : constant Natural := Code - F.First;
               begin
                  Emit (S, F, G,
                        Pen + ESP32S3.Fonts.Glyph_XOff (F, G),
                        Baseline + ESP32S3.Fonts.Glyph_YOff (F, G), Ramp);
                  Pen := Pen + ESP32S3.Fonts.Glyph_Adv (F, G);
               end;
            end if;
         end;
      end loop;
   end Draw_Text;

end ESP32S3.Fonts.Render;
