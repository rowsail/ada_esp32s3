with ECC_Bignum;
with ECC_Curve;
with Interfaces; use Interfaces;

--  The 32-bit-limb modular arithmetic this is built on -- Add_Mod through
--  Mul_Mod -- is the generic ECC_Bignum, instantiated below at twelve limbs;
--  P256 instantiates the same generic at eight.  Widening a curve is therefore
--  a change of one number rather than a second copy of CIOS: the two bounds
--  that used to be written out per curve (the exponent scan in Mont_Pow, the
--  doubling count in Compute_R2) are derived from the limb count inside the
--  generic.
package body P384 with SPARK_Mode => On is

   --  The modular arithmetic, at 384 bits.  Only the CONSTANTS below are
   --  P-384's; they are derived from the generic's Inv32 and Compute_R2.
   package BN is new ECC_Bignum (Limbs => 12);   --  12 x 32 = 384 bit
   use BN;

   ---------------------------------------------------------------------------
   --  Curve parameters (NIST P-384), little-endian limbs.
   ---------------------------------------------------------------------------
   P : constant Num :=
     (16#FFFFFFFF#, 16#00000000#, 16#00000000#, 16#FFFFFFFF#,
      16#FFFFFFFE#, 16#FFFFFFFF#, 16#FFFFFFFF#, 16#FFFFFFFF#,
      16#FFFFFFFF#, 16#FFFFFFFF#, 16#FFFFFFFF#, 16#FFFFFFFF#);
   NN : constant Num :=
     (16#CCC52973#, 16#ECEC196A#, 16#48B0A77A#, 16#581A0DB2#,
      16#F4372DDF#, 16#C7634D81#, 16#FFFFFFFF#, 16#FFFFFFFF#,
      16#FFFFFFFF#, 16#FFFFFFFF#, 16#FFFFFFFF#, 16#FFFFFFFF#);
   B : constant Num :=
     (16#D3EC2AEF#, 16#2A85C8ED#, 16#8A2ED19D#, 16#C656398D#,
      16#5013875A#, 16#0314088F#, 16#FE814112#, 16#181D9C6E#,
      16#E3F82D19#, 16#988E056B#, 16#E23EE7E4#, 16#B3312FA7#);
   GX : constant Num :=
     (16#72760AB7#, 16#3A545E38#, 16#BF55296C#, 16#5502F25D#,
      16#82542A38#, 16#59F741E0#, 16#8BA79B98#, 16#6E1D3B62#,
      16#F320AD74#, 16#8EB1C71E#, 16#BE8B0537#, 16#AA87CA22#);
   GY : constant Num :=
     (16#90EA0E5F#, 16#7A431D7C#, 16#1D7E819D#, 16#0A60B1CE#,
      16#B5F0B8C0#, 16#E9DA3113#, 16#289A147C#, 16#F8F41DBD#,
      16#9292DC29#, 16#5D9E98BF#, 16#96262C6F#, 16#3617DE4A#);

   --  Per-modulus Montgomery constants.
   P_M0 : constant U32 := U32 (0) - Inv32 (P (0));
   N_M0 : constant U32 := U32 (0) - Inv32 (NN (0));
   P_R2 : constant Num := Compute_R2 (P);
   N_R2 : constant Num := Compute_R2 (NN);

   --  Montgomery form of 1 (= R mod M).
   P_One_M : constant Num := To_Mont (One, P, P_M0, P_R2);

   --  The point arithmetic, at P-384's constants.  Point, Infinity, Dbl, Add,
   --  Scalar_Mul, To_Jacobian and On_Curve all come from here -- the same
   --  generic P256 instantiates, and with it the SPARK contracts this curve
   --  did not previously carry.
   package CV is new ECC_Curve
     (BN => BN, P => P, P_M0 => P_M0, P_R2 => P_R2, P_One_M => P_One_M,
      Curve_B => B);
   use CV;

   ---------------------------------------------------------------------------
   --  Conversions.
   ---------------------------------------------------------------------------
   --  48 big-endian bytes -> Num.
   function From_BE (Bz : Bytes_48) return Num is
      R : Num;
   begin
      for I in Num'Range loop
         --  word I = bytes [44-4I .. 47-4I]
         R (I) :=
           Shift_Left (U32 (Bz (44 - 4 * I)), 24)
           or Shift_Left (U32 (Bz (45 - 4 * I)), 16)
           or Shift_Left (U32 (Bz (46 - 4 * I)), 8)
           or U32 (Bz (47 - 4 * I));
      end loop;
      return R;
   end From_BE;


   ---------------------------------------------------------------------------
   --  ECDSA verification.
   ---------------------------------------------------------------------------
   function Verify
     (Key : Public_Point; Sig : Signature; Hash : Bytes_48) return Boolean
   is
      Qx             : constant Num := From_BE (Key.X);
      Qy             : constant Num := From_BE (Key.Y);
      Rr             : constant Num := From_BE (Sig.R);
      Ss             : constant Num := From_BE (Sig.S);
      E              : Num := From_BE (Hash);
      W, U1, U2, Vx  : Num;
      G_Pt, Q_Pt, RP : Point;
      Zinv, Z2inv    : Num;
   begin
      --  r, s must be in [1, n-1].
      if Is_Zero (Rr) or else Geq (Rr, NN) or else Is_Zero (Ss) or else Geq (Ss, NN) then
         return False;
      end if;
      --  Public key on the curve and in range.
      if Geq (Qx, P) or else Geq (Qy, P) or else not On_Curve (Qx, Qy) then
         return False;
      end if;
      if Geq (E, NN) then
         E := Sub_Raw (E, NN);
      end if;   --  e mod n (e < 2^384 < 2n)

      W := Inv_Mod (Ss, NN, N_M0, N_R2, To_Mont (One, NN, N_M0, N_R2));
      U1 := Mul_Mod (E, W, NN, N_M0, N_R2);
      U2 := Mul_Mod (Rr, W, NN, N_M0, N_R2);

      G_Pt := To_Jacobian (GX, GY);
      Q_Pt := To_Jacobian (Qx, Qy);
      RP := Add (Scalar_Mul (U1, G_Pt), Scalar_Mul (U2, Q_Pt));
      if Is_Zero (RP.Z) then
         return False;
      end if;

      --  Affine x = X / Z^2 (in Montgomery), then back to plain.
      Zinv := Mont_Pow (RP.Z, Sub_Raw (P, (0 => 2, others => 0)), P, P_M0, P_One_M);
      Z2inv := FMul (Zinv, Zinv);
      Vx := FMul (RP.X, Z2inv);
      Vx := Mont_Mul (Vx, One, P, P_M0);                --  out of Montgomery
      if Geq (Vx, NN) then
         Vx := Sub_Raw (Vx, NN);
      end if;  --  x mod n
      return Vx = Rr;
   end Verify;

end P384;
