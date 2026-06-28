#!/bin/bash
# IDF-free build via the shared bare-boot (examples/common/bare).
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
