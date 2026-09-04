# Wi-Fi — an HTTP fetch over a pure-Ada software TCP stack (ESP32-S3, no FreeRTOS)

Associates, brings up the **pure-Ada IPv4/ARP/UDP/TCP engine**
(`ESP32S3.WiFi.IP`), gets an address by DHCP, resolves a hostname, then opens a
TCP connection through the standard `GNAT.Sockets` facade and fetches `/` over
HTTP.

Where `esp32s3_wifi_dns` proves the UDP path, this proves **TCP**: the SYN
handshake, reliable send with retransmission, in-order receive, and the FIN
close — with **no offloaded TCP/IP stack**.

```
=== ESP32-S3 Wi-Fi HTTP (pure-Ada TCP stack) ===
Initialize ... OK
Connecting to 'myssid' ...
  associated (channel 6)
DHCP ... OK
IP=192.168.1.74 gw=192.168.1.1 dns=192.168.1.1
resolve example.com ... OK
connect 93.184.215.14:80 ... OK
--- response ---
HTTP/1.1 200 OK
...
--- end ---
total bytes = 1256
```

`total bytes` is the count actually received before the close — the number to
watch if a response looks truncated.

## Before you build

1. **Credentials.** Copy the template and fill in your network — the real file is
   git-ignored, repo-wide:

   ```sh
   cp src/wifi_credentials.ads.template src/wifi_credentials.ads
   ```

2. **The radio blobs.** The driver is pure Ada, but the lower MAC and PHY are
   Espressif's Apache-2.0 binaries, which are *fetched, not committed*:

   ```sh
   tools/fetch-wifi-blobs.sh          # pinned + sha256-checked
   ```

   `build.sh` runs this for you on a cold tree. Set `IDF_PATH` to link your own
   ESP-IDF copies instead.

## Hardware

None beyond the board; console on UART0.

## Build & flash

```sh
./build.sh && ./flash.sh /dev/ttyUSB0
```

Embedded profile.

## See also

`esp32s3_wifi_tls` puts TLS 1.3 on top of this same TCP stack.
