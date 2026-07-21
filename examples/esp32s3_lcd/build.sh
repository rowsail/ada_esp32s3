#!/bin/bash
# IDF-free build of the Waveshare ESP32-S3-Touch-LCD-7 demo via the shared
# bare-boot (examples/common/bare).  Combines the two example patterns:
#   * embedded runtime profile -- the LCD Session is a controlled type, so it
#     needs finalization (light-tasking has No_Finalization);
#   * external PSRAM -- the 768 KB framebuffers live in .ext_ram.bss at
#     0x3D000000 (lcd.ld).  The 2nd-stage bootloader brings the octal PSRAM up;
#     src/lcd_board.adb (bare_board_init) re-applies the cache-MMU d-bus map
#     after start.S wipes it.  No vendored PSRAM objects needed (ROM map only).
HERE="$(cd "$(dirname "$0")" && pwd)"
export ESP32S3_RTS_PROFILE=embedded
export HEAP_SIZE=65536 ENV_STACK_SIZE=65536
export NEED_BARE_MEM=1                  # freestanding memset via Bare_Mem
export EXTRA_LD="$HERE/lcd.ld"
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
