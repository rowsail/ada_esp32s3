# Wi-Fi — DNS over a pure-Ada software IP stack (ESP32-S3, no FreeRTOS)

Associates to the network in `Wifi_Credentials`, brings up the **pure-Ada
IPv4/ARP/UDP engine** (`ESP32S3.WiFi.IP`), gets an address by DHCP, registers the
Wi-Fi link as a `Net_Devices.Device` NIC, and then resolves a hostname with the
chip-neutral `DNS_Client` over `GNAT.Sockets`.

That chain is the point: **Ethernet → ARP → IP → UDP → DHCP/DNS, all in Ada**,
with **no offloaded TCP/IP stack** anywhere. The radio moves frames; everything
above that is this repo'"'"'s code.

```
=== ESP32-S3 Wi-Fi DNS (pure-Ada IP stack) ===
Initialize ... OK
Connecting to 'myssid' ...
  associated (channel 6) BSSID 3a:32:74:f2:36:02
our MAC 28:84:85:48:83:10
DHCP ... OK
IP=192.168.1.74 gw=192.168.1.1 dns=192.168.1.1
resolve api.open-meteo.com ... 172.67.72.24
resolve api.open-meteo.com ... 172.67.72.24
```

The resolve line repeats. `retry (handshake incomplete) ...` means the WPA2
four-way handshake did not finish and it is trying again. A `DHCP ... FAILED`
line carries frame counters (`rx= tx= drop= txdone= ptk_rc=`) — those tell you
whether frames are moving at all, which separates a radio problem from an IP one.

## Why the same DNS_Client as the Ethernet examples

`DNS_Client` is written against `GNAT.Sockets` and nothing chip-specific, so the
identical source runs here, over the W5500 in `esp32s3_w5500_dns`, and natively
in the `dns_host` test suite. Registering Wi-Fi as a `Net_Devices.Device` is
what makes that work — the NIC is swappable underneath the same sockets API.

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
