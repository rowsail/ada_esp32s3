# ext4 on SD — bare-metal Ada pure-Ada filesystem (ESP32-S3, no FreeRTOS)

Mounts a real **ext4** (or ext2/3) SD card with the pure-Ada filesystem
(**`ESP32S3.Ext4`**, in `libs/esp32s3_hal/src/ext4/`) layered over the
**`ESP32S3.SD_SPI`** block driver, and reads a file — no ESP-IDF, no FreeRTOS.

```
[ext4] bare-metal pure-Ada ext4 over SD-over-SPI (needs a wired ext4 card)
[ext4] SD card init: OK
[ext4] mount: OK   block size = 4096
[ext4] read /hello.txt: OK   first bytes = 68 65 6c 6c
[ext4] done.
```

With **no card wired** it prints `SD card init: FAILED` and stops cleanly — which
is what the in-tree smoke build shows (the boot + SD + FS-mount path runs on
silicon; the OK lines need a real card).

## Maturity

The filesystem itself is **extensively host-verified** on x86 against real
`mke2fs` images with `e2fsck`/the Linux kernel as the oracle (read ext2/3/4 +
checksums, full write path, JBD2 journal replay + commit). This on-device example
is **compile-verified + a no-card smoke run**; the on-card read/write itself
depends on the `ESP32S3.SD_SPI` block driver, which is **not yet
on-card-verified** (see its README) — bring that up first.

For ext4 on a card *today*, use the SDMMC pair instead:
[`esp32s3_ext4_sdmmc`](../esp32s3_ext4_sdmmc) (read) and
[`esp32s3_ext4_write`](../esp32s3_ext4_write) (the journaled write battery). Both
run on a real `mkfs.ext4` card over the native SDHOST. What is missing here is
the SPI block driver under the filesystem, not the filesystem.

## Card setup (on a Linux host)

```sh
sudo mkfs.ext4 /dev/sdX1            # or mke2fs -t ext2 ; default ext4 reads fine
sudo mount /dev/sdX1 /mnt && echo "hello from ext4" | sudo tee /mnt/hello.txt && sudo umount /mnt
```

Reading a default `mkfs.ext4` card works. **Writing** requires a
non-`metadata_csum` filesystem (`mke2fs -t ext4 -O ^metadata_csum` or ext2/3).

## Wiring

| SD pin | signal | default GPIO |
|--------|--------|--------------|
| CLK | SCLK | **GPIO12** |
| DI  | MOSI | **GPIO11** |
| DO  | MISO | **GPIO13** |
| CS  | CS   | **GPIO10** |
| VDD / VSS | 3V3 / GND | 3V3 / GND |

Edit the pins at the top of `src/main.adb`.

## Build & flash

```sh
./x run esp32s3_ext4            # build + flash + monitor
```

Built as the **embedded** profile (the filesystem uses exceptions + finalization).
The report prints over USB-Serial-JTAG via the ROM `esp_rom_printf` glue.
