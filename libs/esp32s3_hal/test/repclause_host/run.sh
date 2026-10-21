#!/bin/bash
# Build and run the native register bit-field rep-clause equivalence check
# (pure logic -- no hardware).  Auto-discovers a native GNAT + gprbuild.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
# The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
. "$HERE/../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }
gprbuild -P repclause_host.gpr -q
./repcheck
