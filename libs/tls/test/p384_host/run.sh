#!/bin/bash
# Build and run the P384.Verify known-answer test.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
AL="$HOME/.local/share/alire/toolchains"
NATIVE="$(ls -d "$AL"/gnat_native_* 2>/dev/null | sort | tail -1)"
GPR="$(ls -d "$AL"/gprbuild_* 2>/dev/null | sort | tail -1)"
[ -n "$NATIVE" ] && PATH="$NATIVE/bin:$PATH"; [ -n "$GPR" ] && PATH="$GPR/bin:$PATH"; export PATH
gprbuild -P p384_host.gpr -q
./p384_host
