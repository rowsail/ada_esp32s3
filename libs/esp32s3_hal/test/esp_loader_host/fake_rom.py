#!/usr/bin/env python3
"""A simulated ESP32 ROM serial bootloader -- an independent second opinion.

Written from the protocol description rather than from the Ada source: it runs
esp_loader_test as a child, speaks SLIP over its stdin/stdout, watches the
target's control lines on its stderr, and is strict about everything it is sent.
Anything the loader gets wrong -- a bad frame, a wrong length field, a wrong
block checksum, a skipped sequence number, a SYNC before the target was reset
into download mode -- is reported here rather than quietly tolerated.

    fake_rom.py <scenario> [--image IN] [--out OUT] [--mode MODE]

Exit status 0 if the child passed AND this simulator saw nothing wrong.
"""

import argparse
import struct
import subprocess
import sys
import threading

FRAME_END = 0xC0
ESCAPE = 0xDB
ESCAPED_END = 0xDC
ESCAPED_ESCAPE = 0xDD

OP_FLASH_BEGIN = 0x02
OP_FLASH_DATA = 0x03
OP_FLASH_END = 0x04
OP_SYNC = 0x08
OP_READ_REG = 0x0A
OP_SPI_PARAMS = 0x0B
OP_SPI_ATTACH = 0x0D
OP_CHANGE_BAUD = 0x0F
OP_FLASH_MD5 = 0x13

BLOCK = 1024
CHIP_MAGIC = 9            # ESP32-S3
KNOWN_MD5 = "0123456789abcdef0123456789abcdef"


def slip_escape(payload):
    out = bytearray([FRAME_END])
    for byte in payload:
        if byte == FRAME_END:
            out += bytes([ESCAPE, ESCAPED_END])
        elif byte == ESCAPE:
            out += bytes([ESCAPE, ESCAPED_ESCAPE])
        else:
            out.append(byte)
    out.append(FRAME_END)
    return bytes(out)


class Lines(threading.Thread):
    """Drain the child's stderr: control-line transitions and its own report."""

    def __init__(self, stream, rom):
        super().__init__(daemon=True)
        self.stream = stream
        self.rom = rom
        self.report = []

    def run(self):
        for raw in self.stream:
            line = raw.decode("utf-8", "replace").rstrip("\n")
            if not line:
                continue
            word = line.split()
            if word[0] == "RESET":
                self.rom.set_reset(word[1] == "1")
            elif word[0] == "BOOT":
                self.rom.set_boot(word[1] == "1")
            elif word[0] == "BAUD":
                self.rom.baud = int(word[1])
            else:
                self.report.append(line)


