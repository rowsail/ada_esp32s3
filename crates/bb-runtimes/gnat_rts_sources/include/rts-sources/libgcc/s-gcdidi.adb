------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--               S Y S T E M . G C C . D I . D I V I S I O N S              --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--          Copyright (C) 2013-2025, Free Software Foundation, Inc.         --
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

--  Ada implementation of libgcc: 64-bit Divisions

with System.Machine_Code;
--  @design used to implement some functionalities in assembler code.

package body System.GCC.DI.Divisions is
   use Interfaces;

   function Divmoddi3 (Num : Integer_64;
                       Den : Integer_64;
                       Return_Rem : Boolean)
                      return Integer_64;

   function Count_Leading_Zero (V : Unsigned_32) return Natural;
   --  Return the number of consecutive zero in V, starting from the MSB.
   --  The result is between 0 and 32.

   function Count_Leading_Zero (V : Unsigned_32) return Natural is
      Tmp : Unsigned_32;
      Res : Natural;
   begin
      --  The following condition is constant to the compiler
      pragma Warnings (Off);

      pragma Annotate
           (Xcov, Exempt_On, "optimized by compiler according to target");

      if Standard'Target_Name = "powerpc-elf" then

         pragma Annotate (Xcov, Exempt_Off);

         pragma Warnings (On);

         System.Machine_Code.Asm ("cntlzw %0,%1",
                                  Integer'Asm_Output ("=r", Res),
                                  Unsigned_32'Asm_Input ("r", V));

         pragma Annotate
           (Xcov, Exempt_On, "optimized by compiler according to target");

      elsif Standard'Target_Name = "arm-eabi" then

         pragma Annotate (Xcov, Exempt_Off);

         declare
            function CLZ (V : Unsigned_32) return Natural;
            pragma Import (Intrinsic, CLZ, "__builtin_clz");
         begin
            Res := CLZ (V);
         end;

      else
         if (V and 16#ffff_0000#) = 0 then
            Res := 16;
            Tmp := Shift_Left (V, 16);
         else
            Res := 0;
            Tmp := V;
         end if;

         if (Tmp and 16#ff00_0000#) = 0 then
            Res := Res + 8;
            Tmp := Shift_Left (Tmp, 8);
         end if;

         if (Tmp and 16#f000_0000#) = 0 then
            Res := Res + 4;
            Tmp := Shift_Left (Tmp, 4);
         end if;

         if (Tmp and 16#c000_0000#) = 0 then
            Res := Res + 2;
            Tmp := Shift_Left (Tmp, 2);
         end if;

         if (Tmp and 16#8000_0000#) = 0 then
            Res := Res + 1;
         end if;
      end if;

      return Res;
   end Count_Leading_Zero;

   ----------------
   -- Udivmoddi4 --
   ----------------

   pragma Annotate (Gnatcheck, Exempt_On, "Metrics_Cyclomatic_Complexity",
                    "performance issues");

   function Udivmoddi4 (Num : Unsigned_64;
                        Den : Unsigned_64;
                        Remainder : access Unsigned_64)
                       return Unsigned_64
   is
      pragma Suppress (All_Checks);
      Den_Sh, Num_Sh : Natural;
      --  Number of leading zero in denominator and numerator

      Diff_Sh : Natural;

      D1, D0 : Unsigned_32;
      --  High and low part of Den

      N1, N0 : Unsigned_32;
      --  High and low part of Num
   begin
      Split (Num, N1, N0);
      Split (Den, D1, D0);

      if D1 = 0 then
         --  Small denominator

         if N1 = 0 then
            --  32 bit division

            declare
               Q0 : Unsigned_32;
            begin
               Q0 := N0 / D0;

               if Remainder /= null then
                  Remainder.all := Unsigned_64 (N0 - Q0 * D0);
               end if;

               pragma Annotate (Gnatcheck, Exempt_On, "Improper_Returns",
                                "early return for performance");

               return Unsigned_64 (Q0);

               pragma Annotate (Gnatcheck, Exempt_Off, "Improper_Returns");
            end;

         elsif D0 < 2**16 then
            --  Use pencil and paper algorithm, using D0 as single digit. The
            --  quotient is Q2:Q1:Q0.

            declare
               Q2, Q1, Q0 : Unsigned_32;
            begin
               --  First digit
               Q2 := N1 / D0;
               N1 := N1 - Q2 * D0;  --  Less than 2**16
               N1 := Shift_Left (N1, 16) or Shift_Right (N0, 16);

               --  Second digit
               Q1 := N1 / D0;
               N1 := N1 - Q1 * D0;  --  Less than 2**16
               N1 := Shift_Left (N1, 16) or (N0 and 16#ffff#);

               --  Third digit
               Q0 := N1 / D0;

               if Remainder /= null then
                  Remainder.all := Unsigned_64 (N1 - Q0 * D0);
               end if;

               pragma Annotate (Gnatcheck, Exempt_On, "Improper_Returns",
                                "early return for performance");

               return Merge (Q2, Shift_Left (Q1, 16) or Q0);

               pragma Annotate (Gnatcheck, Exempt_Off, "Improper_Returns");
            end;
         end if;

         Den_Sh := 32 + Count_Leading_Zero (D0);
      else
         Den_Sh := Count_Leading_Zero (D1);
      end if;

      --  Number of leading zero for the numerator
      if N1 = 0 then
         Num_Sh := 32 + Count_Leading_Zero (N0);
      else
         Num_Sh := Count_Leading_Zero (N1);
      end if;

      if Den_Sh < Num_Sh then
         --  Den < Num, so the quotient is 0

         if Remainder /= null then
            Remainder.all := Num;
         end if;

         pragma Annotate (Gnatcheck, Exempt_On, "Improper_Returns",
                          "early return for performance");

         return 0;

         pragma Annotate (Gnatcheck, Exempt_Off, "Improper_Returns");
      end if;

      --  Align the denominator on the numerator, and use pencil and paper
      --  algorithm in base 2. Nothing special is done for division per 0,
      --  the result isn't meaningful.

      Diff_Sh := Den_Sh - Num_Sh;
      if Diff_Sh > 32 then
         D1 := Shift_Left (D0, Diff_Sh - 32);
         D0 := 0;
      else
         D1 := Shift_Left (D1, Diff_Sh) or Shift_Right (D0, 32 - Diff_Sh);
         D0 := Shift_Left (D0, Diff_Sh);
      end if;

      declare
         N : Unsigned_64 := Num;
         Q : Unsigned_64 := 0;
      begin
         for I in 0 .. Diff_Sh loop
            Q := Shift_Left (Q, 1);

            if N >= Merge (D1, D0) then
               Q := Q or 1;
               N := N - Merge (D1, D0);
            end if;

            D0 := Shift_Right (D0, 1) or Shift_Left (D1, 31);
            D1 := Shift_Right (D1, 1);
         end loop;

         if Remainder /= null then
            Remainder.all := N;
         end if;

         pragma Annotate (Gnatcheck, Exempt_On, "Improper_Returns",
                          "code clearer with 2 returns");

         return Q;

         pragma Annotate (Gnatcheck, Exempt_Off, "Improper_Returns");
      end;
   end Udivmoddi4;

   pragma Annotate (Gnatcheck, Exempt_Off, "Metrics_Cyclomatic_Complexity");

   -------------
   -- Udivdi3 --
   -------------

   function Udivdi3 (Num : Unsigned_64; Den : Unsigned_64)
                    return Unsigned_64 is
   begin
      return Udivmoddi4 (Num, Den, null);
   end Udivdi3;

   -------------
   -- Umoddi3 --
   -------------

   function Umoddi3 (Num : Unsigned_64; Den : Unsigned_64)
                    return Unsigned_64 is
      Remainder : aliased Unsigned_64;
      Result    : Unsigned_64;
      pragma Warnings (Off, Result); -- kill unused warning
   begin
      Result := Udivmoddi4 (Num, Den, Remainder'Access);
      return Remainder;
   end Umoddi3;

   ---------------
   -- Divmoddi3 --
   ---------------

   function Divmoddi3 (Num : Integer_64;
                       Den : Integer_64;
                       Return_Rem : Boolean)
                       return Integer_64
   is
      pragma Suppress (All_Checks);
      Neg       : Boolean := False;
      N         : Unsigned_64;
      D         : Unsigned_64;
      R         : Unsigned_64;
      Remainder : aliased Unsigned_64;
      Res       : Integer_64;
   begin
      if Num < 0 then
         Neg := True;
         N := Unsigned_64 (-Num);
      else
         N := Unsigned_64 (Num);
      end if;

      if Den < 0 then
         Neg := not Neg;
         D := Unsigned_64 (-Den);
      else
         D := Unsigned_64 (Den);
      end if;

      R := Udivmoddi4 (N, D, Remainder'Access);

      --  The remainder has the sign of the numerator
      if Return_Rem then
         Neg := Num < 0;
         R   := Remainder;
      end if;

      if Neg then
         Res := -Integer_64 (R);
      else
         Res := Integer_64 (R);
      end if;

      return Res;
   end Divmoddi3;

   ------------
   -- Divdi3 --
   ------------

   function Divdi3 (Num : Integer_64; Den : Integer_64) return Integer_64 is
   begin
      return Divmoddi3 (Num, Den, False);
   end Divdi3;

   ------------
   -- Moddi3 --
   ------------

   function Moddi3 (Num : Integer_64; Den : Integer_64) return Integer_64 is
   begin
      return Divmoddi3 (Num, Den, True);
   end Moddi3;

end System.GCC.DI.Divisions;
