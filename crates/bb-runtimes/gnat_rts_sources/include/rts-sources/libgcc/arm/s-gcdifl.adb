------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                  S Y S T E M . G C C . D I . F L O A T S                 --
--                                                                          --
--                                 B o d y                                  --
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

--  Ada implementation of libgcc: 64-bit double conversions
pragma Restrictions (No_Elaboration_Code);

package body System.GCC.DI.Floats is
   pragma Annotate (Gnatcheck, Exempt_On, "Improper_Returns",
                    "better readability with multiple returns");

   use Interfaces;

   function "-" (V : AEABI_F32) return AEABI_F32
     is (Conv (-Conv (V)));

   function "-" (V : AEABI_F64) return AEABI_F64
     is (Conv (-Conv (V)));

   function To_Unsigned_64 is new
     Ada.Unchecked_Conversion (Integer_64, Unsigned_64);

   function To_Integer_64 is new
     Ada.Unchecked_Conversion (Unsigned_64, Integer_64);

   function To_Integer_32 is new
     Ada.Unchecked_Conversion (Unsigned_32, Integer_32);

   function Floatdisf (V : Integer_64) return AEABI_F32 is
      Rep_Bit : constant Unsigned_64 :=
        Shift_Left (1, 64 - Float64'Machine_Mantissa);
      --  Bit to represent low-order bits that will be truncated in the first
      --  conversion.

      First_Truncated_Int : constant Integer_64 :=
        Integer_64 (Shift_Left (Unsigned_64 (1), Float64'Machine_Mantissa));
      --  The first positive integer that has more bits than the mantissa

      W : Integer_64 := V;
      --  Working version of V

      UW : Unsigned_64 := To_Unsigned_64 (W);
      --  Bit representation of W
   begin
      --  The 64 bits of the integer are truncated to the required 24-bit
      --  significand using the same technique as Floatundisf.

      --  Protect against double rounding

      if W <= -First_Truncated_Int or else W >= First_Truncated_Int then
         if (UW and (Rep_Bit - 1)) /= 0 then
            UW := UW and not (Rep_Bit - 1);
            UW := UW or Rep_Bit;
            W := To_Integer_64 (UW);
         end if;
      end if;

      --  Perform the conversion by first converting to the wider Binary64 type
      --  then to the narrower Binary32 type.

      return Conv (Float32 (Float64 (W)));
   end Floatdisf;

   function Floatundisf (V : Unsigned_64) return AEABI_F32 is
      Rep_Bit : constant Unsigned_64 :=
        Shift_Left (1, 64 - Float64'Machine_Mantissa);
      --  Bit to represent low-order bits that will be truncated in the first
      --  conversion.

      W : Unsigned_64 := V;
      --  Working version of V
   begin
      --  The 64 bits of the integer are truncated to the required 24-bit
      --  significand in two steps: first by converting the integer to a
      --  Binary64 (implicitly via the Floatundidf function) and then to a
      --  Binary32. The benefit of this approach is efficiency: it minimizes
      --  conditional statements and enables the use of hardware Binary64 to
      --  Binary32 instructions that allow the second conversion to be
      --  performed in a single clock cycle.

      --  The problem with a two step truncation is the rounding that occurs
      --  at each step. To protected against double rounding we use a rep bit
      --  to represent any low-order bits that will be truncated in the first
      --  conversion. This bit can be located anywhere between the rounding
      --  position of the Binary64 and Binary32 types (so between bits 10 and
      --  39). This approach is based on libgcc's implementation.

      if W > Shift_Left (1, Float64'Machine_Mantissa) then
         if (W and (Rep_Bit - 1)) /= 0 then
            W := W and not (Rep_Bit - 1);
            W := W or Rep_Bit;
         end if;
      end if;

      return Conv (Float32 (Float64 (W)));
   end Floatundisf;

   function Floatdidf (V : Integer_64) return AEABI_F64 is
      UV     : constant Unsigned_64 := To_Unsigned_64 (V);
      Result : Float64;
   begin
      --  Perform the conversion by converting the upper and lower parts of the
      --  integer separately.

      --  Convert the upper 32 bits

      Result := Float64 (To_Integer_32 (Unsigned_32 (Shift_Right (UV, 32))));
      Result := Result * 2#1.0#E32;

      --  Convert the lower 32 bits and add to the above result. The addition
      --  operation will take care of rounding the result.

      Result := Result + Float64 (Unsigned_32 (UV and 16#FFFFFFFF#));

      return Conv (Result);
   end Floatdidf;

   function Floatundidf (V : Unsigned_64) return AEABI_F64 is
      Result : Float64;
   begin
      --  Perform the conversion by converting the upper and lower parts of the
      --  Unsigned_64 separately. This produces more efficent code than if the
      --  conversion was performed using bitwise operations, as there are fewer
      --  constants to load. It also allows compiler to use integer to double
      --  conversion instructions if available.

      --  Convert the upper 32 bits

      Result := Float64 (Unsigned_32 (Shift_Right (V, 32)));
      Result := Result * 2#1.0#E32;

      --  Convert the lower 32 bits and add to the above result. The addition
      --  operation will take care of rounding the result.

      Result := Result + Float64 (Unsigned_32 (V and 16#FFFFFFFF#));

      return Conv (Result);
   end Floatundidf;

   function Fixsfdi (V : AEABI_F32) return Integer_64
   is
   begin
      if Conv (V) < 0.0 then
         return -Integer_64 (Fixunssfdi (-V));
      else
         return Integer_64 (Fixunssfdi (V));
      end if;
   end Fixsfdi;

   function Fixunssfdi (V : AEABI_F32) return Unsigned_64
   is
      --  Use Float64 representation as it provides more than 32 bit of
      --  mantissa.
      Dv     : constant Float64 := Float64 (Conv (V));
      Hi, Lo : Unsigned_32;
   begin
      if Dv <= 0.0 then
         return 0;
      end if;

      Hi := Unsigned_32 (Float64'Truncation (Dv / 2.0**32));
      Lo := Unsigned_32 (Float64'Truncation (Dv - Float64 (Hi) * 2.0**32));
      return Merge (Hi, Lo);
   end Fixunssfdi;

   function Fixdfdi (V : AEABI_F64) return Integer_64 is
   begin
      if Conv (V) < 0.0 then
         return -Integer_64 (Fixunsdfdi (-V));
      else
         return Integer_64 (Fixunsdfdi (V));
      end if;
   end Fixdfdi;

   function Fixunsdfdi (V : AEABI_F64) return Unsigned_64
   is
      Dv     : constant Float64 := Conv (V);
      Hi, Lo : Unsigned_32;
   begin
      if Dv <= 0.0 then
         return 0;
      end if;

      Hi := Unsigned_32 (Float64'Truncation (Dv / 2.0**32));
      Lo := Unsigned_32 (Float64'Truncation (Dv - Float64 (Hi) * 2.0**32));
      return Merge (Hi, Lo);
   end Fixunsdfdi;

   pragma Annotate (Gnatcheck, Exempt_Off, "Improper_Returns");
end System.GCC.DI.Floats;
