# Wi-Fi — HTTPS with pure-Ada TLS 1.3 over a pure-Ada TCP stack (no FreeRTOS)

Real-world HTTPS end to end on the radio, with **no offloaded TCP/IP and no C TLS
library**. Every layer above the PHY is Ada:

```
Wi-Fi assoc + DHCP → DNS → NTP (wall clock for cert validity)
→ TCP connect :443 (ESP32S3.WiFi.IP) → TLS 1.3 handshake (X25519 ECDHE,
AES-128-GCM, RSA-PSS CertificateVerify, Finished)
→ validate the chain to the pinned ISRG Root X1
→ encrypted HTTP GET → decrypt → scrape the JSON forecast
```

All crypto is Ada: SPARKNaCl plus the S3'"'"'s own accelerators.

```
=== ESP32-S3 Wi-Fi HTTPS (pure-Ada TLS 1.3 over software TCP) ===
Initialize ... OK
Connecting to 'myssid' ...
  associated (channel 6)
DHCP ... OK
IP=192.168.1.74 dns=192.168.1.1
NTP ... UTC 2026-09-04 11:42:07
TLS handshake attempt
TLS 1.3 up: cipher 0x1301
CertificateVerify (RSA-PSS): OK
server Finished: OK
chain validation to ISRG Root X1: VALID
forecast for 33.97,-84.33
  temperature : 24.8 C
  wind speed  : 11.2 km/h
```

## Two things worth noticing

**NTP is not optional.** The board has no RTC, and certificate validity cannot be
checked without trusted wall-clock time. If it fails you get
`NTP ... FAILED (cannot verify cert validity), aborting` and the run stops —
deliberately, rather than proceeding with an unknown clock.

**The board refuses to send if the peer is not authenticated.**
`WARNING: peer NOT authenticated -- aborting before sending` appears *before*
any request goes out. A TLS client that completes a handshake and then sends its
request regardless of chain validation has gained nothing over plaintext.

## The de-blob report

At the end the run prints:

```
==== DE-BLOB: Ada cipher-engine programming ran (blob's did not) ====
  Wrap_Set_Key    (was hal_crypto_set_key_entry) fired = ...
  Wrap_Clr_Key    (was hal_crypto_clr_key_entry) fired = ...
  Wrap_Crypto_Enable (was hal_crypto_enable)     fired = ...
====================================================================
```

Those three symbols are linker-wrapped so the blob'"'"'s cipher-engine programming
never executes and **no key byte reaches blob C** — the counters are the evidence
that the Ada replacements ran instead. `[cal] fresh RF-cal baseline` /
`CALBLOB:` lines are the PHY calibration blob, printed so it can be pasted into
`Cal_Store_Demo.Baseline` and reused to skip a full calibration on later boots.

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

None beyond the board; console on UART0. Needs a live internet path to the API
host.

## Build & flash

```sh
./build.sh && ./flash.sh /dev/ttyUSB0
```

Embedded profile.

## See also

`esp32s3_tls_weather` is the identical pipeline over W5500 Ethernet instead of
Wi-Fi — the same `TLS_Client`, the same trust anchor, a different NIC.
