with Ada.Real_Time;
with ESP32S3_Registers;            use ESP32S3_Registers;
with ESP32S3_Registers.RSA;
with ESP32S3_Registers.SYSTEM;

package body ESP32S3.RSA is

   package R   renames ESP32S3_Registers.RSA;
   package Sys renames ESP32S3_Registers.SYSTEM;

   --  Wall-clock bound on the accelerator polls below, rather than an iteration
   --  count (which the optimiser collapses to microseconds at -O2, giving up
   --  before the operation finishes).  Memory-init and a modexp each complete in
   --  milliseconds; 1 s is a generous worst case that still escapes a wedged
   --  accelerator instead of spinning.  Same rationale as the SDMMC driver.
   use type Ada.Real_Time.Time;
   RSA_Timeout : constant Ada.Real_Time.Time_Span :=
     Ada.Real_Time.Milliseconds (1000);
   function Past (D : Ada.Real_Time.Time) return Boolean is
     (Ada.Real_Time.Clock >= D);

   --  -M^-1 mod 2^32 from the low word of M (Newton's iteration; M is odd, so M0
   --  is odd and invertible mod 2^32).  Inv := M0 is correct to 3 bits; each step
   --  doubles the correct bits (3 -> 6 -> 12 -> 24 -> 48 > 32).
   function M_Prime (M0 : Word) return Word is
      Inv : Word := M0;
   begin
      for K in 1 .. 4 loop
         Inv := Inv * (2 - M0 * Inv);
      end loop;
      return (not Inv) + 1;            --  negate mod 2^32
   end M_Prime;

   --  Power up the accelerator and wait for its memory to initialise.
   function Enable return Boolean is
   begin
      Sys.SYSTEM_Periph.PERIP_CLK_EN1.CRYPTO_RSA_CLK_EN := True;
      Sys.SYSTEM_Periph.PERIP_RST_EN1.CRYPTO_RSA_RST    := False;  --  release reset
      Sys.SYSTEM_Periph.RSA_PD_CTRL.RSA_MEM_PD          := False;  --  power up memory
      declare
         Deadline : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + RSA_Timeout;
      begin
         loop
            if R.RSA_Periph.CLEAN.CLEAN then       --  1 = memories initialised
               return True;
            end if;
            exit when Past (Deadline);
         end loop;
      end;
      return False;
   end Enable;

   procedure Disable is
   begin
      Sys.SYSTEM_Periph.PERIP_CLK_EN1.CRYPTO_RSA_CLK_EN := False;
   end Disable;

   procedure Mod_Exp (X, Y, M, R2 : Word_Array;
                      Z  : out Word_Array;
                      Ok : out Boolean)
   is
      N    : constant Natural := M'Length;
      Done : Boolean := False;
   begin
      Z  := (others => 0);
      Ok := False;
      if not Enable then
         return;
      end if;

      R.RSA_Periph.MODE.MODE := R.MODE_MODE_Field (N - 1);     --  N words
      for I in 0 .. N - 1 loop                                 --  load operands
         R.RSA_Periph.X_MEM (I) := UInt32 (X  (X'First  + I));
         R.RSA_Periph.Y_MEM (I) := UInt32 (Y  (Y'First  + I));
         R.RSA_Periph.M_MEM (I) := UInt32 (M  (M'First  + I));
         R.RSA_Periph.Z_MEM (I) := UInt32 (R2 (R2'First + I)); --  R^2 mod M
      end loop;
      R.RSA_Periph.M_PRIME := UInt32 (M_Prime (M (M'First)));

      R.RSA_Periph.CONSTANT_TIME.CONSTANT_TIME := True;        --  timing-attack guard
      R.RSA_Periph.SEARCH_ENABLE.SEARCH_ENABLE := False;
      R.RSA_Periph.MODEXP_START.MODEXP_START   := True;

      declare
         Deadline : constant Ada.Real_Time.Time := Ada.Real_Time.Clock + RSA_Timeout;
      begin
         loop
            if R.RSA_Periph.IDLE.IDLE then        --  1 = accelerator idle (done)
               Done := True;
               exit;
            end if;
            exit when Past (Deadline);
         end loop;
      end;
      R.RSA_Periph.CLEAR_INTERRUPT.CLEAR_INTERRUPT := True;

      if Done then
         for I in 0 .. N - 1 loop
            Z (Z'First + I) := Word (R.RSA_Periph.Z_MEM (I));
         end loop;
         Ok := True;
      end if;
      Disable;
   end Mod_Exp;

   --  R2 := R^2 mod M, R = 2^(32*N).  Compute 2^(2*32*N) mod M by doubling from 1,
   --  reducing with a conditional subtract each step -- only shift / compare /
   --  subtract on N-word little-endian values.  (Keeps the invariant T < M.)
   procedure Compute_R2 (M : Word_Array; R2 : out Word_Array) is
      N : constant Natural := M'Length;
      T : Word_Array (0 .. N - 1) := (0 => 1, others => 0);

      --  T >= M ?
      function Ge return Boolean is
      begin
         for I in reverse 0 .. N - 1 loop
            if T (I) /= M (M'First + I) then
               return T (I) > M (M'First + I);
            end if;
         end loop;
         return True;                       --  equal
      end Ge;

      --  T := T - M  (mod 2^(32N); borrow discarded, the caller guarantees T >= M
      --  in value once the shifted-out carry is accounted for).
      procedure Sub_M is
         Borrow : Word := 0;
      begin
         for I in 0 .. N - 1 loop
            declare
               Ai : constant Word := T (I);
               Bi : constant Word := M (M'First + I);
            begin
               T (I) := Ai - Bi - Borrow;
               if Borrow = 0 then
                  Borrow := (if Ai < Bi then 1 else 0);
               else
                  Borrow := (if Ai <= Bi then 1 else 0);
               end if;
            end;
         end loop;
      end Sub_M;

      Carry, Top : Word;
   begin
      for Step in 1 .. 2 * N * 32 loop      --  double 2*(32N) times: -> 2^(2*32N)
         Carry := 0;                        --  T := T << 1 (capturing carry-out)
         for I in 0 .. N - 1 loop
            Top    := Shift_Right (T (I), 31);        --  old bit 31
            T (I)  := Shift_Left (T (I), 1) or Carry;  --  << 1, bring in low carry
            Carry  := Top;
         end loop;
         if Carry = 1 or else Ge then       --  2T >= M -> reduce once
            Sub_M;
         end if;
      end loop;
      R2 := T;
   end Compute_R2;

   procedure Mod_Exp (X, Y, M : Word_Array;
                      Z  : out Word_Array;
                      Ok : out Boolean)
   is
      R2 : Word_Array (0 .. M'Length - 1);
   begin
      Compute_R2 (M, R2);
      Mod_Exp (X, Y, M, R2, Z, Ok);
   end Mod_Exp;

end ESP32S3.RSA;
