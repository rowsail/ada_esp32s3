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

Every part is one `Geometry` in the catalogue `ESP32S3.EEPROM_24C`, instantiated as
a child unit, so `with`ing one part costs one part:

```ada
with ESP32S3.EEPROM_24C.M24M01;
...
Rom : ESP32S3.EEPROM_24C.M24M01.Device;
```

Shipped: `M24C01` `M24C02` `M24C04` `M24C08` `M24C16` `M24C32` `M24C64` `M24128`
`M24256` `M24512` `M24M01` `M24M02`, plus `AT24C01`/`AT24C02` (Atmel and Microchip
1K/2K parts have an **8**-byte page where ST's have 16 — guessing wrong corrupts
data silently) and `LC1026` (Microchip 24LC1026, whose sequential read cannot cross
its 512-Kbit block). Microchip's 24LC1025 puts its block bit in the *high*
select-byte position and is deliberately absent — the driver's addressing model
cannot express it.

**Only `M24C64` is hardware-verified.** The others are transcribed from datasheets;
each instance exports `Hardware_Verified : constant Boolean` and says so in a banner
at the top of its spec. Flip `M24xxx_Part` to `Verified` in the catalogue once you
have run one.

The generic derives the strap budget rather than taking it: a part whose array
outruns its word address folds the surplus bits into the *low* bits of its
device-select byte, eating a chip-enable pin each (E0 first). A 24C16 folds all
three, so it has no strap and only one can sit on a bus — `M24C16.Setup (…, A0 =>
High)` raises.

## Build & run

```
./x run esp32s3_m24c64
```

The driver uses the controlled I2C `Session` (finalization), so this builds on
the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`), not
the default light-tasking.
