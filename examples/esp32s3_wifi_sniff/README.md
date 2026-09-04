# Wi-Fi — promiscuous sniffer, a WPA2 ground-truth tool (ESP32-S3, no FreeRTOS)

This one runs on a **second board, next to the one under test**. It brings the
radio up, parks on a channel, and decodes the management and EAPOL frames that
matter for association: assoc request/response, auth, deauth, and EAPOL-Key.

Point it at the AP'"'"'s channel, trigger a connect on the other board, and read
**exactly** what the station sends (its RSN information element) and how the AP
answers (status code, or deauth reason). When a WPA2 connect fails, the station'"'"'s
own logs tell you it failed; this tells you *why*.

```
=== ESP32-S3 Wi-Fi sniffer ===
Initialize ... OK
sniffer MAC 84:f7:03:aa:bb:cc
sniffing (hopping 1/6/11) ...
```

After that, decoded frames stream from the promiscuous callback inside
`ESP32S3.WiFi.Sniffer`.

## Configuring it

`src/main.adb` sets up filters that are **hard-coded to one diagnosis session**
and almost certainly need editing for yours:

* `Watch_Beacon (...)` — the BSSID whose data frames get printed and raw-dumped.
* `Watch_Sta (...)` — a station MAC; any frame involving it is printed.
* `Set_Channel (...)` — the sniffer parks here. Set it to the target AP'"'"'s
  channel; hopping 1/6/11 catches the assoc whichever BSSID the station picks,
  but parking is more reliable once you know the channel.

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

(The sniffer itself does not associate, so the credentials only matter if you
build the other examples from the same tree.)

## Hardware

Two boards: this one sniffing, and the one under test running
`esp32s3_wifi_scan` (or any of the Wi-Fi examples). Console on UART0.

## Build & flash

```sh
./build.sh && ./flash.sh /dev/ttyACM1     # note the SECOND board's port
```

Embedded profile.
