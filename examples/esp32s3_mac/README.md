# Factory MAC addresses from eFuse (ESP32-S3, no FreeRTOS)

Reads the factory MAC address burned into the S3's eFuse, and the per-interface
MACs the chip derives from it. Espressif allocates each part a **block of four**
addresses, so a board with several interfaces does not need any of them assigned
by hand.

```
[mac] ESP32-S3 factory MAC addresses (from eFuse):
[mac]   base / wifi-sta : 28:84:85:48:83:10
[mac]   wifi-softap     : 28:84:85:48:83:11
[mac]   bluetooth       : 28:84:85:48:83:12
[mac]   ethernet (W5500): 28:84:85:48:83:13
[mac]   2nd NIC (local) : 2a:84:85:48:83:13
[mac] done.
```

## What to use for what

`base + 3` — the **ethernet** slot — is the natural address to hand a W5500. It
is globally unique and belongs to this board, which beats the hard-coded
`DE:AD:BE:EF:...` that Ethernet examples usually ship with. `esp32s3_multinic`
seeds its W5500s exactly this way.

The `2nd NIC (local)` line is what to do when you have run out: the block is only
four addresses, so a second Ethernet interface takes the ethernet MAC with the
**locally-administered bit** set in the first octet (`28` → `2a`). That is
unique on your LAN without being globally allocated to anyone — which is exactly
what that bit means.

## Build & flash

```sh
./x run esp32s3_mac                  # build + flash + monitor
```

Embedded profile. No wiring — eFuse is on-chip.
