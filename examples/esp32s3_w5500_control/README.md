# W5500 — the control registers (ESP32-S3, no FreeRTOS)

The app-controlled register knobs the driver exposes — link mode, the mode-register
switches (wake-on-LAN, ping-block, force-ARP), retransmission timing, per-socket
options and the fault diagnostics. This is the "Tuning the chip" material from
the book, as running code.

```
[ctl] W5500 control-register demo
[ctl] VERSIONR = 0x04
[ctl] --- retransmission (write then read back) ---
[ctl] default : 200 ms x8
[ctl] set 500 ms x4 -> read 500 ms x4
[ctl]   -> round-trip OK (register path verified)
[ctl] --- mode switches, link mode, diagnostics ---
[ctl] ping-block on
[ctl] wake-on-LAN on
[ctl] force-ARP on
[ctl] conflict + magic-packet interrupts routed to INTn
[ctl] link pinned to 10BASE-T half (lower PHY current)
[ctl] PHY still powered: yes
[ctl] faults: conflict=no
[ctl] magic packet pending: no
[ctl] --- per-socket options on an opened TCP socket ---
[ctl] Open_TCP (No_Delay) -> SOCK_INIT
[ctl] keepalive/TTL/ToS/MSS/buffers set (chip accepted the writes)
[ctl] done.
```

## What is provable without a cable

Most of these knobs only bite with a live network — you cannot see force-ARP work
without traffic. But **two of them prove the whole register path on this board
with nothing plugged in**, which is what makes this example useful as a bring-up
check:

* **`Set_Retransmission` then `Get_Retransmission`** — a write/read round-trip.
  `round-trip OK (register path verified)` means SPI writes are landing in the
  chip and reads are coming back from the same place. `MISMATCH` means they are
  not, and nothing else in the stack can be trusted.
* **`Open_TCP` reaching `SOCK_INIT`** — a purely local chip operation that needs
  no link. Once the socket is in `SOCK_INIT`, the per-socket options (keepalive,
  TTL, ToS, MSS, buffer sizes) are accepted, which exercises the per-socket
  register bank as well as the common one.

`VERSIONR = 0x04` is the fixed version byte; anything else means SPI is not
reaching the chip at all.

## Hardware

Same wiring as `esp32s3_w5500`: SPI2, `SCLK=IO1`, `MOSI=IO4`, `MISO=IO45`,
`CS=IO39`, `RSTn=IO11`, `INTn=IO3`. No cable needed for the two checks above.

## Build & flash

```sh
./x run esp32s3_w5500_control        # build + flash + monitor
```

Embedded profile.