class Rom:
    def __init__(self, mode, out_path):
        self.mode = mode
        self.out_path = out_path
        self.faults = []

        self.in_reset = False
        self.boot_requested = False
        self.in_download = False
        self.reset_count = 0
        self.baud = 115200

        self.attached = False
        self.params_set = False
        self.image = bytearray()
        self.image_at = 0
        self.image_size = 0
        self.expect_blocks = 0
        self.next_seq = 0
        self.finished = False

    def fault(self, why):
        self.faults.append(why)

    # -- control lines ----------------------------------------------------
    def set_reset(self, asserted):
        if not asserted and self.in_reset:
            #  The ROM samples IO0 as reset is released; that is the ONLY
            #  moment that decides whether it runs the app or the loader.
            self.in_download = self.boot_requested
            self.reset_count += 1
            self.baud = 115200        # a reset returns the target to the default
        self.in_reset = asserted

    def set_boot(self, asserted):
        #  "ignore_boot" simulates a target whose IO0 never gets pulled down --
        #  a broken transistor, a wrong pin.  It is also how run.sh proves this
        #  simulator can actually fail: nothing should get past SYNC.
        self.boot_requested = asserted and self.mode != "ignore_boot"

    # -- the command dispatcher -------------------------------------------
    def handle(self, frame):
        if len(frame) < 8:
            self.fault(f"runt frame, {len(frame)} bytes")
            return None
        direction, op, length, checksum = struct.unpack("<BBHI", frame[:8])
        payload = frame[8:]

        if direction != 0:
            self.fault(f"frame direction {direction}, expected 0 (request)")
        if length != len(payload):
            self.fault(f"op {op:#x}: length field {length} but {len(payload)} bytes")

        if not self.in_download:
            self.fault(f"op {op:#x} while not in download mode")
            return None

        if op == OP_SYNC:
            want = bytes([0x07, 0x07, 0x12, 0x20]) + b"\x55" * 32
            if payload != want:
                self.fault("SYNC payload is not the fixed pattern")
            #  The real ROM answers a SYNC several times over.
            return [self.reply(op)] * 8

        if op == OP_READ_REG:
            (address,) = struct.unpack("<I", payload)
            if address != 0x40001000:
                self.fault(f"READ_REG of {address:#x}, expected the chip magic")
            return [self.reply(op, value=CHIP_MAGIC)]

        if op == OP_SPI_ATTACH:
            self.attached = True
            return [self.reply(op)]

        if op == OP_SPI_PARAMS:
            if not self.attached:
                self.fault("SPI_SET_PARAMS before SPI_ATTACH")
            size = struct.unpack("<6I", payload)[1]
            if size == 0:
                self.fault("SPI_SET_PARAMS with a zero flash size")
            self.params_set = True
            return [self.reply(op)]

        if op == OP_CHANGE_BAUD:
            new, old = struct.unpack("<II", payload)
            if old != 0:
                self.fault(f"CHANGE_BAUD old rate {old}, expected 0 for the ROM")
            reply = self.reply(op)
            self.pending_baud = new
            return [reply]

        if op == OP_FLASH_BEGIN:
            if not self.params_set:
                self.fault("FLASH_BEGIN before SPI_SET_PARAMS")
            size, blocks, block_size, offset, encrypted = struct.unpack("<5I", payload)
            if block_size != BLOCK:
                self.fault(f"FLASH_BEGIN block size {block_size}, expected {BLOCK}")
            if blocks != (size + BLOCK - 1) // BLOCK:
                self.fault(f"FLASH_BEGIN claims {blocks} blocks for {size} bytes")
            if encrypted != 0:
                self.fault("FLASH_BEGIN asked for encryption")
            self.image = bytearray()
            self.image_at = offset
            self.image_size = size
            self.expect_blocks = blocks
            self.next_seq = 0
            if self.mode == "refuse_begin":
                return [self.reply(op, error=True)]
            return [self.reply(op)]

        if op == OP_FLASH_DATA:
            if len(payload) < 16:
                self.fault("FLASH_DATA header is short")
                return None
            data_len, seq, _z0, _z1 = struct.unpack("<4I", payload[:16])
            block = payload[16:]
            if data_len != BLOCK or len(block) != BLOCK:
                self.fault(f"FLASH_DATA carries {len(block)} bytes, header says {data_len}")
            if seq != self.next_seq:
                self.fault(f"FLASH_DATA sequence {seq}, expected {self.next_seq}")
            computed = 0xEF
            for byte in block:
                computed ^= byte
            if computed != checksum:
                self.fault(
                    f"FLASH_DATA block {seq} checksum {checksum:#x}, computed {computed:#x}"
                )
            self.image += block
            self.next_seq += 1
            return [self.reply(op)]

        if op == OP_FLASH_END:
            self.finished = True
            if self.next_seq != self.expect_blocks:
                self.fault(
                    f"FLASH_END after {self.next_seq} blocks, {self.expect_blocks} declared"
                )
            #  Everything past the declared size must be erased-flash padding.
            tail = self.image[self.image_size :]
            if any(byte != 0xFF for byte in tail):
                self.fault("the final block is not padded with 0xFF")
            if self.out_path:
                with open(self.out_path, "wb") as out:
                    out.write(self.image[: self.image_size])
            return [self.reply(op)]

        if op == OP_FLASH_MD5:
            offset, length, _z0, _z1 = struct.unpack("<4I", payload)
            if length == 0:
                self.fault("FLASH_MD5 over a zero-length region")
            return [self.reply(op, data=KNOWN_MD5.encode("ascii"))]

        self.fault(f"unknown opcode {op:#x}")
        return None

    def reply(self, op, value=0, data=b"", error=False):
        status = bytes([1 if error else 0, 5 if error else 0])
        body = data + status
        return slip_escape(struct.pack("<BBHI", 1, op, len(body), value) + body)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("scenario")
    parser.add_argument("--tool", default="./esp_loader_test")
    parser.add_argument("--image")
    parser.add_argument("--out")
    parser.add_argument("--mode", default="ok")
    args = parser.parse_args()

    command = [args.tool, args.scenario]
    if args.image:
        command.append(args.image)

    rom = Rom(args.mode, args.out)
    child = subprocess.Popen(
        command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    lines = Lines(child.stderr, rom)
    lines.start()

    #  Frame the child's output stream, answering each request as it completes.
    pending = bytearray()
    started = False
    escaped = False
    try:
        while True:
            chunk = child.stdout.read(1)
            if not chunk:
                break
            byte = chunk[0]

            if byte == FRAME_END:
                if started and pending:
                    if args.mode != "silent":
                        for reply in rom.handle(bytes(pending)) or []:
                            child.stdin.write(reply)
                        child.stdin.flush()
                    pending.clear()
                started = True
            elif started:
                if escaped:
                    pending.append(FRAME_END if byte == ESCAPED_END else ESCAPE)
                    escaped = False
                elif byte == ESCAPE:
                    escaped = True
                else:
                    pending.append(byte)
    except BrokenPipeError:
        pass

    code = child.wait()
    lines.join(timeout=2)

    for line in lines.report:
        print("   ", line)
    #  A stuck target repeats the same complaint hundreds of times; say each
    #  distinct one once, with a count.
    seen = {}
    for fault in rom.faults:
        seen[fault] = seen.get(fault, 0) + 1
    for fault, times in seen.items():
        print("    ROM FAULT:", fault, f"(x{times})" if times > 1 else "")

    if rom.reset_count == 0:
        rom.faults.append("the target was never reset")
        print("    ROM FAULT: the target was never reset")

    return 0 if code == 0 and not rom.faults else 1


if __name__ == "__main__":
    sys.exit(main())
