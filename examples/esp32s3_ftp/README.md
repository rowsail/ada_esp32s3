# esp32s3_ftp — FTP client over the W5500

An **FTP client** over the WIZnet W5500, driven through the portable
`FTP_Client` package (itself written against the `GNAT.Sockets` facade, so the
same code runs on desktop GNAT.Sockets and on the bare-metal W5500 alike).

It logs in, prints a file's `SIZE`, downloads it (`RETR`) to the console, lists
the directory (`NLST`), and quits — **passive mode, binary**, the
embedded-friendly profile (only outbound connections, so it needs no listening
socket and works behind NAT).

## Run

```
./x run esp32s3_ftp
```

The board takes the static IP **192.168.1.50** (/24, gateway .254 — set in
`w5500_dev.adb`). Put it and an FTP server on the same subnet and point
`Server_IP` (top of `main.adb`) at the server. A zero-dependency local server:

```
python3 libs/esp32s3_hal/test/ftp_host/ftp_server.py     # prints its port
```

…or any FTP daemon on port 21 with the configured credentials.

## Expected output

```
[ftp] W5500 FTP client (FTP_Client over GNAT.Sockets)
[w5500] link up, IP 192.168.1.50
[ftp] connecting to 192.168.1.100:21 ...
[ftp] logged in.
[ftp] SIZE /hello.txt = 30
[ftp] --- RETR /hello.txt ---
hello from the ftp host test
[ftp] --- NLST ---
hello.txt
[ftp] done.
```

## Where the protocol is verified

The `FTP_Client` protocol logic (login, `SIZE`, `RETR`, `STOR`, round-trip,
`NLST`, `DELE`, `QUIT`) is exercised end-to-end on the host against a real FTP
server by `libs/esp32s3_hal/test/ftp_host/run.sh` — the same source, compiled
against native GNAT.Sockets. This on-board example is the same code over the
W5500 socket backend.

## The data-sink callback

`FTP_Client.Retrieve` / `List` stream their bytes to a `Data_Sink` callback,
which (like every callback in this HAL) must be **library-level and
closure-free** — here `FTP_Print.Put_Chunk`, not a subprogram nested in `Main`.
