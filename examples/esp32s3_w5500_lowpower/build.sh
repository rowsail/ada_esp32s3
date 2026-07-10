#!/bin/bash
# IDF-free build via the shared bare-boot (examples/common/bare).
# The W5500 driver uses a controlled SPI Session => embedded (or full) profile.
export ESP32S3_RTS_PROFILE=embedded
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
