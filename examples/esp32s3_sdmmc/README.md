# Native SD/MMC host — bare-metal Ada (ESP32-S3, no FreeRTOS)

Self-test for the reusable **`ESP32S3.SDMMC`** driver (in `libs/esp32s3_hal`) — the
*native* SD host (the dedicated SDHOST controller, clock + command + 1/4 data
lines), as opposed to `ESP32S3.SD_SPI` which talks to a card over SPI. It brings
the controller up and does a **non-destructive** round-trip on one scratch sector.

```
[sdmmc] bare-metal native SD/MMC-host self-test (needs a wired card)
[sdmmc] init: OK   card: SDHC/SDXC   bus: 4-bit
[sdmmc] read#1: OK   first bytes = .. .. .. ..
[sdmmc] write-back: OK
[sdmmc] read#2: OK   first bytes = .. .. .. ..
[sdmmc] round-trip (re-read == original): PASS
[sdmmc] done.
```

With **no card wired** it prints `init: No_Card` and stops cleanly — which is what
the in-tree smoke build shows (boots, runs the init path on silicon, reports
`No_Card`, 0 panics). The PASS line needs a real card.

> **Maturity:** the driver *is* card-verified, but in **1-bit** mode, not the
> 4-bit bus this example brings up. [`esp32s3_sdmmc_ch422g`](../esp32s3_sdmmc_ch422g)
> identifies a real SDHC card and reads block 0 at 50 MHz, and
> [`esp32s3_ext4_sdmmc`](../esp32s3_ext4_sdmmc) /
> [`esp32s3_ext4_write`](../esp32s3_ext4_write) mount and write a real ext4
> filesystem over it. What is unproven here is the 4-bit wiring and its
> clock-tree details (the SDHOST functional clock source, `Src_Hz`, CLK-edge
> phase), which want a card on a scope to tune.

## Wiring

Route any free GPIOs through the GPIO matrix; **pull-ups (10k–50k) on CMD and every
DATA line** (the SD bus idles high). 1-bit needs only D0; 4-bit needs D0–D3.

| SD pin | signal | default GPIO |
|--------|--------|--------------|
| CLK    | CLK    | **GPIO14**   |
| CMD    | CMD    | **GPIO15**   |
| DAT0   | D0     | **GPIO2**    |
| DAT1   | D1     | **GPIO4**    |
| DAT2   | D2     | **GPIO12**   |
| DAT3   | D3     | **GPIO13**   |
| VDD    | 3V3    | 3V3          |
| VSS    | GND    | GND          |

Edit the pins / slot / width at the top of `src/main.adb`.

## What it checks

The card is identified at ≤400 kHz (CMD0/8 → ACMD41 → CMD2/3/7 → ACMD6 width →
CMD16), the bus is raised to `Data_Clock_Hz` (default 20 MHz), then it **reads**
sector `0x2000`, **writes the same bytes back**, and **reads again** — the re-read
must equal the original. The bytes written are exactly what was just read, so no
card data is lost.

Data moves in **PIO/FIFO mode** (the CPU pushes/pops the block through the
controller FIFO) — no DMA, no finalization, so the driver works under **every**
runtime profile (light-tasking included), serialised by an internal protected
object.

## Concurrency

Each public operation (`Initialize` / `Read_Block` / `Write_Block`) runs inside a
single library-level protected object, so the one shared SDHOST controller is
serialised: a second task suspends until the first operation completes, and the
protected object releases on exit (including on exception). Because there is only
one controller for both slots, **all** access serialises — even two cards on Slot1
vs Slot2. The lock is held across the whole block transfer (including the FIFO
busy-polls), so there is no concurrency *during* a transfer. The lock keeps the
hardware consistent; coordinating *which* task writes *what* is still the app's job.

`Setup` is **not** locked — call it once at startup, single-threaded, before any
task contends for the controller.

## Build & flash

```sh
./x run esp32s3_sdmmc           # build + flash + monitor
```

Built as the **embedded** profile here. The report prints over the USB-Serial-JTAG
console via the ROM `esp_rom_printf` glue in `glue.c`.
