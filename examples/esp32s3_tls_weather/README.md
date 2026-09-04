# Pure-Ada TLS 1.3 — a real HTTPS fetch over the W5500 (ESP32-S3, no FreeRTOS)

Real-world HTTPS, end to end, with **no C TLS library anywhere**: fetch a live
weather forecast from `api.open-meteo.com` on a bare-metal ESP32-S3. The whole
pipeline runs in one example.

```
DNS (DNS_Client) → TCP connect :443 → TLS 1.3 handshake (X25519 ECDHE,
HKDF key schedule, AES-128-GCM records, RSA-PSS CertificateVerify, Finished)
→ validate the chain to a pinned ISRG Root X1 → encrypted HTTP GET
→ decrypt → parse the JSON forecast
```

All crypto is Ada — SPARKNaCl plus the S3's own AES/SHA/RSA accelerators.

```
[wx] pure-Ada HTTPS weather (TLS 1.3 over the W5500)
[wx] resolving api.open-meteo.com
[wx] getting time from NTP ...
[wx] NTP UTC = 2026-09-04 11:42:07
[wx] handshake attempt
[wx] TLS 1.3 up: cipher 0x1301
[wx] forecast for 33.97,-84.33
[wx]   temperature : 24.8 C
[wx]   wind speed  : 11.2 km/h
```

Lines from the NIC bring-up are tagged `[w5500]`; everything else is `[wx]`. Any
earlier failure prints a `failed` / `aborting` line and **parks the board** — it
does not reset, so the last line stays on screen.

## Why NTP comes first

The board has no RTC. Certificate validity — `notBefore` / `notAfter` — cannot be
checked without trusted wall-clock time, and a device that skips that check
accepts expired and revoked-then-reissued certificates forever. So the run
queries NTP before the handshake and **aborts if NTP fails** rather than
proceeding with an unknown clock.

## What a successful run proves

This is the example that shows the pure-Ada stack works against the real
internet, not against a test server you configured to agree with it:

* a **real** certificate chain, presented by a real CDN, validated to the real
  **ISRG Root X1** (Let's Encrypt) pinned in `trust_anchors.ads`;
* **RSA-PSS** `CertificateVerify` — not the simpler PKCS#1 v1.5 — because that is
  what TLS 1.3 requires and what real servers send;
* a full **HKDF key schedule** and AES-128-GCM record protection that a real
  server's implementation agrees with, byte for byte.

## Hardware

A **W5500** Ethernet module on SPI2 — pins are in `w5500_dev.adb` — and a live
internet path to the API host. Edit `Latitude` / `Longitude` in `src/main.adb`
for another place.

## Build & flash

```sh
./x run esp32s3_tls_weather          # build + flash + monitor
```

Needs the **embedded** profile; `build.sh` sets `ESP32S3_RTS_PROFILE=embedded`.

## See also

`esp32s3_tls_hello` is the same handshake against a local `openssl s_server`,
with more of the intermediate state printed — start there if this one fails.
`esp32s3_wifi_tls` runs the identical pipeline over Wi-Fi instead of Ethernet.
