#!/bin/bash
# Build one example's Ada (its single *.gpr) against the pinned esp32s3_rts runtime
# into a relocatable obj/app_main.o for the bare-boot link.  Shared by every example
# and invoked by bare_build.sh as `build_ada.sh <example-dir>`, so examples no longer
# carry a per-project copy or a main/ directory.
set -e
EX="$(cd "${1:?usage: build_ada.sh <example-dir>}" && pwd)"
BARE="$(cd "$(dirname "$0")" && pwd)"         # examples/common/bare
REPO="$(cd "$BARE/../../.." && pwd)"          # repo root
RTCRATE="$REPO/crates/esp32s3_rts"
DYNDIR="$REPO/crates/xtensa-dynconfig"
DYNCFG="$DYNDIR/xtensa-dynconfig/xtensa_esp32s3.so"
. "$REPO/tools/sdk-env.sh"                     # toolchain on PATH, Alire-free
esp32s3_toolchain_on_path
esp32s3_build_dynconfig "$DYNDIR" "$DYNCFG"
export XTENSA_GNU_CONFIG="$(realpath "$DYNCFG")"
export GPR_PROJECT_PATH="$RTCRATE${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
bash "$RTCRATE/gen_runtime.sh"

# Exactly one project file per example dir; find it rather than hard-code the name.
shopt -s nullglob
GPRS=( "$EX"/*.gpr )
if [ "${#GPRS[@]}" -ne 1 ]; then
    echo "[build_ada] expected exactly one .gpr in $EX, found ${#GPRS[@]}" >&2
    exit 1
fi

# STACK_ANALYSIS=1 -> emit GCC's per-frame stack-usage (obj/*.su) and call-graph
# (obj/*.ci) files alongside the objects, for `x stack`.  Off by default so normal
# builds are byte-identical.  Passed via -cargs so no .gpr needs editing; covers the
# application's own units (the pinned runtime is prebuilt, so its frames don't appear
# -- the runtime watermark catches those at run time).
STACK_CARGS=()
if [ -n "${STACK_ANALYSIS:-}" ]; then
    STACK_CARGS=(-cargs:Ada -fstack-usage -fcallgraph-info=su,da)
fi

( cd "$EX" && gprbuild -p -P "$(basename "${GPRS[0]}")" "${STACK_CARGS[@]}" )
cp "$EX/obj/ada_app.o" "$EX/obj/app_main.o"
echo "[build_ada] done: $EX/obj/app_main.o"
