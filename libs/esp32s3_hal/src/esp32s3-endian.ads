with Interfaces;

--  One tested definition of the byte<->word packing that the AES / SHA / SDMMC
--  register paths (little-endian: byte 0 = LSB) and the network protocol code
--  (big-endian: byte 0 = MSB) previously open-coded in half a dozen places.
--
--  Word type is Interfaces.Unsigned_32/16 so this stays Pure and host-testable;
--  callers whose word is a derived type (e.g. the registers' UInt32) convert at
--  the call, which is one conversion per word, not per byte.

package ESP32S3.Endian
  with Pure, SPARK_Mode => On
is

   subtype U8 is Interfaces.Unsigned_8;
   subtype U16 is Interfaces.Unsigned_16;
   subtype U32 is Interfaces.Unsigned_32;

   --  Little-endian: byte 0 is the least-significant.
   function Join_LE (B0, B1, B2, B3 : U8) return U32
   with Inline;
   procedure Split_LE (W : U32; B0, B1, B2, B3 : out U8)
   with Inline;

   --  Big-endian (network byte order): byte 0 is the most-significant.
   function Join_BE16 (Hi, Lo : U8) return U16
   with Inline;
   function Join_BE32 (B0, B1, B2, B3 : U8) return U32
   with Inline;
   procedure Split_BE16 (V : U16; Hi, Lo : out U8)
   with Inline;
   procedure Split_BE32 (V : U32; B0, B1, B2, B3 : out U8)
   with Inline;

end ESP32S3.Endian;
