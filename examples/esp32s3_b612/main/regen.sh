#!/bin/bash
# Regenerate the B612 atlases via the shared font generator.
HERE="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$HERE/../../../libs/esp32s3_hal/tools/gen_font.py" \
  --ttf "$HERE/B612-Regular.ttf" --name b612 --sizes 12,16,24 \
  --range 0x20-0xFF --bpp 4 --header-dir "$HERE" --ada-dir "$HERE/../src"
