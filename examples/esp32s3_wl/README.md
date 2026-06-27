# Dynamic wear-leveling FTL over SPI NOR flash (ESP32-S3, no FreeRTOS)

Exercises **`ESP32S3.Block_Dev.WL`** — the "Option B" dynamic wear-leveling FTL —
layered over the W25Q256FV flash:

```
ext4  →  ESP32S3.Block_Dev.WL  →  ESP32S3.Block_Dev.W25Q_Source  →  ESP32S3.W25Q
```

```
[wl] dynamic wear-leveling FTL over W25Q SPI NOR (SPI2, CS=IO21)
[wl] flash JEDEC ef 40 19, 4-byte mode: OK
[wl] attached: 65512 logical sectors; formatted
[wl] wrote 32 sectors; moves performed: 8
[wl] read-back (same volume): PASS
[wl] remount (fresh volume + Mount) read-back: PASS
[wl] done.
```

## What it checks

1. **Attach + Format** a fresh wear-leveling volume over the raw flash block
   device, reserving the top two erase blocks for the ping-pong config.
2. **Write** a distinct pattern to a band of logical sectors. With
   `Update_Rate = 4`, 32 writes trigger **8 moves** (mapping rotations), so the
   data is physically relocated underneath while staying logically addressable.
3. **Read-back** every sector through the same volume — PASS.
4. **Remount**: attach a *brand-new* volume over the same flash and `Mount` it
   (no format). If the ping-pong config recovers the move counter, the map is
   reconstructed from persisted state alone and every sector still reads back —
   PASS. This is the power-cycle case.

This **erases and writes** the flash (the low data band plus the two config
blocks near the top of the chip). Safe here: the flash is dedicated to this
experiment and holds no filesystem yet.

## How the FTL spreads wear

`Block_Dev.WL` keeps **O(1) state** — just a move counter `t` — and maps a
logical 4 KB block `lb` to physical block `(t + ((lb − t) mod L)) mod D`, with
one always-free "hole" at `(t − 1) mod D`. Every `Update_Rate` writes it copies a
single block into the hole and advances `t`, so the hole walks the region and the
whole mapping rotates one block at a time. A hot logical block therefore migrates
across **every** physical block over time instead of wearing one out. State is
committed to two config blocks **ping-pong** (alternating, increasing sequence +
CRC), so a power failure mid-update always leaves a consistent earlier state.

The remap and persistence are brute-force tested on the host (random writes +
simulated power cycle + wear-distribution check) in
`libs/esp32s3_hal/test/wl_host` (`./run.sh`).

## Hardware

W25Q256FV on SPI2: `SCLK=GPIO1  MOSI=GPIO4  MISO=GPIO45  CS=GPIO21` (3V3 / GND).

## Build & run

```
./x run esp32s3_wl            # build + flash + report over USB-Serial-JTAG
```
