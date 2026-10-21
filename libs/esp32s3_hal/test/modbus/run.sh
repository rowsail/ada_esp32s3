#!/bin/bash
# Build and run the native Modbus framing host test (pure logic -- no hardware).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
# The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
. "$HERE/../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }
gprbuild -P modbus_test.gpr -q
./modbus_test
