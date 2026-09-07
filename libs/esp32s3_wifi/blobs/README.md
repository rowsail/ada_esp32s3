# Espressif Wi-Fi / PHY blobs

The `esp32s3_wifi` driver is pure Ada, but the ESP32-S3 radio's lower-MAC and
PHY are only available from Espressif as **binary** libraries. This directory
carries the licensing/provenance record for those blobs and the lock file that
pins them; the `.a` files themselves are **fetched, not committed** (see
`.gitignore`).

## Fetching

```sh
tools/fetch-wifi-blobs.sh
```

downloads the four archives pinned in `MANIFEST.lock` from their upstream
commits, verifies each against its sha256, and writes them here. The example
`build.sh` scripts run this automatically if a blob is missing. If you already
have ESP-IDF, set `IDF_PATH` and the build will use your local copies instead.

**Four are fetched; not every example links four.** `libcore.a` is retired on the
de-blobbed path (`esp32s3_wifi_tls`, `esp32s3_wifi_ecdsa`): the handful of symbols
it was pulled in for are provided in Ada by `ESP32S3.WiFi.Core_Shim`, because the
misc-NVS code behind them is dormant on a port with no NVS. The other examples
still link it. See [`../BRINGUP.md`](../BRINGUP.md) for that story and for the
crypto the driver no longer takes from a blob either.

## Provenance

Matching **ESP-IDF v5.4.4**:

| blob | upstream repo | commit |
|------|---------------|--------|
| `libcore.a`, `libnet80211.a`, `libpp.a` | [espressif/esp32-wifi-lib](https://github.com/espressif/esp32-wifi-lib) | `7bd1599468d0912b7773ba225a6ef05252633e88` |
| `libphy.a` | [espressif/esp-phy-lib](https://github.com/espressif/esp-phy-lib) | `ac744ff2c5c39c63f8cdd503d4074905647fdbb6` |

## License

Both upstream libraries are licensed under the **Apache License 2.0** — see
`LICENSE.esp32-wifi-lib` and `LICENSE.esp-phy-lib` (verbatim copies from the
upstream repos). Copyright © Espressif Systems (Shanghai) Co., Ltd. The blobs
are redistributed unmodified under those terms; a release archive that bundles
them includes these license files for attribution.
