--  Background jobs: a build (or any captured command) running while the IDE
--  stays live, its output collected line by line for the message window.
--
--  One job at a time, like Turbo C++.  The output goes to a temporary file
--  that is read as it grows, which works the same on every platform GNAT
--  supports (no pipes, no ptys).

with Turbo.Dialogs;

package Turbo.Jobs is

   procedure Start (Command, Dir : String; Ok : out Boolean);
   --  Run Command through the shell in Dir.

   function Running return Boolean;

   procedure Poll (Lines : out Turbo.Dialogs.String_List; Finished : out Boolean);
   --  The complete output lines that arrived since the last Poll (UTF-8,
   --  escape sequences and carriage-return overprinting removed).  Finished
   --  is True once, when the process has ended and all its output has been
   --  returned.

   function Succeeded return Boolean;
   --  After Finished: did the command exit with status 0?

   procedure Cancel;
   --  Kill the job and everything it started.

   function Elapsed return Duration;

   procedure Run_Foreground
     (Command, Dir : String; Success : out Boolean);
   --  Run Command with the terminal (the serial monitor, GDB, a shell): the
   --  IDE steps aside, then waits for a key so the output can be read.

end Turbo.Jobs;
