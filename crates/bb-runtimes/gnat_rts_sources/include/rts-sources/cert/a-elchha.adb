------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--    A D A . E X C E P T I O N S . L A S T _ C H A N C E _ H A N D L E R   --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--          Copyright (C) 2012-2025, Free Software Foundation, Inc.         --
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

--  Default last chance handler for use with the ravenscar-cert and cert
--  run-time libs on LynxOS-178

--  Dumps exception identity and partial argument string to addr2line for
--  generation of a symbolic stack backtrace (when gnatbind -E is used)

with GNAT.IO;                  use GNAT.IO;
with GNAT.Debug_Utilities;     use GNAT.Debug_Utilities;
with System.Standard_Library;  use System.Standard_Library;
with System;

procedure Ada.Exceptions.Last_Chance_Handler (Except : Exception_Occurrence) is

   Max_Error_Message_Size : constant := 128;

   --  The length of the exception name.  We have to subtract one
   --  because it is NUL-terminated.
   Exception_Name_Length : constant Integer := Except.Id.Name_Length - 1;

   subtype Error_Message_Size_Type is Integer range
      1 .. Max_Error_Message_Size;

   procedure Stop (ID : Integer := 0)
     with No_Return, Import, Convention => C, External_Name => "exit";

   Message : String (1 .. Max_Error_Message_Size);

   Message_Length : Error_Message_Size_Type;

begin
   if Exception_Name_Length + 25 > Max_Error_Message_Size then
      Message_Length := Max_Error_Message_Size;
   else
      Message_Length := Exception_Name_Length + 25;
   end if;

   Message (1 .. 25) := "Unhandled Ada Exception: ";
   Message (26 .. Message_Length) :=
     To_Ptr (Except.Id.Full_Name) (1 .. Message_Length - 25);

   New_Line;
   Put_Line ("In last chance handler");
   Put_Line (Message (1 .. Message_Length));
   New_Line;

   Put_Line ("Traceback addresses for addr2line:");

   for J in 1 .. Except.Num_Tracebacks loop
      Put (Image_C (Except.Tracebacks (J)));
      Put (" ");
   end loop;

   New_Line;

   Stop;
end Ada.Exceptions.Last_Chance_Handler;
