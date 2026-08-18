# QUICKSTART — bare-metal Ada on the ESP32-S3 (IDF-free)

From a blank machine to a **running bare-metal Ada program on an ESP32-S3** —
**no ESP-IDF, no `idf.py`, no esptool, no Python**. The only toolchain you install
is **Alire** (the Ada package manager); building and flashing go through this
repo's own scripts and host tools (a pure-Ada `elf2image` + serial flasher).

> Linux shown (Ubuntu/Debian). macOS is similar but untested; Windows: use WSL2.
> Expected time: ~15 min, mostly the one-time toolchain download.

---

## What you need

**Hardware**
- An **ESP32-S3** board with its **native USB** port (the one wired to the chip's
  USB-Serial-JTAG — usually labelled **USB**, not **UART**).
- A **data-carrying** USB cable (not charge-only).

**Software** — just three Alire toolchains (git optional). *That's the whole list*: there is
no ESP-IDF, no esptool, and no Python in the build/flash path.

### The big picture

```
  your Ada code ──┐
  Ada RTS       ──┤  ./build.sh ─► gprbuild (Alire xtensa GNAT) ─► app_main.o
  (generated)     │             ─► link (bare boot + vendored Xtensa support)
  bare boot (Ada) ┘             ─► esp_elf2image (Ada)           ─► app.bin
                                ─► our 2nd-stage bootloader      ─► bootloader.bin
                     ./flash.sh ─► esp_flash (Ada, over USB ROM) ─► board runs it
                                   0x0 bootloader │ 0x8000 partitions │ 0x10000 app
```

You only ever type **`./build.sh`** and **`./flash.sh`**. The Ada runtime ("RTS")
is generated and cached on the first build; you never build it by hand. The first
build also compiles the two Ada host tools (`esp_elf2image`, `esp_flash`) once.

---

## Step 1 — Install Alire and the toolchains

```sh
cd ~
wget https://github.com/alire-project/alire/releases/download/v2.1.0/alr-2.1.0-bin-x86_64-linux.zip
unzip alr-2.1.0-bin-x86_64-linux.zip -d ~/alire
export PATH="$HOME/alire/bin:$PATH"        # add to ~/.bashrc to make permanent
alr version                                # -> alr version 2.1.0
```
> ARM64 host? Use the `aarch64` asset. Validated with **alr 2.1.0**, GNAT **15.2**.

Select the three toolchains (one cross-compiler for the chip, plus the native GNAT
and `gprbuild` used to build the runtime and the host tools):

```sh
alr toolchain --select gnat_native gprbuild
alr toolchain --select gnat_xtensa_esp32_elf
alr toolchain                              # confirm all three are present
```

That's the only install. **No ESP-IDF, no esptool, no Python.**

---

## Step 2 — Get the repo (with submodules!)

Two ways in. **There are no submodules** — `bb-runtimes` and `xtensa-dynconfig`
are vendored as ordinary directories — so nothing extra has to be fetched.

Unzip the latest release (no git needed; ~11 MB, a complete build tree). Neither
form names a version, so both keep working as releases come and go:

```sh
cd ~
gh release download --repo rowsail/ada_esp32s3 --archive=zip
unzip ada_esp32s3-*.zip && cd ada_esp32s3-*/
```

Without the GitHub CLI — `/releases/latest` redirects to the current tag:

```sh
cd ~
REPO=rowsail/ada_esp32s3
TAG=$(curl -sSLo /dev/null -w '%{url_effective}' \
        https://github.com/$REPO/releases/latest | sed 's|.*/||')
curl -LO https://github.com/$REPO/archive/refs/tags/$TAG.zip
unzip $TAG.zip && cd ada_esp32s3-${TAG#v}
```

Or clone, if you want `git pull` to bring updates:

```sh
cd ~
git clone https://github.com/rowsail/ada_esp32s3.git
cd ada_esp32s3
```

The book (*Bare-Metal Ada on the ESP32-S3*, PDF) is attached to the same
release. Release assets have a stable redirect, so it needs no version either:

