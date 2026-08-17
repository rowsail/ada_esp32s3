# Using this project in VS Code

Step-by-step setup to **edit, build, flash, monitor, and debug** the bare-metal
Ada ESP32-S3 examples in VS Code. The committed `.vscode/` files
(`tasks.json`, `launch.json`, `settings.json`) wire everything to the top-level
**`./x`** dispatcher, so there's almost nothing to configure.

> First time on this repo at all? Do the toolchain + board setup in
> [`../QUICKSTART.md`](../QUICKSTART.md) (Alire toolchains, clone with submodules,
> serial-port permission) — that's the prerequisite. This guide is only the VS Code
> layer on top.

---

## 1. Install VS Code

- **Debian/Ubuntu:** `sudo snap install code --classic` (or the `.deb` from
  <https://code.visualstudio.com/>).
- **Other OS / WSL2:** download from the site; on WSL2 also install the **WSL**
  extension and open the repo with `code .` from your WSL shell.

## 2. Install the extensions

Open **Extensions** (`Ctrl-Shift-X`) and install:

| Extension | ID | Why |
|---|---|---|
| **Ada & SPARK** (AdaCore) | `AdaCore.ada` | Language server: completion, diagnostics, go-to-def, hover. **Required.** |
| **Native Debug** | `webfreak.debug` | GDB frontend for the debug launch. *Only needed for F5 debugging.* (cppdbg can't walk the Xtensa stack — no call stack/source — so we use Native Debug, which relays GDB's frames.) |

Or from a terminal:

```sh
code --install-extension AdaCore.ada
code --install-extension webfreak.debug
```

> The **Ada Language Server ships inside the AdaCore extension** — you don't
> install it separately.

## 3. Open the repo

```sh
cd ~/ada_esp32s3
code .
```

Make sure the Alire toolchains are on the `PATH` of the shell you launch `code`
from (the same `export PATH="$HOME/alire/bin:$PATH"` from QUICKSTART), so ALS and
the build tasks find the compilers.

## 4. Point the language server at an example

Each example has its own `.gpr`, and `.vscode/settings.json` defaults ALS to the
GPIO0 blink one:

```jsonc
"ada.projectFile": "examples/esp32s3_gpio0_blink/gpio_blink.gpr"
```

To work on a **different** example, change that path (the file lists every
example's `.gpr`) and run **`Ctrl-Shift-P` → "Developer: Reload Window"**. Code
intelligence then reflects that example.

## 5. Build, flash, monitor

These come from `.vscode/tasks.json` (each just calls `./x`, prompting for the
example, serial port, and runtime profile):

| Action | How |
|---|---|
| **Build** | `Ctrl-Shift-B` (the default build task → `Ada: build`) |
| **Flash** | `Ctrl-Shift-P` → **Tasks: Run Task** → `Ada: flash` |
| **Build + flash** | `Ctrl+F9` (or Run Task → `Ada: build + flash`) |
| **Monitor** | Run Task → `Ada: monitor` (serial console @115200) |
| **Build + flash + monitor** | Run Task → `Ada: run` |
| **Clean** | Run Task → `Ada: clean` |

Each prompts for the **example** (a dropdown) and **port** (default
`/dev/ttyACM0`). `Ada: build` / `Ada: run` also prompt for the **runtime
profile** — `auto` (default — the example's own), `light-tasking`, `embedded`, or
`full` — passed to `./x` as `--profile`. Build errors appear in the **Problems**
panel (a GNAT problem matcher is wired in `tasks.json`).

### `Ctrl+F9` = build + flash

The `Ada: build + flash` task (build then flash, in sequence) is bound to
**`Ctrl+F9`**. Because VS Code keybindings are **user-global** (there is no
workspace `keybindings.json`), the binding can't live in this repo — add it once
via `Ctrl-Shift-P` → **Preferences: Open Keyboard Shortcuts (JSON)**:

```jsonc
{ "key": "ctrl+f9", "command": "workbench.action.tasks.runTask",
  "args": "Ada: build + flash" }
```

(The task itself *is* in `tasks.json`, so `Run Task → Ada: build + flash` works
without the keybinding.)

## 6. Debug on-chip (optional, F5)

`.vscode/launch.json` provides **"Ada: debug (OpenOCD + GDB)"**: it starts an
`openocd` task and attaches GDB to the example's `app.elf`. Setup is two things:

- the **Native Debug** (`webfreak.debug`) extension (step 2), and
- **OpenOCD + GDB**, fetched once with `./x get-debug-tools` (pinned, SHA-256-verified
  downloads into the git-ignored `tools/openocd/` + `tools/gdb/`).

> **Why a fetched GDB:** the ESP32-S3 needs the s3-specific `xtensa-esp32s3-elf-gdb`.
> The Alire crate's `xtensa-esp32-elf-gdb` is built for the ESP32 (LX6) register set
> and fails on the S3 (LX7) with *"'g' packet reply too long (452 vs 608)"* —
> verified on hardware. So debugging fetches the matching GDB; build/flash/run don't.

1. **Fetch the debug tools once:** `./x get-debug-tools` (in the integrated terminal).
2. **Build *and flash*** the example first (`Ctrl+F9` = build + flash) so the chip
   is running the *same* image whose `app.elf` you debug. Debugging only **attaches**
   — if the flashed image is stale or a different profile, the breakpoint addresses
   won't match the running code and you'll land in a crash instead of `app_main`.
3. Press **F5**, pick the example directory. It resets and **halts at `app_main`**
   (the shared boot-glue entry — these GNAT images have no C `main`, so the launch
   stops there instead). Set breakpoints in the Ada source and continue/step.
   (CLI equivalent: `./x debug <example>`.)

> Debugging over the built-in USB-Serial-JTAG needs the udev rule from the board
> setup (`SUBSYSTEM=="usb",ATTRS{idVendor}=="303a",MODE="0666"`). If `openocd`
> can't claim the device, that rule (and unplugging any serial monitor holding the
> port) is usually why.

## 7. Board config (flash / PSRAM size)

Edit `examples/common/bare/config/board.ads` (the single source of truth) and
rebuild, or use the dispatcher from VS Code's integrated terminal:

```sh
./x config show
./x config flash-size 4MB
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| No completion / "no project loaded" | Check `ada.projectFile` in `.vscode/settings.json` points to a real `.gpr`, then **Reload Window**. Confirm the AdaCore extension is enabled. |
| ALS can't find the compiler | Launch `code` from a shell that has the Alire toolchains on `PATH` (QUICKSTART step 1). |
| `Ada: build` fails: tool not found | Same PATH issue — the build tasks need the Alire xtensa GNAT + `gprbuild`. |
| Flash: *Permission denied* on the port | Add yourself to `dialout` and re-login (QUICKSTART step 3). |
| `Ada: monitor` opens nothing | Install one of `picocom`/`screen`/`pyserial`, or set `ESP_MONITOR` (see `../TOOLING.md`). |
| F5 debug: `openocd`/GDB not found | Run `./x get-debug-tools` once (fetches both, pinned). |
| F5 debug: `'g' packet reply too long` | You're using the esp32 (LX6) GDB; the S3 needs `xtensa-esp32s3-elf-gdb` — `./x get-debug-tools` installs it. |

See [`../TOOLING.md`](../TOOLING.md) for the full `./x` command surface and how the
same pieces map onto Vim/Neovim and Eclipse.
