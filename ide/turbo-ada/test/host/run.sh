#!/bin/bash
# Build and run Turbo Ada's host tests (buffer + undo, message parsing,
# highlighting, project detection).  Native toolchain only; no terminal.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

AL="$HOME/.local/share/alire/toolchains"
NATIVE="$(ls -d "$AL"/gnat_native_* 2>/dev/null | sort | tail -1)"
GPR="$(ls -d "$AL"/gprbuild_* 2>/dev/null | sort | tail -1)"
[ -n "$NATIVE" ] && PATH="$NATIVE/bin:$PATH"
[ -n "$GPR" ]    && PATH="$GPR/bin:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }

gprbuild -P tada_host.gpr -q -p
./tada_host "$(cd "$HERE/../../../.." && pwd)"
