# Turbo Ada — a Turbo C++ style IDE for Ada, Alire and the ESP32-S3

The Borland Turbo C++ 3.0 IDE, redone in Ada for this SDK: the blue edit
windows, the dotted desktop, the gray menu bar with red hot letters, the green
buttons with their drop shadows, the cyan message window, the "Compiling" box
that ends in *Success: Press any key* — and the keys your fingers remember
(F9 make, Ctrl-F9 run, Alt-F8 next error, F10 menu, Alt-X exit).

```
  ≡  File  Edit  Search  Run  Compile  Project  Options  Window  Help
╔═[■]═══════════ ../examples/esp32s3_gpio0_blink/src/main.adb ════════1══[↑]═╗
║procedure Main is                                                           ▲
║begin                                                                       ■
║   loop                                                                     ░
║      delay until Clock + Seconds (3600);                                   ░
║   end loop;                                                                ░
║end Main;     ╔═══════════════════════ Make ════════════════════════╗       ░
║              ║                                                     ║       ░
║              ║  Main file:  gpio0_blink                            ║       ░
║              ║  Command:    ./x build gpio0_blink                  ║       ░
║              ║  Compiling:  main.adb                               ║       ░
║              ║                     Total                           ║       ░
║              ║  Lines output:      31          Elapsed: 9.4 s      ║       ░
║              ║      Warnings:      0                               ║       ░
║              ║        Errors:      0                               ║       ░
║              ║                                                     ║       ░
║              ║            Success   :   Press any key              ║       ▼
╚══ 1:1 ═══════╚═════════════════════════════════════════════════════╝══════►─┘
 F1 Help  F2 Save  F3 Open  F9 Make  Ctrl-F9 Run  Alt-F9 Compile  F10 Menu
```

It is a native program written in Ada (no curses; the only C is a small
raw-terminal shim), and it adds **no build logic of its own**: like the VS Code
and Vim integrations it drives the commands that already know how to build
each kind of project.

| Project (found from the directory you start in) | Target | Build / run / flash with |
|---|---|---|
| an example inside this SDK repository | ESP32-S3 | `./x build <example>`, `./x run`, `./x flash`, ... |
| a library's host test suite (`libs/<lib>/test/<suite>`) | native | `./x test host <suite>`; Run is its `run.sh` |
| a standalone project (`esp32-ada init`: `build.sh` + `app.gpr`) | ESP32-S3 | `esp32-ada build`, `run`, `flash`, ... |
| any other Alire crate (`alire.toml`) | native | `alr build`, `alr run`, `alr test`, `alr clean` |

The target follows the project, so there is nothing to switch: Project | Open
project in the SDK lists the examples (ESP32-S3) and the host test suites
(native) together, and the status line shows which is open. Native means code
written to run on this machine: a firmware example cannot be built natively,
since it uses the bare-metal runtime (`System.BB`), but the libraries' logic
is built and run natively exactly as their host tests already do, with
Alt-F9, the language server and go-to-definition into the HAL all working
against the native toolchain.

Compile (Alt-F9) and the language server also need the project's compile
environment — the toolchain on `PATH`, `GPR_PROJECT_PATH`, the xtensa core
plugin — which they get from `./x env <example>`, `esp32-ada env` or
`alr printenv` respectively, without running a build.

## Running it

From the SDK (built on first use with the native GNAT that `./x` already uses):

```sh
./x turbo                     # on the SDK: Project | Open project picks an example
./x turbo gpio0_blink         # straight into an example
esp32-ada turbo               # in a standalone esp32-ada project
```

As an ordinary Alire crate, anywhere:

```sh
cd ide/turbo-ada
alr build                     # -> bin/tada
alr install                   # optional: puts tada in ~/.alire/bin
tada [-C DIR] [FILE...]       # in any Alire crate or esp32-ada project
```

For the language-server features, install the server once: Project | Install
tool (`ada_language_server` is the default), or from a shell

```sh
alr install ada_language_server      # or have the VS Code "Ada & SPARK" extension
```

Alire itself is not a prerequisite. When something needs `alr` and there is
none, Turbo Ada offers to download the latest release for this machine from
GitHub (curl or wget, then unzip or python3) into
`~/.local/share/turbo-ada/alire/bin` (`$TURBO_ADA_ALIRE` moves it) and puts
that directory first on `PATH` for itself and everything it runs. From then on
that `alr` fetches everything else: crates, dependencies, the GNAT toolchain,
the language server.

