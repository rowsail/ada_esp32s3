--  gnatformat, AdaCore's Ada formatter, run on an editor's text: Edit |
--  Format when the language server (which formats with its own copy) is
--  not running.  The text goes through a temporary file, so what is
--  formatted is what is on screen, saved or not.
--
--  It runs without the project (--no-project): a cross project's toolchain
--  need not be there, and gnatformat would print its complaints about one
--  among the code.  So the project's Format package is not read; the
--  language server's formatting reads it.

with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Turbo.Buffers;

package Turbo.Formatter is

   function Program return String;
   --  gnatformat on PATH or in ~/.alire/bin (where alr install puts it),
   --  or "" (or no shell to run it with).

   type Result is record
      Ok       : Boolean := False;
      Error    : Ada.Strings.Unbounded.Unbounded_String;   --  why not, when not Ok
      From, To : Turbo.Buffers.Position;                   --  what Text replaces (To excluded)
      Text     : Ada.Strings.Wide_Wide_Unbounded.Unbounded_Wide_Wide_String;
   end record;

   procedure Format
     (Name     : String;
      Text     : Wide_Wide_String;
      Whole    : Boolean;
      From, To : Turbo.Buffers.Position;
      R        : out Result);
   --  Text is a file's (Name: its simple name, which tells a spec from a
   --  body), lines separated by LF.  Whole: all of it, else the selection
   --  From .. To, which gnatformat widens to the constructs it touches.

end Turbo.Formatter;
