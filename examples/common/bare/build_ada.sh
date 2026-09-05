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
RTS_DIR="$RTCRATE/${ESP32S3_RTS_PROFILE:-light-tasking}-esp32s3"

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

#  A CHANGED RUNTIME MUST FORCE A RELINK.  gprbuild tracks the project's own
#  sources, not the runtime it links against -- and this build is a RELOCATABLE
#  PARTIAL LINK (-Wl,-r), so obj/ada_app.o has the runtime's objects baked into
#  it.  Rebuild the runtime (edit gen_runtime.sh, bump the pack, switch profile)
#  and gprbuild still calls the example "up to date": the stale ada_app.o keeps
#  the OLD runtime code and the change silently does not take.  Measured: a fixed
#  s-taprop.o sat in adalib while the flashed image kept the broken one, and the
#  bug appeared unfixed.  Compare against the runtime archive and force it.
RTS_STAMP="$(ls -t "$RTS_DIR"/adalib/libgnarl.a "$RTS_DIR"/adalib/libgnat.a 2>/dev/null | head -1)"
if [ -n "$RTS_STAMP" ] && [ -f "$EX/obj/ada_app.o" ] \
   && [ "$RTS_STAMP" -nt "$EX/obj/ada_app.o" ]; then
    echo "[build_ada] runtime is newer than obj/ada_app.o -- forcing a rebuild"
    rm -f "$EX/obj/ada_app.o" "$EX/obj/app_main.o"
    FORCE_BUILD=-f
fi
( cd "$EX" && gprbuild -p ${FORCE_BUILD:-} -P "$(basename "${GPRS[0]}")" "${STACK_CARGS[@]}" )
cp "$EX/obj/ada_app.o" "$EX/obj/app_main.o"
echo "[build_ada] done: $EX/obj/app_main.o"