It needs a terminal at least 80×25 that speaks xterm escape sequences: any
Linux or macOS terminal, tmux/screen, or on Windows the Windows Terminal or
the Windows 10 (1809+) console. Mouse and bracketed paste are used when the
terminal offers them. Colours follow the terminal's palette; with
`COLORTERM=truecolor` (or Options | Editor) they are the exact CGA ones, so
brown is brown.

## What's in it

- **Editor** — any number of windows, Ada syntax colouring (plus GPR, shell,
  TOML and C), auto-indent that steps in after `is`/`then`/`loop`/`begin`,
  undo/redo, Shift-select and mouse select, the WordStar Ctrl-K/Ctrl-Q block
  and cursor commands, Find/Replace with the Turbo options dialog, Go to line,
  spec/body switching (Ctrl-F6), Grep the word under the cursor across the
  project (Search | Grep).
- **Format** — Edit | Format lays out the selection (widened to the
  statements or declarations it touches) or the whole file with AdaCore's
  gnatformat rules: through the language server when it runs, which reads
  the project's `Format` package and formats the unsaved text, else by
  running `gnatformat` itself (on `PATH` or in `~/.alire/bin`, without the
  project). `./x setup-toolchain` installs it (`alr install gnatformat_bin`;
  `./x setup-formatter` alone). One undo step takes it back. Shift-F11.
- **Clipboard** — Cut, Copy and Paste (Ctrl-X/C/V, Shift-Del, Ctrl-Ins,
  Shift-Ins), in the editor and in dialog fields, use the system clipboard
  through the desktop's helper: `wl-copy`/`wl-paste` on Wayland, `xclip` or
  `xsel` on X11, `pbcopy`/`pbpaste` on macOS, PowerShell on Windows and WSL.
  Copies also go to the terminal as OSC 52, which reaches your own desktop's
  clipboard over ssh where the terminal allows it; there the terminal's own
  paste key (Ctrl-Shift-V, Cmd-V) pastes into the IDE. With no helper the IDE
  keeps its own clipboard: Project | Set up ESP32-S3 toolchain offers to
  install one (`xclip`, or `wl-clipboard` on Wayland), as does
  `./x setup-clipboard`. Other helpers go in `.turbo_ada`, as shell commands
  that read the text on stdin and write it on stdout:
  `clipboard.copy=tmux load-buffer -w -` and `clipboard.paste=tmux save-buffer -`,
  say (`none` turns either off).
- **Compile** — Alt-F9 checks the current file with the real compiler
  (`gprbuild -gnatc` into a scratch tree, so the build's `obj/` is never
  touched): about a second, even for the xtensa target. Make (F9) runs the
  project's build in the background behind the Compiling box (Esc cancels),
  through `./x --machine` so the box shows the real stages and the Message window
  gets every diagnostic with its full path; Enter, a click, or Alt-F8 / Alt-F7
  jumps to the line. Also Build all, Clean, and the SDK's Memory (`./x mem`),
  Stack (`./x stack`) and Test reports.
