------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                   S Y S T E M .  M E M O R Y _ T Y P E S                 --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--              Copyright (C) 2017-2025, Free Software Foundation, Inc.     --
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

--  This is the CHERI version of this package

with System.Storage_Elements;

package System.Memory_Types is
   pragma No_Elaboration_Code_All;
   pragma Pure;

   package SSE renames System.Storage_Elements;

   use type SSE.Integer_Address;

   type size_t is mod Memory_Size;
   --  The type corresponding to size_t in C. We cannot reuse the one defined
   --  in Interfaces.C as we want this package not to have any elaboration
   --  code.

   type Byte is mod 2 ** 8;
   for Byte'Size use 8;
   --  Byte is the storage unit

   Byte_Unit : constant := 1;
   --  Number of storage unit in a byte

   type Word is mod 2 ** System.Word_Size;
   for Word'Size use System.Word_Size;
   --  Word is efficiently loaded and stored by the processor, but has
   --  alignment constraints.

   Word_Unit : constant := Word'Size / Storage_Unit;
   --  Number of storage unit per word

   Address_Unit : constant size_t := Address'Size / Storage_Unit;
   --  Number of storage unit per Address

   function Is_Aligned (A, B : Address) return Boolean is
     (((SSE.To_Integer (A) or SSE.To_Integer (B)) mod Address'Alignment) = 0);
   --  Check whether two addresses are both aligned to Address'Alignment

   function Align_Down_Amount (Addr : Address) return size_t is
     (size_t (SSE.To_Integer (Addr) mod Address'Alignment));
   --  Calculate the amount needed to subtract from an address until it is
   --  aligned to the previous Address'Alignment boundary.

   function Align_Up_Amount (A : Address) return size_t is
     (if Align_Down_Amount (A) = 0 then 0
      else Address'Alignment - Align_Down_Amount (A));
   --  Calculate the amount needed to add to an address until it is aligned to
   --  the next Address'Alignment boundary.

end System.Memory_Types;
