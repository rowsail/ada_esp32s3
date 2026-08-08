# FAT16 host test harness (native x86)

Runs the **pure-Ada FAT16 filesystem** (`ESP32S3.Fat16.*`, from
`libs/esp32s3_hal/src/fat16`) on the development host against a **file-backed
block device**, and cross-checks every volume with the host's own `dosfstools`.
No hardware, no flashing.

The harness builds the *same* sources the firmware uses (the `.gpr`
`Source_Files` whitelist pulls in the portable units and omits the on-target
block-device adapters), so a bug reproduced here is a real filesystem bug.

## Block device

`fat16_test.adb` plugs an `Ada.Direct_IO` view of an image file into the
`ESP32S3.Block_Dev` seam (512-byte sectors) — the same abstraction the on-target
`W25Q_Source` and `SDMMC_Source` adapters implement. It also supplies the
optional multi-sector `Read_Run`, so the reader's run path is the one under test
rather than `Block_Dev`'s per-sector fallback.

## Run

```sh
./run.sh
```

It auto-discovers an Alire native GNAT + gprbuild, builds, and prints one line
per check. Requirements: a native GNAT toolchain and `dosfstools`
(`mkfs.fat`, `fsck.fat`).

## What it proves

Three independent implementations have to agree about every volume:

1. **the Ada code** — `ESP32S3.Fat16.Mkfs` writes, `ESP32S3.Fat16` reads;
2. **the host's dosfstools** — `fsck.fat` checks what we wrote, `mkfs.fat` writes
   volumes we must read;
3. **`reference_writer.py`** — a FAT16 writer written from the specification
   rather than from the Ada source, which injects the files.

A bug that only one of the three believes in shows up as a disagreement.

| Scenario | What it covers |
|---|---|
| our own mkfs, 32 MB, partitioned | `Fat16.Mkfs` output validated by `fsck.fat`, before and after filling; 4 KB clusters; label |
| `mkfs.fat`, no partition table | a bare "superfloppy" written by the host, boot sector at LBA 0 |
| `mkfs.fat` inside a partition | our partition table, the host's filesystem inside it — the reader must follow the offset |
| volumes we must refuse | FAT32, FAT12, blank media and random bytes must all fail rather than misread |

Within each volume: long names up to the 255-character limit, a subdirectory, a
zero-length file, a 700 KB multi-cluster image read byte-exact both a chunk at a
time and in one `Read_File` call, case-insensitive matching, and the error paths
(missing file, directory opened as a file).

`fsck.fat` checks a *filesystem*, not a disk — on a partitioned image the
harness `dd`s the partition out first, or `fsck.fat` reads the partition table
as a boot sector and reports "Logical sector size is zero".
