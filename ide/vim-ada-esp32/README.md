# Ada ESP32-S3 — Vim plugin

Build / flash / monitor / **debug** bare-metal Ada ESP32-S3 from Vim. The companion
to `ide/vscode-ada-esp32/`, with the same **two modes**, auto-detected from where you
open Vim:

- **Repo mode** — inside the SDK repo (an `./x` is above you): commands take an
  example and drive `./x <cmd> <example>`.
- **Standalone mode** — inside an `esp32-ada` project (`build.sh` + `app.gpr` above
  you, no `./x`): commands drive `esp32-ada <cmd>` on the project (no example). The
  SDK is found via `$ESP32S3_ADA_SDK` (source the SDK `export.sh`) or `esp32-ada` on
  PATH.

Debug uses Vim's built-in **termdebug** (its GDB frontend) — the Vim analog of the
VS Code Native Debug setup: it relays GDB's own frames, so it handles **Xtensa**
correctly (cppdbg/DAP adapters generally don't). You get the source window with the
current-line sign, breakpoint signs, and `:Step`/`:Over`/`:Continue`.

## Requirements
- **Vim 8.1+ with `+terminal`** (termdebug ships with Vim; Neovim also works).
- Pure Vimscript — nothing to compile.
- For debug: run **`./x get-debug-tools`** once (fetches OpenOCD + the s3 GDB) and
  build the example first (`:AdaEsp32Build`). Uses `tools/openocd.sh` + the s3
  `xtensa-esp32s3-elf-gdb` — same tools as the CLI/VS Code.

## Install

Easiest — one command (symlinks the plugin into Vim's + Neovim's native package
dir; because it's a **symlink into the repo**, `git pull` updates it in place — no
reinstall, no build):

```sh
./x install-vim          # or, from a standalone project:  esp32-ada install-vim
```
Then restart Vim. Or wire it up yourself — it has the standard `plugin/` layout:

```vim
" vim-plug
Plug '/path/to/ada_esp32s3/ide/vim-ada-esp32'
" or, no plugin manager:
set runtimepath^=/path/to/ada_esp32s3/ide/vim-ada-esp32
" or symlink the dir into a pack start dir (what install-vim does):
"   ln -s .../ide/vim-ada-esp32 ~/.vim/pack/ada-esp32/start/vim-ada-esp32
```
The commands auto-detect the mode by searching upward — for `./x` (repo) or an
`app.gpr`+`build.sh` (standalone) — so you can open Vim anywhere inside the repo or
inside a standalone project. In standalone mode the example selectors don't apply
(the project *is* the target); debug pins OpenOCD to the chosen port and uses the
SDK's GDB/OpenOCD.

## Commands

| Command | Action |
|---|---|
| `:AdaEsp32New [dir]` | **scaffold a fresh standalone project** (`esp32-ada init`), then open `src/main.adb` (cd's there) |
| `:AdaEsp32Build [example]` | `./x build` |
| `:AdaEsp32Flash [example]` | `./x flash -p <port>` |
| `:AdaEsp32BuildFlash [example]` | build then flash |
| `:AdaEsp32Run [example]` | `./x run` (build + flash + monitor) |
| `:AdaEsp32Monitor` | `./x monitor -p <port>` (serial console @115200) |
| `:AdaEsp32Clean [example]` | `./x clean` |
| `:AdaEsp32Config` | `./x config show` |
| `:AdaEsp32Debug [example]` | OpenOCD + termdebug (see below) |
| `:AdaEsp32Example [name]` | choose the example (no arg = picker) |
| `:AdaEsp32Port [port]` | set the serial port |
| `:AdaEsp32Profile [prof]` | runtime profile for build/run (no arg = picker) |

`[example]` accepts the short name (`gpio0_blink`) or full dir
(`esp32s3_gpio0_blink`), with tab-completion. The chosen example/port/profile
persist in `g:ada_esp32_example` / `g:ada_esp32_port` (default port `$ESPPORT` or
`/dev/ttyACM0`) / `g:ada_esp32_profile`, so later commands reuse them without
re-prompting. `[prof]` is `auto` (default — the example's own profile),
`light-tasking`, `embedded`, or `full`; it's passed to `./x build`/`run` as
`--profile`.

## Debug workflow
```
:AdaEsp32Build gpio0_blink      " ensure app.elf exists (with -g)
:AdaEsp32Debug gpio0_blink
```
This starts OpenOCD in the background, waits for its GDB server, then opens
**termdebug** with the s3 GDB connected to the target, reset and halted with a
temporary hardware breakpoint armed at `app_main` (the shared boot-glue entry —
these GNAT images have no C `main`). Then, in termdebug:

- **`:Continue`** — run to `app_main`; the source window jumps to `bare_glue.c`
  with the current-line sign.
- **`:Break src/gpio.adb:53`** (or `:Break` on the cursor line) — set an Ada
  breakpoint; `:Continue` lands on your Ada source.
- **`:Step` / `:Over` / `:Finish` / `:Continue`** — step controls.
- `:Evaluate` / the Program/Gdb windows show variables and raw GDB.

OpenOCD is stopped automatically when you end the session (`:Termdebug` quit).

> Caveat (inherent): a **`:Over`** that steps across a *yielding/blocking*
> statement (a `delay`, an entry call) can pass through the hand-written Xtensa
> asm (interrupt vectors / context switch), which has no debug bounds — GDB then
> reports "cannot find bounds of current function." Set a breakpoint past the
> statement and `:Continue` instead.

## Language features (completion, go-to-def) — the Ada Language Server
This plugin only provides *actions*; code intelligence comes from the **Ada
Language Server** (`ada_language_server`) via your LSP client, pointed at the
example's `.gpr`. The example gprs `with` the runtime by a relative path, so the
project resolves with no `GPR_PROJECT_PATH`. Examples:

- **coc.nvim** (`coc-settings.json`):
  ```json
  { "ada.projectFile": "examples/esp32s3_gpio0_blink/gpio_blink.gpr" }
  ```
- **vim-lsp / native LSP / vim9 lsp**: register `ada_language_server` for `ada`
  filetype and set the project file via the server's `ada.projectFile` setting.

`ada_language_server` ships with the AdaCore toolchain / the GNAT Studio install.
