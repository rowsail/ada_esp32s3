#!/bin/bash
# tada-cli on a board: the debugger stepping a dual-core program.  Needs an
# ESP32-S3 on USB (./x ports finds it) and USB access for OpenOCD; not part
# of test/cli (no board there).
#
# examples/esp32s3_smp keeps core 1 busy (its Producer task) while the steps
# below run on core 0.  OpenOCD shows each core as a GDB thread (debug-server
# --smp); a step must end, and be shown, on core 0 -- not in core 1's code or
# in the runtime's idle loop.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

. "$ROOT/tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
gprbuild -P "$HERE/../../turbo_ada.gpr" -q -p
CLI="$HERE/../../bin/tada-cli"

"$ROOT/x" ports --json | grep -q '"flash":"/dev/' || { echo "board: skipped (no board)"; exit 0; }

W="$(mktemp -d)"
# The SDK's own .turbo_ada (the example's project options) is put back as it was.
[ -f "$ROOT/.turbo_ada" ] && cp -a "$ROOT/.turbo_ada" "$W/turbo_ada"
trap '[ -f "$W/turbo_ada" ] && cp -a "$W/turbo_ada" "$ROOT/.turbo_ada"; rm -rf "$W"' EXIT
export TURBO_ADA_CONFIG="$W/config"

# Build, flash, stop at the Ada main; into Clock and back, into Seconds and back.
"$CLI" -C "$ROOT/examples/esp32s3_smp" debug \
    -e start -e "expect-line 34" \
    -e step -e "expect-line 313" -e finish -e "expect-line 34" \
    -e step -e "expect-line 524" -e finish -e "expect-line 34" > "$W/debug.log" 2>&1 \
    || { cat "$W/debug.log"; exit 1; }
grep -q "a-reatim.adb:313  ada.real_time.clock$" "$W/debug.log"
grep -q "a-reatim.adb:524  ada.real_time.seconds$" "$W/debug.log"
grep -q "^| \[boot\] Ada runtime up on both cores" "$W/debug.log"
echo "board debug (dual-core stepping): ok"
