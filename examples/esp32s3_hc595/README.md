# 74HC595 — a shift-register string over SPI (ESP32-S3, no FreeRTOS)

A daisy-chained string of **74HC595** shift registers driven over SPI: MOSI →
`SER`, SCLK → `SRCLK`, plus a GPIO `RCLK` latch and a GPIO `/OE`.

It walks a single high output across the whole string — a "chase" — so you can
watch it on LEDs or a scope and confirm three things at once: **the wiring, the
chip count, and the bit/chip ordering**.

```
=== 74HC595 string -- chase test ===
24 outputs; chasing...
  Q 0 high
  Q 1 high
  Q 2 high
  ...
```

The console tells you which output *should* be high. If the LED that lights is
not the one named, the ordering is wrong — either the chips are chained in the
opposite order to what the code assumes, or the bit order within a byte is
reversed. That is the whole diagnostic value of a chase over just setting a
pattern.

## Wiring

Confirm or edit the constants at the top of `src/main.adb`:

| signal | pin | 74HC595 |
|---|---|---|
| SCLK | IO1 (SPI2) | `SRCLK` |
| MOSI | IO4 (SPI2) | `SER` |
| RCLK | IO5 | `RCLK` (latch) |
| /OE | IO6 | `/OE` (output enable) |

`Chips : constant := 3` — three chips daisy-chained, so **24 outputs**. Change it
to match your string; the printed count is derived from it, so a wrong value
shows up immediately as a chase that wraps early or late.

SCLK and MOSI are the board's shared SPI2 pads, so the 595 string coexists with
other SPI devices on the same bus — `RCLK` is what makes the shifted bits appear,
so nothing is disturbed while another device is selected.

## Build & flash

```sh
./x run esp32s3_hc595                # build + flash + monitor
```

Embedded profile (`build.sh` sets it). Then watch the outputs alongside the
console.
