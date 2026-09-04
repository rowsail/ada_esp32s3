# W5500 — a DNS lookup with the portable DNS_Client (ESP32-S3, no FreeRTOS)

A DNS name lookup over the W5500, using the **portable** `DNS_Client` module.
`DNS_Client.Resolve` sends a standard A-record query over UDP through
`GNAT.Sockets` and returns the first IPv4 address from the answer, handling DNS
**name compression** on the way.

The protocol lives entirely in the module
(`libs/esp32s3_hal/src/net/dns_client.adb`). Because it is written against
`GNAT.Sockets` and nothing chip-specific, it is portable — any project reuses it
with `with DNS_Client;`, and the same source is exercised natively by the
`dns_host` test suite.

```
[dns] W5500 DNS lookup (DNS_Client over GNAT.Sockets, UDP)
[w5500] link up, IP 192.168.1.50
[dns] resolving example.com ...
[dns] example.com = 93.184.215.14
```

The last line is whatever the resolver currently answers for that name. The
failure paths print `[w5500] not found ...` or `[w5500] link DOWN ...` (wiring or
cable), or `[dns] no answer (timed out) or no A record` if nothing came back
inside the timeout.

## Hardware

A WIZnet **W5500** module on SPI2, wired per `src/w5500_dev.adb` (S3 GPIO →
W5500 pin), at 10 MHz:

| signal | GPIO |
|---|---|
| SCLK | IO1 |
| MOSI | IO4 |
| MISO | IO45 |
| CS | IO39 |
| RSTn | IO11 |
| INTn | IO3 |

Plug the module into your LAN with a live cable. The board takes the static IP
**192.168.1.50** (gateway `.254`); edit those and the SPI pins in
`src/w5500_dev.adb` to match your own network and wiring.

## Build & flash

```sh
./x run esp32s3_w5500_dns            # build + flash + monitor
```

Needs the **embedded** profile; `build.sh` sets `ESP32S3_RTS_PROFILE=embedded`.

## See also

`esp32s3_dns_secure` does the same lookup over DoT and DoH; `esp32s3_wifi_dns`
over Wi-Fi instead of Ethernet.
