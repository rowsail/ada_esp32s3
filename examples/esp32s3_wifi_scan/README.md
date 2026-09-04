# Wi-Fi — scan and WPA2 connect (ESP32-S3, no FreeRTOS)

The radio brought up end to end on **`libs/esp32s3_wifi`**, this repo'"'"'s pure-Ada
Wi-Fi driver. It initialises the radio (`ESP32S3.WiFi.Initialize`), lists the
access points in range once (`Scan`), then associates to the AP in
`Wifi_Credentials` and runs the **pure-Ada WPA2 four-way handshake**
(`Connect`) — looping, so the link is re-established if it drops.

```
=== ESP32-S3 Wi-Fi scan ===
Initialize ... OK
Scanning ...
  found 6 AP(s):
  - myssid  ch=6  rssi=-51  WPA2-PSK  bssid=3a:32:74:f2:36:02
  - neighbour  ch=11  rssi=-77  WPA2-PSK  bssid=...
Connecting to AP 'myssid' ...
  connect start: OK
*** ASSOCIATED ***
```

`*** ASSOCIATED ***` means the four-way handshake completed and the link is up;
`not associated` means it did not within the ~6 s poll, and the loop tries again
after 4 s. `init failed -- radio not up; see which OS-adapter slot halted.`
means the radio never came up at all.

`Target_BSSID` in the credentials pins one AP when several share an SSID with
different security; all-zero means "strongest match".

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

None beyond the board. **The console is on UART0** on this example (the board it
was written for is a UART-bridge, not USB-Serial-JTAG); a JTAG board would use
the default console instead.

## Build & flash

```sh
./x run esp32s3_wifi_scan            # build + flash + monitor
```

Embedded profile, set by `build.sh`.

## See also

`esp32s3_wifi_sniff` decodes this association from a second board — the
ground-truth tool when a connect will not complete.
