--  Scripts for the IDE on a virtual terminal (tada-cli ui): keys in, the
--  screen out, and checks on it, so the real program can be driven from a
--  test or a shell without a terminal.
--
--  One step per line ('#' starts a comment):
--
--    key NAME ...         keys, by name: F8, Ctrl-F9, Alt-X, Shift-Tab,
--                         Enter, Esc, Down, PgDn, Ctrl-K, a, ...
--    type TEXT            the text, as typed (the rest of the line)
--    wait SECONDS         let the IDE run (a debug session, a build)
--    wait-for TEXT [S]    until TEXT is on the screen (default 30 s); the
--                         script fails and stops if it never comes
--    wait-stopped [S]     until a debug session's program has stopped and
--                         the IDE has shown where (default 30 s): after F7,
--                         F8, Ctrl-F9, which return while it still runs
--    expect TEXT          TEXT is on the screen now, else a failure
--    expect-not TEXT      TEXT is not on the screen
--    screen [json]        print the screen: text, or JSON with colours
--    echo TEXT            print TEXT
--    quit                 end here
--
--  Steps run as the IDE asks for input, so each one sees the screen as the
--  previous one left it; a long command (a build, F8 starting a session)
--  finishes before the next step.  While the IDE is busy (a build box, which
--  only looks for Esc) just wait, wait-for, screen, echo and a key Esc run.  The script ends the IDE (Term.Script_
--  Ended) after its last step.

with Turbo.Term;

package Turbo.Script is

   Bad_Step : exception;

   procedure Add (Step : String);
   --  Raises Bad_Step (with the reason) for a step it cannot run.

   procedure Load (File : String);
   --  Every line of File ("-": standard input).

   function Key_Bytes (Name : String) return String;
   --  What a terminal sends for the key; Bad_Step for an unknown name.

   function Key_Names return String;
   --  The names Key_Bytes takes, for tada-cli keys.

   function Source (Buf : out Term.Byte_Array; Timeout_Ms : Integer) return Natural;
   --  The virtual terminal's input (Term.Start_Virtual).

   function Failures return Natural;

   procedure Set_Trace (On : Boolean);
   --  Log each step, and each key handed over, on standard error.

   function Screen_Text return String;
   --  The screen, a line per row (UTF-8, trailing blanks trimmed).

   procedure Put_Screen (Json : Boolean := False);
   --  On standard output.

end Turbo.Script;
