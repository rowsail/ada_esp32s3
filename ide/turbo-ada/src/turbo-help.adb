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
      & "  {Alt-F9}        Compile: check this file with the compiler (about a" & LF
      & "                  second; nothing is built or linked)" & LF
      & "  {F9}            Make: build the project, errors to the Message" & LF
      & "                  window.  Enter on a message jumps to the line." & LF
      & "  {Alt-F8}        next error     {Alt-F7}  previous error" & LF
      & "  {Ctrl-F9}       Run: make and flash, then the board's console in" & LF
      & "                  the Output window (Run | Monitor: the console alone)" & LF
      & "  {Shift-F2}      pause the Output window (or Space in it); again resumes" & LF
      & "  {Esc}           stop reading the console (or Ctrl-F2; the board runs on)" & LF
      & "  {Shift-F9}      Flash" & LF
      & "  {Alt-F5}        User screen: what the last program printed" & LF
      & "  {Esc}           in the Compiling box: cancel the build" & LF
      & LF
      & "# Debugging (as in Turbo C++)" & LF
      & "  {F7}            Trace into     {F8}  Step over" & LF
      & "  {F4}            Go to cursor   {Ctrl-F9}  Run on to a breakpoint" & LF
      & "  {Ctrl-F8}       Toggle breakpoint (a red line; kept with the project)" & LF
      & "  {Ctrl-F2}       Program reset: end the session, the board runs on" & LF
      & "  {Ctrl-F7}       Add watch (Window | Watch; Ins, Enter, Del in it)" & LF
      & "  {Ctrl-F4}       Evaluate/modify     {Alt-F4}   Inspect" & LF
      & "  {Ctrl-F3}       Call stack          {Alt-F5}   the program's output" & LF
      & "  With no session, F7, F8 and F4 build, flash and start one: OpenOCD" & LF
      & "  and GDB, the board reset and run to the Ada main (or the cursor)." & LF
      & "  A native program (an Alire crate, a host test suite) is made and" & LF
      & "  run under the system's gdb instead; Ctrl-F2 ends it." & LF
      & "  The cyan bar is where it stopped; while it runs, F7/F8/F4 pause" & LF
      & "  it.  Run | GDB console is the plain GDB prompt." & LF
      & LF
      & "  The commands come from the project: ./x for an SDK example," & LF
      & "  esp32-ada for a standalone project, alr for any other Alire" & LF
      & "  crate.  See Help | Project commands, and Options | Commands" & LF
      & "  to change them." & LF
      & LF
      & "# The Ada Language Server" & LF
      & "  When ada_language_server is installed (Project | Install tool," & LF
      & "  or the VS Code Ada extension), errors show" & LF
      & "  as you type, in red, with the message on the status line, and:" & LF
      & "  {F12}           go to the definition   {Alt-F12}   go back" & LF
      & "  {Shift-F12}     find uses              {Ctrl-F12}  symbol list" & LF
      & "  {Ctrl-Space}    complete the word      {Ctrl-F1}   help on it" & LF
      & "  Search | Rename symbol, Search | Diagnostics.  Options |" & LF
      & "  Language server turns it off or names the program." & LF
      & LF
      & "# Alire" & LF
      & "  The Project menu searches the crate index, gets a crate into a" & LF
      & "  directory and opens it, installs tools, and adds dependencies" & LF
      & "  to this project.  With no alr on PATH, Turbo Ada offers to" & LF
      & "  download it from GitHub (Project | Fetch Alire does it any" & LF
      & "  time), and that alr fetches the toolchain and everything else." & LF
      & "  Set up ESP32-S3 toolchain gets the validated cross GNAT, native" & LF
      & "  GNAT and gprbuild and builds the xtensa-dynconfig plugin; the" & LF
      & "  first build of an SDK project checks for them and offers it." & LF
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
      & "  Edit | Format lays out the selection, or the whole file, the" & LF
      & "  way gnatformat does: the language server's (with the project's" & LF
      & "  Format settings) when it runs, else gnatformat itself (Project |" & LF
      & "  Set up ESP32-S3 toolchain installs it).  A selection grows to" & LF
      & "  the statements or declarations it touches.  Alt-BkSp undoes it." & LF
      & "  Cut, copy and paste use the system clipboard (wl-copy, xclip or" & LF
      & "  xsel, pbcopy, PowerShell), in the editor and in dialog fields." & LF
      & "  Copies also go to the terminal (OSC 52), which reaches your own" & LF
      & "  desktop over ssh where the terminal allows it.  Project | Set up" & LF
      & "  ESP32-S3 toolchain offers to install a helper if there is none;" & LF
      & "  others go in .turbo_ada as clipboard.copy= and clipboard.paste=." & LF
      & LF
      & "# Search" & LF
      & "  {Ctrl-Q F} {Ctrl-F}        find" & LF
      & "  {Ctrl-Q A} {Ctrl-R}        replace" & LF
      & "  {Ctrl-L} {F3 in a find}    search again" & LF
      & "  {Ctrl-F6}                  switch between spec and body" & LF
      & "  Search | Grep              the word at the cursor, in the project" & LF
      & LF
      & "# With the language server" & LF
      & "  {F12} / {Alt-F12}          go to definition / go back" & LF
      & "  {Shift-F12}                find uses (into the Message window)" & LF
      & "  {Ctrl-F12}                 symbols in this file" & LF
      & "  {Ctrl-Space}               complete: keep typing to narrow," & LF
      & "                             Enter or Tab to take it, Esc to leave" & LF
      & "  {Ctrl-F1}                  help on the word at the cursor" & LF
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
      & "# Native and ESP32-S3" & LF
      & "The target follows the project.  SDK examples and esp32-ada" & LF
      & "projects build for the ESP32-S3.  The libraries' host test suites" & LF
      & "(libs/<lib>/test/<suite>, listed after the examples in Project |" & LF
      & "Open project) and Alire crates build natively, for this machine:" & LF
      & "F9 runs ./x test host <suite>, Ctrl-F9 its run.sh, and Alt-F9 and" & LF
      & "the language server use the native compiler." & LF
      & LF
      & "# Templates" & LF
      & "Each command is a template (Options | Commands).  In them:" & LF
      & LF
      & "  {{example}}      the chosen SDK example" & LF
      & "  {{port_opt}}     ' -p PORT' when a port is set, else nothing" & LF
      & "  {{console_opt}}  ' -c CONSOLE' when a console is set" & LF
      & "  {{profile_opt}}  ' -P PROFILE' when a profile is set" & LF
      & "  {{port}} {{console}} {{profile}} {{dir}} {{root}} {{file}}" & LF
      & LF
      & "Commands run through /bin/sh -c (on Windows: bash -c when bash" & LF
      & "is on PATH, as it is under MSYS2 or Git Bash; cmd /c otherwise)" & LF
      & "in the SDK root or the project directory." & LF
      & LF
      & "# What the IDE reads back" & LF
      & "Builds run as ./x --machine (esp32-ada --machine), which marks" & LF
      & "stages, diagnostics with full paths, and the files made, so the" & LF
      & "Compiling box and the Message window need no guessing." & LF
      & "{{tmp}} {{gpr}}: the scratch tree and project file Compile uses." & LF
      & "The Environment command (./x env, esp32-ada env, alr printenv)" & LF
      & "gives Compile and the language server the toolchain and project" & LF
      & "paths; it never leaks into the build commands, which set up their" & LF
      & "own." & LF
      & LF
      & "# Interactive commands" & LF
      & "On the board, Run and Monitor read its console into the Output" & LF
      & "window, keeping the last 10000 lines.  Paused, the window stands" & LF
      & "still (to scroll back) while the console is still read, so" & LF
      & "nothing is lost and the board never waits; resuming adds what" & LF
      & "came meanwhile.  Run for a native program, and Run | GDB console," & LF
      & "take over the terminal: Turbo Ada steps aside and comes back when" & LF
      & "they exit.  Alt-F5 shows their output again afterwards." & LF
      & LF
      & "# Desktop shortcuts" & LF
      & "A desktop may keep some keys for itself: KDE switches desktops" & LF
      & "with Ctrl-F1..F4 and shows its windows on Ctrl-F9, so the IDE" & LF
      & "never sees them.  Use the menu (Alt-R R runs, Alt-R P resets)," & LF
      & "Esc to stop the console, or free the keys in System Settings |" & LF
      & "Shortcuts (KWin: Switch to Desktop N, Toggle Present Windows)." & LF
      & "The debugger keys (F7, F8, ...) keep the IDE on screen." & LF
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
