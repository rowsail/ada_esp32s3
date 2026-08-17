# esp_flash — an Ada `esptool write_flash`

A **host** tool (**pure native Ada**, built with Alire `gnat_native`) that flashes an
ESP32-S3 over its serial / USB-JTAG **ROM bootloader**, replacing the `write_flash`
half of esptool.  `bare_flash.sh` uses it by default (set `ESP_USE_ESPTOOL=1` to
fall back).  The OS serial interface (open / termios raw mode / `TIOCM*` DTR-RTS /
poll / read / write) is bound directly to libc via `Interfaces.C` — there is no C
source; the stable Linux ABI constants are named in `src/esp_flash.adb`.

Together with the sibling `../elf2image/`, the build/flash path needs **no esptool
and no ESP-IDF** — just the Alire toolchain (`gnat_xtensa` + `gnat_native` +
`gprbuild`) and the committed vendored blobs.

## What it does (ROM bootloader, no stub, no compression)

1. **Reset into download mode** — the USB-JTAG DTR/RTS sequence (`src` `Reset_To_Download`).
2. **SYNC** — the `0x07 0x07 0x12 0x20` + 32×`0x55` handshake until the ROM replies.
3. **SPI attach** + **SPI set-params** (2 MB geometry).
4. Per file: **flash_begin** (erase) then **flash_data** blocks of `0x400` (the last
   padded with `0xFF`), each with the ROM XOR checksum (seed `0xEF`).
5. **flash_end**, then a **hard reset** to run (skip with `--no-reset`).

All of it is the standard esptool/ROM protocol: SLIP framing (`0xC0` delimiters,
`0xDB` escaping) around `<dir,op,len,chk>` command packets over the serial port.

## Usage

```sh
gprbuild -P esp_flash.gpr                       # Alire gnat_native + gprbuild
./esp_flash [-p] <port> [--flash-size SZ] [--no-reset] \
            <offset> <file> [<offset> <file> ...]
# e.g.
./esp_flash -p /dev/ttyACM0 --flash-size 4MB 0x0 bootloader.bin \
            0x8000 partition-table.bin 0x10000 app.bin
```

Options:
- `-p <port>` — serial port (or give it positionally as the first non-flag arg).
- `--flash-size SZ` — flash size for `SPI_SET_PARAMS` (default `2MB`); accepts
  `2MB`/`8MB`/`0x400000`/`4194304` (K/M/G suffixes).
- `--no-reset` — leave the chip in the bootloader (for a capture workflow that resets
  itself, like the ACATS sweep) instead of hard-resetting to run.

`<offset>` accepts hex (`0x10000`) or decimal. Flash **mode/frequency** stay fixed at
`dio`/`80m` (the chip is ESP32-S3); change the constants in `src/esp_flash.adb` if
needed. (There is no PSRAM option — `write_flash` only writes flash; PSRAM is brought
up by the 2nd-stage bootloader at runtime, not the flasher.)

## Scope / notes

- Verified on HW: flashes our own 2nd-stage bootloader + the vendored partition
  table + an app and the
  board boots and runs (ACATS C41306 PASSED, 0 Guru); ~3 s for ~225 KB (ROM speed).
- ROM commands only — no RAM stub (so no on-the-fly compression; fine at this scale).
- 100% Ada — libc's serial syscalls (open/termios/ioctl/poll/read/write) are bound
  directly via `Interfaces.C`, so there's no C source. (`GNAT.Serial_Communications`
  would cover the I/O but lacks the DTR/RTS modem-line control the reset needs, so we
  bind `ioctl(TIOCMBIS/TIOCMBIC)` ourselves.)
