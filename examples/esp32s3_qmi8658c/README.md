# QMI8658C IMU — a bare-metal Ada device driver (ESP32-S3, no FreeRTOS)

Demo for the reusable **`ESP32S3.QMI8658C`** 6-axis IMU driver (in
`libs/esp32s3_hal`) — no ESP-IDF, no FreeRTOS, on the Ada runtime. It layers the
QST QMI8658C's register protocol over the task-safe **`ESP32S3.I2C`** master,
configures the accelerometer + gyroscope, and streams readings.

```
[imu] QMI8658C 6-axis IMU driver demo (SDA=IO8  SCL=IO7)
[imu] who_am_i : 0x05 @ 0x6b  (QMI8658 present)
[imu] reset     : OK
[imu] configure : OK
[imu] temp[C]=28.98
[imu] a=accel[mg]  |a|=total[m/s2]  g=gyro[mdps]
[imu] a=   -49   -78   928 |a|=9.14 g=  -8921   1484   -437
[imu] a=   -55   -82   922 |a|=9.09 g=  -9078   1609   -453
   ... one line per 250 ms ...
[imu] done.
```

Sitting flat, Z ≈ +925 mg = gravity, and the total magnitude **|a| ≈ 9.1 m/s²**
— a good sanity check against the expected **9.81 m/s² (1 g)**. The ~7% shortfall
is the *uncalibrated* part reading ~0.93 g (within the QMI8658's ±6% initial
sensitivity tolerance + offset; QST expects a board-level calibration routine for
full accuracy). The steady gyro offset is likewise the uncalibrated bias, within
the ±10 dps spec. The magnitude is computed in the example with an integer
`sqrt` (no float library), so it confirms the driver's scaling without pulling in
`Ada.Numerics`.

## Wiring

| QMI8658C | ESP32-S3 | notes |
|---|---|---|
| SDA | **IO8** | I2C0 data — internal pull-up enabled for bring-up |
| SCL | **IO7** | I2C0 clock — internal pull-up enabled for bring-up |
| INT1 / INT2 | *not wired* | the demo polls — see `Imu_Int` below |
| VDDIO / VDD | 3V3 | |
| GND | GND | |

The 7-bit address is set by SA0/SDO: **0x6B** (SA0 = GND) or **0x6A** (SA0 =
VDDIO, the floating/pull-up default). The demo probes both. Add real bus
pull-ups (e.g. 4.7 kΩ) for anything beyond a quick bench bring-up.

## What it does

| step | driver call | proves |
|---|---|---|
| `probe` | `Read_Who_Am_I` | the chip answers `0x05`; tries both SA0 addresses |
| `reset` | `Reset` | soft reset to a known register state (then waits ~15 ms) |
| `configure` | `Configure` | sets accel / gyro full scale + output rate, enables register auto-increment + little-endian, and enables both sensors (6DOF) |
| `sample` | `Read_Accelerometer` / `Read_Gyroscope` / `Read_Temperature` | streams raw counts, scaled to milli-g / milli-dps / °C using the configured `Accel_LSB_Per_G` / `Gyro_LSB_Per_DPS` sensitivity |

The driver hard-codes no pins: the wiring + address are stated in `src/main.adb`
(`Imu_Sda`, `Imu_Scl`, `Imu_Int`, and the probed SA0 address) and handed to
`Setup`, which records them in the `Device`. Each operation then opens a
short-lived `ESP32S3.I2C` `Session` that auto-releases the host on scope exit
(finalization), so transactions serialise and a fault can't leak the bus.

This board does not wire the QMI8658C INT line, so `Imu_Int` is
`ESP32S3.GPIO.No_Pin`: the demo polls, and `ESP32S3.QMI8658C.Interrupts.Attach
(Dev, …)` is a no-op. Point `Imu_Int` at the GPIO an INT line (INT1/INT2) is
wired to arm the data-ready interrupt instead (rising edge, push-pull
active-high — adjust the `.Interrupts` child if you change the on-chip polarity);
the ISR latches an `Atomic` flag (`src/imu_irq.adb`) and the main task does the
I2C work.

## Build / flash / run

```sh
./x build qmi8658c            # -> app.bin (embedded profile)
./x flash qmi8658c -p /dev/ttyACM0
./x run   qmi8658c -p /dev/ttyACM0    # build + flash + serial monitor (115200)
```

Console output goes through the ROM USB-Serial-JTAG `printf`; the Ada driver does
all the I2C and register work. If you see `no QMI8658C found`, check power and
the SDA/SCL wiring.

## Notes

- The ROM `printf` to the USB-serial-JTAG has quirks the glue (`main/glue.c`)
  works around: no `+` flag, a ~6-conversion cap, and it drops output past the
  64-byte FIFO in one call. The per-sample line is therefore built into a buffer
  and emitted with a single `%s`, kept under 64 bytes (hence the compact labels
  and the one-time legend).
- `Configure` runs the device little-endian with register auto-increment
  (CTRL1), which the burst reads of the 6-byte accel / gyro blocks rely on — so
  it must precede the `Read_*` calls.
- This driver uses the controlled I2C `Session` (finalization), so like the other
  Session drivers it targets the **embedded / full** profiles, not light-tasking.
