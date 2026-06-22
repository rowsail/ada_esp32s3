------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--               S Y S T E M . S E C O N D A R Y _ S T A C K                --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--          Copyright (C) 1992-2025, Free Software Foundation, Inc.         --
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

--  This is the Cert version of this package, needed for thread registration
--  (rts-cert on VxWorks) or cert Ada tasking (rts-ravenscar-cert,
--  rts-ravenscar-cert-rtp). Also OK for rts-cert on LynxOS-178 where APEX
--  processes are not threads. It is a simplified version of the package that
--  assumes the fixed allocation of the secondary stack, and includes only the
--  interfaces needed for the fixed allocation case.

with Ada.Unchecked_Conversion;
with System.Soft_Links;

package body System.Secondary_Stack is

   package SSL renames System.Soft_Links;

   use type System.Parameters.Size_Type;

   -----------------
   -- SS_Allocate --
   -----------------

   procedure SS_Allocate
     (Addr         : out Address;
      Storage_Size : SSE.Storage_Count;
      Alignment    : SSE.Storage_Count := Standard'Maximum_Alignment)
   is
      use type System.Storage_Elements.Storage_Count;
      use type System.Storage_Elements.Integer_Address;

      function Align_Addr (Addr : Address) return Address;
      pragma Inline (Align_Addr);
      --  Align Addr to the next multiple of Alignment

      ----------------
      -- Align_Addr --
      ----------------

      function Align_Addr (Addr : Address) return Address is
         Int_Algn : constant SSE.Integer_Address :=
           SSE.Integer_Address (Alignment);
         Int_Addr : constant SSE.Integer_Address := SSE.To_Integer (Addr);
      begin

         --  L : Alignment
         --  A : Standard'Maximum_Alignment

         --           Addr
         --      L     |     L           L
         --   ...A--A--A--A--A--A--A--A--A--A--A--...
         --                  |     |
         --      \----/      |     |
         --    Addr mod L    |   Addr + L
         --                  |
         --                Addr + L - (Addr mod L)

         return SSE.To_Address (Int_Addr + Int_Algn - (Int_Addr mod Int_Algn));
      end Align_Addr;

      Max_Align   : constant SS_Ptr := SS_Ptr (Standard'Maximum_Alignment);
      Mem_Request : SS_Ptr;

      Over_Aligning : constant Boolean :=
        Alignment > Standard'Maximum_Alignment;

      Padding : SSE.Storage_Count := 0;

      Stack : constant SS_Stack_Ptr := SSL.Get_Sec_Stack.all;
   begin
      --  Alignment must be a power of two and can be:

      --  - lower than or equal to Maximum_Alignement, in which case the result
      --    will be aligned on Maximum_Alignement;
      --  - higher than Maximum_Alignement, in which case the result will be
      --    dynamically realigned.

      if Over_Aligning then
         Padding := Alignment;
      end if;

      --  Round up Storage_Size (plus the needed padding in case of
      --  over-alignment) to the nearest multiple of the max alignment value
      --  for the target to ensure efficient access and that the next available
      --  Byte is always aligned on the default alignement value.

      --  First perform a check to ensure that the rounding operation does not
      --  overflow SS_Ptr.

      if SSE.Storage_Count (SS_Ptr'Last) - Standard'Maximum_Alignment <
        (Storage_Size + Padding)
      then
         raise Storage_Error;
      end if;

      Mem_Request :=
        ((SS_Ptr (Storage_Size + Padding) + Max_Align - 1)
         / Max_Align) * Max_Align;

      --  Check if max stack usage is increasing

      if Stack.Max - Stack.Top - Mem_Request < 0 then
         --  If so, check if the stack is exceeded, noting Stack.Top points to
         --  the first free byte (so the value of Stack.Top on a fully
         --  allocated stack will be Stack.Size + 1). The comparison is formed
         --  to prevent integer overflows.

         if Stack.Size - Stack.Top - Mem_Request < -1 then
            raise Storage_Error;
         end if;

         --  Record new max usage

         Stack.Max := Stack.Top + Mem_Request;
      end if;

      --  Set resulting address and update top of stack pointer

      Addr := Stack.Internal_Chunk (Stack.Top)'Address;

      if Over_Aligning then
         Addr := Align_Addr (Addr);
      end if;

      Stack.Top := Stack.Top + Mem_Request;
   end SS_Allocate;

   ----------------
   -- SS_Get_Max --
   ----------------

   function SS_Get_Max return Long_Long_Integer is
      Stack : constant SS_Stack_Ptr := SSL.Get_Sec_Stack.all;
   begin
      --  Stack.Max points to the first untouched byte in the stack, thus the
      --  maximum number of bytes that have been allocated on the stack is one
      --  less the value of Stack.Max.

      return Long_Long_Integer (Stack.Max - 1);
   end SS_Get_Max;

   -------------
   -- SS_Init --
   -------------

   procedure SS_Init
     (Stack : in out SS_Stack_Ptr;
      Size  : SP.Size_Type := SP.Unspecified_Size)
   is
      use Parameters;

   begin
      --  If the size of the secondary stack for a task has been specified via
      --  the Secondary_Stack_Size aspect, then the compiler has allocated the
      --  stack at compile time and the task create call will provide a pointer
      --  to this stack. Otherwise, the task will be allocated a secondary
      --  stack from the pool of default-sized secondary stacks created by the
      --  binder.

      if Stack = null then
         --  Allocate a default-sized stack for the task.

         if Size = Unspecified_Size
           and then Binder_SS_Count > 0
           and then Num_Of_Assigned_Stacks < Binder_SS_Count
         then
            --  The default-sized secondary stack pool is passed from the
            --  binder to this package as an Address since it is not possible
            --  to have a pointer to an array of unconstrained objects. A
            --  pointer to the pool is obtainable via an unchecked conversion
            --  to a constrained array of SS_Stacks that mirrors the one used
            --  by the binder.

            --  However, Ada understandably does not allow a local pointer to
            --  a stack in the pool to be stored in a pointer outside of this
            --  scope. While the conversion is safe in this case, since a view
            --  of a global object is being used, using Unchecked_Access
            --  would prevent users from specifying the restriction
            --  No_Unchecked_Access whenever the secondary stack is used. As
            --  a workaround, the local stack pointer is converted to a global
            --  pointer via System.Address.

            declare
               type Stk_Pool_Array is array (1 .. Binder_SS_Count) of
                 aliased SS_Stack (Default_SS_Size);
               type Stk_Pool_Access is access Stk_Pool_Array;

               function To_Stack_Pool is new
                 Ada.Unchecked_Conversion (Address, Stk_Pool_Access);

               pragma Warnings (Off);
               function To_Global_Ptr is new
                 Ada.Unchecked_Conversion (Address, SS_Stack_Ptr);
               pragma Warnings (On);
               --  Suppress aliasing warning since the pointer we return will
               --  be the only access to the stack.

               Local_Stk_Address : System.Address;

            begin
               Num_Of_Assigned_Stacks := Num_Of_Assigned_Stacks + 1;

               Local_Stk_Address :=
                 To_Stack_Pool
                   (Default_Sized_SS_Pool) (Num_Of_Assigned_Stacks)'Address;
               Stack := To_Global_Ptr (Local_Stk_Address);
            end;

         --  Many run-times unconditionally bring in this package and call
         --  SS_Init even though the secondary stack is not used by the
         --  program. In this case return without assigning a stack as it will
         --  never be used.

         elsif Binder_SS_Count = 0 then
            return;

         else
            raise Program_Error;
         end if;
      end if;

      Stack.Top := 1;
      Stack.Max := 1;
   end SS_Init;

   -------------
   -- SS_Mark --
   -------------

   function SS_Mark return Mark_Id is
   begin
      return Mark_Id (SSL.Get_Sec_Stack.all.Top);
   end SS_Mark;

   ----------------
   -- SS_Release --
   ----------------

   procedure SS_Release (M : Mark_Id) is
      Stack : constant SS_Stack_Ptr := SSL.Get_Sec_Stack.all;
   begin
      Stack.Top := SS_Ptr (M);
   end SS_Release;

end System.Secondary_Stack;
