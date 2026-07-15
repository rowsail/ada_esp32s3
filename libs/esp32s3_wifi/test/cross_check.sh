#!/usr/bin/env bash
# Cross compile-check the Wi-Fi Ada against the REAL esp32s3 ABI (32-bit words),
# so the OS-adapter table (480 B = 120 words) and wifi_ap_record_t (92 B) rep
# clauses are validated for the chip -- a native host check cannot (host
# pointers are 8 B).  Uses the xtensa GNAT + dynconfig via the SDK env; compiles
# only the Wi-Fi closure (not the whole HAL).  Compile-only, no board.
set -euo pipefail
SDK="${ESP32S3_ADA_SDK:-$HOME/tempgit/ada_esp32s3}"
. "$SDK/export.sh" >/dev/null
RTS="$SDK/crates/esp32s3_rts/embedded-esp32s3"
HAL="$SDK/libs/esp32s3_hal/src"
OUT="$(mktemp -d)"
cd "$(dirname "$0")/../src"
xtensa-esp32-elf-gnatmake -c -gnat2022 -gnatf --RTS="$RTS" \
  -aI. -aI"$HAL" -D "$OUT" esp32s3-wifi.adb esp32s3-wifi-os_adapter.adb
echo "OK: Wi-Fi Ada cross-compiles for esp32s3 (OS-adapter 480 B, ap_record 92 B)"
