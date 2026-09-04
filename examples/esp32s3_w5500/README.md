# W5500 — the whole Ethernet stack, then a GNAT.Sockets echo server (no FreeRTOS)

The WIZnet **W5500** stack exercised end to end, then ordinary sockets on top.
The bring-up is W5500-specific — the SPI transport (`ESP32S3.W5500`), the socket
engine (`ESP32S3.W5500.Sockets`) and the `INTn` interrupt path
(`ESP32S3.W5500.Interrupts`) — but once the chip is registered as the default
network interface, the echo loop is just
`Create`/`Bind`/`Listen`/`Accept`/`Receive`/`Send`/`Close`: **the same standard
GNAT.Sockets code you would write on a desktop.**

```
[w5500] WIZnet W5500 GNAT.Sockets echo server
[w5500] VERSIONR = 0x04  (W5500 present)
[w5500] IP = 192.168.1.50
[w5500] link up
[w5500] interrupts armed (INTn=IO3)
[w5500] GNAT.Sockets TCP echo on 192.168.1.50:5000  (try:  nc 192.168.1.50 5000)
[w5500] client 192.168.1.20
[w5500] client disconnected
```

Try it with:

```sh
nc 192.168.1.50 5000
```

## Reading the output

`VERSIONR = 0x04` is the W5500's fixed version byte. **Any other value** prints
`(unexpected -- check wiring!)` and the demo parks forever — that is the
first thing to look at, because it means SPI is not talking to the chip at all.

`link up` becomes `link down` if the PHY never negotiated (cable, switch port).
`interrupts armed (INTn=IO3)` becomes `polling` if `INTn` could not be armed —
the example still works, it just spins instead of blocking on the interrupt.

`client ...` / `client disconnected` print per connection.

## Why this one inlines the bring-up

The client examples (`w5500_http`, `w5500_ntp`, `w5500_dns`, `w5500_weather`)
hide the bring-up inside a `W5500_Dev` package so their `Main` stays portable
GNAT.Sockets. **This one inlines it on purpose**: it is the "whole stack in one
file" example, so you can read the chip bring-up and interrupt arming in the same
place as the sockets code that uses them. The echo loop itself is still portable.

## Hardware

A WIZnet **W5500** module on SPI2:

| signal | GPIO |
|---|---|
| SCLK | IO1 |
| MOSI | IO4 |
| MISO | IO45 |
| CS | IO39 |
| RSTn | IO11 |
| INTn | IO3 |

The board takes the static IP **192.168.1.50**. Plug the RJ45 into your LAN.

## Build & flash

```sh
./x run esp32s3_w5500                # build + flash + monitor
```

Needs the **embedded** (or full) profile: the W5500 driver uses a controlled SPI
`Session`, which the default light-tasking profile does not provide. `build.sh`
sets `ESP32S3_RTS_PROFILE=embedded`.

## See also

`esp32s3_w5500_dhcp` gets the address from a router instead of hard-coding it;
`esp32s3_w5500_http` / `_ntp` / `_dns` are the client side.
