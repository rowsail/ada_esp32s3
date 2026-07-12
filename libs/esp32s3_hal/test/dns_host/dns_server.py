#!/usr/bin/env python3
"""Stdlib-only mini DNS server for the DNS_Client host test: UDP and TCP on
the same port, answering every A query with 10.11.12.13 -- except:

  *.tconly.example : UDP answers TRUNCATED (TC set, no answers); TCP answers
                     fully -- the classic fall-back-to-TCP case.
  *.badid.example  : the reply carries the WRONG transaction id -- the
                     anti-spoofing check must refuse it.

Usage: dns_server.py PORT.  Prints READY once both sockets listen."""
import socket, struct, sys, threading


def qname_of(msg):
    labels, i = [], 12
    while i < len(msg):
        n = msg[i]
        if n == 0:
            break
        labels.append(msg[i + 1:i + 1 + n].decode("ascii", "replace"))
        i += 1 + n
    return ".".join(labels), i + 1  # name, index past the root label


def reply_for(query, via_tcp):
    name, qend = qname_of(query)
    qid = query[0:2]
    question = query[12:qend + 4]                 # QNAME + QTYPE + QCLASS
    if name.endswith("badid.example"):
        qid = bytes([query[0] ^ 0xFF, query[1]])  # wrong id on purpose
    if name.endswith("tconly.example") and not via_tcp:
        flags = struct.pack(">H", 0x8380)         # response, TC, no answers
        return qid + flags + struct.pack(">HHHH", 1, 0, 0, 0) + question
    flags = struct.pack(">H", 0x8180)
    answer = (b"\xc0\x0c" + struct.pack(">HHIH", 1, 1, 60, 4)
              + bytes([10, 11, 12, 13]))
    return (qid + flags + struct.pack(">HHHH", 1, 1, 0, 0)
            + question + answer)


def udp_loop(port):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", port))
    ready.release()
    while True:
        msg, peer = s.recvfrom(2048)
        if len(msg) >= 12:
            s.sendto(reply_for(msg, via_tcp=False), peer)


def tcp_loop(port):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("127.0.0.1", port))
    s.listen(4)
    ready.release()
    while True:
        conn, _ = s.accept()
        try:
            hdr = conn.recv(2)
            if len(hdr) == 2:
                (need,) = struct.unpack(">H", hdr)
                msg = b""
                while len(msg) < need:
                    part = conn.recv(need - len(msg))
                    if not part:
                        break
                    msg += part
                if len(msg) == need:
                    out = reply_for(msg, via_tcp=True)
                    conn.sendall(struct.pack(">H", len(out)) + out)
        finally:
            conn.close()


port = int(sys.argv[1])
ready = threading.Semaphore(0)
threading.Thread(target=udp_loop, args=(port,), daemon=True).start()
threading.Thread(target=tcp_loop, args=(port,), daemon=True).start()
ready.acquire()
ready.acquire()
print("READY", flush=True)
threading.Event().wait()
