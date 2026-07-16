#!/bin/bash
# esp32s3_wifi_tls -- pure-Ada TLS 1.3 HTTPS over the software TCP stack.
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
export HEAP_SIZE=65536 ENV_STACK_SIZE=65536 ENV_STACK_PSRAM=1

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
# libcore.a (misc_nvs.o) is RETIRED -- its 6 referenced symbols are provided in
# Ada by ESP32S3.WiFi.Core_Shim (misc NVS is dormant on our NVS-disabled port).
# One fewer Espressif blob.  See research/wifi-re.
export EXTRA_OBJS="-Wl,--start-group $W/libnet80211.a $W/libpp.a $P/libphy.a -Wl,--end-group"

# DE-BLOB (no crypto in a blob): retire ALL blob cipher-engine programming by
# redirecting it to Ada replacements in libs/esp32s3_wifi.  hal_crypto_set_key_
# entry / hal_crypto_clr_key_entry (key slots) -> Wrap_Set_Key / Wrap_Clr;
# hal_crypto_enable (engine-mode regs) -> Wrap_Crypto_Enable.  None of the blob's
# crypto functions execute, and no key byte reaches blob C.
WRAP_CRYPTO="hal_crypto_set_key_entry hal_crypto_clr_key_entry hal_crypto_enable"
for fn in $WRAP_CRYPTO; do EXTRA_OBJS="$EXTRA_OBJS -Wl,--wrap=$fn"; done

# DE-BLOB libphy (recreate in Ada, proof of method): the first transpiled PHY
# primitive.  force_txrx_off -> ESP32S3.WiFi.PHY.Wrap_Force_Txrx_Off (faithful
# port of its 0x60006110 read-modify-write).  ROM stays; only this .a fn moves.
WRAP_PHY="force_txrx_off phy_disable_low_rate phy_enable_low_rate phy_wifi_enable_set \
ant_dft_cfg ram_enable_wifi_agc ram_disable_wifi_agc phy_set_tx_seed wifi_rifs_mode_en"
for fn in $WRAP_PHY; do EXTRA_OBJS="$EXTRA_OBJS -Wl,--wrap=$fn"; done

# ROM symbol addresses the blobs call (lower-MAC/PHY/newlib routines in ROM).
export EXTRA_LD="$HERE/wifi_rom.ld"

exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
