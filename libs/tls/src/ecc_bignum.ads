with Interfaces; use Interfaces;

--  Modular big-integer arithmetic over a fixed number of 32-bit limbs, in
--  Montgomery form (CIOS) -- the layer that P256 and P384 had a copy of each.
--
--  Every operation here takes its modulus M as a PARAMETER.  That is what makes
--  one generic serve both curves: the curve-specific part of P256/P384 is not
--  the arithmetic, it is the constants (p, n, b, the generator) and the two
--  Montgomery constants derived from them.  Those stay in the instantiating
--  package, which computes them by calling Inv32 and Compute_R2 below.
--
--  The generic is parameterised on the limb COUNT alone.  The two loop bounds
--  that used to be written out as literals both follow from it:
--    * Mont_Pow scans the exponent from bit Limbs * 32 - 1 down (255 / 383);
--    * Compute_R2 doubles 2 * Limbs * 32 times, i.e. R^2 = 2^(2*Limbs*32).
--  Getting either wrong is not a compile error, so deriving them from Limbs
--  rather than restating them per curve is the point of the exercise.
--
--  SPARK.  The contracts are P256's -- P384 had none, and inherits them by
--  instantiating.  They are load-bearing, not decorative: GNATprove inlines a
--  CONTRACT-LESS subprogram into its caller, and transitively inlining
--  Mont_Mul's nested CIOS loops through Dbl/Add into Scalar_Mul's 256
--  iterations builds a verification condition for Verify that does not
--  converge.  A contract -- any contract -- makes the call opaque, so the
--  callee is proved once on its own and the caller reasons from it.  Being in
--  a separate unit now makes them opaque anyway; the aspects are kept because
--  they say something true and cost nothing.
generic
   --  Limbs * 32 = the modulus width in bits: 8 for P-256, 12 for P-384.
   Limbs : Positive;
package ECC_Bignum with SPARK_Mode => On is

   subtype U32 is Unsigned_32;
   subtype U64 is Unsigned_64;

   type Num is array (0 .. Limbs - 1) of U32;   --  little-endian (0 = LSW)

   Zero : constant Num := (others => 0);
   One  : constant Num := (0 => 1, others => 0);

   function Is_Zero (A : Num) return Boolean
     with Global => null,
          Post   => Is_Zero'Result = (for all I in Num'Range => A (I) = 0);

   function "=" (A, B : Num) return Boolean
     with Global => null,
          Post   => "="'Result = (for all I in Num'Range => A (I) = B (I));

   --  A >= B, as a lexicographic scan from the most significant limb down: the
   --  first limb where they differ decides.  Geq_Spec pins that meaning down so
   --  a future edit that inverts the scan direction, or compares from limb 0,
   --  fails the proof rather than silently weakening the range checks in Verify
   --  that gate r, s and the public-key coordinates.  Nothing CONSUMES it:
   --  Verify reasons from the Global aspects, not from this.
   function Geq_Spec (A, B : Num) return Boolean
   is ((for all I in Num'Range => A (I) = B (I))
       or else (for some I in Num'Range =>
                  A (I) > B (I)
                  and then (for all K in I + 1 .. Num'Last => A (K) = B (K))))
   with Ghost, Global => null;

   function Geq (A, B : Num) return Boolean
     with Global => null,
          Post   => Geq'Result = Geq_Spec (A, B);

   --  A - B mod 2^(Limbs*32) (drops the final borrow).
   function Sub_Raw (A, B : Num) return Num
     with Global => null;

   --  A + B; sets Carry to the bit above the top limb.
   procedure Add_Raw (A, B : Num; R : out Num; Carry : out U64)
     with Global => null;

   --  (A + B) mod M, for A, B < M.
   function Add_Mod (A, B, M : Num) return Num
     with Global => null;

   --  (A - B) mod M, for A, B < M.
   function Sub_Mod (A, B, M : Num) return Num
     with Global => null;

   ---------------------------------------------------------------------------
   --  Montgomery arithmetic (CIOS).  R = 2^(Limbs*32).
   ---------------------------------------------------------------------------

   --  X^-1 mod 2^32 (X odd), Newton's iteration.
   function Inv32 (X : U32) return U32
     with Global => null,
          Pre    => X mod 2 = 1;         --  Newton needs an odd X to converge

   --  CIOS Montgomery multiply: returns A*B*R^-1 mod M (A, B < M).
   function Mont_Mul (A, B, M : Num; M0 : U32) return Num
     with Global => null;

   --  R^2 mod M, by 2*Limbs*32 modular doublings (add/sub only).
   function Compute_R2 (M : Num) return Num
     with Global => null;

   --  a*R mod M.
   function To_Mont (A, M : Num; M0 : U32; R2 : Num) return Num
   is (Mont_Mul (A, R2, M, M0))
   with Global => null;

   --  a^E mod M with a, result in Montgomery form (E a plain Num, MSB..LSB).
   function Mont_Pow (A_M, E, M : Num; M0 : U32; One_M : Num) return Num
     with Global => null;

   --  Modular inverse of A (plain) mod M, returned plain.  Fermat: A^(M-2).
   function Inv_Mod (A, M : Num; M0 : U32; R2, One_M : Num) return Num
     with Global => null,
          Pre    => M (0) >= 2;          --  so M - 2 does not borrow (M odd)

   --  (A * B) mod M, plain in, plain out.  (aR)*b*R^-1 = ab.
   function Mul_Mod (A, B, M : Num; M0 : U32; R2 : Num) return Num
   is (Mont_Mul (Mont_Mul (A, R2, M, M0), B, M, M0))
   with Global => null;

end ECC_Bignum;
