#!/bin/bash
# Flash an IDF-free example built by bare_build.sh: our own 2nd-stage bootloader
# + partition table + the example's app.bin.  By default this uses our OWN Ada
# esp_flash (examples/common/bare/espflash, the ESP32-S3 serial ROM-bootloader
# protocol in Ada) -- so flashing needs no esptool/idf.py.  Set ESP_USE_ESPTOOL=1
# to fall back to esptool.
#   $1 = example directory (contains app.bin)
#   $2 = serial port (default /dev/ttyACM0)
set -e
EX="$(cd "$1" && pwd)"
PORT="${2:-/dev/ttyACM0}"
BARE="$(cd "$(dirname "$0")" && pwd)"
VENDOR="$BARE/vendor"
#  This PROJECT's bootloader + board config (bare_build wrote them into .noidf/ from
#  the project's config/board.ads -- reused SDK default or project-specific).
BOOT="$EX/.noidf/bootloader.bin"
[ -f "$BOOT" ] || { echo "[flash] no $BOOT -- build first (bare_build.sh / esp32-ada build)" >&2; exit 1; }
[ -f "$EX/.noidf/board_config.env" ] && . "$EX/.noidf/board_config.env"

if [ -n "${ESP_USE_ESPTOOL:-}" ]; then
    ESPTOOL="esptool.py"; command -v esptool.py >/dev/null || ESPTOOL="python3 -m esptool"
    $ESPTOOL --chip esp32s3 -p "$PORT" write_flash --flash_mode dio --flash_freq 80m \
        --flash_size "${BOARD_FLASH_SIZE_STR:-2MB}" \
        0x0 "$BOOT" 0x8000 "$VENDOR/partition-table.bin" \
        0x10000 "$EX/app.bin"
else
    EFL="$BARE/espflash/esp_flash"
    [ -x "$EFL" ] || echo "[flash] building the Ada esp_flash host tool (one-time) ..."
    #  Always run gprbuild: incremental, so it rebuilds when the tool source OR
    #  ../config/board.ads changed (e.g. Flash_Size) and no-ops otherwise.
    #  The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
    . "$BARE/../../../tools/sdk-env.sh"
    esp32s3_toolchain_on_path
    ( cd "$BARE/espflash" \
        && PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH" gprbuild -q -P esp_flash.gpr )
    #  ESP_FLASH_MONITOR=1 : after flashing, reset-to-run and stream the console to
    #  stdout WITHOUT closing the port (the ACATS sweep uses this -- one held-open
    #  session captures the single post-reset run from its first byte; an external
    #  monitor would have to re-open after the close, racing the USB-JTAG
    #  re-enumeration the reset triggers).  ESP_FLASH_NO_RESET=1 instead leaves the
    #  chip halted in download mode.  (Mutually exclusive; monitor wins.)
    FLASH_OPT=""
    [ -n "${ESP_FLASH_MONITOR:-}" ] && FLASH_OPT="--monitor"
    [ -z "$FLASH_OPT" ] && [ -n "${ESP_FLASH_NO_RESET:-}" ] && FLASH_OPT="--no-reset"
    #  Drive the SPI flash-size param from THIS project's board.ads, not the tool's
    #  compiled-in default.
    FS_ARG=""; [ -n "${BOARD_FLASH_SIZE:-}" ] && FS_ARG="--flash-size $BOARD_FLASH_SIZE"
    "$EFL" "$PORT" 0x0 "$BOOT" 0x8000 "$VENDOR/partition-table.bin" \
        0x10000 "$EX/app.bin" $FS_ARG $FLASH_OPT
fi
