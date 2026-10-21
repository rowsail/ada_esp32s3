#!/usr/bin/env bash
# Build + run the native host test for Bare_Heap_Core (the Ada malloc/free/
# realloc allocator).  Uses the Alire native GNAT; no hardware.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# The validated native GNAT (tools/sdk-env.sh), first on PATH.
. "$HERE/../../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
export PATH="$ESP32S3_GNAT_NATIVE_BIN:$PATH"
mkdir -p "$HERE/obj"
gnatmake -I"$HERE/.." -D "$HERE/obj" -O2 -g -gnata -gnatwa \
    "$HERE/allocator_test.adb" -o "$HERE/allocator_test" >/dev/null
exec "$HERE/allocator_test"