```sh
curl -LO https://github.com/rowsail/ada_esp32s3/releases/latest/download/Bare-Metal-Ada-on-the-ESP32-S3.pdf
```

---

## Step 3 — Plug in the board and grant access

1. Connect the board's **native USB** port.
2. Find the port: `ls /dev/ttyACM*` → usually **`/dev/ttyACM0`**.
3. One-time permission to use it without `sudo`:
   ```sh
   sudo usermod -aG dialout $USER          # then LOG OUT and back in
   ```

---

## Step 4 — Build, flash, and watch your first example

Start with the GPIO0 blink (a peripheral driver written in pure Ada):

```sh
cd ~/ada_esp32s3/examples/esp32s3_gpio0_blink
./build.sh                                 # compile + package -> app.bin
./flash.sh /dev/ttyACM0                    # flash over the USB ROM bootloader
```
The **first** `./build.sh` is slow — it builds the `xtensa-dynconfig` core-config
plugin (needs a host C toolchain), generates the Ada runtime, and builds the two
host tools; later builds are fast. `./flash.sh` with no argument defaults to
`/dev/ttyACM0`.

**Watch the console** (any serial terminal at 115200; pick one you have):

```sh
screen /dev/ttyACM0 115200                 # quit: Ctrl-A then K
# or:  python3 -m serial.tools.miniterm /dev/ttyACM0 115200
# or:  cat /dev/ttyACM0
```
You should see GPIO0 toggling at 2 Hz:
```
[C] GPIO0 blink (bare Ada driver, no FreeRTOS)
[gpio0] HIGH
[gpio0] low
...
```
Wire an LED (with a resistor) from GPIO0 to GND, or scope GPIO0, for a visible 2 Hz.

---

## Step 5 — The other examples

Every example builds and flashes the **same way** from its own directory
(`./build.sh` → `./flash.sh [port]`). Each selects the runtime profile it needs.

| Example | What it shows |
|---|---|
| `esp32s3_gpio0_blink` | A pure-Ada peripheral driver — blinks GPIO0 at 2 Hz |
| `esp32s3_heartbeat` | Single-core heartbeat (`[ADA] N` at 1 Hz) |
| `esp32s3_psram` | A 1 MB array in external PSRAM |
| `esp32s3_smp` | Cross-core mailbox over a protected-object entry |
| `esp32s3_embedded` | **Embedded profile** — exceptions, finalization, dispatching |
| `esp32s3_full_tasking` | **Full profile** — full tasking, dynamic tasks, `abort`, rendezvous |

> The `embedded`/`full` examples build a larger runtime, so their **first** build
> takes longer. That's normal.

---

## Step 6 — Board config (flash & PSRAM size)

The two tunable board sizes are **per-project**, in Ada syntax, in a `board.ads`
at the **project's root** (every example has one; there is no global config):

`examples/esp32s3_gpio0_blink/board.ads`
```ada
package Board is
   Flash_Size : constant := 2 * 1024 * 1024;   --  total SPI flash
   PSRAM_Size : constant := 2 * 1024 * 1024;   --  external PSRAM @0x3D000000
end Board;
```
Edit it and rebuild — `./build.sh` regenerates the board config and the 2nd-stage
bootloader automatically (no manual step). A project whose `PSRAM_Size` differs from
the default gets its **own** bootloader; ones that match reuse the prebuilt default.

Prefer not to hand-edit? The repo-root **`./x`** dispatcher does it for you:
```sh
./x config gpio0_blink show
./x config gpio0_blink flash-size 4MB     # or psram-size 8MB
```

---

## Step 7 — Write your own app (in any empty folder)

Don't edit an example — treat this repo as an **SDK**. Source its `export.sh` once
per shell, then scaffold a project anywhere on disk; the project folder holds only
your sources + thin build glue (no runtime source copied in — it references the SDK
via `$ESP32S3_ADA_SDK`):

