# ESP serial-bootloader host test harness (native x86)

Runs the **pure-Ada ESP32 serial-bootloader client** (`ESP32S3.Esp_Loader`, from
`libs/esp32s3_hal/src/esp_loader`) on the development host against a **simulated
ESP32 ROM**, and checks both what it sends and how it reacts to what comes back.
No hardware.

The protocol is transport-agnostic, so the *same* sources the firmware compiles
run here — only the `Link`'s callbacks differ. On target they are a UART and two
GPIOs (`ESP32S3.Esp_Loader.Serial_Link`); here they are the process's own file
descriptors:

| | |
|---|---|
| `stdout` | bytes to the target — `Send` |
| `stdin` | bytes from the target — `Receive` (with `poll` for the timeout) |
| `stderr` | control-line transitions, as text — `Assert_Reset` / `Assert_Boot` / `Set_Baud` |

Putting the control lines on their own stream is the point: it lets the
simulator check that the target was **actually reset into its download loader**
before it answers a SYNC — the part a plain loopback would silently skip.

## Run

```sh
./run.sh
```

It auto-discovers an Alire native GNAT + gprbuild, builds, and prints one line
per check. Requirements: a native GNAT toolchain and `python3`.

## What it proves

`fake_rom.py` is written from the protocol description rather than from the Ada
source, and it is strict about everything it is sent. It faults on a bad frame
direction, a length field that disagrees with the payload, a wrong FLASH_DATA
block checksum, a skipped or repeated sequence number, a block size that is not
1 KB, a final block not padded with `0xFF`, a SYNC whose payload is not the
fixed pattern, a command issued before its prerequisite (`FLASH_BEGIN` before
`SPI_SET_PARAMS`), and any command at all while the target is not in download
mode.

| Check | What it covers |
|---|---|
| a complete flashing run | connect → configure → stream 200 KB → finish, and the reassembled image compared byte-for-byte with the source |
| individual commands | `READ_REG` (chip magic), `CHANGE_BAUDRATE`, `SPI_FLASH_MD5` |
| refused command | an error status must surface as `Target_Refused`, not success |
| silent target | must give up in bounded time (~8 s), not hang |
| length mismatches | fewer or more bytes than `Begin_Image` declared must both be `Wrong_Length` |
| the harness can fail | a target whose IO0 never goes low must get nowhere — a pass here would mean the simulator is asleep |

The 200 KB image is deliberately not a multiple of the 1 KB block, and the test
feeds it in 3000-byte chunks, so every block boundary lands mid-chunk and the
final block is partial.

## What it does NOT prove

The real ROM's quirks. This is a simulator built from the protocol as
documented; a genuine ESP32 on the other end of a real UART is still the only
thing that proves the timing of the reset sequence, the ROM's tolerance of our
frame pacing, and the erase durations behind `FLASH_BEGIN`. Until then, treat
`ESP32S3.Esp_Loader` as host-verified only.
