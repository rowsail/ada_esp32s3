#!/bin/bash
# Build and run the native Net_Routes host test (pure logic -- no hardware).
# Requires a native GNAT + gprbuild (auto-discovered from the Alire toolchains).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
. "$HERE/../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }

gprbuild -P net_routes_test.gpr -q
./net_routes_test
