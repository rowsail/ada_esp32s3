#!/bin/bash
# Build and run Turbo Ada's host tests (buffer + undo, message parsing,
# highlighting, project detection).  Native toolchain only; no terminal.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
. "$HERE/../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }

gprbuild -P tada_host.gpr -q -p
SDK="$(cd "$HERE/../../../.." && pwd)"
./tada_host "$SDK"

# The other side of the IDE's protocol: the --machine filter in ./x.
OUT="$(cd "$SDK" && bash -c '
    source ./x
    MACHINE_DIRS="$PWD/examples/esp32s3_gpio0_blink $PWD/libs"
    printf "%s\n" "[bare] 1/4  Ada -> app_main.o" \
        "main.adb:18:19: error: expected type" \
        "gpio.adb:3:01: warning: unused [-gnatwu]" \
        "x.adb:4: missing semicolon" \
        "plain tool output" | machine_filter')"
EXPECT="@x stage 1/4 Ada -> app_main.o
@x diag error $SDK/examples/esp32s3_gpio0_blink/src/main.adb:18:19: error: expected type
@x diag warning $SDK/examples/esp32s3_gpio0_blink/src/gpio.adb:3:01: warning: unused [-gnatwu]
@x diag error x.adb:4:1: missing semicolon
plain tool output"
if [ "$OUT" != "$EXPECT" ]; then
    printf 'FAIL  machine_filter: got\n%s\nexpected\n%s\n' "$OUT" "$EXPECT"
    exit 1
fi
echo "machine_filter: ok"

# ./x env names the target, and a suite's environment is the native one.
(cd "$SDK" && ./x env dns_host 2>/dev/null | grep -qx 'TARGET=native') \
    || { echo "FAIL  ./x env dns_host is not native"; exit 1; }
echo "x env (native suite): ok"
