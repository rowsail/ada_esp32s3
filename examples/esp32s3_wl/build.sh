#!/bin/bash
# IDF-free build of esp32s3_wl via the shared bare-boot (examples/common/bare).
# No ESP-IDF / idf.py.  Main unit is "Main" -> _ada_main.  Drivers target the
# embedded profile (full exceptions) -> request heap + larger env stack.
HERE="$(cd "$(dirname "$0")" && pwd)"
export ESP32S3_RTS_PROFILE=embedded
export HEAP_SIZE=65536 ENV_STACK_SIZE=65536
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
