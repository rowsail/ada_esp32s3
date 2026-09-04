# ESP32-S3 peripheral drivers (shared, reusable)

A common, reusable driver library (HAL) for the ESP32-S3, shared across the
examples and any project on the bare-metal Ada runtime. Two layers:

```
svd/   GENERATED register layer  -> ESP32S3_Registers.*   (svd2ada; do not hand-edit)
src/   hand-written drivers      -> ESP32S3.*             (the HAL API you use)
```

`src/` is split into subdirectories, and the split is **load-bearing**: it is how
a runtime profile decides which drivers it can see. `light-tasking` compiles
`src/` alone; `embedded` and `full` compile `src/**`.

| directory | what belongs there |
|---|---|
| `src/` | lock-free, `Preelaborate`, no finalization / secondary stack: GPIO, RNG, Temperature, SHA/AES/RSA/MD5, RTC, SDMMC, X509, strings/endian helpers |
| `src/peripherals/` | on-chip drivers with an RAII `Session`/`Channel` handle: SPI, I2C, UART, GDMA, I2S, LEDC, RMT, PCNT, SDM, MCPWM, TWAI, Timer, LCD, ADC |
| `src/devices/` | off-chip parts reached over those: ST7789, GT911, ES8311, W25Q, SD_SPI, TLV2556, TX1812, SHT41, QMI8658C, PCF85063A, TCA9555, CH422G, HC595, GPS |
| `src/net/` | `Net_Devices` + the W5500 NIC, the `GNAT.Sockets` facade, and everything on it: DNS, NTP, FTP client/server, Modbus |
| `src/ext4/` `src/fat16/` | the pure-Ada filesystems and the block-device layer |
| `src/eeprom/` `src/fram/` | the 24Cxx / FRAM device families |
| `src/esp_loader/` `src/text_io/` | the ESP serial-bootloader client; `ESP32S3.Text_IO` |

**Putting a new file in the wrong directory is caught, not silent:** `./x test
lib` builds this library on all three profiles, and CI runs it. (This replaced a
~130-entry `Excluded_Source_Files` blacklist in the `.gpr`, under which a new
driver was *in* the light-tasking build until somebody remembered to exclude it
— and which had drifted far enough that the library no longer built under its
own default profile.)

- **`svd/`** — the full set of ESP32-S3 register-map packages (`ESP32S3_Registers`,
  `ESP32S3_Registers.GPIO`, `ESP32S3_Registers.IO_MUX`, … all ~46 peripherals),
  generated from a CMSIS-SVD file by `svd2ada` and committed. Typed bit-field
  records with `Volatile_Full_Access`. Regenerate with `./regenerate.sh` (manual;
  not a build step). Root is `ESP32S3_Registers`, **not** `Interfaces.ESP32S3` —
  GNAT forbids user-defined descendants of `Interfaces` outside the runtime.
- **`src/`** — hand-written, ZFP-safe driver packages (`Preelaborate`, no
  heap / secondary stack / finalization) that wrap the register layer in a clean
  API. Today: **`ESP32S3.GPIO`** (full pin abstraction), **`ESP32S3.RNG`**
  (hardware random numbers — `Read` a 32-bit word or `Fill` a byte array; see its
  spec for the entropy caveat), **`ESP32S3.Temperature`** (on-chip die
  temperature — `Initialize` then `Read_Celsius` / `Read_Centi_Celsius`), and
  **`ESP32S3.GDMA`** (general DMA — `Claim` a channel, `Copy` memory-to-memory,
  or `Start`/`Wait` a peripheral transfer), **`ESP32S3.SPI`** (SPI2/SPI3
  full-duplex master over GDMA), **`ESP32S3.SD_SPI`** (SD/SDHC memory card over
  that SPI master) and **`ESP32S3.SDMMC`** (the native SD host / SDHOST
  controller), **`ESP32S3.I2C`** (I2C0/I2C1 master), and
  **`ESP32S3.UART`** (UART0/1/2, optional RTS/CTS flow control),
  **`ESP32S3.MCPWM`** (motor-control PWM output), **`ESP32S3.I2S`** (I2S0/I2S1
  digital-audio master over GDMA), **`ESP32S3.LEDC`** (8-channel LED/PWM
  generator), **`ESP32S3.RMT`** (remote-control pulse TX/RX — IR, WS2812), and
  **`ESP32S3.PCNT`** (4-unit pulse / edge counter), **`ESP32S3.SDM`** (8-channel
  sigma-delta density output), **`ESP32S3.TWAI`** (CAN 2.0 controller), and
  **`ESP32S3.Timer`** (TIMG0/TIMG1 general-purpose timers), **`ESP32S3.LCD`**
  (LCD_CAM 8-bit i80 parallel master over GDMA), **`ESP32S3.ADC`** (SAR ADC
  one-shot reads), **`ESP32S3.RTC`** (low-power: retained RTC memory, deep sleep,
  timer/GPIO wake), **`ESP32S3.RTC_IO`** (RTC-domain pad hold + pulls), and
  **`ESP32S3.Touch`** (capacitive touch sensing), and **`ESP32S3.SHA`** /
  **`ESP32S3.AES`** (hardware crypto) — all **task-safe**; see below.
  Future: the LCD_CAM camera-receive half, `ESP32S3.I2S` PDM, … (the registers for
  those already exist in `svd/`).

  > **Task-safety.** Every driver is safe for concurrent use from multiple
  > tasks (requires a tasking runtime — Jorvik or richer):
  > - **`SPI`** — raw driver hidden in the private child `ESP32S3.SPI.Engine`
  >   (the app cannot `with` it); the public package mediates each host with a
  >   protected object + a limited `Session` handle.
  > - **`GDMA`** — `Claim`/`Release` go through a protected channel allocator;
  >   transfers are safe by ownership (you hold the channel).
  > - **`MCPWM`** — a generator channel and a capture channel are `Claim`ed as
  >   limited, controlled handles through a protected pool; per-channel ops
  >   (including `Set_Duty`) are safe by ownership (you hold the channel).
  > - **`I2S`** — raw driver hidden in the private child `ESP32S3.I2S.Engine`;
  >   the public package guards each port with a protected object + a limited
  >   `Session` handle (same shape as SPI), DMA transfer outside the lock.
  > - **`LEDC`** — the eight channels are `Claim`ed as limited, controlled
  >   handles through a protected pool; per-channel ops (incl. `Set_Duty`) are
  >   safe by ownership (you hold the channel).
  > - **`RMT`** — the four TX and four RX channels are `Claim`ed as limited,
  >   controlled handles (distinct `TX_Channel`/`RX_Channel` types) through a
  >   protected pool; transmit/receive are safe by ownership.
  > - **`PCNT`** — the four counter units are `Claim`ed as limited, controlled
  >   `Unit` handles through a protected pool; counting is safe by ownership.
  > - **`SDM`** — the eight sigma-delta channels are `Claim`ed as limited,
  >   controlled handles through a protected pool; `Set_Density` is safe by
  >   ownership (you hold the channel).
  > - **`TWAI`** — the single CAN controller is guarded by a protected object +
  >   a limited `Session` handle (like SPI); send/receive run outside the lock.
  > - **`Timer`** — the two general-purpose timers are `Claim`ed as limited,
  >   controlled handles through a protected pool; each is owned exclusively.
  > - **`LCD`** — the single LCD_CAM controller is guarded by a protected object +
  >   a limited `Session` handle (like SPI); the DMA transmit runs outside the lock.
  > - **`ADC`** — the two SAR units are `Claim`ed as limited, controlled `Reader`
  >   handles through a protected pool (which also does the one-time analog
  >   bring-up); reads are safe by ownership.
  > - **`Temperature`** — a protected `Sensor` serialises the read handshake.
  > - **`GPIO`** — `Set`/`Clear`/`Write`/`Read` are hardware-atomic (lock-free);
  >   `Configure`/`Toggle` are serialised by a protected `Lock`.
  > - **`RNG`** — inherently safe (atomic register reads, no shared state); the
  >   only driver that stays `Preelaborate`/ZFP-safe as well.
  > - **`SD_SPI`** — each card operation takes the underlying SPI host's
  >   `Session` for the whole command/response/data transaction, so concurrent
  >   callers serialise on that host's protected guard.
  > - **`SDMMC`** — every operation runs inside one library-level protected
  >   object, so the single SDHOST controller is serialised across both slots.
  >
  > Each of the above was HW-validated under multi-task contention on the Jorvik
  > runtime — **except the two SD-card drivers**, which use these same patterns
  > but have not yet been validated on real hardware (see *Verification status*).

