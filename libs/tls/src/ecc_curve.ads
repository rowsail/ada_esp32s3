with ECC_Bignum;

--  Short-Weierstrass point arithmetic over GF(p) for a curve with a = -3 --
--  the NIST prime curves.  Points are Jacobian with Montgomery-form
--  coordinates; Z = 0 is the point at infinity.
--
--  This is the second half of what P256 and P384 used to hold a copy of each.
--  ECC_Bignum supplies the modular arithmetic; what is left curve-specific is
--  five values, and they arrive as generic formals.  Everything below is
--  written in terms of them, so the only thing that distinguishes P-256 from
--  P-384 here is the instantiation -- including Scalar_Mul's scan length,
--  which is BN.Limbs * 32 - 1 rather than a per-curve literal.
--
--  NOT here: From_BE / To_BE (they name each curve's own big-endian byte
--  type) and Verify (which composes them).  Those stay with the curve.
--
--  SPARK.  The contracts are P256's; P384 inherits them by instantiating, so
--  its point arithmetic is now proved rather than merely assumed to match.
--  See ECC_Bignum for why `Global => null` on each of these is load-bearing
--  and not decoration.
generic
   with package BN is new ECC_Bignum (<>);

   --  The field modulus p, and the Montgomery constants derived from it:
   --  -p^-1 mod 2^32, R^2 mod p, and R mod p (Montgomery 1).
   P       : BN.Num;
   P_M0    : BN.U32;
   P_R2    : BN.Num;
   P_One_M : BN.Num;

   --  The curve's b, plain (not Montgomery): y^2 = x^3 - 3x + b mod p.
   Curve_B : BN.Num;
package ECC_Curve with SPARK_Mode => On is

   use BN;

   ---------------------------------------------------------------------------
   --  Jacobian point arithmetic over GF(p); coordinates in Montgomery form.
   --  Z = 0 marks the point at infinity.
   ---------------------------------------------------------------------------
   type Point is record
      X, Y, Z : Num;
   end record;
   Infinity : constant Point := (Zero, Zero, Zero);

   function FMul (A, B : Num) return Num
   is (Mont_Mul (A, B, P, P_M0))
   with Global => null;
   function FAdd (A, B : Num) return Num
   is (Add_Mod (A, B, P))
   with Global => null;
   function FSub (A, B : Num) return Num
   is (Sub_Mod (A, B, P))
   with Global => null;
   function FDbl (A : Num) return Num
   is (Add_Mod (A, A, P))
   with Global => null;

   --  Jacobian doubling (a = -3): the "dbl-2001-b" formulas.
   function Dbl (Q : Point) return Point
     with Global => null;

   --  Jacobian point addition ("add-2007-bl"), with the doubling and
   --  point-at-infinity cases handled explicitly.
   function Add (P1, P2 : Point) return Point
     with Global => null;

   --  K (plain scalar) times Q, double-and-add (MSB..LSB; variable-time is
   --  fine -- every input here is public).
   function Scalar_Mul (K : Num; Q : Point) return Point
     with Global => null;

   --  Affine (plain x, y) -> Jacobian with Montgomery coords (Z = 1).
   function To_Jacobian (X, Y : Num) return Point
   is (X => Mont_Mul (X, P_R2, P, P_M0), Y => Mont_Mul (Y, P_R2, P, P_M0), Z => P_One_M)
   with Global => null;

   --  Is (x, y) (plain affine) on the curve y^2 = x^3 - 3x + b mod p?
   function On_Curve (X, Y : Num) return Boolean
     with Global => null;

end ECC_Curve;
