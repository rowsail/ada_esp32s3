pragma Ada_2022;

package ESP32S3.SIMD.I32 is

   procedure Add (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Add_Scalar (A : SIMD_I32_Vector; Scalar : Integer_32; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = Result'Length;

   procedure Sub (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Mul_Shift (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Shift : Shift_I32)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Mul_Scalar
     (A : SIMD_I32_Vector; Scalar : Integer_32; Result : in out SIMD_I32_Vector; Shift : Shift_I32)
   with Pre => A'Length = Result'Length;

   procedure Neg (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = Result'Length;

   procedure Abs_Val (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = Result'Length;

   function Sum (A : SIMD_I32_Vector) return Integer_32;

   function Dot_Product (A, B : SIMD_I32_Vector) return Integer_32
   with Pre => A'Length = B'Length;

   procedure MAC (A : SIMD_I32_Vector; Accumulator : in out Integer_32; Multiplier : Integer_32);

   procedure Ceil (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Max_Val : Integer_32)
   with Pre => A'Length = Result'Length;

   procedure Floor (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector; Min_Val : Integer_32)
   with Pre => A'Length = Result'Length;

   procedure Max (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Min (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_And (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Or (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Xor (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Bitwise_Not (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = Result'Length;

   procedure Compare_GT (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_LT (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Compare_EQ (A, B : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Zeros (A : in out SIMD_I32_Vector);
   procedure Ones (A : in out SIMD_I32_Vector);
   procedure Fill (A : in out SIMD_I32_Vector; Value : Integer_32);
   procedure Copy (A : SIMD_I32_Vector; Result : in out SIMD_I32_Vector)
   with Pre => A'Length = Result'Length;

end ESP32S3.SIMD.I32;
