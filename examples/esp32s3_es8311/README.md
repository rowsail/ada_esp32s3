# ES8311 audio codec — full-duplex 440 Hz loopback — bare-metal Ada (ESP32-S3)

Brings up an **Everest ES8311** low-power mono audio codec **full-duplex**: it
plays a **click-free 440 Hz sine** on its DAC **and at the same time captures the
codec's ADC (microphone)** and estimates the tone it hears back — a loopback
test. Control is over **I2C**; audio is over **I2S**. The codec runs as an **I2S
slave** clocked from the ESP's **MCLK = 256 × sample-rate** (4.096 MHz at 16 kHz).

```
[es8311] ES8311 codec: 440 Hz test tone on the DAC output (I2C control + I2S audio)
[es8311] codec init: OK
[es8311] playing 440 Hz... (connect a speaker/headphone to the codec output)
[es8311] mic capture on (ADC PGA 24 dB) -- play feeds the speaker, mic should hear it
[es8311] captured: peak=3116  est tone=434 Hz
[es8311] captured: peak=3102  est tone=434 Hz
...
```

`codec init: OK` means the codec **ACKed on I2C** and the full register-init
sequence completed. With the board's speaker and mic, the **mic acoustically
picks up the 440 Hz playback**, so each `captured:` line reports ~440 Hz (the
±11 Hz scatter is the zero-crossing estimator's resolution over the ~46 ms
window). (`FAILED` means no I2C ACK: check the address/wiring.)

## Wiring

| Codec    | ESP32-S3 | Role                                   |
|----------|----------|----------------------------------------|
| SCL      | IO7      | I2C clock (control)                    |
| SDA      | IO8      | I2C data (control)                     |
| MCLK     | IO1      | I2S master clock (256 × fs)            |
| SCLK     | IO2      | I2S bit clock (BCLK)                   |
| LRCK     | IO4      | I2S word/frame clock (WS)              |
| DSDIN    | IO5      | I2S data **to** the codec (playback)   |
| ASDOUT   | IO3      | I2S data **from** the codec (capture)  |

I2C address is **0x18** (CE/AD0 low; 0x19 if CE is high).

## The driver — `ESP32S3.ES8311`

`Setup` runs once at startup: it brings up the I2C control bus, starts the I2S
master (so MCLK is already running when the codec's clock state machine comes
up), then runs the codec's register-init sequence and clock coefficients for the
**256 × fs / 16-bit** configuration (the divider values are rate-independent).
`Ok` is `False` if the codec never ACKed.

Audio output goes through a limited, non-copyable, **controlled `Output`** handle
that owns the I2S port exclusively and **releases it automatically on scope exit**
— the same concurrency guard the other HAL drivers use.

```ada
ESP32S3.ES8311.Setup
  (I2C_Bus => ESP32S3.I2C.I2C0, Sda => 8, Scl => 7,
   Port    => ESP32S3.I2S.I2S0, Mclk => 1, Sclk => 2, Lrck => 4, Dsdin => 5,
   Asdout  => 3,                          --  ADC out in -> brings up capture
   Sample_Rate => 16_000, Volume => 75, Mic_Gain_Db => 24, Ok => Ok);

ESP32S3.ES8311.Acquire (Audio);                         --  take the I2S port
ESP32S3.ES8311.Play_Continuous (Audio, Buf'Address, Buf_Bytes);  --  gapless loop
ESP32S3.ES8311.Capture (Audio, Cap'Address, Cap_Bytes);          --  read the mic
```

