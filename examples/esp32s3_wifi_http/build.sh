#!/bin/bash
# esp32s3_wifi_http -- fetch a URL over Wi-Fi on the pure-Ada software TCP stack.
#
# Pure-Ada Wi-Fi driver (libs/esp32s3_wifi) built on the shared bare-boot.  The
# radio's binary lower-MAC + PHY blobs are fetched and checksum-verified by
# tools/fetch-wifi-blobs.sh (Apache-2.0; see libs/esp32s3_wifi/blobs).  Set
# IDF_PATH to link your own ESP-IDF copies instead.
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
