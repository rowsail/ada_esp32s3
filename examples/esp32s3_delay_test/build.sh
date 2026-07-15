#!/bin/bash
# IDF-free build of the SYSTIMER-alarm delay-accuracy test via the shared
# bare-boot.  Needs the embedded profile (UART/Serial Sessions use finalization).
HERE="$(cd "$(dirname "$0")" && pwd)"
export ESP32S3_RTS_PROFILE=embedded
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
