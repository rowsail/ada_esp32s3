--  Turbo Ada: a Borland Turbo C++ style text-mode IDE for Ada, Alire and the
--  bare-metal ESP32-S3 SDK.
--
--  The layering, bottom up:
--
--    Turbo.Term         raw terminal I/O (the only package that touches C)
--    Turbo.Events       bytes -> key / mouse / paste / resize events
--    Turbo.Screen       a cell buffer, diffed to the terminal on Flush
--    Turbo.Theme        the Turbo C++ 3.0 colour scheme, by role
--    Turbo.Buffers      the text of one file, with undo
--    Turbo.Syntax       per-line highlighting (Ada, GPR, shell/TOML, C)
--    Turbo.Windows      the window base type + frame drawing
--    Turbo.Clipboard    the system clipboard, through its helper program
--    Turbo.Formatter    gnatformat on an editor's text (Edit | Format)
--    Turbo.Editors      the edit window
--    Turbo.Messages     the message window (build output, jump to error)
--    Turbo.Desktop      the window stack, menu bar, status line
--    Turbo.Menus        the pull-down menus
--    Turbo.Dialogs      modal dialogs (find, open file, options, ...)
--    Turbo.Projects     what "the project" is and which commands drive it
--    Turbo.Jobs         background build processes
--    Turbo.Pipes        child processes read line by line (GDB, consoles)
--    Turbo.Console      the board's console for Run and Monitor
--    Turbo.App          the main loop and the command dispatcher
--    Turbo.Script       keys in, screen out: the IDE on a virtual terminal,
--                       for tada-cli

package Turbo is

   pragma Pure;

   Version : constant String := "0.1";

   --  The sixteen CGA colours, in the CGA order (so Blue is 1, as on the
   --  original hardware the colour scheme was designed for).
   type Color is
     (Black, Blue, Green, Cyan, Red, Magenta, Brown, Light_Gray,
      Dark_Gray, Light_Blue, Light_Green, Light_Cyan, Light_Red,
      Light_Magenta, Yellow, White);

   type Attribute is record
      Fg : Color := Light_Gray;
      Bg : Color := Black;
   end record;

   function "/" (Fg, Bg : Color) return Attribute is ((Fg, Bg));
   --  Fg / Bg reads like the attribute it is: Yellow / Blue.

end Turbo;
