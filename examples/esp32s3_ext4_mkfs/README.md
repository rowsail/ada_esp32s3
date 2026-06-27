# Format a blank SPI NOR flash to ext4 on-device (ESP32-S3, no FreeRTOS)

The pure-Ada **mkfs** — no host, no pre-built image. `ESP32S3.Ext4.Mkfs` lays down
a fresh ext4 filesystem on the board, straight onto the wear-leveling volume:

```
ESP32S3.Ext4.Mkfs  →  Block_Dev.WL  →  Block_Dev.W25Q_Source  →  ESP32S3.W25Q
```

```
[mkfs] format a blank SPI NOR flash to ext4 on-device (SPI2, CS=IO21)
[mkfs] flash ef 40 19, 4-byte mode: OK
[mkfs] wear-leveling volume: 65512 logical sectors
[mkfs] formatted ext4 (journaled); WL moves: 17
[mkfs] mounted read-write; block size 4096
[mkfs] wrote /boot.txt + mkdir /logs + /logs/1.txt; committed
[mkfs] remounted; reading back:
[mkfs] /boot.txt (42 bytes):
formatted on-device by ESP32S3.Ext4.Mkfs!
[mkfs] /logs/1.txt (14 bytes):
log entry one
[mkfs] done.
```

## What it does

0. **Auto-detects the chip size** from its JEDEC id (`W25Q.Capacity_Bytes`) and
   prints it — so the whole stack (`W25Q_Source` → `WL` → the filesystem) sizes
   itself to whatever W25Q part is fitted (8/16/32/64 MB), no constants to edit.
1. Brings up the flash and **formats a fresh wear-leveling volume** over it.
2. **`Ext4.Mkfs.Format`** writes a minimal but valid ext4 directly onto the WL
   volume — one block group, 4 KiB blocks, classic block-mapped inodes (the same
   style the FS's `Writer` creates), no `metadata_csum`, with a root directory and
   a `lost+found`. The `Use_Journal` constant chooses a **JBD2 journal** (4 MiB,
   crash-safe commits — the default here) or a lighter no-journal volume.
3. **Mounts read-write**, creates `/boot.txt`, `mkdir /logs`, writes `/logs/1.txt`,
   **streams a 64 KB `/logs/stream.bin`** with `Append` (256-byte chunks — never
   buffering the whole file, and large enough to use the single-indirect block
   map), and commits (through the journal if there is one, else a direct flush).
4. **Remounts** read-only, reads the files back — including the one in the
   subdirectory it just created — and **byte-checks the streamed file**
   (every byte = its file offset mod 251).

Unlike [`esp32s3_ext4_flash`](../esp32s3_ext4_flash) (which installs a host-built
image), nothing here is pre-baked: the filesystem is created from a blank volume
on the device.

## Trust but verify

`Ext4.Mkfs` is the inverse of the read path, so the obvious risk is a subtly
wrong on-disk field. The formatter is validated against the host's **`e2fsck`**
(the reference checker) in `libs/esp32s3_hal/test/mkfs_host` (`./run.sh`): it
formats blank images of several sizes — **with and without a journal** —
e2fsck-checks each, mounts them with *our* FS to list the root, and re-checks
after our FS writes to them — all clean (`dumpe2fs` confirms a real 4 MB JBD2
journal). This example then runs the identical formatter on real flash.

## Hardware

W25Q256FV on SPI2: `SCLK=GPIO1  MOSI=GPIO4  MISO=GPIO45  CS=GPIO21` (3V3 / GND).

## Build & run

```
./x run esp32s3_ext4_mkfs     # build + flash + report over USB-Serial-JTAG
```

The FS heap lives in the 8 MB PSRAM (`build.sh` sets `HEAP_PSRAM=1`).
