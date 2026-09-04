# W5500 — an HTTP GET client over GNAT.Sockets (ESP32-S3, no FreeRTOS)

An HTTP **client** over the WIZnet W5500, driven through the `GNAT.Sockets`
facade on a TCP stream socket. It connects out to a web server, sends
`GET / HTTP/1.0`, and prints the response until the server closes.

This exercises the TCP **client** path — `Connect_Socket` / `Send_Socket` /
`Receive_Socket` — which the `esp32s3_w5500` echo server, being a TCP *server*,
never touches.

```
[http] W5500 HTTP GET client (GNAT.Sockets, TCP)
[w5500] link up, IP 192.168.1.50
[http] connecting to 192.168.1.100:8000 ...
[http] --- response ---
HTTP/1.0 200 OK
Server: SimpleHTTP/0.6 Python/3.12.3
...
[http] --- done ---
```

`[w5500] not found ...` means SPI never reached the chip, and the run idles
without ever attempting the connect. `[http] connection failed -- is a web
server listening on ...` means the TCP connect itself was refused or timed out.

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

Point `Server_IP` in `src/main.adb` at a host on that subnet serving HTTP on
port 8000 — for example `python3 -m http.server 8000`.

## Build & flash

```sh
./x run esp32s3_w5500_http           # build + flash + monitor
```

Uses the IDF-free bare boot; `build.sh` sets the **embedded** profile
(`ESP32S3_RTS_PROFILE=embedded`), not the default light-tasking one.

## See also

`esp32s3_w5500_weather` adds DNS and a JSON scrape on top of the same client;
`esp32s3_tls_weather` does it over TLS.
