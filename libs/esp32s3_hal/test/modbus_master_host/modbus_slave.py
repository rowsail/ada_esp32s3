#!/usr/bin/env python3
# Minimal Modbus TCP slave (server) using only the standard library -- no
# pymodbus.  Serves four tables and the common function codes so the Ada
# Modbus.Master can be exercised end to end.  Addresses at or above 0x9000 return
# exception 02 (Illegal Data Address) so the master's exception path is tested.
#
# Usage: modbus_slave.py [port]   (prints "PORT <n>" once listening)
import socket, struct, sys, threading

N = 0x10000
coils    = [ (r % 2 == 0) for r in range(N) ]   # FC01
discrete = [ (r % 3 == 0) for r in range(N) ]   # FC02
holding  = [ (1000 + r) & 0xFFFF for r in range(N) ]  # FC03
inputs   = [ (2000 + r) & 0xFFFF for r in range(N) ]  # FC04

BAD = 0x9000   # addresses >= here -> Illegal Data Address

def pack_bits(values):
    out = bytearray((len(values) + 7) // 8)
    for i, v in enumerate(values):
        if v:
            out[i // 8] |= (1 << (i % 8))
    return bytes(out)

def handle_pdu(pdu):
    fc = pdu[0]
    try:
        if fc in (1, 2):
            addr, qty = struct.unpack(">HH", pdu[1:5])
            if addr + qty > BAD:
                raise IndexError
            src = coils if fc == 1 else discrete
            data = pack_bits(src[addr:addr + qty])
            return bytes([fc, len(data)]) + data
        elif fc in (3, 4):
            addr, qty = struct.unpack(">HH", pdu[1:5])
            if addr + qty > BAD:
                raise IndexError
            src = holding if fc == 3 else inputs
            data = b"".join(struct.pack(">H", src[addr + i]) for i in range(qty))
            return bytes([fc, len(data)]) + data
        elif fc == 5:   # write single coil
            addr, val = struct.unpack(">HH", pdu[1:5])
            if addr >= BAD:
                raise IndexError
            coils[addr] = (val == 0xFF00)
            return pdu[:5]
        elif fc == 6:   # write single register
            addr, val = struct.unpack(">HH", pdu[1:5])
            if addr >= BAD:
                raise IndexError
            holding[addr] = val
            return pdu[:5]
        elif fc == 15:  # write multiple coils
            addr, qty, bc = struct.unpack(">HHB", pdu[1:6])
            if addr + qty > BAD:
                raise IndexError
            body = pdu[6:6 + bc]
            for i in range(qty):
                coils[addr + i] = bool(body[i // 8] & (1 << (i % 8)))
            return struct.pack(">BHH", fc, addr, qty)
        elif fc == 16:  # write multiple registers
            addr, qty, bc = struct.unpack(">HHB", pdu[1:6])
            if addr + qty > BAD:
                raise IndexError
            body = pdu[6:6 + bc]
            for i in range(qty):
                holding[addr + i] = struct.unpack(">H", body[2*i:2*i+2])[0]
            return struct.pack(">BHH", fc, addr, qty)
        else:
            return bytes([fc | 0x80, 0x01])   # illegal function
    except IndexError:
        return bytes([fc | 0x80, 0x02])       # illegal data address

def serve(conn):
    with conn:
        while True:
            hdr = recvn(conn, 7)
            if hdr is None:
                return
            tid, pid, length = struct.unpack(">HHH", hdr[0:6])
            unit = hdr[6]
            pdu = recvn(conn, length - 1)
            if pdu is None:
                return
            rpdu = handle_pdu(pdu)
            resp = struct.pack(">HHHB", tid, 0, len(rpdu) + 1, unit) + rpdu
            conn.sendall(resp)

def recvn(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", port))   # all interfaces, so a board on the LAN can reach it
    s.listen(5)
    print("PORT %d" % s.getsockname()[1], flush=True)
    while True:
        conn, _ = s.accept()
        threading.Thread(target=serve, args=(conn,), daemon=True).start()

if __name__ == "__main__":
    main()
