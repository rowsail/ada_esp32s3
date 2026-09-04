# SPI master — full-duplex DMA loopback self-test, no wiring (ESP32-S3, no FreeRTOS)

A hardware self-test for the reusable **`ESP32S3.SPI`** master driver, with **no
external wiring at all**.

Unlike I2C, the SPI signal matrix *can* loop a controller's MOSI back into its
own MISO through a single pad (`Enable_Loopback`). That makes it possible to
verify the **full-duplex DMA path and the read direction on real silicon** using
nothing but the master.

```
[spi] bare-metal SPI master full-duplex DMA loopback self-test (no wiring)
[spi] test0 (32-byte loopback): PASS
[spi] test1 (RAII auto-release): PASS
[spi] done.
```

## What each test proves

**`test0`** loops a 32-byte pseudo-random pattern through one pad and compares
the MISO-captured Rx to the Tx, byte for byte. `PASS` (Rx = Tx) proves the whole
chain: START, clocking, capture, the GDMA in *and* out descriptors, and the
bounded transfer-complete wait.

A random pattern rather than a counting one matters here — a stuck bus that
returns the last byte, or a descriptor that reads the Tx buffer instead of the Rx
one, both survive a pattern with structure in it.

**`test1`** is the controlled (RAII) `Session`. It acquires the host, **raises an
exception**, and then re-acquires. `PASS` means the re-acquire did not deadlock —
i.e. `Finalize` released the host on the way out of the scope, even though the
scope was left by propagation rather than normally. That is the property the
type exists for: no `Release` call can be forgotten, and no error path can leak
the bus.

## Build & flash

```sh
./x run esp32s3_spi_loopback         # build + flash + monitor
```

Needs the **embedded** profile (the `Session` is a controlled type); `build.sh`
sets `ESP32S3_RTS_PROFILE=embedded`.

**No hardware**: the master's MOSI is fed back into its own MISO on a single GPIO
pad through the signal matrix.

## See also

`esp32s3_i2c_loopback` is the equivalent for I2C; `esp32s3_gdma_copy` isolates
the DMA engine underneath this one.
