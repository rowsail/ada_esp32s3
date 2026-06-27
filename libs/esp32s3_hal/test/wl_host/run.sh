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
AL="$HOME/.local/share/alire/toolchains"
NATIVE="$(ls -d "$AL"/gnat_native_* 2>/dev/null | sort | tail -1)"
GPR="$(ls -d "$AL"/gprbuild_* 2>/dev/null | sort | tail -1)"
[ -n "$NATIVE" ] && PATH="$NATIVE/bin:$PATH"
[ -n "$GPR" ]    && PATH="$GPR/bin:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }

gprbuild -P wl_host.gpr -q
exec ./wl_host
