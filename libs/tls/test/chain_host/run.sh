#!/bin/bash
#  Build and run the certificate-chain validation test.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"; cd "$HERE"
AL="${ESP32S3_ADA_TOOLCHAINS:-$HOME/.local/share/alire/toolchains}"
NATIVE="$(ls -d "$AL"/gnat_native_* 2>/dev/null | sort | tail -1)"
GPR="$(ls -d "$AL"/gprbuild_* 2>/dev/null | sort | tail -1)"
[ -n "$NATIVE" ] && PATH="$NATIVE/bin:$PATH"; [ -n "$GPR" ] && PATH="$GPR/bin:$PATH"; export PATH
python3 make_chain.py >/dev/null
gprbuild -P chain_host.gpr -q
./chain_host
