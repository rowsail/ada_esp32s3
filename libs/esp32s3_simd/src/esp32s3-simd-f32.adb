pragma Ada_2022;

with ESP32S3.SIMD.Helpers;
with Interfaces.C;
with Interfaces; use Interfaces;
with System;
with System.Machine_Code;

package body ESP32S3.SIMD.F32 is

   use type IEEE_Float_32;
   use Interfaces.C;
   use ESP32S3.SIMD.Helpers;
   use System;
   use System.Machine_Code;

   procedure Add (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector) is
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
           "extui   %4, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Ladd_f32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Ladd_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Ladd_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  add.s f3, f3, f7"
           & ASCII.LF
           & "  add.s f2, f2, f6"
           & ASCII.LF
           & "  add.s f1, f1, f5"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  add.s f3, f3, f7"
           & ASCII.LF
           & "  add.s f2, f2, f6"
           & ASCII.LF
           & "  add.s f1, f1, f5"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  add.s f3, f3, f7"
           & ASCII.LF
           & "  add.s f2, f2, f6"
           & ASCII.LF
           & "  add.s f1, f1, f5"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  add.s f3, f3, f7"
           & ASCII.LF
           & "  add.s f2, f2, f6"
           & ASCII.LF
           & "  add.s f1, f1, f5"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Ladd_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Ladd_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Ladd_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  add.s f3, f3, f7"
           & ASCII.LF
           & "  add.s f2, f2, f6"
           & ASCII.LF
           & "  add.s f1, f1, f5"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Ladd_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Ladd_f32_tail_start_%=:",
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
         Result (Result'First + I) := A (A'First + I) + B (B'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Add;

   procedure Add_Scalar
     (A : SIMD_F32_Vector; Scalar : IEEE_Float_32; Result : in out SIMD_F32_Vector)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
      S     : aliased IEEE_Float_32 := Scalar;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Ladds_f32_tail_start_%="
           & ASCII.LF
           & "lsi     f4, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Ladds_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Ladds_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f3, f3, f4"
           & ASCII.LF
           & "  add.s f2, f2, f4"
           & ASCII.LF
           & "  add.s f1, f1, f4"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f3, f3, f4"
           & ASCII.LF
           & "  add.s f2, f2, f4"
           & ASCII.LF
           & "  add.s f1, f1, f4"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f3, f3, f4"
           & ASCII.LF
           & "  add.s f2, f2, f4"
           & ASCII.LF
           & "  add.s f1, f1, f4"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f3, f3, f4"
           & ASCII.LF
           & "  add.s f2, f2, f4"
           & ASCII.LF
           & "  add.s f1, f1, f4"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & ".Ladds_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Ladds_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Ladds_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f3, f3, f4"
           & ASCII.LF
           & "  add.s f2, f2, f4"
           & ASCII.LF
           & "  add.s f1, f1, f4"
           & ASCII.LF
           & "  add.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & ".Ladds_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Ladds_f32_tail_start_%=:",
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
         Result (Result'First + I) := A (A'First + I) + Scalar;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Add_Scalar;

   procedure Sub (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector) is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := size_t (0);
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lsub_f32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lsub_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lsub_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  sub.s f3, f3, f7"
           & ASCII.LF
           & "  sub.s f2, f2, f6"
           & ASCII.LF
           & "  sub.s f1, f1, f5"
           & ASCII.LF
           & "  sub.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  sub.s f3, f3, f7"
           & ASCII.LF
           & "  sub.s f2, f2, f6"
           & ASCII.LF
           & "  sub.s f1, f1, f5"
           & ASCII.LF
           & "  sub.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  sub.s f3, f3, f7"
           & ASCII.LF
           & "  sub.s f2, f2, f6"
           & ASCII.LF
           & "  sub.s f1, f1, f5"
           & ASCII.LF
           & "  sub.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  sub.s f3, f3, f7"
           & ASCII.LF
           & "  sub.s f2, f2, f6"
           & ASCII.LF
           & "  sub.s f1, f1, f5"
           & ASCII.LF
           & "  sub.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Lsub_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lsub_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lsub_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  sub.s f3, f3, f7"
           & ASCII.LF
           & "  sub.s f2, f2, f6"
           & ASCII.LF
           & "  sub.s f1, f1, f5"
           & ASCII.LF
           & "  sub.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Lsub_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Lsub_f32_tail_start_%=:",
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
         Result (Result'First + I) := A (A'First + I) - B (B'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Sub;

   procedure Mul_Shift (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Shift : Natural)
   is
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

      if Shift /= 0 then
         raise Constraint_Error with "Shift must be 0 for SIMD_F32 Mul_Shift";
      end if;

      Asm
        (Template =>
           "extui   %4, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmulsh_f32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmulsh_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmulsh_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f7"
           & ASCII.LF
           & "  mul.s f2, f2, f6"
           & ASCII.LF
           & "  mul.s f1, f1, f5"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f7"
           & ASCII.LF
           & "  mul.s f2, f2, f6"
           & ASCII.LF
           & "  mul.s f1, f1, f5"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f7"
           & ASCII.LF
           & "  mul.s f2, f2, f6"
           & ASCII.LF
           & "  mul.s f1, f1, f5"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f7"
           & ASCII.LF
           & "  mul.s f2, f2, f6"
           & ASCII.LF
           & "  mul.s f1, f1, f5"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Lmulsh_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmulsh_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmulsh_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f7"
           & ASCII.LF
           & "  mul.s f2, f2, f6"
           & ASCII.LF
           & "  mul.s f1, f1, f5"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Lmulsh_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Lmulsh_f32_tail_start_%=:",
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
         Result (Result'First + I) := A (A'First + I) * B (B'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Shift;

   procedure Mul_Scalar
     (A : SIMD_F32_Vector; Scalar : IEEE_Float_32; Result : in out SIMD_F32_Vector)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
      S     : aliased IEEE_Float_32 := Scalar;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lmuls_f32_tail_start_%="
           & ASCII.LF
           & "lsi     f4, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lmuls_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lmuls_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f4"
           & ASCII.LF
           & "  mul.s f2, f2, f4"
           & ASCII.LF
           & "  mul.s f1, f1, f4"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f4"
           & ASCII.LF
           & "  mul.s f2, f2, f4"
           & ASCII.LF
           & "  mul.s f1, f1, f4"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f4"
           & ASCII.LF
           & "  mul.s f2, f2, f4"
           & ASCII.LF
           & "  mul.s f1, f1, f4"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f4"
           & ASCII.LF
           & "  mul.s f2, f2, f4"
           & ASCII.LF
           & "  mul.s f1, f1, f4"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & ".Lmuls_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmuls_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmuls_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  mul.s f3, f3, f4"
           & ASCII.LF
           & "  mul.s f2, f2, f4"
           & ASCII.LF
           & "  mul.s f1, f1, f4"
           & ASCII.LF
           & "  mul.s f0, f0, f4"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & ".Lmuls_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Lmuls_f32_tail_start_%=:",
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
         Result (Result'First + I) := A (A'First + I) * Scalar;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Scalar;

   procedure Neg (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector) is
      A_Ptr    : Address := First_Address (A);
      R_Ptr    : Address := First_Address (Result);
      Cnt      : size_t := size_t (A'Length);
      Tail     : size_t := 0;
      Mask_Neg : aliased Interfaces.Unsigned_32 := 16#80000000#;
      I        : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lneg_f32_tail_start_%="
           & ASCII.LF
           & "ee.vldbc.32 q0, %4"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lneg_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lneg_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Lneg_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lneg_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lneg_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.xorq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Lneg_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Lneg_f32_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Mask_Neg'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) := -A (A'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Neg;

   procedure Abs_Val (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector) is
      A_Ptr    : Address := First_Address (A);
      R_Ptr    : Address := First_Address (Result);
      Cnt      : size_t := size_t (A'Length);
      Tail     : size_t := 0;
      Mask_Abs : aliased Interfaces.Unsigned_32 := 16#7FFFFFFF#;
      I        : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Labs_f32_tail_start_%="
           & ASCII.LF
           & "ee.vldbc.32 q0, %4"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Labs_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Labs_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.andq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.andq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.andq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.andq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Labs_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Labs_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Labs_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.andq       q1, q1, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Labs_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Labs_f32_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Mask_Abs'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) := abs A (A'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Abs_Val;

   function Sum (A : SIMD_F32_Vector) return IEEE_Float_32 is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Part  : aliased IEEE_Float_32 := 0.0;
      I     : Natural;
   begin
      if A'Length = 0 then
         return 0.0;
      end if;

      Asm
        (Template =>
           "extui   %2, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "const.s f4, 0"
           & ASCII.LF
           & "const.s f5, 0"
           & ASCII.LF
           & "const.s f6, 0"
           & ASCII.LF
           & "const.s f7, 0"
           & ASCII.LF
           & "beqz    %1, .Lsum_f32_done_%="
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lsum_f32_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lsum_f32_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f4, f0, f4"
           & ASCII.LF
           & "  add.s f5, f1, f5"
           & ASCII.LF
           & "  add.s f6, f2, f6"
           & ASCII.LF
           & "  add.s f7, f3, f7"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f4, f0, f4"
           & ASCII.LF
           & "  add.s f5, f1, f5"
           & ASCII.LF
           & "  add.s f6, f2, f6"
           & ASCII.LF
           & "  add.s f7, f3, f7"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f4, f0, f4"
           & ASCII.LF
           & "  add.s f5, f1, f5"
           & ASCII.LF
           & "  add.s f6, f2, f6"
           & ASCII.LF
           & "  add.s f7, f3, f7"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f4, f0, f4"
           & ASCII.LF
           & "  add.s f5, f1, f5"
           & ASCII.LF
           & "  add.s f6, f2, f6"
           & ASCII.LF
           & "  add.s f7, f3, f7"
           & ASCII.LF
           & ".Lsum_f32_loop4_%=:"
           & ASCII.LF
           & ".Lsum_f32_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lsum_f32_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  add.s f4, f0, f4"
           & ASCII.LF
           & "  add.s f5, f1, f5"
           & ASCII.LF
           & "  add.s f6, f2, f6"
           & ASCII.LF
           & "  add.s f7, f3, f7"
           & ASCII.LF
           & ".Lsum_f32_loop_%=:"
           & ASCII.LF
           & "add.s f4, f4, f5"
           & ASCII.LF
           & "add.s f6, f6, f7"
           & ASCII.LF
           & "add.s f4, f4, f6"
           & ASCII.LF
           & ".Lsum_f32_done_%=:"
           & ASCII.LF
           & "ssi f4, %3, 0",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Part'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Part := Part + A (A'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      return Part;
   end Sum;

   function Dot_Product (A, B : SIMD_F32_Vector) return IEEE_Float_32 is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Part  : aliased IEEE_Float_32 := 0.0;
      I     : Natural;
   begin
      if A'Length = 0 then
         return 0.0;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "const.s f8, 0"
           & ASCII.LF
           & "const.s f9, 0"
           & ASCII.LF
           & "const.s f10, 0"
           & ASCII.LF
           & "const.s f11, 0"
           & ASCII.LF
           & "beqz    %2, .Ldot_f32_done_%="
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Ldot_f32_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Ldot_f32_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  madd.s f8,  f3, f7"
           & ASCII.LF
           & "  madd.s f9,  f2, f6"
           & ASCII.LF
           & "  madd.s f10, f1, f5"
           & ASCII.LF
           & "  madd.s f11, f0, f4"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  madd.s f8,  f3, f7"
           & ASCII.LF
           & "  madd.s f9,  f2, f6"
           & ASCII.LF
           & "  madd.s f10, f1, f5"
           & ASCII.LF
           & "  madd.s f11, f0, f4"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  madd.s f8,  f3, f7"
           & ASCII.LF
           & "  madd.s f9,  f2, f6"
           & ASCII.LF
           & "  madd.s f10, f1, f5"
           & ASCII.LF
           & "  madd.s f11, f0, f4"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  madd.s f8,  f3, f7"
           & ASCII.LF
           & "  madd.s f9,  f2, f6"
           & ASCII.LF
           & "  madd.s f10, f1, f5"
           & ASCII.LF
           & "  madd.s f11, f0, f4"
           & ASCII.LF
           & ".Ldot_f32_loop4_%=:"
           & ASCII.LF
           & ".Ldot_f32_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Ldot_f32_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  madd.s f8,  f3, f7"
           & ASCII.LF
           & "  madd.s f9,  f2, f6"
           & ASCII.LF
           & "  madd.s f10, f1, f5"
           & ASCII.LF
           & "  madd.s f11, f0, f4"
           & ASCII.LF
           & ".Ldot_f32_loop_%=:"
           & ASCII.LF
           & "add.s f8, f8, f9"
           & ASCII.LF
           & "add.s f10, f10, f11"
           & ASCII.LF
           & "add.s f8, f8, f10"
           & ASCII.LF
           & ".Ldot_f32_done_%=:"
           & ASCII.LF
           & "ssi f8, %4, 0",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Part'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Part := Part + A (A'First + I) * B (B'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      return Part;
   end Dot_Product;

   procedure MAC
     (A : SIMD_F32_Vector; Accumulator : in out IEEE_Float_32; Multiplier : IEEE_Float_32)
   is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Acc   : aliased IEEE_Float_32 := Accumulator;
      Mul   : aliased IEEE_Float_32 := Multiplier;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %2, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "lsi     f4, %3, 0"
           & ASCII.LF
           & "lsi     f5, %4, 0"
           & ASCII.LF
           & "const.s f7, 0"
           & ASCII.LF
           & "const.s f8, 0"
           & ASCII.LF
           & "const.s f9, 0"
           & ASCII.LF
           & "beqz    %1, .Lmac_f32_done_%="
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lmac_f32_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lmac_f32_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  madd.s f4, f3, f5"
           & ASCII.LF
           & "  madd.s f7, f2, f5"
           & ASCII.LF
           & "  madd.s f8, f0, f5"
           & ASCII.LF
           & "  madd.s f9, f1, f5"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  madd.s f4, f3, f5"
           & ASCII.LF
           & "  madd.s f7, f2, f5"
           & ASCII.LF
           & "  madd.s f8, f0, f5"
           & ASCII.LF
           & "  madd.s f9, f1, f5"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  madd.s f4, f3, f5"
           & ASCII.LF
           & "  madd.s f7, f2, f5"
           & ASCII.LF
           & "  madd.s f8, f0, f5"
           & ASCII.LF
           & "  madd.s f9, f1, f5"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  madd.s f4, f3, f5"
           & ASCII.LF
           & "  madd.s f7, f2, f5"
           & ASCII.LF
           & "  madd.s f8, f0, f5"
           & ASCII.LF
           & "  madd.s f9, f1, f5"
           & ASCII.LF
           & ".Lmac_f32_loop4_%=:"
           & ASCII.LF
           & ".Lmac_f32_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmac_f32_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  madd.s f4, f3, f5"
           & ASCII.LF
           & "  madd.s f7, f2, f5"
           & ASCII.LF
           & "  madd.s f8, f0, f5"
           & ASCII.LF
           & "  madd.s f9, f1, f5"
           & ASCII.LF
           & ".Lmac_f32_loop_%=:"
           & ASCII.LF
           & "add.s f4, f4, f7"
           & ASCII.LF
           & "add.s f8, f8, f9"
           & ASCII.LF
           & "add.s f4, f4, f8"
           & ASCII.LF
           & ".Lmac_f32_done_%=:"
           & ASCII.LF
           & "ssi f4, %3, 0",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Acc'Address), Address'Asm_Input ("r", Mul'Address)),
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Acc := Acc + A (A'First + I) * Multiplier;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      Accumulator := Acc;
   end MAC;

   procedure Ceil (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Max_Val : IEEE_Float_32)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Max_V : aliased IEEE_Float_32 := Max_Val;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "lsi     f4, %4, 0"
           & ASCII.LF
           & "beqz    %2, .Lceil_f32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lceil_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lceil_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f4, f3"
           & ASCII.LF
           & "  olt.s  b1, f4, f2"
           & ASCII.LF
           & "  olt.s  b2, f4, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f4, f3"
           & ASCII.LF
           & "  olt.s  b1, f4, f2"
           & ASCII.LF
           & "  olt.s  b2, f4, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f4, f3"
           & ASCII.LF
           & "  olt.s  b1, f4, f2"
           & ASCII.LF
           & "  olt.s  b2, f4, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f4, f3"
           & ASCII.LF
           & "  olt.s  b1, f4, f2"
           & ASCII.LF
           & "  olt.s  b2, f4, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & ".Lceil_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lceil_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lceil_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f4, f3"
           & ASCII.LF
           & "  olt.s  b1, f4, f2"
           & ASCII.LF
           & "  olt.s  b2, f4, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & ".Lceil_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Lceil_f32_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Max_V'Address)),
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

   procedure Floor (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Min_Val : IEEE_Float_32)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Min_V : aliased IEEE_Float_32 := Min_Val;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "lsi     f4, %4, 0"
           & ASCII.LF
           & "beqz    %2, .Lfloor_f32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lfloor_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lfloor_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f4"
           & ASCII.LF
           & "  olt.s  b1, f2, f4"
           & ASCII.LF
           & "  olt.s  b2, f1, f4"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f4"
           & ASCII.LF
           & "  olt.s  b1, f2, f4"
           & ASCII.LF
           & "  olt.s  b2, f1, f4"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f4"
           & ASCII.LF
           & "  olt.s  b1, f2, f4"
           & ASCII.LF
           & "  olt.s  b2, f1, f4"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f4"
           & ASCII.LF
           & "  olt.s  b1, f2, f4"
           & ASCII.LF
           & "  olt.s  b2, f1, f4"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & ".Lfloor_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lfloor_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lfloor_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f4"
           & ASCII.LF
           & "  olt.s  b1, f2, f4"
           & ASCII.LF
           & "  olt.s  b2, f1, f4"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f4, b0"
           & ASCII.LF
           & "  movt.s f2, f4, b1"
           & ASCII.LF
           & "  movt.s f1, f4, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %1, 16"
           & ASCII.LF
           & ".Lfloor_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Lfloor_f32_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Min_V'Address)),
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

   procedure Max (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector) is
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
           "extui   %4, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmax_f32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmax_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmax_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f7"
           & ASCII.LF
           & "  olt.s  b1, f2, f6"
           & ASCII.LF
           & "  olt.s  b2, f1, f5"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f7"
           & ASCII.LF
           & "  olt.s  b1, f2, f6"
           & ASCII.LF
           & "  olt.s  b2, f1, f5"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f7"
           & ASCII.LF
           & "  olt.s  b1, f2, f6"
           & ASCII.LF
           & "  olt.s  b2, f1, f5"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f7"
           & ASCII.LF
           & "  olt.s  b1, f2, f6"
           & ASCII.LF
           & "  olt.s  b2, f1, f5"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Lmax_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmax_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmax_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f3, f7"
           & ASCII.LF
           & "  olt.s  b1, f2, f6"
           & ASCII.LF
           & "  olt.s  b2, f1, f5"
           & ASCII.LF
           & "  olt.s  b3, f0, f4"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Lmax_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Lmax_f32_tail_start_%=:",
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

   procedure Min (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector) is
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
           "extui   %4, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmin_f32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmin_f32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmin_f32_simd_loop4_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f7, f3"
           & ASCII.LF
           & "  olt.s  b1, f6, f2"
           & ASCII.LF
           & "  olt.s  b2, f5, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f7, f3"
           & ASCII.LF
           & "  olt.s  b1, f6, f2"
           & ASCII.LF
           & "  olt.s  b2, f5, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f7, f3"
           & ASCII.LF
           & "  olt.s  b1, f6, f2"
           & ASCII.LF
           & "  olt.s  b2, f5, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f7, f3"
           & ASCII.LF
           & "  olt.s  b1, f6, f2"
           & ASCII.LF
           & "  olt.s  b2, f5, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Lmin_f32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmin_f32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmin_f32_simd_loop_%="
           & ASCII.LF
           & "  ee.ldf.128.ip f3, f2, f1, f0, %0, 16"
           & ASCII.LF
           & "  ee.ldf.128.ip f7, f6, f5, f4, %1, 16"
           & ASCII.LF
           & "  olt.s  b0, f7, f3"
           & ASCII.LF
           & "  olt.s  b1, f6, f2"
           & ASCII.LF
           & "  olt.s  b2, f5, f1"
           & ASCII.LF
           & "  olt.s  b3, f4, f0"
           & ASCII.LF
           & "  movt.s f3, f7, b0"
           & ASCII.LF
           & "  movt.s f2, f6, b1"
           & ASCII.LF
           & "  movt.s f1, f5, b2"
           & ASCII.LF
           & "  movt.s f0, f4, b3"
           & ASCII.LF
           & "  ee.stf.128.ip f3, f2, f1, f0, %2, 16"
           & ASCII.LF
           & ".Lmin_f32_simd_loop_%=:"
           & ASCII.LF
           & ".Lmin_f32_tail_start_%=:",
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
end ESP32S3.SIMD.F32;