## Verification status

Every driver below the line is exercised by an example that runs a self-test on
real silicon; "confirmed on silicon" means that self-test passed on an ESP32-S3.
The two SD-card drivers are the current exception — they cannot be self-tested
without a physical card, so they are compile-verified and smoke-run only, with the
on-card test left to the user.

**✅ Confirmed working on silicon** (self-test passes on hardware):

| Driver | How it was verified (example) |
|--------|-------------------------------|
| `GPIO` (+ `GPIO.Interrupts`) | pin drive/read; level-3 device interrupts (`esp32s3_gpio0_blink`) |
| `RNG` | non-constant random words |
| `Temperature` | on-die temperature read |
| `GDMA` | mem-to-mem copy (`esp32s3_gdma_copy`) |
| `SPI` | full-duplex loopback, 2-task contention |
| `I2C` | master self-test (`esp32s3_i2c_loopback`) |
| `UART` | internal TX→RX loopback (`esp32s3_uart_loopback`) |
| `MCPWM` | GPIO-sampled PWM + all 5 sub-features (`esp32s3_mcpwm_pwm`) |
| `I2S` | full-duplex DMA loopback (`esp32s3_i2s_loopback`) |
| `LEDC` | GPIO-sampled PWM (`esp32s3_ledc_pwm`) |
| `RMT` | TX→RX single-pad loopback (`esp32s3_rmt_loopback`) |
| `PCNT` | 100 software edges counted (`esp32s3_pcnt_count`) |
| `SDM` | GPIO-sampled density (`esp32s3_sdm_output`) |
| `TWAI` | CAN self-test loopback (`esp32s3_twai_loopback`) |
| `Timer` | count vs wall clock + alarm (`esp32s3_timer_count`) |
| `LCD` | DMA + timed i80 pclk (`esp32s3_lcd_i8080`) |
| `ADC` | drive pad → 4095/0 (`esp32s3_adc_read`) |
| `RTC` | deep sleep + retained mem + wake (`esp32s3_rtc_sleep`) |
| `RTC_IO` | RTC-domain pad hold (`esp32s3_rtcio_hold`) |
| `Touch` | per-pad capacitance + `Touched` threshold (`esp32s3_touch_read`) |
| `SHA` | FIPS-180 SHA-1/224/256 vectors (`esp32s3_crypto`) |
| `AES` | FIPS-197 AES-128/256 vectors (`esp32s3_crypto`) |
| `W25Q` | W25Q256FV JEDEC ID + erase/program/read-back round-trip (`esp32s3_w25q`) |
| `TLV2556` | TI 12-bit SPI ADC: self-test voltages 0/2048/4095 + channel read (`esp32s3_tlv2556`) |

**🟡 Needs on-card testing** (compile-verified + no-card smoke run only — boots,
runs the init path on silicon, reports `No_Card` cleanly; the on-card read/write
PASS is left to the user):

| Driver | State | Notes |
|--------|-------|-------|
| `SD_SPI` | compile + no-card smoke | lower-risk; reuses the verified SPI master (`esp32s3_sd_spi`) |
| `SDMMC` | compile + light-tasking + no-card smoke | least-verified; native-host clock tree likely needs bring-up (`esp32s3_sdmmc`) |

## How a project consumes it
One `with` in the project's `.gpr` — no `Source_Dirs`, no paths:

```ada
--  standalone project (resolved by name via GPR_PROJECT_PATH from export.sh):
with "esp32s3_hal.gpr";
--  or, in an in-repo example (relative, so the Ada Language Server needs no env):
with "../../libs/esp32s3_hal/esp32s3_hal.gpr";
```
then in your code `with ESP32S3.GPIO;` (etc.). The build compiles only the
**closure** of your main, so the dozens of unused register packages cost nothing —
`app.bin` is unchanged whether or not the HAL is `with`ed. `esp32-ada init` /
`./x new` add the `with` for you, so new projects have the HAL on tap.

