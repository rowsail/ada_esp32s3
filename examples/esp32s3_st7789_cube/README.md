# Bouncing hidden-line wireframe cube — bare-metal Ada (ESP32-S3)

A rotating 3D wireframe cube drawn with **hidden-line removal** and
**perspective**, each visible face's edges in its own colour, its window
bouncing around the edges of a 240×240 ST7789 panel. Runs at ~60 fps.

```
[cube] bouncing hidden-line wireframe cube -> ST7789 240x240
[cube]   SPI2 sclk=12 mosi=13 dc=16 cs=10 bl=6
[cube] ~61 fps
```

## How it works

The panel is **write-only** (no framebuffer to read back), so the cube is drawn
into a small in-RAM framebuffer that acts as a **moving window** always
containing the whole cube:

1. **Render** — clear the `FB_W × FB_W` RGB565 framebuffer, rotate + project the
   cube into it, rasterise the visible edges (Bresenham).
2. **Blit** — `ESP32S3.ST7789.Draw_Bitmap` copies the window to its current
   screen position.
3. **Bounce + clean** — the window moves a few pixels per frame and reflects off
   the `0 .. 240 − FB_W` limits. Only the thin strips the window *uncovers* as it
   moves are cleared to black (`Fill_Rect`) — no full-screen clears, so there are
   no trails and no flicker.

### Hidden-line removal

For a convex cube, HLR is exactly **back-face culling**. Each face carries an
outward normal; the normal is rotated with the cube, and the face is drawn only
if it points toward the viewer (rotated normal *z* > 0). Edges shared only by
back faces are never drawn — hidden. From a generic angle exactly 3 faces are
front-facing → 9 of the 12 edges are drawn, and the 3 edges meeting at the far
(hidden) corner are removed. Each visible edge is drawn in the colour of
whichever front face draws it last (shared visible edges are drawn twice, which
is harmless).

### Maths

Fixed-point **Q12 integers** with an embedded 256-entry sine table — no
floating-point and no `libm`/trig dependency. Rotation is about the Y then X
axis. Projection is **perspective**: with the eye on +Z at distance `Eye`, a
vertex maps to `Centre + coord · Focal / (Eye − z)`, so nearer faces project
larger than far ones. `Eye`/`Focal`/`FB_W` were chosen (via a host sweep over
all rotations) so the largest near-face vertex stays inside the window.

## Display wiring

| ST7789 | ESP32-S3 |
|---|---|
| SCLK / MOSI | **IO12 / IO13** (SPI2, write-only) |
| DC / CS | **IO16 / IO10** |
| BLK | **IO6** — backlight, driven by the example |
| RST | *not wired* (software reset) |

## Build / flash / run

```sh
./x build st7789_cube            # -> app.bin (embedded profile)
./x flash st7789_cube -p /dev/ttyACM0
./x run   st7789_cube -p /dev/ttyACM0
```

## Notes

- The framebuffer window (`FB_W = 128`) is sized to hold the rotating cube under
  perspective (near faces project larger). Raising `Focal` / lowering `Eye`
  strengthens the perspective and enlarges the cube; the bounce range is
  `240 − FB_W` each axis.
- Uses the controlled-`Session` display driver, so it targets the **embedded /
  full** profiles, not light-tasking.
