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

For the language-server features, install the server once: Alire | Install
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
  project (Search | Grep). Copies also reach the system clipboard via OSC 52.
- **Compile** — Alt-F9 checks the current file with the real compiler
  (`gprbuild -gnatc` into a scratch tree, so the build's `obj/` is never
  touched): about a second, even for the xtensa target. Make (F9) runs the
  project's build in the background behind the Compiling box (Esc cancels),
  through `./x --machine` so the box shows the real stages and the Message window
  gets every diagnostic with its full path; Enter, a click, or Alt-F8 / Alt-F7
  jumps to the line. Also Build all, Clean, and the SDK's Memory (`./x mem`),
  Stack (`./x stack`), Analyze and Test reports.
- **Ada Language Server** — when `ada_language_server` is installed (found on
  `PATH`, in `~/.alire/bin`, or inside an installed VS Code Ada extension),
  errors appear as you type, in red, with the message on the status line; F12
  goes to a definition (into the generated xtensa runtime too), Alt-F12 comes
  back, Shift-F12 lists uses, Ctrl-F12 lists the file's symbols, Ctrl-Space
  completes, Ctrl-F1 shows the declaration, and Search | Rename symbol renames
  across files. Without it, everything else works as before.
- **Run** — Ctrl-F9 makes, then flashes and opens the serial monitor (the
  terminal is handed over; Ctrl-] leaves miniterm). Flash, Monitor, Debug
  (OpenOCD + GDB) and Kill OpenOCD separately; Alt-F5 shows the user screen.
- **Project** — pick an SDK example, scaffold a new project (`./x new`,
  `esp32-ada init` or `alr init --bin`), edit `alire.toml` and the `.gpr`, see
  the board's flash/PSRAM sizes.
- **Alire** — Search crates (`alr search --crates`), Get crate (`alr get` into
  a directory you choose, then open it as the project), Install tool (`alr
  install`, e.g. `ada_language_server`), Add dependency (`alr with <crate>`,
  after which the compile environment and the language server are refreshed),
  Dependencies, Update dependencies, Show crate, and Fetch Alire to download or
  replace `alr` itself.
- **ESP32-S3 toolchain** — before the first build of an SDK example or
  `esp32-ada` project, Turbo Ada runs `./x setup-toolchain --check`
  (`esp32-ada setup-toolchain --check`). If a compiler, gprbuild or the
  xtensa-dynconfig plugin is missing it says which and offers Alire | Set up
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
  with the options and the open files, so the desktop comes back next time.
- **Windows** — move and resize with the mouse or Ctrl-F5, F5 zoom, F6 next,
  Alt-1..9, Alt-0 list, Tile, Cascade; F1 help, Help | Keyboard for every key.

## Commands are templates

Each action is a template (Options | Commands) run through `/bin/sh -c`
(on Windows `bash -c` when bash is on `PATH`, e.g. MSYS2 or Git Bash, else
`cmd /c`), in the SDK root or the project directory:

```
{example} {port_opt} {profile_opt} {port} {profile} {dir} {root} {file} {gpr} {tmp}
```

`{port_opt}` is ` -p PORT` only when a port is set, so the tool's own default
(`$ESPPORT`, else `/dev/ttyACM0`) applies otherwise; `{profile_opt}` likewise.

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
src/turbo-messages*   the message window and the diagnostic parser
src/turbo-viewers*    read-only text (help, clipboard, project information)
src/turbo-desktop*    the window stack, the status line
src/turbo-menus*      the menu bar and pull-downs
src/turbo-dialogs*    dialog controls, message boxes, find, the file dialog
src/turbo-projects*   project detection, command templates, .turbo_ada
src/turbo-jobs*       background builds (output read from a log as it grows)
src/turbo-json*       just enough JSON for LSP
src/turbo-lsp*        the language server client (reader task, requests)
src/turbo-app*        the event loop and every command
test/host/            host tests (./x test host runs them)
```
