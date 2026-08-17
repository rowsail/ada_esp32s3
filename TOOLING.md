# Developer tooling & IDE integration

Two layers, kept deliberately separate:

1. **Language features** (completion, diagnostics, go-to-def, hover) — provided by
   the **Ada Language Server (ALS)** reading each example's **`.gpr`** file. This
   works in *any* editor with an ALS client (VS Code, Eclipse, Vim/Neovim, GNAT
   Studio) — no project-specific plugin needed.
2. **Actions** (build / flash / monitor / clean / config) — provided by one
   stable command surface, the top-level **`./x`** dispatcher. IDEs wrap these as
   tasks / launch configs; they never re-implement build logic.

This split is what keeps an eventual VS Code / Eclipse / Vim plugin thin: the hard
parts (language intelligence, the IDF-free build) already live in ALS + `./x`.

## The `./x` dispatcher

```sh
./x list [--json]                 # examples (name, dir, profile) — discovery
./x new     <name>                # scaffold a new bare project (examples/<name>)
./x build   <example> [-P PROF]   # -> app.bin (PROF: light-tasking|embedded|full)
./x flash   <example> [-p PORT]   # flash over the USB ROM bootloader
./x run     <example> [-p PORT] [-P PROF]  # build + flash + monitor
./x monitor [-p PORT]             # serial console @115200
./x clean   [<example>]           # remove build artifacts (all if omitted)
./x config  <example> [show|--json]   # show flash/PSRAM size (the example's board.ads)
./x config  <example> flash-size <SIZE>  # e.g. 4MB, 512KB, 0x800000, 8388608
./x config  <example> psram-size <SIZE>  # (rebuild the bootloader for it to take effect)
./x get-debug-tools               # fetch the pinned OpenOCD + s3 GDB (debug only)
./x debug   <example>             # on-chip debug: OpenOCD + GDB on app.elf
```

- `<example>` accepts the **short** name (`gpio0_blink`) or the full directory
  (`esp32s3_gpio0_blink`).
- `PORT` defaults to `$ESPPORT` or `/dev/ttyACM0`.
- The monitor picks the first available of `miniterm` / `picocom` / `screen`, then
  a raw `cat` fallback; override with `ESP_MONITOR="<cmd>"`.

### Starting your own project

`./x new <name>` scaffolds a **minimal, uncluttered** project under
`examples/<name>/` — just the files that are actually yours:

```
examples/<name>/
  alire.toml          # pins the esp32s3_rts runtime crate
  app.gpr             # Ada build (-> a relocatable ada_app.o)
  src/main.adb        # your code — boots both cores, then idles
  build.sh flash.sh   # thin shims into common/bare (no edits needed)
  .gitignore
```

All the bare-boot machinery (start-up, the L5 vector, the 2nd-stage bootloader,
linker scripts, image packaging) is **shared** in `examples/common/bare/` — your
project never copies it. Then:

```sh
./x run <name>        # build + flash + monitor (no ESP-IDF needed)
```

The runtime is consumed by an Alire path-pin (`../../crates/esp32s3_rts`), so the
project must live under `examples/`. A scaffolded project defaults to the
**embedded** profile (its `build.sh` exports `ESP32S3_RTS_PROFILE=embedded`);
pick another per build with `./x build <ex> --profile light-tasking|full`, or
change that line in the example's `build.sh`.

### Your own project, *outside* the repo (`esp32-ada`)

`./x new` keeps your project under `examples/`. To work **anywhere on disk**,
treat this repo as an SDK: `source export.sh` once per shell and use `esp32-ada`,
the out-of-tree counterpart of `./x` with the same verbs. `export.sh` puts
`esp32-ada` on `PATH`, exports `$ESP32S3_ADA_SDK`, and adds the runtime + HAL to
`GPR_PROJECT_PATH` (so `gprbuild` **and** the Ada Language Server resolve
`with "esp32s3_rts.gpr"` with no baked-in path).

