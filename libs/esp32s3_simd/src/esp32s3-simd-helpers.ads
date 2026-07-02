pragma Ada_2022;

with ESP32S3.SIMD;
with System;

use ESP32S3.SIMD;

package ESP32S3.SIMD.Helpers is

   function First_Address (V : SIMD_I8_Vector) return System.Address
   with Inline;
   function First_Address (V : SIMD_I16_Vector) return System.Address
   with Inline;
   function First_Address (V : SIMD_I32_Vector) return System.Address
   with Inline;
   function First_Address (V : SIMD_F32_Vector) return System.Address
   with Inline;

end ESP32S3.SIMD.Helpers;
