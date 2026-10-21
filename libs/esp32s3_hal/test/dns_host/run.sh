#!/bin/bash
# Build the native DNS_Client harness and run it against the local stdlib
# Python mini DNS server (UDP + TCP on one port; no external deps).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
. "$HERE/../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }
command -v python3  >/dev/null || { echo "no python3 found"; exit 1; }

gprbuild -P dns_host.gpr -q

PORT=15853
python3 dns_server.py "$PORT" &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
for i in $(seq 1 50); do
    if python3 - "$PORT" <<'EOF' 2>/dev/null
import socket, sys
s = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=0.2)
s.close()
EOF
    then break; fi
    sleep 0.1
done

if OUT="$(./dns_host "$PORT")"; then
    echo "$OUT"
else
    STATUS=$?
    echo "$OUT"
    exit $STATUS
fi
