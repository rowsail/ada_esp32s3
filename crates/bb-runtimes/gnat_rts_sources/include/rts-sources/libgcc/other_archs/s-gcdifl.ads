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

--  Ada implementation of libgcc: floating points conversions

--  @design @internal
--  This package implements various conversions between floating point types
--  and integers.

pragma Restrictions (No_Elaboration_Code);

package System.GCC.DI.Floats is
   pragma Pure;

   subtype Binary32 is Interfaces.IEEE_Float_32;
   subtype Binary64 is Interfaces.IEEE_Float_64;

   --  Integer types to float types conversion

   function Floatdisf (V : Integer_64) return Binary32;
   pragma Export (C, Floatdisf, "__floatdisf");
   --  @internal
   --  Convert an signed 64 bit value to a IEEE 754 binary32 float

   function Floatundisf (V : Unsigned_64) return Binary32;
   pragma Export (C, Floatundisf, "__floatundisf");
   --  @internal
   --  Convert an unsigned 64 bit value to a IEEE 754 binary32 float

   function Floatdidf (V : Integer_64) return Binary64;
   pragma Export (C, Floatdidf, "__floatdidf");
   --  @internal
   --  Convert an signed 64 bit value to a IEEE 754 binary64 float

   function Floatundidf (V : Unsigned_64) return Binary64;
   pragma Export (C, Floatundidf, "__floatundidf");
   --  @internal
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

   function Fixsfdi (V : Binary32) return Integer_64;
   pragma Export (C, Fixsfdi, "__fixsfdi");
   --  @internal
   --  Convert a binary32 float to a signed 64 bit value. Overflows are
   --  ignored and values are truncated toward 0.

   function Fixunssfdi (V : Binary32) return Unsigned_64;
   pragma Export (C, Fixunssfdi, "__fixunssfdi");
   --  @internal
   --  Convert a binary32 float to an unsigned 64 bit value. Negative values
   --  are converted to 0, overflows are ignored and values are truncated
   --  toward 0.

   function Fixdfdi (V : Binary64) return Integer_64;
   pragma Export (C, Fixdfdi, "__fixdfdi");
   --  @internal
   --  Convert a binary64 float to a signed 64 bit value. Overflows are
   --  ignored and values are truncated toward 0.

   function Fixunsdfdi (V : Binary64) return Unsigned_64;
   pragma Export (C, Fixunsdfdi, "__fixunsdfdi");
   --  @internal
   --  Convert a binary64 float to an unsigned 64 bit value. Negative values
   --  are converted to 0, overflows are ignored and values are truncated
   --  toward 0.

end System.GCC.DI.Floats;
