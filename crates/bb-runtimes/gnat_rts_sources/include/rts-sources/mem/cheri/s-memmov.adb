------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                     S Y S T E M .  M E M O R Y _ M O V E                 --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--            Copyright (C) 2006-2025, Free Software Foundation, Inc.       --
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

--  This is the CHERI version

--  On CHERI targets, the memory being copied may contain valid capabilities
--  whose tags must be preserved during the copy. This implementation attempts
--  to copy by Address units (i.e. capabilities) instead of Word units whenever
--  alignment constraints are met to ensure capabilities are preserved.

with Ada.Unchecked_Conversion;
with System.Memory_Types; use System.Memory_Types;
with System.Storage_Elements; use System.Storage_Elements;

package body System.Memory_Move is

   -------------
   -- memmove --
   -------------

   function memmove
     (Dest : Address;
      Src  : Address;
      N    : size_t)
      return Address
   is

      function To_Storage_Offset is new Ada.Unchecked_Conversion
        (Source => size_t,
         Target => System.Storage_Elements.Storage_Offset);
      --  To support targets that use capabilities, Address arithmetic has to
      --  be performed using the facilities provided by
      --  System.Storage_Elements. Since size_t and Storage_Offset have
      --  different ranges (Storage_Offset'Last is about half of size_t'Last),
      --  large size_t values cannot be safely converted to Storage_Offset
      --  using a regular type conversion. We instead use
      --  Unchecked_Conversion, taking advantage that Address is a modular
      --  type and adding the signed representation representation of size_t
      --  (Storage_Offset) is equivalent to adding the unsigned representation
      --  of size_t.

      D : Address := Dest;
      S : Address := Src;
      C : size_t  := N;
      A : size_t;
   begin
      --  There was an early exit if there are no bytes to copy. There are no
      --  reasons to handle this very rare case specially, as it is handled
      --  correctly by the common path.

      --  This function must handle overlapping memory regions for the source
      --  and destination. If the Dest buffer is located past the Src buffer
      --  then we use backward copying, and forward copying otherwise.

      --  To support targets that use hardware capabilities this function
      --  tries to copy by Address units whenever alignment constraints are met
      --  to ensure that the capability validity tags are correctly preserved
      --  during the copy.

      if D > S and then D < S + To_Storage_Offset (C) then

         --  Backward copy

         D := D + To_Storage_Offset (C);
         S := S + To_Storage_Offset (C);

         --  If Src and Dest are misaligned by the same amount, then copy per
         --  byte until they are both aligned.

         A := Align_Down_Amount (S);

         if A > 0 and then A = Align_Down_Amount (D) then
            A := size_t'Min (A, C);  -- Don't copy more than C bytes
            C := C - A;

            while A > 0 loop
               D := D - Storage_Count (Byte_Unit);
               S := S - Storage_Count (Byte_Unit);
               declare
                  D_B : Byte with Import, Address => D;
                  S_B : Byte with Import, Address => S;
               begin
                  D_B := S_B;
               end;

               A := A - Byte_Unit;
            end loop;
         end if;

         --  Try to copy address units, if alignment constraints are respected

         if Is_Aligned (S, D) then
            while C >= Address_Unit loop
               D := D - Storage_Count (Address_Unit);
               S := S - Storage_Count (Address_Unit);
               declare
                  D_W : Address with Import, Address => D;
                  S_W : Address with Import, Address => S;
               begin
                  D_W := S_W;
               end;

               C := C - Address_Unit;
            end loop;
         end if;

         --  Copy the remainder byte by byte

         while C /= 0 loop
            D := D - Storage_Count (Byte_Unit);
            S := S - Storage_Count (Byte_Unit);
            declare
               D_B : Byte with Import, Address => D;
               S_B : Byte with Import, Address => S;
            begin
               D_B := S_B;
            end;

            C := C - Byte_Unit;
         end loop;
      else

         --  Forward copy

         --  If Src and Dest are misaligned by the same amount, then copy per
         --  byte until they are both aligned.

         A := Align_Up_Amount (S);

         if A > 0 and then A = Align_Up_Amount (D) then
            A := size_t'Min (A, C);  -- Don't copy more than C bytes
            C := C - A;

            while A > 0 loop
               declare
                  D_B : Byte with Import, Address => D;
                  S_B : Byte with Import, Address => S;
               begin
                  D_B := S_B;
               end;

               D := D + Storage_Count (Byte_Unit);
               S := S + Storage_Count (Byte_Unit);
               A := A - Byte_Unit;
            end loop;
         end if;

         --  Try to copy per word, if alignment constraints are respected

         if Is_Aligned (S, D) then
            while C >= Address_Unit loop
               declare
                  D_W : Address with Import, Address => D;
                  S_W : Address with Import, Address => S;
               begin
                  D_W := S_W;
               end;
               D := D + Storage_Count (Address_Unit);
               S := S + Storage_Count (Address_Unit);
               C := C - Address_Unit;
            end loop;
         end if;

         --  Copy the remainder byte by byte

         while C /= 0 loop
            declare
               D_B : Byte with Import, Address => D;
               S_B : Byte with Import, Address => S;
            begin
               D_B := S_B;
            end;
            D := D + Storage_Count (Byte_Unit);
            S := S + Storage_Count (Byte_Unit);
            C := C - Byte_Unit;
         end loop;
      end if;

      return Dest;
   end memmove;

end System.Memory_Move;
