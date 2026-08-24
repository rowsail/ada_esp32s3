# ADC — a bare-metal Ada peripheral driver (ESP32-S3, no FreeRTOS)

Self-test for the reusable **`ESP32S3.ADC`** SAR analog-to-digital driver (in
`libs/esp32s3_hal`) — no ESP-IDF, no FreeRTOS, on the Ada runtime. It reads an
analog voltage back **with no external wiring**.

```
[adc] bare-metal SAR ADC one-shot self-test (drive+sense one pad, no wiring)
[adc] ADC1 ch0: drive-high=4095  drive-low=0  PASS
[adc]   cal_code=2241  all_valid=1
```

## What it checks

ADC1 channel 0 is wired to GPIO1. The test drives that pad **high** with the GPIO
output driver and reads the ADC (expect near full scale, ~4095 at 12 dB
attenuation), then drives it **low** and reads again (~0). The pad is both driven
and ADC-sensed, so no wiring is needed. The diagnostic line shows the
self-calibrated initial code and that the conversion completed.

The interesting part is what `Claim` does under the hood. The S3 SAR returns 0
from every conversion until its analog front-end is brought up:

- power the SAR core (digital `XPD_SAR_FORCE` + the RTC-side `xpd`),
- gate on the **SENS-domain `SARADC_CLK_EN`** conversion clock (the piece that's
  easy to miss — without it the conversion never completes),
- open the internal **REGI2C** bus to the SAR analog block and, over it (via the
  boot ROM `rom_i2c_writeReg_Mask`, the same path the temperature sensor uses),
  set the reference and run a **self-calibration** that binary-searches the SAR's
  initial code with the input grounded.

The driver does all of this once, in the protected pool, when the first `Reader`
is claimed.

## Using the driver

```ada
with ESP32S3.ADC; use ESP32S3.ADC;

declare
   R     : Reader;
   V     : Raw_Value;
   Valid : Boolean;
begin
   Claim (R, ADC1);
   Read (R, Ch => 0, Value => V, Valid => Valid, Atten => Db_12);
   --  V is 0 .. 4095, and MEANINGLESS unless Valid.
end;                                             -- unit released
```

`Read` is a procedure, and `Valid` is not decoration.  The conversion-done
poll has a deadline; if it expires the SAR's data register still holds
whatever it last latched, so there is no value that can safely mean "no
reading".  `Valid` is likewise `False` for a handle that was never claimed,
which used to return a silent `0` — indistinguishable from a genuine
zero-current reading.

Two units (ADC1 ch0..9 = GPIO1..10; ADC2 ch0..9 = GPIO11..20), 12-bit results,
attenuation `Db_0` (~1.1 V) .. `Db_12` (~3.3 V full scale). Because the `Reader`
uses finalization, the driver is **embedded/full only** (light-tasking forbids
`No_Finalization`). The raw code is uncalibrated for absolute voltage — pair it
with the eFuse calibration curve if you need volts.

## Build & flash

```sh
./x run esp32s3_adc_read           # build + flash + monitor
```

Built as the **embedded** profile. The report prints over the USB-Serial-JTAG
console via the ROM `esp_rom_printf` glue in `glue.c`.
