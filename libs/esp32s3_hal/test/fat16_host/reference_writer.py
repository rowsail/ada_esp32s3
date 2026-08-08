#!/usr/bin/env python3
"""Put files into a FAT16 image -- an independent reference implementation.

Written from the FAT specification rather than from the Ada source, so that
what it produces is a genuine second opinion: run_tests.sh injects files with
this, validates the result with the host's own fsck.fat, and then requires the
Ada reader to reproduce every name and every byte.

Deliberately simple: it appends to a directory, never deletes, and allocates
clusters first-fit.  Long names are written for every entry, alongside the 8.3
alias FAT requires.

    reference_writer.py <image> put <path-in-image> <host-file>
    reference_writer.py <image> mkdir <path-in-image>
"""

import struct
import sys

SECTOR = 512
SLOT = 32
ATTR_DIRECTORY = 0x10
ATTR_LONG_NAME = 0x0F
ATTR_VOLUME_ID = 0x08


def short_name_checksum(eleven: bytes) -> int:
    total = 0
    for byte in eleven:
        total = (((total & 1) << 7) + (total >> 1) + byte) & 0xFF
    return total


class Volume:
    def __init__(self, path):
        self.file = open(path, "r+b")
        self.partition_start = 0

        boot = self.read_sector(0)
        if not self._is_boot_sector(boot):
            if boot[510:512] != b"\x55\xaa":
                raise SystemExit("neither a boot sector nor a partition table")
            for slot in range(4):
                entry = boot[446 + slot * 16 : 462 + slot * 16]
                start = struct.unpack("<I", entry[8:12])[0]
                if entry[4] in (0x04, 0x06, 0x0E) and start:
                    self.partition_start = start
                    break
            else:
                raise SystemExit("no FAT16 partition in the table")
            boot = self.read_sector(self.partition_start)
            if not self._is_boot_sector(boot):
                raise SystemExit("partition does not start with a FAT boot sector")

        self._parse(boot)

    @staticmethod
    def _is_boot_sector(data):
        if data[510:512] != b"\x55\xaa":
            return False
        bytes_per_sector = struct.unpack("<H", data[11:13])[0]
        per_cluster = data[13]
        fat_size = struct.unpack("<H", data[22:24])[0]
        root_entries = struct.unpack("<H", data[17:19])[0]
        return (
            bytes_per_sector == SECTOR
            and per_cluster != 0
            and (per_cluster & (per_cluster - 1)) == 0
            and fat_size != 0
            and root_entries != 0
        )

    def _parse(self, boot):
        self.cluster_sectors = boot[13]
        reserved = struct.unpack("<H", boot[14:16])[0]
        self.fat_copies = boot[16]
        self.root_entries = struct.unpack("<H", boot[17:19])[0]
        total_16 = struct.unpack("<H", boot[19:21])[0]
        self.fat_sectors = struct.unpack("<H", boot[22:24])[0]
        total_32 = struct.unpack("<I", boot[32:36])[0]

        total = total_16 if total_16 else total_32
        self.fat_start = self.partition_start + reserved
        self.root_start = self.fat_start + self.fat_copies * self.fat_sectors
        self.root_sectors = (self.root_entries * SLOT + SECTOR - 1) // SECTOR
        self.data_start = self.root_start + self.root_sectors
        metadata = reserved + self.fat_copies * self.fat_sectors + self.root_sectors
        self.clusters = (total - metadata) // self.cluster_sectors
        self.cluster_bytes = self.cluster_sectors * SECTOR

        if not 4085 <= self.clusters <= 65524:
            raise SystemExit(f"cluster count {self.clusters} is not FAT16")

    # -- raw sectors -------------------------------------------------------
    def read_sector(self, lba):
        self.file.seek(lba * SECTOR)
        data = self.file.read(SECTOR)
        if len(data) != SECTOR:
            raise SystemExit(f"short read at LBA {lba}")
        return data

    def write_sector(self, lba, data):
        assert len(data) == SECTOR
        self.file.seek(lba * SECTOR)
        self.file.write(data)

    # -- the allocation table ---------------------------------------------
    def get_fat(self, cluster):
        offset = cluster * 2
        sector = self.read_sector(self.fat_start + offset // SECTOR)
        return struct.unpack_from("<H", sector, offset % SECTOR)[0]

    def set_fat(self, cluster, value):
        offset = cluster * 2
        for copy in range(self.fat_copies):
            lba = self.fat_start + copy * self.fat_sectors + offset // SECTOR
            sector = bytearray(self.read_sector(lba))
            struct.pack_into("<H", sector, offset % SECTOR, value)
            self.write_sector(lba, bytes(sector))

    def allocate(self, count):
        chain = []
        cluster = 2
        while len(chain) < count and cluster < self.clusters + 2:
            if self.get_fat(cluster) == 0:
                chain.append(cluster)
            cluster += 1
        if len(chain) < count:
            raise SystemExit("out of space")
        for i, this in enumerate(chain):
            self.set_fat(this, chain[i + 1] if i + 1 < len(chain) else 0xFFFF)
        return chain

    def cluster_lba(self, cluster):
        return self.data_start + (cluster - 2) * self.cluster_sectors

    def write_chain(self, chain, payload):
        pad = (-len(payload)) % self.cluster_bytes
        payload = payload + b"\x00" * pad
        for i, cluster in enumerate(chain):
            block = payload[i * self.cluster_bytes : (i + 1) * self.cluster_bytes]
            for s in range(self.cluster_sectors):
                self.write_sector(
                    self.cluster_lba(cluster) + s, block[s * SECTOR : (s + 1) * SECTOR]
                )

    # -- directories -------------------------------------------------------
    def dir_sectors(self, cluster):
        """The sectors of a directory, root (cluster 0) or a chain."""
        if cluster == 0:
            return [self.root_start + s for s in range(self.root_sectors)]
        out = []
        while 2 <= cluster < 0xFFF8:
            out += [self.cluster_lba(cluster) + s for s in range(self.cluster_sectors)]
            cluster = self.get_fat(cluster)
        return out

    def read_dir(self, cluster):
        """Every 32-byte slot of a directory, in order, with its LBA."""
        slots = []
        for lba in self.dir_sectors(cluster):
            data = self.read_sector(lba)
            for i in range(SECTOR // SLOT):
                slots.append((lba, i, data[i * SLOT : (i + 1) * SLOT]))
        return slots

    def used_short_names(self, cluster):
        names = set()
        for _, _, slot in self.read_dir(cluster):
            if slot[0] == 0:
                break
            if slot[0] != 0xE5 and slot[11] != ATTR_LONG_NAME:
                names.add(bytes(slot[:11]))
        return names

    def append(self, cluster, slots):
        """Write a run of directory slots at the first free run of that length."""
        existing = self.read_dir(cluster)
        start = None
        for index, (_, _, slot) in enumerate(existing):
            if slot[0] == 0:
                start = index
                break
        if start is None or start + len(slots) > len(existing):
            raise SystemExit("directory full")

        for offset, payload in enumerate(slots):
            lba, index, _ = existing[start + offset]
            sector = bytearray(self.read_sector(lba))
            sector[index * SLOT : (index + 1) * SLOT] = payload
            self.write_sector(lba, bytes(sector))

    def make_short_name(self, name, taken):
        stem, _, ext = name.rpartition(".")
        if not stem:
            stem, ext = name, ""
        keep = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'()-@^_`{}~"
        clean = lambda s: "".join(c if c.upper() in keep else "_" for c in s.upper())
        stem, ext = clean(stem), clean(ext)[:3]
        for n in range(1, 100):
            tail = f"~{n}"
            base = (stem[: 8 - len(tail)] + tail)[:8]
            candidate = f"{base:<8}{ext:<3}".encode("ascii")
            if candidate not in taken:
                return candidate
        raise SystemExit("cannot make a unique short name")

    def entry_slots(self, name, short, attributes, first_cluster, size):
        """The long-name slots for name, followed by its 8.3 entry."""
        checksum = short_name_checksum(short)
        chunks = [name[i : i + 13] for i in range(0, len(name), 13)] or [""]

        slots = []
        for index, chunk in enumerate(chunks, start=1):
            padded = chunk + "\x00" if len(chunk) < 13 else chunk
            codes = [ord(c) for c in padded] + [0xFFFF] * (13 - len(padded))
            raw = bytearray(SLOT)
            raw[0] = index | (0x40 if index == len(chunks) else 0)
            raw[11] = ATTR_LONG_NAME
            raw[13] = checksum
            for i in range(5):
                struct.pack_into("<H", raw, 1 + i * 2, codes[i])
            for i in range(6):
                struct.pack_into("<H", raw, 14 + i * 2, codes[5 + i])
            for i in range(2):
                struct.pack_into("<H", raw, 28 + i * 2, codes[11 + i])
            slots.append(bytes(raw))
        slots.reverse()   # highest ordinal first, as FAT stores them

        entry = bytearray(SLOT)
        entry[0:11] = short
        entry[11] = attributes
        struct.pack_into("<H", entry, 22, 0x8000)   # time
        struct.pack_into("<H", entry, 24, 0x5A21)   # date (2025-01-01)
        struct.pack_into("<H", entry, 26, first_cluster)
        struct.pack_into("<I", entry, 28, size)
        slots.append(bytes(entry))
        return slots

    # -- the two operations ------------------------------------------------
    def entries(self, cluster):
        """Every live entry of a directory, with its long name reassembled."""
        parts = {}
        checksum = None
        for _, _, slot in self.read_dir(cluster):
            if slot[0] == 0:
                break
            if slot[0] == 0xE5:
                parts = {}
                continue
            if slot[11] == ATTR_LONG_NAME:
                if slot[0] & 0x40:
                    parts = {}
                    checksum = slot[13]
                codes = (
                    list(struct.unpack_from("<5H", slot, 1))
                    + list(struct.unpack_from("<6H", slot, 14))
                    + list(struct.unpack_from("<2H", slot, 28))
                )
                parts[slot[0] & 0x3F] = codes
                continue

            name = ""
            if parts and checksum == short_name_checksum(slot[:11]):
                codes = []
                for order in sorted(parts):
                    codes += parts[order]
                for code in codes:
                    if code == 0:
                        break
                    if code != 0xFFFF:
                        name += chr(code)
            if not name:
                stem = slot[:8].decode("latin-1").rstrip()
                ext = slot[8:11].decode("latin-1").rstrip()
                name = stem + ("." + ext if ext else "")
            parts = {}
            yield name, slot

    def resolve_directory(self, parts):
        cluster = 0
        for part in parts:
            for name, slot in self.entries(cluster):
                if slot[11] & ATTR_VOLUME_ID:
                    continue
                if name.upper() == part.upper() and slot[11] & ATTR_DIRECTORY:
                    cluster = struct.unpack_from("<H", slot, 26)[0]
                    break
            else:
                raise SystemExit(f"no such directory: {part}")
        return cluster

    def put(self, path, payload):
        parts = [p for p in path.replace("\\", "/").split("/") if p]
        parent = self.resolve_directory(parts[:-1])
        name = parts[-1]

        #  A zero-length file owns no clusters at all and records first
        #  cluster 0 -- allocating one for it would leave fsck.fat a lost chain.
        if payload:
            count = (len(payload) + self.cluster_bytes - 1) // self.cluster_bytes
            chain = self.allocate(count)
            self.write_chain(chain, payload)
            first = chain[0]
        else:
            first = 0

        short = self.make_short_name(name, self.used_short_names(parent))
        self.append(parent, self.entry_slots(name, short, 0x20, first, len(payload)))

    def mkdir(self, path):
        parts = [p for p in path.replace("\\", "/").split("/") if p]
        parent = self.resolve_directory(parts[:-1])
        name = parts[-1]

        chain = self.allocate(1)
        cluster = chain[0]
        blank = bytearray(self.cluster_bytes)
        dot = bytearray(SLOT)
        dot[0:11] = b".          "
        dot[11] = ATTR_DIRECTORY
        struct.pack_into("<H", dot, 26, cluster)
        dotdot = bytearray(SLOT)
        dotdot[0:11] = b"..         "
        dotdot[11] = ATTR_DIRECTORY
        struct.pack_into("<H", dotdot, 26, parent)
        blank[0:SLOT] = dot
        blank[SLOT : 2 * SLOT] = dotdot
        self.write_chain([cluster], bytes(blank))

        short = self.make_short_name(name, self.used_short_names(parent))
        self.append(
            parent, self.entry_slots(name, short, ATTR_DIRECTORY, cluster, 0)
        )

    def close(self):
        self.file.close()


def main(argv):
    if len(argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2

    volume = Volume(argv[1])
    action = argv[2]
    if action == "put":
        with open(argv[4], "rb") as source:
            volume.put(argv[3], source.read())
    elif action == "mkdir":
        volume.mkdir(argv[3])
    else:
        print(f"unknown action {action}", file=sys.stderr)
        return 2
    volume.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
