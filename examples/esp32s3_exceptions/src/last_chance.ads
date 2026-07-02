with Ada.Exceptions;

--  A custom last-chance handler (LCH) for this demo.  The runtime's default LCH
--  reports the exception through System.IO and resets the chip; on the bare boot
--  System.IO does not reach the console and a reset would loop the demo forever.
--  By exporting our own under the C symbol the compiler calls for an unhandled
--  exception (__gnat_last_chance_handler), the runtime's version is not linked,
--  and we instead print the exception over the ROM console and halt -- so step
--  [4] of the demo is visible and the board does not reset.

package Last_Chance is

   procedure Handler (Except : Ada.Exceptions.Exception_Occurrence);
   pragma Export (C, Handler, "__gnat_last_chance_handler");
   pragma No_Return (Handler);

end Last_Chance;
