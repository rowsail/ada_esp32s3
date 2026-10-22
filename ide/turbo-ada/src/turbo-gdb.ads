--  The debugger: OpenOCD and GDB as child processes, GDB driven through its
--  machine interface (GDB/MI), so the IDE stays on screen while it steps.
--
--  On the board, three processes, each with a reader task queueing its
--  output lines:
--
--    the server   OpenOCD, from the SDK (./x debug-server, esp32-ada's): it
--                 owns the board's USB/JTAG and listens for GDB on :3333
--    GDB          --interpreter=mi3 on the ELF; commands go to its stdin with
--                 a token, and the reply that carries the token answers them
--    the console  the board's serial output (it must be read: an app that
--                 prints over USB-Serial/JTAG stalls when nobody does)
--
--  A native program needs only GDB (the system's gdb): it runs the program
--  on a pseudo-terminal whose output is read as the console's would be.
--
--  MI records are turned into JSON text (MI_To_JSON) and read with
--  Turbo.JSON, the reader the language server already uses.

with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Turbo.JSON;

package Turbo.GDB is

   type Session_State is (Off, Stopped, Running, Failed);
   --  Off: no session.  Stopped / Running: the target, as GDB last said.

   function State return Session_State;
   function Is_Active return Boolean is (State in Stopped | Running);

   function Last_Error return String;

   --  Lifetime

   procedure Start_Server (Command, Dir : String; Ok : out Boolean;
                           Timeout : Duration := 20.0);
   --  Run Command (through the shell, in Dir) and wait for it to listen for
   --  GDB.  On failure Last_Error has the server's last words.

   procedure Start (Gdb, Elf, Dir : String; Ok : out Boolean);
   --  Spawn GDB on Elf and connect it to the server (extended-remote :3333).
   --  The target is left as it was (running); the caller resets it.

   procedure Start_Native (Gdb, Exe, Dir : String; Ok : out Boolean);
   --  Spawn GDB on a native program, its output (on a pseudo-terminal, where
   --  there is one) for Take_Console.  The program is not started: the
   --  caller runs it (-exec-run).

   function Is_Native return Boolean;

   procedure Reset_Halt (Ok : out Boolean);
   --  Reset the board and hold it at the reset vector, for a fresh run.

   procedure Start_Console (Command, Dir : String);
   --  Read the board's console (Command prints it on stdout, e.g. a cat of
   --  the port) for Take_Console.

   procedure Stop;
   --  Leave the board running (reset, detach), or end a native program;
   --  quit GDB, stop the server and the console reader.  Safe to call at
   --  any time.

   --  Commands

   type Result is tagged limited record
      Doc   : Turbo.JSON.Document;
      Value : Turbo.JSON.Value := Turbo.JSON.No_Value;   --  the results, an object
      Class : Ada.Strings.Unbounded.Unbounded_String;    --  done, running, error, ...
      Ok    : Boolean := False;
      Error : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   procedure Command (Text : String; R : in out Result; Timeout : Duration := 10.0);
   --  Send an MI command and wait for its reply.  R.Ok is False on ^error,
   --  a timeout, or a dead GDB (R.Error says which).  Async records that
   --  arrive meanwhile are kept for Poll.

   procedure Command (Text : String; Ok : out Boolean; Timeout : Duration := 10.0);

   procedure Console_Command (Text : String; Output : out Ada.Strings.Unbounded.Unbounded_String;
                              Ok : out Boolean; Timeout : Duration := 10.0);
   --  A CLI command (-interpreter-exec console), with what it printed.

   --  Events

   type Stop_Info is record
      Reason   : Ada.Strings.Unbounded.Unbounded_String;  --  breakpoint-hit, end-stepping-range,
                                                          --  exited-normally, exited, ...
      File     : Ada.Strings.Unbounded.Unbounded_String;  --  full path; "" when no source
      Line     : Natural := 0;
      Func     : Ada.Strings.Unbounded.Unbounded_String;
      Addr     : Ada.Strings.Unbounded.Unbounded_String;
      Detail   : Ada.Strings.Unbounded.Unbounded_String;  --  a signal's meaning, an exit code
      Thread   : Ada.Strings.Unbounded.Unbounded_String;  --  GDB's thread-id; on the board, a core
   end record;

   procedure Poll;
   --  Take in what GDB, the server and the console sent.

   function Take_Stop (S : out Stop_Info) return Boolean;
   --  True once for each stop of the target (with where).  On the board
   --  (both cores as GDB threads) the end of a step that GDB put on core 1
   --  is moved to core 0: the steps are core 0's, and core 1 is mostly idle.

   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   function Take_Console return String_Vectors.Vector;
   --  The board's console lines since the last call.

   function Quote (S : String) return String;
   --  S as an MI c-string argument.

   --  MI text (exposed for the host tests)

   function MI_To_JSON (Results : String) return String;
   --  "a=\"1\",b={c=[\"x\",\"y\"]}" -> {"a":"1","b":{"c":["x","y"]}}.
   --  A list of results ([frame={..},frame={..}]) becomes an array of the
   --  values.  C escapes are decoded, octal ones included.

   function C_String (Text : String) return String;
   --  The contents of an MI c-string ("..." with escapes), decoded.

end Turbo.GDB;
