--  Child processes read line by line: a reader task queues what the
--  process prints (stdout and stderr together) for the IDE to take when it
--  polls.  Used by the debugger (GDB, OpenOCD, the board's console) and by
--  the console of a program run without it (Turbo.Console).

with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with GNAT.Expect;
with GNAT.OS_Lib;

package Turbo.Pipes is

   use Ada.Strings.Unbounded;

   package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   protected type Line_Queue is
      procedure Put (Line : String);
      procedure Take (Line : out Unbounded_String; Found : out Boolean);
      procedure Set_Closed (Closed : Boolean);
      function Closed return Boolean;
      --  The reader has seen the end of the output (and queued it all).
      procedure Clear;
   private
      Queue     : Line_Vectors.Vector;
      Is_Closed : Boolean := True;
   end Line_Queue;

   task type Line_Reader (Q : not null access Line_Queue) is
      entry Start (Fd : GNAT.OS_Lib.File_Descriptor);
      --  Read Fd to its end into Q, then wait for the next Start.
   end Line_Reader;

   procedure Spawn (P : in out GNAT.Expect.Process_Descriptor; Q : in out Line_Queue;
                    Reader : in out Line_Reader; Program : String;
                    Args : GNAT.OS_Lib.Argument_List; Ok : out Boolean);

   procedure Kill (P : in out GNAT.Expect.Process_Descriptor; Q : in out Line_Queue;
                   Up : in out Boolean; Grace : Duration);
   --  Wait Grace for it to end by itself, then SIGTERM, then SIGKILL.

   function Shell_Quote (S : String) return String;
   --  S as one word for /bin/sh.

end Turbo.Pipes;
