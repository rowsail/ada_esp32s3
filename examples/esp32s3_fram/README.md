# I²C FRAM — the MB85RC256V driver family (ESP32-S3, no FreeRTOS)

The reusable **`ESP32S3.FRAM_I2C`** driver family against an I²C FRAM — here a
Fujitsu **MB85RC256V**, 256 Kbit / 32 KiB.

```
[fram] I2C FRAM driver demo -- Kbit_256 (SDA=IO41 SCL=IO40)
[fram] capacity: 32768 bytes
[fram] address: 0x50
[fram] device id: manufacturer 0x00A
[fram]   -> Fujitsu
[fram] vendor: Fujitsu
[fram] boot count: 7
[fram] 100-byte write/read: PASS
[fram] done.
```

With no FRAM fitted the demo reports **no ACK** and stops — the driver code is
still exercised at compile time.

## What FRAM does that an EEPROM does not

The demo leans on the two real differences from the 24C EEPROM family:

**`Read_Device_ID`** — FRAM **self-reports** its manufacturer, density and
product code over the reserved-slave sequence. The 24C parts have nothing like
it: you must be told what is fitted. The demo decodes the manufacturer to a name
(`-> Fujitsu`, `-> Cypress/Infineon`), and prints `device id: not reported` for a
part that does not answer the sequence.

**No page boundary and no program cycle.** An EEPROM write must be split at page
boundaries and then ACK-polled until the internal program cycle finishes. FRAM
has neither — it is genuinely random-access non-volatile memory — so the
100-byte pattern goes down in **one transaction with nothing to poll**. That is
also why FRAM survives essentially unlimited writes, which is what makes the boot
counter below reasonable.

**The boot counter** is the same non-volatile counter the EEPROM demo uses:
read at start-up, incremented, written back. It should climb by one per reset —
which is the simplest possible end-to-end proof that a write really persisted
across a power cycle.

## Hardware

One **MB85RC256V** (or any part in the catalogue — change the `with` and the
rename) on I²C0:

| signal | pin |
|---|---|
| SDA | IO41 |
| SCL | IO40 |
| WP | GND (to allow writes) |
| A0/A1/A2 | GND → address `0x50` |

## Build & flash

```sh
./x run esp32s3_fram                 # build + flash + monitor
```

Embedded profile — the I²C `Session` is a controlled type.

## See also

`esp32s3_m24c64` is the 24C EEPROM equivalent, page splitting and ACK polling
included.
