--  Tiny text helpers every driver and example was writing for itself --
--  most famously the "decimal image without Ada's leading blank", which at
--  one point existed as a dozen identical local functions named Img.  One
--  home for them; rename locally if the short name reads better:
--
--     function Img (Value : Natural) return String
--       renames ESP32S3.Strings.Image;
package ESP32S3.Strings is

   --  "0", "42" -- Natural'Image without the nonnegative leading blank.
   function Image (Value : Natural) return String;

   --  "-5", "7" -- likewise, for values that may be negative.
   function Image_Signed (Value : Integer) return String;

end ESP32S3.Strings;
