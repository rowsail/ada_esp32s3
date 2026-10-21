#!/bin/bash
# Build the native FTP_Client host harness and run it against a local stdlib
# Python FTP server (no external deps).  Requirements: a native GNAT + gprbuild
# (auto-discovered from the Alire toolchains) and python3.
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

gprbuild -P ftp_host.gpr -q

PORT_FILE="$(mktemp /tmp/ftp_port.XXXXXX)"
python3 ftp_server.py >"$PORT_FILE" 2>/dev/null &
SRV=$!
trap 'kill $SRV 2>/dev/null; rm -f "$PORT_FILE"' EXIT

PORT=""
for _ in $(seq 1 50); do
   PORT="$(cat "$PORT_FILE" 2>/dev/null)"
   [ -n "$PORT" ] && break
   sleep 0.1
done
[ -n "$PORT" ] || { echo "FTP server did not start"; exit 1; }
echo "FTP server on 127.0.0.1:$PORT"

./ftp_host "$PORT"
