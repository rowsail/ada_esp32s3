#!/usr/bin/env python3
"""Minimal passive-mode FTP server (stdlib only) for the FTP_Client host test.

Serves a temp directory on 127.0.0.1.  Supports exactly the subset the Ada
client uses: USER/PASS, TYPE I, PWD/CWD, MKD/RMD, DELE, SIZE, PASV, RETR/STOR,
NLST, QUIT.  Single client, sequential -- enough to exercise the client end to
end.  Prints the chosen control port as the first stdout line.
"""
import os, socket, sys, tempfile, threading

ROOT = tempfile.mkdtemp(prefix="ftp_host_")
# Seed a file the client downloads + size-checks.
with open(os.path.join(ROOT, "hello.txt"), "wb") as f:
    f.write(b"hello from the ftp host test\r\n")


def handle(conn):
    conn.sendall(b"220 host test ready\r\n")
    rest = b""
    cwd = "/"
    pasv_sock = None

    def reply(s):
        conn.sendall((s + "\r\n").encode())

    def readline():
        nonlocal rest
        while b"\r\n" not in rest:
            chunk = conn.recv(1024)
            if not chunk:
                return None
            rest += chunk
        line, rest = rest.split(b"\r\n", 1)
        return line.decode(errors="replace")

    def localpath(arg):
        p = arg if arg.startswith("/") else (cwd.rstrip("/") + "/" + arg)
        return os.path.join(ROOT, p.lstrip("/"))

    while True:
        line = readline()
        if line is None:
            break
        parts = line.split(" ", 1)
        cmd = parts[0].upper()
        arg = parts[1] if len(parts) > 1 else ""

        if cmd == "USER":
            reply("331 need password")
        elif cmd == "PASS":
            reply("230 logged in")
        elif cmd == "SYST":
            reply("215 UNIX Type: L8")
        elif cmd == "TYPE":
            reply("200 type set")
        elif cmd == "PWD":
            reply('257 "%s"' % cwd)
        elif cmd == "CWD":
            cwd = arg if arg.startswith("/") else (cwd.rstrip("/") + "/" + arg)
            reply("250 cwd ok")
        elif cmd == "MKD":
            os.makedirs(localpath(arg), exist_ok=True)
            reply('257 "%s" created' % arg)
        elif cmd == "RMD":
            try:
                os.rmdir(localpath(arg)); reply("250 rmd ok")
            except OSError:
                reply("550 rmd failed")
        elif cmd == "DELE":
            try:
                os.remove(localpath(arg)); reply("250 dele ok")
            except OSError:
                reply("550 no such file")
        elif cmd == "SIZE":
            try:
                reply("213 %d" % os.path.getsize(localpath(arg)))
            except OSError:
                reply("550 no such file")
        elif cmd == "PASV":
            pasv_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            pasv_sock.bind(("127.0.0.1", 0))
            pasv_sock.listen(1)
            p = pasv_sock.getsockname()[1]
            reply("227 Entering Passive Mode (127,0,0,1,%d,%d)" % (p >> 8, p & 0xFF))
        elif cmd in ("RETR", "STOR", "NLST"):
            if pasv_sock is None:
                reply("425 use PASV first"); continue
            reply("150 opening data connection")
            data, _ = pasv_sock.accept()
            if cmd == "RETR":
                try:
                    with open(localpath(arg), "rb") as f:
                        data.sendall(f.read())
                    ok = True
                except OSError:
                    ok = False
            elif cmd == "STOR":
                with open(localpath(arg), "wb") as f:
                    while True:
                        b = data.recv(4096)
                        if not b:
                            break
                        f.write(b)
                ok = True
            else:  # NLST
                names = "".join(n + "\r\n" for n in sorted(os.listdir(ROOT)))
                data.sendall(names.encode())
                ok = True
            data.close()
            pasv_sock.close(); pasv_sock = None
            reply("226 transfer complete" if ok else "550 transfer failed")
        elif cmd == "QUIT":
            reply("221 bye")
            break
        else:
            reply("502 not implemented")
    conn.close()


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    print(srv.getsockname()[1], flush=True)   # first line: the control port
    # Serve a bounded number of sessions, then exit (test runs one).
    conn, _ = srv.accept()
    handle(conn)
    srv.close()


if __name__ == "__main__":
    main()
