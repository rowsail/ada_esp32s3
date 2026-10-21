#!/bin/bash
# Build + run the native host brute-force test for the wear-leveling FTL
# (ESP32S3.Block_Dev.WL).  Self-checking: the harness exits non-zero on any
# remap / persistence / wear-spreading mismatch.
#
# Requirements: a NATIVE GNAT + gprbuild (Alire toolchains are auto-discovered).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# --- locate a native Ada toolchain (Alire layout) ---
# The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
. "$HERE/../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }

gprbuild -P wl_host.gpr -q
exec ./wl_host
