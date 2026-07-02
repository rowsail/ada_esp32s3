with Interfaces; use Interfaces;
with SPARKNaCl;
with SPARKNaCl.Hashing.SHA256;

package body P256 is

   subtype U32 is Unsigned_32;
   subtype U64 is Unsigned_64;

   Limbs : constant := 8;                       --  8 x 32 = 256 bit
   type Num is array (0 .. Limbs - 1) of U32;   --  little-endian limbs (0 = LSW)

   Zero : constant Num := (others => 0);
   One  : constant Num := (0 => 1, others => 0);

   ---------------------------------------------------------------------------
   --  Curve parameters (NIST P-256), little-endian limbs.
   ---------------------------------------------------------------------------
   P  : constant Num :=
     (16#FFFFFFFF#,
      16#FFFFFFFF#,
      16#FFFFFFFF#,
      16#00000000#,
      16#00000000#,
      16#00000000#,
      16#00000001#,
      16#FFFFFFFF#);
   NN : constant Num :=
     (16#FC632551#,
      16#F3B9CAC2#,
      16#A7179E84#,
      16#BCE6FAAD#,
      16#FFFFFFFF#,
      16#FFFFFFFF#,
      16#00000000#,
      16#FFFFFFFF#);
   B  : constant Num :=
     (16#27D2604B#,
      16#3BCE3C3E#,
      16#CC53B0F6#,
      16#651D06B0#,
      16#769886BC#,
      16#B3EBBD55#,
      16#AA3A93E7#,
      16#5AC635D8#);
   GX : constant Num :=
     (16#D898C296#,
      16#F4A13945#,
      16#2DEB33A0#,
      16#77037D81#,
      16#63A440F2#,
      16#F8BCE6E5#,
      16#E12C4247#,
      16#6B17D1F2#);
   GY : constant Num :=
     (16#37BF51F5#,
      16#CBB64068#,
      16#6B315ECE#,
      16#2BCE3357#,
      16#7C0F9E16#,
      16#8EE7EB4A#,
      16#FE1A7F9B#,
      16#4FE342E2#);

   ---------------------------------------------------------------------------
   --  Plain 256-bit helpers.
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

   --  A - B mod 2^256 (drops the final borrow).
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

   --  A + B; sets Carry to the 257th bit.
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
            Add_Raw (Sub_Raw (A, B), M, R, C);   --  (A - B + 2^256) + M, keep low
            return R;
         end;
      end if;
   end Sub_Mod;

   ---------------------------------------------------------------------------
   --  Montgomery arithmetic (CIOS).  R = 2^256.
   ---------------------------------------------------------------------------

   --  X^-1 mod 2^32 (X odd), Newton's iteration.
   function Inv32 (X : U32) return U32 is
      Y : U32 := X;
   begin
      for I in 1 .. 5 loop
         Y := Y * (2 - X * Y);          --  doubles the number of correct bits
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

   --  R^2 mod M = 2^512 mod M, by 512 modular doublings (add/sub only).
   function Compute_R2 (M : Num) return Num is
      X : Num := One;
   begin
      for I in 1 .. 512 loop
         X := Add_Mod (X, X, M);
      end loop;
      return X;
   end Compute_R2;

   --  Per-modulus Montgomery constants.
   P_M0 : constant U32 := U32 (0) - Inv32 (P (0));    --  -P^-1 mod 2^32
   N_M0 : constant U32 := U32 (0) - Inv32 (NN (0));
   P_R2 : constant Num := Compute_R2 (P);
   N_R2 : constant Num := Compute_R2 (NN);

   function To_Mont (A, M : Num; M0 : U32; R2 : Num) return Num
   is (Mont_Mul (A, R2, M, M0));                       --  a*R mod M

   --  Montgomery form of 1 (= R mod M).
   P_One_M : constant Num := To_Mont (One, P, P_M0, P_R2);

   --  a^E mod M with a, result in Montgomery form (E a plain Num, MSB..LSB).
   function Mont_Pow (A_M, E, M : Num; M0 : U32; One_M : Num) return Num is
      R : Num := One_M;
   begin
      for I in reverse 0 .. 255 loop
         R := Mont_Mul (R, R, M, M0);
         if (Shift_Right (E (I / 32), I mod 32) and 1) = 1 then
            R := Mont_Mul (R, A_M, M, M0);
         end if;
      end loop;
      return R;
   end Mont_Pow;

   --  Modular inverse of A (plain) mod M, returned plain.  Fermat: A^(M-2).
   function Inv_Mod (A, M : Num; M0 : U32; R2, One_M : Num) return Num is
      A_M  : constant Num := Mont_Mul (A, R2, M, M0);    --  to Montgomery
      Emin : Num := M;
      Inv  : Num;
   begin
      Emin := Sub_Raw (Emin, (0 => 2, others => 0));     --  M - 2 (M odd, M(0) >= 3)
      Inv := Mont_Pow (A_M, Emin, M, M0, One_M);         --  (a^-1) in Montgomery
      return Mont_Mul (Inv, One, M, M0);                 --  back to plain
   end Inv_Mod;

   --  (A * B) mod M, plain in, plain out.
   function Mul_Mod (A, B, M : Num; M0 : U32; R2 : Num) return Num
   is (Mont_Mul (Mont_Mul (A, R2, M, M0), B, M, M0));     --  (aR)*b*R^-1 = ab

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
      Dlt := FMul (Q.Z, Q.Z);                 --  Z^2
      Gamma := FMul (Q.Y, Q.Y);                 --  Y^2
      Beta := FMul (Q.X, Gamma);               --  X*Y^2
      --  alpha = 3*(X-delta)*(X+delta)
      Alpha := FMul (FSub (Q.X, Dlt), FAdd (Q.X, Dlt));
      Alpha := FAdd (FDbl (Alpha), Alpha);      --  *3
      --  X3 = alpha^2 - 8*beta
      T := FDbl (FDbl (FDbl (Beta)));           --  8*beta
      X3 := FSub (FMul (Alpha, Alpha), T);
      --  Z3 = (Y+Z)^2 - gamma - delta
      Z3 := FMul (FAdd (Q.Y, Q.Z), FAdd (Q.Y, Q.Z));
      Z3 := FSub (FSub (Z3, Gamma), Dlt);
      --  Y3 = alpha*(4*beta - X3) - 8*gamma^2
      T := FSub (FDbl (FDbl (Beta)), X3);       --  4*beta - X3
      G2 := FMul (Gamma, Gamma);
      G2 := FDbl (FDbl (FDbl (G2)));             --  8*gamma^2
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
            return Infinity;                     --  P + (-P)
         end if;
      end if;
      H := FSub (U2, U1);
      I := FDbl (H);
      I := FMul (I, I);          --  (2H)^2
      J := FMul (H, I);
      Rr := FDbl (FSub (S2, S1));                 --  2*(S2-S1)
      V := FMul (U1, I);
      --  X3 = r^2 - J - 2V
      X3 := FSub (FSub (FMul (Rr, Rr), J), FDbl (V));
      --  Y3 = r*(V - X3) - 2*S1*J
      T := FMul (FDbl (S1), J);
      Y3 := FSub (FMul (Rr, FSub (V, X3)), T);
      --  Z3 = ((Z1+Z2)^2 - Z1Z1 - Z2Z2) * H
      Z3 := FMul (FAdd (P1.Z, P2.Z), FAdd (P1.Z, P2.Z));
      Z3 := FMul (FSub (FSub (Z3, Z1Z1), Z2Z2), H);
      return (X3, Y3, Z3);
   end Add;

   --  K (plain scalar) times P, double-and-add (MSB..LSB; variable-time is fine).
   function Scalar_Mul (K : Num; Q : Point) return Point is
      R : Point := Infinity;
   begin
      for I in reverse 0 .. 255 loop
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
   --  32 big-endian bytes -> Num.
   function From_BE (Bz : Bytes_32) return Num is
      R : Num;
   begin
      for I in 0 .. Limbs - 1 loop
         --  word I = bytes [28-4I .. 31-4I]
         R (I) :=
           Shift_Left (U32 (Bz (28 - 4 * I)), 24)
           or Shift_Left (U32 (Bz (29 - 4 * I)), 16)
           or Shift_Left (U32 (Bz (30 - 4 * I)), 8)
           or U32 (Bz (31 - 4 * I));
      end loop;
      return R;
   end From_BE;

   --  Affine (plain x, y) -> Jacobian with Montgomery coords (Z = 1).
   function To_Jacobian (X, Y : Num) return Point
   is (X => Mont_Mul (X, P_R2, P, P_M0), Y => Mont_Mul (Y, P_R2, P, P_M0), Z => P_One_M);

   --  Is (x, y) (plain affine) on the curve y^2 = x^3 - 3x + b mod p?
   function On_Curve (X, Y : Num) return Boolean is
      XM  : constant Num := Mont_Mul (X, P_R2, P, P_M0);
      YM  : constant Num := Mont_Mul (Y, P_R2, P, P_M0);
      BM  : constant Num := Mont_Mul (B, P_R2, P, P_M0);
      LHS : constant Num := FMul (YM, YM);
      X3  : Num := FMul (FMul (XM, XM), XM);
      TX  : constant Num := FAdd (FDbl (XM), XM);         --  3x
   begin
      X3 := FAdd (FSub (X3, TX), BM);
      return LHS = X3;
   end On_Curve;

   ---------------------------------------------------------------------------
   --  ECDSA verification.
   ---------------------------------------------------------------------------
   function Verify (Pub_X, Pub_Y : Bytes_32; Hash : Bytes_32; R, S : Bytes_32) return Boolean is
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
      end if;   --  e mod n

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
      Vx := Mont_Mul (Vx, One, P, P_M0);              --  out of Montgomery
      if Geq (Vx, NN) then
         Vx := Sub_Raw (Vx, NN);
      end if;  --  x mod n
      return Vx = Rr;
   end Verify;

   ---------------------------------------------------------------------------
   --  ECDH key exchange.
   ---------------------------------------------------------------------------

   --  Num -> 32 big-endian bytes.
   function To_BE (A : Num) return Bytes_32 is
      R : Bytes_32;
   begin
      for I in 0 .. Limbs - 1 loop
         R (31 - 4 * I) := Byte (A (I) and 16#FF#);
         R (30 - 4 * I) := Byte (Shift_Right (A (I), 8) and 16#FF#);
         R (29 - 4 * I) := Byte (Shift_Right (A (I), 16) and 16#FF#);
         R (28 - 4 * I) := Byte (Shift_Right (A (I), 24) and 16#FF#);
      end loop;
      return R;
   end To_BE;

   --  Jacobian (Montgomery) -> plain affine (X, Y).  Ok False at infinity.
   procedure To_Affine (Pt : Point; AX, AY : out Num; Ok : out Boolean) is
      Zinv, Z2inv, Z3inv : Num;
   begin
      AX := Zero;
      AY := Zero;
      if Is_Zero (Pt.Z) then
         Ok := False;
         return;
      end if;
      Zinv := Mont_Pow (Pt.Z, Sub_Raw (P, (0 => 2, others => 0)), P, P_M0, P_One_M);
      Z2inv := FMul (Zinv, Zinv);
      Z3inv := FMul (Z2inv, Zinv);
      AX := Mont_Mul (FMul (Pt.X, Z2inv), One, P, P_M0);   --  x = X*Z^-2, out of Montgomery
      AY := Mont_Mul (FMul (Pt.Y, Z3inv), One, P, P_M0);   --  y = Y*Z^-3
      Ok := True;
   end To_Affine;

   function Public_Key (Priv : Bytes_32; Pub_X, Pub_Y : out Bytes_32) return Boolean is
      D      : constant Num := From_BE (Priv);
      R      : Point;
      AX, AY : Num;
      Ok     : Boolean;
   begin
      Pub_X := (others => 0);
      Pub_Y := (others => 0);
      if Is_Zero (D) or else Geq (D, NN) then
         return False;
      end if;
      R := Scalar_Mul (D, To_Jacobian (GX, GY));
      To_Affine (R, AX, AY, Ok);
      if not Ok then
         return False;
      end if;
      Pub_X := To_BE (AX);
      Pub_Y := To_BE (AY);
      return True;
   end Public_Key;

   function ECDH
     (Priv : Bytes_32; Peer_X, Peer_Y : Bytes_32; Shared_X : out Bytes_32) return Boolean
   is
      D      : constant Num := From_BE (Priv);
      QX     : constant Num := From_BE (Peer_X);
      QY     : constant Num := From_BE (Peer_Y);
      R      : Point;
      AX, AY : Num;
      Ok     : Boolean;
   begin
      Shared_X := (others => 0);
      if Is_Zero (D) or else Geq (D, NN) then
         return False;
      end if;
      if Geq (QX, P) or else Geq (QY, P) or else not On_Curve (QX, QY) then
         return False;
      end if;
      R := Scalar_Mul (D, To_Jacobian (QX, QY));
      To_Affine (R, AX, AY, Ok);
      if not Ok then
         return False;
      end if;
      Shared_X := To_BE (AX);
      return True;
   end ECDH;

   ---------------------------------------------------------------------------
   --  ECDSA signing (deterministic nonce, RFC 6979).
   ---------------------------------------------------------------------------

   --  SHA-256 of Data via SPARKNaCl.
   function SHA256 (Data : Bytes) return Bytes_32 is
      Msg : SPARKNaCl.Byte_Seq (0 .. SPARKNaCl.N32 (Data'Length - 1));
      Dg  : SPARKNaCl.Hashing.SHA256.Digest;
      R   : Bytes_32;
   begin
      for I in 0 .. Data'Length - 1 loop
         Msg (SPARKNaCl.N32 (I)) := SPARKNaCl.Byte (Data (Data'First + I));
      end loop;
      Dg := SPARKNaCl.Hashing.SHA256.Hash (Msg);
      for I in 0 .. 31 loop
         R (I) := Byte (Dg (SPARKNaCl.Index_32 (I)));
      end loop;
      return R;
   end SHA256;

   --  HMAC-SHA-256.  Keys here are always 32 bytes (the DRBG V/K), which fit in
   --  one 64-byte block, so no key-shortening hash is needed.
   HMAC_Block : constant := 64;
   function HMAC_SHA256 (Key, Msg : Bytes) return Bytes_32 is
      K0    : Bytes (0 .. HMAC_Block - 1) := (others => 0);
      Inner : Bytes (0 .. HMAC_Block - 1 + Msg'Length);
      Outer : Bytes (0 .. HMAC_Block - 1 + 32);
      H1    : Bytes_32;
   begin
      for I in 0 .. Key'Length - 1 loop
         K0 (I) := Key (Key'First + I);
      end loop;
      for I in 0 .. HMAC_Block - 1 loop
         Inner (I) := K0 (I) xor 16#36#;
      end loop;
      for I in 0 .. Msg'Length - 1 loop
         Inner (HMAC_Block + I) := Msg (Msg'First + I);
      end loop;
      H1 := SHA256 (Inner);
      for I in 0 .. HMAC_Block - 1 loop
         Outer (I) := K0 (I) xor 16#5C#;
      end loop;
      for I in 0 .. 31 loop
         Outer (HMAC_Block + I) := H1 (I);
      end loop;
      return SHA256 (Outer);
   end HMAC_SHA256;

   function Sign (Priv, Hash : Bytes_32; R, S : out Bytes_32) return Boolean is
      D       : constant Num := From_BE (Priv);
      E       : Num := From_BE (Hash);
      N_One_M : constant Num := To_Mont (One, NN, N_M0, N_R2);
      V       : Bytes_32 := (others => 16#01#);
      K       : Bytes_32 := (others => 16#00#);
      Count   : Natural := 0;
   begin
      R := (others => 0);
      S := (others => 0);
      if Is_Zero (D) or else Geq (D, NN) then
         --  private key in [1, n-1]
         return False;
      end if;
      if Geq (E, NN) then
         E := Sub_Raw (E, NN);
      end if;  --  e = hash mod n

      declare
         X_Oct : constant Bytes_32 := Priv;              --  int2octets(x)
         H_Oct : constant Bytes_32 := To_BE (E);         --  bits2octets(h1) = e mod n
         Seed  : Bytes (0 .. 96);                        --  V(32) || sep(1) || X || H
      begin
         --  RFC 6979 3.2 (b)..(g): seed the HMAC-DRBG.
         Seed (0 .. 31) := V;
         Seed (32) := 16#00#;
         Seed (33 .. 64) := X_Oct;
         Seed (65 .. 96) := H_Oct;
         K := HMAC_SHA256 (K, Seed);
         V := HMAC_SHA256 (K, V);
         Seed (0 .. 31) := V;
         Seed (32) := 16#01#;
         Seed (33 .. 64) := X_Oct;
         Seed (65 .. 96) := H_Oct;
         K := HMAC_SHA256 (K, Seed);
         V := HMAC_SHA256 (K, V);

         --  Generate candidate k = bits2int(T) until it yields a valid (r, s).
         --  hlen = qlen = 256, so one HMAC produces a full-width T.
         while Count < 64 loop
            Count := Count + 1;
            V := HMAC_SHA256 (K, V);
            declare
               Kk        : constant Num := From_BE (V);
               KG        : Point;
               AX, AY    : Num;
               Ok        : Boolean;
               Rn, Sn, T : Num;
            begin
               if not Is_Zero (Kk) and then not Geq (Kk, NN) then
                  KG := Scalar_Mul (Kk, To_Jacobian (GX, GY));   --  k*G
                  To_Affine (KG, AX, AY, Ok);
                  if Ok then
                     Rn := AX;
                     if Geq (Rn, NN) then
                        Rn := Sub_Raw (Rn, NN);
                     end if;  --  r = x mod n
                     if not Is_Zero (Rn) then
                        --  s = k^-1 (e + r*d) mod n
                        T := Mul_Mod (Rn, D, NN, N_M0, N_R2);
                        T := Add_Mod (E, T, NN);
                        Sn := Inv_Mod (Kk, NN, N_M0, N_R2, N_One_M);
                        Sn := Mul_Mod (Sn, T, NN, N_M0, N_R2);
                        if not Is_Zero (Sn) then
                           R := To_BE (Rn);
                           S := To_BE (Sn);
                           return True;
                        end if;
                     end if;
                  end if;
               end if;
            end;
            --  k rejected: reseed K, V and try the next candidate.
            declare
               M : Bytes (0 .. 32);
            begin
               M (0 .. 31) := V;
               M (32) := 16#00#;
               K := HMAC_SHA256 (K, M);
               V := HMAC_SHA256 (K, V);
            end;
         end loop;
         return False;                                   --  not reached in practice
      end;
   end Sign;

end P256;
