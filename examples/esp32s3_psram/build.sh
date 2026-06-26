#!/bin/bash
# IDF-free build of the PSRAM demo via the shared bare-boot (examples/common/bare).
# No ESP-IDF / idf.py.  Main unit is "Main" -> _ada_main.  The external octal PSRAM
# is brought up + mapped by our 2nd-stage bootloader (common/bare/bootloader);
# glue.c only re-applies the cache-MMU map (after start.S wipes it) for big.adb's
# 1 MB .ext_ram.bss array, placed at 0x3D000000 by psram.ld.
# No HEAP_SIZE: this is light-tasking (no heap), and its runtime already provides
# memcpy.
HERE="$(cd "$(dirname "$0")" && pwd)"
export ENV_STACK_SIZE=98304            # generous env stack (kept; the app itself is light)
# No EXTRA_OBJS: the app does NOT bring up PSRAM (glue.c PSRAM_ENABLE=0 -- the 2nd-stage
# bootloader does it).  It only maps PSRAM via ROM Cache_Dbus_MMU_Set, so it needs none of
# the vendored octal-PSRAM / mspi_timing objects.
export EXTRA_LD="$HERE/psram.ld"
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
