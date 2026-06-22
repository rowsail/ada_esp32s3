------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                 S Y S T E M . G C C . D I . S H I F T S                  --
--                                                                          --
--                                 S p e c                                  --
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

--  @design
--  This package implements shift operators for 64-bit integers.
--
--  In particular it provides:
--
--  * ``__aeabi_llsr``
--  * ``__aeabi_lasr``
--  * ``__aeabi_llsl``
--
--  Those subprograms are defined in [ARM-RT-ABI]. Please refer to this
--  document for more information.

pragma Restrictions (No_Elaboration_Code);

package System.GCC.DI.Shifts is
   pragma Pure;

   function Lshrdi3 (Val : Unsigned_64; Count : Integer) return Unsigned_64;
   pragma Export (C, Lshrdi3, "__aeabi_llsr");
   --  Logical right rotation of Val by Count position. Return 0 if Count is
   --  greater or equal than 64, and Val if less than 1.

   function Ashrdi3 (Val : Unsigned_64; Count : Integer) return Unsigned_64;
   pragma Export (C, Ashrdi3, "__aeabi_lasr");
   --  Arithmetic right rotation of Val by Count position. Return 0 or -1 if
   --  Count is greater or equal than 64, and Val if less than 1.

   function Ashldi3 (Val : Unsigned_64; Count : Integer) return Unsigned_64;
   pragma Export (C, Ashldi3, "__aeabi_llsl");
   --  Left rotation of Val by Count position. Return 0 if Count is
   --  greater or equal than 64, and Val if less than 1.
end System.GCC.DI.Shifts;
