# Multi-sensor dashboard on an ST7789 display — bare-metal Ada (ESP32-S3)

Drives **four** reusable HAL drivers onto one 240×240 SPI panel, cycling through
a view per sensor — **5 seconds each**, forever:

| View | Driver | Bus | Shows |
|---|---|---|---|
| **GPS** | `ESP32S3.GPS` | UART0 | live UTC, latitude, longitude, fix mode + sats |
| **ENV** | `ESP32S3.SHT41` | I2C0 0x44 | temperature, relative humidity |
| **RTC** | `ESP32S3.PCF85063A` | I2C0 0x51 | calendar date, time, weekday |
| **IMU** | `ESP32S3.QMI8658C` | I2C0 0x6B/0x6A | 3-axis acceleration (g), die temperature |

Text is rendered with the `ESP32S3.ST7789.Text` 5×7 font layer.

```
[dash] == GPS : NMEA receiver ==
[dash] UTC 03:46:35
[dash] Lat 33.9724730 N
[dash] Lon 084.3321450 W
[dash] Fix 3D Sat 08
[dash] == ENV : SHT41 temp/humid ==
[dash] Temp 26.03 C
[dash] Hum  49.30 %
[dash] == RTC : PCF85063A clock ==
[dash] Date 2000-01-01
[dash] Time 00:39:43
[dash] Day  Sat (unset)
[dash] == IMU : QMI8658C 6-axis ==
[dash] Ax +0.41 g
[dash] Ay +0.06 g
[dash] Az +0.85 g
[dash] Temp 26.85 C
```

The panel is the real output — the console mirrors each row pushed to it so a
live run can be checked over serial too (the display is write-only).

At power-on it shows a **240×240 Ada-mascot splash** for ~2.5 s, then begins the
cycle.

## Startup splash

The textless Ada mascot is rasterised to a 240×240 RGB565 image and blitted
full-screen with `ESP32S3.ST7789.Draw_Bitmap` before the dashboard starts:

- `ada_logo.svg` — the source art (a copy of `book/AdaNoText.svg`).
- `gen_ada_logo.py` — rasterises the SVG (Inkscape) and emits the pixel
  table (Pillow). Re-run only if the art or size changes.
- `src/ada_logo.ads` — the generated pure-Ada package: the 57 600-element
  `Pixels` `Color_Array` aggregate, blitted with the normal driver call (a
  scalar aggregate this size compiles in well under a second).

```sh
./gen_ada_logo.py     # ada_logo.svg -> src/ada_logo.ads  (needs inkscape + Pillow)
```

## How it works

Each view does `Header` (clear the panel, draw a scale-3 title + scale-1
subtitle) once on entry, then refreshes its value rows once a second for five
seconds before the next view. Value rows are rendered at scale 2 and **padded to
a fixed width**, so each opaque redraw overwrites the previous value (the
write-only panel has no framebuffer to clear selectively).

### One display, four sensors, no contention
- The **display** is held in **one `Session` for the whole run**, so no task can
  corrupt the controller, while each text update locks the SPI host only for its
  own transfers (the driver's two-level locking).
- The **GPS** is a background task publishing into a protected store; the
  dashboard reads consistent snapshots (latitude/longitude are one atomic record).
- The **three I2C parts share one bus** (SDA=IO8, SCL=IO7). Each driver opens a
  short-lived I2C `Session` per read and releases it, so they coexist on the bus
  with no global lock.

### Formatting
No `Text_IO` on bare metal — integers are formatted to fixed-width strings by
hand: GPS 1e-7-degree integers → `DD.DDDDDDD` + hemisphere; SHT41 milli-units and
the IMU's raw counts (scaled by `Accel_LSB_Per_G`) → `NN.NN`.

## Wiring

| Signal | ESP32-S3 | notes |
|---|---|---|
| GPS TXD → | **IO44** (U0RXD) | NMEA in (9600 baud) |
| → GPS RXD | **IO43** (U0TXD) | out to receiver (unused here) |
| I2C SDA | **IO8** | shared by SHT41 / RTC / IMU |
| I2C SCL | **IO7** | shared |
| LCD SCLK / MOSI | **IO12 / IO13** | SPI2 (write-only) |
| LCD DC / CS | **IO16 / IO10** | data-command / chip-select |
| LCD BLK | **IO6** | backlight — driven by the example, not the driver |
| LCD RST | *not wired* | software reset |

## Build / flash / run

```sh
./x build gps_display            # -> app.bin (embedded profile)
./x flash gps_display -p /dev/ttyACM0
./x run   gps_display -p /dev/ttyACM0
```

## Notes

- The GPS needs sky view to lock; until then the GPS view shows `--` placeholders
  and `* searching`.
- **The RTC is set from GPS UTC on the first fix** (one time): once the GPS has a
  position lock with a valid date + time, `Sync_RTC_From_GPS` loads that UTC into
  the PCF85063A (deriving the weekday, which NMEA doesn't carry, via Sakamoto's
  algorithm). `Set_Time` clears the oscillator-stop flag, so the RTC then reads
  `Valid`; the RTC view's `Src` line shows `GPS UTC`. Before the first lock it
  shows `awaiting GPS` (or `battery` if the RTC was already running). The UTC
  snapshot can be ~1 s old (no PPS alignment), which is fine for a wall clock.
- The IMU "satellites of gravity" sanity check: at rest the three axes sum to
  ≈1 g; this sensor reads ≈0.94 g uncalibrated (expected, per the QMI8658C
  example).
- GPS "Sat" is `Fix.Satellites` (used in the GGA solution) — stable, unlike the
  per-constellation GSV in-view count.
- All four drivers use controlled `Session`s / a task, so this targets the
  **embedded / full** profiles, not light-tasking.
