# GT911 — 5-point capacitive touch over I2C (ESP32-S3, no FreeRTOS)

The reusable **`ESP32S3.GT911`** driver — a Goodix GT911 five-point capacitive
touch controller — on the Waveshare ESP32-S3-Touch-LCD-7.

```
[gt911] GT911 5-point touch demo
[gt911]   I2C0 SDA=IO8 SCL=IO9 INT=IO4; reset via CH422G IO1
[gt911] panel resets released (expander IO = 0x1E)
[gt911] product id : "911" fw 0x1060
[gt911] output range : 800 x 480
[gt911] touch: n=1  id 0 @ ( 400, 240) size 21
[gt911] touch: n=2  id 0 @ ( 390, 250) size 24  id 1 @ ( 610, 180) size 19
[gt911] release
```

One line per fresh coordinate report, then `release` when all fingers lift. Each
finger reports a **track id** (stable while that finger stays down, so you can
follow a drag), an X/Y position, and a contact size.

## The reset that catches everyone

The GT911's `RST` pin is **not a GPIO** on this board — it is pin **IO1 of the
CH422G I/O expander**, on the same I2C bus. Until it goes high the chip sits in
reset and **ACKs nothing**, so the symptom is a touch controller that appears not
to exist.

Writing `0x1E` to the expander's IO byte releases the touch *and* LCD resets and
turns the backlight on — the value the board's LCD demos use.

Two failure lines map to that directly:

* `[gt911] CH422G bus error -- is this the right board?` — the expander itself
  did not answer, so the reset was never released.
* `[gt911] no ACK at 0x5D -- touch chip not responding` — the expander answered
  but the GT911 did not. Check that the `0x1E` write actually took.

`product id : "911"` is the identity check: the chip reports its part number as
ASCII, so a plausible-looking but wrong value means you are talking to something
else at that address.

## Hardware

**Waveshare ESP32-S3-Touch-LCD-7.**

| signal | pin |
|---|---|
| I2C0 SDA | IO8 |
| I2C0 SCL | IO9 |
| INT | IO4 |
| RST | CH422G expander IO1 (same bus) |

GT911 answers at address **0x5D**. `Read_Touches` is polled at 50 Hz.

## Build & flash

```sh
./x run esp32s3_gt911                # build + flash + monitor
```

Embedded profile (`build.sh` sets it).

## See also

`esp32s3_ch422g` drives the expander on its own; `esp32s3_lcd` brings up the
panel this touchscreen sits on.
