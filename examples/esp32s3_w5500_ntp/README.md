# W5500 — SNTP time client (ESP32-S3, no FreeRTOS)

An SNTP/NTP client over the W5500: query a public time server and print the UTC
date and time. The work is done by the reusable **`NTP_Client`** module, which is
written entirely against `GNAT.Sockets` UDP — so it is portable, and the same
source runs against desktop GNAT.Sockets.

```
[ntp] W5500 NTP time client (NTP_Client over GNAT.Sockets)
[w5500] link up, IP 192.168.1.50
[ntp] querying 216.239.35.0 ...
[ntp] time = 2026-06-26 14:03:21 UTC
```

Success is that final `time = ... UTC` line.

* `[w5500] not found ...` — SPI never reached the chip; the program parks.
* `[w5500] link DOWN ...` — the cable or switch port never negotiated.
* `[ntp] no response from the time server` — the query timed out (server
  unreachable, or UDP/123 blocked on the way out).

## Why this matters beyond the clock

A board with no RTC cannot check a certificate's `notBefore` / `notAfter`
without a trusted time source, so NTP is a prerequisite for TLS rather than a
convenience — `esp32s3_tls_weather` queries it first and **aborts** if it fails.

## Hardware

A WIZnet **W5500** SPI Ethernet module on SPI2. Pins are set in
`src/w5500_dev.adb`, at 10 MHz:

| signal | GPIO |
|---|---|
| SCLK | IO1 |
| MOSI | IO4 |
| MISO | IO45 |
| CS | IO39 |
| RSTn | IO11 |
| INTn | IO3 |

The board takes the static IP **192.168.1.50** (gateway `.254`, /24) — there is
no DHCP here. Edit that and the pins in `src/w5500_dev.adb` for your own network.

The LAN must reach the public internet: the time server is on it. Edit
`NTP_Server` in `src/main.adb` for a different one.

## Build & flash

```sh
./x run esp32s3_w5500_ntp            # build + flash + monitor
```

Uses the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`),
not the default light-tasking profile.
