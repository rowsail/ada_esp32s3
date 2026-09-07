#!/bin/bash
# Flash via the vendored 2nd-stage bootloader + app.bin (esptool).  $1 = port.
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/../common/bare/bare_flash.sh" "$HERE" "$1"
