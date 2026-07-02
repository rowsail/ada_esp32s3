with Ada.Exceptions; use Ada.Exceptions;
with System;

package body Last_Chance is

   --  Print a NUL-terminated C string over the ROM console (glue.c).
   procedure Put_C (S : System.Address);
   pragma Import (C, Put_C, "native_exc_puts");

   procedure Handler (Except : Exception_Occurrence) is
      Line : constant String :=
        "*** LAST CHANCE HANDLER: unhandled "
        & Exception_Name (Except)
        & " -- "
        & Exception_Message (Except)
        & " ***"
        & ASCII.NUL;
   begin
      Put_C (Line'Address);
      --  An unhandled exception is fatal: halt (the default LCH would reset).
      loop
         null;
      end loop;
   end Handler;

end Last_Chance;
