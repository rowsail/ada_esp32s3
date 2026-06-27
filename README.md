# Bare-Metal Ada on the ESP32-S3 — no FreeRTOS, no ESP-IDF

A from-scratch, almost-entirely-Ada software stack for the dual-core **ESP32-S3**
(Xtensa LX7). The runtime owns **both cores** — the context switch, interrupt
vectors, clock tick, SMP scheduler and inter-core IPI are all its own, written in
Ada and Xtensa assembly. **FreeRTOS never runs** (its scheduler isn't even
linked) and there is **no ESP-IDF** in the build: every example compiles with
Alire GNAT alone and boots through our own minimal 2nd-stage bootloader.

## Hardware validation — full-board retest (2026-06-24)

Every driver and the whole runtime were re-verified on real silicon, on a
fully-populated ESP32-S3 board (all external devices except an SD card):

- **Device drivers — all working:** ES8311 codec + mic (440 Hz play **and**
  mic-capture loopback), QMI8658C IMU (≈1 g at rest), SHT41 temp/humidity,
  PCF85063A RTC, TCA9555 GPIO expander, capacitive touch, ST7789 / ST7789-cube /
  LCD-i8080 displays, anti-aliased B612 font, a multi-sensor dashboard, TX1812
  addressable LEDs, and a NMEA GPS parser.
- **Peripheral self-tests — all PASS:** SHA/AES crypto, GDMA, I2S / RMT / TWAI /
  UART loopbacks, PCNT, sigma-delta, LEDC + MCPWM PWM, and the general-purpose
  timer.
- **Runtime / tasking — all working:** ZCX exceptions, full dynamic tasking
  (tasks allocated + freed on the heap, with `abort`), dual-core SMP, rendezvous,
  interrupt levels, and the PSRAM allocator.

The freestanding C runtime (`memcpy`/`malloc`/…) is now **Ada** too: an O(1)
**TLSF** allocator and the `mem*`/libc shims, host-tested and hardware-validated.

It is built in three layers:

1. **A native GNAT/Ada runtime** in three selectable profiles — *light-tasking*
   (Jorvik), *embedded* (ZCX), and *full* (complete GNARL tasking) — grown from
   AdaCore's `bb-runtimes` with a new `esp32s3` board and packaged as a
   pin-consumable Alire crate ([`crates/esp32s3_rts`](crates/esp32s3_rts)).
2. **A reusable, hardware-verified peripheral HAL**
   ([`libs/esp32s3_hal`](libs/esp32s3_hal)) — 25+ task-safe drivers.
3. **A pure-Ada ext2/3/4 filesystem with a JBD2 journal**
   ([`libs/esp32s3_hal/src/ext4`](libs/esp32s3_hal/src/ext4)) — mounts real ext4
   SD cards (read, write, crash recovery) and is cross-validated against the Linux
   kernel's own `e2fsck`.

> New here? Start with **[QUICKSTART.md](QUICKSTART.md)**. For the developer
> tooling and IDE setup see **[TOOLING.md](TOOLING.md)**. For the long-form
> design write-up (the kernel, the HAL, the filesystem, the conformance work)
> read **[the book (`book/main.pdf`)](book/main.pdf)** — its
> [LaTeX source](book/) is in the same directory.

## Blob-free PSRAM bring-up with a real timing tune

Reinforcing the *no-ESP-IDF* claim, the 2nd-stage bootloader's external octal-PSRAM
bring-up is now **entirely from-source** — all five vendored IDF objects (the
`mspi_timing`/GPIO config *and* the chip init) were reverse-engineered live over JTAG
and replaced with ~200 lines of readable C
([`mspi_timing_src.c`](examples/common/bare/bootloader/mspi_timing_src.c) +
[`psram_impl_src.c`](examples/common/bare/bootloader/psram_impl_src.c)). The bring-up
now calls only documented ROM functions: mode-register programming and the
connectivity probe go through the ROM OPI helper, and the controller config is written
from the captured (golden) register state.

The PSRAM **din sampling is also genuinely calibrated now**. The IDF blob runs its
tuning sweep at 20 MHz — where the sampling phase is irrelevant — so it always falls
back to a vendor default that actually *fails* at the 80 MHz operating speed
(previously papered over by a hand-coded override). The replacement sweeps the din at
the real 80 MHz over a *bounded* SPI1 transaction (a wrong setting returns garbage
instead of stalling the bus), finds the true timing window, and centres on it — a
per-board measurement with no magic constant, validated end-to-end by the example's
1 MB checksum. Full write-up:
[PSRAM_BRINGUP_RESEARCH.md](examples/common/bare/bootloader/PSRAM_BRINGUP_RESEARCH.md).

