# UART — a bare-metal Ada peripheral driver (ESP32-S3, no FreeRTOS)

Self-test for the reusable **`ESP32S3.UART`** driver (in `libs/esp32s3_hal`) —
no ESP-IDF, no FreeRTOS, on the Ada runtime. It drives UART1 through the
task-safe HAL and proves the data path on silicon **with no external wiring**.

```
[uart] bare-metal UART self-test (internal TX->RX loopback, no wiring)
[uart] sent: 55 aa 00 ff 12 34 56 78 9a bc de f0 0f a5 5a c3
[uart] recv: 55 aa 00 ff 12 34 56 78 9a bc de f0 0f a5 5a c3
[uart] loopback: PASS
[uart] flow: RX throttled to 8 of 64 bytes, all drained: PASS
[uart] invert: TX-only->link-breaks:y  TX+RX->match:y  PASS
[uart] done.
```

## What it checks

**Test 1 — data path.** `ESP32S3.UART.Enable_Loopback` sets the controller's
`CONF0.LOOPBACK` bit, which wires transmit to receive **inside the controller**
— no GPIO pads. The test sets UART1 to 115200 8-N-1, writes a 16-byte buffer,
reads it back, and compares. A `PASS` proves the baud divider (XTAL-sourced),
the 8-N-1 frame format, and the TX/RX FIFO path. Unlike I2C (open-drain,
wired-AND — see `esp32s3_i2c_loopback`), UART is push-pull and unidirectional,
so a fully on-chip loopback is faithful: nothing is faked.

**Test 2 — RTS/CTS hardware flow control.** RTS is matrix-looped to CTS on one
GPIO (RTS drives the pad, CTS reads it back), the RX flow threshold is set to 8,
and 64 bytes are written without reading. The RX FIFO fills to the threshold, at
which point RTS deasserts → CTS deasserts → the CTS-gated transmitter stalls, so
RX caps at 8 (not 64). Draining the FIFO re-asserts RTS/CTS and the rest flows
in. A `PASS` (RX throttled well below 64, then all 64 bytes drained intact)
proves both directions of flow control engage.

**Test 3 — per-line inversion.** Data loops TXD→RXD on one pad, and
`Set_Inversion` is called **after** `Configure_Pins` to flip polarity at run
time. Inverting only TX flips the idle/start-bit polarity the (non-inverted) RX
expects, so the link breaks (garbled / short read); inverting RX as well makes
both ends agree and the bytes round-trip cleanly. That asymmetry proves the
`CONF0` line inverts take effect, are independent per line, and can be changed
after configuration.

## Talking to a real device

For an external link, skip `Enable_Loopback` and pass the pads straight to
`Acquire`, which claims the port and applies the settings in one call:

```ada
Acquire (S, ESP32S3.UART.UART1, Baud => 115_200, Tx => 17, Rx => 18);
```

`Tx`/`Rx` are validated `ESP32S3.GPIO` pins (a reserved/absent pad is a
compile-time error). All four are optional (default `No_Pin`), so a one-way link
routes only the line it uses — e.g. a GPS or other receive-only module:

```ada
Acquire (S, ESP32S3.UART.UART1, Rx => 18);   --  RX only, no TX
```

With hardware flow control, add the `Rts`/`Cts` pins (and optionally a custom
RX threshold); giving `Rts` enables RX flow control, giving `Cts` enables TX
flow control:

```ada
Acquire (S, ESP32S3.UART.UART1, Tx => 17, Rx => 18, Rts => 19, Cts => 20);
```

All configuration runs through the held `Session`: there is no port-based setup
that precedes ownership. To change settings on a port you already hold, use
`Reconfigure` (the same bundle) or the finer `Configure_Pins` / `Set_Baud` / …
on the same held `Session` — changing a live port's settings requires owning it,
so it can never race another task.

## Build & flash

```sh
./x run esp32s3_uart_loopback           # build + flash + monitor
# or:
./x build esp32s3_uart_loopback
./x flash esp32s3_uart_loopback -p /dev/ttyACM0
```

Built as the **embedded** profile (the drivers target it; `build.sh` exports
`ESP32S3_RTS_PROFILE=embedded`). The report prints over the USB-Serial-JTAG
console via the ROM `esp_rom_printf` glue in `glue.c`.
