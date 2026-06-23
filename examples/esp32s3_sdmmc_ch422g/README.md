# SD card via SDMMC with a CH422G-driven DAT3 — bare-metal Ada (ESP32-S3)

Reads an SD card in **1-bit SDMMC mode** on a board where the card's **DAT3/CD**
line is not wired to the SoC but to a **CH422G** I2C expander pin. Two reusable
HAL drivers together: `ESP32S3.CH422G` holds DAT3 high (so the card enters/stays
in SD mode), and `ESP32S3.SDMMC` talks to the card on CLK/CMD/D0.

```
[sd] SD card via SDMMC 1-bit, DAT3/CD held high by CH422G IO4
[sd]   SDMMC: CLK=IO12 CMD=IO11 D0=IO13   CH422G: I2C0 SDA=8 SCL=9
[sd] CH422G IO bank -> 0x10 (DAT3 high) : OK
[sd] init: OK   card: SDHC/SDXC
[sd] CID: mfr=0x3  oem=SD  name=ASTC?  rev 3.4
[sd]      serial=0x458a  manufactured 2022-8
[sd] capacity: 29818 MB  (~29.1 GB)
[sd] caps: spec 6.0  default-speed max 25 MHz  High-Speed yes  4-bit yes
[sd]        cmd-classes 0x5b5  read-block 512 B
[sd] running: 50 MHz  (High Speed ON)
[sd] read block 0: OK   first bytes = 00 00 00 00   boot sig 0x55AA: present
```

**Read-only:** it identifies the card, decodes its registers, and reads block 0
(checking the 0x55AA boot signature). It never writes — no card content can be
lost.

## Decoding the card's identity

`Initialize` reads the card's **CID** (CMD2) and **CSD** (CMD9) registers; the
driver decodes them:

- `ESP32S3.SDMMC.Identity (C)` → a `Card_Id` record: manufacturer ID, OEM string,
  product name, revision, **serial number**, and **manufacture date** (from CID).
- `ESP32S3.SDMMC.Capacity_Blocks (C)` → usable size in 512-byte blocks (from CSD;
  MB = blocks / 2048). Handles both CSD v2 (SDHC/SDXC) and v1 (SDSC) layouts.
- `ESP32S3.SDMMC.Capabilities (C)` → CSD speed/command-classes/block-size **plus**
  SCR spec version and 4-bit support and CMD6 High-Speed support.

### Running at the card's optimum speed

`Setup` takes `High_Speed => True`: `Initialize` then queries the card's **SCR**
(ACMD51 — spec version, bus widths) and **CMD6 SWITCH_FUNC** (High-Speed
support), and if High Speed is available it switches the card into it and runs at
`min (Data_Clock_Hz, 50 MHz)` — twice the 25 MHz default-speed limit. Without it,
the bus is capped at 25 MHz. `Active_Clock_Hz (C)` and `High_Speed_Active (C)`
report what was negotiated. (4-bit mode — another 4× — needs DAT1–3 wired, which
this board doesn't have, so it stays 1-bit here.)

In the sample run above, `mfr=0x03` + `oem="SD"` are SanDisk's identifiers and
29.1 GB is the usable size of a 32 GB card (marketing GB vs GiB) — the decode is
self-consistent. (An odd product name / tiny serial on an otherwise
SanDisk-branded card can be a sign of a counterfeit; here it's reported
faithfully from the card's CID.)

## Wiring

| SD pin | Connected to | role (1-bit SD mode) |
|---|---|---|
| CLK | **IO12** | SDMMC clock |
| CMD | **IO11** | command line |
| DAT0 | **IO13** | the single data line |
| DAT1 / DAT2 | — | unused in 1-bit mode |
| **CD / DAT3** | **CH422G IO4** | held **high** to select the card |

In 1-bit mode DAT3 is not a host data line; the card samples it at its first
command (high → SD mode) and it must stay high. It's set **once** and never
toggled during transfers, so driving it from the slow I2C expander is fine.

## Sequence

1. **CH422G**: load its IO output register with `0x10` (IO4 = 1, every other IO
   low — per this board), *then* enable outputs, so DAT3 is high the instant the
   bank switches to outputs (no glitch). The expander's IO direction is global,
   so making IO4 an output makes all of IO0–7 outputs; the value drives IO4 high
   and the rest low.
2. **SDMMC**: `Setup` on Slot1, 1-bit (`Width_1`, D1/D2/D3 = No_Pin), then
   `Initialize` and `Read_Block (0)`.

## Build / flash / run

```sh
./x build sdmmc_ch422g
./x flash sdmmc_ch422g -p /dev/ttyACM0
./x run   sdmmc_ch422g -p /dev/ttyACM0
```

## Notes

- **This example surfaced a real bug in `ESP32S3.SDMMC`**, fixed alongside it: the
  driver's controller-poll loops were *iteration-count* bounded, and at `-O2`
  those tight loops expired in microseconds — long before a command response or
  data word arrived. Identification only *appeared* to work (the driver read the
  response register later, after other code gave the hardware time); the data
  read, gated on the command-done flag, timed out. The loops are now bounded by a
  real-time (`Ada.Real_Time`) deadline, independent of CPU speed / optimisation.
  Verified reading at the full 20 MHz data clock.
- Both drivers use controlled / protected resources, so this targets the
  **embedded / full** profiles.
- Pull-ups (~10 kΩ) on CMD/DAT0 are assumed on the board.
