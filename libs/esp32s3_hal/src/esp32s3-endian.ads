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

   --  The postconditions below are written arithmetically (+, *, /, mod) rather
   --  than with shifts, so these make the parent types' operators visible.
   use type Interfaces.Unsigned_16;
   use type Interfaces.Unsigned_32;

   --  The contracts below are the WHOLE meaning of these six subprograms, not
   --  just their run-time safety: each Join is pinned to the positional-notation
   --  sum that defines the byte order, and each Split to the matching quotient /
   --  remainder.  Stating it arithmetically rather than with shifts is the point
   --  -- the shifts are the implementation, and "byte 0 is the least-significant"
   --  is the specification, so a transposed shift in the body stops proving
   --  instead of quietly reversing a word.  Each Split additionally round-trips
   --  through its Join; since Join is injective that single clause already fixes
   --  all four outputs, and it is what the AES / SHA / SDMMC register paths and
   --  the network code actually rely on when they pack and unpack the same word.

   --  Little-endian: byte 0 is the least-significant.
   function Join_LE (B0, B1, B2, B3 : U8) return U32
   with Inline,
        Post => Join_LE'Result = U32 (B0)
                                 + 2 ** 8  * U32 (B1)
                                 + 2 ** 16 * U32 (B2)
                                 + 2 ** 24 * U32 (B3);
   procedure Split_LE (W : U32; B0, B1, B2, B3 : out U8)
   with Inline,
        Post => U32 (B0) = W mod 2 ** 8
                and then U32 (B1) = (W / 2 ** 8) mod 2 ** 8
                and then U32 (B2) = (W / 2 ** 16) mod 2 ** 8
                and then U32 (B3) = W / 2 ** 24
                and then Join_LE (B0, B1, B2, B3) = W;

   --  Big-endian (network byte order): byte 0 is the most-significant.
   function Join_BE16 (Hi, Lo : U8) return U16
   with Inline,
        Post => Join_BE16'Result = 2 ** 8 * U16 (Hi) + U16 (Lo);
   function Join_BE32 (B0, B1, B2, B3 : U8) return U32
   with Inline,
        Post => Join_BE32'Result = 2 ** 24 * U32 (B0)
                                   + 2 ** 16 * U32 (B1)
                                   + 2 ** 8  * U32 (B2)
                                   + U32 (B3);
   procedure Split_BE16 (V : U16; Hi, Lo : out U8)
   with Inline,
        Post => U16 (Hi) = V / 2 ** 8
                and then U16 (Lo) = V mod 2 ** 8
                and then Join_BE16 (Hi, Lo) = V;
   procedure Split_BE32 (V : U32; B0, B1, B2, B3 : out U8)
   with Inline,
        Post => U32 (B0) = V / 2 ** 24
                and then U32 (B1) = (V / 2 ** 16) mod 2 ** 8
                and then U32 (B2) = (V / 2 ** 8) mod 2 ** 8
                and then U32 (B3) = V mod 2 ** 8
                and then Join_BE32 (B0, B1, B2, B3) = V;

end ESP32S3.Endian;
