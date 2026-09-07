# `ESP32S3.Ext4` — a pure-Ada ext2/3/4 filesystem (lwext4, reimplemented)

A from-scratch **ext2 / ext3 / ext4** filesystem with the **JBD2 journal**, written
in pure Ada — a reimplementation of [lwext4](https://github.com/gkostka/lwext4)
against the published ext4 on-disk format (no C is vendored; see
[`REFERENCES.md`](REFERENCES.md)). It mounts **real `mkfs.ext4` cards**, reads and
writes them, and recovers a dirty journal, all on the bare-metal ESP32-S3 — but
because it is *pure logic over a block interface* it also compiles and runs
host-native (x86) for testing against the Linux kernel's own `e2fsck`
(via a host test harness kept in the development repository).

It targets the **embedded** and **full** runtime profiles (it uses exceptions,
finalization and the secondary stack); it is not built under light-tasking.

## The big picture

```
   application
        │  ESP32S3.Ext4.FS  (Mount: a Limited_Controlled handle; Lookup/Stat/
        ▼                    Read_File/Iterate/Create_File/Mkdir/Unlink/.../Commit)
   ┌─────────────────────────────────────────────────────────────────┐
   │  operations:  Path → Dir → Inode → Block_Map → File   (+ Writer, │
   │               Bitmap, Group_Desc, Superblock)        (+ Journal)  │
   └─────────────────────────────────────────────────────────────────┘
        │  ESP32S3.Ext4.Block_Cache   (write-back LRU of filesystem blocks)
        ▼
   ESP32S3.Block_Dev   (a record of access-to-subprogram: Read/Write a 512 B Sector)
        │
        ├── on target : ESP32S3.Block_Dev.SD_SPI_Source  → ESP32S3.SD_SPI card
        └── on host   : File_Device                      → an ext image file
```

Everything above `Block_Dev` is hardware-independent. The block device is a tiny
**record of function pointers** (`Read` / `Write` / `Count` + an opaque context),
so the same filesystem runs over an SD card on the chip or over an image file on a
PC — that is what makes the host test harness possible.

## Modules (`esp32s3-ext4-*.ad?`)

| Package | Responsibility | lwext4 analog |
|---|---|---|
| `ESP32S3.Ext4` (root) | shared scalar types, `Byte_Array`, the exception set, little- **and** big-endian field readers (`Get_U32` / `Get_U32_BE`) | `ext4_types.h` |
| `Block_Dev` | the block-device seam (512-byte sectors) | `ext4_blockdev` |
| `Ext4.CRC32C` | table-driven Castagnoli CRC32c | `ext4_crc32.c` |
| `Ext4.Block_Cache` | heap write-back LRU over a `Device`; `Read`/`Write`/`Read_At`/`Write_At`, dirty tracking, `Flush`/`Drop` | `ext4_bcache.c` |
| `Ext4.Superblock` | parse + validate the superblock; feature gate; free-count sync; CRC32c seed | `ext4_super.c` |
| `Ext4.Volume` | the mounted-volume context (device + cache + superblock) shared by the operation packages | — |
| `Ext4.Group_Desc` | 32-/64-byte block-group descriptors (bitmap + inode-table locations, free counts) | `ext4_balloc.c` |
| `Ext4.Bitmap` | block / inode allocation + freeing | `ext4_balloc.c` / `ext4_ialloc.c` |
| `Ext4.Inode` | inode read / write / delete; metadata_csum | `ext4_inode.c` |
| `Ext4.Block_Map` | logical→physical: indirect maps (ext2/3) **and** extent trees (ext4) | `ext4_extent.c` + classic |
| `Ext4.Dir` | linear directory entries: lookup / iterate / add / remove (HTree dirs are read via their linear leaves) | `ext4_dir.c` / `ext4_dir_idx.c` |
| `Ext4.Path` | resolve `/a/b/c` from the root inode | `ext4.c` |
| `Ext4.File` | read a file by byte offset | `ext4.c` |
| `Ext4.Writer` | the write operations (create / write / truncate / mkdir / rmdir / unlink / rename / link) | `ext4.c` |
| `Ext4.Journal` | JBD2 replay (recovery) + commit + the atomic-transaction commit | `ext4_journal.c` |
| `Ext4.FS` | the public façade — a controlled `Mount` handle tying it together | `ext4_fs.c` |

## How it works

### On-disk structures
ext on-disk fields are **little-endian**; the JBD2 journal is **big-endian**. There
are no packed record overlays — every field is read/written explicitly with
`Get_U16/U32/U64` (LE) or `Get_U32_BE` (BE) at a documented byte offset, so the
decoding is endian-correct and obvious. Block buffers come from the cache (or, for
the few raw accesses like the superblock, directly from the device).

### Reading
`FS.Open` reads the superblock (sectors 2–3), **feature-gates** it (any *incompat*
bit the build doesn't implement → `Unsupported_Feature`; *ro_compat* bits are
ignored for a read-only mount), and brings up the block cache at the filesystem's
block size. From there: `Group_Desc` locates a group's inode table → `Inode` reads
an inode → `Block_Map` turns a file's logical block into a physical one (12 direct
+ single/double/triple **indirect** for ext2/3, or the **extent tree** for ext4) →
`Dir` walks directory blocks → `Path` resolves names → `File` copies bytes out.
Sparse holes read as zeros.

### Integrity (`metadata_csum`)
On a `metadata_csum` filesystem the per-fs CRC32c seed is derived at mount
(`s_checksum_seed`, or `crc32c(~0, uuid)`), and the **superblock** checksum (at
mount) and **every inode's** checksum (on read) are verified — a mismatch raises
`Bad_Checksum` rather than returning garbage.

