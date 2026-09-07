# The book — *Bare-Metal Ada on the ESP32-S3*

A LaTeX book documenting this project: why Ada suits microcontrollers, how it
makes register and bit-field programming safe, the anatomy of an Ada application
from `Main` down to the boot ROM, the three runtime profiles, how to build and
run on the ESP32-S3, a guide to every peripheral driver (with worked examples),
the network and filesystem subsystems built on top of them, and the conformance,
analysis and proof evidence behind the runtime.

The reader it is written for, and the house style it holds itself to, are in
[`STYLE.md`](STYLE.md): manual-grade clarity for an experienced C programmer who
is new to Ada and to bare metal.

## Build

```sh
make            # -> main.pdf  (needs pdflatex + makeindex; runs several passes)
make clean
```

A CI workflow (`.github/workflows/book.yml`) builds the same PDF in a TeX Live
container. Pushing a version tag (`v*`) publishes it as a GitHub Release;
dispatching the workflow by hand uploads it as a build artifact.

## Layout

`main.tex` holds the preamble, the title page and the part structure; every
chapter is one `ch_*.tex` file, in the order below.

### Part I — Ada on Bare Metal

| File | Chapter |
|------|---------|
| `ch_preface.tex` | Preface |
| `ch_foundations.tex` | Why Ada for microcontrollers; register addressing; bit fields |
| `ch_ada_for_c.tex` | Ada for C programmers: the translation table |
| `ch_packages.tex` | Packages: reuse, privacy, and the build |
| `ch_getting_started.tex` | Getting started: toolchain, first build, first flash |
| `ch_anatomy.tex` | Anatomy of an Ada application, from `Main` to the boot ROM |
| `ch_debugging.tex` | Debugging on the chip: JTAG, backtraces, fault diagnostics |
| `ch_lang.tex` | Ada language techniques: literals, subtypes, validation, contracts |

### Part II — The Runtime

| File | Chapter |
|------|---------|
| `ch_gnarl_gnull.tex` | GNARL and GNULL: the two-layer tasking runtime |
| `ch_limitations.tex` | Full-profile limitations, and why they rarely bite |

### Part III — Talking to Hardware

| File | Chapter |
|------|---------|
| `ch_hardware.tex` | Registers, bit layouts, endianness: types that carry the hardware |
| `ch_encapsulation.tex` | Encapsulation, ownership and concurrency (`private`, `limited`, controlled) |
| `ch_hal.tex` | HAL conventions; GPIO, RNG, Temperature, SPI, I2C, UART |
| `ch_hal2.tex` | GDMA, MCPWM, I2S, LEDC, RMT, PCNT, SDM, TWAI, Timer, LCD, ADC |
| `ch_hal3.tex` | RTC, RTC-IO, Touch, SHA, AES |
| `ch_driver_design.tex` | Writing a task-safe driver (Engine / ownership gateway) |
| `ch_tasking.tex` | Tasking and concurrency on the three profiles |
| `ch_suspension.tex` | Suspension objects: the interrupt-to-task handoff |
| `ch_lowpower.tex` | Low power: deep sleep and retained state |

### Part IV — Building Real Systems

| File | Chapter |
|------|---------|
| `ch_storage.tex` | SD\_SPI, SDMMC, ext4; ext4 on raw SPI NOR flash (W25Q, wear leveling, on-device mkfs) |
| `ch_eeprom.tex` | Serial EEPROM: one driver for the whole 24C family |
| `ch_fram.tex` | FRAM: non-volatile RAM, the same catalogue without the wait |
| `ch_text_io.tex` | A pure-Ada `Ada.Text_IO` over the console and ext4 |
| `ch_networking.tex` | `GNAT.Sockets` over the W5500; DNS, DHCP, FTP client and server, multi-interface routing |
| `ch_modbus.tex` | Modbus TCP: your data, your handlers (master and slave) |
| `ch_tls.tex` | Pure-Ada TLS 1.3 (HTTPS) — SPARKNaCl + HW crypto, X.509, ECDHE, P-256/P-384 |
| `ch_wifi.tex` | Wi-Fi: a pure-Ada driver over a binary radio |
| `ch_asm.tex` | Assembly inside Ada: a SIMD vector library |

### Part V — Under the Hood

| File | Chapter |
|------|---------|
| `ch_runtime_build.tex` | Building and porting the runtime (bb-runtimes, the three profiles) |
| `ch_bootloader.tex` | The boot path: 2nd-stage bootloader and PSRAM |
| `ch_esp_loader.tex` | `Esp_Loader`: flashing another ESP32 from the board |
| `ch_production.tex` | Going to production: secure boot, watchdogs, field updates |
| `ch_ota.tex` | Designing over-the-air updates on this boot path |
| `ch_psram.tex` | Bringing up the octal PSRAM; the 80 MHz din-timing tune |
| `ch_heap.tex` | `malloc`/`free` in Ada via the O(1) TLSF allocator |
| `ch_static_memory.tex` | Static memory: bounding the stack and the heap |
| `ch_performance.tex` | Performance: where code and data live (SRAM, cache, PSRAM) |
| `ch_context_switch.tex` | The context switch |
| `ch_interrupts.tex` | Interrupts: vectors, levels, and `Ada.Interrupts` |
| `ch_testing.tex` | Testing and verification: the layers of trust |
| `ch_acats_sweep.tex` | Conformance at scale: a standalone ACATS sweep |
| `ch_analysis.tex` | Static analysis: the baselines, the standards profiles, the trap |
| `ch_spark.tex` | Formal proof with SPARK: silver, gold and platinum |
| `ch_conclusion.tex` | Conclusion |

### Appendices

| File | Chapter |
|------|---------|
| `ch_appendix.tex` | Appendix A — quick reference: usable GPIO pins, the profiles at a glance, the example index |
| `ch_app_internal.tex` | Appendix B — reference for every on-chip peripheral driver |
| `ch_app_external.tex` | Appendix C — reference for every external-device driver |
| `ch_glossary.tex` | Glossary |
| `ch_references.tex` | Further reading |

## Alongside the chapters

| Directory | What it is |
|------|------|
| [`prove/`](prove) | The SPARK proof surface: `prove.sh` runs GNATprove over the pure, bounded units, and `prove/README.md` records every proved unit, its level (silver / gold / platinum), and the defects proving found. Chapter `ch_spark.tex` is the narrative version. |
| `verify/` | A compile-only GPR project holding every worked example printed in the chapters. `gprbuild -P book/verify/verify.gpr` compiles them all against the real HAL on the `embedded` profile, so the book cannot show Ada that does not build. |
| [`STYLE.md`](STYLE.md) | The house style the chapters are held to. |
