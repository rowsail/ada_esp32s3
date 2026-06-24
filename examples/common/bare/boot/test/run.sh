#!/usr/bin/env bash
# Build + run the native host test for Bare_Heap_Core (the Ada malloc/free/
# realloc allocator).  Uses the Alire native GNAT; no hardware.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
NAT="$(ls -d "$HOME"/.local/share/alire/toolchains/gnat_native_*/bin 2>/dev/null | head -1)"
[ -n "$NAT" ] && export PATH="$NAT:$PATH"
mkdir -p "$HERE/obj"
gnatmake -I"$HERE/.." -D "$HERE/obj" -O2 -g -gnata -gnatwa \
    "$HERE/bare_heap_test.adb" -o "$HERE/bare_heap_test" >/dev/null
exec "$HERE/bare_heap_test"