Pass `Asdout` (the codec's ADC-out line) to also bring up the **ADC / mic** path;
`Mic_Gain_Db` (0 .. 42 dB) sets the ADC PGA. Leave `Asdout` off for output only.

`Set_Volume (0 .. 100 %)` adjusts the DAC level after `Setup`. Note the codec's
DAC volume (reg 0x32) is **0.5 dB/step**: **~75 % ≈ 0 dB (unity)**, and higher is
**positive gain** (100 % ≈ +32 dB) that **clips**. So drive loudness from a
**full-scale digital signal at unity codec gain**, not by boosting the codec —
this example plays a ~−1 dBFS sine at Volume 75 %.

## Gapless playback — `Play_Continuous`

A steady tone has to stream **without gaps**: the simple blocking `Play` (one DMA
buffer at a time) stops and restarts the I2S TX between buffers, and each
stop/restart is a momentary underrun — an audible **click** at the buffer rate.

`Play_Continuous` instead arms a **self-looping DMA descriptor** (`Start_Loop` in
the GDMA layer: the descriptor's link points back to itself, `Owner` stays set
with auto-writeback off) and starts the I2S TX **once**, leaving it running. The
hardware replays the buffer **forever with no inter-buffer gap and zero CPU cost**
— after the single kick, `Main` just idles.

For this to wrap seamlessly the buffer must hold a **whole number of wave
periods**. 440 Hz at 16 kHz is 400⁄11 samples per cycle, so **400 frames span
exactly 11 cycles** (gcd(16000, 440) = 40) and sample 400 would equal sample 0 —
the loop is phase-continuous. The buffer lives in `Main`'s frame (internal SRAM)
and stays valid for the life of the program, which the looping DMA requires.

The sine itself is built with an **integer-only** Bhaskara I approximation
(`sin(πt) ≈ 16 t(1−t) / (5 − 4 t(1−t))`) — no math library — sampled at the 400
unit-circle points.

## Full-duplex capture — `Capture`

Playback and capture share one I2S port and **one clock** (the ESP is master,
clocking the codec). The clean way to run both is to keep **playback continuous**
— `Play_Continuous` leaves the I2S TX clock running forever — and toggle capture
underneath it. `Capture` is an **RX-only** blocking read that deliberately
touches *only* the RX path (no `TX_UPDATE` / `TX_START`), so it samples the
data-in line **without disturbing the running tone**. The mono ADC lands in the
**left** slot of each stereo frame.

`SIG_LOOPBACK` (set during port setup) shares only **WS + BCLK** between the TX
and RX units — it does **not** loop the TX data internally — so capture reads the
codec's *real* ADC output on ASDOUT, not a digital echo of what we play. That
makes the loopback an honest acoustic test: the speaker plays, the mic hears.

Three things this example had to get right (all now handled in the HAL/example):

- **RX latch:** while a continuous TX drives the shared clock, the RX `RX_UPDATE`
  bit doesn't self-clear, so the wait on it is **bounded** (an unbounded spin
  hangs the core).
- **Completion:** a capture is **clock-paced** — *Length /(rate·frame)* seconds
  (tens of ms) — so `Capture` waits on the real RX success-EOF, not a short spin
  guard that would return a half-filled buffer.
- **Analysis:** the estimator skips the RX-start FIFO-priming transient, removes
  the ADC's DC offset, and thresholds on the **mean-absolute-deviation** (not a
  lone peak), so a stray start-up spike can't mask the tone.

## The I2S MCLK output

The ES8311 needs a continuous master clock. `ESP32S3.I2S.Configure_Pins` routes
**MCLK** out through the GPIO matrix (I2S0 `MCLK_OUT`, signal index 23) so the
codec is clocked at 256 × fs directly from the I2S clock module — clean and
matched to the coefficient table, rather than derived from BCLK.

## Source

Register sequence + clock coefficients ported from Espressif's ES8311 driver:

- esp-bsp: <https://github.com/espressif/esp-bsp/blob/master/components/es8311/es8311.c>
- esp-adf: <https://github.com/espressif/esp-adf/blob/master/components/audio_hal/driver/es8311/es8311.c>
- ES8311 datasheet: <https://files.waveshare.com/wiki/common/ES8311.DS.pdf>

## Build & flash

```
./build.sh                 # -> app.bin
./flash.sh /dev/ttyACM0    # flash + run
```
