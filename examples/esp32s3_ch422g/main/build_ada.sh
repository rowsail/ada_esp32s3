#!/bin/bash
# Build the CH422G-demo Ada (ch422g.gpr) against the PINNED crate runtime into
# a relocatable app_main.o that the bootloader's image links.  Same runtime crate the
# Alire examples consume (crates/esp32s3_rts).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"        # main/
EX="$(cd "$HERE/.." && pwd)"                 # examples/esp32s3_ch422g/
REPO="$(cd "$EX/../.." && pwd)"              # repo root
RTCRATE="$REPO/crates/esp32s3_rts"
DYNDIR="$REPO/crates/xtensa-dynconfig"
DYNCFG="$DYNDIR/xtensa-dynconfig/xtensa_esp32s3.so"


. "$REPO/tools/sdk-env.sh"
esp32s3_toolchain_on_path
esp32s3_build_dynconfig "$DYNDIR" "$DYNCFG"
export XTENSA_GNU_CONFIG="$(realpath "$DYNCFG")"

# The drivers target the embedded profile (full exceptions); select it so
# gen_runtime builds that RTS and the gpr resolves its Runtime_Path.  (build.sh
# already exports this when invoked via bare_build; set it here too for a direct
# build_ada.sh run.)
export ESP32S3_RTS_PROFILE="${ESP32S3_RTS_PROFILE:-embedded}"

# Generate the crate runtime (idempotent) and build the skeleton against it.
# gprbuild is invoked directly (not via alr), so make the runtime crate's
# project file (esp32s3_rts.gpr) findable.  The HAL is added by bare_build via
# GPR_PROJECT_PATH (libs/* auto-discovery); when run standalone it resolves by
# the relative `with` in the gpr.
export GPR_PROJECT_PATH="$RTCRATE${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
bash "$RTCRATE/gen_runtime.sh"
( cd "$EX" && gprbuild -p -P ch422g.gpr )
cp "$EX/obj/ada_app.o" "$HERE/app_main.o"
echo "[build_ada] done: $HERE/app_main.o"
