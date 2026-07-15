# ESP32-S3 Wi-Fi in Ada — bring-up plan

Goal: a pure-Ada library that drives the ESP32-S3 Wi-Fi radio and presents it to
the existing chip-neutral network stack as a `Net_Device` (a NIC), reusing DHCP,
DNS, TLS and sockets unchanged. First milestone: **scan for access points.**

## Why the Espressif blob (not a from-scratch driver)

The ESP32-S3 Wi-Fi MAC and PHY are **undocumented** — there is no register-level
programming interface and no usable clean-room driver. The radio is driven only
through Espressif's closed libraries. "Directly using the hardware" is therefore
not an option; every open project still links these blobs:

| Blob (esp32s3) | Role |
|---|---|
| `libnet80211.a` | 802.11 MAC / management (assoc, auth, scan) |
| `libpp.a`       | packet processor (the WMAC data path, ISR) |
| `libphy.a`      | RF / baseband PHY + calibration |
| `libcore.a`     | Wi-Fi core / OS glue entry points |
| `libmesh.a`     | (only if ESP-MESH; not needed) |
| `libcoexist.a`  | Wi-Fi/BLE radio-time arbitration (needed once BLE is added) |

These are taken from an ESP-IDF build for `esp32s3` and added to the **bare-boot
vendor link** (alongside the existing `libxt_hal.a` / `libgcc.a`); the Ada app
stays a relocatable object. **The blob version must be pinned** — the OS-adapter
struct layout below is version-specific and a mismatch faults on init.

## The real work: satisfying the blob's dependencies in Ada

The blob is standalone in name only. It calls out through an **OS-adapter table**
(`wifi_osi_funcs_t`, ~40 function pointers) and expects services IDF normally
supplies. Every one of these is reimplemented in Ada (library-level,
`Convention => C`, closure-free — no trampolines) against the **embedded (Jorvik)
runtime**:

- **Tasking** — the Wi-Fi/`pp` tasks run at fixed priorities and must be serviced
  promptly. Map task create/delete/yield/delay and **semaphores, mutexes, queues,
  event groups** (with ISR-safe variants) onto Jorvik tasks + protected objects +
  suspension objects.
- **PHY / RF** — `phy_init` with calibration data, `esp_phy_enable`, the 80 MHz
  APB clock request, RF/clock bring-up.
- **Calibration storage** — the PHY cal blob lives in NVS in IDF; provide an
  NVS-like shim (or full recalibration each boot to start).
- **Timers / events / RNG / time** — `esp_timer`, an event path (or status poll),
  hardware RNG, `esp_timer_get_time`, and DMA-capable heap alloc.
- **Interrupts** — hook the WMAC interrupt (interrupt matrix) and dispatch to the
  blob's ISR.

This glue — not the `esp_wifi_scan_start` call — is the project, and it is the
hardest bring-up on the chip (far past the W5500/BG95 external chips).

## The clean seam to the existing stack

The blob does the 802.11 and exchanges **plain 802.3 (Ethernet) frames**:
`esp_wifi_internal_reg_rxcb` delivers RX frames, `esp_wifi_internal_tx` sends. So
Wi-Fi slots straight into the chip-neutral `Net_Device` interface — it becomes
"just another NIC," and DHCP/DNS/TLS/sockets come for free.

## Milestones (scan first)

- **M0 — init.** Clocks/PHY/RF-cal up; OS-adapter implemented; `esp_wifi_init`
  returns `ESP_OK`. *(~80 % of the risk lives here.)*
- **M1 — scan.** `esp_wifi_set_mode(STA)` + `esp_wifi_start` + passive
  `esp_wifi_scan_start`; read `wifi_ap_record_t[]`; surface as `AP_Record`s and
  print SSID / BSSID / channel / RSSI / auth. **← immediate target**
- **M2 — associate.** STA connect (open, then WPA2-PSK); link up.
- **M3 — NIC.** Register RX callback + `internal_tx`; wrap as a `Net_Device`;
  DHCP over the existing stack.
