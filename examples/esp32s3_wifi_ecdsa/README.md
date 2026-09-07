# Wi-Fi — pure-Ada P-256 / P-384 authenticating a real ECDSA certificate chain

The sibling [`esp32s3_wifi_tls`](../esp32s3_wifi_tls) example proves the whole
HTTPS pipeline, but the chain it walks (`api.open-meteo.com` up to ISRG Root X1)
is **RSA end to end** — it never calls `P256.Verify` or `P384.Verify`. The only
other on-board exercise of P-384, `esp32s3_dns_secure`, needs a W5500 on SPI2.

This example closes that gap. Same pipeline, different peer: a host whose chain
is ECDSA all the way up to the **same pinned ISRG Root X1** the repo already
ships, so no new trust anchor is needed.

```
Wi-Fi assoc + DHCP → DNS → NTP (wall clock for cert validity)
→ TCP connect :443 → TLS 1.3 handshake
→ validate an all-ECDSA chain to the pinned ISRG Root X1
→ report which primitive verified which link
```

## Why the chain shape matters

A certificate is verified with its **issuer's** key, so what a chain exercises
is the key algorithm of the cert one step *up*. At the time of writing
`letsencrypt.org` gives:

| # | subject | key | verified with |
|---|---|---|---|
| 1 | `CN=letsencrypt.org` | EC P-256 | [2]'s **P-384** |
| 2 | `CN=YE2` (Let's Encrypt) | EC P-384 | [3]'s **P-384** |
| 3 | `CN=Root YE` (ISRG) | EC P-384 | [4]'s **P-384** |
| 4 | `CN=ISRG Root X2` | EC P-384 | the pinned anchor (RSA) |

So chain validation runs **`P384.Verify` three times**, and the handshake's
`CertificateVerify` — signed with the leaf's P-256 key — runs **`P256.Verify`**.

The example *reports* that breakdown rather than asserting it, and **fails if the
chain stops exercising ECDSA**. A CA can re-issue under a different key at any
time; if that happens this says so instead of quietly passing on a path that no
longer touches `p256.adb` / `p384.adb`.

## Build & run

Copy `src/wifi_credentials.ads.template` to `src/wifi_credentials.ads` and fill
in your network — that file is `.gitignore`d, so your SSID and passphrase are
never committed.

```sh
./x run wifi_ecdsa          # or: ./build.sh && ./flash.sh /dev/ttyACM0
```

## Output (real run)

```
=== ESP32-S3 Wi-Fi ECDSA (pure-Ada P-256 / P-384 chain auth) ===
Initialize ... OK
Connecting to 'myssid' ...
  associated (channel 3)
DHCP ... IP=192.168.1.199 dns=192.168.1.254
resolving letsencrypt.org ... 98.84.224.111
NTP ... UTC 2026-9-7 2:18
TLS 1.3 up: cipher 0x1301
CertificateVerify: OK
server Finished: OK
chain validation to ISRG Root X1: 4 certs -> VALID
chain, leaf first:
  [1] key=EC P-256 -- verified with [2] key=EC P-384
  [2] key=EC P-384 -- verified with [3] key=EC P-384
  [3] key=EC P-384 -- verified with [4] key=EC P-384
  [4] key=EC P-384 -- verified with the pinned ISRG Root X1 (RSA)
primitives exercised on this run:
  P256.Verify : CertificateVerify=yes, chain links=0
  P384.Verify : chain links=3
response: HTTP/1.0 200 OK

[ecdsa] result: ALL PASS (P-384 links= 3, P-256 links= 0 )
```

## Hardware

Nothing beyond the board — the radio only, console on UART0. Needs a live
internet path to the host. (This is the point: `esp32s3_dns_secure` is the other
P-384 exercise and it cannot run without a W5500.)
