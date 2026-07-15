#!/usr/bin/env bash
#
# Fetch the Espressif Wi-Fi + PHY binary blobs that the esp32s3_wifi driver
# links.  Each blob is pinned to an exact upstream commit and verified by sha256
# (see libs/esp32s3_wifi/blobs/MANIFEST.lock).  The blobs are Apache-2.0 (see
# libs/esp32s3_wifi/blobs/LICENSE.*) but are NOT committed to this repo -- this
# script downloads them on demand into libs/esp32s3_wifi/blobs/.
#
# Idempotent: a blob already present with the right checksum is left alone.
# Set WIFI_BLOB_BASE to use a mirror instead of raw.githubusercontent.com.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
BLOBDIR="$ROOT/libs/esp32s3_wifi/blobs"
MANIFEST="$BLOBDIR/MANIFEST.lock"
BASE="${WIFI_BLOB_BASE:-https://raw.githubusercontent.com}"

[ -f "$MANIFEST" ] || { echo "fetch-wifi-blobs: no manifest at $MANIFEST" >&2; exit 1; }

sha() { sha256sum "$1" | awk '{print $1}'; }

rc=0
while read -r repo commit path want _rest; do
    case "${repo:-}" in ''|\#*) continue ;; esac   # skip blank + comment lines
    name="$(basename "$path")"
    dest="$BLOBDIR/$name"

    if [ -f "$dest" ] && [ "$(sha "$dest")" = "$want" ]; then
        echo "ok     $name (cached)"
        continue
    fi

    url="$BASE/$repo/$commit/$path"
    echo "fetch  $name  <-  $repo@${commit:0:7}"
    tmp="$(mktemp)"
    if ! curl -fsSL --max-time 120 "$url" -o "$tmp"; then
        echo "  ERROR: download failed: $url" >&2
        rm -f "$tmp"; rc=1; continue
    fi
    got="$(sha "$tmp")"
    if [ "$got" != "$want" ]; then
        echo "  ERROR: checksum mismatch for $name" >&2
        echo "    want $want" >&2
        echo "    got  $got" >&2
        rm -f "$tmp"; rc=1; continue
    fi
    mv "$tmp" "$dest"
    echo "  verified + installed"
done < "$MANIFEST"

if [ "$rc" -ne 0 ]; then
    echo "fetch-wifi-blobs: one or more blobs failed" >&2
fi
exit "$rc"