## What runs on real silicon

- **Dual-core SMP** — tasks pinned per core (`CPU => 1`/`CPU => 2`), cross-core
  wake-ups via an inter-core poke, and **protected-object entries across cores**.
- **Cooperative and preemptive priority scheduling**; the runtime owns the Xtensa
  level-5 vector (its tick + IPI) and dispatches level-2/3 device interrupts.
- **Interrupt-driven `delay until` / periodic tasks** with exact, stable periods.
- **Full Ada tasking** on the `full` profile — rendezvous, protected entries,
  dynamic/nested tasks, dynamic priorities, task attributes, exception
  propagation, `abort`, and `Ada.Interrupts` handlers (static *and* dynamic).
- **Single-precision FPU** state preserved across context switches.
- **ACATS 4.2 conformance** on hardware — **0 genuine failures on every profile**
  (`full`: 1,286+ PASS one-test-per-image; see below).
- **25+ peripheral drivers** and a **pure-Ada ext4 filesystem** (most drivers
  ship with a hardware self-test; see [Testing status](#testing-status)).

## Quick start

```sh
git clone --recurse-submodules \
    https://github.com/rowsail/ada-bare-metal-esp32s3.git
cd ada-bare-metal-esp32s3
./x flash smp_empty           # build + flash the empty SMP skeleton
./x monitor                   # watch the console
```

`./x` is the in-repo dispatcher (`./x list`, `./x flash <example>`,
`./x monitor`, `./x new <name>`, `./x debug …`). The first build fetches the
Alire toolchains and builds the runtime crate. Full setup, prerequisites, and a
guided first run are in **[QUICKSTART.md](QUICKSTART.md)**.

To scaffold a project **outside** the repo, `source export.sh` and run
`esp32-ada init [<dir>]` (defaults to the current folder) — see [TOOLING.md](TOOLING.md).

## Runtime profiles

Selected per build with `ESP32S3_RTS_PROFILE` (default `light-tasking`):

| Profile | Tasking model | What you get |
|---|---|---|
| `light-tasking` | Jorvik (Ravenscar+) | Periodic tasks, protected objects, SMP; no exception propagation (heap-less). The lean default. |
| `embedded` | Jorvik + ZCX | Adds full exception propagation **with names**, controlled-type finalization, and a heap. |
| `full` | Complete GNARL | Lifts the Jorvik restrictions: rendezvous, selective `accept`, dynamic/nested tasks, dynamic priorities, `abort`, dynamic `Ada.Interrupts`. |

`light-tasking` and `embedded` set `pragma Profile (Jorvik)`; `full` is the
unrestricted runtime. See the book's profile chapter and the
[Limitations](book/) chapter for the `full`-profile edges.

## Examples

All 31 examples share the same FreeRTOS-free bare boot
([`examples/common/bare/`](examples/common/bare)); build/flash any with
`./x flash <short-name>` (the `esp32s3_` prefix is optional).

**Boot**
| Example | What it is |
|---|---|
| `esp32s3_heartbeat` | Single-core heartbeat (`[ADA] N` at 1 Hz) |
| `esp32s3_psram` | A 1 MB static array placed in the external 8 MB PSRAM |

**Peripheral HAL self-tests** (most need *no wiring* — internal loopback / GPIO sampling)
| Example | Driver exercised |
|---|---|
| `esp32s3_gpio0_blink` | GPIO straight off the registers |
| `esp32s3_uart_loopback` | UART internal TX→RX loopback + RTS/CTS flow control |
| `esp32s3_i2c_loopback` | I2C master (START/addressing/NACK/multi-byte write) |
| `esp32s3_i2s_loopback` | I2S full-duplex DMA loopback, byte-exact |
| `esp32s3_gdma_copy` | GDMA mem-to-mem + RAII `Channel` handle |
| `esp32s3_mcpwm_pwm` / `esp32s3_ledc_pwm` / `esp32s3_sdm_output` | PWM / LED-PWM / sigma-delta, GPIO-sampled |
| `esp32s3_rmt_loopback` / `esp32s3_pcnt_count` | RMT pulse loopback / pulse counter |
| `esp32s3_twai_loopback` | TWAI (CAN) self-test frame, no transceiver |
| `esp32s3_timer_count` | GP timer vs the runtime wall clock + alarm |
| `esp32s3_lcd_i8080` | 8-bit i80 parallel LCD DMA transfer |
| `esp32s3_adc_read` / `esp32s3_touch_read` | SAR ADC / capacitive touch |
| `esp32s3_rtc_sleep` / `esp32s3_rtcio_hold` | Deep sleep + retained memory / RTC-pad hold |
| `esp32s3_crypto` | HW SHA-1/224/256 + AES-128/256 vs FIPS vectors |

**Storage & filesystem**
| Example | What it is |
|---|---|
| `esp32s3_sd_spi` / `esp32s3_sdmmc` | SD over SPI / native SDHOST — non-destructive sector round-trip |
| `esp32s3_w25q` | W25Q256FV SPI NOR flash — JEDEC ID, 4-byte mode, erase + page-program + read-back (CS via the SPI callback on a shared bus) |
| `esp32s3_wl` | Dynamic wear-leveling FTL (`Block_Dev.WL`) over the SPI NOR flash — format, write/verify across mapping moves, remount and re-verify |
| `esp32s3_ext4_flash` | A real ext4 filesystem on the SPI NOR flash — install an embedded image through `Ext4 → Block_Dev.WL → W25Q_Source`, mount read-write, read + create/commit a file (no-journal direct flush) |
| `esp32s3_ext4_mkfs` | **Format** a blank SPI NOR flash to ext4 **on-device** with `Ext4.Mkfs` (no host, no image; optional JBD2 journal), then mount read-write, create files + a subdirectory, remount and read back |
| `esp32s3_ext4` | Mount a real ext4/3/2 SD card with the pure-Ada filesystem and read a file |

**Tasking & runtime profiles**
| Example | What it is |
|---|---|
| `esp32s3_smp` | Cross-core mailbox over a protected-object entry |
| `esp32s3_embedded` | `embedded` profile: tagged dispatch, finalization, named exceptions |
| `esp32s3_full_tasking` | `full` profile: dynamic tasks, master wait, `abort` |
| `esp32s3_rendezvous` | `full` profile: a server task with entries served by selective `accept` |
| `esp32s3_full_intr` | `full` profile: `pragma Attach_Handler` / `Ada.Interrupts` on HW |

**Diagnostics**
| Example | What it is |
|---|---|
| `esp32s3_intr_levels` | Interrupt-vector regression test (L2/L3/L5 dispatch + context preservation) |

## The peripheral HAL

[`libs/esp32s3_hal`](libs/esp32s3_hal) is a reusable Alire library
(`with "esp32s3_hal.gpr";`) of task-safe drivers built on an svd2ada register
layer: GPIO, SPI, I2C, UART, GDMA, I2S, LEDC, RMT, PCNT, SDM, MCPWM, GP timers,
ADC, capacitive touch, RTC + RTC-IO, LCD (i80), TWAI/CAN, hardware crypto
(SHA/AES), RNG, and SD (SPI + native SDHOST). Each is a thin private register
"Engine" hidden behind a task-safe gateway (protected object or a
limited-controlled RAII handle), so concurrent access from multiple tasks is safe
by construction. Most drivers ship with a self-test under `examples/`; see
[Testing status](#testing-status) for what has actually been run on silicon.

## The pure-Ada ext4 filesystem

[`libs/esp32s3_hal/src/ext4`](libs/esp32s3_hal/src/ext4) is a from-scratch
ext2/3/4 implementation in Ada (a reimplementation in the spirit of lwext4):
read **and** write (create/write/truncate/mkdir/rmdir/unlink/rename/link),
metadata checksums, and JBD2 journal replay + commit. It is developed against a
rootless host test harness that checks every operation against
`mke2fs`/`debugfs`/`e2fsck` (that harness lives in the development repository).
It is **host-verified only** — the on-device path (`examples/esp32s3_ext4`, over
the SD driver) has not yet been validated on hardware.

## Testing status

**Important:** the table below reflects what was exercised *during development*;
nothing here has been re-verified as it ships in this distribution. Treat every
driver as **needing verification on your own board** before you rely on it.

Drivers that **have a hardware self-test** (loopback or self-test run on an
ESP32-S3 during development — re-verify on your hardware):

> GPIO (+ level-3 interrupts), RNG, SPI, I2C, UART, GDMA, I2S, LEDC, RMT, PCNT,
> SDM, MCPWM, GP Timer (TIMG), ADC, capacitive Touch, RTC, RTC-IO, LCD (i80),
> TWAI/CAN, SHA, AES.

Drivers and components that are **not hardware-verified** and need testing:

| Component | State | What's needed |
|---|---|---|
| `SD_SPI` (SD card over SPI) | compiles; no-card smoke test only | test against a real card |
| `SDMMC` (native SDHOST) | compiles; no-card smoke test only | test against a real card |
| Temperature sensor | compiles | run on hardware |
| ext4 filesystem | host-verified vs `e2fsck` only | validate on-device over SD |

## ACATS conformance

The runtime is exercised against the **ACATS 4.2** suite on real hardware, with
the grade captured per test over the serial console — **0 genuine failures on
every profile**:

| Profile | Test list | PASS | FAIL |
|---|---|---:|---:|
| `light-tasking` (Jorvik) | `jorvik_hw_runnable.txt` (846) | ~700 | **0** |
| `embedded` (ZCX) | `jorvik_hw_runnable.txt` (846) | 840+ | **0** |
| `full` (complete GNARL) | `full_applicable.txt` (1,518) | 1,286+ | **0** |

The `embedded`/`full` figures are from a **standalone one-test-per-image** sweep
that parallelizes across many boards. Every non-passing test is an interactive
test (needs a bench-generated stimulus), a build-drop (a library unit the bare
runtime omits), a correct `NOT-APPLICABLE`, or a documented limitation. The
book's ACATS chapter has the full breakdown. (The ACATS suite and its sweep
harness are not shipped in this distribution; they live in the development
repository.)

## Tooling & debugging

- **`./x`** — the in-repo dispatcher (build/flash/monitor/new/debug). `./x list`
  shows every example and its profile.
- **`esp32-ada`** — after `source export.sh`, scaffold and build projects in any
  empty folder, no runtime source copied.
- **VS Code** — first-class target: build tasks plus on-chip GDB debugging over
  the built-in USB-Serial-JTAG (pinned OpenOCD + Xtensa GDB). Rests at Ada `Main`.
- **Flashing** uses our own Ada `esp_flash` host tool (no esptool needed;
  `ESP_USE_ESPTOOL=1` is an optional fallback).

Details and editor setup: **[TOOLING.md](TOOLING.md)**.

## Repository layout

```
crates/
  esp32s3_rts/      the GNAT runtime crate (3 profiles) + gen_runtime.sh + full_overlay/
  bb-runtimes/      AdaCore bb-runtimes fork with the esp32s3 board (submodule)
  xtensa-dynconfig/ the Xtensa core-config plugin the toolchain needs
libs/
  esp32s3_hal/      the reusable peripheral HAL + the pure-Ada ext4 filesystem
examples/           the flashable examples (each owns its board.ads)
  common/bare/      the shared FreeRTOS-free boot (bootloader, start.S, vectors, glue)
book/               the long-form guide (LaTeX sources + main.pdf)
x, export.sh        the ./x dispatcher and the esp32-ada launcher
QUICKSTART.md, TOOLING.md
```

## Prerequisites

- **Alire** (`alr`) with the `gnat_xtensa_esp32_elf` and `gnat_native`
  toolchains + `gprbuild` (Alire fetches them on first build).
- A host C compiler (to build the `xtensa-dynconfig` plugin once).
- An ESP32-S3 board on USB. Console is the built-in USB-Serial-JTAG (`/dev/ttyACM*`)
  or an external UART bridge (CH343/FTDI).

The bare boot runs with memory protection (W^X) off, which the Ada task-body
trampolines require; there is no `sdkconfig`/`idf.py` involved.

## Status

The runtime and all three profiles build and run on hardware (the examples flash
and boot). The HAL drivers and the filesystem have varying levels of
verification — see [Testing status](#testing-status); several need testing on
hardware and nothing has been re-verified as it ships here.
The `full` profile is functionally complete for the common cases; its remaining
edges (an RM-permitted abort case, a couple of toolchain-bound constructs, and
post-2099 `Ada.Calendar`) are catalogued in the book's *Full-Profile Limitations*
chapter. The project name dropped the original "Jorvik" branding; the genuine
Ada Jorvik *profile* support remains.

## License

Apache-2.0 WITH LLVM-exception (see [LICENSE](LICENSE) and [NOTICE](NOTICE)).
The runtime builds on AdaCore's GPL-3-with-runtime-exception `bb-runtimes`; the
GNAT Runtime Library Exception applies to code linked against the runtime.
