# W5500 — DHCP with automatic lease maintenance (ESP32-S3, no FreeRTOS)

The W5500 acquiring its address by **DHCP** instead of a static one, and then
keeping that lease alive on its own.

`ESP32S3.W5500.DHCP.Maintain` starts a background task that performs the DORA
exchange (**D**iscover / **O**ffer / **R**equest / **A**cknowledge) and then holds
the address: it **renews** (unicast) at ~T1 = 50 % of the lease, **rebinds**
(broadcast) at ~T2 = 87.5 %, and **re-acquires** on expiry — reprogramming the
chip each time. The `On_Bound` callback prints the lease on every (re)bind.

```
[dhcp] W5500 DHCP client with lease maintenance
[dhcp] link up
[dhcp] starting lease maintenance (acquire + auto-renew) ...
[dhcp] bound: IP 192.168.1.50 mask 255.255.255.0 gw 192.168.1.1 dns 192.168.1.1 lease 86400 s
```

The `bound:` line comes from `On_Bound`, so it reappears on every renewal; the
addresses come from your router. `[dhcp] link down` prints instead of `link up`
if no cable or PHY link came up in time, and `[dhcp] W5500 not found -- check
wiring` if the chip never answered the presence check.

After the first bind the chip is configured, so the layers above it — the socket
engine and `GNAT.Sockets` — are ready to use the leased address.

## Why DHCP is not portable GNAT.Sockets

DHCP is necessarily chip-level. It has to run **before an address exists**, and
then program the obtained IP, mask and gateway **into the interface** — operations
that sit below the sockets API on any platform (raw sockets plus `ioctl` on a
desktop; `Net.Configure` here). So this example rides `ESP32S3.W5500.DHCP`
directly rather than going through the facade.

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

The RJ45 must be on a LAN with a **DHCP server** — a normal home or office
router will do.

## Build & flash

```sh
./x run esp32s3_w5500_dhcp           # build + flash + monitor
```

`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`: DHCP needs the embedded or full
profile for the socket engine and the background maintenance task.
