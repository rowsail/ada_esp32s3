# W5500 — a real weather forecast over plain HTTP (ESP32-S3, no FreeRTOS)

A full plaintext-HTTP client over the W5500: resolve a host **by name**
(`DNS_Client`), open a TCP socket (`GNAT.Sockets`), send an HTTP/1.0 GET, and
scrape the JSON reply.

```
GET /v1/forecast?latitude=..&longitude=..&current_weather=true HTTP/1.0
```

Open-Meteo answers over plain HTTP on port 80, so this is a straight TCP client
with no TLS. Nothing is hard-coded: `api.open-meteo.com` becomes an IP address at
run time via a DNS A-record query.

```
[wx] W5500 weather forecast (Open-Meteo, GNAT.Sockets, TCP)
[w5500] link up, IP 192.168.1.50
[wx] resolving api.open-meteo.com
[wx] GET /v1/forecast?latitude=33.97&longitude=-84.33&current_weather=true
[wx] forecast for 33.97,-84.33
[wx]   temperature : 28.4 C
[wx]   wind        : 9.7 km/h from 210 deg
[wx]   conditions  : partly cloudy
```

Bring-up lines are tagged `[w5500]`, everything else `[wx]`. If the link does
not come up, the DNS query gets no reply
(`[wx] DNS resolution failed (no resolver reply)`), or the JSON cannot be parsed
(`[wx] could not parse the forecast (response below)` — the raw response is
dumped so you can see what arrived), the corresponding failure line prints
instead.

## Editing it

`Latitude` / `Longitude` in `src/main.adb` are decimal degrees as written —
negative is south or west. `conditions` is a word looked up from the numeric WMO
weather code the API returns.

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

The LAN must reach the public internet.

## Build & flash

```sh
./x run esp32s3_w5500_weather        # build + flash + monitor
```

Needs the **embedded** profile; `build.sh` sets `ESP32S3_RTS_PROFILE=embedded`.

## See also

`esp32s3_tls_weather` is this example over **TLS 1.3** with full certificate
chain validation — same API, same scrape, https instead of http.
