--  5x7 bitmap text on top of ESP32S3.ST7789.
--
--  Built purely on the parent's Draw_Bitmap primitive: each glyph is a 5x7
--  bitmap rendered into a 6x8 cell (one column + one row of inter-character
--  spacing) and blitted as one windowed write.  Cells are OPAQUE -- a glyph
--  paints both foreground and background -- because the panel is write-only
--  (no framebuffer to read back for a transparent overlay).
--
--  Takes the same held Session as the rest of the driver, so text shares the
--  two-level locking: the display stays owned across a sequence of Draw_Text
--  calls while each one locks the SPI host only for its own transfers.
--
--     ESP32S3.ST7789.Text.Draw_Text
--       (S, X => 8, Y => 8, Str => "Hello", FG => White, BG => Black);

package ESP32S3.ST7789.Text is

   --  Cell geometry at Scale = 1: a 5x7 glyph in a 6x8 cell.  At Scale = N each
   --  font pixel becomes an N x N block, so a character occupies
   --  Cell_Width * N by Cell_Height * N pixels.
   Cell_Width  : constant := 6;
   Cell_Height : constant := 8;

   --  Draw one character with its cell's top-left at (X, Y).  FG paints the set
   --  pixels, BG the rest (including the spacing column/row).  Characters
   --  outside printable ASCII (0x20 .. 0x7E) render as a blank cell.
   procedure Draw_Char
     (S      : Session;
      X, Y   : Natural;
      Ch     : Character;
      FG, BG : Color;
      Scale  : Positive := 1);

   --  Draw a string with its first cell at (X, Y), advancing X by
   --  Cell_Width * Scale per character.  An ASCII LF (Character'Val (10))
   --  returns to the start column and drops down one line (Cell_Height * Scale).
   --  No automatic right-edge wrap -- glyphs that would start past the panel are
   --  skipped by the driver's bounds check.
   procedure Draw_Text
     (S      : Session;
      X, Y   : Natural;
      Str    : String;
      FG, BG : Color;
      Scale  : Positive := 1);

end ESP32S3.ST7789.Text;
