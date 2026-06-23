with ESP32S3.ST7789;

--  240x240 RGB565 Ada-mascot splash image.  The pixel data lives in
--  main/ada_logo.h (auto-generated from Ada_FreeRTOS/book/AdaNoText.svg) and is
--  compiled into glue.c as the C symbol `ada_logo_rgb565`; this package imports
--  it as a Color_Array so the example can blit it with ESP32S3.ST7789.Draw_Bitmap.
--  Importing the C array (vs. an Ada aggregate) keeps the 57 600-element table
--  out of the Ada source and compiles instantly.
package Ada_Logo is

   Width  : constant := 240;
   Height : constant := 240;

   --  Row-major, one RGB565 value per pixel (the layout Draw_Bitmap expects).
   Pixels : constant ESP32S3.ST7789.Color_Array (0 .. Width * Height - 1);
   pragma Import (C, Pixels, "ada_logo_rgb565");

end Ada_Logo;
