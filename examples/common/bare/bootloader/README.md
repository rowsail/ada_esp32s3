# IDF-free 2nd-stage bootloader (ZFP-Ada loader)

Our own minimal 2nd-stage bootloader for the ESP32-S3, replacing the vendored
ESP-IDF `bootloader.bin`. The first-stage **mask ROM** loads this into SRAM and
runs it; from there everything is ours. It is what makes the examples
build and boot with **no ESP-IDF and no esptool** — only the Alire GNAT toolchain,
our own Ada host tools (`esp_elf2image` / `esp_flash`), and the on-chip mask ROM.

It is flashed at `0x0` (over the partition table / app already on flash) and:

1. disables the boot watchdogs (TG0 MWDT + RTC WDT);
2. reads the app image at flash `0x10000`, copies its IRAM/DRAM segments into
   SRAM, and records its flash IROM/DROM segments;
3. maps IROM (i-bus) + DROM (d-bus) into the cache MMU, enables the cache buses
   and the D-cache;
4. brings up the in-package **octal PSRAM** from SRAM (no flash-XIP rug) and maps
   it at `0x3D000000`;
5. jumps to the app entry.

## What's in each language — and why

The point of this stage is the honest "**Ada from reset**": the loader is Ada,
with assembly only at the irreducible edge. **There is no C here any more** — the
vendored IDF PSRAM objects and the C shims over them are gone, replaced unit for
unit by Ada.

| File | Lang | Role |
|---|---|---|
| `src/boot_main.adb` + `boot_main.ads` | **ZFP-style Ada** | the **loader core** — image parse, RAM-segment copy, flash-cache map, jump. Direct MMIO (`R : Unsigned_32 with Import, Volatile, Address => …`) + ROM imports; the entry handoff is an `access procedure with Convention => C` |
| `src/boot_psram.adb` + `.ads` | **ZFP-style Ada** | the whole octal-PSRAM bring-up: MSPI pin/clock config, mode-register programming through the ROM OPI helper, the cache-MMU map, and a real 80 MHz din-sampling calibration. Exports `psram_bringup`, so `boot_main`'s import resolves unchanged |
| `src/boot_glue.adb` + `.ads` | **ZFP-style Ada** | the freestanding `abort` / `__assert_func` that GCC and the ROM expect (`mem*` come from the shared Ada `Bare_Mem`) |
| `start.S` | asm | the reset prologue (SP / `PS` / `WINDOWSTART`, clear `.bss`) — must run before any high-level language |
| `boot.gpr` | — | compile-only project (no `Main`, no binder) for the Ada loader |
| `rom.ld`, `boot.ld` | — | mask-ROM symbol `PROVIDE`s + the SRAM memory/section layout |

Only documented ROM functions are called from outside this directory. How the
former blobs were reverse-engineered over JTAG, and why the din tune has to run
at the real 80 MHz, is in
[`PSRAM_BRINGUP_RESEARCH.md`](PSRAM_BRINGUP_RESEARCH.md).

### The loader really is runtime-free

`boot_main.adb` is compiled `gprbuild -c -gnatp` against the pinned runtime
*only for `system.ads`* — it has `No_Elaboration` code, so the linked output
needs **no binder (`adainit`) and pulls no runtime**:

```
$ xtensa-esp32-elf-nm obj/boot_main.o | grep ' U '
U Cache_Dbus_MMU_Set   U Cache_Disable_DCache  … U esp_rom_spiflash_read  U psram_bringup
```
Only the ROM/C imports — no `__gnat*`. `start.S` calls `boot_main` directly.

## Build & flash

**You normally don't run these by hand** — `bare_build.sh` (any example's
`./build.sh` / `./x build`) rebuilds this bootloader automatically when
`config/board.ads` (PSRAM/flash size) or a bootloader source changes, and puts
the result in the example's own `.noidf/bootloader.bin`, which is what
`./x flash` writes at `0x0`.

Manually, for just the bootloader:

```sh
./build.sh                 # gprbuild the Ada loader + assemble start.S + link -> boot.elf,
                           #   then package with our Ada esp_elf2image (no esptool)
                           #   -> ./bootloader.bin  (override with $BOOT_OUT)
./flash.sh /dev/ttyACM0    # write_flash 0x0 bootloader.bin  (overlays only 0x0)
```

`build.sh` exports `XTENSA_GNU_CONFIG` (the little-endian ESP32-S3 config —
needed for the link *and* the compiles), runs the runtime crate's
`gen_runtime.sh` for `system.ads`, and packages with the sibling
`../elf2image/esp_elf2image` (byte-identical to esptool; `ESP_USE_ESPTOOL=1`
falls back).

## Notes / gotchas

- A library-unit `Export` aspect needs a **separate spec** (`boot_main.ads`) —
  a body-only `Export` is rejected ("requires separate spec").
- The Ada object is named after the **unit** (`boot_main.o`).
- The bootloader brings up PSRAM unconditionally; for a non-PSRAM app the app's
  `start.S` simply wipes the d-bus map on re-init (harmless). The din tune, and
  the whole PSRAM bring-up story, is in
  [`PSRAM_BRINGUP_RESEARCH.md`](PSRAM_BRINGUP_RESEARCH.md); the first-stage
  picture is in [`../BOOTLOADER_STAGE0.md`](../BOOTLOADER_STAGE0.md).
