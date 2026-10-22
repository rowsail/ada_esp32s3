--  The console of a program run without the debugger (Run, Monitor): the
--  board's serial output, read by a child process (a cat of the port) for
--  the Output window, so the IDE stays on screen while the program runs.
--
--  Pausing holds the lines back from the window, not the reader: a board
--  printing over USB-Serial/JTAG stalls when nobody reads its output, and a
--  UART's lines would be lost.

with Turbo.Pipes;

package Turbo.Console is

   procedure Start (Command, Dir : String; Ok : out Boolean; Whole_Group : Boolean := False);
   --  Run Command through the shell in Dir; what it prints is the console.
   --  Any console already running is stopped first.  Whole_Group: Stop
   --  ends what the command started too (a program run here, not a cat
   --  of the board's port).

   function Running return Boolean;
   --  Started and not stopped (the reader may have ended by itself: Ended).

   function Ended return Boolean;
   --  It ran and its output has all been taken: the port went away, or
   --  the command failed.

   procedure Stop;

   procedure Set_Paused (Paused : Boolean);
   function Paused return Boolean;

   function Held return Natural;
   --  Lines read while paused, not yet taken.

   function Take return Turbo.Pipes.Line_Vectors.Vector;
   --  The lines since the last call (none while paused), escape sequences
   --  removed and tabs expanded.

end Turbo.Console;
