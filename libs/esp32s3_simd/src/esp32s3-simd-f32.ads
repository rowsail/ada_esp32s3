pragma Ada_2022;

package ESP32S3.SIMD.F32 is

   procedure Add (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Add_Scalar
     (A : SIMD_F32_Vector; Scalar : IEEE_Float_32; Result : in out SIMD_F32_Vector)
   with Pre => A'Length = Result'Length;

   procedure Sub (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Mul_Shift (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Shift : Natural)
   with Pre => A'Length = B'Length and then A'Length = Result'Length and then Shift = 0;

   procedure Mul_Scalar
     (A : SIMD_F32_Vector; Scalar : IEEE_Float_32; Result : in out SIMD_F32_Vector)
   with Pre => A'Length = Result'Length;

   procedure Neg (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)
   with Pre => A'Length = Result'Length;

   procedure Abs_Val (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)
   with Pre => A'Length = Result'Length;

   function Sum (A : SIMD_F32_Vector) return IEEE_Float_32;

   function Dot_Product (A, B : SIMD_F32_Vector) return IEEE_Float_32
   with Pre => A'Length = B'Length;

   procedure MAC
     (A : SIMD_F32_Vector; Accumulator : in out IEEE_Float_32; Multiplier : IEEE_Float_32);

   procedure Ceil (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Max_Val : IEEE_Float_32)
   with Pre => A'Length = Result'Length;

   procedure Floor (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Min_Val : IEEE_Float_32)
   with Pre => A'Length = Result'Length;

   procedure Max (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

   procedure Min (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector)
   with Pre => A'Length = B'Length and then A'Length = Result'Length;

end ESP32S3.SIMD.F32;
