# A real ext4 filesystem on wear-leveled SPI NOR flash (ESP32-S3, no FreeRTOS)

The whole storage stack, end to end — the pure-Ada **ESP32S3.Ext4** filesystem
mounting a real ext4 image that lives on a W25Q256FV through the wear-leveling
FTL:

```
ESP32S3.Ext4  →  Block_Dev.WL  →  Block_Dev.W25Q_Source  →  ESP32S3.W25Q
```

```
[ext4f] ext4 on wear-leveled SPI NOR flash (SPI2, CS=IO21)
[ext4f] flash ef 40 19, 4-byte mode: OK
[ext4f] installing ext4 image: 512 sectors (31 non-zero)...
[ext4f] installed; WL moves during install: 8
[ext4f] mounted ext4 read-only; block size 4096
[ext4f] /hello.txt (56 bytes):
hello from pure-Ada ext4 on wear-leveled SPI NOR flash!
[ext4f] /docs/readme.txt (125 bytes):
This file lives in a real ext4 image installed on a W25Q256FV
over the Block_Dev.WL wear-leveling FTL, read by ESP32S3.Ext4.
[ext4f] done.
```

## Why an embedded image

The pure-Ada FS mounts and reads ext4 but does **not** `mkfs`, and the external
W25Q flash is **not** on the host flasher's path (esptool only reaches the
ESP32-S3's own boot flash). So a tiny ext4 image — built on a host with
`mkfs.ext4` (4 KB blocks, no journal, no `metadata_csum`) and holding
`/hello.txt` + `/docs/readme.txt` — is embedded in the firmware **sparsely**: a
freshly-`mkfs`'d image is almost all zeros, so only its ~31 non-zero 512-byte
sectors are stored (`src/flash_image.ads`, ~15 KB). Regenerate it with
`./gen_image.sh`.

## What it does

1. Brings up the flash (JEDEC, 4-byte mode) and **formats** a fresh wear-leveling
   volume over it.
2. **Installs** the image by writing every filesystem sector through the WL
   device — the stored non-zero sectors, zeros for the rest — so it lands
   remapped and wear-leveled on the flash. (Writing zeros is a clear-only program
   on NOR, so the install stays fast.) A few WL **moves** happen along the way.
3. **Mounts** the result read-only with `ESP32S3.Ext4` over the same WL device
   and reads both files back — proving the full path: ext4 superblock / inode /
   directory / file parsing → WL remap → SPI NOR.

This **erases and writes** the flash. Safe here: the flash is dedicated to this
experiment and holds no other filesystem.

Read-only by design: the pure-Ada FS journals every write (JBD2), and a journaled
image is far larger to embed; the `esp32s3_ext4_write` example exercises the
write path on a (journaled) SD card.

## Hardware

W25Q256FV on SPI2: `SCLK=GPIO1  MOSI=GPIO4  MISO=GPIO45  CS=GPIO21` (3V3 / GND).

## Build & run

```
./x run esp32s3_ext4_flash    # build + flash + report over USB-Serial-JTAG
```

The FS heap lives in the 8 MB PSRAM (`build.sh` sets `HEAP_PSRAM=1`).
