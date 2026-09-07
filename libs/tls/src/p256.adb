with ECC_Bignum;
with ECC_Curve;
with Interfaces; use Interfaces;
with SPARKNaCl;
with SPARKNaCl.Hashing.SHA256;

--  The field arithmetic, the point arithmetic AND the Verify / On_Curve
--  compositions on top of them are proved free of run-time errors
--  (libs/tls/p256_prove.gpr, run by book/prove/prove.sh).  The RFC-6979 signing
--  path (SHA256/HMAC_SHA256/Sign) calls into SPARKNaCl hashing and carries
--  SPARK_Mode => Off, as do Public_Key/ECDH/Sign -- not for want of proof but
--  because a SPARK function may not have out parameters, which those three do.
--
--  Almost none of that arithmetic is in THIS file.  The modular big-integer
--  layer (Add_Mod through Mul_Mod) is the generic ECC_Bignum and the Jacobian
--  point layer (Dbl, Add, Scalar_Mul, To_Jacobian, On_Curve) is the generic
--  ECC_Curve; both are instantiated below, at eight limbs and P-256's five
--  constants.  P384 instantiates the same two generics at twelve limbs.  What
--  is left here is the curve constants, the big-endian byte conversions (they
--  name Bytes_32, which is P-256's own type) and the compositions on top:
--  Verify, To_Affine, and the ECDH / signing paths.
--
--  Every helper carries `Global => null`.  That is a true statement -- they are
--  pure functions of their arguments -- but it is also load-bearing.  GNATprove
--  inlines a CONTRACT-LESS local subprogram into its caller, and transitively
--  inlining Mont_Mul's nested CIOS loops through Dbl/Add into Scalar_Mul's 256
--  iterations builds a verification condition for Verify that does not
--  converge.  A contract -- any contract -- makes the call opaque, so the
--  callee is proved once on its own and the caller reasons from it.  Measured
--  at --level=1 --prover=z3 --timeout=10: 210 obligations in 3m03s with
--  Verify/On_Curve outside the subset; no result after 28m with them inside and
--  no contracts; 144 obligations in 2m33s with these, and the same 144 in 2m38s
--  once the two layers moved into generics (the aspects moved with them).
--
--  `gnatprove --no-inlining` switches contextual analysis off for a whole run and
--  proves this unit with no source contracts at all (95 obligations, 2m34s).  The
--  aspects are here anyway because they travel with the source: the unit proves
--  under any project and any invocation, the cross tls.gpr included, rather than
--  only when whoever runs the tool remembers a switch.
--
--  The pre- and postconditions further down are NOT load-bearing.  Verify
--  discharges exactly one check of its own (Inv_Mod's precondition, from NN's
--  literal value) and On_Curve none, so those contracts prove nothing that the
--  Global aspects do not already give.  They are kept as documentation that the
--  compiler checks: assumptions that used to sit in comments, and the meaning of
--  three comparison predicates that gate untrusted input.
package body P256 with SPARK_Mode => On is

   --  The modular arithmetic, at 256 bits.  Everything the curve layer below
   --  calls -- Add_Mod, Mont_Mul, Inv_Mod, the Num type itself -- comes from
   --  here; only the CONSTANTS are P-256's, and they are declared once the
   --  generic's Inv32 and Compute_R2 are available to derive them.
   package BN is new ECC_Bignum (Limbs => 8);   --  8 x 32 = 256 bit
   use BN;

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

   --  Per-modulus Montgomery constants.
   P_M0 : constant U32 := U32 (0) - Inv32 (P (0));    --  -P^-1 mod 2^32
   N_M0 : constant U32 := U32 (0) - Inv32 (NN (0));
   P_R2 : constant Num := Compute_R2 (P);
   N_R2 : constant Num := Compute_R2 (NN);

   --  Montgomery form of 1 (= R mod M).
   P_One_M : constant Num := To_Mont (One, P, P_M0, P_R2);

   --  The point arithmetic, at P-256's constants.  Point, Infinity, Dbl, Add,
   --  Scalar_Mul, To_Jacobian and On_Curve all come from here; the generic is
   --  written for any a = -3 short-Weierstrass curve, and P384 instantiates it
   --  at twelve limbs with its own five constants.
   package CV is new ECC_Curve
     (BN => BN, P => P, P_M0 => P_M0, P_R2 => P_R2, P_One_M => P_One_M,
      Curve_B => B);
   use CV;

   ---------------------------------------------------------------------------
   --  Conversions.
   ---------------------------------------------------------------------------
   --  32 big-endian bytes -> Num.
   function From_BE (Bz : Bytes_32) return Num
     with Global => null
   is
      R : Num;   --  the 8 little-endian limbs assembled from the big-endian bytes
   begin
      for I in Num'Range loop
         --  word I = bytes [28-4I .. 31-4I]
         R (I) :=
           Shift_Left (U32 (Bz (28 - 4 * I)), 24)
           or Shift_Left (U32 (Bz (29 - 4 * I)), 16)
           or Shift_Left (U32 (Bz (30 - 4 * I)), 8)
           or U32 (Bz (31 - 4 * I));
      end loop;
      return R;
   end From_BE;


   ---------------------------------------------------------------------------
   --  ECDSA verification.
   ---------------------------------------------------------------------------
   function Verify (Key : Public_Point; Sig : Signature; Hash : Bytes_32) return Boolean is
      --  ECDSA verify: (Qx,Qy) public key, (Rr,Ss) the signature (r,s), E = hash,
      --  W = s^-1 mod n, U1/U2 the scalars, RP = U1*G + U2*Q, Vx = recovered x.
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
   function To_BE (A : Num) return Bytes_32
     with Global => null
   is
      R : Bytes_32 := (others => 0);   --  big-endian bytes of A (loop fills all 32;
                                       --  the init lets flow analysis see it whole)
   begin
      for I in Num'Range loop
         R (31 - 4 * I) := Byte (A (I) and 16#FF#);
         R (30 - 4 * I) := Byte (Shift_Right (A (I), 8) and 16#FF#);
         R (29 - 4 * I) := Byte (Shift_Right (A (I), 16) and 16#FF#);
         R (28 - 4 * I) := Byte (Shift_Right (A (I), 24) and 16#FF#);
      end loop;
      return R;
   end To_BE;

   --  Jacobian (Montgomery) -> plain affine (X, Y).  Ok False at infinity.
   procedure To_Affine (Pt : Point; AX, AY : out Num; Ok : out Boolean)
     with Global => null
   is
      Zinv, Z2inv, Z3inv : Num;   --  Z^-1 and its square/cube, to divide out Jacobian Z
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

   function Public_Key (Priv : Bytes_32; Pub : out Public_Point) return Boolean
     with SPARK_Mode => Off
   is
      D      : constant Num := From_BE (Priv);   --  private scalar
      R      : Point;                            --  D*G
      AX, AY : Num;                              --  affine result
      Ok     : Boolean;
   begin
      Pub := (X => (others => 0), Y => (others => 0));
      if Is_Zero (D) or else Geq (D, NN) then
         return False;
      end if;
      R := Scalar_Mul (D, To_Jacobian (GX, GY));
      To_Affine (R, AX, AY, Ok);
      if not Ok then
         return False;
      end if;
      Pub := (X => To_BE (AX), Y => To_BE (AY));
      return True;
   end Public_Key;

   function ECDH
     (Priv : Bytes_32; Peer : Public_Point; Shared_X : out Bytes_32) return Boolean
     with SPARK_Mode => Off
   is
      --  D = private scalar; (QX,QY) = peer public point; R = D*Q; (AX,AY) = shared point.
      D      : constant Num := From_BE (Priv);
      QX     : constant Num := From_BE (Peer.X);
      QY     : constant Num := From_BE (Peer.Y);
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
   function SHA256 (Data : Bytes) return Bytes_32
     with SPARK_Mode => Off   --  SPARKNaCl hashing glue (RFC-6979 path)
   is
      Msg : SPARKNaCl.Byte_Seq (0 .. SPARKNaCl.N32 (Data'Length - 1));   --  input as NaCl bytes
      Dg  : SPARKNaCl.Hashing.SHA256.Digest;                            --  digest
      R   : Bytes_32;                                                   --  digest as Bytes_32
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
   function HMAC_SHA256 (Key, Msg : Bytes) return Bytes_32
     with SPARK_Mode => Off   --  HMAC over SPARKNaCl SHA-256 (RFC-6979 path)
   is
      --  K0 = block-padded key; Inner/Outer = the two HMAC blocks; H1 = inner hash.
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

   function Sign (Priv, Hash : Bytes_32; Sig : out Signature) return Boolean
     with SPARK_Mode => Off
   is
      --  RFC 6979: D = private key, E = hash mod n, N_One_M = 1 (Montgomery, mod n);
      --  V/K = HMAC-DRBG state; Count = candidate-attempt guard.
      D       : constant Num := From_BE (Priv);
      E       : Num := From_BE (Hash);
      N_One_M : constant Num := To_Mont (One, NN, N_M0, N_R2);
      V       : Bytes_32 := (others => 16#01#);
      K       : Bytes_32 := (others => 16#00#);
      Count   : Natural := 0;
   begin
      Sig := (R => (others => 0), S => (others => 0));
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
               --  Kk = candidate nonce k; KG = k*G; (AX,AY) its affine point;
               --  Rn/Sn = signature r,s; T = (e + r*d) scratch.
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
                           Sig := (R => To_BE (Rn), S => To_BE (Sn));
                           return True;
                        end if;
                     end if;
                  end if;
               end if;
            end;
            --  k rejected: reseed K, V and try the next candidate.
            declare
               M : Bytes (0 .. 32);   --  V || 0x00, the DRBG reseed input
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
