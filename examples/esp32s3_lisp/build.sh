#!/bin/bash
# ext4-on-flash: the pure-Ada FS uses a heap block cache, so put the heap arena
# in the 8 MB PSRAM (like esp32s3_ext4_write).
HERE="$(cd "$(dirname "$0")" && pwd)"
export ESP32S3_RTS_PROFILE=embedded
export HEAP_SIZE=1 HEAP_PSRAM=1 ENV_STACK_SIZE=65536
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
