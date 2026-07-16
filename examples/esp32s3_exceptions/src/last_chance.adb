with Ada.Exceptions; use Ada.Exceptions;
with System;

package body Last_Chance is

   --  Print over the ROM console directly (was exceptions/glue.c's
   --  native_exc_puts).  The last-chance handler runs in the fragile state just
   --  after an exception has escaped everything, where the ROM esp_rom_printf is
   --  always available -- so it is used here rather than the buffered console.
   procedure Rom_Printf (Fmt, S : System.Address);
   pragma Import (C, Rom_Printf, "esp_rom_printf");

   Line_Fmt : constant String := "%s" & ASCII.LF & ASCII.NUL;

   procedure Handler (Except : Exception_Occurrence) is
      Line : constant String :=
        "*** LAST CHANCE HANDLER: unhandled "
        & Exception_Name (Except)
        & " -- "
        & Exception_Message (Except)
        & " ***"
        & ASCII.NUL;
   begin
      Rom_Printf (Line_Fmt'Address, Line'Address);
      --  An unhandled exception is fatal: halt (the default LCH would reset).
      loop
         null;
      end loop;
   end Handler;

end Last_Chance;
