# esp32s3_ftp_inet — real-world FTP over the W5500

A real-world `FTP_Client` run against a public internet FTP server (default
**`ftp.gnu.org`**, anonymous). It's the FTP analogue of `esp32s3_tls_weather`,
brought up with **DHCP** — the router supplies the IP, gateway *and* DNS, so
there's nothing to hand-configure for your LAN.

It:
1. resolves `ftp.gnu.org` via the DHCP-provided DNS,
2. logs in **anonymously**,
3. `SIZE` + `RETR` a file (`/README`) — counting bytes and comparing to `SIZE`,
4. `NLST` the root directory, and `QUIT`.

Passive mode, binary, **read-only** (anonymous FTP can't upload). To target a
different server edit the constants at the top of `main.adb`.

## Run

```
./x run esp32s3_ftp_inet
```

Plug the W5500 into a LAN with a **DHCP server** and internet access — the board
gets its IP, gateway and DNS from the router (no editing needed). Make sure
outbound FTP (port 21, passive data) is permitted on your network — some
networks/firewalls block FTP.

**DHCP or static.** `Bring_Up` takes a `W5500_Dev.IP_Settings`; `main.adb`
defaults to `W5500_Dev.DHCP_Config`. For a fixed address, set it to a static
config instead (the alternative is shown commented at the top of `main.adb`):

```ada
Net_Config : constant W5500_Dev.IP_Settings :=
  (Use_DHCP => False,
   IP      => ESP32S3.W5500.IPv4 (192, 168, 1, 50),
   Subnet  => ESP32S3.W5500.IPv4 (255, 255, 255, 0),
   Gateway => ESP32S3.W5500.IPv4 (192, 168, 1, 1),
   DNS     => ESP32S3.W5500.IPv4 (8, 8, 8, 8));
```

## Expected output (abridged)

```
[ftp] real-world FTP client -> ftp.gnu.org (anonymous)
[w5500] link up; DHCP IP 192.168.1.50 gw 192.168.1.1 dns 192.168.1.1
[ftp] resolving ftp.gnu.org via 192.168.1.1 ...
[ftp] ftp.gnu.org = 209.51.188.20
[ftp] logged in.
[ftp] SIZE /README = 2814 bytes
[ftp] RETR /README: 2814 bytes received, result OK
[ftp] --- NLST / ---
/README
/gnu
/pub
...
[ftp] done.
```

## Verification status

The `FTP_Client` protocol is verified on the host against real servers — both
`pyftpdlib` (RFC-compliant, `vsftpd`-class) and the live **`ftp.gnu.org`** over
the internet (`SIZE`/`RETR` byte-exact); see `libs/esp32s3_hal/test/ftp_host`
(`run.sh` offline, `run_real.sh` against the real server). This example is the
same `FTP_Client` source over the W5500 backend, and it **has run on a board**:
the `RETR` from `ftp.gnu.org` worked first try over the W5500.

The upload direction is where the board disagreed with the host, and it is worth
knowing about. Two bugs lived in the W5500 send path that no host test could
reach, because a desktop's socket buffers are megabytes deep and its close is
graceful: `Send` gave up with `No_Space` instead of waiting for the peer to drain
the 2 KB transmit buffer, and `Close` issued the abrupt `CLOSE` instead of a
`DISCON`, so the server never saw end-of-stream. Both are fixed, and
[`esp32s3_ftp`](../esp32s3_ftp) now verifies a 1 MiB `STOR` byte-for-byte
against a local server. The book's networking chapter tells the whole story.