```sh
. /path/to/ada_esp32s3/export.sh   # once per shell (add to ~/.bashrc to persist)
mkdir ~/myblink && cd ~/myblink
esp32-ada init                     # scaffold app.gpr, board.ads, src/main.adb, .vscode
esp32-ada run -p /dev/ttyACM0      # build + flash + monitor
```

Verbs: `init [DIR] / build [-P PROFILE] / flash [-p PORT] / run [-p PORT] [-P PROFILE] /
monitor / clean / config / debug / kill-openocd / install-ide / install-vim`. A fresh
`init` defaults to the **embedded** profile (set in the project's `build.sh`);
`-C DIR` runs as if from `DIR`.

**Lifting an example out of tree.** Don't copy a whole example directory (its Alire
path-pin, `<name>.gpr`, and relative build shims are tied to `examples/`). Scaffold a
fresh project and bring the sources across — the scaffold already supplies `app.gpr`,
`board.ads` and the build shims:

```sh
esp32-ada init ~/myblink && cd ~/myblink
cp "$ESP32S3_ADA_SDK"/examples/esp32s3_gpio0_blink/src/*.ad? src/   # incl. main.adb
esp32-ada build -P embedded        # match the example's profile (./x list shows it)
esp32-ada run -p /dev/ttyACM0
```

Copy the example's `board.ads` too if it sets a non-default flash/PSRAM size, and its
`glue.c` (at the example root) in the rare case it has C natives — no example
currently does, the boot glue itself being Ada. Add `with "<name>.gpr";` to `app.gpr`
for any extra SDK library it uses.

### Machine-readable discovery (for plugin authors)

`./x list --json` and `./x config <example> --json` emit structured output so a plugin can
populate menus without hardcoding:

```jsonc
// ./x list --json
[{"id":"esp32s3_gpio0_blink","name":"gpio0_blink",
  "dir":"examples/esp32s3_gpio0_blink","profile":"light-tasking"}, ...]
// ./x config <example> --json
{"flash_size":2097152,"flash_size_str":"2MB","psram_size":2097152,"psram_pages":32}
```

## VS Code (first-class target)

> Full step-by-step setup (install VS Code, extensions, ALS project, debug tools)
> is in [`.vscode/README.md`](.vscode/README.md). Quick version:

1. Install the **"Ada & SPARK"** (AdaCore) extension → ALS gives language features
   from the example `.gpr` files. For debugging also install **"Native Debug"**
   (`webfreak.debug`) — cppdbg can't walk the Xtensa stack, so the launch uses
   Native Debug's `gdb` type, which relays GDB's own frames.
2. The committed **`.vscode/tasks.json`** provides `Ada: build` (default build
   task, with a GNAT problem matcher), `Ada: flash`, `Ada: monitor`,
   `Ada: run`, and `Ada: clean` — each a thin call to `./x`, prompting for the
   example and port.
3. **`.vscode/launch.json`** provides `Ada: debug (OpenOCD + GDB)` — it starts the
   `openocd` task and attaches GDB to `app.elf`. Debug setup is just **`./x
   get-debug-tools`** once: it pin-downloads OpenOCD *and* the s3-specific
   `xtensa-esp32s3-elf-gdb` (into `tools/openocd/` + `tools/gdb/`). The S3 needs
   that GDB — the Alire crate's esp32 (LX6) GDB fails on it (HW-verified). Both are
   debug-only; build/flash/run need neither.

> `Ctrl-Shift-B` builds; `F5` debugs; the command palette → "Run Task" lists the rest.

## Other editors

- **Vim / Neovim** — point your LSP client at `ada_language_server` for language
  features; use `./x build` (or `:make ./x build <ex>`) for actions. The GNAT
  error format `file:line:col: error:` works with a matching `errorformat`.
- **Eclipse** — GNATbench/ALS for language; add external-tool / launch configs
  that shell out to `./x`.

In every case the integration is: **ALS for language + `./x` for actions** — the
same two pieces this repo already ships.
