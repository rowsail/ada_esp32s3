#!/bin/bash
# esp32s3_wifi_deepsleep -- associate to Wi-Fi, then deep-sleep the chip.
#
# Same pure-Ada Wi-Fi driver + bare-boot as esp32s3_wifi_scan; this example adds
# the ESP32S3.RTC deep-sleep path.  The point it makes: entering deep sleep is
# itself the Wi-Fi power-down -- the RTC controller cuts the whole digital + RF
# power domain (radio, MAC and CPU), so no explicit radio shutdown is needed.
# On the timer wake the chip RESETS and re-runs from the top, re-initialising the
# radio from scratch (a retained boot counter proves the cycle).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"

# Embedded (Jorvik) profile + heap: the OS-adapter maps Wi-Fi malloc onto the
# leftover-DRAM arena (DMA-capable internal SRAM).
export ESP32S3_RTS_PROFILE=embedded
export HEAP_SIZE=65536 ENV_STACK_SIZE=65536

# Wi-Fi + PHY blobs: a local ESP-IDF (IDF_PATH) if present, else the fetched,
# checksum-verified copies under libs/esp32s3_wifi/blobs (auto-fetched here).
if [ -n "${IDF_PATH:-}" ] && [ -d "$IDF_PATH/components/esp_wifi/lib/esp32s3" ]; then
    W="$IDF_PATH/components/esp_wifi/lib/esp32s3"
    P="$IDF_PATH/components/esp_phy/lib/esp32s3"
else
    W="$REPO/libs/esp32s3_wifi/blobs"; P="$W"
    [ -f "$W/libnet80211.a" ] || bash "$REPO/tools/fetch-wifi-blobs.sh"
fi
# --start-group: the archives cross-reference, so order-independent resolution.
export EXTRA_OBJS="-Wl,--start-group $W/libnet80211.a $W/libpp.a $W/libcore.a $P/libphy.a -Wl,--end-group"

# ROM symbol addresses the blobs call (lower-MAC/PHY/newlib routines in ROM).
export EXTRA_LD="$HERE/wifi_rom.ld"

exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
