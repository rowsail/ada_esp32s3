--  The clipboard: the system's, so Cut, Copy and Paste work with other
--  programs.  It is reached through the helper the desktop provides:
--  wl-copy/wl-paste on Wayland, xclip or xsel on X11, pbcopy/pbpaste on
--  macOS, PowerShell on Windows and WSL.  Copies also go to the terminal
--  with OSC 52, which reaches the local clipboard over ssh in terminals
--  that allow it (xterm, kitty, WezTerm, iTerm2, Windows Terminal, tmux
--  with set-clipboard on).  A copy is kept inside the IDE as well, for
--  when there is no helper or it fails.

package Turbo.Clipboard is

   procedure Configure (Copy_Command, Paste_Command : String);
   --  Shell commands: Copy_Command reads the text on its standard input,
   --  Paste_Command writes it on its standard output.  "" or "auto": found
   --  from the environment, as above; "none": the IDE's own clipboard only.
   --  On a virtual terminal (tada-cli) "auto" means none, so a script never
   --  touches the user's clipboard.  Until this is called: none.

   procedure Set (Text : Wide_Wide_String);
   function Get return Wide_Wide_String;
   --  The system clipboard's text when there is some, else the last Set.

   function Is_Empty return Boolean;
   --  Nothing to paste: no text Set, and no system clipboard to look in.

   function Helper return String;
   --  The program used for the system clipboard ("xclip", ...), or "".

end Turbo.Clipboard;
