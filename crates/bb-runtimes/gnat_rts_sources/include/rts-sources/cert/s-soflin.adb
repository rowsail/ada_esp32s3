------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                    S Y S T E M . S O F T _ L I N K S                     --
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

package body System.Soft_Links is

   NT_TSD : aliased TSD;
   --  The task specific data for the main task when the Ada tasking run-time
   --  is not used. It relies on the default initialization of NT_TSD.

   NT_Sec_Stack_Ptr : SST.SS_Stack_Ptr := null;
   pragma Export (Ada, NT_Sec_Stack_Ptr, "__gnat_main_sec_stack");
   --  The non-tasking secondary stack pointer is set by the binder before the
   --  package is elaborated and is stored separately to prevent the
   --  default initialization of NT_TSD from overwriting it.

   --  Needed for Vx6Cert (Vx653mc) GOS cert and ravenscar-cert runtimes,
   --  VxMILS cert, ravenscar-cert and full runtimes, Vx 5 default runtime
   Stack_Limit : aliased System.Address;
   pragma Export (C, Stack_Limit, "__gnat_stack_limit");

   ----------------------
   -- Get_Sec_Stack_NT --
   ----------------------

   function Get_Sec_Stack_NT return SST.SS_Stack_Ptr is
   begin
      return NT_Sec_Stack_Ptr;
   end Get_Sec_Stack_NT;

   -----------------------------
   -- Get_Sec_Stack_Soft --
   -----------------------------

   function Get_Sec_Stack_Soft return SST.SS_Stack_Ptr is
   begin
      return Get_Sec_Stack.all;
   end Get_Sec_Stack_Soft;

   -------------------
   -- Null_Adafinal --
   -------------------

   procedure Null_Adafinal is
   begin
      null;
   end Null_Adafinal;

   ------------------------
   -- Get_GNAT_Exception --
   ------------------------

   function Get_GNAT_Exception return Ada.Exceptions.Exception_Id is
      Cur_TSD : constant not null TSD_Access := Get_TSD_Addr.all;
   begin
      return Ada.Exceptions.Exception_Identity
        (Cur_TSD.Exceptions (Cur_TSD.Last_Exception).Occurrence);
   end Get_GNAT_Exception;

   ----------------
   -- Get_TSD_NT --
   ----------------

   function Get_TSD_NT return TSD_Access is
   begin
      return NT_TSD'Access;
   end Get_TSD_NT;

   ----------------------
   -- Set_Sec_Stack_NT --
   ----------------------

   procedure Set_Sec_Stack_NT (Stack : SST.SS_Stack_Ptr) is
   begin
      NT_Sec_Stack_Ptr := Stack;
   end Set_Sec_Stack_NT;

   ------------------------
   -- Set_Sec_Stack_Soft --
   ------------------------

   procedure Set_Sec_Stack_Soft (Stack : SST.SS_Stack_Ptr) is
   begin
      Set_Sec_Stack (Stack);
   end Set_Sec_Stack_Soft;

   ----------------------
   -- Set_Sjlj_Context --
   ----------------------

   procedure Set_Sjlj_Context (Fc : Sjlj_Function_Context_Acc) is
   begin
      Get_TSD_Addr.all.all.Sjlj_Context := Fc;
   end Set_Sjlj_Context;

   ----------------------
   -- Get_Sjlj_Context --
   ----------------------

   function Get_Sjlj_Context return Sjlj_Function_Context_Acc is
   begin
      return Get_TSD_Addr.all.all.Sjlj_Context;
   end Get_Sjlj_Context;

end System.Soft_Links;
