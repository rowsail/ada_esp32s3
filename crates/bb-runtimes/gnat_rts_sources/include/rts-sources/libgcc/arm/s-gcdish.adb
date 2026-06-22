------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                 S Y S T E M . G C C . D I . S H I F T S                  --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--         Copyright (C) 2013-2025, Free Software Foundation, Inc.          --
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

package body System.GCC.DI.Shifts is
   use Interfaces;

   -------------
   -- Lshrdi3 --
   -------------

   function Lshrdi3 (Val : Unsigned_64; Count : Integer) return Unsigned_64
   is
      Hi, Lo  : Unsigned_32;
      Carries : Unsigned_32;
      Res     : Unsigned_64;
   begin
      Split (Val, Hi, Lo);

      case Count is
         when 64 .. Integer'Last =>
            Res := 0;
         when 32 .. 63 =>
            Res := Unsigned_64 (Shift_Right (Hi, Count - 32));
         when 1 .. 31 =>
            Carries := Shift_Left (Hi, 32 - Count);
            Hi := Shift_Right (Hi, Count);
            Lo := Shift_Right (Lo, Count) or Carries;
            Res := Merge (Hi, Lo);
         when Integer'First .. 0 =>
            Res := Val;
      end case;

      return Res;
   end Lshrdi3;

   -------------
   -- Ashrdi3 --
   -------------

   function Ashrdi3 (Val : Unsigned_64; Count : Integer) return Unsigned_64
   is
      Hi, Lo  : Unsigned_32;
      Carries : Unsigned_32;
      Res     : Unsigned_64;
   begin
      Split (Val, Hi, Lo);

      case Count is
         when 64 .. Integer'Last =>
            Hi := Shift_Right_Arithmetic (Hi, 31);
            Res := Merge (Hi, Hi);
         when 32 .. 63 =>
            Lo := Shift_Right_Arithmetic (Hi, Count - 32);
            Hi := Shift_Right_Arithmetic (Hi, 31);
            Res := Merge (Hi, Lo);
         when 1 .. 31 =>
            Carries := Shift_Left (Hi, 32 - Count);
            Hi := Shift_Right_Arithmetic (Hi, Count);
            Lo := Shift_Right (Lo, Count) or Carries;
            Res := Merge (Hi, Lo);
         when Integer'First .. 0 =>
            Res := Val;
      end case;

      return Res;
   end Ashrdi3;

   -------------
   -- Ashldi3 --
   -------------

   function Ashldi3 (Val : Unsigned_64; Count : Integer) return Unsigned_64
   is
      Hi, Lo : Unsigned_32;
      Carries : Unsigned_32;
      Res : Unsigned_64;
   begin
      Split (Val, Hi, Lo);

      case Count is
         when 64 .. Integer'Last =>
            Res := 0;
         when 32 .. 63 =>
            Res := Merge (Shift_Left (Lo, Count - 32), 0);
         when 1 .. 31 =>
            Carries := Shift_Right (Lo, 32 - Count);
            Lo := Shift_Left (Lo, Count);
            Hi := Shift_Left (Hi, Count) or Carries;
            Res := Merge (Hi, Lo);
         when Integer'First .. 0 =>
            Res := Val;
      end case;

      return Res;
   end Ashldi3;
end System.GCC.DI.Shifts;
