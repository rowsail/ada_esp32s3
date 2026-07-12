with Interfaces; use Interfaces;

package body P384 is

   subtype U32 is Unsigned_32;
   subtype U64 is Unsigned_64;

   Limbs : constant := 12;                      --  12 x 32 = 384 bit
   type Num is array (0 .. Limbs - 1) of U32;   --  little-endian limbs (0 = LSW)

   Zero : constant Num := (others => 0);
   One  : constant Num := (0 => 1, others => 0);

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

   ---------------------------------------------------------------------------
   --  Plain 384-bit helpers.
   ---------------------------------------------------------------------------
   function Is_Zero (A : Num) return Boolean is
   begin
      for I in Num'Range loop
         if A (I) /= 0 then
            return False;
         end if;
      end loop;
      return True;
   end Is_Zero;

   function "=" (A, B : Num) return Boolean is
   begin
      for I in Num'Range loop
         if A (I) /= B (I) then
            return False;
         end if;
      end loop;
      return True;
   end "=";

   --  A >= B ?
   function Geq (A, B : Num) return Boolean is
   begin
      for I in reverse Num'Range loop
         if A (I) /= B (I) then
            return A (I) > B (I);
         end if;
      end loop;
      return True;
   end Geq;

   --  A - B mod 2^384 (drops the final borrow).
   function Sub_Raw (A, B : Num) return Num is
      R   : Num;
      Bor : U64 := 0;
      D   : U64;
   begin
      for I in Num'Range loop
         D := (U64 (A (I)) - U64 (B (I)) - Bor) and 16#FFFF_FFFF_FFFF_FFFF#;
         R (I) := U32 (D and 16#FFFF_FFFF#);
         Bor := (if U64 (A (I)) < U64 (B (I)) + Bor then 1 else 0);
      end loop;
      return R;
   end Sub_Raw;

   --  A + B; sets Carry to the 385th bit.
   procedure Add_Raw (A, B : Num; R : out Num; Carry : out U64) is
      S : U64 := 0;
   begin
      for I in Num'Range loop
         S := U64 (A (I)) + U64 (B (I)) + S;
         R (I) := U32 (S and 16#FFFF_FFFF#);
         S := Shift_Right (S, 32);
      end loop;
      Carry := S;
   end Add_Raw;

   --  (A + B) mod M, for A, B < M.
   function Add_Mod (A, B, M : Num) return Num is
      R : Num;
      C : U64;
   begin
      Add_Raw (A, B, R, C);
      if C /= 0 or else Geq (R, M) then
         R := Sub_Raw (R, M);
      end if;
      return R;
   end Add_Mod;

   --  (A - B) mod M, for A, B < M.
   function Sub_Mod (A, B, M : Num) return Num is
   begin
      if Geq (A, B) then
         return Sub_Raw (A, B);
      else
         declare
            R : Num;
            C : U64;
         begin
            Add_Raw (Sub_Raw (A, B), M, R, C);
            return R;
         end;
      end if;
   end Sub_Mod;

   ---------------------------------------------------------------------------
   --  Montgomery arithmetic (CIOS).  R = 2^384.
   ---------------------------------------------------------------------------

   --  X^-1 mod 2^32 (X odd), Newton's iteration.
   function Inv32 (X : U32) return U32 is
      Y : U32 := X;
   begin
      for I in 1 .. 5 loop
         Y := Y * (2 - X * Y);
      end loop;
      return Y;
   end Inv32;

   --  CIOS Montgomery multiply: returns A*B*R^-1 mod M (A, B < M).
   function Mont_Mul (A, B, M : Num; M0 : U32) return Num is
      T  : array (0 .. Limbs + 1) of U32 := (others => 0);
      CS : U64;
      Cr : U64;
      MM : U64;
      R  : Num;
   begin
      for I in 0 .. Limbs - 1 loop
         Cr := 0;
         for J in 0 .. Limbs - 1 loop
            CS := U64 (T (J)) + U64 (A (J)) * U64 (B (I)) + Cr;
            T (J) := U32 (CS and 16#FFFF_FFFF#);
            Cr := Shift_Right (CS, 32);
         end loop;
         CS := U64 (T (Limbs)) + Cr;
         T (Limbs) := U32 (CS and 16#FFFF_FFFF#);
         T (Limbs + 1) := U32 (Shift_Right (CS, 32));

         MM := (U64 (T (0)) * U64 (M0)) and 16#FFFF_FFFF#;
         CS := U64 (T (0)) + MM * U64 (M (0));
         Cr := Shift_Right (CS, 32);
         for J in 1 .. Limbs - 1 loop
            CS := U64 (T (J)) + MM * U64 (M (J)) + Cr;
            T (J - 1) := U32 (CS and 16#FFFF_FFFF#);
            Cr := Shift_Right (CS, 32);
         end loop;
         CS := U64 (T (Limbs)) + Cr;
         T (Limbs - 1) := U32 (CS and 16#FFFF_FFFF#);
         T (Limbs) := T (Limbs + 1) + U32 (Shift_Right (CS, 32));
         T (Limbs + 1) := 0;
      end loop;
      for K in Num'Range loop
         R (K) := T (K);
      end loop;
      if T (Limbs) /= 0 or else Geq (R, M) then
         R := Sub_Raw (R, M);
      end if;
      return R;
   end Mont_Mul;

   --  R^2 mod M = 2^768 mod M, by 768 modular doublings (add/sub only).
   function Compute_R2 (M : Num) return Num is
      X : Num := One;
   begin
      for I in 1 .. 768 loop
         X := Add_Mod (X, X, M);
      end loop;
      return X;
   end Compute_R2;

   --  Per-modulus Montgomery constants.
   P_M0 : constant U32 := U32 (0) - Inv32 (P (0));
   N_M0 : constant U32 := U32 (0) - Inv32 (NN (0));
   P_R2 : constant Num := Compute_R2 (P);
   N_R2 : constant Num := Compute_R2 (NN);

   function To_Mont (A, M : Num; M0 : U32; R2 : Num) return Num
   is (Mont_Mul (A, R2, M, M0));

   P_One_M : constant Num := To_Mont (One, P, P_M0, P_R2);

   --  a^E mod M with a, result in Montgomery form (E a plain Num, MSB..LSB).
   function Mont_Pow (A_M, E, M : Num; M0 : U32; One_M : Num) return Num is
      R : Num := One_M;
   begin
      for I in reverse 0 .. 383 loop
         R := Mont_Mul (R, R, M, M0);
         if (Shift_Right (E (I / 32), I mod 32) and 1) = 1 then
            R := Mont_Mul (R, A_M, M, M0);
         end if;
      end loop;
      return R;
   end Mont_Pow;

   --  Modular inverse of A (plain) mod M, returned plain.  Fermat: A^(M-2).
   function Inv_Mod (A, M : Num; M0 : U32; R2, One_M : Num) return Num is
      A_M  : constant Num := Mont_Mul (A, R2, M, M0);
      Emin : Num := M;
      Inv  : Num;
   begin
      Emin := Sub_Raw (Emin, (0 => 2, others => 0));     --  M - 2
      Inv := Mont_Pow (A_M, Emin, M, M0, One_M);
      return Mont_Mul (Inv, One, M, M0);
   end Inv_Mod;

   --  (A * B) mod M, plain in, plain out.
   function Mul_Mod (A, B, M : Num; M0 : U32; R2 : Num) return Num
   is (Mont_Mul (Mont_Mul (A, R2, M, M0), B, M, M0));

   ---------------------------------------------------------------------------
   --  Jacobian point arithmetic over GF(p); coordinates in Montgomery form.
   --  Z = 0 marks the point at infinity.
   ---------------------------------------------------------------------------
   type Point is record
      X, Y, Z : Num;
   end record;
   Infinity : constant Point := (Zero, Zero, Zero);

   function FMul (A, B : Num) return Num
   is (Mont_Mul (A, B, P, P_M0));
   function FAdd (A, B : Num) return Num
   is (Add_Mod (A, B, P));
   function FSub (A, B : Num) return Num
   is (Sub_Mod (A, B, P));
   function FDbl (A : Num) return Num
   is (Add_Mod (A, A, P));

   function Dbl (Q : Point) return Point is
      Dlt, Gamma, Beta, Alpha, T, X3, Y3, Z3, G2 : Num;
   begin
      if Is_Zero (Q.Z) or else Is_Zero (Q.Y) then
         return Infinity;
      end if;
      Dlt := FMul (Q.Z, Q.Z);
      Gamma := FMul (Q.Y, Q.Y);
      Beta := FMul (Q.X, Gamma);
      Alpha := FMul (FSub (Q.X, Dlt), FAdd (Q.X, Dlt));
      Alpha := FAdd (FDbl (Alpha), Alpha);              --  *3
      T := FDbl (FDbl (FDbl (Beta)));                   --  8*beta
      X3 := FSub (FMul (Alpha, Alpha), T);
      Z3 := FMul (FAdd (Q.Y, Q.Z), FAdd (Q.Y, Q.Z));
      Z3 := FSub (FSub (Z3, Gamma), Dlt);
      T := FSub (FDbl (FDbl (Beta)), X3);               --  4*beta - X3
      G2 := FMul (Gamma, Gamma);
      G2 := FDbl (FDbl (FDbl (G2)));                    --  8*gamma^2
      Y3 := FSub (FMul (Alpha, T), G2);
      return (X3, Y3, Z3);
   end Dbl;

   function Add (P1, P2 : Point) return Point is
      Z1Z1, Z2Z2, U1, U2, S1, S2, H, I, J, Rr, V, X3, Y3, Z3, T : Num;
   begin
      if Is_Zero (P1.Z) then
         return P2;
      end if;
      if Is_Zero (P2.Z) then
         return P1;
      end if;
      Z1Z1 := FMul (P1.Z, P1.Z);
      Z2Z2 := FMul (P2.Z, P2.Z);
      U1 := FMul (P1.X, Z2Z2);
      U2 := FMul (P2.X, Z1Z1);
      S1 := FMul (FMul (P1.Y, P2.Z), Z2Z2);
      S2 := FMul (FMul (P2.Y, P1.Z), Z1Z1);
      if U1 = U2 then
         if S1 = S2 then
            return Dbl (P1);
         else
            return Infinity;                            --  P + (-P)
         end if;
      end if;
      H := FSub (U2, U1);
      I := FDbl (H);
      I := FMul (I, I);                                 --  (2H)^2
      J := FMul (H, I);
      Rr := FDbl (FSub (S2, S1));                       --  2*(S2-S1)
      V := FMul (U1, I);
      X3 := FSub (FSub (FMul (Rr, Rr), J), FDbl (V));
      T := FMul (FDbl (S1), J);
      Y3 := FSub (FMul (Rr, FSub (V, X3)), T);
      Z3 := FMul (FAdd (P1.Z, P2.Z), FAdd (P1.Z, P2.Z));
      Z3 := FMul (FSub (FSub (Z3, Z1Z1), Z2Z2), H);
      return (X3, Y3, Z3);
   end Add;

   --  K (plain scalar) times P, double-and-add (MSB..LSB; variable-time OK).
   function Scalar_Mul (K : Num; Q : Point) return Point is
      R : Point := Infinity;
   begin
      for I in reverse 0 .. 383 loop
         R := Dbl (R);
         if (Shift_Right (K (I / 32), I mod 32) and 1) = 1 then
            R := Add (R, Q);
         end if;
      end loop;
      return R;
   end Scalar_Mul;

   ---------------------------------------------------------------------------
   --  Conversions.
   ---------------------------------------------------------------------------
   --  48 big-endian bytes -> Num.
   function From_BE (Bz : Bytes_48) return Num is
      R : Num;
   begin
      for I in 0 .. Limbs - 1 loop
         --  word I = bytes [44-4I .. 47-4I]
         R (I) :=
           Shift_Left (U32 (Bz (44 - 4 * I)), 24)
           or Shift_Left (U32 (Bz (45 - 4 * I)), 16)
           or Shift_Left (U32 (Bz (46 - 4 * I)), 8)
           or U32 (Bz (47 - 4 * I));
      end loop;
      return R;
   end From_BE;

   --  Affine (plain x, y) -> Jacobian with Montgomery coords (Z = 1).
   function To_Jacobian (X, Y : Num) return Point
   is (X => Mont_Mul (X, P_R2, P, P_M0),
       Y => Mont_Mul (Y, P_R2, P, P_M0),
       Z => P_One_M);

   --  Is (x, y) (plain affine) on the curve y^2 = x^3 - 3x + b mod p?
   function On_Curve (X, Y : Num) return Boolean is
      XM  : constant Num := Mont_Mul (X, P_R2, P, P_M0);
      YM  : constant Num := Mont_Mul (Y, P_R2, P, P_M0);
      BM  : constant Num := Mont_Mul (B, P_R2, P, P_M0);
      LHS : constant Num := FMul (YM, YM);
      X3  : Num := FMul (FMul (XM, XM), XM);
      TX  : constant Num := FAdd (FDbl (XM), XM);        --  3x
   begin
      X3 := FAdd (FSub (X3, TX), BM);
      return LHS = X3;
   end On_Curve;

   ---------------------------------------------------------------------------
   --  ECDSA verification.
   ---------------------------------------------------------------------------
   function Verify
     (Pub_X, Pub_Y : Bytes_48; Hash : Bytes_48; R, S : Bytes_48) return Boolean
   is
      Qx             : constant Num := From_BE (Pub_X);
      Qy             : constant Num := From_BE (Pub_Y);
      Rr             : constant Num := From_BE (R);
      Ss             : constant Num := From_BE (S);
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
