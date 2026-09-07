package body ECC_Bignum with SPARK_Mode => On is

   function Is_Zero (A : Num) return Boolean is
   begin
      for I in Num'Range loop
         if A (I) /= 0 then
            return False;
         end if;
         pragma Loop_Invariant (for all K in Num'First .. I => A (K) = 0);
      end loop;
      return True;
   end Is_Zero;

   function "=" (A, B : Num) return Boolean is
   begin
      for I in Num'Range loop
         if A (I) /= B (I) then
            return False;
         end if;
         pragma Loop_Invariant (for all K in Num'First .. I => A (K) = B (K));
      end loop;
      return True;
   end "=";

   function Geq (A, B : Num) return Boolean is
   begin
      for I in reverse Num'Range loop
         if A (I) /= B (I) then
            return A (I) > B (I);
         end if;
         pragma Loop_Invariant (for all K in I .. Num'Last => A (K) = B (K));
      end loop;
      return True;
   end Geq;

   function Sub_Raw (A, B : Num) return Num is
      --  R = A - B mod 2^(Limbs*32); Bor = borrow out of each limb;
      --  D = per-limb difference.
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

   procedure Add_Raw (A, B : Num; R : out Num; Carry : out U64) is
      S : U64 := 0;   --  running limb sum (low 32 bits stored, high 32 carried up)
   begin
      for I in Num'Range loop
         S := U64 (A (I)) + U64 (B (I)) + S;
         R (I) := U32 (S and 16#FFFF_FFFF#);
         S := Shift_Right (S, 32);
      end loop;
      Carry := S;
   end Add_Raw;

   function Add_Mod (A, B, M : Num) return Num is
      R : Num;   --  A + B
      C : U64;   --  carry out of the top limb
   begin
      Add_Raw (A, B, R, C);
      if C /= 0 or else Geq (R, M) then
         R := Sub_Raw (R, M);
      end if;
      return R;
   end Add_Mod;

   function Sub_Mod (A, B, M : Num) return Num is
   begin
      if Geq (A, B) then
         return Sub_Raw (A, B);
      else
         declare
            R : Num;   --  wrapped difference, then + M
            C : U64;   --  discarded carry
         begin
            Add_Raw (Sub_Raw (A, B), M, R, C);   --  (A - B + R) + M, keep low
            return R;
         end;
      end if;
   end Sub_Mod;

   function Inv32 (X : U32) return U32 is
      Y : U32 := X;   --  inverse approximation; Newton doubles the correct-bit count
   begin
      for I in 1 .. 5 loop
         Y := Y * (2 - X * Y);          --  doubles the number of correct bits
      end loop;
      return Y;
   end Inv32;

   function Mont_Mul (A, B, M : Num; M0 : U32) return Num is
      --  CIOS scratch: T = wide accumulator; CS/Cr = column sum and carry;
      --  MM = reduction multiplier m = T(0)*M0 mod 2^32; R = the reduced result.
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

   function Compute_R2 (M : Num) return Num is
      X : Num := One;   --  1 doubled 2*Limbs*32 times mod M yields R^2 mod M
   begin
      for I in 1 .. 2 * Limbs * 32 loop
         X := Add_Mod (X, X, M);
      end loop;
      return X;
   end Compute_R2;

   function Mont_Pow (A_M, E, M : Num; M0 : U32; One_M : Num) return Num is
      R : Num := One_M;   --  running Montgomery product (square-and-multiply)
   begin
      for I in reverse 0 .. Limbs * 32 - 1 loop
         R := Mont_Mul (R, R, M, M0);
         if (Shift_Right (E (I / 32), I mod 32) and 1) = 1 then
            R := Mont_Mul (R, A_M, M, M0);
         end if;
      end loop;
      return R;
   end Mont_Pow;

   function Inv_Mod (A, M : Num; M0 : U32; R2, One_M : Num) return Num is
      A_M  : constant Num := Mont_Mul (A, R2, M, M0);    --  to Montgomery
      Emin : Num := M;
      Inv  : Num;
   begin
      Emin := Sub_Raw (Emin, (0 => 2, others => 0));     --  M - 2 (M odd, M(0) >= 3)
      Inv := Mont_Pow (A_M, Emin, M, M0, One_M);         --  (a^-1) in Montgomery
      return Mont_Mul (Inv, One, M, M0);                 --  back to plain
   end Inv_Mod;

end ECC_Bignum;
