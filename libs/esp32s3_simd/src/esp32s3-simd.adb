pragma Ada_2022;

with ESP32S3.SIMD.F32;
with ESP32S3.SIMD.I16;
with ESP32S3.SIMD.I32;
with ESP32S3.SIMD.I8;
with Interfaces;          use Interfaces;
with System.Machine_Code; use System.Machine_Code;

package body ESP32S3.SIMD is

   use type Integer_8;
   use type Integer_16;
   use type Integer_32;
   use type IEEE_Float_32;

   --------------
   -- Enable --
   --------------

   procedure Enable is
      V : Unsigned_32;
   begin
      --  Read the caller-task CPENABLE, OR in CP3 (the PIE/SIMD unit) while
      --  preserving CP0 (FPU), write it back, and rsync so the change takes
      --  effect before the next instruction.  See the spec for why per-task
      --  CPENABLE means this must run in every SIMD-using task.
      Asm ("rsr.cpenable %0", Outputs => Unsigned_32'Asm_Output ("=r", V), Volatile => True);
      V := V or 16#08#;
      Asm
        ("wsr.cpenable %0" & ASCII.LF & "rsync",
         Inputs   => Unsigned_32'Asm_Input ("r", V),
         Volatile => True);
   end Enable;

   procedure Add (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Add;

   procedure Add (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Add;

   procedure Add (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Add;

   procedure Add (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)

     renames
     ESP32S3.SIMD.F32.Add;

   procedure Add_Scalar (A : SIMD_I8_Vector; Scalar : Integer_8; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Add_Scalar;

   procedure Add_Scalar (A : SIMD_I16_Vector; Scalar : Integer_16; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Add_Scalar;

   procedure Add_Scalar (A : SIMD_I32_Vector; Scalar : Integer_32; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Add_Scalar;

   procedure Add_Scalar
     (A : SIMD_F32_Vector; Scalar : IEEE_Float_32; Result : in out SIMD_F32_Vector)

     renames
     ESP32S3.SIMD.F32.Add_Scalar;

   procedure Sub (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Sub;

   procedure Sub (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Sub;

   procedure Sub (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Sub;

   procedure Sub (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)

     renames
     ESP32S3.SIMD.F32.Sub;

   function "+" (A, B : SIMD_I8_Vector) return SIMD_I8_Vector is
      R : SIMD_I8_Vector (A'Range);
   begin
      Add (A, B, R);
      return R;
   end "+";

   function "+" (A, B : SIMD_I16_Vector) return SIMD_I16_Vector is
      R : SIMD_I16_Vector (A'Range);
   begin
      Add (A, B, R);
      return R;
   end "+";

   function "+" (A, B : SIMD_I32_Vector) return SIMD_I32_Vector is
      R : SIMD_I32_Vector (A'Range);
   begin
      Add (A, B, R);
      return R;
   end "+";

   function "+" (A, B : SIMD_F32_Vector) return SIMD_F32_Vector is
      R : SIMD_F32_Vector (A'Range);
   begin
      Add (A, B, R);
      return R;
   end "+";

   function "-" (A, B : SIMD_I8_Vector) return SIMD_I8_Vector is
      R : SIMD_I8_Vector (A'Range);
   begin
      Sub (A, B, R);
      return R;
   end "-";

   function "-" (A, B : SIMD_I16_Vector) return SIMD_I16_Vector is
      R : SIMD_I16_Vector (A'Range);
   begin
      Sub (A, B, R);
      return R;
   end "-";

   function "-" (A, B : SIMD_I32_Vector) return SIMD_I32_Vector is
      R : SIMD_I32_Vector (A'Range);
   begin
      Sub (A, B, R);
      return R;
   end "-";

   function "-" (A, B : SIMD_F32_Vector) return SIMD_F32_Vector is
      R : SIMD_F32_Vector (A'Range);
   begin
      Sub (A, B, R);
      return R;
   end "-";

   function "-" (A : SIMD_I8_Vector) return SIMD_I8_Vector is
      R : SIMD_I8_Vector (A'Range);
   begin
      Neg (A, R);
      return R;
   end "-";

   function "-" (A : SIMD_I16_Vector) return SIMD_I16_Vector is
      R : SIMD_I16_Vector (A'Range);
   begin
      Neg (A, R);
      return R;
   end "-";

   function "-" (A : SIMD_I32_Vector) return SIMD_I32_Vector is
      R : SIMD_I32_Vector (A'Range);
   begin
      Neg (A, R);
      return R;
   end "-";

   function "-" (A : SIMD_F32_Vector) return SIMD_F32_Vector is
      R : SIMD_F32_Vector (A'Range);
   begin
      Neg (A, R);
      return R;
   end "-";

   function "+" (A : SIMD_I8_Vector; Scalar : Integer_8) return SIMD_I8_Vector is
      R : SIMD_I8_Vector (A'Range);
   begin
      Add_Scalar (A, Scalar, R);
      return R;
   end "+";

   function "+" (A : SIMD_I16_Vector; Scalar : Integer_16) return SIMD_I16_Vector is
      R : SIMD_I16_Vector (A'Range);
   begin
      Add_Scalar (A, Scalar, R);
      return R;
   end "+";

   function "+" (A : SIMD_I32_Vector; Scalar : Integer_32) return SIMD_I32_Vector is
      R : SIMD_I32_Vector (A'Range);
   begin
      Add_Scalar (A, Scalar, R);
      return R;
   end "+";

   function "+" (A : SIMD_F32_Vector; Scalar : IEEE_Float_32) return SIMD_F32_Vector is
      R : SIMD_F32_Vector (A'Range);
   begin
      Add_Scalar (A, Scalar, R);
      return R;
   end "+";

   function "+" (Scalar : Integer_8; A : SIMD_I8_Vector) return SIMD_I8_Vector is
   begin
      return A + Scalar;
   end "+";

   function "+" (Scalar : Integer_16; A : SIMD_I16_Vector) return SIMD_I16_Vector is
   begin
      return A + Scalar;
   end "+";

   function "+" (Scalar : Integer_32; A : SIMD_I32_Vector) return SIMD_I32_Vector is
   begin
      return A + Scalar;
   end "+";

   function "+" (Scalar : IEEE_Float_32; A : SIMD_F32_Vector) return SIMD_F32_Vector is
   begin
      return A + Scalar;
   end "+";

   function "-" (A : SIMD_I8_Vector; Scalar : Integer_8) return SIMD_I8_Vector is
      R : SIMD_I8_Vector (A'Range);
   begin
      Fill (R, Scalar);
      Sub (A, R, R);
      return R;
   end "-";

   function "-" (A : SIMD_I16_Vector; Scalar : Integer_16) return SIMD_I16_Vector is
      R : SIMD_I16_Vector (A'Range);
   begin
      Fill (R, Scalar);
      Sub (A, R, R);
      return R;
   end "-";

   function "-" (A : SIMD_I32_Vector; Scalar : Integer_32) return SIMD_I32_Vector is
      R : SIMD_I32_Vector (A'Range);
   begin
      Fill (R, Scalar);
      Sub (A, R, R);
      return R;
   end "-";

   function "-" (A : SIMD_F32_Vector; Scalar : IEEE_Float_32) return SIMD_F32_Vector is
      R          : SIMD_F32_Vector (A'Range);
      Neg_Scalar : constant IEEE_Float_32 := -Scalar;
   begin
      Add_Scalar (A, Neg_Scalar, R);
      return R;
   end "-";

   function "-" (Scalar : Integer_8; A : SIMD_I8_Vector) return SIMD_I8_Vector is
      R : SIMD_I8_Vector (A'Range);
   begin
      Fill (R, Scalar);
      Sub (R, A, R);
      return R;
   end "-";

   function "-" (Scalar : Integer_16; A : SIMD_I16_Vector) return SIMD_I16_Vector is
      R : SIMD_I16_Vector (A'Range);
   begin
      Fill (R, Scalar);
      Sub (R, A, R);
      return R;
   end "-";

   function "-" (Scalar : Integer_32; A : SIMD_I32_Vector) return SIMD_I32_Vector is
      R : SIMD_I32_Vector (A'Range);
   begin
      Fill (R, Scalar);
      Sub (R, A, R);
      return R;
   end "-";

   function "-" (Scalar : IEEE_Float_32; A : SIMD_F32_Vector) return SIMD_F32_Vector is
      R : SIMD_F32_Vector (A'Range);
   begin
      for I in R'Range loop
         R (I) := Scalar;
      end loop;
      Sub (R, A, R);
      return R;
   end "-";

   function "*" (A, B : SIMD_I8_Vector) return SIMD_I8_Vector is
      R : SIMD_I8_Vector (A'Range);
   begin
      Mul_Shift (A, B, R, 0);
      return R;
   end "*";

   function "*" (A, B : SIMD_I16_Vector) return SIMD_I16_Vector is
      R : SIMD_I16_Vector (A'Range);
   begin
      Mul_Shift (A, B, R, 0);
      return R;
   end "*";

   function "*" (A, B : SIMD_I32_Vector) return SIMD_I32_Vector is
      R : SIMD_I32_Vector (A'Range);
   begin
      Mul_Shift (A, B, R, 0);
      return R;
   end "*";

   function "*" (A, B : SIMD_F32_Vector) return SIMD_F32_Vector is
      R : SIMD_F32_Vector (A'Range);
   begin
      Mul_Shift (A, B, R, 0);
      return R;
   end "*";

   function "*" (A : SIMD_I8_Vector; Scalar : Integer_8) return SIMD_I8_Vector is
      R : SIMD_I8_Vector (A'Range);
   begin
      Mul_Scalar (A, Scalar, R, 0);
      return R;
   end "*";

   function "*" (A : SIMD_I16_Vector; Scalar : Integer_16) return SIMD_I16_Vector is
      R : SIMD_I16_Vector (A'Range);
   begin
      Mul_Scalar (A, Scalar, R, 0);
      return R;
   end "*";

   function "*" (A : SIMD_I32_Vector; Scalar : Integer_32) return SIMD_I32_Vector is
      R : SIMD_I32_Vector (A'Range);
   begin
      Mul_Scalar (A, Scalar, R, 0);
      return R;
   end "*";

   function "*" (A : SIMD_F32_Vector; Scalar : IEEE_Float_32) return SIMD_F32_Vector is
      R : SIMD_F32_Vector (A'Range);
   begin
      Mul_Scalar (A, Scalar, R);
      return R;
   end "*";

   function "*" (Scalar : Integer_8; A : SIMD_I8_Vector) return SIMD_I8_Vector is
   begin
      return A * Scalar;
   end "*";

   function "*" (Scalar : Integer_16; A : SIMD_I16_Vector) return SIMD_I16_Vector is
   begin
      return A * Scalar;
   end "*";

   function "*" (Scalar : Integer_32; A : SIMD_I32_Vector) return SIMD_I32_Vector is
   begin
      return A * Scalar;
   end "*";

   function "*" (Scalar : IEEE_Float_32; A : SIMD_F32_Vector) return SIMD_F32_Vector is
   begin
      return A * Scalar;
   end "*";

   procedure Mul_Shift (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector; Shift : Shift_I8)

     renames
     ESP32S3.SIMD.I8.Mul_Shift;

   procedure Mul_Shift (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector; Shift : Shift_I16)

     renames
     ESP32S3.SIMD.I16.Mul_Shift;

   procedure Mul_Shift (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Shift : Shift_I32)

     renames
     ESP32S3.SIMD.I32.Mul_Shift;

   procedure Mul_Shift (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Shift : Natural)

     renames
     ESP32S3.SIMD.F32.Mul_Shift;

   procedure Mul_Scalar
     (A : SIMD_I8_Vector; Scalar : Integer_8; Result : in out SIMD_I8_Vector; Shift : Shift_I8)

     renames
     ESP32S3.SIMD.I8.Mul_Scalar;

   procedure Mul_Scalar
     (A : SIMD_I16_Vector; Scalar : Integer_16; Result : in out SIMD_I16_Vector; Shift : Shift_I16)

     renames
     ESP32S3.SIMD.I16.Mul_Scalar;

   procedure Mul_Scalar
     (A : SIMD_I32_Vector; Scalar : Integer_32; Result : in out SIMD_I32_Vector; Shift : Shift_I32)

     renames
     ESP32S3.SIMD.I32.Mul_Scalar;

   procedure Mul_Scalar
     (A : SIMD_F32_Vector; Scalar : IEEE_Float_32; Result : in out SIMD_F32_Vector)

     renames
     ESP32S3.SIMD.F32.Mul_Scalar;

   procedure Mul_Widen (A, B : SIMD_I8_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I8.Mul_Widen;

   procedure Mul_Widen (A, B : SIMD_I16_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I16.Mul_Widen;

   procedure Neg (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Neg;

   procedure Neg (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Neg;

   procedure Neg (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Neg;

   procedure Neg (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)

     renames
     ESP32S3.SIMD.F32.Neg;

   procedure Abs_Val (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Abs_Val;

   procedure Abs_Val (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Abs_Val;

   procedure Abs_Val (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Abs_Val;

   procedure Abs_Val (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)

     renames
     ESP32S3.SIMD.F32.Abs_Val;

   function Sum (A : SIMD_I8_Vector) return Integer_32

     renames
     ESP32S3.SIMD.I8.Sum;

   function Sum (A : SIMD_I16_Vector) return Integer_32

     renames
     ESP32S3.SIMD.I16.Sum;

   function Sum (A : SIMD_I32_Vector) return Integer_32

     renames
     ESP32S3.SIMD.I32.Sum;

   function Sum (A : SIMD_F32_Vector) return IEEE_Float_32

     renames
     ESP32S3.SIMD.F32.Sum;

   function Dot_Product (A, B : SIMD_I8_Vector) return Integer_32

     renames
     ESP32S3.SIMD.I8.Dot_Product;

   function Dot_Product (A, B : SIMD_I16_Vector) return Integer_32

     renames
     ESP32S3.SIMD.I16.Dot_Product;

   function Dot_Product (A, B : SIMD_I32_Vector) return Integer_32

     renames
     ESP32S3.SIMD.I32.Dot_Product;

   function Dot_Product (A, B : SIMD_F32_Vector) return IEEE_Float_32

     renames
     ESP32S3.SIMD.F32.Dot_Product;

   procedure MAC (A : SIMD_I8_Vector; Accumulator : in out Integer_32; Multiplier : Integer_8)

     renames
     ESP32S3.SIMD.I8.MAC;

   procedure MAC (A : SIMD_I16_Vector; Accumulator : in out Integer_32; Multiplier : Integer_16)

     renames
     ESP32S3.SIMD.I16.MAC;

   procedure MAC (A : SIMD_I32_Vector; Accumulator : in out Integer_32; Multiplier : Integer_32)

     renames
     ESP32S3.SIMD.I32.MAC;

   procedure MAC
     (A : SIMD_F32_Vector; Accumulator : in out IEEE_Float_32; Multiplier : IEEE_Float_32)

     renames
     ESP32S3.SIMD.F32.MAC;

   procedure Relu
     (A          : SIMD_I8_Vector;
      Multiplier : Integer_32;
      Shift      : Shift_I8;
      Result     : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Relu;

   procedure Relu
     (A          : SIMD_I16_Vector;
      Multiplier : Integer_32;
      Shift      : Shift_I16;
      Result     : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Relu;

   procedure Ceil (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector; Max_Val : Integer_8)

     renames
     ESP32S3.SIMD.I8.Ceil;

   procedure Ceil (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector; Max_Val : Integer_16)

     renames
     ESP32S3.SIMD.I16.Ceil;

   procedure Ceil (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Max_Val : Integer_32)

     renames
     ESP32S3.SIMD.I32.Ceil;

   procedure Ceil (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Max_Val : IEEE_Float_32)

     renames
     ESP32S3.SIMD.F32.Ceil;

   procedure Floor (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector; Min_Val : Integer_8)

     renames
     ESP32S3.SIMD.I8.Floor;

   procedure Floor (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector; Min_Val : Integer_16)

     renames
     ESP32S3.SIMD.I16.Floor;

   procedure Floor (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Min_Val : Integer_32)

     renames
     ESP32S3.SIMD.I32.Floor;

   procedure Floor (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Min_Val : IEEE_Float_32)

     renames
     ESP32S3.SIMD.F32.Floor;

   procedure Max (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Max;

   procedure Max (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Max;

   procedure Max (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Max;

   procedure Max (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)

     renames
     ESP32S3.SIMD.F32.Max;

   procedure Min (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Min;

   procedure Min (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Min;

   procedure Min (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Min;

   procedure Min (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)

     renames
     ESP32S3.SIMD.F32.Min;

   procedure Compare_GT (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Compare_GT;

   procedure Compare_GT (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Compare_GT;

   procedure Compare_GT (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Compare_GT;

   procedure Compare_LT (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Compare_LT;

   procedure Compare_LT (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Compare_LT;

   procedure Compare_LT (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Compare_LT;

   procedure Compare_EQ (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Compare_EQ;

   procedure Compare_EQ (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Compare_EQ;

   procedure Compare_EQ (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Compare_EQ;

   procedure Bitwise_And (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Bitwise_And;

   procedure Bitwise_And (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Bitwise_And;

   procedure Bitwise_And (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Bitwise_And;

   procedure Bitwise_Or (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Bitwise_Or;

   procedure Bitwise_Or (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Bitwise_Or;

   procedure Bitwise_Or (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Bitwise_Or;

   procedure Bitwise_Xor (A, B : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Bitwise_Xor;

   procedure Bitwise_Xor (A, B : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Bitwise_Xor;

   procedure Bitwise_Xor (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Bitwise_Xor;

   procedure Bitwise_Not (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Bitwise_Not;

   procedure Bitwise_Not (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Bitwise_Not;

   procedure Bitwise_Not (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Bitwise_Not;

   procedure Zeros (A : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Zeros;

   procedure Zeros (A : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Zeros;

   procedure Zeros (A : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Zeros;

   procedure Ones (A : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Ones;

   procedure Ones (A : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Ones;

   procedure Ones (A : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Ones;

   procedure Fill (A : in out SIMD_I8_Vector; Value : Integer_8)

     renames
     ESP32S3.SIMD.I8.Fill;

   procedure Fill (A : in out SIMD_I16_Vector; Value : Integer_16)

     renames
     ESP32S3.SIMD.I16.Fill;

   procedure Fill (A : in out SIMD_I32_Vector; Value : Integer_32)

     renames
     ESP32S3.SIMD.I32.Fill;

   procedure Copy (A : SIMD_I8_Vector; Result : in out SIMD_I8_Vector)

     renames
     ESP32S3.SIMD.I8.Copy;

   procedure Copy (A : SIMD_I16_Vector; Result : in out SIMD_I16_Vector)

     renames
     ESP32S3.SIMD.I16.Copy;

   procedure Copy (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)

     renames
     ESP32S3.SIMD.I32.Copy;

   procedure Convert (A : SIMD_I8_Vector; Result : in out SIMD_I16_Vector) is
   begin
      ESP32S3.SIMD.I8.Convert_To_I16 (A, Result);
   end Convert;

   procedure Convert (A : SIMD_I8_Vector; Result : in out SIMD_I32_Vector) is
   begin
      ESP32S3.SIMD.I8.Convert_To_I32 (A, Result);
   end Convert;

   procedure Convert (A : SIMD_I16_Vector; Result : in out SIMD_I32_Vector) is
   begin
      ESP32S3.SIMD.I16.Convert_To_I32 (A, Result);
   end Convert;

end ESP32S3.SIMD;
