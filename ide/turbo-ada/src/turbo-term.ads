--  Raw terminal I/O.  A thin Ada face on src/term_c.c, plus the escape
--  sequences that put an xterm-compatible terminal into "full screen
--  application" mode and back.

package Turbo.Term is

   type Byte_Array is array (Positive range <>) of Character;

   Not_A_Terminal : exception;

   procedure Start;
   --  Raw mode, alternate screen, mouse reporting, bracketed paste.
   --  Raises Not_A_Terminal when stdin/stdout is not a usable console.

   procedure Stop;
   --  Undo Start: the user's shell screen comes back exactly as it was.

   procedure Suspend renames Stop;
   procedure Resume renames Start;
   --  Around a foreground child (a shell, the serial monitor, GDB).

   procedure Wait_Key;
   --  While suspended: one key press, raw, without taking the screen back.

   procedure Show_User_Screen;
   --  Alt-F5: show the shell screen (what the last foreground program
   --  printed) until a key is pressed.

   function Read (Buf : out Byte_Array; Timeout_Ms : Integer) return Natural;
   --  Up to Buf'Length bytes; 0 on timeout.  A negative timeout blocks.

   procedure Write (S : String);
   --  S is already UTF-8 / escape sequences: written as-is.

   procedure Size (Rows, Cols : out Positive);

   function Take_Resized return Boolean;
   --  True once after the terminal changed size.

   function Is_Windows return Boolean;

   function Is_Active return Boolean;

   --  A virtual terminal, for tada-cli: no console is touched.  Output is
   --  dropped (the screen is read from Turbo.Screen instead), the size is
   --  fixed, and input comes from Source, which a script drives.

   type Input_Source is access function
     (Buf : out Byte_Array; Timeout_Ms : Integer) return Natural;

   procedure Start_Virtual (Rows, Cols : Positive; Source : not null Input_Source);
   --  Then Start, Stop and the rest work on the virtual terminal.

   function Is_Virtual return Boolean;

   procedure Set_Polling (On : Boolean);
   function Polling return Boolean;
   --  Around a read that only looks for Esc (a build, a busy box): a script
   --  holds back its other keys meanwhile (Turbo.Events.Poll).

   Script_Ended : exception;
   --  Raised by a Source when its script is done: the application leaves
   --  its main loop (from inside a dialog too) and lets it through.

end Turbo.Term;
