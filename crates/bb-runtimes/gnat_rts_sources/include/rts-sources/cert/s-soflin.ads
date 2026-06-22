------------------------------------------------------------------------------
--                                                                          --
--                         GNAT COMPILER COMPONENTS                         --
--                                                                          --
--                    S Y S T E M . S O F T _ L I N K S                     --
--                                                                          --
--                                 S p e c                                  --
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

--  Ravenscar / CERT

--  This package contains a set of subprogram access variables that access some
--  low-level primitives that are called different depending wether tasking is
--  involved or not (e.g. the Get/Set_Jmpbuf_Address that needs to provide a
--  different value for each task). To avoid dragging in the tasking all the
--  time, we use a system of soft links where the links are initialized to
--  non-tasking versions, and then if the tasking is initialized, they are
--  reset to the real tasking versions.

with Ada.Exceptions;

with System.Secondary_Stack;
with System.Storage_Elements;
with System.Exceptions.Machine;

package System.Soft_Links is
   pragma Preelaborate;

   package SST renames System.Secondary_Stack;

   subtype EOA is Ada.Exceptions.Exception_Occurrence_Access;
   subtype EO is Ada.Exceptions.Exception_Occurrence;

   --  First we have the access subprogram types used to establish the links.
   --  The approach is to establish variables containing access subprogram
   --  values which by default point to dummy no tasking versions of routines.

   type No_Param_Proc     is access procedure;
   type EO_Param_Proc     is access procedure (Excep : EO);

   type Get_Stack_Call  is access function return SST.SS_Stack_Ptr;
   type Set_Stack_Call  is access procedure (Stack : SST.SS_Stack_Ptr);

   type Get_Integer_Call  is access function return Integer;
   type Set_Integer_Call  is access procedure (Len : Integer);

   type Get_EOA_Call      is access function return EOA;

   --  Suppress checks on all these types, since we know corresponding values
   --  can never be null (the soft links are always initialized).

   pragma Suppress (Access_Check, No_Param_Proc);
   pragma Suppress (Access_Check, Get_Stack_Call);
   pragma Suppress (Access_Check, Set_Stack_Call);
   pragma Suppress (Access_Check, Get_Integer_Call);
   pragma Suppress (Access_Check, Set_Integer_Call);
   pragma Suppress (Access_Check, Get_EOA_Call);

   procedure Null_Adafinal;
   --  Shuts down the runtime system (non-tasking no-finalization case,
   --  does nothing)

   Adafinal : No_Param_Proc := Null_Adafinal'Access;
   --  Performs the finalization of the Ada Runtime

   function  Get_Sec_Stack_NT return  SST.SS_Stack_Ptr;
   procedure Set_Sec_Stack_NT (Stack : SST.SS_Stack_Ptr);

   Get_Sec_Stack : Get_Stack_Call := Get_Sec_Stack_NT'Access;
   Set_Sec_Stack : Set_Stack_Call := Set_Sec_Stack_NT'Access;

   --  Export the Get/Set routines for the various Task Specific Data (TSD)
   --  elements as callable subprograms instead of objects of access to
   --  subprogram types.

   function  Get_Sec_Stack_Soft return  SST.SS_Stack_Ptr;
   procedure Set_Sec_Stack_Soft (Stack : SST.SS_Stack_Ptr);
   pragma Inline (Get_Sec_Stack_Soft);
   pragma Inline (Set_Sec_Stack_Soft);

   function Get_GNAT_Exception return Ada.Exceptions.Exception_Id;
   --  This function obtains the Exception_Id from Exception_Occurrence
   --  referenced by the current exception of the task specific data.
   --  This is used to transfer exceptions from entries.

   type Stack_Info is record
      Start_Address : System.Address := System.Null_Address;
      Size          : System.Storage_Elements.Storage_Offset;
   end record;
   pragma Suppress_Initialization (Stack_Info);

   Max_Nbr_Occurrences : constant := 8;
   --  Maximum number of in-flight (or nested) exceptions. An exception is
   --  said in-flight when it is propagated or could be reraised.

   type Exceptions_Array is array (1 .. Max_Nbr_Occurrences) of
     aliased System.Exceptions.Machine.GNAT_GCC_Exception;
   --  Array for in-flight exceptions

   type Sjlj_Function_Context is null record;
   type Sjlj_Function_Context_Acc is access Sjlj_Function_Context;
   pragma Convention (C, Sjlj_Function_Context_Acc);
   --  Ada opaque representation of the SjLj function context pointer

   type TSD is record
      Pri_Stack_Info : aliased Stack_Info;
      --  Information on stack (Base/Limit/Size) used by System.Stack_Checking.
      --  If this TSD does not belong to the environment task, the Size field
      --  must be initialized to the tasks requested stack size before the task
      --  can do its first stack check.

      Sec_Stack_Ptr : SST.SS_Stack_Ptr;
      --  Pointer of the allocated secondary stack

      Sjlj_Context : Sjlj_Function_Context_Acc := null;
      --  Pointer to the function context for sjlj exception

      Last_Exception : Natural := 0;
      --  Index of the last exception used in the array of exception. 0 means
      --  no exception used.

      Exceptions : Exceptions_Array;
      --  Per thread static buffer of exceptions
   end record;

   type TSD_Access is access all TSD;

   type Get_TSD_Call is not null access function return TSD_Access;

   function Get_TSD_NT return TSD_Access;

   Get_TSD_Addr : Get_TSD_Call := Get_TSD_NT'Access;

   procedure Set_Sjlj_Context (Fc : Sjlj_Function_Context_Acc);
   pragma Export (C, Set_Sjlj_Context, "__gnat_set_sjlj_context");
   function  Get_Sjlj_Context return Sjlj_Function_Context_Acc;
   pragma Export (C, Get_Sjlj_Context, "__gnat_get_sjlj_context");
   --  Routine (compatible with C) to set and get the sjlj function context
end System.Soft_Links;
