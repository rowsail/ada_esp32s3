#!/usr/bin/env python3
# Minimal Modbus TCP master (stdlib only) to poll the esp32s3_modbus_slave board.
# Usage: modbus_master.py <board-ip> [port]
import socket, struct, sys

class MB:
    def __init__(self, host, port=502):
        self.s = socket.create_connection((host, port), timeout=5)
        self.tid = 0
    def _xact(self, unit, pdu):
        self.tid = (self.tid + 1) & 0xFFFF
        adu = struct.pack(">HHHB", self.tid, 0, len(pdu) + 1, unit) + pdu
        self.s.sendall(adu)
        hdr = self._recvn(7)
        tid, pid, length = struct.unpack(">HHH", hdr[:6])
        body = self._recvn(length - 1)
        if body[0] & 0x80:
            raise RuntimeError("modbus exception %d" % body[1])
        return body
    def _recvn(self, n):
        b = b""
        while len(b) < n:
            c = self.s.recv(n - len(b))
            if not c: raise IOError("closed")
            b += c
        return b
    def read_holding(self, addr, qty, unit=1):
        r = self._xact(unit, struct.pack(">BHH", 3, addr, qty))
        return list(struct.unpack(">%dH" % qty, r[2:2 + 2 * qty]))
    def read_coils(self, addr, qty, unit=1):
        r = self._xact(unit, struct.pack(">BHH", 1, addr, qty))
        data = r[2:]
        return [bool(data[i // 8] & (1 << (i % 8))) for i in range(qty)]
    def write_register(self, addr, val, unit=1):
        self._xact(unit, struct.pack(">BHH", 6, addr, val))
    def write_registers(self, addr, vals, unit=1):
        body = struct.pack(">BHHB", 16, addr, len(vals), 2 * len(vals))
        body += b"".join(struct.pack(">H", v) for v in vals)
        self._xact(unit, body)
    def write_coil(self, addr, on, unit=1):
        self._xact(unit, struct.pack(">BHH", 5, addr, 0xFF00 if on else 0))

def main():
    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 502
    m = MB(host, port)
    ok = True
    def check(label, cond):
        nonlocal ok
        print("  %s %s" % ("ok  " if cond else "FAIL", label))
        ok = ok and cond

    h = m.read_holding(0, 6)
    print("holding 0..5:", h)
    check("holding seeded 1000..1005", h == [1000, 1001, 1002, 1003, 1004, 1005])

    c = m.read_coils(0, 8)
    print("coils 0..7  :", c)
    check("coils alternate", c == [True, False, True, False, True, False, True, False])

    m.write_register(10, 0xCAFE)
    check("write reg 10 -> read 0xCAFE", m.read_holding(10, 1) == [0xCAFE])

    m.write_registers(20, [11, 22, 33])
    check("write regs 20..22 -> [11,22,33]", m.read_holding(20, 3) == [11, 22, 33])

    m.write_coil(1, True)
    check("write coil 1 -> read True", m.read_coils(1, 1) == [True])

    print("RESULT:", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)

if __name__ == "__main__":
    main()
