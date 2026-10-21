#!/bin/bash
# Build and run the P384.Verify known-answer test.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
# The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
. "$HERE/../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
gprbuild -P p384_host.gpr -q
./p384_host
