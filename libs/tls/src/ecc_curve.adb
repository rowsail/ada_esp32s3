with Interfaces; use Interfaces;   --  Shift_Right, for the Scalar_Mul bit scan

package body ECC_Curve with SPARK_Mode => On is

   function Dbl (Q : Point) return Point is
      --  Jacobian doubling temps: Dlt = Z^2, Gamma = Y^2, Beta = X*Gamma,
      --  Alpha = 3*(X-Dlt)*(X+Dlt), G2 = Gamma^2, T scratch, (X3,Y3,Z3) result.
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
      --  Jacobian add temps (add-2007-bl): Z1Z1/Z2Z2 = Zi^2, U1/U2 and S1/S2 the
      --  projected X and Y, H/I/J/Rr/V intermediates, (X3,Y3,Z3) result, T scratch.
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
      R : Point := Infinity;   --  running accumulator (double-and-add)
   begin
      for I in reverse 0 .. BN.Limbs * 32 - 1 loop
         R := Dbl (R);
         if (Shift_Right (K (I / 32), I mod 32) and 1) = 1 then
            R := Add (R, Q);
         end if;
      end loop;
      return R;
   end Scalar_Mul;

   function On_Curve (X, Y : Num) return Boolean is
      --  XM/YM/BM = x, y, b in Montgomery form; LHS = y^2; X3 = x^3 - 3x + b.
      XM  : constant Num := Mont_Mul (X, P_R2, P, P_M0);
      YM  : constant Num := Mont_Mul (Y, P_R2, P, P_M0);
      BM  : constant Num := Mont_Mul (Curve_B, P_R2, P, P_M0);
      LHS : constant Num := FMul (YM, YM);
      X3  : Num := FMul (FMul (XM, XM), XM);
      TX  : constant Num := FAdd (FDbl (XM), XM);         --  3x
   begin
      X3 := FAdd (FSub (X3, TX), BM);
      return LHS = X3;
   end On_Curve;

end ECC_Curve;
