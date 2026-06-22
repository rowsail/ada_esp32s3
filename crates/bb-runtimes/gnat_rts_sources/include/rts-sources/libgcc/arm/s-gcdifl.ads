------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                  S Y S T E M . G C C . D I . F L O A T S                 --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--         Copyright (C) 2017-2025, Free Software Foundation, Inc.          --
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

--  @design
--  This package implements various conversions between floating point types
--  and 64-bit integers.
--
--  In particular it provides:
--
--  * ``__aeabi_l2f``
--  * ``__aeabi_ul2f``
--  * ``__aeabi_l2d``
--  * ``__aeabi_ul2d``
--  * ``__aeabi_f2lz``
--  * ``__aeabi_f2ulz``
--  * ``__aeabi_d2lz``
--  * ``__aeabi_d2ulz``
--
--  Those subprograms are defined in [ARM-RT-ABI]. Please refer to this
--  document for more information.

pragma Restrictions (No_Elaboration_Code);
with Ada.Unchecked_Conversion;
--  @design used to convert between various representations of floating points.

package System.GCC.DI.Floats is
   pragma Pure;

   --  The AEABI functions use soft-float calling convention even in a
   --  hard-float context: so we need to map the float_t types to integers
   --  to have the arguments passed on in the proper registers

   type AEABI_F32 is new Interfaces.Unsigned_32;
   type AEABI_F64 is new Interfaces.Unsigned_64;

   subtype Float32 is Interfaces.IEEE_Float_32;
   subtype Float64 is Interfaces.IEEE_Float_64;

   --  Integer types to float types conversion

   function Floatdisf (V : Integer_64) return AEABI_F32;
   pragma Export (C, Floatdisf, "__aeabi_l2f");
   --  Convert an signed 64 bit value to a IEEE 754 binary32 float

   function Floatundisf (V : Unsigned_64) return AEABI_F32;
   pragma Export (C, Floatundisf, "__aeabi_ul2f");
   --  Convert an unsigned 64 bit value to a IEEE 754 binary32 float

   function Floatdidf (V : Integer_64) return AEABI_F64;
   pragma Export (C, Floatdidf, "__aeabi_l2d");
   --  Convert an signed 64 bit value to a IEEE 754 binary64 float

   function Floatundidf (V : Unsigned_64) return AEABI_F64;
   pragma Export (C, Floatundidf, "__aeabi_ul2d");
   --  Convert an unsigned 64 bit value to a IEEE 754 binary64 float

   --  Float types to Integer types conversions

   --  Our implemenation of libgcc's floating-point to integer conversion
   --  functions follows libgcc's implementations with one notable difference:
   --  whereas libgcc rounds overflows to the nearest valid integer, we ignore
   --  overflows. This is done because the compiler performs the integer
   --  subtype range check independently in the floating-point domain for
   --  floating-point to integer conversions. Consequently, the conversion
   --  routines will only be called with values that will not cause overflows.
   --  See Checks.Apply_Float_Conversion_Check for more details.

   function Fixsfdi (V : AEABI_F32) return Integer_64;
   pragma Export (C, Fixsfdi, "__aeabi_f2lz");
   --  Convert a binary32 float to a signed 64 bit value. Overflows are
   --  ignored and values are truncated toward 0.

   function Fixunssfdi (V : AEABI_F32) return Unsigned_64;
   pragma Export (C, Fixunssfdi, "__aeabi_f2ulz");
   --  Convert a binary32 float to an unsigned 64 bit value. Negative values
   --  are converted to 0, overflows are ignored and values are truncated
   --  toward 0.

   function Fixdfdi (V : AEABI_F64) return Integer_64;
   pragma Export (C, Fixdfdi, "__aeabi_d2lz");
   --  Convert a binary64 float to a signed 64 bit value. Overflows are
   --  ignored and values are truncated toward 0.

   function Fixunsdfdi (V : AEABI_F64) return Unsigned_64;
   pragma Export (C, Fixunsdfdi, "__aeabi_d2ulz");
   --  Convert a binary64 float to an unsigned 64 bit value. Negative values
   --  are converted to 0, overflows are ignored and values are truncated
   --  toward 0.

private

   function Conv is new Ada.Unchecked_Conversion (AEABI_F32, Float32);
   function Conv is new Ada.Unchecked_Conversion (AEABI_F64, Float64);
   function Conv is new Ada.Unchecked_Conversion (Float32,  AEABI_F32);
   function Conv is new Ada.Unchecked_Conversion (Float64,  AEABI_F64);

   function "-" (V : AEABI_F32) return AEABI_F32;
   function "-" (V : AEABI_F64) return AEABI_F64;
   pragma Inline_Always ("-");

   function To_Float64 is new Ada.Unchecked_Conversion
     (Unsigned_64, Float64);

   function To_Float32 is new Ada.Unchecked_Conversion
     (Unsigned_32, Float32);

end System.GCC.DI.Floats;
