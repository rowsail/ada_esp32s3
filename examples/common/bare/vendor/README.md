# Vendored artifacts for the IDF-free bare boot

Everything the bare boot needs is **committed here in-tree** — the examples build
and flash with **no ESP-IDF install and no esptool**, only Alire GNAT.  Nothing
in this directory is fetched or required from ESP-IDF at build
time; the files below merely *originated* from ESP-IDF v5.4.4 / the toolchain
(recorded for provenance + license).  They fall into three groups:

* **Vendored IDF *source*, compiled in-tree.** The Xtensa support
  (`xtensa_context.S`, `xtensa_vectors.S`, `xtensa_intr_asm.S`, `xtensa_intr.c`) is
  built from the v5.4.4 source by `bare_build.sh`, over the headers + shims in
  `xtensa_include/`; each object is `objdump -d`-identical to IDF's `libxtensa.a`
  copy. **No prebuilt Xtensa `.obj` remain.**
* **Vendored IDF *text*.** The linker scripts (`memory.ld`, `sections.ld`) and the
  mask-ROM symbol addresses (`rom_syms.ld`).
* **Binary artifacts.** Two genuine opaque blobs that cannot be built from this
  tree — `libxt_hal.a` (the Cadence/Tensilica Xtensa HAL) and `libgcc.a` (the
  toolchain runtime) — plus `partition-table.bin` (a trivial single-app `factory`
  table). The 2nd-stage **bootloader is *not* here**: it's *ours*, built from
  `../bootloader/` to `../bootloader/bootloader.bin` (gitignored, rebuilt on
  demand by `bare_build.sh`); `bare_flash.sh` flashes it from there.

Packaging (`app.elf` → `app.bin`) and flashing use our own Ada host tools
(`../elf2image`, `../espflash`), so the build needs no esptool/idf.py
(`ESP_USE_ESPTOOL=1` falls back to esptool). **STATUS — DONE:** every example
builds IDF-free and runs on hardware (light-tasking, embedded ZCX, full tasking,
ACATS, PSRAM, SMP).

## What is vendored here (provenance: ESP-IDF **v5.4.4**)

| File | Source | Role |
|---|---|---|
| `partition-table.bin` | `build/partition_table/` | Single-app `factory` table, flashed at `0x8000`. |
| `memory.ld`, `sections.ld` | `build/esp-idf/esp_system/ld/` | Chip memory map + section layout (the app-desc / MMU-page-dummy / segment dance). Self-contained (no `INCLUDE`); our link uses these + `-e _start`. |
| `rom_syms.ld` | mask ROM | `PROVIDE(...)` for the ROM functions the boot uses (`esp_rom_printf`=`ets_printf`, `ets_set_appcpu_boot_addr`, `ets_update_cpu_frequency`, the cache/MMU ROM helpers, …). |
| `libxt_hal.a` | `build/esp-idf/xtensa/` | Cadence/Tensilica Xtensa HAL (`xthal_*`). Opaque blob. |
| `libgcc.a` | toolchain | 64-bit divide helpers (`__divdi3` & friends). Opaque blob. |

### Xtensa support — built from vendored source

All four are compiled from the IDF v5.4.4 `components/xtensa/` source by
`bare_build.sh` (no prebuilt `.obj`); each object is instruction-for-instruction
identical to IDF's `libxtensa.a` copy (verified by `objdump -d` diff). The
"FreeRTOS coupling" was only symbol-name macros (`XT_RTOS_INT_ENTER` →
`_frxt_int_enter`, … — resolved in the link as before) plus two config defines,
not port code.

| File | Role / build notes |
|---|---|
| `xtensa_context.S` | `_xt_context_save/_restore` — the register-window save + `SPILL_ALL_WINDOWS`, run by `highint5.S` on every interrupt. Needs `xtensa_include/xt_asm_utils.h`. |
| `xtensa_vectors.S` | The vector table (window/exception/interrupt vectors at VECBASE). Needs `sdkconfig.h` (`CONFIG_FREERTOS_INTERRUPT_BACKTRACE` → the `s32e` backtrace blocks) + `esp_private/panic_reason.h`; `XT_RTOS_TIMER_INT` left undefined (S3 ticks off the systimer, not the Xtensa timer). |
| `xtensa_intr_asm.S` | `xt_ints_on` + the `_xt_exception_table`/`_xt_interrupt_table` definitions. Built with `-DportNUM_PROCESSORS=2` (per-core table size). |
| `xtensa_intr.c` | Interrupt-registration tables/dispatch (API unused; linked only for `xt_unhandled_interrupt`, the tables' static default). C — compiled at **`-Og`** (IDF's level for this component) to match; the `freertos/FreeRTOS.h` shim supplies `portNUM_PROCESSORS` + `xPortGetCoreID`. |

`xtensa_include/` holds the vendored Xtensa/IDF headers these need, plus our
minimal shims (`xtensa_rtos.h`, `esp_attr.h`, `sdkconfig.h`, `soc/soc.h`,
`freertos/*.h`, …) that stand in for the deep IDF/FreeRTOS header closures.

These vendored files are the source of truth and need no ESP-IDF to build.  The
only reason to go back to ESP-IDF is a maintainer **re-vendoring** against a
different IDF version: re-copy the Xtensa sources/headers from `components/xtensa/`
and the linker scripts from `build/esp-idf/` of that release, then re-verify the
from-source objects with the `objdump -d` diff.