- **Static analysis** — Compile | Analyze file and Analyze project run
  [AdaLang_Analyzer](https://github.com/mmartign/AdaLang_Analyzer) on the file
  being edited or on the project's own code (`./x analyze`, `esp32-ada analyze`,
  or for an Alire crate `adalang_analyzer -P` in alr's environment). Its findings
  go to the Message window as warnings, with the rule, the advice and the source
  line under each; Enter or Alt-F8 goes to them. The file is saved first. If the
  analyzer is not installed, the IDE offers to build it with Alire (it builds
  Libadalang, so it takes a while, once); `./x setup-toolchain` offers it too.
- **Ada Language Server** — when `ada_language_server` is installed (found on
  `PATH`, in `~/.alire/bin`, or inside an installed VS Code Ada extension),
  errors appear as you type, in red, with the message on the status line; F12
  goes to a definition (into the generated xtensa runtime too), Alt-F12 comes
  back, Shift-F12 lists uses, Ctrl-F12 lists the file's symbols, Ctrl-Space
  completes, Ctrl-F1 shows the declaration, Shift-F1 (and by itself, typing
  `(` or `,`) puts the call's profile on the status line with the current
  parameter marked, and Search | Rename symbol renames across files. Without
  it, everything else works as before.
- **SPARK** — Compile | Prove file and Prove project run GNATprove: what it
  cannot prove comes back as warnings (medium/high) or notes (low) in the
  Message window. In the SDK, `./x prove FILE` proves the file with the native
  proof project that lists it (`libs/*/*_prove.gpr`, the host suites), and
  `./x prove` runs the whole pass (`book/prove/prove.sh`). Elsewhere it is
  `gnatprove -P` on the project (`-u` the file). Not installed: the IDE offers
  `alr install gnatprove`.
- **Search in files** — Search | Find in files: any text (case, whole word),
  in files matching patterns (`*.adb *.ads ...`), in the project and, in the
  SDK, its libraries; the matches go to the Message window. Replace in files
  lists them, then changes them in editors and leaves them unsaved, one undo
  step per file, to be looked over before File | Save all.
- **Git** — Alt-G (Project | Git): status (Enter opens the file), diff of the
  file or of everything (in the Output window), log, stage, commit (with
  `git add -A` first unless unticked), pull `--ff-only`, push (asked first),
  and `git pull` in the ESP32-S3 SDK. Outside a repository it offers
  `git init`. Git never prompts for a password on the IDE's terminal.
- **Run** — Ctrl-F9 makes and flashes, then reads the board's console into
  the Output window while the IDE stays on screen (Run | Monitor reads it
  without flashing). Shift-F2, or Space in the Output window, pauses the
  window so you can scroll back; the console is still read meanwhile, so
  nothing is lost and the board never stalls on output, and resuming adds
  what came. Esc (or Ctrl-C in the Output window, or Ctrl-F2) stops reading
  (the board runs on). KDE keeps Ctrl-F1..F4 and Ctrl-F9 for itself: F11
  runs too, or free them in System Settings | Shortcuts. The window keeps
  the last 10000 lines. A native program runs the same way: made, then its
  output in the Output window (its input is empty; Esc ends it and anything
  it started). Run | Run on user screen, for a program that reads the
  keyboard, and Run | GDB console (a plain GDB prompt), hand the terminal
  over; Alt-F5 shows the user screen.
  Flash and Kill OpenOCD are there separately.
- **Debug** — Turbo C++'s integrated debugger, on the board or natively, with
  its keys:
  F7 trace into, F8 step over, F4 go to cursor, Ctrl-F9 run on, Ctrl-F2
  program reset, Ctrl-F8 toggle breakpoint (red lines, kept in `.turbo_ada`),
  Ctrl-F7 add watch (the Watch window, re-evaluated at every stop), Ctrl-F4
  evaluate/modify (Ada assignment, so records too), Alt-F4 inspect (the value
  laid out in full), Ctrl-F3 call stack. With no session, F7/F8/F4 (or Ctrl-F9
  with breakpoints set) build and flash the program, start OpenOCD
  (`./x debug-server --smp`: both cores, each a GDB thread) and GDB in its
  machine interface on the ELF
  (`./x debug-info`), reset the board and run it to the Ada main or the
  cursor; the cyan bar shows where it stopped (on core 0: a stop GDB
  reports on core 1, idling in the runtime, is moved to core 0), and the board's console goes
  to the Output window (Alt-F5). While it runs, F7/F8/F4 pause it. OpenOCD's
  flash breakpoints are on, so breakpoints in flash code are not limited to
  the chip's two hardware ones (they are patched into flash and taken out
  again when the session ends; if the IDE dies mid-session, re-flash).
  Needs OpenOCD and the ESP32-S3 GDB: the first session offers
  `./x get-debug-tools`. A native program (an Alire crate, a host test suite)
  is debugged with the system's `gdb`: Make, then the program the project
  file names as its main (from `bin/`, the project directory or `obj/`) run
  on a pseudo-terminal whose output goes to the Output window; Ctrl-F2 ends
  it. Paused inside the runtime or libc, the bar shows the nearest caller
  with source, and F7/F8 first return to it. The program runs with no
  arguments, so a suite whose `run.sh` passes some (or starts a server) runs
  differently under the debugger.
- **Project** — open an SDK example or any folder, edit `alire.toml` and the
  `.gpr`, see the board's flash/PSRAM sizes. File | Reopen and Project |
  Recent projects list the files and projects opened last.
