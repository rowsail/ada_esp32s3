with ESP32S3.Fonts.Render;

--  Proportional anti-aliased / monochrome text for the ST7789, an instantiation
--  of the panel-agnostic ESP32S3.Fonts.Render engine bound to this driver's
--  pixel type and Draw_Bitmap.  Hold the display Session (the two-level lock)
--  and paint the text background first, then:
--
--     ESP32S3.ST7789.Fonts.Draw_Text
--       (S, My_Font, X => 6, Baseline => 20, Str => "Hello",
--        FG => (255, 255, 255), BG => (0, 0, 0));
--
--  Font values come from generated atlases (see tools/gen_font.py); they are
--  ESP32S3.Fonts.Font and so are shared unchanged with any other panel's
--  instantiation.  Distinct from ESP32S3.ST7789.Text, which is the built-in 5x7
--  bitmap font.
package ESP32S3.ST7789.Fonts is new ESP32S3.Fonts.Render
  (Color       => ESP32S3.ST7789.Color,
   Color_Array => ESP32S3.ST7789.Color_Array,
   Surface     => ESP32S3.ST7789.Session,
   To_Color    => ESP32S3.ST7789.RGB,
   Blit        => ESP32S3.ST7789.Draw_Bitmap);