- **M4 — BLE + coexistence.** Separate controller blob; later.

## Pinned to ESP-IDF v5.4.4  (local: `~/esp/esp-idf`)

Blobs for the bare-boot vendor link:
- `components/esp_wifi/lib/esp32s3/{libnet80211,libpp,libcore}.a` (+ `libcoexist` for BLE)
- `components/esp_phy/lib/esp32s3/libphy.a`

ABI facts (from `esp_private/wifi_os_adapter.h`, `esp_wifi_types_generic.h`):
- **OS adapter**: version **8**, magic **0xDEADBEAF**, **118 slots** for esp32s3
  (excludes `_phy_common_clock_*` and the C6/C5 regdma fields, includes
  `_slowclk_cal_get`). Bound exactly in `ESP32S3.WiFi.OS_Adapter` (slot count
  verified against the header).

**Target-ABI validated** with the esp32s3 GNAT + dynconfig (`test/cross_check.sh`
-- a native host check can't, host pointers are 8 B): `OSI_FUNCS'Size = 480 B`
(120 words = 118 slots + version + magic) and `wifi_ap_record_t = 92 B`, both
exact for the chip.
- **`wifi_ap_record_t`** has a version-specific tail (`country`, `he_ap`,
  `bandwidth`, `vht_ch_freq1/2`). Bind its size by a C probe and read only the
  leading fields (bssid, ssid, primary channel, rssi, authmode) into `AP_Record`.
- **`wifi_auth_mode_t`**: OPEN=0, WEP, WPA_PSK, WPA2_PSK, WPA_WPA2_PSK,
  ENTERPRISE(=WPA2_ENT), WPA3_PSK, WPA2_WPA3_PSK, WAPI_PSK, OWE, ...

## wifi_init_config_t (resolved from the wifi/scan example's sdkconfig)

`sdkconfig` comes from the IDF build system, not esptool: `. ~/esp/esp-idf/export.sh;
cp -r $IDF/examples/wifi/scan /tmp/wscan; cd /tmp/wscan; idf.py set-target esp32s3`
generates `build/config/sdkconfig.h`.  Expanding `WIFI_INIT_CONFIG_DEFAULT()`
with the real flags gives the exact defaults for esp32s3 (v5.4.4):

**Layout — sizeof = 152 B:** `osi_funcs`@0 (ptr) · `wpa_crypto_funcs`@4 (44-byte
struct-by-value, set from extern `g_wifi_default_wpa_crypto_funcs`) · 18×int32
@48 · `feature_caps` (uint64)@120 · 4×int32@128 · `magic`@144.

**Values:** static_rx_buf_num=10, dynamic_rx_buf_num=32, tx_buf_type=1,
static_tx_buf_num=0, dynamic_tx_buf_num=32, rx_mgmt_buf_type=0, rx_mgmt_buf_num=5,
cache_tx_buf_num=0, csi_enable=0, ampdu_rx_enable=1, ampdu_tx_enable=1,
amsdu_tx_enable=0, nvs_enable=1, nano_enable=0, rx_ba_win=6, wifi_task_core_id=0,
beacon_max_len=752, mgmt_sbuf_num=32, feature_caps=0xA1 ((1<<0)|(1<<5)|(1<<7)),
sta_disconnected_pm=1, espnow_max_encrypt_num=7, tx_hetb_queue_num=1,
dump_hesigb_enable=0, magic=0x1F2F3F4F.  (`nvs_enable=1` -> need the NVS shim for
PHY cal; the `wifi/scan` example's `main/scan.c` is the reference call sequence.)

## Risks / open needs

1. ~~Blobs + IDF version~~ — **resolved: v5.4.4 pinned** (above).
2. PHY calibration data source (NVS shim vs recalibrate-each-boot).
3. Interrupt priorities / Jorvik ceiling protocol vs the blob's expectations.
4. DMA-capable heap sizing for Wi-Fi buffers.
5. Hardware-only: none of this can be validated on the host.
