pragma Ada_2022;

with ESP32S3.SIMD.Helpers;
with Ada.Unchecked_Conversion;
with Interfaces;
with Interfaces.C;
with System;
with System.Machine_Code;

package body ESP32S3.SIMD.I32 is

   use Interfaces;
   use Interfaces.C;
   use ESP32S3.SIMD.Helpers;
   use System;
   use System.Machine_Code;

   --  Convert a wider intermediate value back to Integer_32 with saturation.
   --
   --  Many SIMD operations here do their math in Long_Long_Integer first so
   --  the intermediate product or sum can temporarily exceed the 32-bit range
   --  without overflowing immediately.  When we finally store the value back
   --  into an Integer_32 lane, we do not want wraparound; we want the result
   --  clamped to the nearest representable 32-bit signed value.
   --
   --  In other words:
   --    * values above Integer_32'Last become Integer_32'Last
   --    * values below Integer_32'First become Integer_32'First
   --    * values already in range are converted normally
   function Sat_I32 (V : Long_Long_Integer) return Integer_32 is
   begin
      --  If the widened computation produced something larger than a signed
      --  32-bit integer can hold, clamp it to the largest legal lane value.
      if V > Long_Long_Integer (Integer_32'Last) then
         return Integer_32'Last;

      --  Likewise, clamp underflow to the most negative 32-bit value.
      elsif V < Long_Long_Integer (Integer_32'First) then
         return Integer_32'First;

      --  Otherwise the value is safe to narrow back to Integer_32 exactly.
      else
         return Integer_32 (V);
      end if;
   end Sat_I32;

   --  Arithmetic right shift for a signed widened value.
   --
   --  This helper is used for the scalar tail path of fixed-point style
   --  multiply-and-shift operations.  The Xtensa assembly path uses hardware
   --  shift behavior directly, but in Ada we need to reproduce the same idea
   --  explicitly for Long_Long_Integer intermediates.
   --
   --  The key detail is that this must behave like an *arithmetic* shift,
   --  not a logical one:
   --    * positive values shift right toward zero in the obvious way
   --    * negative values keep their sign and round toward negative infinity
   --
   --  Example with Amount = 1:
   --    *  9  becomes  4
   --    * -9  becomes -5
   --
   --  That second case is why we cannot just rely on a plain division formula
   --  for all inputs; negative values need a small bias before dividing so the
   --  result matches arithmetic-shift semantics.
   function Arith_Shr (V : Long_Long_Integer; Amount : Shift_I32) return Long_Long_Integer is
      --  2 ** Amount is the divisor equivalent to shifting right by Amount
      --  bits.  For example, shifting right by 3 is the same as dividing by 8,
      --  with the special handling below for negative values.
      D : constant Long_Long_Integer := Long_Long_Integer'(2**Amount);
   begin
      --  A shift by zero leaves the value unchanged.
      if Amount = 0 then
         return V;

      --  For non-negative values, ordinary division already matches the result
      --  of an arithmetic right shift.
      elsif V >= 0 then
         return V / D;

      --  For negative values we compute the result manually so the sign bit is
      --  effectively preserved.  The inner expression rounds the magnitude up
      --  before division, and the outer minus sign restores the original sign.
      --  This gives the same result you would expect from shifting a signed
      --  two's-complement value to the right.
      else
         return -(((-V) + (D - 1)) / D);
      end if;
   end Arith_Shr;

   function To_U32 is new Ada.Unchecked_Conversion (Integer_32, Interfaces.Unsigned_32);
   function To_I32 is new Ada.Unchecked_Conversion (Interfaces.Unsigned_32, Integer_32);

   procedure Add (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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

      --  GNAT's Asm procedure is Ada's way to embed a raw assembly fragment
      --  directly inside a subprogram body.
      --
      --  The call is split into a few important parts:
      --    * Template: the actual assembly text to emit
      --    * Outputs: Ada variables/registers modified by the assembly
      --    * Inputs: Ada values made available to the assembly
      --    * Clobber: registers or state the assembly may destroy implicitly
      --    * Volatile: tells the compiler not to optimize the block away or
      --      assume it has no externally visible effect
      --
      --  Inside the Template string, placeholders such as %0, %1, %2 ... refer
      --  to operands in the Outputs/Inputs lists in order.
      --
      --  In this block:
      --    * %0 is A_Ptr
      --    * %1 is B_Ptr
      --    * %2 is R_Ptr
      --    * %3 is Cnt
      --    * %4 is Tail
      --
      --  The assembler text updates those Ada variables in place.  For example,
      --  when the template increments %0 or %1, it is really advancing A_Ptr or
      --  B_Ptr so Ada can see the final pointer position afterward.
      Asm
        (Template =>
         --  Step 1: split the vector length into:
         --    * a SIMD block count held in Cnt (%3)
         --    * a leftover element count held in Tail (%4)
         --  Because each 128-bit register holds four 32-bit lanes, the low
         --  two bits of the original element count are the scalar remainder.
           "extui   %4, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           &

           --  If there are no full SIMD blocks, skip straight to the scalar
           --  cleanup path after the Asm call.
                                                "beqz    %3, .Ladd_i32_tail_start_%="
           & ASCII.LF
           &

           --  Prime q0 with the first 128-bit chunk from A.  The later
           --  `ld.incp` instructions both compute the current result and load
           --  the next chunk of A in a single instruction.
                                                            "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           &

           --  Further split the SIMD block count into groups of four full SIMD
           --  iterations plus a small remainder.  This is manual loop unrolling:
           --  do four vector additions per loop body to reduce loop overhead.
                                                                               "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Ladd_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Ladd_i32_simd_loop4_%="
           & ASCII.LF
           &

           --  Each triplet below does one vector add step:
           --    1. load the next 128-bit chunk from B into q1
           --    2. add q0 and q1, writing the result to q4, and at the same
           --       time load the next chunk from A back into q0
           --    3. store q4 to the result buffer
                                                  "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & ".Ladd_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Ladd_i32_simd_rem_start_%=:"
           & ASCII.LF
           &

           --  Finish any leftover SIMD iterations that did not fit the unrolled
           --  four-at-a-time loop.
                                    "loopnez a14, .Ladd_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & ".Ladd_i32_simd_loop_%=:"
           & ASCII.LF
           &

           --  The pipelined `ld.incp` form leaves A_Ptr one chunk ahead when
           --  SIMD work completes, so we pull it back by 16 bytes.  That keeps
           --  the post-assembly pointer state consistent with the scalar tail
           --  calculation that follows.
                                         "addi    %0, %0, -16"
           & ASCII.LF
           & ".Ladd_i32_tail_start_%=:",
         Outputs  =>
         --  "+r" means: place this operand in a register and treat it as both
         --  an input and an output.  The assembly reads the initial value and
         --  may write back an updated one.
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),

            --  "=&r" means an early-clobber output register.  The compiler must
            --  allocate a fresh register because the assembly writes this value
            --  before it is safe to overlap with other operands.
            size_t'Asm_Output ("=&r", Tail)),

         --  This block does not need any separate input-only operands because
         --  everything it reads comes from the read/write outputs above.
         Inputs   => No_Input_Operands,

         --  The template uses register a14 explicitly, so we declare it clobbered.
         --  `memory` tells the compiler that the assembly reads/writes memory in
         --  ways it cannot fully reason about just from the operand list.
         Clobber  => "a14,memory",
         Volatile => True);

      --  After the vectorized part finishes, Tail holds however many elements
      --  were left over because the length was not a multiple of four.
      --  Those last elements are handled in plain Ada so the routine works for
      --  any vector length, not just SIMD-aligned lengths.
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) :=
           Sat_I32 (Long_Long_Integer (A (A'First + I)) + Long_Long_Integer (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Add;

   procedure Add_Scalar (A : SIMD_I32_Vector; Scalar : Integer_32; Result : in out SIMD_I32_Vector)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      S     : aliased Integer_32 := Scalar;
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
           & "beqz    %2, .Ladds_i32_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.32.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Ladds_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Ladds_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & ".Ladds_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Ladds_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Ladds_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %1, 16"
           & ASCII.LF
           & ".Ladds_i32_simd_loop_%=:"
           & ASCII.LF
           & ".Ladds_i32_tail_start_%=:",
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
         Result (Result'First + I) :=
           Sat_I32 (Long_Long_Integer (A (A'First + I)) + Long_Long_Integer (Scalar));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Add_Scalar;

   procedure Sub (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "beqz    %3, .Lsub_i32_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lsub_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lsub_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & ".Lsub_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lsub_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lsub_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip         q1, %1, 16"
           & ASCII.LF
           & "  ee.vsubs.s32.ld.incp  q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip         q4, %2, 16"
           & ASCII.LF
           & ".Lsub_i32_simd_loop_%=:"
           & ASCII.LF
           & ".Lsub_i32_tail_start_%=:",
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
           Sat_I32 (Long_Long_Integer (A (A'First + I)) - Long_Long_Integer (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Sub;

   procedure Mul_Shift (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Shift : Shift_I32)
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
           "extui   %5, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "wsr     %4, sar"
           & ASCII.LF
           & "beqz    %3, .Lmulsh_i32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmulsh_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmulsh_i32_simd_loop4_%="
           & ASCII.LF
           & "  l32i.n   a8,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  l32i.n   a11, %1, 4"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 0"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 4"
           & ASCII.LF
           & "  l32i.n   a8,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  l32i.n   a11, %1, 12"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 8"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & "  addi     %2, %2, 16"
           & ASCII.LF
           & "  l32i.n   a8,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  l32i.n   a11, %1, 4"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 0"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 4"
           & ASCII.LF
           & "  l32i.n   a8,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  l32i.n   a11, %1, 12"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 8"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & "  addi     %2, %2, 16"
           & ASCII.LF
           & "  l32i.n   a8,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  l32i.n   a11, %1, 4"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 0"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 4"
           & ASCII.LF
           & "  l32i.n   a8,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  l32i.n   a11, %1, 12"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 8"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & "  addi     %2, %2, 16"
           & ASCII.LF
           & "  l32i.n   a8,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  l32i.n   a11, %1, 4"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 0"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 4"
           & ASCII.LF
           & "  l32i.n   a8,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  l32i.n   a11, %1, 12"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 8"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & "  addi     %2, %2, 16"
           & ASCII.LF
           & ".Lmulsh_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmulsh_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmulsh_i32_simd_loop_%="
           & ASCII.LF
           & "  l32i.n   a8,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  l32i.n   a11, %1, 4"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 0"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 4"
           & ASCII.LF
           & "  l32i.n   a8,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  l32i.n   a11, %1, 12"
           & ASCII.LF
           & "  mulsh    a12, a8,  a9"
           & ASCII.LF
           & "  mull     a8,  a8,  a9"
           & ASCII.LF
           & "  src      a8,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a8,  %2, 8"
           & ASCII.LF
           & "  mulsh    a12, a10, a11"
           & ASCII.LF
           & "  mull     a8,  a10, a11"
           & ASCII.LF
           & "  src      a9,  a12, a8"
           & ASCII.LF
           & "  s32i.n   a9,  %2, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & "  addi     %2, %2, 16"
           & ASCII.LF
           & ".Lmulsh_i32_simd_loop_%=:"
           & ASCII.LF
           & ".Lmulsh_i32_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            unsigned'Asm_Output ("+r", Sh),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a8,a9,a10,a11,a12,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         P := Long_Long_Integer (A (A'First + I)) * Long_Long_Integer (B (B'First + I));
         Result (Result'First + I) := Sat_I32 (Arith_Shr (P, Shift));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Shift;

   procedure Mul_Scalar
     (A : SIMD_I32_Vector; Scalar : Integer_32; Result : in out SIMD_I32_Vector; Shift : Shift_I32)
   is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Sh    : unsigned := unsigned (Shift);
      Tail  : size_t := 0;
      S     : aliased Integer_32 := Scalar;
      I     : Natural;
      P     : Long_Long_Integer;
   begin
      if A'Length = 0 then
         return;
      end if;

      Asm
        (Template =>
           "extui   %4, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "l32i    a8, %5, 0"
           & ASCII.LF
           & "wsr     %3, sar"
           & ASCII.LF
           & "beqz    %2, .Lmuls_i32_tail_start_%="
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lmuls_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lmuls_i32_simd_loop4_%="
           & ASCII.LF
           & "  l32i.n   a9,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  s32i.n   a10, %1, 4"
           & ASCII.LF
           & "  l32i.n   a9,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  s32i.n   a10, %1, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & "  l32i.n   a9,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  s32i.n   a10, %1, 4"
           & ASCII.LF
           & "  l32i.n   a9,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  s32i.n   a10, %1, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & "  l32i.n   a9,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  s32i.n   a10, %1, 4"
           & ASCII.LF
           & "  l32i.n   a9,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  s32i.n   a10, %1, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & "  l32i.n   a9,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  s32i.n   a10, %1, 4"
           & ASCII.LF
           & "  l32i.n   a9,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  s32i.n   a10, %1, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & ".Lmuls_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmuls_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmuls_i32_simd_loop_%="
           & ASCII.LF
           & "  l32i.n   a9,  %0, 0"
           & ASCII.LF
           & "  l32i.n   a10, %0, 4"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 0"
           & ASCII.LF
           & "  s32i.n   a10, %1, 4"
           & ASCII.LF
           & "  l32i.n   a9,  %0, 8"
           & ASCII.LF
           & "  l32i.n   a10, %0, 12"
           & ASCII.LF
           & "  mulsh    a11, a9,  a8"
           & ASCII.LF
           & "  mull     a9,  a9,  a8"
           & ASCII.LF
           & "  mulsh    a12, a10, a8"
           & ASCII.LF
           & "  mull     a10, a10, a8"
           & ASCII.LF
           & "  src      a9,  a11, a9"
           & ASCII.LF
           & "  src      a10, a12, a10"
           & ASCII.LF
           & "  s32i.n   a9,  %1, 8"
           & ASCII.LF
           & "  s32i.n   a10, %1, 12"
           & ASCII.LF
           & "  addi     %0, %0, 16"
           & ASCII.LF
           & "  addi     %1, %1, 16"
           & ASCII.LF
           & ".Lmuls_i32_simd_loop_%=:"
           & ASCII.LF
           & ".Lmuls_i32_tail_start_%=:",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            unsigned'Asm_Output ("+r", Sh),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", S'Address)),
         Clobber  => "a14,a8,a9,a10,a11,a12,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         P := Long_Long_Integer (A (A'First + I)) * Long_Long_Integer (Scalar);
         Result (Result'First + I) := Sat_I32 (Arith_Shr (P, Shift));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Mul_Scalar;

   procedure Neg (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lneg_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lneg_i32_simd_loop4_%="
           & ASCII.LF
           & "  l32i.n a7, %0, 0"
           & ASCII.LF
           & "  l32i.n a8, %0, 4"
           & ASCII.LF
           & "  l32i.n a9, %0, 8"
           & ASCII.LF
           & "  l32i.n a10, %0, 12"
           & ASCII.LF
           & "  neg    a7, a7"
           & ASCII.LF
           & "  neg    a8, a8"
           & ASCII.LF
           & "  neg    a9, a9"
           & ASCII.LF
           & "  neg    a10, a10"
           & ASCII.LF
           & "  s32i.n a7, %1, 0"
           & ASCII.LF
           & "  s32i.n a8, %1, 4"
           & ASCII.LF
           & "  s32i.n a9, %1, 8"
           & ASCII.LF
           & "  s32i.n a10, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & "  l32i.n a7, %0, 0"
           & ASCII.LF
           & "  l32i.n a8, %0, 4"
           & ASCII.LF
           & "  l32i.n a9, %0, 8"
           & ASCII.LF
           & "  l32i.n a10, %0, 12"
           & ASCII.LF
           & "  neg    a7, a7"
           & ASCII.LF
           & "  neg    a8, a8"
           & ASCII.LF
           & "  neg    a9, a9"
           & ASCII.LF
           & "  neg    a10, a10"
           & ASCII.LF
           & "  s32i.n a7, %1, 0"
           & ASCII.LF
           & "  s32i.n a8, %1, 4"
           & ASCII.LF
           & "  s32i.n a9, %1, 8"
           & ASCII.LF
           & "  s32i.n a10, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & "  l32i.n a7, %0, 0"
           & ASCII.LF
           & "  l32i.n a8, %0, 4"
           & ASCII.LF
           & "  l32i.n a9, %0, 8"
           & ASCII.LF
           & "  l32i.n a10, %0, 12"
           & ASCII.LF
           & "  neg    a7, a7"
           & ASCII.LF
           & "  neg    a8, a8"
           & ASCII.LF
           & "  neg    a9, a9"
           & ASCII.LF
           & "  neg    a10, a10"
           & ASCII.LF
           & "  s32i.n a7, %1, 0"
           & ASCII.LF
           & "  s32i.n a8, %1, 4"
           & ASCII.LF
           & "  s32i.n a9, %1, 8"
           & ASCII.LF
           & "  s32i.n a10, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & "  l32i.n a7, %0, 0"
           & ASCII.LF
           & "  l32i.n a8, %0, 4"
           & ASCII.LF
           & "  l32i.n a9, %0, 8"
           & ASCII.LF
           & "  l32i.n a10, %0, 12"
           & ASCII.LF
           & "  neg    a7, a7"
           & ASCII.LF
           & "  neg    a8, a8"
           & ASCII.LF
           & "  neg    a9, a9"
           & ASCII.LF
           & "  neg    a10, a10"
           & ASCII.LF
           & "  s32i.n a7, %1, 0"
           & ASCII.LF
           & "  s32i.n a8, %1, 4"
           & ASCII.LF
           & "  s32i.n a9, %1, 8"
           & ASCII.LF
           & "  s32i.n a10, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & ".Lneg_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lneg_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lneg_i32_simd_loop_%="
           & ASCII.LF
           & "  l32i.n a7, %0, 0"
           & ASCII.LF
           & "  l32i.n a8, %0, 4"
           & ASCII.LF
           & "  l32i.n a9, %0, 8"
           & ASCII.LF
           & "  l32i.n a10, %0, 12"
           & ASCII.LF
           & "  neg    a7, a7"
           & ASCII.LF
           & "  neg    a8, a8"
           & ASCII.LF
           & "  neg    a9, a9"
           & ASCII.LF
           & "  neg    a10, a10"
           & ASCII.LF
           & "  s32i.n a7, %1, 0"
           & ASCII.LF
           & "  s32i.n a8, %1, 4"
           & ASCII.LF
           & "  s32i.n a9, %1, 8"
           & ASCII.LF
           & "  s32i.n a10, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & ".Lneg_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %3, %3, 0, 2",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a7,a8,a9,a10,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         Result (Result'First + I) := -A (A'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Neg;

   procedure Abs_Val (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      I     : Natural;
      V     : Integer_32;
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
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Labs_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Labs_i32_simd_loop4_%="
           & ASCII.LF
           & "  l32i.n a6, %0, 0"
           & ASCII.LF
           & "  l32i.n a7, %0, 4"
           & ASCII.LF
           & "  l32i.n a8, %0, 8"
           & ASCII.LF
           & "  l32i.n a9, %0, 12"
           & ASCII.LF
           & "  abs    a6, a6"
           & ASCII.LF
           & "  abs    a7, a7"
           & ASCII.LF
           & "  abs    a8, a8"
           & ASCII.LF
           & "  abs    a9, a9"
           & ASCII.LF
           & "  s32i.n a6, %1, 0"
           & ASCII.LF
           & "  s32i.n a7, %1, 4"
           & ASCII.LF
           & "  s32i.n a8, %1, 8"
           & ASCII.LF
           & "  s32i.n a9, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & "  l32i.n a6, %0, 0"
           & ASCII.LF
           & "  l32i.n a7, %0, 4"
           & ASCII.LF
           & "  l32i.n a8, %0, 8"
           & ASCII.LF
           & "  l32i.n a9, %0, 12"
           & ASCII.LF
           & "  abs    a6, a6"
           & ASCII.LF
           & "  abs    a7, a7"
           & ASCII.LF
           & "  abs    a8, a8"
           & ASCII.LF
           & "  abs    a9, a9"
           & ASCII.LF
           & "  s32i.n a6, %1, 0"
           & ASCII.LF
           & "  s32i.n a7, %1, 4"
           & ASCII.LF
           & "  s32i.n a8, %1, 8"
           & ASCII.LF
           & "  s32i.n a9, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & "  l32i.n a6, %0, 0"
           & ASCII.LF
           & "  l32i.n a7, %0, 4"
           & ASCII.LF
           & "  l32i.n a8, %0, 8"
           & ASCII.LF
           & "  l32i.n a9, %0, 12"
           & ASCII.LF
           & "  abs    a6, a6"
           & ASCII.LF
           & "  abs    a7, a7"
           & ASCII.LF
           & "  abs    a8, a8"
           & ASCII.LF
           & "  abs    a9, a9"
           & ASCII.LF
           & "  s32i.n a6, %1, 0"
           & ASCII.LF
           & "  s32i.n a7, %1, 4"
           & ASCII.LF
           & "  s32i.n a8, %1, 8"
           & ASCII.LF
           & "  s32i.n a9, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & "  l32i.n a6, %0, 0"
           & ASCII.LF
           & "  l32i.n a7, %0, 4"
           & ASCII.LF
           & "  l32i.n a8, %0, 8"
           & ASCII.LF
           & "  l32i.n a9, %0, 12"
           & ASCII.LF
           & "  abs    a6, a6"
           & ASCII.LF
           & "  abs    a7, a7"
           & ASCII.LF
           & "  abs    a8, a8"
           & ASCII.LF
           & "  abs    a9, a9"
           & ASCII.LF
           & "  s32i.n a6, %1, 0"
           & ASCII.LF
           & "  s32i.n a7, %1, 4"
           & ASCII.LF
           & "  s32i.n a8, %1, 8"
           & ASCII.LF
           & "  s32i.n a9, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & ".Labs_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Labs_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Labs_i32_simd_loop_%="
           & ASCII.LF
           & "  l32i.n a6, %0, 0"
           & ASCII.LF
           & "  l32i.n a7, %0, 4"
           & ASCII.LF
           & "  l32i.n a8, %0, 8"
           & ASCII.LF
           & "  l32i.n a9, %0, 12"
           & ASCII.LF
           & "  abs    a6, a6"
           & ASCII.LF
           & "  abs    a7, a7"
           & ASCII.LF
           & "  abs    a8, a8"
           & ASCII.LF
           & "  abs    a9, a9"
           & ASCII.LF
           & "  s32i.n a6, %1, 0"
           & ASCII.LF
           & "  s32i.n a7, %1, 4"
           & ASCII.LF
           & "  s32i.n a8, %1, 8"
           & ASCII.LF
           & "  s32i.n a9, %1, 12"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & ".Labs_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %3, %3, 0, 2",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", R_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => No_Input_Operands,
         Clobber  => "a14,a6,a7,a8,a9,memory",
         Volatile => True);

      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         V := A (A'First + I);
         if V = Integer_32'First then
            Result (Result'First + I) := Integer_32'Last;
         elsif V < 0 then
            Result (Result'First + I) := -V;
         else
            Result (Result'First + I) := V;
         end if;
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Abs_Val;

   function Sum (A : SIMD_I32_Vector) return Integer_32 is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Part  : aliased Integer_32 := 0;
      I     : Natural;
      R     : Long_Long_Integer := 0;
   begin
      if A'Length = 0 then
         return 0;
      end if;

      Asm
        (Template =>
           "extui   %2, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "movi.n  a6, 0"
           & ASCII.LF
           & "beqz    %1, .Lsum_i32_done_%="
           & ASCII.LF
           & "ee.xorq q0, q0, q0"
           & ASCII.LF
           & "ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lsum_i32_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lsum_i32_loop4_%="
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp q1, %0, q0, q1, q0"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp q1, %0, q0, q1, q0"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp q1, %0, q0, q1, q0"
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp q1, %0, q0, q1, q0"
           & ASCII.LF
           & ".Lsum_i32_loop4_%=:"
           & ASCII.LF
           & ".Lsum_i32_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lsum_i32_loop_%="
           & ASCII.LF
           & "  ee.vadds.s32.ld.incp q1, %0, q0, q1, q0"
           & ASCII.LF
           & ".Lsum_i32_loop_%=:"
           & ASCII.LF
           & "ee.movi.32.a q0, a6, 0"
           & ASCII.LF
           & "ee.movi.32.a q0, a7, 1"
           & ASCII.LF
           & "ee.movi.32.a q0, a8, 2"
           & ASCII.LF
           & "ee.movi.32.a q0, a9, 3"
           & ASCII.LF
           & "add.n   a6, a6, a7"
           & ASCII.LF
           & "add.n   a6, a6, a8"
           & ASCII.LF
           & "add.n   a6, a6, a9"
           & ASCII.LF
           & "addi    %0, %0, -16"
           & ASCII.LF
           & ".Lsum_i32_done_%=:"
           & ASCII.LF
           & "s32i.n  a6, %3, 0",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Part'Address)),
         Clobber  => "a14,a6,a7,a8,a9,memory",
         Volatile => True);

      R := Long_Long_Integer (Part);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         R := R + Long_Long_Integer (A (A'First + I));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      return Sat_I32 (R);
   end Sum;

   function Dot_Product (A, B : SIMD_I32_Vector) return Integer_32 is
      A_Ptr : Address := First_Address (A);
      B_Ptr : Address := First_Address (B);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Part  : aliased Integer_32 := 0;
      I     : Natural;
      R     : Long_Long_Integer := 0;
   begin
      if A'Length = 0 then
         return 0;
      end if;

      Asm
        (Template =>
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "movi.n  a11, 0"
           & ASCII.LF
           & "movi.n  a12, 0"
           & ASCII.LF
           & "movi.n  a13, 0"
           & ASCII.LF
           & "movi.n  a15, 0"
           & ASCII.LF
           & "beqz    %2, .Ldot_i32_done_%="
           & ASCII.LF
           & "loopnez %2, .Ldot_i32_loop_%="
           & ASCII.LF
           & "  l32i.n a7, %0, 0"
           & ASCII.LF
           & "  l32i.n a8, %1, 0"
           & ASCII.LF
           & "  l32i.n a9, %0, 4"
           & ASCII.LF
           & "  l32i.n a10, %1, 4"
           & ASCII.LF
           & "  mull   a7, a7, a8"
           & ASCII.LF
           & "  mull   a9, a9, a10"
           & ASCII.LF
           & "  add.n  a11, a11, a7"
           & ASCII.LF
           & "  add.n  a12, a12, a9"
           & ASCII.LF
           & "  l32i.n a7, %0, 8"
           & ASCII.LF
           & "  l32i.n a8, %1, 8"
           & ASCII.LF
           & "  l32i.n a9, %0, 12"
           & ASCII.LF
           & "  l32i.n a10, %1, 12"
           & ASCII.LF
           & "  mull   a7, a7, a8"
           & ASCII.LF
           & "  mull   a9, a9, a10"
           & ASCII.LF
           & "  add.n  a13, a13, a7"
           & ASCII.LF
           & "  add.n  a15, a15, a9"
           & ASCII.LF
           & "  addi   %0, %0, 16"
           & ASCII.LF
           & "  addi   %1, %1, 16"
           & ASCII.LF
           & ".Ldot_i32_loop_%=:"
           & ASCII.LF
           & ".Ldot_i32_done_%=:"
           & ASCII.LF
           & "add.n   a11, a11, a12"
           & ASCII.LF
           & "add.n   a13, a13, a15"
           & ASCII.LF
           & "add.n   a11, a11, a13"
           & ASCII.LF
           & "s32i.n  a11, %4, 0",
         Outputs  =>
           (Address'Asm_Output ("+r", A_Ptr),
            Address'Asm_Output ("+r", B_Ptr),
            size_t'Asm_Output ("+r", Cnt),
            size_t'Asm_Output ("=&r", Tail)),
         Inputs   => (Address'Asm_Input ("r", Part'Address)),
         Clobber  => "a7,a8,a9,a10,a11,a12,a13,a15,memory",
         Volatile => True);

      R := Long_Long_Integer (Part);
      I := A'Length - Natural (Tail);
      while Tail > 0 loop
         R := R + Long_Long_Integer (A (A'First + I)) * Long_Long_Integer (B (B'First + I));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
      return Sat_I32 (R);
   end Dot_Product;

   procedure MAC (A : SIMD_I32_Vector; Accumulator : in out Integer_32; Multiplier : Integer_32) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      Acc   : aliased Integer_32 := Accumulator;
      Mul   : aliased Integer_32 := Multiplier;
      I     : Natural;
      R     : Long_Long_Integer := Long_Long_Integer (Accumulator);
   begin
      if A'Length > 0 then
         Asm
           (Template =>
              "extui   %2, %1, 0, 2"
              & ASCII.LF
              & "srli    %1, %1, 2"
              & ASCII.LF
              & "movi.n  a7, 0"
              & ASCII.LF
              & "movi.n  a8, 0"
              & ASCII.LF
              & "movi.n  a9, 0"
              & ASCII.LF
              & "movi.n  a10, 0"
              & ASCII.LF
              & "l32i.n  a6, %4, 0"
              & ASCII.LF
              & "beqz    %1, .Lmac_i32_done_%="
              & ASCII.LF
              & "loopnez %1, .Lmac_i32_loop_%="
              & ASCII.LF
              & "  l32i.n a11, %0, 0"
              & ASCII.LF
              & "  l32i.n a12, %0, 4"
              & ASCII.LF
              & "  l32i.n a13, %0, 8"
              & ASCII.LF
              & "  l32i.n a15, %0, 12"
              & ASCII.LF
              & "  mull   a11, a11, a6"
              & ASCII.LF
              & "  mull   a12, a12, a6"
              & ASCII.LF
              & "  mull   a13, a13, a6"
              & ASCII.LF
              & "  mull   a15, a15, a6"
              & ASCII.LF
              & "  add.n  a7, a7, a11"
              & ASCII.LF
              & "  add.n  a8, a8, a12"
              & ASCII.LF
              & "  add.n  a9, a9, a13"
              & ASCII.LF
              & "  add.n  a10, a10, a15"
              & ASCII.LF
              & "  addi   %0, %0, 16"
              & ASCII.LF
              & ".Lmac_i32_loop_%=:"
              & ASCII.LF
              & ".Lmac_i32_done_%=:"
              & ASCII.LF
              & "add.n   a7, a7, a8"
              & ASCII.LF
              & "add.n   a9, a9, a10"
              & ASCII.LF
              & "add.n   a7, a7, a9"
              & ASCII.LF
              & "l32i.n  a9, %3, 0"
              & ASCII.LF
              & "add.n   a7, a9, a7"
              & ASCII.LF
              & "s32i.n  a7, %3, 0",
            Outputs  =>
              (Address'Asm_Output ("+r", A_Ptr),
               size_t'Asm_Output ("+r", Cnt),
               size_t'Asm_Output ("=&r", Tail)),
            Inputs   =>
              (Address'Asm_Input ("r", Acc'Address), Address'Asm_Input ("r", Mul'Address)),
            Clobber  => "a6,a7,a8,a9,a10,a11,a12,a13,a15,memory",
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

   procedure Ceil (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Max_Val : Integer_32) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      M     : aliased Integer_32 := Max_Val;
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
           & "beqz    %2, .Lceil_i32_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.32.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lceil_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lceil_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & ".Lceil_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lceil_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lceil_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & ".Lceil_i32_simd_loop_%=:"
           & ASCII.LF
           & "addi   %0, %0, -16"
           & ASCII.LF
           & ".Lceil_i32_tail_start_%=:",
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

   procedure Floor (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Min_Val : Integer_32) is
      A_Ptr : Address := First_Address (A);
      R_Ptr : Address := First_Address (Result);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      M     : aliased Integer_32 := Min_Val;
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
           & "beqz    %2, .Lfloor_i32_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "ee.vldbc.32.ip q1, %4, 0"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lfloor_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lfloor_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & ".Lfloor_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lfloor_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lfloor_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %1, 16"
           & ASCII.LF
           & ".Lfloor_i32_simd_loop_%=:"
           & ASCII.LF
           & "addi   %0, %0, -16"
           & ASCII.LF
           & ".Lfloor_i32_tail_start_%=:",
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

   procedure Max (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "beqz    %3, .Lmax_i32_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmax_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmax_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lmax_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmax_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmax_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmax.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lmax_i32_simd_loop_%=:"
           & ASCII.LF
           & "addi   %0, %0, -16"
           & ASCII.LF
           & ".Lmax_i32_tail_start_%=:",
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

   procedure Min (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "beqz    %3, .Lmin_i32_tail_start_%="
           & ASCII.LF
           & "ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lmin_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lmin_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lmin_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lmin_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lmin_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vmin.s32.ld.incp q0, %0, q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lmin_i32_simd_loop_%=:"
           & ASCII.LF
           & "addi   %0, %0, -16"
           & ASCII.LF
           & ".Lmin_i32_tail_start_%=:",
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

   procedure Bitwise_And (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Land_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Land_i32_simd_loop4_%="
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
           & ".Land_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Land_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Land_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.andq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Land_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %4, %4, 0, 2",
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
           To_I32 (To_U32 (A (A'First + I)) and To_U32 (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Bitwise_And;

   procedure Bitwise_Or (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lor_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lor_i32_simd_loop4_%="
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
           & ".Lor_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lor_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lor_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.orq        q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lor_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %4, %4, 0, 2",
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
           To_I32 (To_U32 (A (A'First + I)) or To_U32 (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Bitwise_Or;

   procedure Bitwise_Xor (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lxor_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lxor_i32_simd_loop4_%="
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
           & ".Lxor_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lxor_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lxor_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.xorq       q4, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %2, 16"
           & ASCII.LF
           & ".Lxor_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %4, %4, 0, 2",
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
           To_I32 (To_U32 (A (A'First + I)) xor To_U32 (B (B'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Bitwise_Xor;

   procedure Bitwise_Not (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lnot_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lnot_i32_simd_loop4_%="
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
           & ".Lnot_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lnot_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lnot_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.notq       q4, q0"
           & ASCII.LF
           & "  ee.vst.128.ip q4, %1, 16"
           & ASCII.LF
           & ".Lnot_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %3, %3, 0, 2",
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
         Result (Result'First + I) := To_I32 (not To_U32 (A (A'First + I)));
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Bitwise_Not;

   procedure Compare_GT (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lcgt_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lcgt_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcgt_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcgt_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcgt_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.gt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lcgt_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %4, %4, 0, 2",
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

   procedure Compare_LT (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lclt_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lclt_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lclt_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lclt_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lclt_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.lt.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lclt_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %4, %4, 0, 2",
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

   procedure Compare_EQ (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           & "extui   a14, %3, 0, 2"
           & ASCII.LF
           & "srli    %3, %3, 2"
           & ASCII.LF
           & "beqz    %3, .Lceq_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %3, .Lceq_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lceq_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lceq_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lceq_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vld.128.ip q1, %1, 16"
           & ASCII.LF
           & "  ee.vcmp.eq.s32 q2, q0, q1"
           & ASCII.LF
           & "  ee.vst.128.ip q2, %2, 16"
           & ASCII.LF
           & ".Lceq_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %4, %4, 0, 2",
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

   procedure Zeros (A : in out SIMD_I32_Vector) is
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
           "extui   %2, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "ee.xorq q0, q0, q0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lzeros_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lzeros_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lzeros_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lzeros_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lzeros_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lzeros_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %2, %2, 0, 2",
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

   procedure Ones (A : in out SIMD_I32_Vector) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      One   : aliased Integer_32 := 1;
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
           & "ee.vldbc.32.ip q0, %3, 0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lones_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lones_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lones_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lones_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lones_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lones_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %2, %2, 0, 2",
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

   procedure Fill (A : in out SIMD_I32_Vector; Value : Integer_32) is
      A_Ptr : Address := First_Address (A);
      Cnt   : size_t := size_t (A'Length);
      Tail  : size_t := 0;
      V     : aliased Integer_32 := Value;
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
           & "ee.vldbc.32.ip q0, %3, 0"
           & ASCII.LF
           & "extui   a14, %1, 0, 2"
           & ASCII.LF
           & "srli    %1, %1, 2"
           & ASCII.LF
           & "beqz    %1, .Lfill_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %1, .Lfill_i32_simd_loop4_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lfill_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lfill_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lfill_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vst.128.ip q0, %0, 16"
           & ASCII.LF
           & ".Lfill_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %2, %2, 0, 2",
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

   procedure Copy (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector) is
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
           "extui   %3, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "extui   a14, %2, 0, 2"
           & ASCII.LF
           & "srli    %2, %2, 2"
           & ASCII.LF
           & "beqz    %2, .Lcopy_i32_simd_rem_start_%="
           & ASCII.LF
           & "loopnez %2, .Lcopy_i32_simd_loop4_%="
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
           & ".Lcopy_i32_simd_loop4_%=:"
           & ASCII.LF
           & ".Lcopy_i32_simd_rem_start_%=:"
           & ASCII.LF
           & "loopnez a14, .Lcopy_i32_simd_loop_%="
           & ASCII.LF
           & "  ee.vld.128.ip q1, %0, 16"
           & ASCII.LF
           & "  ee.vst.128.ip q1, %1, 16"
           & ASCII.LF
           & ".Lcopy_i32_simd_loop_%=:"
           & ASCII.LF
           & "extui   %3, %3, 0, 2",
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
         Result (Result'First + I) := A (A'First + I);
         I := I + 1;
         Tail := Tail - 1;
      end loop;
   end Copy;
end ESP32S3.SIMD.I32;
