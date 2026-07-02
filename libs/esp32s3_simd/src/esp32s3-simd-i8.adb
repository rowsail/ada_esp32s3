pragma Ada_2022;

with ESP32S3.SIMD.Helpers;
with Interfaces; use Interfaces;
with Interfaces.C;
with System;
with System.Machine_Code;

package body ESP32S3.SIMD.I8 is

   use type Integer_8;
   use type Integer_16;
   use type Integer_32;
   use Interfaces.C;
   use ESP32S3.SIMD.Helpers;
   use System;
   use System.Machine_Code;

   function Sat_I8 (V : Integer) return Integer_8 is
   begin
      if V > Integer (Integer_8'Last) then
         return Integer_8'Last;
      elsif V < Integer (Integer_8'First) then
         return Integer_8'First;
      else
         return Integer_8 (V);
      end if;
   end Sat_I8;

   function Arith_Shr (V : Integer; Amount : Shift_I8) return Integer is
      Divisor : constant Integer := 2**Integer (Amount);
   begin
      if Amount = 0 then
         return V;
      elsif V >= 0 then
         return V / Divisor;
      else
         return -(((-V) + (Divisor - 1)) / Divisor);
      end if;
   end Arith_Shr;

   procedure Add (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "beqz    %3, .Ladd_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Ladd_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Ladd_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & ".Ladd_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Ladd_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Ladd_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & ".Ladd_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Ladd_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) :=
           Sat_I8 (Integer (A (A'First + I)) + Integer (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Add;

   procedure Add_Scalar (A : SIMD_I8_Vector; Scalar : Integer_8; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      S     : aliased Integer_8 := Scalar;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 4"
           & ASCII.LF
           & "srli    %2, %2, 4"
           & ASCII.LF
           & "beqz    %2, .Ladds_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.8.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Ladds_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Ladds_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & ".Ladds_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Ladds_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Ladds_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vadds.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & ".Ladds_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Ladds_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", S'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) := Sat_I8 (Integer (A (A'First + I)) + Integer (Scalar));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Add_Scalar;

   procedure Sub (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "beqz    %3, .Lsub_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lsub_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lsub_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & ".Lsub_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lsub_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lsub_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & ".Lsub_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lsub_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) :=
           Sat_I8 (Integer (A (A'First + I)) - Integer (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Sub;

   procedure Mul_Shift (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector; Shift : Shift_I8) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      S     : aliased size_t := size_t (Shift);
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "wsr     %5, sar"
           & ASCII.LF
           & "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "beqz    %3, .Lmul_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmul_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmul_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip      q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip      q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip      q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip      q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %2, 16"
           & ASCII.LF
           & ".Lmul_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmul_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmul_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip      q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %2, 16"
           & ASCII.LF
           & ".Lmul_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lmul_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (size_t'Asm_Input ("r", S)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) :=
           Sat_I8 (Arith_Shr (Integer (A (A'First + I)) * Integer (B (B'First + I)), Shift));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Shift;

   procedure Mul_Scalar
     (A : SIMD_I8_Vector; Scalar : Integer_8; Result : in out SIMD_I8_Vector; Shift : Shift_I8)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Sh    : unsigned := unsigned (Shift);
      Tail  : size_t := 0;
      S     : aliased Integer_8 := Scalar;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "wsr     %3, sar"
           & ASCII.LF
           & "extui   %4, %2, 0, 4"
           & ASCII.LF
           & "srli    %2, %2, 4"
           & ASCII.LF
           & "beqz    %2, .Lmuls_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.8.ip q1, %5, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lmuls_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lmuls_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & ".Lmuls_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmuls_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmuls_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & ".Lmuls_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lmuls_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            unsigned'Asm_Output ("+r", Sh),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", S'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) :=
           Sat_I8 (Arith_Shr (Integer (A (A'First + I)) * Integer (Scalar), Shift));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Scalar;

   procedure Mul_Widen (A, B : SIMD_I8_Vector; Result : in out SIMD_I16_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "beqz    %3, .Lmulw_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmulw_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmulw_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip        q0, %0, 16"
           & ASCII.LF
           & "  ssai                 8"
           & ASCII.LF
           & "  ee.vmul.s8           q2, q0, q1"
           & ASCII.LF
           & "  ssai                 0"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp   q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.8            q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip        q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip        q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q0, %0, 16"
           & ASCII.LF
           & "  ssai                 8"
           & ASCII.LF
           & "  ee.vmul.s8           q2, q0, q1"
           & ASCII.LF
           & "  ssai                 0"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp   q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.8            q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip        q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip        q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q0, %0, 16"
           & ASCII.LF
           & "  ssai                 8"
           & ASCII.LF
           & "  ee.vmul.s8           q2, q0, q1"
           & ASCII.LF
           & "  ssai                 0"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp   q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.8            q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip        q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip        q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q0, %0, 16"
           & ASCII.LF
           & "  ssai                 8"
           & ASCII.LF
           & "  ee.vmul.s8           q2, q0, q1"
           & ASCII.LF
           & "  ssai                 0"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp   q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.8            q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip        q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip        q2, %2, 16"
           & ASCII.LF
           & ".Lmulw_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmulw_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmulw_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip        q0, %0, 16"
           & ASCII.LF
           & "  ssai                 8"
           & ASCII.LF
           & "  ee.vmul.s8           q2, q0, q1"
           & ASCII.LF
           & "  ssai                 0"
           & ASCII.LF
           & "  ee.vmul.s8.ld.incp   q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.8            q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip        q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip        q2, %2, 16"
           & ASCII.LF
           & ".Lmulw_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %1, %1, -16"
           & ASCII.LF
           & ".Lmulw_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) :=
           Integer_16 (Integer (A (A'First + I)) * Integer (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Widen;

   procedure Neg (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      N127  : aliased Integer_8 :=
        -127;  --  Integer_8'First + 1: the most negative value that negates without overflow
      I     : Natural;
      V     : Integer_8;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 4"
           & ASCII.LF
           & "srli    %2, %2, 4"
           & ASCII.LF
           & "beqz    %2, .Lneg_i8_tail_start_%="
           & ASCII.LF
           & "ssai    0"
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vcmp.eq.s8 q1, q1, q1"
           & ASCII.LF
           & "ee.vldbc.8.ip q2, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lneg_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lneg_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q3, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q3, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q3, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q3, %1, 16"
           & ASCII.LF
           & ".Lneg_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lneg_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lneg_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q3, %1, 16"
           & ASCII.LF
           & ".Lneg_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lneg_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", N127'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         V := A (A'First + I);
         if V = Integer_8'First then
            V := -127;
         else
            V := -V;
         end if;
         Result (Result'First + I) := V;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Neg;

   procedure Abs_Val (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      N127  : aliased Integer_8 :=
        -127;  --  Integer_8'First + 1: the most negative value that negates without overflow
      I     : Natural;
      V     : Integer_8;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 4"
           & ASCII.LF
           & "srli    %2, %2, 4"
           & ASCII.LF
           & "beqz    %2, .Labs_i8_tail_start_%="
           & ASCII.LF
           & "ssai    0"
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vcmp.eq.s8 q1, q1, q1"
           & ASCII.LF
           & "ee.vldbc.8.ip q2, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Labs_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Labs_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s8         q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s8         q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s8         q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s8         q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & ".Labs_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Labs_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Labs_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s8         q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s8         q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip      q4, %1, 16"
           & ASCII.LF
           & ".Labs_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Labs_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", N127'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         V := A (A'First + I);
         if V = Integer_8'First then
            V := 127;
         elsif V < 0 then
            V := -V;
         end if;
         Result (Result'First + I) := V;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Abs_Val;

   function Sum (A : SIMD_I8_Vector) return Integer_32 is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      One   : aliased Integer_8 := 1;
      Part  : aliased Integer_32 := 0;
      I     : Natural;
      R     : Integer_32 := 0;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %2, %1, 0, 4"
              & ASCII.LF
              & "srli    %1, %1, 4"
              & ASCII.LF
              & "movi.n  a6, 0"
              & ASCII.LF
              & "beqz    %1, .Lsum_i8_done_%="
              & ASCII.LF
              & "ee.zero.accx"
              & ASCII.LF
              & "ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "ee.vldbc.8.ip q1, %3, 0"
              & ASCII.LF
              & "extui   a14, %1, 0, 2"
              & ASCII.LF
              & "srli    %1, %1, 2"
              & ASCII.LF
              & "beqz    %1, .Lsum_i8_rem_start_%="
              & ASCII.LF
              & "loopnez %1, .Lsum_i8_loop4_%="
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Lsum_i8_loop4_%=:"
              & ASCII.LF
              & ".Lsum_i8_rem_start_%=:"
              & ASCII.LF
              & "loopnez a14, .Lsum_i8_loop_%="
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Lsum_i8_loop_%=:"
              & ASCII.LF
              & "rur.accx_0 a6"
              & ASCII.LF
              & "addi    %0, %0, -16"
              & ASCII.LF
              & ".Lsum_i8_done_%=:"
              & ASCII.LF
              & "s32i.n  a6, %4, 0",
            Outputs  =>
              (Address'Asm_Output ("+r", A_Ptr),
               size_t'Asm_Output ("+r", Cnt),
               size_t'Asm_Output ("=&r", Tail)),
            Inputs   =>
              (Address'Asm_Input ("r", One'Address), Address'Asm_Input ("r", Part'Address)),
            Clobber  => "a14,a6,memory",
            Volatile => True);
      end if;
      R := Part;
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         R := R + Integer_32 (A (A'First + I));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      return R;
   end Sum;

   function Dot_Product (A, B : SIMD_I8_Vector) return Integer_32 is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Part  : aliased Integer_32 := 0;
      I     : Natural;
      R     : Integer_32 := 0;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %3, %2, 0, 4"
              & ASCII.LF
              & "srli    %2, %2, 4"
              & ASCII.LF
              & "movi.n  a7, 0"
              & ASCII.LF
              & "beqz    %2, .Ldot_i8_done_%="
              & ASCII.LF
              & "ee.zero.accx"
              & ASCII.LF
              & "ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "extui   a14, %2, 0, 2"
              & ASCII.LF
              & "srli    %2, %2, 2"
              & ASCII.LF
              & "beqz    %2, .Ldot_i8_rem_start_%="
              & ASCII.LF
              & "loopnez %2, .Ldot_i8_loop4_%="
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Ldot_i8_loop4_%=:"
              & ASCII.LF
              & ".Ldot_i8_rem_start_%=:"
              & ASCII.LF
              & "loopnez a14, .Ldot_i8_loop_%="
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Ldot_i8_loop_%=:"
              & ASCII.LF
              & "rur.accx_0 a7"
              & ASCII.LF
              & "addi    %0, %0, -16"
              & ASCII.LF
              & ".Ldot_i8_done_%=:"
              & ASCII.LF
              & "s32i.n  a7, %4, 0",
            Outputs  =>
              (Address'Asm_Output ("+r", A_Ptr),
               Address'Asm_Output ("+r", B_Ptr),
               size_t'Asm_Output ("+r", Cnt),
               size_t'Asm_Output ("=&r", Tail)),
            Inputs   => (Address'Asm_Input ("r", Part'Address)),
            Clobber  => "a14,a7,memory",
            Volatile => True);
      end if;
      R := Part;
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         R := R + Integer_32 (A (A'First + I)) * Integer_32 (B (B'First + I));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      return R;
   end Dot_Product;

   procedure MAC (A : SIMD_I8_Vector; Accumulator : in out Integer_32; Multiplier : Integer_8) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Mul   : aliased Integer_8 := Multiplier;
      Acc   : aliased Integer_32 := Accumulator;
      I     : Natural;
      R     : Integer_32 := 0;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %2, %1, 0, 4"
              & ASCII.LF
              & "srli    %1, %1, 4"
              & ASCII.LF
              & "movi.n  a7, 0"
              & ASCII.LF
              & "beqz    %1, .Lmac_i8_done_%="
              & ASCII.LF
              & "ee.zero.accx"
              & ASCII.LF
              & "ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "ee.vldbc.8.ip q1, %4, 0"
              & ASCII.LF
              & "extui   a14, %1, 0, 2"
              & ASCII.LF
              & "srli    %1, %1, 2"
              & ASCII.LF
              & "beqz    %1, .Lmac_i8_rem_start_%="
              & ASCII.LF
              & "loopnez %1, .Lmac_i8_loop4_%="
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Lmac_i8_loop4_%=:"
              & ASCII.LF
              & ".Lmac_i8_rem_start_%=:"
              & ASCII.LF
              & "loopnez a14, .Lmac_i8_loop_%="
              & ASCII.LF
              & "  ee.vmulas.s8.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Lmac_i8_loop_%=:"
              & ASCII.LF
              & "rur.accx_0 a7"
              & ASCII.LF
              & "addi    %0, %0, -16"
              & ASCII.LF
              & "l32i    a9, %3, 0"
              & ASCII.LF
              & "add     a7, a9, a7"
              & ASCII.LF
              & ".Lmac_i8_done_%=:"
              & ASCII.LF
              & "s32i.n  a7, %3, 0",
            Outputs  =>
              (Address'Asm_Output ("+r", A_Ptr),
               size_t'Asm_Output ("+r", Cnt),
               size_t'Asm_Output ("=&r", Tail)),
            Inputs   =>
              (Address'Asm_Input ("r", Acc'Address), Address'Asm_Input ("r", Mul'Address)),
            Clobber  => "a14,a7,a9,memory",
            Volatile => True);
         R := Acc;
      else
         R := Accumulator;
      end if;

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         R := R + Integer_32 (A (A'First + I)) * Integer_32 (Multiplier);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      Accumulator := R;
   end MAC;

   procedure Relu
     (A          : SIMD_I8_Vector;
      Multiplier : Integer_32;
      Shift      : Shift_I8;
      Result     : in out SIMD_I8_Vector)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      M     : Integer_32 := Multiplier;
      Sh    : unsigned := unsigned (Shift);
      I     : Natural;
      V     : Integer;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %4, %2, 0, 4"
              & ASCII.LF
              & "srli    %2, %2, 4"
              & ASCII.LF
              & "extui   a14, %2, 0, 2"
              & ASCII.LF
              & "srli    %2, %2, 2"
              & ASCII.LF
              & "beqz    %2, .Lrelu_i8_rem_start_%="
              & ASCII.LF
              & "loopnez %2, .Lrelu_i8_loop4_%="
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s8 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s8 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s8 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s8 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & ".Lrelu_i8_loop4_%=:"
              & ASCII.LF
              & ".Lrelu_i8_rem_start_%=:"
              & ASCII.LF
              & "loopnez a14, .Lrelu_i8_loop_%="
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s8 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & ".Lrelu_i8_loop_%=:"
              & ASCII.LF
              & "extui   %4, %4, 0, 4",
            Outputs  =>
              (Address'Asm_Output ("+r", A_Ptr),
               Address'Asm_Output ("+r", R_Ptr),
               size_t'Asm_Output ("+r", Cnt),
               unsigned'Asm_Output ("+r", Sh),
               size_t'Asm_Output ("=&r", Tail)),
            Inputs   => (Integer_32'Asm_Input ("r", M)),
            Clobber  => "a14,memory",
            Volatile => True);
      end if;

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         V := Integer (A (A'First + I));
         if V < 0 then
            V := Arith_Shr (V * Integer (Multiplier), Shift mod 32);
         end if;
         Result (Result'First + I) := Integer_8 (V);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Relu;

   procedure Ceil (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector; Max_Val : Integer_8) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      M     : aliased Integer_8 := Max_Val;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 4"
           & ASCII.LF
           & "srli    %2, %2, 4"
           & ASCII.LF
           & "beqz    %2, .Lceil_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.8.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lceil_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lceil_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & ".Lceil_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lceil_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lceil_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & ".Lceil_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lceil_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", M'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         if A (A'First + I) > Max_Val then
            Result (Result'First + I) := Max_Val;
         else
            Result (Result'First + I) := A (A'First + I);
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Ceil;

   procedure Floor (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector; Min_Val : Integer_8) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      M     : aliased Integer_8 := Min_Val;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 4"
           & ASCII.LF
           & "srli    %2, %2, 4"
           & ASCII.LF
           & "beqz    %2, .Lfloor_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.8.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lfloor_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lfloor_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & ".Lfloor_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lfloor_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lfloor_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip      q2, %1, 16"
           & ASCII.LF
           & ".Lfloor_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lfloor_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", M'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         if A (A'First + I) < Min_Val then
            Result (Result'First + I) := Min_Val;
         else
            Result (Result'First + I) := A (A'First + I);
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Floor;

   procedure Max (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "beqz    %3, .Lmax_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmax_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmax_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & ".Lmax_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmax_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmax_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & ".Lmax_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lmax_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         if A (A'First + I) >= B (B'First + I) then
            Result (Result'First + I) := A (A'First + I);
         else
            Result (Result'First + I) := B (B'First + I);
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Max;

   procedure Min (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "beqz    %3, .Lmin_i8_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmin_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmin_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & ".Lmin_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmin_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmin_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip       q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s8.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip       q4, %2, 16"
           & ASCII.LF
           & ".Lmin_i8_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lmin_i8_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         if A (A'First + I) <= B (B'First + I) then
            Result (Result'First + I) := A (A'First + I);
         else
            Result (Result'First + I) := B (B'First + I);
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Min;

   procedure Bitwise_And (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Land_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Land_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Land_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Land_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Land_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Land_i8_simd_loop_%=:"
           & ASCII.LF
           & "loopnez %4, .Land_i8_tail_loop_%="
           & ASCII.LF
           & "  l8ui    a10, %0, 0"
           & ASCII.LF
           & "  l8ui    a11, %1, 0"
           & ASCII.LF
           & "  and     a10, a10, a11"
           & ASCII.LF
           & "  s8i     a10, %2, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & "  addi.n  %1, %1, 1"
           & ASCII.LF
           & "  addi.n  %2, %2, 1"
           & ASCII.LF
           & ".Land_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,a11,memory",
         Volatile => True);
   end Bitwise_And;

   procedure Bitwise_Or (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lor_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lor_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq        q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq        q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq        q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq        q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lor_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lor_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lor_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq        q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lor_i8_simd_loop_%=:"
           & ASCII.LF
           & "loopnez %4, .Lor_i8_tail_loop_%="
           & ASCII.LF
           & "  l8ui    a10, %0, 0"
           & ASCII.LF
           & "  l8ui    a11, %1, 0"
           & ASCII.LF
           & "  or      a10, a10, a11"
           & ASCII.LF
           & "  s8i     a10, %2, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & "  addi.n  %1, %1, 1"
           & ASCII.LF
           & "  addi.n  %2, %2, 1"
           & ASCII.LF
           & ".Lor_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,a11,memory",
         Volatile => True);
   end Bitwise_Or;

   procedure Bitwise_Xor (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lxor_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lxor_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lxor_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lxor_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lxor_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lxor_i8_simd_loop_%=:"
           & ASCII.LF
           & "loopnez %4, .Lxor_i8_tail_loop_%="
           & ASCII.LF
           & "  l8ui    a10, %0, 0"
           & ASCII.LF
           & "  l8ui    a11, %1, 0"
           & ASCII.LF
           & "  xor     a10, a10, a11"
           & ASCII.LF
           & "  s8i     a10, %2, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & "  addi.n  %1, %1, 1"
           & ASCII.LF
           & "  addi.n  %2, %2, 1"
           & ASCII.LF
           & ".Lxor_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,a11,memory",
         Volatile => True);
   end Bitwise_Xor;

   procedure Bitwise_Not (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 4"
           & ASCII.LF
           & "srli    %2, %2, 4"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lnot_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lnot_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq       q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq       q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq       q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq       q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & ".Lnot_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lnot_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lnot_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq       q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & ".Lnot_i8_simd_loop_%=:"
           & ASCII.LF
           & "movi    a11, -1"
           & ASCII.LF
           & "loopnez %3, .Lnot_i8_tail_loop_%="
           & ASCII.LF
           & "  l8ui    a10, %0, 0"
           & ASCII.LF
           & "  xor     a10, a10, a11"
           & ASCII.LF
           & "  s8i     a10, %1, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & "  addi.n  %1, %1, 1"
           & ASCII.LF
           & ".Lnot_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,a11,memory",
         Volatile => True);
   end Bitwise_Not;

   procedure Compare_GT (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lcmp_gt_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lcmp_gt_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcmp_gt_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcmp_gt_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcmp_gt_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcmp_gt_i8_simd_loop_%=:"
           & ASCII.LF
           & "movi    a12, -1"
           & ASCII.LF
           & "loopnez %4, .Lcmp_gt_i8_tail_loop_%="
           & ASCII.LF
           & "  l8ui    a10, %0, 0"
           & ASCII.LF
           & "  l8ui    a11, %1, 0"
           & ASCII.LF
           & "  sext    a10, a10, 7"
           & ASCII.LF
           & "  sext    a11, a11, 7"
           & ASCII.LF
           & "  movi.n  a13, 0"
           & ASCII.LF
           & "  sub     a10, a11, a10"
           & ASCII.LF
           & "  movltz  a13, a12, a10"
           & ASCII.LF
           & "  s8i     a13, %2, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & "  addi.n  %1, %1, 1"
           & ASCII.LF
           & "  addi.n  %2, %2, 1"
           & ASCII.LF
           & ".Lcmp_gt_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,a11,a12,a13,memory",
         Volatile => True);
   end Compare_GT;

   procedure Compare_LT (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lcmp_lt_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lcmp_lt_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcmp_lt_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcmp_lt_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcmp_lt_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcmp_lt_i8_simd_loop_%=:"
           & ASCII.LF
           & "movi    a12, -1"
           & ASCII.LF
           & "loopnez %4, .Lcmp_lt_i8_tail_loop_%="
           & ASCII.LF
           & "  l8ui    a10, %0, 0"
           & ASCII.LF
           & "  l8ui    a11, %1, 0"
           & ASCII.LF
           & "  sext    a10, a10, 7"
           & ASCII.LF
           & "  sext    a11, a11, 7"
           & ASCII.LF
           & "  movi.n  a13, 0"
           & ASCII.LF
           & "  sub     a10, a10, a11"
           & ASCII.LF
           & "  movltz  a13, a12, a10"
           & ASCII.LF
           & "  s8i     a13, %2, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & "  addi.n  %1, %1, 1"
           & ASCII.LF
           & "  addi.n  %2, %2, 1"
           & ASCII.LF
           & ".Lcmp_lt_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,a11,a12,a13,memory",
         Volatile => True);
   end Compare_LT;

   procedure Compare_EQ (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 4"
           & ASCII.LF
           & "srli    %3, %3, 4"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lcmp_eq_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lcmp_eq_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcmp_eq_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcmp_eq_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcmp_eq_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s8 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcmp_eq_i8_simd_loop_%=:"
           & ASCII.LF
           & "movi    a12, -1"
           & ASCII.LF
           & "loopnez %4, .Lcmp_eq_i8_tail_loop_%="
           & ASCII.LF
           & "  l8ui    a10, %0, 0"
           & ASCII.LF
           & "  l8ui    a11, %1, 0"
           & ASCII.LF
           & "  movi.n  a13, 0"
           & ASCII.LF
           & "  sub     a10, a11, a10"
           & ASCII.LF
           & "  moveqz  a13, a12, a10"
           & ASCII.LF
           & "  s8i     a13, %2, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & "  addi.n  %1, %1, 1"
           & ASCII.LF
           & "  addi.n  %2, %2, 1"
           & ASCII.LF
           & ".Lcmp_eq_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,a11,a12,a13,memory",
         Volatile => True);
   end Compare_EQ;

   procedure Zeros (A : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %2, %1, 0, 4"
           & ASCII.LF
           & "srli    %1, %1, 4"
           & ASCII.LF
           & "ee.xorq q0, q0, q0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lzeros_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lzeros_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lzeros_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lzeros_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lzeros_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lzeros_i8_simd_loop_%=:"
           & ASCII.LF
           & "xor     a10, a10, a10"
           & ASCII.LF
           & "loopnez %2, .Lzeros_i8_tail_loop_%="
           & ASCII.LF
           & "  s8i     a10, %0, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & ".Lzeros_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,memory",
         Volatile => True);
   end Zeros;

   procedure Ones (A : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      One   : aliased Integer_8 := 1;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui         %2, %1, 0, 4"
           & ASCII.LF
           & "srli          %1, %1, 4"
           & ASCII.LF
           & "ee.vldbc.8.ip q0, %3, 0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lones_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lones_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lones_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lones_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lones_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lones_i8_simd_loop_%=:"
           & ASCII.LF
           & "movi.n        a10, 1"
           & ASCII.LF
           & "loopnez       %2, .Lones_i8_tail_loop_%="
           & ASCII.LF
           & "  s8i           a10, %0, 0"
           & ASCII.LF
           & "  addi.n        %0, %0, 1"
           & ASCII.LF
           & ".Lones_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", One'Address)),
         Clobber  => "a14,a10,memory",
         Volatile => True);
   end Ones;

   procedure Fill (A : in out SIMD_I8_Vector; Value : Integer_8) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      V     : aliased Integer_8 := Value;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui         %2, %1, 0, 4"
           & ASCII.LF
           & "srli          %1, %1, 4"
           & ASCII.LF
           & "ee.vldbc.8.ip q0, %3, 0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lfill_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lfill_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lfill_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lfill_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lfill_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lfill_i8_simd_loop_%=:"
           & ASCII.LF
           & "l8ui          a10, %3, 0"
           & ASCII.LF
           & "loopnez       %2, .Lfill_i8_tail_loop_%="
           & ASCII.LF
           & "  s8i           a10, %0, 0"
           & ASCII.LF
           & "  addi.n        %0, %0, 1"
           & ASCII.LF
           & ".Lfill_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", V'Address)),
         Clobber  => "a14,a10,memory",
         Volatile => True);
   end Fill;

   procedure Copy (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 4"
           & ASCII.LF
           & "srli    %2, %2, 4"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lcopy_i8_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lcopy_i8_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Lcopy_i8_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcopy_i8_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcopy_i8_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Lcopy_i8_simd_loop_%=:"
           & ASCII.LF
           & "loopnez %3, .Lcopy_i8_tail_loop_%="
           & ASCII.LF
           & "  l8ui    a10, %0, 0"
           & ASCII.LF
           & "  addi.n  %0, %0, 1"
           & ASCII.LF
           & "  s8i     a10, %1, 0"
           & ASCII.LF
           & "  addi.n  %1, %1, 1"
           & ASCII.LF
           & ".Lcopy_i8_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a10,memory",
         Volatile => True);
   end Copy;

   procedure Convert_To_I16 (A : SIMD_I8_Vector; Result : in out SIMD_I16_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Bias  : aliased Integer_32 := 16#80#;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui         %3, %2, 0, 4"
           & ASCII.LF
           & "srli          %2, %2, 4"
           & ASCII.LF
           & "beqz          %2, .Lcv_i8_i16_tail_start_%="
           & ASCII.LF
           & "ee.vldbc.8    q2, %4"
           & ASCII.LF
           & "ee.vldbc.16   q3, %4"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lcv_i8_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lcv_i8_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vsubs.s16  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s16  q1, q1, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vsubs.s16  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s16  q1, q1, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vsubs.s16  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s16  q1, q1, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vsubs.s16  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s16  q1, q1, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Lcv_i8_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcv_i8_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcv_i8_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vsubs.s16  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s16  q1, q1, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Lcv_i8_i16_simd_loop_%=:"
           & ASCII.LF
           & ".Lcv_i8_i16_tail_start_%=:"
           & ASCII.LF
           & "loopnez       %3, .Lcv_i8_i16_tail_loop_%="
           & ASCII.LF
           & "  l8ui          a10, %0, 0"
           & ASCII.LF
           & "  sext          a10, a10, 7"
           & ASCII.LF
           & "  s16i          a10, %1, 0"
           & ASCII.LF
           & "  addi.n        %0, %0, 1"
           & ASCII.LF
           & "  addi.n        %1, %1, 2"
           & ASCII.LF
           & ".Lcv_i8_i16_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Bias'Address)),
         Clobber  => "a14,a10,memory",
         Volatile => True);
   end Convert_To_I16;

   procedure Convert_To_I32 (A : SIMD_I8_Vector; Result : in out SIMD_I32_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Bias  : aliased Integer_32 := 16#80#;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui         %3, %2, 0, 4"
           & ASCII.LF
           & "srli          %2, %2, 4"
           & ASCII.LF
           & "beqz          %2, .Lcv_i8_i32_tail_start_%="
           & ASCII.LF
           & "ee.vldbc.8    q2, %4"
           & ASCII.LF
           & "ee.vldbc.32   q3, %4"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lcv_i8_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lcv_i8_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.xorq       q4, q4, q4"
           & ASCII.LF
           & "  ee.xorq       q5, q5, q5"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vzip.16    q0, q4"
           & ASCII.LF
           & "  ee.vzip.16    q1, q5"
           & ASCII.LF
           & "  ee.vsubs.s32  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q1, q1, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q4, q4, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q5, q5, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q5, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.xorq       q4, q4, q4"
           & ASCII.LF
           & "  ee.xorq       q5, q5, q5"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vzip.16    q0, q4"
           & ASCII.LF
           & "  ee.vzip.16    q1, q5"
           & ASCII.LF
           & "  ee.vsubs.s32  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q1, q1, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q4, q4, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q5, q5, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q5, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.xorq       q4, q4, q4"
           & ASCII.LF
           & "  ee.xorq       q5, q5, q5"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vzip.16    q0, q4"
           & ASCII.LF
           & "  ee.vzip.16    q1, q5"
           & ASCII.LF
           & "  ee.vsubs.s32  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q1, q1, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q4, q4, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q5, q5, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q5, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.xorq       q4, q4, q4"
           & ASCII.LF
           & "  ee.xorq       q5, q5, q5"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vzip.16    q0, q4"
           & ASCII.LF
           & "  ee.vzip.16    q1, q5"
           & ASCII.LF
           & "  ee.vsubs.s32  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q1, q1, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q4, q4, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q5, q5, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q5, %1, 16"
           & ASCII.LF
           & ".Lcv_i8_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcv_i8_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcv_i8_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q1"
           & ASCII.LF
           & "  ee.xorq       q0, q0, q2"
           & ASCII.LF
           & "  ee.xorq       q4, q4, q4"
           & ASCII.LF
           & "  ee.xorq       q5, q5, q5"
           & ASCII.LF
           & "  ee.vzip.8     q0, q1"
           & ASCII.LF
           & "  ee.vzip.16    q0, q4"
           & ASCII.LF
           & "  ee.vzip.16    q1, q5"
           & ASCII.LF
           & "  ee.vsubs.s32  q0, q0, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q1, q1, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q4, q4, q3"
           & ASCII.LF
           & "  ee.vsubs.s32  q5, q5, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q5, %1, 16"
           & ASCII.LF
           & ".Lcv_i8_i32_simd_loop_%=:"
           & ASCII.LF
           & ".Lcv_i8_i32_tail_start_%=:"
           & ASCII.LF
           & "loopnez       %3, .Lcv_i8_i32_tail_loop_%="
           & ASCII.LF
           & "  l8ui          a10, %0, 0"
           & ASCII.LF
           & "  sext          a10, a10, 7"
           & ASCII.LF
           & "  s32i          a10, %1, 0"
           & ASCII.LF
           & "  addi.n        %0, %0, 1"
           & ASCII.LF
           & "  addi.n        %1, %1, 4"
           & ASCII.LF
           & ".Lcv_i8_i32_tail_loop_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Bias'Address)),
         Clobber  => "a14,a10,memory",
         Volatile => True);
   end Convert_To_I32;

end ESP32S3.SIMD.I8;