## Runtime profile & contract checks

The drivers **target the `embedded` profile** (full exception propagation). The
HAL is built with `-gnata` under `embedded`/`full`, so its contracts — e.g. the
`ESP32S3.GPIO.Pin_Id` valid-pad predicate — are **checked at run time** and a
violation raises a catchable `Constraint_Error`/`Assertion_Error`. Driver
projects should select embedded (their `build.sh` exports
`ESP32S3_RTS_PROFILE=embedded`; see `examples/esp32s3_i2c_loopback`).

`light-tasking` keeps its place in the RTS as the minimal / certifiable tier, and
the drivers that don't use finalization (**GPIO, RNG, Temperature, RTC, RTC_IO,
Touch, SHA, AES**) compile and run there. They use protected objects where they need mutual exclusion (GPIO's
RMW `Lock`, the Temperature `Sensor`) or are genuinely lock-free (RNG, the RTC
register pokes) — and
protected objects are perfectly fine under Jorvik, which is a *tasking* profile.
Two embedded-only things don't apply to light-tasking:

- **No run-time contract checks.** `-gnata` is omitted under light-tasking (its
  assertion path would drag in the unwinder + a libc the heap-less profile
  doesn't link). You keep the *compile-time* predicate warning for static pins;
  there's just no run-time check, and a tripped check elsewhere resets the board
  rather than raising.
- **The RAII-handle drivers — SPI, I2C, UART, GDMA, MCPWM, I2S, LEDC, RMT, PCNT,
  SDM, TWAI, Timer, LCD and ADC — are embedded/full-only.** Their handle (the
  SPI/I2C/UART/I2S/TWAI/LCD `Session`, the GDMA `Channel`, the MCPWM `Channel`/
  `Capture`, the LEDC `Channel`, the RMT `TX_Channel`/`RX_Channel`, the PCNT
  `Unit`, the SDM `Channel`, the `Timer`, the ADC `Reader`) is a *controlled* type
  that releases
  its resource automatically on scope exit, including during exception unwinding
  — which needs finalization, forbidden under light-tasking (`No_Finalization`).
  So those are excluded from the light-tasking build.

Pick embedded to use exceptions, finalization and the contract checks to the
fullest.

## GPIO example
```ada
with ESP32S3.GPIO; use ESP32S3.GPIO;
...
Configure (Pin => 2, Mode => Output, Drive => Drive_Strong);   -- IO-MUX + matrix + enable
Set (2);  Clear (2);  Toggle (2);  Write (2, True);
B := Read (Pin => 0);                                          -- sample an input
```
Any pad 0..48; `Configure` sets pad function / direction / pull / drive. The
32-bit-bank vs `*1`-bank split (pins >31) is hidden. NOTE: pads ~26..32 are the
SPI flash / PSRAM on most modules — don't drive them.

### GPIO interrupts
```ada
with ESP32S3.GPIO.Interrupts; use ESP32S3.GPIO.Interrupts;
...
Enable (Pin => 4, On => Rising_Edge, Action => On_Edge'Access);
```
`On_Edge` is a library-level procedure run in **interrupt context** (inside the
protected ISR, at the level-3 ceiling) — keep it short; the usual idiom is to
bump an `Atomic` flag or `Set` a `Suspension_Object` a task is waiting on. One
GPIO source serves all pins (the ISR demuxes by status). Routes to the runtime's
level-3 device-interrupt slot; requires a tasking runtime.

## Temperature example
```ada
with ESP32S3.Temperature; use ESP32S3.Temperature;
...
Initialize;                       -- bring the sensor up (default -10..80 C range)
T  := Read_Celsius;               -- whole degrees C (die temperature, signed)
CC := Read_Centi_Celsius;         -- 1763 = 17.63 C, if you want one decimal
```
Reports the SoC *die* temperature, not ambient (the chip self-heats, so an idle
board reads a few degrees above room temperature); ~±1 °C after factory trim.
Pass a `Measure_Range` to `Initialize` to re-centre accuracy on a hotter band.

## GDMA example (memory-to-memory)
```ada
with ESP32S3.GDMA; use ESP32S3.GDMA;
...
declare
   Ch : Channel;                          -- limited + controlled (RAII handle)
begin
   Claim (Ch, Mem2Mem);                   -- grab one of the 5 channel pairs
   if Is_Valid (Ch) then
      Copy (Ch, Dst'Address, Src'Address, 64);  -- blocking; up to Max_Transfer bytes
   end if;
end;                                      -- Finalize releases the channel back to the pool
```
The S3 has five GDMA channel pairs assignable to peripherals via the crossbar.
`Channel` is a **limited, controlled** handle: it cannot be copied (two tasks
can't alias one channel) and its `Finalize` returns the channel to the pool on
scope exit, so channels can't leak or be reused through a stale copy. `Claim`
fills the handle in place with a free channel (check `Is_Valid`); `Copy` does a
blocking memory-to-memory transfer (`Src`/`Dst` in internal SRAM). NOTE for
mem2mem the channel borrows a peripheral trigger slot (it does NOT use the
disconnected id 0x3F — doing so leaves the channel idle, which was a subtle
bring-up bug). Being controlled, `Channel` is embedded/full-only (light-tasking
forbids finalization).

### Peripheral-bound transfers
A peripheral driver `Claim`s a channel bound to its peripheral and drives one
direction at a time with the lower-level primitives:

```ada
declare
   Ch : Channel;
begin
   Claim (Ch, SPI2);                               -- channel bound to the peripheral
   Start (Ch, Mem_To_Periph, Tx_Buf'Address, Len); -- RAM -> peripheral (OUT/TX path)
   Start (Ch, Periph_To_Mem, Rx_Buf'Address, Len); -- peripheral -> RAM (IN/RX path)
   --  ... configure + start the peripheral itself ...
   Wait (Ch, Periph_To_Mem);                        -- or poll Done (Ch, Dir)
end;
```

`Start` is non-blocking and arms the same descriptor engine `Copy` uses; the
peripheral's own registers and its DMA-request handshake belong to the
peripheral driver. **`ESP32S3.SPI` is the first such consumer and HW-verifies
this whole path** (full-duplex SPI2 DMA, see below).

## SPI example (task-safe; the first GDMA peripheral consumer)
```ada
with ESP32S3.SPI; use ESP32S3.SPI;

--  once, single-threaded, at startup:
Setup (SPI2);                                            -- or Setup (SPI3, ...)
Configure_Pins (SPI2, Sclk => 12, Mosi => 11, Miso => 13, Cs => 10);  -- shared wires
--  or, for a wiring-free self-test:  Enable_Loopback (SPI2, Pad => 5);

--  then, from any task (mutually exclusive):
declare
   S : Session;                       -- limited: cannot be copied/shared
begin
   Acquire  (S, SPI2, Mode => 0, Clock_Hz => 4_000_000);  -- this device's mode/clock
   Transfer (S, Tx'Address, Rx'Address, 32);   -- full-duplex DMA, blocking
end;                                  -- S auto-releases the host on scope exit
```
A full-duplex SPI **master** for either general-purpose host (**SPI2** or
**SPI3** — SPI0/SPI1 are the flash/PSRAM controllers, off-limits). The two hosts
share one register layout and differ only in base address, GDMA trigger and
GPIO-matrix signals, so one body drives either. Mode (0..3) and a software-divided
bit clock are **per-device**, applied at `Acquire` under the exclusive hold, so two
devices on one host can run different modes/clocks; transfers run over `ESP32S3.GDMA`.

**Concurrency:** each host is mediated by a protected object, so two tasks can't
clash — `Acquire` blocks until the host is free, the `Session` handle is *limited*
(non-copyable, can't be shared), and the blocking DMA runs *outside* the lock. The
raw unsynchronised driver lives in the hidden private child `ESP32S3.SPI.Engine`
and is unreachable from application code. HW-validated under **two tasks
contending on one host** (80 loopback transfers, 0 corruption). The `Session` is
a **controlled** type: it releases the host automatically when it leaves scope,
including during exception unwinding, so a fault between `Acquire` and the end of
the block can't leak the lock (`Release` is still available to hand it back
early, and is idempotent). That uses finalization, so SPI/I2C/UART are
embedded/full-only (see *Runtime profile* above).

## SD card over SPI (`ESP32S3.SD_SPI`, builds on the SPI master)
```ada
with ESP32S3.SD_SPI; with ESP32S3.SPI;

C  : ESP32S3.SD_SPI.Card;
St : ESP32S3.SD_SPI.Status;
B  : ESP32S3.SD_SPI.Block;          --  512-byte sector

ESP32S3.SD_SPI.Setup (C, ESP32S3.SPI.SPI2, Sclk => 12, Mosi => 11,
                      Miso => 13, Cs => 10);     -- CS is a plain GPIO
ESP32S3.SD_SPI.Initialize (C, St);               -- CMD0/8/ACMD41/CMD58 handshake
ESP32S3.SD_SPI.Read_Block  (C, LBA => 0, Data => B, Result => St);
ESP32S3.SD_SPI.Write_Block (C, LBA => 0, Data => B, Result => St);
```
The SD "SPI mode" command protocol (CMD0/8/58, ACMD41, CMD17/24, CRC7) layered on
the task-safe SPI master. The chip-select is driven as a **plain GPIO** so it can
be held asserted across a whole command / response / data sequence (the SPI
peripheral's own CS pulses per transfer, which SD can't use). Cards init at
≤400 kHz then run at `Data_Clock_Hz` (via the new `ESP32S3.SPI.Set_Clock`, which
re-divides the bit clock without re-Claiming GDMA). SDSC v1/v2 and SDHC/SDXC are
detected from CMD8 + the OCR CCS bit; the API is always 512-byte **LBA** (byte vs
block addressing is handled internally). DMA scratch is a per-host internal-SRAM
buffer (a task stack in PSRAM can't be a GDMA target), and each operation takes
the host `Session`, so concurrent callers serialise. Finalization (via that
Session) → **embedded / full** only.

> **Verification:** an SD card has no wiring-free self-test, so this is
> compile-verified + a no-card smoke run (boots, runs the init path on silicon,
> reports `No_Card` cleanly). The on-card PASS (`examples/esp32s3_sd_spi`, a
> non-destructive read / write-back / re-read round-trip) is run by the user.

## Native SD/MMC host (`ESP32S3.SDMMC`, the dedicated SDHOST controller)
```ada
with ESP32S3.SDMMC;

C  : ESP32S3.SDMMC.Card;
St : ESP32S3.SDMMC.Status;
B  : ESP32S3.SDMMC.Block;

ESP32S3.SDMMC.Setup (C, ESP32S3.SDMMC.Slot1, Clk => 14, Cmd => 15, D0 => 2,
                     D1 => 4, D2 => 12, D3 => 13,
                     Width => ESP32S3.SDMMC.Width_4);
ESP32S3.SDMMC.Initialize (C, St);                 -- CMD0/8/ACMD41/CMD2/3/7/16
ESP32S3.SDMMC.Read_Block  (C, LBA => 0, Data => B, Result => St);
```
The *native* SD bus (clock + bidirectional command + 1 or 4 data lines) on the
DesignWare SDHOST controller — faster than SPI mode and how you reach an SDHC/SDXC
card at speed. Data moves in **PIO/FIFO mode** (the CPU pushes/pops the 512-byte
block through the controller FIFO), so there is **no DMA and no finalization**: a
library-level protected object serialises the single controller, and the driver
works under **every** runtime profile (light-tasking included — unlike the
finalization-based SPI/SD_SPI). Two slots; lines route through the GPIO matrix
(pull-ups on CMD/DATA). Init at ≤400 kHz then `Data_Clock_Hz`; the API is 512-byte
LBA (SDSC/SDHC addressing handled internally).

> **Maturity:** **compile-verified + a no-card smoke run only** (boots, runs the
> init path on silicon, reports `No_Card` cleanly, 0 panics) — *not yet brought up
> on a real card*. The native host has clock-tree/timing details (the SDHOST
> functional-clock source `Src_Hz`, CLK-edge phase) that need a card on a scope to
> tune; expect on-card bring-up (`examples/esp32s3_sdmmc`). For low-risk storage,
> prefer `ESP32S3.SD_SPI`.

## I2C example (task-safe master)
```ada
with ESP32S3.I2C; use ESP32S3.I2C;

--  once, single-threaded, at startup:
Setup (I2C0, Clock_Hz => 100_000);            -- or Setup (I2C1, ...)
Configure_Pins (I2C0, Scl => 6, Sda => 4);

--  then, from any task (mutually exclusive):
declare
   S  : Session;                      -- limited: cannot be copied/shared
   Ok : Boolean;
begin
   Acquire (S, I2C0);                  -- suspends until the controller is free
   Write   (S, Addr => 16#42#, Data => (16#10#, 16#00#), Success => Ok);
end;                                   -- S auto-releases the controller on exit
```
An I2C **master** for either controller (**I2C0** / **I2C1**, one shared register
layout). It drives the ESP32-S3 command-sequence engine (START / WRITE / READ /
STOP), an XTAL-sourced bus clock, open-drain matrix pad routing, and ACK/NACK +
timeout detection; `Write` takes an optional `Check_Ack`. Same task-safe shape as
SPI (per-controller protected guard, limited `Session`, raw driver hidden in the
private child `ESP32S3.I2C.Engine`).

> **Verification caveat.** A fully on-chip master↔slave loopback is *impossible*
> on the S3: I2C SDA is open-drain (wired-AND) and the GPIO matrix gives each pad
> a single output source, so two controllers can't share one line. The self-test
> (`examples/esp32s3_i2c_loopback`) therefore proves START/addressing, NACK
> detection and multi-byte transmit; the **read** direction and the ACK handshake
> need a real device or a two-pad jumper.

## UART example (task-safe; optional RTS/CTS flow control)
```ada
with ESP32S3.UART; use ESP32S3.UART;

--  once, single-threaded, at startup:
Setup (UART1, Baud => 115_200);                  -- 8-N-1 by default
Configure_Pins (UART1, Tx => 17, Rx => 18);      -- all pins optional;
--   Configure_Pins (UART1, Rx => 18);           --   e.g. a receive-only GPS
--   Configure_Pins (UART1, Tx => 17, Rx => 18, Rts => 19, Cts => 20);  -- flow control
--  or a wiring-free self-test:  Enable_Loopback (UART1);

--  then, from any task (mutually exclusive):
declare
   S  : Session;
   Rx : Byte_Array (0 .. 31);
   N  : Natural;
begin
   Acquire (S, UART1);
   Write   (S, (16#48#, 16#69#));      -- "Hi"
   Read    (S, Rx, N);                 -- up to 32 bytes, short-read on timeout
end;                                   -- S auto-releases the port on exit
```
An async UART for **UART0 / UART1 / UART2** (one shared layout). Baud (XTAL-sourced
divider) and 5–8 / parity / 1–2-stop framing are configurable; TX/RX go through the
FIFOs. `Configure_Pins` validates each pad (`ESP32S3.GPIO.Pin_Id`) and every line is
optional, so a one-way link routes only what it uses. Giving `Rts`/`Cts` enables
**hardware flow control** (RTS throttles the peer at an RX-FIFO threshold; CTS gates
our transmitter). Each line's polarity can be **inverted independently** (`CONF0`
line inverts) — set initial inversion via the `*_Invert` flags on `Configure_Pins`,
or flip it at run time with `Set_Inversion`. The controller's `Enable_Loopback`
(internal TX→RX) gives a faithful no-wire self-test because UART is push-pull. Same
task-safe shape as SPI; raw driver hidden in `ESP32S3.UART.Engine`. HW-verified: data
loopback + RTS/CTS throttle + per-line inversion (`examples/esp32s3_uart_loopback`).

## MCPWM example (motor-control PWM output)
```ada
with ESP32S3.MCPWM; use ESP32S3.MCPWM;

--  once, single-threaded, at startup:
Setup (MCPWM0);                                       -- bring the unit's clock up

declare
   Ch : Channel;                                      -- limited + controlled (RAII)
begin
   Claim (Ch, MCPWM0, Ch0);                           -- own generator channel 0
   Configure_Channel (Ch, Freq => 20_000, Pin => 4);
   Start (Ch);

   Set_Duty (Ch, Percent => 25.0);                    -- single atomic write; you own Ch

   --  or a complementary half-bridge pair with dead-time on another channel:
   --  Configure_Channel (Ch1, Freq => 20_000, Pin => 6,
   --                     Complement_Pin => 7, Dead_Time_Ns => 1_000);
end;                                                  -- Finalize stops + releases the channel
```
Edge-aligned PWM for either unit (**MCPWM0** / **MCPWM1**), three generator
channels each (`Ch0`/`Ch1`/`Ch2`).  A channel is one timer + one operator
generating a single output on A (high at the period start, low at the duty
comparator), routed to a validated `ESP32S3.GPIO` pin; the 160 MHz PWM clock's
prescaler + 16-bit period are picked automatically for the requested frequency
(~10 Hz .. 10 MHz).  Pass a `Complement_Pin` to also drive the inverted B output
with `Dead_Time_Ns` of dead-time on each edge (half-bridge / H-bridge motor
drive) — the two outputs are then never high simultaneously.

**Ownership / concurrency:** a generator channel and a capture channel are
claimed as **limited, controlled** handles (`Channel` / `Capture`) — non-copyable
(two tasks can't drive the same channel) and auto-released on scope exit (stopping
the timer, so a leaked handle can't keep driving a pad). `Setup` is the one-time
per-unit clock bring-up; the per-channel ops (`Configure_Channel` / `Start` /
`Stop` / `Set_Duty`) take the handle, and `Set_Duty` is a single atomic register
write that needs no lock because you exclusively own the channel. (Because it uses
finalization, MCPWM is embedded/full-only — see *Runtime profile* above.) The full
operator is covered: single-output and complementary-with-dead-time PWM,
**carrier** (chopper) modulation (`Set_Carrier`), the **fault / trip-zone**
input that forces outputs to a safe state (`Configure_Fault` / `Protect_Channel`
/ `Clear_Fault` / `Faulted`), and the **capture** submodule for timestamping an
input's edges to measure its period/duty (`Configure_Capture` /
`Capture_Pending` / `Read_Capture`, on the 80 MHz capture timer). HW-verified end
to end (`examples/esp32s3_mcpwm_pwm`): 20 kHz at 25/75 % duty, a 50 %
complementary pair with 1 µs dead-time (0 % overlap), capture reading back
exactly 20000 Hz / 30 %, a fault tripping the output to 0 % and recovering, and
the carrier chopping a 100 % output to ~50 %.

## I2S example (task-safe digital audio over GDMA)
```ada
with ESP32S3.I2S; use ESP32S3.I2S;

--  once, single-threaded, at startup:
Setup (I2S0, Sample_Rate => 16_000, Bits => Bits_16);     -- stereo master
Configure_Pins (I2S0, Bclk => 5, Ws => 6, Dout => 7, Din => 8);
--  or, for a wiring-free self-test:  Enable_Loopback (I2S0, Pad => 4);

--  then, from any task (mutually exclusive):
declare
   S : Session;                       -- limited: cannot be copied/shared
begin
   Acquire  (S, I2S0);                -- suspends until the port is free
   Transfer (S, Tx'Address, Rx'Address, Len);   -- full-duplex DMA, or Write/Read
end;                                  -- auto-released on scope exit
```
Two ports (**I2S0** / **I2S1**), each a stereo Philips/TDM master that streams
PCM over its own GDMA channel (the S3 I2S has no CPU FIFO — data moves only by
DMA). `Write` shifts a buffer out (to a DAC), `Read` captures one (from a mic),
`Transfer` does both at once. The `Session` is the same limited, controlled
handle as SPI: `Acquire` suspends until the port is free and it auto-releases on
scope exit. `Enable_Loopback` uses the hardware `SIG_LOOPBACK` (TX and RX share
WS+BCK internally) so a single data pad round-trips with **no wiring**.
HW-verified (`examples/esp32s3_i2s_loopback`): 64 stereo 16-bit samples DMA'd out
and back, byte-for-byte match.

## LEDC example (8-channel PWM / LED dimmer)
```ada
with ESP32S3.LEDC; use ESP32S3.LEDC;

declare
   Ch : Channel;                          -- limited + controlled (RAII)
begin
   Claim     (Ch, 0);                      -- own channel 0
   Configure (Ch, Freq => 5_000, Pin => 4, Bits => 10);   -- 5 kHz, 10-bit duty
   Set_Duty  (Ch, Percent => 25.0);        -- any time; you own Ch
end;                                       -- output stopped + channel released
```
Eight channels (`0 .. 7`) fed by four timers; `Configure` programs the channel's
timer (`Index mod 4`) for the requested frequency and duty resolution and routes
the output to a validated `ESP32S3.GPIO` pin, and `Set_Duty` changes the duty at
run time. The `Channel` is the same limited, controlled handle as MCPWM/GDMA:
non-copyable, and its `Finalize` stops the output and returns the channel to the
pool. (Channels whose indices differ by 4 share a timer, so use `0 .. 3` for four
independent frequencies.) HW-verified (`examples/esp32s3_ledc_pwm`): 5 kHz at
25/75 % duty GPIO-sampled back, plus the RAII handle (claim all 8, 9th rejected,
reclaimed on scope exit).

## RMT example (remote-control pulse TX/RX — IR, WS2812)
```ada
with ESP32S3.RMT; use ESP32S3.RMT;

declare
   Tx : TX_Channel;
begin
   Claim     (Tx, 0);
   Configure (Tx, Resolution_Hz => 1_000_000, Pin => 4);   -- 1 tick = 1 µs
   Transmit  (Tx, (0 => (Level0 => True,  Duration0 => 50,
                         Level1 => False, Duration1 => 60),
                   1 => (Level0 => True,  Duration0 => 80,
                         Level1 => False, Duration1 => 90)));
end;                                       -- channel stopped + released
```
Eight channels — `0 .. 3` transmit, `4 .. 7` receive — each with a 48-symbol RAM
block; a symbol is two `{level, duration}` pulses, durations in channel ticks
(tick length = `1 / Resolution_Hz`). TX and RX are distinct limited, controlled
handle types (`TX_Channel` / `RX_Channel`) so they can't be confused; both
`Claim` through a protected pool and auto-release on scope exit. HW-verified
(`examples/esp32s3_rmt_loopback`): a TX channel transmits a burst that an RX
channel reads back through one GPIO pad (the matrix loops out→in, no wiring) and
the captured durations match what was sent, symbol for symbol.

## PCNT example (pulse / edge counter)
```ada
with ESP32S3.PCNT; use ESP32S3.PCNT;

declare
   U : Unit;
begin
   Claim     (U, 0);
   Configure (U, Pin => 4);              -- count rising edges on GPIO4
   --  ... pulses arrive ...
   N := Count (U);                        -- signed 16-bit count
end;                                      -- counter paused + released
```
Four counter units (`0 .. 3`), each counting edges on its input pin into a signed
16-bit counter (`Configure` with `Both_Edges` to count both edges; `Count` /
`Clear` / `Pause` / `Resume`). The `Unit` is the same limited, controlled handle:
non-copyable, auto-released on scope exit. HW-verified
(`examples/esp32s3_pcnt_count`): a GPIO is software-toggled 100 times into the
unit's input (routed on the same pad, no wiring) and the count reads exactly 100,
plus the RAII handle (claim all 4, 5th rejected, reclaimed on scope exit).

## SDM example (sigma-delta density output)
```ada
with ESP32S3.SDM; use ESP32S3.SDM;

declare
   Ch : Channel;
begin
   Claim       (Ch, 0);
   Configure   (Ch, Pin => 4);            -- route to GPIO4
   Set_Density (Ch, Percent => 25.0);     -- average output density
end;                                       -- output low + released
```
Eight channels (`0 .. 7`), each emitting a 1-bit pulse stream whose average
density is set by `Set_Density` (pass it through an RC low-pass for a cheap analog
output). The `Channel` is the same limited, controlled handle. HW-verified
(`examples/esp32s3_sdm_output`): a channel set to 25 / 50 / 75 % density,
GPIO-sampled back, reads its programmed density, plus the RAII handle (claim all
8, 9th rejected, reclaimed on scope exit).

## TWAI example (CAN 2.0, task-safe)
```ada
with ESP32S3.TWAI; use ESP32S3.TWAI;

Setup (Mode => Normal, Bit_Rate => 500_000);      -- once
Configure_Pins (Tx => 5, Rx => 6);                -- to an external transceiver
--  or, for a wiring-free self-test:  Setup (Self_Test); Enable_Loopback (4);

declare
   S : Session;  Rx : Frame;  Got : Boolean;
begin
   Acquire (S);
   Send    (S, (Id => 16#123#, Length => 5,
                Data => (16#DE#, 16#AD#, 16#BE#, 16#EF#, 16#42#, others => 0)));
   Receive (S, Rx, Got);
end;                                              -- controller released
```
One SJA1000-compatible CAN controller; standard (11-bit) data frames via a
limited, controlled `Session` (the same shape as SPI). In `Self_Test` mode it
transmits and receives its own frame with no second node, and `Enable_Loopback`
loops TX→RX through one GPIO pad, so the whole path runs **with no wiring or
transceiver**. HW-verified (`examples/esp32s3_twai_loopback`): a frame
(`id 0x123`, 5 data bytes) is self-transmitted and read back with matching ID,
length and payload.

## Timer example (general-purpose timers)
```ada
with ESP32S3.Timer; use ESP32S3.Timer;

declare
   T : Timer;
begin
   Claim     (T, 0);                      -- TIMG0
   Configure (T, Tick_Hz => 1_000_000);   -- 1 tick = 1 µs
   Start     (T);
   --  ... later ...
   N := Value (T);                         -- 54-bit count
   Set_Alarm (T, 30_000);                  -- flag fires at 30 ms
   if Alarm_Fired (T) then Clear_Alarm (T); end if;
end;                                       -- stopped + released
```
Two general-purpose timers (TIMG0 / TIMG1), each a 54-bit up-counter off the APB
clock through a 16-bit prescaler, with a one-shot alarm flag. The `Timer` is the
same limited, controlled handle. HW-verified (`examples/esp32s3_timer_count`): a
1 MHz timer's count over a 50 ms runtime delay reads ~50 000 (the two independent
time bases agree), and an alarm set at 30 000 fires at ~30 ms.

## LCD example (8-bit i80 parallel master over GDMA)
```ada
with ESP32S3.LCD; use ESP32S3.LCD;

Setup (Pclk_Hz => 1_000_000);                          -- once; claims a GDMA channel
Configure_Pins (Data => (4, 5, 6, 7, 8, 9, 10, 11), Pclk => 13);

declare
   S : Session;  Ok : Boolean;
begin
   Acquire  (S);
   Transmit (S, Buf'Address, Buf'Length, Ok);          -- one byte per pixel clock
end;                                                   -- controller released
```
The LCD half of the LCD_CAM controller as an 8-bit Intel-8080 parallel master:
a byte buffer is streamed out the data bus over GDMA, one byte per pixel clock,
through a limited, controlled `Session` (the same shape as SPI). HW-verified
(`examples/esp32s3_lcd_i8080`): a 4000-byte DMA transfer completes (trans-done),
and timing it confirms the configured 200 kHz pixel clock. (The camera-receive
half and the 16-bit / RGB modes are future work.)

## ADC example (SAR analog-to-digital, one-shot)
```ada
with ESP32S3.ADC; use ESP32S3.ADC;

declare
   R : Reader;
begin
   Claim (R, ADC1);                              -- powers + self-calibrates the SAR
   V := Read (R, Ch => 0, Atten => Db_12);       -- ch0 = GPIO1; 0 .. 4095
end;                                             -- unit released
```
Two SAR units (ADC1 ch0..9 = GPIO1..10; ADC2 ch0..9 = GPIO11..20), 12-bit one-shot
conversions with selectable input attenuation (`Db_0` ~1.1 V .. `Db_12` ~3.3 V
full scale). The `Reader` is the same limited, controlled handle; claiming it
performs the one-time analog bring-up the S3 SAR needs — powering the core,
enabling the SENS-domain conversion clock, and a per-unit self-calibration over
the internal REGI2C bus (via the boot ROM, like the temperature sensor) — without
which every conversion returns 0. HW-verified (`examples/esp32s3_adc_read`):
ADC1 ch0's own pad is driven high then low and read back as ~4095 then ~0.

## RTC example (low-power: retained memory + deep sleep + wake)
```ada
with ESP32S3.RTC; use ESP32S3.RTC;

--  Data in RTC slow memory survives deep sleep (and most resets).  Access it via
--  the word accessors (bounds-checked), a typed generic, or your own overlay:
Boot_Count : constant Unsigned_32 := Read (0);          -- word 0
Write (0, Boot_Count + 1);
--  or:  package Counter is new ESP32S3.RTC.Retained (Unsigned_32, Offset => 0);
--  or:  C : Unsigned_32 with Import, Volatile, Address => ESP32S3.RTC.Slow_Memory;

case Last_Wake is                                  -- why did we boot?
   when Deep_Sleep_Timer | Deep_Sleep_GPIO => Boot_Count := Boot_Count + 1;
   when others                             => Boot_Count := 1;
end case;

Deep_Sleep_For (2.0);                              -- sleep ~2 s; does NOT return
--  or Deep_Sleep_Until (Pin => 0, High => True);  -- wake on an RTC-GPIO level
```
In deep sleep the digital core (CPU + main RAM) powers down — on wake the chip
**resets and re-runs from the start**, but data in RTC slow memory (8 KB at
`Slow_Memory`) persists. `Last_Wake` reports whether this boot is a power-on or a
deep-sleep wake (timer or GPIO); `Deep_Sleep_For` / `Deep_Sleep_Until` enter deep
sleep with a timer or RTC-GPIO (EXT1) wake source. HW-verified
(`examples/esp32s3_rtc_sleep`): a boot counter in retained memory survives across
deep-sleep cycles (`1 → 2 → 3 → 4`) while the wake cause reads `deep-sleep-timer`
and the ROM reports `rst:0x5 (DSLEEP)`. (`Disable_Super_Watchdog` lets a woken app
stay awake, since a deep-sleep wake can leave the super-WDT armed.) These are
register pokes with no finalization, so RTC works under **every** profile,
light-tasking included.

## RTC-IO example (low-power pad hold)
```ada
with ESP32S3.RTC_IO; use ESP32S3.RTC_IO;

ESP32S3.GPIO.Set (5);     -- drive the RTC-capable pad to the wanted level
Hold (5);                 -- latch it: GPIO writes are now ignored, and the level
                          -- survives deep sleep + the wake reset
--  ... Deep_Sleep_For (...) keeps GPIO5 driven while the core is powered down ...
Release (5);              -- pad follows the GPIO register again
```
GPIO0 .. GPIO21 are RTC-capable. `Hold` latches a pad at its current output level
through ordinary GPIO writes, **and through deep sleep** (the digital core powers
down but a held RTC pad stays put) and the reset a wake causes — so you can keep a
load enabled or a reset line asserted while you sleep. `Release` restores normal
control. The package also has the **RTC-domain pulls**: `Enable_RTC_Input (Pin)`
routes a pad into the RTC domain and `Set_Pull (Pin, Up | Down | No_Pull)` applies
an RTC pull-up/down (active in deep sleep, distinct from the digital `ESP32S3.GPIO`
pulls). HW-verified (`examples/esp32s3_rtcio_hold`): a held pad ignores a `Clear`
and obeys it after `Release`; and an RTC-input pad reads high under its RTC pull-up
and low under its pull-down. Register pokes, no finalization, so it works under
every profile.

## Touch example (capacitive touch sensing)
```ada
with ESP32S3.Touch; use ESP32S3.Touch;

Setup;                          -- bring up the touch FSM (scans on the RTC timer)
Enable (1);                     -- channel 1 = GPIO1
Enable (3);                     -- channel 3 = GPIO3
N := Read (1);                  -- raw self-capacitance count; rises when touched

Base := Read (1);                                  -- untouched baseline
Hit  := Touched (1, Base, Margin => 50_000);       -- True when a finger lands
```
14 channels on GPIO1 .. GPIO14. The FSM measures each enabled pad's
self-capacitance by counting charge/discharge cycles; `Read` returns the latest
count (higher = more capacitance, so a finger raises it). `Touched (Ch,
Reference, Margin)` is a software threshold on the live `Read` value — True when
the count deviates from `Reference` by more than `Margin` in either direction.
HW-verified (`examples/esp32s3_touch_read`): with nothing connected, two channels
read **stable, non-zero, and distinct** baselines (each pad's own capacitance) —
proving the measuring FSM runs on silicon; and `Touched` reads *not touched*
against the captured baseline and *touched* against a shifted reference. (A finger
on a pad raises its count past the margin the same way; that part is interactive,
not part of the automated check.) Register pokes, no finalization, so it works
under every profile.

## Crypto example (hardware SHA-1/224/256 + AES-128/256)
```ada
with ESP32S3.SHA; with ESP32S3.AES;

D1  : constant ESP32S3.SHA.SHA1_Digest   := ESP32S3.SHA.Hash_1   (Message);
D24 : constant ESP32S3.SHA.SHA224_Digest := ESP32S3.SHA.Hash_224 (Message);
D   : constant ESP32S3.SHA.SHA256_Digest := ESP32S3.SHA.Hash_256 (Message);
C   : constant ESP32S3.AES.Block := ESP32S3.AES.Encrypt_ECB (Key, Plain);  -- Key_128 or Key_256
P   : constant ESP32S3.AES.Block := ESP32S3.AES.Decrypt_ECB (Key, C);
```
`ESP32S3.SHA.Hash_1` / `Hash_224` / `Hash_256` run the hardware SHA accelerator
over a byte message (any length, padded internally); `ESP32S3.AES` does
single-block ECB encrypt / decrypt, the key length selecting AES-128 (`Key_128`,
16 bytes) or AES-256 (`Key_256`, 32 bytes). Each accelerator is a single shared
resource, so a protected object serialises the load/trigger/read — concurrent
calls from different tasks are safe. HW-verified against published test vectors
(`examples/esp32s3_crypto`): `SHA-{1,224,256}("abc")` match the FIPS-180 digests,
and the FIPS-197 AES-128/256 examples encrypt to the expected ciphertext and
decrypt back. (The block hardware also does SHA-384/512 and AES chaining modes —
not wrapped here yet. **AES-192 is *not* available on the S3 silicon** — selecting
it makes the engine fall back to AES-128 — so it is intentionally not offered: the
operations carry a `Pre => Supported_Key (Key)` contract that admits only 16- or
32-byte keys, so a wrong-sized key is a contract violation, not a silent fallback.
Correct callers passing `Key_128` / `Key_256` satisfy it statically — no run-time
cost — and under the exception-capable profiles `-gnata` enforces it at run time.)

## Adding the next peripheral (LCD_CAM camera / …)
1. The registers are already in `svd/` (full layer generated).
2. Add `ESP32S3.<Peri>` (spec + body) **in the right `src/` subdirectory** — see
   the table at the top. `src/` itself only if the driver is lock-free and
   `Preelaborate` (no finalization, exceptions or secondary stack), because
   that is what `light-tasking` compiles; `src/peripherals/` if it hands out an
   RAII handle. `with` `ESP32S3_Registers.<Peri>` and look at `esp32s3-gpio.adb`
   for the read-modify-write + atomic-W1TS idiom.
3. Consumers already have the `Source_Dirs`; they just `with ESP32S3.<Peri>`.
4. `./x test lib` — it builds this library on every profile, so a driver in the
   wrong directory fails there rather than in somebody's light-tasking app.
   Warnings are failures: the HAL is clean under `-gnatwa`, keep it that way.
5. Only re-run `regenerate.sh` if the SVD or svd2ada options change.

## Regeneration
`./regenerate.sh` fetches the ESP32-S3 SVD from the official **espressif/svd**
repo, pinned to a commit (currently SVD v21; this supersedes the older
Arduino-bundled v12, whose `INTERRUPT_CORE1` base-address defect is fixed
upstream, so no base patch is needed). Override the source with
`ESP32S3_SVD=/path.svd ./regenerate.sh`. It also fetches+builds `svd2ada` from
source on first use (the Alire-indexed one is too old; needs network, cached in
`.svd2ada/`), then runs `svd2ada <svd> -o svd -p ESP32S3_Registers --boolean`.
