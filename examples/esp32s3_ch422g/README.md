# CH422G I/O expander — a bare-metal Ada I2C driver (ESP32-S3)

Demo for the reusable **`ESP32S3.CH422G`** driver (in `libs/esp32s3_hal`) — the
WCH CH422G: 8 bidirectional pins (IO0–IO7) + 4 output-only pins (OC0–OC3) over
I2C. **Read-only:** it never drives a pin, so it can't disturb whatever the
CH422G's outputs are wired to on the board.

```
[ch422g] CH422G I2C I/O expander demo (read-only)
[ch422g]   I2C0 SDA=IO8 SCL=IO9; addrs 0x24/0x23/0x38/0x26
[ch422g] probe 0x24 : ACK (present)
[ch422g] IO inputs = 0x9f  IO7..IO0 = 10011111
```

## A multi-address command device (not a register-pointer chip)

Unlike the TCA9555, the CH422G has no register pointer. Each operation is a
single-byte transaction to a **fixed, function-specific I2C address**:

| Function | 7-bit addr | Transaction |
|---|---|---|
| Set system config (WR-SET) | **0x24** | write `[SLEEP]·0·0·[OD_EN]·0·[A_SCAN]·0·[IO_OE]` |
| Set OC outputs (WR-OC) | **0x23** | write `0000·OC3..OC0` |
| Set IO outputs (WR-IO) | **0x38** | write IO7..IO0 |
| Read IO inputs (RD-IO) | **0x26** | read IO7..IO0 |

So there is **one CH422G per bus** (no address straps) — `Setup` takes no address.

## Behaviour vs. the TCA9555

- **IO direction is global** — one `IO_OE` bit makes *all* IO0–7 inputs or *all*
  outputs (no per-pin direction). OC0–3 are output-only, globally push-pull or
  open-drain (`OD_EN`).
- **No interrupt pin** on the chip → no `.Interrupts` child.
- **Write registers can't be read back** (only IO pins, via RD-IO), so the driver
  keeps a shadow of config / IO-out / OC-out, initialised to the datasheet
  power-on defaults (IO = inputs, OC = high, push-pull).

## Two-level locking (same shape as the TCA9555)

A `Session` is an exclusive RAII hold on the device (acquired like the RTC); the
**I2C host** is locked only *inside* each transaction (open a short-lived
`ESP32S3.I2C.Session`, transact, release), so the bus is free between operations.
The per-device guards are a library-level array keyed by the I2C host (one
CH422G per bus), so no protected object lives in a `Device`.

## What the demo does

`Setup` (SDA=IO8, SCL=IO9, I2C0), `Acquire`, then probe the chip (address-only
ACK on 0x24) and read IO0–7 once a second. The CH422G powers up with IO0–7 as
inputs (I/O-expansion mode), so reads reflect the external pin levels without
configuring anything.

The driver also exposes `Configure` (global IO direction + OC drive), `Sleep`,
`Write_IO`/`Write_IO_Pin`, `Read_IO`/`Read_IO_Pin`, `Write_OC`/`Write_OC_Pin` —
deliberately unused here to keep the example read-only.

## Build / flash / run

```sh
./x build ch422g            # -> app.bin (embedded profile)
./x flash ch422g -p /dev/ttyACM0
./x run   ch422g -p /dev/ttyACM0
```

## Notes

- Uses a controlled `Session`, so like the other Session drivers it targets the
  **embedded / full** profiles, not light-tasking.
- This board wires the I2C bus to **SDA=IO8, SCL=IO9** (note: different from the
  TCA9555 board's SDA=IO8/SCL=IO7).
