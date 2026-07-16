# B612 font on an ST7789 display — bare-metal Ada (ESP32-S3)

Renders the **B612** typeface (Airbus's cockpit font, SIL OFL 1.1) on a 240×240
ST7789 panel, anti-aliased, at three sizes, through the **panel-agnostic HAL
text engine** — `ESP32S3.Fonts` (data model) + the generic `ESP32S3.Fonts.Render`
(blitting engine), here instantiated as `ESP32S3.ST7789.Fonts`.

```
[b612] anti-aliased B612 font: 12/16/24 px -> ST7789 240x240
[b612]   12px      5498 bytes
[b612]   16px      9093 bytes
[b612]   24px     19486 bytes
```

## Anti-aliasing on a write-only panel

Coverage is **4-bit (16-level)**, 2 px/byte. Each glyph pixel's coverage indexes
a 16-entry **bg→fg colour ramp** built once per string, so anti-aliasing is done
by blending against the *known* background — no framebuffer read-back, which the
panel doesn't support. Spacing is proportional (per-glyph advance).

## Pay only for the sizes you use

Each size is fully independent:

- its glyph data (metrics + packed bitmap) lives in its own pure-Ada package
  (`src/b612_<sz>.ads`) as constant arrays, in its own `-fdata-sections` section,
  with an `ESP32S3.Fonts.Font` constant over them.

So a program links a size's bytes **only if** it `with`s that package. Need only
16 px? `with B612_16;` — 12/24 px are never compiled in (0 bytes). **This demo
includes all three** to show them together; trim the `with`s in `main.adb` for a
real build.

## The text engine (in the HAL, panel-agnostic)

- **`ESP32S3.Fonts`** — the data model: the `Font` descriptor (address-based
  metrics + 4-bit/1-bit coverage), `Text_Width`, an `RGB` colour triple. No
  display dependency, so it compiles under every profile.
- **`ESP32S3.Fonts.Render`** — a *generic* engine parameterised by a panel's
  pixel type, `To_Color`, and `Blit`. It builds each glyph cell by blending FG↔BG
  per coverage (anti-aliasing against a *known* background — no read-back) and
  blits it; the pen advances proportionally.
- **`ESP32S3.ST7789.Fonts`** — a one-line instantiation binding the engine to
  this driver's `Color`/`Draw_Bitmap`. A different panel just adds its own
  instantiation; the atlas data and `Font` values are reused unchanged.

This example calls `ESP32S3.ST7789.Fonts.Draw_Text (S, B612_16.Font, X,
Baseline, Str, FG, BG)` with `FG`/`BG` as `ESP32S3.Fonts.RGB` triples. (Distinct
from the built-in 5×7 `ESP32S3.ST7789.Text`.)

## Glyphs

Printable **Latin-1** (`0x20..0xFF`, 191 glyphs) — the full set addressable from
an Ada `String`. The font also has ~400 codepoints above `0xFF` (Latin
Extended, etc.); reaching those would need UTF-8 input + a cmap lookup (future).

## Regenerating the atlases

The atlases are produced by the **shared, font-agnostic** generator
`libs/esp32s3_hal/tools/gen_font.py` (works on any TTF/OTF). This example wraps
the invocation:

```sh
./regen.sh           # B612-Regular.ttf -> src/b612_<sz>.ads
```

i.e. `gen_font.py --ttf B612-Regular.ttf --name b612 --sizes 12,16,24
--range 0x20-0xFF --bpp 4`. Re-run only when the sizes/range/font change; the
committed headers and Ada packages are the build inputs. Needs Pillow (with
FreeType). `B612-Regular.ttf` and `OFL.txt` are vendored under the example root. (Add a
size by appending to `--sizes`; `--bpp 1` would emit a monochrome atlas.)

## Licensing

B612 is **SIL Open Font License 1.1** (`OFL.txt`) — free to embed and
redistribute; the derived bitmap atlas is a permitted use.

## Build / flash / run

```sh
./x build b612            # -> app.bin (embedded profile)
./x flash b612 -p /dev/ttyACM0
./x run   b612 -p /dev/ttyACM0
```
