#!/bin/bash
# Flash the PSRAM demo (vendored bootloader + partition table + app.bin) via esptool.
#   $1 = serial port (default /dev/ttyACM0)
HERE="$(cd "$(dirname "$0")" && pwd)"
SDK="/home/dhowells/tempgit/ada_esp32s3"   # the ada_esp32s3 SDK repo (bare-boot tooling)
exec bash "$SDK/examples/common/bare/bare_flash.sh" "$HERE" "$1"
