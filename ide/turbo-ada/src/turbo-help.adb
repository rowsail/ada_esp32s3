package body Turbo.Help is

   LF : constant Character := Character'Val (10);

   function Contents return String is
     ("# Turbo Ada " & Version & LF
      & LF
      & "A text-mode IDE in the style of Borland Turbo C++ 3.0, for Ada" & LF
      & "projects built with Alire and for the bare-metal ESP32-S3 SDK." & LF
      & LF
      & "# Getting around" & LF
      & "  {F10}           the menu bar (or {Alt} + the red letter)" & LF
      & "  {F1}            this help        {Alt-X}   exit" & LF
      & "  {F3}            open a file      {F2}      save it" & LF
      & "  {F6}            next window      {F5}      zoom it" & LF
      & "  {Alt-1..9}      window by number {Alt-0}   window list" & LF
      & "  {Ctrl-F5}       move/size the window with the arrow keys" & LF
      & "  The mouse works too: menus, close and zoom boxes, title bars," & LF
      & "  the resize corner, scroll bars, and click-drag to select." & LF
      & LF
      & "# Building" & LF
      & "  {F9}            Make: build the project, errors to the Message" & LF
      & "                  window.  Enter on a message jumps to the line." & LF
      & "  {Alt-F8}        next error     {Alt-F7}  previous error" & LF
      & "  {Ctrl-F9}       Run: make, then flash and open the serial monitor" & LF
      & "  {Shift-F9}      Flash          {Alt-F9}  Monitor" & LF
      & "  {Ctrl-F8}       Debug: OpenOCD + GDB on the board" & LF
      & "  {Alt-F5}        User screen: what the last program printed" & LF
      & "  {Esc}           in the Compiling box: cancel the build" & LF
      & LF
      & "  The commands come from the project: ./x for an SDK example," & LF
      & "  esp32-ada for a standalone project, alr for any other Alire" & LF
      & "  crate.  See Help | Project commands, and Options | Commands" & LF
      & "  to change them." & LF
      & LF
      & "# More" & LF
      & "  Help | Keyboard lists every editor key.");

   function Keys return String is
     ("# Cursor movement" & LF
      & "  {Arrows} {PgUp} {PgDn}     as expected" & LF
      & "  {Home} / {End}             line start (first non-blank) / end" & LF
      & "  {Ctrl-Left/Right}          word left / right" & LF
      & "  {Ctrl-PgUp/PgDn}           top / bottom of file" & LF
      & "  {Ctrl-Home/End}            top / bottom of file" & LF
      & "  {Ctrl-Up/Down}             scroll without moving the cursor" & LF
      & "  {Ctrl-G}                   go to line number" & LF
      & "  {Ctrl-Q R} / {Ctrl-Q C}    top / bottom of file (WordStar)" & LF
      & "  {Ctrl-Q E} / {Ctrl-Q X}    top / bottom of window" & LF
      & LF
      & "# Editing" & LF
      & "  {Ins}                      insert / overwrite" & LF
      & "  {Tab} / {Shift-Tab}        indent / outdent (a whole block" & LF
      & "                             when lines are selected)" & LF
      & "  {Ctrl-Y}                   delete line" & LF
      & "  {Ctrl-Q Y}                 delete to end of line" & LF
      & "  {Ctrl-T}                   delete word right" & LF
      & "  {Ctrl-BkSp}                delete word left" & LF
      & "  {Alt-BkSp} / {Ctrl-Z}      undo" & LF
      & "  {Shift-Alt-BkSp}           redo" & LF
      & "  Enter auto-indents, one level deeper after an Ada line that" & LF
      & "  opens a block (is, then, loop, begin, record, ...)." & LF
      & LF
      & "# Blocks and the clipboard" & LF
      & "  {Shift}+movement or a mouse drag selects; a double click" & LF
      & "  selects a word." & LF
      & "  {Shift-Del} {Ctrl-X}       cut" & LF
      & "  {Ctrl-Ins} {Ctrl-C}        copy" & LF
      & "  {Shift-Ins} {Ctrl-V}       paste" & LF
      & "  {Ctrl-Del}                 clear" & LF
      & "  {Ctrl-A}                   select all" & LF
      & "  {Ctrl-K B} / {Ctrl-K K}    mark block begin / end (persistent)" & LF
      & "  {Ctrl-K C} / {Ctrl-K V}    copy / move the block to the cursor" & LF
      & "  {Ctrl-K Y} / {Ctrl-K H}    delete / hide the block" & LF
      & "  {Ctrl-K I} / {Ctrl-K U}    indent / outdent the block" & LF
      & "  Copies also go to the terminal's clipboard (OSC 52) where the" & LF
      & "  terminal allows it." & LF
      & LF
      & "# Search" & LF
      & "  {Ctrl-Q F} {Ctrl-F}        find" & LF
      & "  {Ctrl-Q A} {Ctrl-R}        replace" & LF
      & "  {Ctrl-L} {F3 in a find}    search again" & LF
      & "  {Ctrl-F6}                  switch between spec and body" & LF
      & "  {Ctrl-F1}                  grep the word at the cursor in the project" & LF
      & LF
      & "# Dialogs" & LF
      & "  {Tab} / {Shift-Tab}        next / previous control" & LF
      & "  {Alt}+letter               the control with that red/yellow letter" & LF
      & "  {Space}                    toggle a check box, press a button" & LF
      & "  {Enter} / {Esc}            OK / Cancel");

   function Project_Commands return String is
     ("# Which tool runs" & LF
      & "Turbo Ada looks up from the directory it was started in:" & LF
      & LF
      & "  {SDK example}   inside the ada_esp32s3 repository: ./x <verb>" & LF
      & "                  <example>.  Started inside examples/<name>, that" & LF
      & "                  example is chosen; otherwise pick one with" & LF
      & "                  Project | Open project." & LF
      & "  {Standalone}    a directory with build.sh + app.gpr (made by" & LF
      & "                  esp32-ada init): esp32-ada <verb>." & LF
      & "  {Alire crate}   any other alire.toml: alr build / alr run /" & LF
      & "                  alr test / alr clean." & LF
      & LF
      & "# Templates" & LF
      & "Each command is a template (Options | Commands).  In them:" & LF
      & LF
      & "  {{example}}      the chosen SDK example" & LF
      & "  {{port_opt}}     ' -p PORT' when a port is set, else nothing" & LF
      & "  {{profile_opt}}  ' -P PROFILE' when a profile is set" & LF
      & "  {{port}} {{profile}} {{dir}} {{root}} {{file}}" & LF
      & LF
      & "Commands run through /bin/sh -c (on Windows: bash -c when bash" & LF
      & "is on PATH, as it is under MSYS2 or Git Bash; cmd /c otherwise)" & LF
      & "in the SDK root or the project directory." & LF
      & LF
      & "# Interactive commands" & LF
      & "Run, Monitor and Debug take over the terminal: Turbo Ada steps" & LF
      & "aside and comes back when they exit (Ctrl-] leaves miniterm)." & LF
      & "Alt-F5 shows their output again afterwards." & LF
      & LF
      & "# Options file" & LF
      & "Options | Save options writes .turbo_ada in the SDK root or the" & LF
      & "project directory: the example, port, profile, any changed" & LF
      & "command, editor settings and the open files.  Exit saves the" & LF
      & "open files there too, so the desktop comes back next time.");

   function About return String is
     ("Turbo Ada" & LF
      & LF
      & "Version " & Version & LF
      & LF
      & "A Turbo C++ style IDE for Ada," & LF
      & "Alire and the ESP32-S3.");

end Turbo.Help;
