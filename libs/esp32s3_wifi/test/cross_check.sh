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
HAL="$SDK/libs/esp32s3_hal"
# Every HAL source directory on the search path (-aI), collected from the tree:
# the HAL scopes its runtime profiles BY DIRECTORY (src/peripherals, src/net,
# ...), so naming them here would need an edit each time one is added.  svd/ is
# included too -- ESP32S3.RNG, which the OS adapter pulls in, is written against
# the generated register layer, and leaving it off is why this check could not
# compile anything before.
HAL_AI=""
while IFS= read -r d; do HAL_AI="$HAL_AI -aI$d"; done <<EOF
$(find "$HAL/src" "$HAL/svd" -type d | sort)
EOF
OUT="$(mktemp -d)"
cd "$(dirname "$0")/../src"
xtensa-esp32-elf-gnatmake -c -gnat2022 -gnatf --RTS="$RTS" \
  -aI. $HAL_AI -D "$OUT" esp32s3-wifi.adb esp32s3-wifi-os_adapter.adb
echo "OK: Wi-Fi Ada cross-compiles for esp32s3 (OS-adapter 480 B, ap_record 92 B)"
