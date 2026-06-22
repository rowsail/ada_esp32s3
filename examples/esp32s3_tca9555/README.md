# TCA9555 GPIO expander — a bare-metal Ada I2C driver (ESP32-S3)

Demo for the reusable **`ESP32S3.TCA9555`** driver (in `libs/esp32s3_hal`) — a
16-bit I2C GPIO expander (two 8-bit ports, address `0x20 + A2A1A0`, up to 8 on a
bus).

```
[gpio] TCA9555 16-bit I2C GPIO expander demo (0x20, SDA=IO8 SCL=IO7)
[gpio] probe   : inputs=0xff77  (present)
[gpio] out-reg : wrote=0xa55a read=0xa55a  PASS
[gpio] out-reg : wrote=0x5aa5 read=0x5aa5  PASS
[gpio] pin 5   : set=1  out-bit=1  PASS
[gpio] pin 5   : set=0  out-bit=0  PASS
[gpio] pol-reg : wrote=0xa55a read=0xa55a  PASS
[gpio] done.
```

## Two-level locking (what this driver is built around)

Unlike the RTC — whose `Session` *is* the I2C-host lock — this driver separates
the two so a held device doesn't tie up the whole bus:

- **`Session`** is an exclusive, RAII hold on **one expander**. Hold it across
  as many operations as you like; it keeps other tasks off *that chip* (so a
  per-pin read-modify-write is safe).
- The **I2C host** is locked only *inside* each read/write, then released — so
  while you hold an expander's `Session` the bus is free between your
  transactions, and another task can drive a different expander (or the RTC /
  IMU / SHT41) in the gaps.

```ada
Acquire (S, Exp);          -- lock THIS chip (bus untouched)
  Write_Port (S, …, St);   -- briefly lock I2C → transact → release
   … bus free for others …
  Read_Port  (S, V, St);   -- briefly lock I2C → transact → release
Release (S);               -- unlock chip (auto on scope exit)
```

The per-device guards are a fixed library-level array keyed by `(host, strap)` —
the same shape as `ESP32S3.I2C`'s per-host guards — so no protected object lives
in a `Device` (which would be a forbidden local PO).

## Wiring

| TCA9555 | ESP32-S3 | notes |
|---|---|---|
| SDA | **IO8** | I2C0 data (shared bus) |
| SCL | **IO7** | I2C0 clock (shared bus) |
| A0/A1/A2 | GND | strap = 0 → address **0x20** |
| INT | *not connected* | active-low open-drain; `Int_Pin` defaults to `No_Pin` |

`Setup` takes the strap value `Addr` (0..7 → 0x20..0x27). The `.Interrupts` child
mirrors the RTC's (falling edge) but is unexercised here since INT isn't wired.

## What the demo does

This board's expander pins read a fixed external pattern (`0xff77`), so the demo
**never drives a pin** — it keeps every pin an input and proves the driver via
register round-trips: read the input port, write+read the output register (which
stores the value even while the pins stay inputs, so nothing is driven), do a
per-pin RMW of the output register, and write+read the polarity register. To
actually drive outputs (e.g. LEDs on free pins), call `Set_Directions` to make
them outputs and `Write_Port` / `Write_Pin`.

The driver exposes both **whole-port** (16-bit `Port_Value`) and **per-pin**
operations: `Set_Directions`/`Set_Direction`, `Write_Port`/`Write_Pin`,
`Read_Port`/`Read_Pin`, `Set_Polarity`, plus `Read_Directions`/`Read_Outputs`/
`Read_Polarity` to read configured state back.

## Build / flash / run

```sh
./x build tca9555            # -> app.bin (embedded profile)
./x flash tca9555 -p /dev/ttyACM0
./x run   tca9555 -p /dev/ttyACM0
```

## Notes

- On this board's part the polarity-inversion *register* accepts writes and reads
  back correctly, but the chip does not actually invert the input — a quirk of
  the part, not the driver (every register read/write round-trips).
- Uses controlled `Session`s, so like the other Session drivers it targets the
  **embedded / full** profiles, not light-tasking.
