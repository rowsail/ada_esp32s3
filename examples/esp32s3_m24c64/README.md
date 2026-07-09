# M24C64 EEPROM — a bare-metal Ada I2C driver (ESP32-S3)

Demo for the reusable **`ESP32S3.M24C64`** driver (in `libs/esp32s3_hal`) — an
instantiation of the family generic **`ESP32S3.EEPROM_24C`**. Same shape as the
SHT41/RTC/IMU drivers — a `Device` set up with the I2C wiring, each
operation opening a short-lived, auto-released `ESP32S3.I2C` `Session` — so the
ST M24C64 64-Kbit (8 KiB) serial EEPROM shares the bus safely with the other I2C
devices. No interrupt: it is read and written on request.

```
[rom] M24C64 EEPROM driver demo (SDA=IO41 SCL=IO40)
[rom] address: 0x50  (M24C64 present)
[rom] boot count: 6  (rises by one on every reset)
[rom] page-crossing write/read: PASS
[rom] 0x0110: 5c 67 6e 69 70 7b 82 8d 94 9f a6 a1 a8 b3 ba c5
[rom] done.
```

## Wiring

| M24C64 | ESP32-S3 | notes |
|---|---|---|
| SDA | **IO41** | I2C0 data |
| SCL | **IO40** | I2C0 clock |
| VCC / VSS | 3V3 / GND | |
| WC | GND | write control — high write-protects the array |
| A0 / A1 / A2 | GND | chip-enable straps: address **0x50** |

The part answers at `0x50 + A2*4 + A1*2 + A0`, so up to eight share one bus. Tie
a strap high and tell `Setup` about it:

```ada
ESP32S3.M24C64.Setup (Rom, Sda => 41, Scl => 40, A0 => High, A2 => High);
--  -> 0x55;  ESP32S3.M24C64.Device_Address (A0 => High, A1 => Low, A2 => High)
```

If the part does not ACK at the configured address, the demo probes all eight
strap combinations and prints whichever one answers — so a mis-strapped board
tells you its real address instead of just failing.

## What it does

* **strap** — print the address the straps select, then probe it.
* **boot** — a one-byte counter in the last cell (0x1FFF), read, incremented and
  written back on every run. It rises by one per reset: the data really is
  non-volatile. (A blank part reads `0xFF`; the demo starts counting from 0.)
* **page** — write a 40-byte pattern at `0x0110` and read it back. That start
  address sits 16 bytes into a page, so the payload straddles a 32-byte page
  boundary — the split the driver has to get right. The pattern is varied by the
  boot count, so a stale read-back cannot pass by accident.
* **dump** — the head of what came back off the part.

## What the driver handles for you

The M24C64's raw protocol has three sharp edges; `ESP32S3.M24C64` hides all
three behind `Read`/`Write` of an arbitrary `Byte_Array` at an arbitrary address:

* **Page boundaries.** A write may not cross a 32-byte page — the part wraps to
  the start of the page instead of advancing, silently corrupting data. `Write`
  splits its payload on page boundaries.
* **The program cycle.** Each page write starts a ~5 ms internal write during
  which the chip NACKs everything. `Write` ACK-polls the part back to readiness
  rather than blindly sleeping the worst case.
* **Random read needs a repeated START.** The address is written, then the bus
  turns around *without* a STOP — a STOP would end the command. `Read` issues
  one `ESP32S3.I2C.Write_Read`, so a read of any length is a single transaction
  and the part's address counter walks the array.

Neither `Read` nor `Write` is capped by the controller's 32-byte FIFO:
`ESP32S3.I2C` refills (or drains) it mid-transaction without releasing the bus,
so a whole page (2 address bytes + 32 data) goes out as the single segment the
part requires. That **full 32-byte page write** is worth ~2× on bulk writes: one
~5 ms program cycle per page instead of two. Measured on this board, 1024 bytes
(32 aligned pages) takes **131 ms**; when the driver was capped at 29 data bytes
per segment it took **239 ms**.

A `Write` holds the I2C host across every page and program cycle, so a multi-page
write is atomic with respect to other tasks sharing the bus.

## Other parts in the family

`ESP32S3.M24C64` is three lines:

```ada
package ESP32S3.M24C64 is new ESP32S3.EEPROM_24C
  (Capacity_Bytes => 8_192, Page_Bytes => 32, Word_Address_Bytes => 2);
```

The generic derives the rest, including how many chip-enable straps survive. Parts
below 32 Kbit take a one-byte word address and fold their high address bits into
the device-select byte, eating a strap each (E0 first) — a 24C16 folds all three,
so it has no strap at all and only one can sit on a bus. `Setup`'s precondition
enforces that per instance: `24C16.Setup (…, A0 => High)` raises.

| | `Capacity_Bytes` | `Page_Bytes` | `Word_Address_Bytes` | devices/bus |
|---|---|---|---|---|
| 24C02 | 256 | 8 (ST: 16) | 1 | 8 |
| 24C04 | 512 | 16 | 1 | 4 |
| 24C08 | 1024 | 16 | 1 | 2 |
| 24C16 | 2048 | 16 | 1 | 1 |
| 24C64 | 8192 | 32 | 2 | 8 |
| 24C256 | 32768 | 64 | 2 | 8 |
| M24M01 | 131072 | 256 | 2 | 4 |
| M24M02 | 262144 | 256 | 2 | 2 |

Microchip's 24LC1025/1026 additionally cannot read across their 512-Kbit block, so
they pass `Max_Read_Span => 65_536`. Only the M24C64 instance is hardware-verified
here; the others rest on the datasheets alone.

## Build & run

```
./x run esp32s3_m24c64
```

The driver uses the controlled I2C `Session` (finalization), so this builds on
the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`), not
the default light-tasking.
