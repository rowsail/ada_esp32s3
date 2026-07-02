pragma Ada_2022;

with ESP32S3.SIMD.Helpers;
with Ada.Unchecked_Conversion;
with Interfaces;
with Interfaces.C;
with System;
with System.Machine_Code;

package body ESP32S3.SIMD.I16 is

   use Interfaces;
   use Interfaces.C;
   use ESP32S3.SIMD.Helpers;
   use System;
   use System.Machine_Code;

   function Sat_I16 (V : Integer) return Integer_16 is
   begin
      if V > Integer (Integer_16'Last) then
         return Integer_16'Last;
      elsif V < Integer (Integer_16'First) then
         return Integer_16'First;
      else
         return Integer_16 (V);
      end if;
   end Sat_I16;

   function Sat_I32 (V : Long_Long_Integer) return Integer_32 is
   begin
      if V > Long_Long_Integer (Integer_32'Last) then
         return Integer_32'Last;
      elsif V < Long_Long_Integer (Integer_32'First) then
         return Integer_32'First;
      else
         return Integer_32 (V);
      end if;
   end Sat_I32;

   function Arith_Shr (V : Long_Long_Integer; Amount : Shift_I16) return Long_Long_Integer is
      D : constant Long_Long_Integer := Long_Long_Integer'(2**Amount);
   begin
      if Amount = 0 then
         return V;
      elsif V >= 0 then
         return V / D;
      else
         return -(((-V) + (D - 1)) / D);
      end if;
   end Arith_Shr;

   function To_U16 is new Ada.Unchecked_Conversion (Integer_16, Interfaces.Unsigned_16);
   function To_I16 is new Ada.Unchecked_Conversion (Interfaces.Unsigned_16, Integer_16);

   procedure Add (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui   %4, %3, 0, 3"
           & ASCII.LF
           & "srli    %3, %3, 3"
           & ASCII.LF
           & "beqz    %3, .Ladd_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Ladd_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Ladd_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & ".Ladd_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Ladd_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Ladd_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & ".Ladd_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Ladd_i16_tail_start_%=:",
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
           Sat_I16 (Integer (A (A'First + I)) + Integer (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Add;

   procedure Add_Scalar (A : SIMD_I16_Vector; Scalar : Integer_16; Result : in out SIMD_I16_Vector)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      S     : aliased Integer_16 := Scalar;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 3"
           & ASCII.LF
           & "srli    %2, %2, 3"
           & ASCII.LF
           & "beqz    %2, .Ladds_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.16.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Ladds_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Ladds_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & ".Ladds_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Ladds_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Ladds_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vadds.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & ".Ladds_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Ladds_i16_tail_start_%=:",
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
         Result (Result'First + I) := Sat_I16 (Integer (A (A'First + I)) + Integer (Scalar));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Add_Scalar;

   procedure Sub (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui   %4, %3, 0, 3"
           & ASCII.LF
           & "srli    %3, %3, 3"
           & ASCII.LF
           & "beqz    %3, .Lsub_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lsub_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lsub_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & ".Lsub_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lsub_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lsub_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & ".Lsub_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lsub_i16_tail_start_%=:",
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
           Sat_I16 (Integer (A (A'First + I)) - Integer (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Sub;

   procedure Mul_Shift (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector; Shift : Shift_I16)
   is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Sh    : unsigned := unsigned (Shift);
      Tail  : size_t := 0;
      I     : Natural;
      P     : Long_Long_Integer;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %5, %3, 0, 3"
           & ASCII.LF
           & "srli    %3, %3, 3"
           & ASCII.LF
           & "wsr     %4, sar"
           & ASCII.LF
           & "beqz    %3, .Lmulsh_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmulsh_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmulsh_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & ".Lmulsh_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmulsh_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmulsh_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip        q1, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %2, 16"
           & ASCII.LF
           & ".Lmulsh_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lmulsh_i16_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            unsigned'Asm_Output ("+r", Sh),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         P := Long_Long_Integer (A (A'First + I)) * Long_Long_Integer (B (B'First + I));
         Result (Result'First + I) := Sat_I16 (Integer (Arith_Shr (P, Shift)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Shift;

   procedure Mul_Scalar
     (A : SIMD_I16_Vector; Scalar : Integer_16; Result : in out SIMD_I16_Vector; Shift : Shift_I16)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Sh    : unsigned := unsigned (Shift);
      Tail  : size_t := 0;
      S     : aliased Integer_16 := Scalar;
      I     : Natural;
      P     : Long_Long_Integer;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %2, 0, 3"
           & ASCII.LF
           & "srli    %2, %2, 3"
           & ASCII.LF
           & "wsr     %3, sar"
           & ASCII.LF
           & "beqz    %2, .Lmuls_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.16.ip q1, %5, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lmuls_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lmuls_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & ".Lmuls_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmuls_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmuls_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip        q4, %1, 16"
           & ASCII.LF
           & ".Lmuls_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lmuls_i16_tail_start_%=:",
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
         P := Long_Long_Integer (A (A'First + I)) * Long_Long_Integer (Scalar);
         Result (Result'First + I) := Sat_I16 (Integer (Arith_Shr (P, Shift)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Scalar;

   procedure Mul_Widen (A, B : SIMD_I16_Vector; Result : in out SIMD_I32_Vector) is
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
           "extui   %4, %3, 0, 3"
           & ASCII.LF
           & "srli    %3, %3, 3"
           & ASCII.LF
           & "beqz    %3, .Lmulw_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmulw_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmulw_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ssai 16"
           & ASCII.LF
           & "  ee.vmul.s16 q2, q0, q1"
           & ASCII.LF
           & "  ssai 0"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.16 q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ssai 16"
           & ASCII.LF
           & "  ee.vmul.s16 q2, q0, q1"
           & ASCII.LF
           & "  ssai 0"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.16 q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ssai 16"
           & ASCII.LF
           & "  ee.vmul.s16 q2, q0, q1"
           & ASCII.LF
           & "  ssai 0"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.16 q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ssai 16"
           & ASCII.LF
           & "  ee.vmul.s16 q2, q0, q1"
           & ASCII.LF
           & "  ssai 0"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.16 q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lmulw_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmulw_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmulw_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ssai 16"
           & ASCII.LF
           & "  ee.vmul.s16 q2, q0, q1"
           & ASCII.LF
           & "  ssai 0"
           & ASCII.LF
           & "  ee.vmul.s16.ld.incp q1, %1, q3, q0, q1"
           & ASCII.LF
           & "  ee.vzip.16 q3, q2"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %2, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lmulw_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi    %1, %1, -16"
           & ASCII.LF
           & ".Lmulw_i16_tail_start_%=:",
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
           Sat_I32 (Long_Long_Integer (A (A'First + I)) * Long_Long_Integer (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Widen;

   procedure Neg (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Min_1 : aliased Integer_16 := -32767;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;
      Asm
        (Template =>
           "extui   %3, %2, 0, 3"
           & ASCII.LF
           & "srli    %2, %2, 3"
           & ASCII.LF
           & "beqz    %2, .Lneg_i16_tail_start_%="
           & ASCII.LF
           & "ssai 0"
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vcmp.eq.s16 q1, q1, q1"
           & ASCII.LF
           & "ee.vldbc.16.ip q2, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lneg_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lneg_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %1, 16"
           & ASCII.LF
           & ".Lneg_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lneg_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lneg_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q3, %1, 16"
           & ASCII.LF
           & ".Lneg_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lneg_i16_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Min_1'Address)),
         Clobber  => "a14,memory",
         Volatile => True);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         if A (A'First + I) = Integer_16'First then
            Result (Result'First + I) := Integer_16'Last;
         else
            Result (Result'First + I) := -A (A'First + I);
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Neg;

   procedure Abs_Val (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Min_1 : aliased Integer_16 := -32767;
      I     : Natural;
      V     : Integer_16;
   begin
      if A'Length = 0 then
         return;
      end if;
      Asm
        (Template =>
           "extui   %3, %2, 0, 3"
           & ASCII.LF
           & "srli    %2, %2, 3"
           & ASCII.LF
           & "beqz    %2, .Labs_i16_tail_start_%="
           & ASCII.LF
           & "ssai 0"
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vcmp.eq.s16 q1, q1, q1"
           & ASCII.LF
           & "ee.vldbc.16.ip q2, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Labs_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Labs_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s16 q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s16 q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s16 q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s16 q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & ".Labs_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Labs_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Labs_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q2"
           & ASCII.LF
           & "  ee.vmul.s16 q3, q4, q1"
           & ASCII.LF
           & "  ee.vmax.s16 q4, q4, q3"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & ".Labs_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Labs_i16_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Min_1'Address)),
         Clobber  => "a14,memory",
         Volatile => True);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         V := A (A'First + I);
         if V = Integer_16'First then
            Result (Result'First + I) := Integer_16'Last;
         elsif V < 0 then
            Result (Result'First + I) := -V;
         else
            Result (Result'First + I) := V;
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Abs_Val;

   function Sum (A : SIMD_I16_Vector) return Integer_32 is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      One   : aliased Integer_16 := 1;
      Part  : aliased Integer_32 := 0;
      I     : Natural;
      R     : Long_Long_Integer := 0;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %2, %1, 0, 3"
              & ASCII.LF
              & "srli    %1, %1, 3"
              & ASCII.LF
              & "movi.n  a6, 0"
              & ASCII.LF
              & "beqz    %1, .Lsum_i16_done_%="
              & ASCII.LF
              & "ee.zero.accx"
              & ASCII.LF
              & "ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "ee.vldbc.16.ip q1, %3, 0"
              & ASCII.LF
              & "extui   a14, %1, 0, 2"
              & ASCII.LF
              & "srli    %1, %1, 2"
              & ASCII.LF
              & "beqz    %1, .Lsum_i16_rem_start_%="
              & ASCII.LF
              & "loopnez %1, .Lsum_i16_loop4_%="
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Lsum_i16_loop4_%=:"
              & ASCII.LF
              & ".Lsum_i16_rem_start_%=:"
              & ASCII.LF
              & "loopnez a14, .Lsum_i16_loop_%="
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Lsum_i16_loop_%=:"
              & ASCII.LF
              & "rur.accx_0 a6"
              & ASCII.LF
              & "addi    %0, %0, -16"
              & ASCII.LF
              & ".Lsum_i16_done_%=:"
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
      R := Long_Long_Integer (Part);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         R := R + Long_Long_Integer (A (A'First + I));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      return Sat_I32 (R);
   end Sum;

   function Dot_Product (A, B : SIMD_I16_Vector) return Integer_32 is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Part  : aliased Integer_32 := 0;
      I     : Natural;
      R     : Long_Long_Integer := 0;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %3, %2, 0, 3"
              & ASCII.LF
              & "srli    %2, %2, 3"
              & ASCII.LF
              & "movi.n  a7, 0"
              & ASCII.LF
              & "beqz    %2, .Ldot_i16_done_%="
              & ASCII.LF
              & "ee.zero.accx"
              & ASCII.LF
              & "ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "extui   a14, %2, 0, 2"
              & ASCII.LF
              & "srli    %2, %2, 2"
              & ASCII.LF
              & "beqz    %2, .Ldot_i16_rem_start_%="
              & ASCII.LF
              & "loopnez %2, .Ldot_i16_loop4_%="
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Ldot_i16_loop4_%=:"
              & ASCII.LF
              & ".Ldot_i16_rem_start_%=:"
              & ASCII.LF
              & "loopnez a14, .Ldot_i16_loop_%="
              & ASCII.LF
              & "  ee.vld.128.ip q1, %1, 16"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Ldot_i16_loop_%=:"
              & ASCII.LF
              & "rur.accx_0 a7"
              & ASCII.LF
              & "addi    %0, %0, -16"
              & ASCII.LF
              & ".Ldot_i16_done_%=:"
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
      R := Long_Long_Integer (Part);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         R := R + Long_Long_Integer (A (A'First + I)) * Long_Long_Integer (B (B'First + I));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      return Sat_I32 (R);
   end Dot_Product;

   procedure MAC (A : SIMD_I16_Vector; Accumulator : in out Integer_32; Multiplier : Integer_16) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Mul   : aliased Integer_16 := Multiplier;
      Acc   : aliased Integer_32 := Accumulator;
      I     : Natural;
      R     : Long_Long_Integer := Long_Long_Integer (Accumulator);
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %2, %1, 0, 3"
              & ASCII.LF
              & "srli    %1, %1, 3"
              & ASCII.LF
              & "movi.n  a7, 0"
              & ASCII.LF
              & "beqz    %1, .Lmac_i16_done_%="
              & ASCII.LF
              & "ee.zero.accx"
              & ASCII.LF
              & "ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "ee.vldbc.16.ip q1, %4, 0"
              & ASCII.LF
              & "extui   a14, %1, 0, 2"
              & ASCII.LF
              & "srli    %1, %1, 2"
              & ASCII.LF
              & "beqz    %1, .Lmac_i16_rem_start_%="
              & ASCII.LF
              & "loopnez %1, .Lmac_i16_loop4_%="
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Lmac_i16_loop4_%=:"
              & ASCII.LF
              & ".Lmac_i16_rem_start_%=:"
              & ASCII.LF
              & "loopnez a14, .Lmac_i16_loop_%="
              & ASCII.LF
              & "  ee.vmulas.s16.accx.ld.ip q0, %0, 16, q0, q1"
              & ASCII.LF
              & ".Lmac_i16_loop_%=:"
              & ASCII.LF
              & "rur.accx_0 a7"
              & ASCII.LF
              & "addi    %0, %0, -16"
              & ASCII.LF
              & "l32i    a9, %3, 0"
              & ASCII.LF
              & "add     a7, a9, a7"
              & ASCII.LF
              & ".Lmac_i16_done_%=:"
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
         R := Long_Long_Integer (Acc);
      end if;

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         R := R + Long_Long_Integer (A (A'First + I)) * Long_Long_Integer (Multiplier);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      Accumulator := Sat_I32 (R);
   end MAC;

   procedure Relu
     (A          : SIMD_I16_Vector;
      Multiplier : Integer_32;
      Shift      : Shift_I16;
      Result     : in out SIMD_I16_Vector)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      M     : Integer_32 := Multiplier;
      Sh    : unsigned := unsigned (Shift);
      I     : Natural;
      V     : Long_Long_Integer;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %4, %2, 0, 3"
              & ASCII.LF
              & "srli    %2, %2, 3"
              & ASCII.LF
              & "extui   a14, %2, 0, 2"
              & ASCII.LF
              & "srli    %2, %2, 2"
              & ASCII.LF
              & "beqz    %2, .Lrelu_i16_rem_start_%="
              & ASCII.LF
              & "loopnez %2, .Lrelu_i16_loop4_%="
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s16 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s16 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s16 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s16 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & ".Lrelu_i16_loop4_%=:"
              & ASCII.LF
              & ".Lrelu_i16_rem_start_%=:"
              & ASCII.LF
              & "loopnez a14, .Lrelu_i16_loop_%="
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.vrelu.s16 q0, %5, %3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & ".Lrelu_i16_loop_%=:"
              & ASCII.LF
              & "extui   %4, %4, 0, 3",
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
         V := Long_Long_Integer (A (A'First + I));
         if V < 0 then
            V := Arith_Shr (V * Long_Long_Integer (Multiplier), Shift mod 32);
         end if;
         Result (Result'First + I) := Sat_I16 (Integer (V));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Relu;

   procedure Ceil (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector; Max_Val : Integer_16) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      M     : aliased Integer_16 := Max_Val;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;
      Asm
        (Template =>
           "extui   %3, %2, 0, 3"
           & ASCII.LF
           & "srli    %2, %2, 3"
           & ASCII.LF
           & "beqz    %2, .Lceil_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.16.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lceil_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lceil_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & ".Lceil_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lceil_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lceil_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & ".Lceil_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi   %0, %0, -16"
           & ASCII.LF
           & ".Lceil_i16_tail_start_%=:",
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

   procedure Floor (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector; Min_Val : Integer_16) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      M     : aliased Integer_16 := Min_Val;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;
      Asm
        (Template =>
           "extui   %3, %2, 0, 3"
           & ASCII.LF
           & "srli    %2, %2, 3"
           & ASCII.LF
           & "beqz    %2, .Lfloor_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.16.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lfloor_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lfloor_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & ".Lfloor_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lfloor_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lfloor_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & ".Lfloor_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi   %0, %0, -16"
           & ASCII.LF
           & ".Lfloor_i16_tail_start_%=:",
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

   procedure Max (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui   %4, %3, 0, 3"
           & ASCII.LF
           & "srli    %3, %3, 3"
           & ASCII.LF
           & "beqz    %3, .Lmax_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmax_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmax_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lmax_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmax_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmax_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lmax_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi   %0, %0, -16"
           & ASCII.LF
           & ".Lmax_i16_tail_start_%=:",
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

   procedure Min (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui   %4, %3, 0, 3"
           & ASCII.LF
           & "srli    %3, %3, 3"
           & ASCII.LF
           & "beqz    %3, .Lmin_i16_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmin_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmin_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lmin_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmin_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmin_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s16.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lmin_i16_simd_loop_%=:"
           & ASCII.LF
           & "addi   %0, %0, -16"
           & ASCII.LF
           & ".Lmin_i16_tail_start_%=:",
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

   procedure Bitwise_And (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui %4, %3, 0, 3"
           & ASCII.LF
           & "srli  %3, %3, 3"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Land_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Land_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Land_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Land_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Land_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Land_i16_simd_loop_%=:"
           & ASCII.LF
           & "extui %4, %4, 0, 3",
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
           To_I16 (To_U16 (A (A'First + I)) and To_U16 (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Bitwise_And;

   procedure Bitwise_Or (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui %4, %3, 0, 3"
           & ASCII.LF
           & "srli  %3, %3, 3"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lor_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lor_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lor_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lor_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lor_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lor_i16_simd_loop_%=:"
           & ASCII.LF
           & "extui %4, %4, 0, 3",
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
           To_I16 (To_U16 (A (A'First + I)) or To_U16 (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Bitwise_Or;

   procedure Bitwise_Xor (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui %4, %3, 0, 3"
           & ASCII.LF
           & "srli  %3, %3, 3"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lxor_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lxor_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lxor_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lxor_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lxor_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lxor_i16_simd_loop_%=:"
           & ASCII.LF
           & "extui %4, %4, 0, 3",
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
           To_I16 (To_U16 (A (A'First + I)) xor To_U16 (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Bitwise_Xor;

   procedure Bitwise_Not (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
      A_Ptr : Address := First_Address (A);
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
           "extui %3, %2, 0, 3"
           & ASCII.LF
           & "srli  %2, %2, 3"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lnot_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lnot_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & ".Lnot_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lnot_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lnot_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & ".Lnot_i16_simd_loop_%=:"
           & ASCII.LF
           & "extui %3, %3, 0, 3",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,memory",
         Volatile => True);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) := To_I16 (not To_U16 (A (A'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Bitwise_Not;

   procedure Compare_GT (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui %4, %3, 0, 3"
           & ASCII.LF
           & "srli  %3, %3, 3"
           & ASCII.LF
           & "beqz %3, .Lcgt_i16_tail_start_%="
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lcgt_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lcgt_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcgt_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcgt_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcgt_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcgt_i16_simd_loop_%=:"
           & ASCII.LF
           & ".Lcgt_i16_tail_start_%=:"
           & ASCII.LF
           & "extui %4, %4, 0, 3",
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
         if A (A'First + I) > B (B'First + I) then
            Result (Result'First + I) := -1;
         else
            Result (Result'First + I) := 0;
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Compare_GT;

   procedure Compare_LT (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui %4, %3, 0, 3"
           & ASCII.LF
           & "srli  %3, %3, 3"
           & ASCII.LF
           & "beqz %3, .Lclt_i16_tail_start_%="
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lclt_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lclt_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lclt_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lclt_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lclt_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lclt_i16_simd_loop_%=:"
           & ASCII.LF
           & ".Lclt_i16_tail_start_%=:"
           & ASCII.LF
           & "extui %4, %4, 0, 3",
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
         if A (A'First + I) < B (B'First + I) then
            Result (Result'First + I) := -1;
         else
            Result (Result'First + I) := 0;
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Compare_LT;

   procedure Compare_EQ (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
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
           "extui %4, %3, 0, 3"
           & ASCII.LF
           & "srli  %3, %3, 3"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lceq_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lceq_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lceq_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lceq_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lceq_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s16 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lceq_i16_simd_loop_%=:"
           & ASCII.LF
           & "extui %4, %4, 0, 3",
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
         if A (A'First + I) = B (B'First + I) then
            Result (Result'First + I) := -1;
         else
            Result (Result'First + I) := 0;
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Compare_EQ;

   procedure Zeros (A : in out SIMD_I16_Vector) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;
      Asm
        (Template =>
           "extui %2, %1, 0, 3"
           & ASCII.LF
           & "srli  %1, %1, 3"
           & ASCII.LF
           & "ee.xorq q0, q0, q0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lzeros_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lzeros_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lzeros_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lzeros_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lzeros_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lzeros_i16_simd_loop_%=:"
           & ASCII.LF
           & "extui %2, %2, 0, 3",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,memory",
         Volatile => True);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         A (A'First + I) := 0;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Zeros;

   procedure Ones (A : in out SIMD_I16_Vector) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      One   : aliased Integer_16 := 1;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;
      Asm
        (Template =>
           "extui %2, %1, 0, 3"
           & ASCII.LF
           & "srli  %1, %1, 3"
           & ASCII.LF
           & "ee.vldbc.16.ip q0, %3, 0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lones_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lones_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lones_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lones_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lones_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lones_i16_simd_loop_%=:"
           & ASCII.LF
           & "extui %2, %2, 0, 3",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", One'Address)),
         Clobber  => "a14,memory",
         Volatile => True);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         A (A'First + I) := 1;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Ones;

   procedure Fill (A : in out SIMD_I16_Vector; Value : Integer_16) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      V     : aliased Integer_16 := Value;
      I     : Natural;
   begin
      if A'Length = 0 then
         return;
      end if;
      Asm
        (Template =>
           "extui %2, %1, 0, 3"
           & ASCII.LF
           & "srli  %1, %1, 3"
           & ASCII.LF
           & "ee.vldbc.16.ip q0, %3, 0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lfill_i16_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lfill_i16_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lfill_i16_simd_loop4_%=:"
           & ASCII.LF
           & ".Lfill_i16_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lfill_i16_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lfill_i16_simd_loop_%=:"
           & ASCII.LF
           & "extui %2, %2, 0, 3",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", V'Address)),
         Clobber  => "a14,memory",
         Volatile => True);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         A (A'First + I) := Value;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Fill;

   procedure Copy (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length / 8);
      Tail  : size_t := size_t (A'Length mod 8);
      I     : Natural;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "beqz    %2, .Lcopy_i16_tail_start_%="
              & ASCII.LF
              & "loopnez %2, .Lcopy_i16_simd_loop_%="
              & ASCII.LF
              & "  ee.vld.128.ip q1, %0, 16"
              & ASCII.LF
              & "  ee.vst.128.ip q1, %1, 16"
              & ASCII.LF
              & ".Lcopy_i16_simd_loop_%=:"
              & ASCII.LF
              & ".Lcopy_i16_tail_start_%=:",
            Outputs  =>
              (Address'Asm_Output ("+r", A_Ptr),
               Address'Asm_Output ("+r", R_Ptr),
               size_t'Asm_Output ("+r", Cnt)),
            Inputs   => No_Input_Operands,
            Clobber  => "memory",
            Volatile => True);
      end if;
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) := A (A'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Copy;

   procedure Convert_To_I32 (A : SIMD_I16_Vector; Result : in out SIMD_I32_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length / 8);
      Tail  : size_t := size_t (A'Length mod 8);
      Sx    : aliased Integer_32 := 16#0000_8000#;
      I     : Natural;
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "beqz  %2, .Lto_i32_tail_start_%="
              & ASCII.LF
              & "ee.vldbc.16 q2, %3"
              & ASCII.LF
              & "ee.vldbc.32 q3, %3"
              & ASCII.LF
              & "loopnez %2, .Lto_i32_simd_loop_%="
              & ASCII.LF
              & "  ee.vld.128.ip q0, %0, 16"
              & ASCII.LF
              & "  ee.xorq q1, q1, q1"
              & ASCII.LF
              & "  ee.xorq q0, q0, q2"
              & ASCII.LF
              & "  ee.vzip.16 q0, q1"
              & ASCII.LF
              & "  ee.vsubs.s32 q0, q0, q3"
              & ASCII.LF
              & "  ee.vsubs.s32 q1, q1, q3"
              & ASCII.LF
              & "  ee.vst.128.ip q0, %1, 16"
              & ASCII.LF
              & "  ee.vst.128.ip q1, %1, 16"
              & ASCII.LF
              & ".Lto_i32_simd_loop_%=:"
              & ASCII.LF
              & ".Lto_i32_tail_start_%=:",
            Outputs  =>
              (Address'Asm_Output ("+r", A_Ptr),
               Address'Asm_Output ("+r", R_Ptr),
               size_t'Asm_Output ("+r", Cnt)),
            Inputs   => (Address'Asm_Input ("r", Sx'Address)),
            Clobber  => "memory",
            Volatile => True);
      end if;
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) := Integer_32 (A (A'First + I));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Convert_To_I32;
end ESP32S3.SIMD.I16;
