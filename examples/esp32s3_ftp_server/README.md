# esp32s3_ftp_server — anonymous FTP server over the ext4 flash

An anonymous **FTP server** on the ESP32-S3 that exposes the **ext4-on-W25Q-flash**
filesystem to the network: a desktop FTP client can browse, download, **upload**,
delete and mkdir on the board's flash. It is the server counterpart to
`esp32s3_ftp` / `esp32s3_ftp_inet` (the FTP *client*), and ties the whole stack
together — W5500 + GNAT.Sockets + `FTP_Server` on top of
`ESP32S3.Ext4 → Block_Dev.WL → W25Q`.

Passive mode, a fixed data port (50000), one client at a time.

## Run

```
./x run esp32s3_ftp_server
```

The board comes up by **DHCP** (router supplies IP/gateway/DNS) and prints its
address, then formats a **fresh** ext4 on the flash (seeded with `/readme.txt` and
an `/uploads` directory) and serves it. From a host on the same LAN:

```
ftp <board-ip>                       # user: anything, password: anything
python3 -c "from ftplib import FTP; f=FTP('<board-ip>'); f.login(); print(f.nlst('/'))"
```

…or point FileZilla / a browser at `ftp://<board-ip>/`.

## Verified on hardware

Against Python `ftplib`: login, `NLST`/`LIST` (proper `ls -l`), `RETR` + `SIZE`,
`STOR` (upload) with a byte-exact read-back round-trip, `MKD`, `DELE` — all backed
by the on-flash ext4 FS.

## Notes

- **The flash is reformatted on every boot** (a fresh ext4), so uploads survive
  only until the next reset. To keep data, mount an existing FS instead of
  `Mkfs.Format` (see `esp32s3_ext4_flash`).
- Anonymous **read-write**. `FTP_Server.Run` takes a `Read_Only` flag to refuse
  `STOR`/`DELE`/`MKD`/`RMD`.
- Make sure outbound FTP and the passive data port (50000) are permitted between
  the client and the board on your LAN.
- The mount objects (`Flash_FS`) are **library-level**: `FTP_Server` stores the
  Mount access in a library-level variable, so the Mount must outlive the call —
  a `Main`-local one fails the runtime accessibility check.
