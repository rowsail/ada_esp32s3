--  Tiny text helpers every driver and example was writing for itself --
--  most famously the "decimal image without Ada's leading blank", which at
--  one point existed as a dozen identical local functions named Img.  One
--  home for them; rename locally if the short name reads better:
--
--     function Img (Value : Natural) return String
--       renames ESP32S3.Strings.Image;
package ESP32S3.Strings with SPARK_Mode => On is

   --  "0", "42" -- Natural'Image without the nonnegative leading blank.
   --
   --  The result bounds are contracted because callers build fixed-budget
   --  strings out of them -- an MQTT topic, a log line -- and a prover cannot
   --  otherwise know how long a formatted number is.  Ten digits covers
   --  Natural'Last (2147483647).
   --  (Only the LENGTH is contracted: the result is a slice of 'Image, so its
   --  'First is that slice's, and every caller concatenates rather than
   --  indexes.)
   function Image (Value : Natural) return String
   with Post => Image'Result'Length in 1 .. 10;

   --  "-5", "7" -- likewise, for values that may be negative.
   function Image_Signed (Value : Integer) return String
   with Post => Image_Signed'Result'Length in 1 .. 11;   --  incl. the '-'

end ESP32S3.Strings;
