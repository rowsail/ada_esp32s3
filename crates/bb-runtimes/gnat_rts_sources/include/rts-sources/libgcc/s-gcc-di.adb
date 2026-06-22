------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                         S Y S T E M . G C C . D I                        --
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

package body System.GCC.DI is
   use Interfaces;

   -----------
   -- Split --
   -----------

   procedure Split (Val : Unsigned_64;
                    Hi : out Unsigned_32;
                    Lo : out Unsigned_32)
   is
   begin
      Hi := Unsigned_32 (Val / 2**32);
      Lo := Unsigned_32 (Val rem 2**32);
   end Split;

   -----------
   -- Merge --
   -----------

   function Merge (Hi : Unsigned_32; Lo : Unsigned_32) return Unsigned_64 is
   begin
      return Unsigned_64 (Hi) * 2**32 + Unsigned_64 (Lo);
   end Merge;

end System.GCC.DI;
