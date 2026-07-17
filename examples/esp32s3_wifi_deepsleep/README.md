# Wi-Fi + deep sleep — the power-domain cut *is* the radio power-down (ESP32-S3)

Associates to Wi-Fi with the pure-Ada driver (`libs/esp32s3_wifi`), holds the
link briefly, then enters **deep sleep** via **`ESP32S3.RTC`**. The point it
makes: you do **not** need an explicit `esp_wifi_stop` / `phy_close_rf` before
deep sleep — the RTC controller powers down the entire digital + RF domain (the
radio, the MAC and the CPU all lose power), so **entering deep sleep is itself
the radio power-down**. On the timer wake the chip *resets* and re-runs from the
top, re-initialising the radio from scratch.

```
=== ESP32-S3 Wi-Fi + deep sleep ===
boot: wake=power-on         retained boot-count=1
Initialize ... OK
Scan found 10 AP(s)
Connecting to AP 'YOURSSID' ...
  connect start: OK
  connected=yes
Entering deep sleep -- the RTC power-down cuts the Wi-Fi RF, MAC ...
rst:0x5 (DSLEEP) ...
=== ESP32-S3 Wi-Fi + deep sleep ===
boot: wake=deep-sleep-timer  retained boot-count=2
...
boot: wake=deep-sleep-timer  retained boot-count=3
[final] cycled 3 boots across deep sleep -- staying awake.
```

## What it shows

A boot counter lives in **retained RTC slow memory** (survives deep sleep). Each
boot the program brings the radio up, scans, associates, holds the link for a few
seconds (radio on, ~100 mA measurable), then deep-sleeps with a ~5 s timer wake.
Across the cycles the counter climbs `1 → 2 → 3`, the wake cause turns into
`deep-sleep-timer`, and the ROM's own reset line reads `rst:0x5 (DSLEEP)` — so
the digital core (and the radio with it) really powered down and woke, with a
clean re-initialisation of the whole Wi-Fi stack each time.

### Deep sleep vs. light / modem sleep

For **deep sleep** the domain cut does the work, so nothing extra is required
here. For **light / modem sleep** — where the digital domain stays powered and
the stack RF-gates between DTIM beacons — the radio *must* be powered down
explicitly (`phy_close_rf`), and the lower-MAC blob already drives that on/off
cycle continuously (see `ESP32S3.WiFi.PHY.Phy_Disable`). This example targets
deep sleep, so it relies on the power-down that deep sleep gives for free.

## Build & flash

```sh
./x run esp32s3_wifi_deepsleep       # build + flash + monitor
```

First copy `src/wifi_credentials.ads.template` to `src/wifi_credentials.ads` and
fill in your network (the real file is git-ignored). Built as the **embedded**
profile. Console is on **UART0** (this board is wired to a UART bridge, not the
USB-serial-JTAG); the console drops during each sleep, which is expected.
