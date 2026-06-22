------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUNTIME COMPONENTS                          --
--                                                                          --
--               ADA.NUMERICS.LONG_LONG_ELEMENTARY_FUNCTIONS                --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--          Copyright (C) 1992-2025, Free Software Foundation, Inc.         --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

--  @llrset a-nllefu.ads
--  Long_Long_Elementary_Functions
--  ==============================
--
--  This is the Ada Cert Math specific version of a-nllefu.ads.

with System.Generic_C_Math_Interface;
with System.Libm_Long_Double;

package Ada.Numerics.Long_Long_Elementary_Functions is
  new System.Generic_C_Math_Interface
        (Float_Type => Long_Long_Float,
         C_Sqrt  => System.Libm_Long_Double.Sqrt,
         C_Log   => System.Libm_Long_Double.Log,
         C_Exp   => System.Libm_Long_Double.Exp,
         C_Pow   => System.Libm_Long_Double.Pow,

         C_Sin   => System.Libm_Long_Double.Sin,
         C_Cos   => System.Libm_Long_Double.Cos,
         C_Tan   => System.Libm_Long_Double.Tan,

         C_Asin  => System.Libm_Long_Double.Asin,
         C_Acos  => System.Libm_Long_Double.Acos,
         C_Atan2 => System.Libm_Long_Double.Atan2,

         C_Sinh  => System.Libm_Long_Double.Sinh,
         C_Cosh  => System.Libm_Long_Double.Cosh,
         C_Tanh  => System.Libm_Long_Double.Tanh,

         C_Asinh => System.Libm_Long_Double.Asinh,
         C_Acosh => System.Libm_Long_Double.Acosh,
         C_Atanh => System.Libm_Long_Double.Atanh);
pragma Pure (Long_Long_Elementary_Functions);
