#!/bin/bash
# Flash ONLY our minimal 2nd-stage bootloader at flash 0x0 (leaves the partition
# table @0x8000 and app @0x10000 untouched).  $1 = serial port (default ttyACM0).
# Recovery: re-flash any working example fully (its vendored bootloader goes to 0x0).
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT="${1:-/dev/ttyACM0}"
# Use our Ada esp_flash (no esptool).  Set ESP_USE_ESPTOOL=1 to fall back.
if [ -n "${ESP_USE_ESPTOOL:-}" ]; then
    ESPTOOL="esptool.py"; command -v esptool.py >/dev/null || ESPTOOL="python3 -m esptool"
    exec $ESPTOOL --chip esp32s3 -p "$PORT" write_flash \
        --flash_mode dio --flash_freq 80m --flash_size 2MB 0x0 "$HERE/bootloader.bin"
fi
EFL="$HERE/../espflash/esp_flash"
if [ ! -x "$EFL" ]; then
    #  The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
    . "$HERE/../../../../tools/sdk-env.sh"
    esp32s3_toolchain_on_path
    ( cd "$HERE/../espflash" \
        && PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH" gprbuild -q -P esp_flash.gpr )
fi
exec "$EFL" "$PORT" 0x0 "$HERE/bootloader.bin"
