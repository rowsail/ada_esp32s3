--  The clipboard.  Kept inside the IDE (so it works everywhere), and also
--  offered to the terminal with OSC 52, so a copy can be pasted into other
--  programs when the terminal supports it (xterm, kitty, WezTerm, iTerm2,
--  Windows Terminal, tmux with set-clipboard on).

package Turbo.Clipboard is

   procedure Set (Text : Wide_Wide_String);
   function Get return Wide_Wide_String;
   function Is_Empty return Boolean;

end Turbo.Clipboard;
