------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--               S Y S T E M . G C C . D I . D I V I S I O N S              --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--            Copyright (C) 2013-2025, Free Software Foundation, Inc.       --
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

--  @design @internal
--  This package provides signed and unsigned 64 bit division and remainder.

pragma Restrictions (No_Elaboration_Code);

package System.GCC.DI.Divisions is
   pragma Pure;

   function Udivmoddi4
     (Num : Unsigned_64; Den : Unsigned_64; Remainder : access Unsigned_64)
     return Unsigned_64;
   pragma Export (C, Udivmoddi4, "__udivmoddi4");
   --  @internal
   --  Unsigned division with reminder.
   --  Effects: if Rem /= null then Rem.all = a rem b end if;
   --  Returns: Num / Den

   function Udivdi3 (Num : Unsigned_64; Den : Unsigned_64) return Unsigned_64;
   pragma Export (C, Udivdi3, "__udivdi3");
   --  Unsigned division. Raise CE if Den is 0.

   function Umoddi3 (Num : Unsigned_64; Den : Unsigned_64) return Unsigned_64;
   pragma Export (C, Umoddi3, "__umoddi3");
   --  Unsigned remainder

   function Divdi3 (Num : Integer_64; Den : Integer_64) return Integer_64;
   pragma Export (C, Divdi3, "__divdi3");
   --  Signed division, without checking overflows

   function Moddi3 (Num : Integer_64; Den : Integer_64) return Integer_64;
   pragma Export (C, Moddi3, "__moddi3");
   --  Unsigned remainder. This implements the Ada 'rem' operator, without
   --  checking overflows.
end System.GCC.DI.Divisions;
