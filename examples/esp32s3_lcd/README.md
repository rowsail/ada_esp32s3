# RGB LCD — tear-free double buffering at 800×480 (ESP32-S3, no FreeRTOS)

The Waveshare **ESP32-S3-Touch-LCD-7** (800×480 RGB565) driven by
`ESP32S3.LCD` in RGB mode, with **two framebuffers that ping-pong**: the app
draws into the hidden one, then `Flip` shows it whole at a frame boundary, so a
frame is never seen mid-draw.

The panel is refreshed from small **internal-SRAM bounce buffers** that a GDMA
ISR refills from the shown framebuffer. That indirection is what makes scan-out
immune to the app's drawing into PSRAM.

A white box hops the four corners once every two seconds. The frame is rock-steady
between hops and **never tears** — that is the whole output; this example prints
nothing to the console.

## The rule this example exists to demonstrate

**Draw only what changed.**

An 800×480 RGB565 framebuffer is **768 KB**. Redrawing all of it on every flip
saturates the single PSRAM bus against the DMA refill, the refill starves, and
the picture slips. Touching only the moving box — a few KB — leaves the refill
plenty of bus, and the frame stays locked.

This is not a micro-optimisation, it is the difference between a stable picture
and a visibly broken one, and it is why the framebuffers live in PSRAM while the
bounce buffers do not.

## Hardware

Waveshare **ESP32-S3-Touch-LCD-7**. The RGB data lines and the four control
signals are wired in `src/main.adb`:

* 16 data lines across IO0–IO2, IO10, IO14, IO17, IO18, IO21, IO38–IO42, IO45,
  IO47, IO48
* `Pclk` = IO7, `HSync` = IO46, `VSync` = IO3, `DE` = IO5
* panel reset and backlight are released through the **CH422G** expander on I2C
  (SDA = IO8, SCL = IO9), by writing `0x1E`

`Signals => LCD.Identity_Signals` says the panel's data lines are wired straight
through — RGB bit *N* leaves on `Data (N)`. Boards that fan the bits out
differently override that map rather than rewiring the framebuffer format.

PSRAM is required: `bare_board_init` re-maps the PSRAM d-bus so the
`.ext_ram.bss` framebuffers are backed by real external RAM.

## Build & flash

```sh
./x run esp32s3_lcd                  # build + flash + monitor
```

Embedded profile (`build.sh` sets it).

## See also

`esp32s3_lcd_i8080` is the same peripheral in 8-bit i80 parallel mode;
`esp32s3_gt911` reads the touch panel bonded to this display.
