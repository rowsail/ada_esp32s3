------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                         S Y S T E M . M E M O R Y                        --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--          Copyright (C) 2001-2025, Free Software Foundation, Inc.         --
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

--  Simple implementation for use with ZFP on targets with capability-based
--  hardware memory protection features.

pragma Restrictions (No_Elaboration_Code);
--  This unit may be linked without being with'ed, so we need to ensure
--  there is no elaboration code (since this code might not be executed).

with Interfaces.CHERI;
with System.Storage_Elements;

package body System.Memory is
   use System.Storage_Elements;
   use Interfaces;

   Heap_Start : Character with
     Import, Convention => C, External_Name => "__heap_start";
   --  The address of the variable is the start of the heap

   Heap_End : Character with
     Import, Convention => C, External_Name => "__heap_end";
   --  The address of the variable is the end of the heap

   Heap_Limit : Integer_Address;
   --  The address of the end of the heap. This might be more strictly aligned
   --  than __heap_end to ensure that the capability's bounds are precisely
   --  representable.

   Top : Address;
   --  First not used address (always aligned to the maximum alignment)

   procedure Initialize with
     Export, Convention => C, External_Name => "__gnat_heap_init";
   --  Initializes the capability for the heap area.
   --
   --  The capability's bounds are set to avoid exceeding the address range
   --  Heap_Start .. Heap_End - 1. Due to capability compression, the actual
   --  bounds may be a subset of this range to ensure that the capability is
   --  representable.

   ----------------
   -- For C code --
   ----------------

   function Malloc (Size : size_t) return System.Address with
     Export, Convention => C, External_Name => "malloc";

   function Calloc (N_Elem : size_t; Elem_Size : size_t)
                    return System.Address with
     Export, Convention => C, External_Name => "calloc";

   procedure C_Free (Ptr : System.Address) with
     Export, Convention => C, External_Name => "free";

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize is
      Base   : Integer_Address;
      Limit  : Integer_Address;
      Length : CHERI.Bounds_Length;
   begin
      Base   := To_Integer (Heap_Start'Address);
      Limit  := To_Integer (Heap_End'Address);
      Length := (if Base <= Limit
                 then CHERI.Bounds_Length (Limit - Base)
                 else 0);

      --  Align the bounds to ensure the capability will be representable,
      --  taking care to avoid exceeding Heap_Base and Heap_Limit.

      Base   := CHERI.Align_Address_Up (Base, Length);
      Limit  := CHERI.Align_Address_Down (Limit, Length);
      Length := (if Base <= Limit
                 then CHERI.Bounds_Length (Limit - Base)
                 else 0);

      --  Create the heap capability from the DDC, without execute permissions

      Top := CHERI.Capability_With_Address_And_Exact_Bounds
               (Cap     => CHERI.Get_DDC,
                Address => Base,
                Length  => Length);

      Top := CHERI.Clear_Permissions (Top, CHERI.Permit_Execute);

      Heap_Limit := Base + Integer_Address (Length);
   end Initialize;

   -----------
   -- Alloc --
   -----------

   function Alloc (Size : size_t) return System.Address
   is
      Max_Align  : constant := Standard'Maximum_Alignment;
      Max_Size   : Storage_Count;
      Res        : Address;

   begin
      if Size = 0 then

         --  Change size from zero to nonzero. We still want a proper pointer
         --  for the zero case because pointers to zero-length objects have to
         --  be distinct.

         Max_Size := Max_Align;

      else
         --  Detect overflow in the addition below. Note that we know that
         --  upper bound of size_t is bigger than the upper bound of
         --  Storage_Count.

         if Size > size_t (Storage_Count'Last - Max_Align) then
            raise Storage_Error;
         end if;

         --  Compute aligned size

         Max_Size :=
           ((Storage_Count (Size) + Max_Align - 1) / Max_Align) * Max_Align;

         --  Round up the size to ensure the capability's upper bound is
         --  representable. This only affects very large allocations where
         --  the capability's bounds need an alignment greater than Max_Align
         --  due to capability compression.

         Max_Size := Storage_Count (CHERI.Representable_Length
                                      (CHERI.Bounds_Length (Max_Size)));
      end if;

      --  Align the lower bound of the capability so that it is representable
      --  and won't be rounded down, which would overlap with the previous
      --  allocation.

      Res := CHERI.Capability_With_Address_Aligned_Up
               (Top, CHERI.Bounds_Length (Max_Size));

      --  Detect too large allocation

      if Max_Size >= Storage_Count (Heap_Limit - CHERI.Get_Address (Res)) then
         pragma Annotate
           (CodePeer, Intentional, "range check", "defensive code");
         raise Storage_Error;
      end if;

      --  Update the top of the heap.

      Top := Res + Max_Size;

      --  Restrict the bounds of the returned capability.
      --
      --  Use the original requested size instead of Max_Size to ensure the
      --  bounds are as precise as possible.

      CHERI.Set_Exact_Bounds
        (Cap    => Res,
         Length => CHERI.Representable_Length (CHERI.Bounds_Length (Size)));

      return Res;
   end Alloc;

   ------------
   -- Malloc --
   ------------

   function Malloc (Size : size_t) return System.Address is
   begin
      return Alloc (Size);
   end Malloc;

   ------------
   -- Calloc --
   ------------

   function Calloc
     (N_Elem : size_t; Elem_Size : size_t) return System.Address
   is
   begin
      return Malloc (N_Elem * Elem_Size);
   end Calloc;

   ----------
   -- Free --
   ----------

   procedure Free (Ptr : System.Address) is
      pragma Unreferenced (Ptr);
   begin
      null;
   end Free;

   ------------
   -- C_Free --
   ------------

   procedure C_Free (Ptr : System.Address) is
   begin
      Free (Ptr);
   end C_Free;

end System.Memory;