### Writing
The write operations allocate from the block/inode **bitmaps** (updating the group
+ superblock free counts), write inodes, and splice directory entries:
`Create_File`, `Write` (direct + single-indirect), `Truncate`, `Mkdir`, `Rmdir`,
`Unlink`, `Rename` (same- and cross-directory, fixing `..` and link counts) and
hard `Link`. Every mutation is checked by `e2fsck -fn` in the test harness.
Writing is gated to **non-`metadata_csum`** filesystems for now (the group-desc /
bitmap / dir-tail checksums are not yet recomputed) → `Read_Only` on a csum volume.

### The JBD2 journal — crash safety
- **Recovery** (`Journal.Replay`, run automatically by `FS.Open` on a writable
  mount whose superblock has the RECOVER flag): read the journal (inode 8, big-
  endian), scan the committed transactions and revoke records, replay each logged
  block to its target, then reset the journal and clear RECOVER.
- **Commit** (`Journal.Transaction_Commit`, via `FS.Commit`): make a filesystem
  operation **atomic**. The cache's dirty metadata blocks **and** the superblock
  are written to the journal (durably), then the RECOVER flag is set — *the commit
  barrier* — then the metadata is checkpointed to its final locations, then RECOVER
  is cleared and the journal reset. A crash **after** the barrier recovers forward
  (the next mount replays); a crash **before** it has no effect. (Today the write-
  set must fit the cache, so this covers metadata + small-data operations.)

Both directions are cross-validated against the kernel: `e2fsck -fy` recovers
journals this code writes, and this code's replay reproduces the kernel's result.

### Error model
Idiomatic Ada IO: operations **raise**. The IO-family exceptions are the standard
ones from `Ada.IO_Exceptions` (`Name_Error`, `Use_Error`, `Device_Error`,
`End_Error`, …) so a future `Ada.Streams.Stream_IO` bridge maps cleanly, plus a few
filesystem-specific ones (`Unsupported_Feature`, `Bad_Checksum`, `Corrupt`,
`No_Space`, `Not_Empty`, `Read_Only`). `Mount` is `Limited_Controlled` and flushes
+ releases on scope exit.

## Using it

```ada
with ESP32S3.Ext4.FS;  with ESP32S3.Ext4.Inode;  with ESP32S3.Block_Dev;

Dev : constant ESP32S3.Block_Dev.Device := ...;     -- SD adapter or host file
M   : ESP32S3.Ext4.FS.Mount;
I   : ESP32S3.Ext4.Inode.Info;
Buf : ESP32S3.Ext4.Byte_Array (0 .. 4095);
Last : Natural;
begin
   M.Open (Dev, Read_Only => True);                 -- mount (auto-recovers a dirty journal)
   M.Stat (M.Lookup ("/etc/hello.txt"), I);         -- resolve + read inode
   M.Read_File (I, 0, Buf, Last);                    -- read Last bytes
   --  writing (non-csum fs):
   --     N := M.Create_File ("/", "log.txt");
   --     M.Write_File (N, Data);
   --     M.Commit;     -- atomic, journaled
end;                                                 -- Mount finalizes (flush + close)
```

On the chip, build a `Device` from whichever adapter matches the medium:
`SD_SPI_Source` (SD over SPI), `SDMMC_Source` (native SDHOST) or `W25Q_Source`
(SPI NOR flash, usually under `Block_Dev.WL` for wear leveling). Four examples
show the combinations:

| Example | Medium | What it does |
|---|---|---|
| [`esp32s3_ext4`](../../../../examples/esp32s3_ext4/) | SD over SPI | mount, list, read a file |
| [`esp32s3_ext4_sdmmc`](../../../../examples/esp32s3_ext4_sdmmc/) | SD over SDMMC | the same, read-only, on the native SDHOST |
| [`esp32s3_ext4_write`](../../../../examples/esp32s3_ext4_write/) | SD over SDMMC | the write battery as one journaled transaction |
| [`esp32s3_ext4_flash`](../../../../examples/esp32s3_ext4_flash/) / [`esp32s3_ext4_mkfs`](../../../../examples/esp32s3_ext4_mkfs/) | SPI NOR + WL | an installed image / `Ext4.Mkfs` formatting the flash on-device |

## Testing & status

A host test harness ([`test/ext4_host`](../../test/ext4_host), run by
`./x test host`) runs the filesystem on x86 against real `mke2fs` images:
it byte-compares reads to the source files, and every scenario ends in a clean
`e2fsck -fn` from the host kernel. **17 scenarios pass**, covering journaled and
no-journal writes, double-indirect append/truncate/unlink past 4 MiB, crash
recovery by journal replay, directory growth to a multi-block directory, and
disk exhaustion (a failing write must hand back its scratch buffer). The same
code cross-compiles for the ESP32-S3 (xtensa, embedded).

**On-card bring-up is done.** The filesystem mounts and writes a real
`mkfs.ext4` SD card on the board over `SDMMC_Source`, and the card then passes
`e2fsck -f` on a Linux host, which is where the tree, the symlink target, the
hard-link inode sharing and a 1 MiB file's contents are checked. The SPI NOR
path (`W25Q_Source` under `Block_Dev.WL`) runs on the board too, including
on-device `Ext4.Mkfs`. The one adapter still without an on-card run is
`SD_SPI_Source`.

Remaining (enhancement-tier): triple-indirect + extent *allocation* on write,
`metadata_csum`-filesystem writes, large-file `data=ordered` journaling, and a
checksummed journal (CSUM_V3). See [`REFERENCES.md`](REFERENCES.md).
