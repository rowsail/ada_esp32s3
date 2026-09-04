#!/bin/bash
# Flash the PSRAM demo (vendored bootloader + partition table + app.bin) via esptool.
#   $1 = serial port (default /dev/ttyACM0)
HERE="$(cd "$(dirname "$0")" && pwd)"
#  The SDK root is two levels up from this example -- not an absolute path to
#  one developer's home directory, which is what this said and which cannot work
#  in anybody else's clone.
SDK="$(cd "$HERE/../.." && pwd)"
exec bash "$SDK/examples/common/bare/bare_flash.sh" "$HERE" "$1"
