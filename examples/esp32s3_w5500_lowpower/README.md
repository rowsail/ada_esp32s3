# W5500 — PHY power-down (ESP32-S3, no FreeRTOS)

The W5500's low-power mode. `ESP32S3.W5500.Set_Power (Dev, Power_Down)` turns the
Ethernet **PHY** off — the 100BASE-TX line driver, which is the bulk of the chip's
current, so this is the power saving that actually matters. The link drops and no
frames move, but the registers and the 32 KiB socket buffers **stay intact**.
`Set_Power (Dev, Normal)` brings the PHY back and the link re-negotiates.

```
[lp] W5500 PHY power-down demo
[lp] VERSIONR = 0x04
[lp] --- round 1 ---
[lp]   -> PHY off, link down as expected
[lp]   -> PHY back, link re-negotiated
[lp] --- round 2 ---
[lp]   -> PHY off, link down as expected
[lp]   -> PHY back, link re-negotiated
[lp] done -- registers/buffers survived every cycle; only the wire slept.
```

## What the link proves

Current draw needs a meter. The **link state** does not, and it is the
software-visible signal that the PHY really slept: it reads **Up** while the PHY
runs, **Down** while it is powered down, and **Up again** after wake, with
`Power` reading back the mode each time. You can confirm it physically too — the
switch port LED and the W5500's own link LED go dark and come back.

Two failure lines are worth knowing:

* `-> unexpected: PHY did not power down` — the power-down did not take.
* `-> link not back yet (slow switch, or no cable)` — the wake worked but
  auto-negotiation had not finished when the check ran; some switches are slow.

Without a cable the run prints
`[lp] (no link -- plug into a live switch to see the transitions)`, and there is
nothing to observe: the whole demonstration is the link transition.

## Hardware

Same wiring as `esp32s3_w5500` — SPI2, `SCLK=IO1`, `MOSI=IO4`, `MISO=IO45`,
`SCSn=IO39`, `RSTn=IO11`, `INTn=IO3`. **Plug the W5500 into a live switch or
router** so the link can negotiate.

## Build & flash

```sh
./x run esp32s3_w5500_lowpower       # build + flash + monitor
```

Embedded profile; see `build.sh`.
