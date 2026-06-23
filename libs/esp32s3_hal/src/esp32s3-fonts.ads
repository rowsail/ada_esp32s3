with System;
with Interfaces;

--  Panel-independent text/font data model for proportional bitmap fonts.
--
--  A Font is a light descriptor that POINTS (by address) at flat glyph-atlas
--  arrays generated offline (see libs/esp32s3_hal/tools/gen_font.py): per-glyph
--  metrics (advance, size, bearings, byte offset) plus packed coverage.  Two
--  coverage encodings are supported:
--
--    Bpp = 4  anti-aliased: 4-bit (16-level) coverage, 2 px/byte.
--    Bpp = 1  monochrome:   1-bit coverage, 8 px/byte (MSB first), ~4x smaller.
--
--  This package has NO display dependency -- it only models the glyph data and
--  reads it through accessor functions.  The actual rasterising/blitting is done
--  by the generic ESP32S3.Fonts.Render, instantiated per panel (e.g.
--  ESP32S3.ST7789.Fonts).  The atlas data and Font values are therefore reusable
--  across panels unchanged.
package ESP32S3.Fonts is

   --  Atlas array element types (the generated atlas packages import these).
   type Byte_Array  is array (Natural range <>) of Interfaces.Unsigned_8;
   type SByte_Array is array (Natural range <>) of Interfaces.Integer_8;
   type U16_Array   is array (Natural range <>) of Interfaces.Unsigned_16;

   --  An 8-bit-per-channel colour the renderer blends in; the panel instance
   --  maps it to its own pixel format via its To_Color formal.
   type RGB is record
      R, G, B : Natural := 0;   --  each 0 .. 255
   end record;

   --  Font descriptor.  Covers code points [First .. First + Count - 1] (index
   --  = code - First).  Ascent is the baseline offset below a line's top, Height
   --  the line advance.  The seven addresses point at the per-glyph metric arrays
   --  (adv, w, h, xoff, yoff, off) and the packed coverage bytes.
   type Font is record
      First, Count   : Natural;
      Height, Ascent : Natural;
      Bpp            : Natural;             --  1 or 4
      Adv, W, H      : System.Address;
      XOff, YOff     : System.Address;
      Off            : System.Address;      --  U16 byte offset into Bits per glyph
      Bits           : System.Address;
   end record;

   --  True if Code has a glyph in F.
   function Has_Glyph (F : Font; Code : Natural) return Boolean is
     (Code in F.First .. F.First + F.Count - 1);

   --  Per-glyph metrics (G is a glyph index, 0 .. Count-1).
   function Glyph_Adv  (F : Font; G : Natural) return Natural;
   function Glyph_W    (F : Font; G : Natural) return Natural;
   function Glyph_H    (F : Font; G : Natural) return Natural;
   function Glyph_XOff (F : Font; G : Natural) return Integer;
   function Glyph_YOff (F : Font; G : Natural) return Integer;

   --  16-level coverage (0 .. 15) of pixel Index (row-major) within glyph G,
   --  decoded per F.Bpp (mono returns 0 or 15).
   function Coverage (F : Font; G : Natural; Index : Natural) return Natural;

   --  Total pixel advance of Str (codes outside F are skipped).
   function Text_Width (F : Font; Str : String) return Natural;

end ESP32S3.Fonts;
