#!/bin/bash
# 74HC595 shift-register chase.  Needs the embedded profile (the SPI Session is a
# controlled type).
HERE="$(cd "$(dirname "$0")" && pwd)"
export ESP32S3_RTS_PROFILE=embedded
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
