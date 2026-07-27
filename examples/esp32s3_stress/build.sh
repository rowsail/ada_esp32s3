#!/bin/bash
# RTS stress suite: scheduler tiny-delay storm + cross-core wakeup ping-pong,
# with an on-board stall monitor and JTAG-readable heartbeats (see check.sh).
# Builds under the embedded profile by default; ESP32S3_RTS_PROFILE=full works
# too (the full profile heap-allocates task stacks/ATCBs, so it needs a much
# larger heap).
HERE="$(cd "$(dirname "$0")" && pwd)"
export ESP32S3_RTS_PROFILE=${ESP32S3_RTS_PROFILE:-embedded}
if [ "$ESP32S3_RTS_PROFILE" = "full" ]; then
    export HEAP_SIZE=262144 ENV_STACK_SIZE=32768
else
    export HEAP_SIZE=65536 ENV_STACK_SIZE=16384
fi
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