```sh
. ~/ada_esp32s3/export.sh        # sets ESP32S3_ADA_SDK, PATH, GPR_PROJECT_PATH
                                 # (add to ~/.bashrc to make it permanent)
mkdir ~/myblink && cd ~/myblink
esp32-ada init                   # scaffold app.gpr, board.ads, src/main.adb, .vscode
# ... edit src/main.adb ...
esp32-ada run -p /dev/ttyACM0              # build + flash + monitor
```

`esp32-ada` is the standalone-project counterpart of the in-repo `./x`:
`init / build [-P profile] / flash [-p port] / run / monitor / clean / config / debug`.
The new folder looks like:

```
myblink/  app.gpr  board.ads  build.sh  flash.sh  .gitignore  src/main.adb  .vscode/
```

`app.gpr` does `with "esp32s3_rts.gpr"`, resolved via `GPR_PROJECT_PATH` (set by
`export.sh`) — so the build **and** the Ada Language Server find the runtime with no
hard-coded path. The project owns its own `board.ads` (Step 6), edited with
`esp32-ada config …`.

---

## Everyday workflow & tips

- **Edit Ada and rebuild:** just `./build.sh` again, then `./flash.sh`.
- **Force the Ada to rebuild:** `rm -f obj/app_main.o` then `./build.sh`.
- **Force the runtime to regenerate** (e.g. after a toolchain change):
  `rm -rf crates/esp32s3_rts/*-esp32s3`.
- **Pick a different port:** pass it to flash, e.g. `./flash.sh /dev/ttyACM1`.
- **Prefer esptool?** It's an optional fallback: `ESP_USE_ESPTOOL=1 ./build.sh`
  (and `./flash.sh`). The default path needs neither esptool nor Python.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `gprbuild` / cross-GNAT not found | A toolchain is missing — redo Step 1, check `alr toolchain`. |
| `XTENSA_GNU_CONFIG unset` / missing `bb-runtimes` | Not a submodule issue (there are none): the tree is incomplete, or `xtensa-dynconfig` hasn't been built — the first build does that and needs a host C compiler. |
| `Permission denied` on `/dev/ttyACM0` | Add yourself to `dialout` (Step 3) and log out/in. |
| No `/dev/ttyACM0` appears | Use the **native USB** port (not UART); try another cable; check `dmesg \| tail`. |
| Flash never connects | Hold **BOOT**, tap **RESET**, release **BOOT** to force download mode, then `./flash.sh`. |
| Board resets/panics in a loop | Each example ships `CONFIG_ESP_SYSTEM_MEMPROT_FEATURE=n` (W^X off, needed for Ada trampolines); rebuild clean. |
| First build very slow | Expected — generating the Ada runtime + building the host tools. Later builds are fast. |
| Console shows nothing/garbage | 115200 8N1 on the native USB port; confirm the right `/dev/ttyACM*`. |

---

## One-screen cheat sheet

```sh
# --- one-time setup (no ESP-IDF, no esptool, no Python) ---
wget .../alr-2.1.0-bin-x86_64-linux.zip && unzip -d ~/alire alr-*.zip
export PATH="$HOME/alire/bin:$PATH"
alr toolchain --select gnat_native gprbuild
alr toolchain --select gnat_xtensa_esp32_elf
git clone https://github.com/rowsail/ada_esp32s3.git   # or unzip a release
cd ada_esp32s3
sudo usermod -aG dialout $USER          # then log out/in

# --- build, flash, watch an example ---
cd examples/esp32s3_gpio0_blink
./build.sh
./flash.sh /dev/ttyACM0
screen /dev/ttyACM0 115200              # Ctrl-A K to quit

# --- or start your own app in any folder ---
. ~/ada_esp32s3/export.sh               # ESP32S3_ADA_SDK + esp32-ada on PATH
mkdir ~/myblink && cd ~/myblink && esp32-ada init
esp32-ada run -p /dev/ttyACM0           # build + flash + monitor
```

Welcome to bare-metal Ada on the ESP32-S3. Next, read the root `README.md` and any
example's `README.md` for how the runtime and the IDF-free boot work.