- **GPR project** — outside the SDK, a folder with a `.gpr` and no
  `alire.toml` is built with `gprbuild` (Clean: `gprclean`), and Run runs the
  program it built. The GNAT and gprbuild on `PATH` are used, else Alire's
  newest native ones. New project makes one ("Ada program, without
  Alire").
- **New project** — Project | New project asks for a name, a *Location* (the
  folder the project's own folder is made in; Browse... picks one, and one
  that is not there yet is made) and a kind: an ESP32-S3 application
  (`esp32-ada init`), an SDK example (`./x new`, always in `examples/`, offered
  inside the SDK), an Alire crate, a program or a library (`alr init --bin`
  / `--lib`), or an Ada program without Alire (a `.gpr` and `src/`). The location starts as the one used last (kept in
  `~/.config/turbo-ada/options`), else beside the open project (or the SDK),
  else the folder the IDE was started in. The new project is opened.
- **Get the SDK** — Project | Get ESP32-S3 SDK clones the SDK's `main` branch
  from GitHub (`git clone`, so `git pull` there updates it) into
  `ada_esp32s3` in a Location of your choice (default: your home folder), or
  uses an SDK already there. The IDE remembers it (`sdk.path` in
  `~/.config/turbo-ada/options`), so New project and `esp32-ada` find it from
  anywhere; it then offers to run `setup-toolchain` and to add
  `. ~/ada_esp32s3/export.sh >/dev/null` to `~/.bashrc`. New project offers it
  when an ESP32-S3 application is wanted and no SDK can be found.
- **Project file** — the `.gpr` is found by one rule, the same as `./x`'s and
  `esp32-ada`'s: `alire.toml`'s first `project-files` entry (else
  `<crate>.gpr`), else `app.gpr`, else the first `*.gpr` by name that is not a
  `*_prove.gpr`. Project | Project file picks another of the directory's
  `.gpr` files; it is kept in `.turbo_ada` and used by Compile, the language
  server, the project viewer and Analyze (passed to `./x` and `esp32-ada` as
  `--gpr FILE`). `alr build` still builds what `alire.toml` names.
- **Project viewer** — Project | Viewer (or Window | Project) opens a tree
  down the left. Tab switches its two views. *Folders* is the project
  directory (folders first; Enter or Right opens one, Left closes it). *Sources*
  is what the project builds from, grouped by project: its own and each one it
  withs (the SDK libraries, Alire dependencies), from `gprinspect` in the
  project's environment. Once the program is built it lists the closure from
  `gprls --closure` (exactly the files it needs: 12 for the heartbeat example,
  of the hundreds in the libraries); before that, every source in the
  projects' source directories. Enter on a file opens it (not a binary one,
  such as `app.bin`); Ctrl-R re-reads. Lines too long for the window end in
  an ellipsis.
- **Project, Alire items** — Search crates (`alr search --crates`), Get crate (`alr get` into
  a directory you choose, then open it as the project), Install tool (`alr
  install`, e.g. `ada_language_server`), Add dependency (`alr with <crate>`,
  after which the compile environment and the language server are refreshed),
  Dependencies, Update dependencies, Show crate, and Fetch Alire to download or
  replace `alr` itself.
- **ESP32-S3 toolchain** — before the first build of an SDK example or
  `esp32-ada` project, Turbo Ada runs `./x setup-toolchain --check`
  (`esp32-ada setup-toolchain --check`). If a compiler, gprbuild or the
  xtensa-dynconfig plugin is missing it says which and offers Project | Set up
  ESP32-S3 toolchain: the validated GNAT and gprbuild through `alr` (fetched
  first if there is none; your default `alr` toolchain is left alone), the
  plugin built from the vendored source, and a check that the cross compiler
  now emits little-endian ESP32-S3 objects. Then the build carries on.
- **Options** — Target: the USB/JTAG port and the console port (passed as
  `-p` / `-c`; both found by USB id when left empty — Detect lists the board
  ports, and naming one is only needed with several boards attached) and the
  runtime profile (`-P`), the
  command templates themselves, editor settings. Options | Save options, and
  every exit, writes `.turbo_ada` (git-ignored) in the project or SDK root
  with the options, the open files, the breakpoints and the watches, so the
  desktop comes back next time.
- **Windows** — move and resize with the mouse or Ctrl-F5, F5 zoom, F6 next,
  Alt-1..9, Alt-0 list, Tile, Cascade; F1 help, Help | Keyboard for every key.

## tada-cli: Turbo Ada without a terminal

`bin/tada-cli` is the IDE without a screen, in the manner of `kicad-cli`: for
tests, for scripts, and for working on the IDE itself. Relative paths are
taken from `-C DIR`, as with `git -C`.

```sh
tada-cli -C DIR project info [--json]   # the project as the IDE sees it
tada-cli -C DIR ui [--size 100x30] [--script FILE] [-e STEP]... [FILE...]
tada-cli -C DIR debug [--break FILE:LINE]... [--watch EXPR]... [--no-build] \
                      [--script FILE] [-e STEP]...
tada-cli keys                           # the key names a script takes
```

