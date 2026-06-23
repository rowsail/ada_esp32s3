--  Panel-agnostic glyph renderer.  Instantiate it once per display with that
--  panel's pixel type and bitmap-blit operation; the resulting package draws
--  ESP32S3.Fonts.Font atlases onto that panel.
--
--    package ST7789_Fonts is new ESP32S3.Fonts.Render
--      (Color => ST7789.Color, Color_Array => ST7789.Color_Array,
--       Surface => ST7789.Session, To_Color => ST7789.RGB,
--       Blit => ST7789.Draw_Bitmap);
--
--  Anti-aliasing works on a write-only panel because each glyph pixel's coverage
--  is blended between FG and BG (a 16-entry ramp built per string) and the whole
--  glyph cell is blitted opaque -- no framebuffer read-back.  Glyphs whose origin
--  would fall left of / above the surface (negative X/Y) are skipped (the Blit
--  contract takes Natural coordinates).
generic
   type Color is private;
   type Color_Array is array (Natural range <>) of Color;
   type Surface (<>) is limited private;
   --  Build a pixel from 8-bit-per-channel RGB (each 0 .. 255).
   with function To_Color (R, G, B : Natural) return Color;
   --  Blit a W x H block of pixels (row-major) at (X, Y) on the surface.
   with procedure Blit
     (S : Surface; X, Y, W, H : Natural; Pixels : Color_Array);
package ESP32S3.Fonts.Render is

   --  Draw one character with its baseline left corner at (X, Baseline).
   procedure Draw_Char
     (S        : Surface;
      F        : ESP32S3.Fonts.Font;
      X        : Integer;
      Baseline : Integer;
      Ch       : Character;
      FG, BG   : ESP32S3.Fonts.RGB);

   --  Draw Str with its baseline left end at (X, Baseline); FG over a known BG
   --  (the caller has painted BG behind the text run).  Codes not in F are
   --  skipped.  Advances proportionally by each glyph's metric.
   procedure Draw_Text
     (S        : Surface;
      F        : ESP32S3.Fonts.Font;
      X        : Integer;
      Baseline : Integer;
      Str      : String;
      FG, BG   : ESP32S3.Fonts.RGB);

end ESP32S3.Fonts.Render;