`ui` runs the real IDE on a virtual terminal (`Turbo.Script`): the same
code, the same windows, nothing faked; its input is a script and its screen
can be printed or checked. One step per line:

```
key Down Down Ctrl-F8        # keys by name: F8, Ctrl-F9, Alt-X, Shift-Tab, Esc ...
type Total                   # text, as typed
key F8
wait-stopped                 # until the debugger has stopped and the IDE shows where
expect Total: 1              # on the screen, else the run fails (exit 1)
wait-for Success. 60         # until it appears (seconds), else fail and stop
screen                       # print the screen (screen json: with colours)
key Alt-X                    # quit as a user would (options saved)
```

Steps run when the IDE asks for input, so a long command (a build, F8
starting a session) is over before the next step. While the IDE is busy and
only watching for Esc, keys and checks wait; `wait`, `wait-for` and `screen`
still run, so a build can be watched. `--trace` logs every step and key.

`debug` runs a session through the IDE's GDB/MI client (natively, or on the
board with OpenOCD) and prints each stop, the watches, and the program's
output (`| ...`); steps are `start next step finish continue until break
watch print stack wait expect-line expect-value`, `print X := 3` sets X:

```
$ tada-cli -C demo debug --break demo.adb:15 --watch Total -e next -e continue
stopped  breakpoint-hit  demo.adb:3  demo
> next
stopped  end-stepping-range  demo.adb:4  demo
  Total = 0
> continue
| Sum of squares
stopped  breakpoint-hit  demo.adb:15  demo
  Total = 1
```

`test/cli/run.sh` uses both on a scratch crate (`./x test host` runs it).
`test/board/run.sh` needs an ESP32-S3 on USB: it steps `examples/esp32s3_smp`
on core 0 while core 1 runs. On the board, `tada-cli debug` reads the
console as the IDE does (a USB-Serial/JTAG console nobody reads stalls the
program).

## Commands are templates

Each action is a template (Options | Commands) run through `/bin/sh -c`
(on Windows `bash -c` when bash is on `PATH`, e.g. MSYS2 or Git Bash, else
`cmd /c`), in the SDK root or the project directory:

```
{example} {port_opt} {profile_opt} {gpr_opt} {port} {profile} {dir} {root} {file} {gpr} {tmp}
```

`{port_opt}` is ` -p PORT` only when a port is set, so the tool's own default
(`$ESPPORT`, else `/dev/ttyACM0`) applies otherwise; `{profile_opt}` likewise,
and `{gpr_opt}` is ` --gpr FILE` only when Project | Project file chose one.

## Layout

```
src/term_c.c          raw terminal: termios on POSIX, VT console modes on Windows
src/turbo-term*       its Ada face; alternate screen, mouse, bracketed paste
src/turbo-events*     bytes -> keys, mouse, paste, resize
src/turbo-screen*     the cell grid, flushed as a diff (16 colours or exact CGA)
src/turbo-theme.ads   the Turbo C++ colour scheme
src/turbo-buffers*    a file's text, with undo/redo and search
src/turbo-syntax*     per-line highlighting
src/turbo-windows*    framed windows: close/zoom boxes, scroll bars, resize grip
src/turbo-editors*    the edit window
src/turbo-clipboard*  the system clipboard (wl-copy, xclip, xsel, pbcopy, PowerShell), OSC 52
src/turbo-formatter*  Edit | Format without the language server: gnatformat on the text
src/turbo-messages*   the message window and the diagnostic parser
src/turbo-project_view*  the Project window: folders, and the sources by project
src/turbo-viewers*    read-only text (help, clipboard, project information)
src/turbo-desktop*    the window stack, the status line
src/turbo-menus*      the menu bar and pull-downs
src/turbo-dialogs*    dialog controls, message boxes, find, the file dialog
src/turbo-projects*   project detection, command templates, .turbo_ada
src/turbo-jobs*       background builds (output read from a log as it grows)
src/turbo-pipes*      child processes read line by line by a reader task
src/turbo-console*    the board's console for Run and Monitor (pause, stop)
src/turbo-json*       just enough JSON for LSP
src/turbo-lsp*        the language server client (reader task, requests)
src/turbo-app*        the event loop and every command
src/turbo-script*     scripts for the IDE on a virtual terminal (tada-cli ui)
src/tada.adb          tada, the IDE
src/tada_cli.adb      tada-cli: project info, ui, debug
test/host/            host tests (./x test host runs them)
test/cli/             tada-cli: the IDE and the debugger, scripted
test/board/           tada-cli debug on a board (dual-core stepping)
```
