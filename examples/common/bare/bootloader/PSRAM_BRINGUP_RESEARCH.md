# PSRAM bring-up — research toward a blob-free, readable configuration

**Status:** research only, no code changed. Goal: understand how the octal PSRAM is
configured during the 2nd-stage bootloader well enough to replace the vendored IDF
blobs (`esp_psram_impl_octal.c.obj`, `mspi_timing_*.c.obj`) + ROM calls with readable
from-source code.

Provenance of the blobs: ESP-IDF **v5.4.4** (see `BOOTLOADER_STAGE0.md`). The S3 octal
driver lives at `components/esp_psram/esp32s3/esp_psram_impl_octal.c`; the timing tuning
at `components/esp_hw_support/mspi_timing_*.c` + `port/esp32s3/mspi_timing_*`.

---

## TL;DR — the one finding that changes the plan

**Our vendored blob is an 80 MHz octal-DDR build, _not_ the IDF 40 MHz default.**
That matters because **80 MHz requires an empirical, per-board MSPI input-sampling
calibration (a sweep)**, whereas 40 MHz is a fixed register sequence with no
calibration at all.

Proven three independent ways from the binaries + our own shim:

1. **Clock divider.** `mspi_timing_config_set_psram_clock` programs **core clock
   160 MHz → PSRAM 80 MHz** on its high-speed branch (`movi a7,160`; the low branch is
   `movi a7,80` → 40 MHz). The high branch is the one taken.
2. **Tuning is real, not stubbed.** At ≤40 MHz IDF compiles `mspi_timing_psram_tuning`
   to an empty stub (`MSPI_TIMING_PSRAM_NEEDS_TUNING == (MODULE_CLOCK > 40)`). In our
   blob that function is **160 bytes of real work**: it writes the 64-byte reference
   pattern `0xa5ff005a`, runs `s_sweep_for_success_sample_points`, and applies the
   winner. So the build had `CONFIG_SPIRAM_SPEED_80M`.
3. **Our own shim admits it.** `psram_boot.c` FIX 2 comment: *"our psram-tuning leaves
   din SMEM_MODE=0x04924924 (mode 4) but the SPI0 cache OPI-DDR read only completes with
   the IDF's mode 1; force it."* The sweep runs and leaves a result we then override.

**Implication:** `psram_boot.c`'s FIX 2 (`REG(0x600030C0)=0x01249249`) is *already* a
hand-captured, hardcoded override of one register of the tuning result. That is the seam
we can widen into a fully readable, sweep-free configuration (Option C below).

---

## The full bring-up sequence (from IDF v5.4.4 source, validated against the blob)

`psram_bringup()` (our shim) wraps the IDF flow:

```
esp_rom_opiflash_pin_config()          ROM: octal MSPI pads SPID4-7 + DQS (FIX 1)
mspi_timing_set_pin_drive_strength()   blob: pad drive strength
esp_psram_impl_enable():               blob: the actual chip bring-up (below)
esp_psram_impl_get_physical_size()     blob: read decoded density -> 8 MB
Cache_Disable_DCache()                 ROM
REG(0x600030C0)=0x01249249             FIX 2: force SPI0 SMEM din-mode = 1
Cache_Dbus_MMU_Set(... 0x3D000000 ...) ROM: map BOARD_PSRAM_PAGES x 64 KB
Cache_Enable_DCache(0)                 ROM
```

`esp_psram_impl_enable()` call graph (confirmed by disassembly), in order:

| step | fn | what it does | deterministic? |
|---|---|---|---|
| 1 | `s_init_psram_pins` | route CS1 (`FUNC_SPICS1`), pad drive=3, reserve pin | yes |
| 2 | `s_set_psram_cs_timing` | SPI0 `SMEM_AC`: CS hold=3, setup=3, hold-delay=2 | yes |
| 3 | `s_configure_psram_ecc` | ECC off → clear `SYSCON_SRAM_ACE0_ATTR bit8` | yes |
| 4 | `mspi_timing_enter_low_speed_mode(true)` | drop SPI0/SPI1 to 20 MHz, clear all din/dummy tuning regs | yes |
| 5 | set `SPI_MEM_SPI_FMEM_VAR_DUMMY` on SPI1 + `esp_rom_spi_set_dtr_swap_mode(1,f,f)` | variable-dummy, no DDR byte-swap | yes |
| 6 | `s_init_psram_mode_reg(1,&mr)` | **write MR0**: `lt=1` (fixed latency), `read_latency=2` (→10 cyc), `drive_str=0` | yes |
| 7 | `s_check_psram_connected(1)` | write+read-back `0x5a6b7c8d` at addr 0; verify | yes |
| 8 | `s_get_psram_mode_reg` | read MR0/MR1/MR2/MR3/MR4/MR8 → vendor/density/Vcc | yes |
| 9 | validate vendor (`0x0D`=AP, `0x1A`=UnilC), decode density `0x3`→**8 MB** | info/print | yes |
| 10 | **`mspi_timing_psram_tuning()`** | **empirical din-sampling sweep @ 80 MHz** | **NO** |
| 11 | `mspi_timing_enter_high_speed_mode(true)` | set clocks to 160/80 MHz, apply tuning regs | mostly |
| 12 | `spi_flash_set_{rom,vendor}_required_regs` | restore SPI1 for legacy ROM flash API | yes |
| 13 | `s_config_psram_spi_phases` | program **SPI0 cache** for transparent OPI-DDR access | yes |

### OPI transfer geometry (constants, from the blob + source)

- MR read cmd `0x4040`, MR write `0xC0C0`, sync read `0x0000`, sync write `0x8080`.
- cmd 16 bit, addr 32 bit, read dummy = 18 half-cycles, write dummy = 8, reg-read dummy = 8.
- All MR/probe traffic via ROM `esp_rom_opiflash_exec_cmd(..., DTR_MODE, ..., CS=BIT(1))`.
- There is **no** JEDEC 0x99 reset / 0x9F read-id in the octal path; identity is the MR registers.

### SPI0 cache phase config (step 13), the registers normal access uses

`s_config_psram_spi_phases` programs the 0x6000_3000 (SPI0) block:
`CACHE_SCTRL`/`SRAM_DRD_CMD`/`SRAM_DWR_CMD` (rcmd=0x0000, wcmd=0x8080, 16-bit), addr 32-bit
(`SCMD_4BYTE`), read dummy 18 / write dummy 8 (`VAR_DUMMY`), `SMEM_DDR_EN`, and the octal
lane bits `SCMD_OCT|SADDR_OCT|SDOUT_OCT|SDIN_OCT|SRAM_OCT`.

---

## The empirical part — what the sweep actually calibrates (step 10)

At 80 MHz DDR the round-trip clock→data delay is a meaningful fraction of a bit period,
so the controller must learn *when to sample* the returning data. The sweep tunes three
per-data-line knobs, all in the SPI0 (0x6000_3000) MSPI block:

- **din_mode** — `SPI_MEM_SPI_SMEM_DIN[0..7]_MODE` (the reg our FIX 2 forces, `0x600030C0`):
  the sampling edge/phase.
- **din_num** — `SPI_MEM_SPI_SMEM_DIN[0..7]_NUM`: integer-cycle delay added to data-in.
- **extra_dummy** — `SPI_MEM_SPI_SMEM_TIMING_CALI` + `EXTRA_DUMMY_CYCLELEN`.

Algorithm (`mspi_timing_by_mspi_delay.c`): write the 64-byte `0xa5ff005a` pattern at
20 MHz; for each `{din_mode,din_num,extra_dummy}` triplet in the **160 MHz/80 MHz DTR
table** (14 entries, default id 5) set the regs, read back, `memcmp`; record pass/fail;
take the **middle of the longest run of consecutive passes**. The chosen triplet is
board/chip/temperature dependent — that is the *only* non-reproducible-from-source step.
(120 MHz adds a BBPLL frequency scan + optional temperature-sensor re-tune; we are not at
120 MHz, so that complexity does not apply.)

Our board's observed result: the sweep settles on din SMEM_MODE `0x04924924` (mode 4 on
all lanes), which FIX 2 then overrides to `0x01249249` (mode 1) because the cache OPI-DDR
read path only completes in mode 1. (din_num / extra_dummy from the sweep are currently
left as-is.)

---

## Three routes to a readable, blob-free configuration

### Option A — drop PSRAM to 40 MHz: fully deterministic, simplest
At ≤40 MHz `NEEDS_TUNING` is false: no sweep, din/num/dummy all zero, fixed read dummy.
The entire bring-up becomes a straight register script directly portable to Ada — every
value is a compile-time constant. **Cost:** half the PSRAM bandwidth (40 vs 80 MHz DDR).
Best if PSRAM is used for capacity (buffers/heap) rather than bandwidth.

### Option B — keep 80 MHz, port the sweep: faithful + adaptive, most work
Reimplement `s_sweep_for_success_sample_points` + the 14-entry 160M/80M DTR table +
"middle of longest pass run" selection in Ada. Robust across boards/temperature, but it
is the most code and the part most sensitive to getting the LL register writes exactly
right. Keep as a fallback if Option C proves marginal.

### Option C — keep 80 MHz, capture the tuning result once and hardcode it (recommended)
We already do this for one register (FIX 2). Extend it: capture the *full* tuning state
the sweep produces on our fixed board — `din_mode`, `din_num`, `extra_dummy`, the SPI0
phase regs — and write those as named constants in a readable Ada bring-up. Everything
except the sweep is already deterministic; replacing the sweep with three captured
constants makes the whole flow readable and removes the blobs, at the cost of static
(non-adaptive) timing. For a single fixed board + fixed 80 MHz clock this is low-risk,
and margin can be checked by reading where in the passing run the captured point sits.

---

## JTAG / OpenOCD measurement plan (enables Option C, validates B)

The user's suggestion to single-step is the right instinct; the cheaper equivalent is to
let the existing blob bring PSRAM up, then **read the final MSPI register state** — that
*is* the tuning answer, no stepping required. Read-only, no code change.

On a board with PSRAM mapped (the `esp32s3_psram` example on a Meshnology LoRa AIOT board), after boot, via
the OpenOCD telnet port 4444 (`halt` then `mdw`):

| capture | register(s) | why |
|---|---|---|
| din mode | `0x600030C0` (`SMEM_DIN_MODE`) | the sampling phase the sweep picked (expect mode 4 pre-FIX2) |
| din num | `SMEM_DIN_NUM` (0x6000_30xx) | integer data-in delay |
| extra dummy | `SMEM_TIMING_CALI` + `EXTRA_DUMMY_CYCLELEN` | calibrated dummy cycles |
| cs timing | `SPI_MEM_SPI_SMEM_AC_REG(0)` | confirm hold/setup = 3/3, delay 2 |
| spi phases | `CACHE_SCTRL`, `SRAM_DRD/DWR_CMD`, `SMEM_DDR` | the cache OPI-DDR config to replicate |
| clock | `0x60003050` (core-clk sel, blob writes `0x80000000`) | confirm 160/80 split |

Snapshot these on 2–3 power cycles (and, ideally, warm vs cold) to gauge how stable the
sweep's choice is; tight clustering = Option C is safe, scatter = prefer Option B. The
addr-level disassembly already gives the candidate table and the deterministic writes; a
single live capture turns Option C from "probably" into a verified constant set.

To single-step the real bootloader instead: flash, set the OpenOCD HW breakpoint at
`psram_bringup`, and step into `esp_psram_impl_enable` → `mspi_timing_psram_tuning`,
dumping the same regs before/after each phase. Higher fidelity, more effort; the
post-boot snapshot is enough for Option C.

---

## Hardware test results (2026-06-24, Meshnology LoRa AIOT board on /dev/ttyACM0)

Flashed the `esp32s3_psram` example (blob bring-up) and captured the live MSPI state via
OpenOCD (`tools/openocd.sh`, telnet/`-c` `mdw`), plus single-stepped the bootloader sweep
with HW breakpoints in `mspi_timing_psram_tuning` / `s_do_tuning`.

**1. Final applied registers (post-boot, after FIX 2), 5/5 resets identical — deterministic:**
| reg | addr | value | decode |
|---|---|---|---|
| SMEM extra_dummy / timing_cali | 0x600030BC | `0x0000000b` | CLK_ENA=1, CALI=1, **EXTRA_DUMMY=2** |
| SMEM din_mode | 0x600030C0 | `0x01249249` | **mode 1** ×8 lanes (FIX 2 forced) |
| SMEM din_num | 0x600030C4 | `0x00000000` | **din_num=0** |
| PSRAM @0x3D000000 | — | `03020100 07060504…` | live, correct (big.adb pattern) |

**2. ROOT CAUSE — the sweep is a no-op: it never varies the din timing it claims to test.**
Single-stepped `s_sweep_for_success_sample_points` (HW bp at the per-config `memcmp`,
0x403ccdf8) on the live board:
- **Readback is byte-perfect every iteration.** The reference buffer (@0x3fce9560) is
  `0xa5ff005a`×16; the readback buffer (@0x3fce9470) equals it exactly for all sampled
  configs. **`memcmp` returns 0 (PASS) for 40/40 iterations** — not isolated passes, *all*
  passes. (An earlier reading of "isolated passes / run=1" off raw stack words was a
  misinterpretation; the direct `memcmp`-result capture is authoritative.)
- **The din timing registers never change across the sweep.** At the compare point, SPI0
  (cache) din regs `0x600030C0/C4/BC` are pinned at `0/0/1` and SPI1 din regs
  `0x600020C0/C4/BC` at `0/0/0` — for *every* config. The sweep walks the 14-entry table but
  the `{din_mode,din_num,extra_dummy}` values are **never applied to hardware**, so every
  read uses the same (din=0) configuration and trivially passes.
- With an all-pass result the window is implausibly wide; the DTR heuristic distrusts it
  (run ≥ 6 ⇒ fall back to `default_config_id`) and selects id 5 = `{din_mode=4,…}`. That
  din_mode is wrong for the high-speed cache path, so **FIX 2 forces din_mode=1**.

**Why it's a no-op (not yet root-caused to the line):** the IDF tuning's `set_tuning_regs`
either isn't applying the per-config din values in our bare integration, or a precondition
it expects (the read path actually running at the high-speed, din-sensitive cache timing)
isn't met — the SPI1 manual-read path used for tuning is insensitive to din here, while the
SPI0 cache path is sensitive (that asymmetry is exactly why FIX 2 is needed). Either way the
calibration measures nothing. The working config is fixed by **(default + FIX 2)**, i.e. the
three constants `din_mode=1, din_num=0, extra_dummy=2` — not by any per-board tuning.

## Option B attempt (2026-06-24) — a measured cache-path din sweep

Implemented a from-scratch sweep in `psram_boot.c` (replacing FIX 2): write a reference
to a scratch PSRAM page, then for each of the 8 sampling modes set `SMEM_DIN_MODE`
(0x600030C0), re-read through the cache, and compare; pick the centre of the widest
passing run. Tested live on the Meshnology LoRa AIOT board. Outcome, in order of what we learned:

1. **The measurement works.** The sweep correctly finds the window: **modes 0 and 1 read
   back perfectly, mode 1 chosen as centre** — independently confirming FIX 2's mode 1 from
   data (passmask=0x03, best=1).
2. **A wrong cache-din HANGS the CPU.** A synchronous PSRAM load with a bad din never
   completes — the bus stalls, PC pins, `exccause=0`, uncatchable (no IRQ can preempt a
   stalled load). So you cannot naively "read and see if it's garbage".
3. **Async preload dodges the CPU hang but POISONS the controller.** Using
   `Cache_Start_DCache_Preload` + poll `Cache_DCache_Preload_Done` with a timeout +
   `Cache_End_DCache_Preload` lets the *sweep* complete (the CPU only polls a flag). But a
   stalled preload leaves the MSPI/cache controller wedged: afterwards normal cache reads
   return `0xbad00bad` (the cache fault-fill pattern) and **even `Cache_Disable_DCache`
   hangs**. Per-stall recovery (disable/remap/enable) can't recover — the disable itself
   hangs. Only an MSPI peripheral reset would clear it, and that also kills flash XIP.
4. **SPI1 can't substitute.** SPI1 has its *own* din registers (`0x600020xx`), separate
   from the cache controller's (`0x600030xx`) — confirmed live (SPI1 din=0 while cache
   din=mode1). A bounded SPI1 manual read calibrates the wrong register; it tells you
   nothing about the cache path's din.

**Conclusion: the cache-read din (`0x600030C0`) cannot be safely swept in software.** Any
probe of a bad value risks an unrecoverable controller wedge, and the only din-sensitive
path *is* the cache path. This is almost certainly why the IDF/blob leans on a default +
our FIX 2 hardcode rather than calibrating this register on the S3.

**Net:** FIX 2's mode 1 is now **measurement-confirmed** (modes 0,1 pass, mode 1 is the
window centre) — it is both correct and practically necessary. The achievable improvement
is *verification*, not adaptive calibration: a one-shot safe read at mode 1 after bring-up
to self-test PSRAM (mode 1 doesn't stall), turning the blind hardcode into a checked one.
A fully adaptive sweep is blocked by the hardware, not by effort.

### Verdict on Option B (port the IDF sweep) — superseded by the attempt above
Two readings, both important:
- **Porting the IDF sweep as-is: not worth it.** It would reproduce the same no-op (the bug
  is in the tuning↔integration interaction, not something a faithful port fixes) → same
  fallback → same registers → still needs FIX 2. More code, trickier (SPI1 octal-DDR manual
  transactions), zero added adaptivity.
- **Writing a *correct* sweep: would genuinely beat the IDF blob — but it's a real project.**
  A sweep that actually varies the SPI0 din regs and reads through the *cache* path (the one
  that matters) would pick the right din_mode (1) from data, **eliminate FIX 2**, and report
  true margin. That is a principled improvement over today's "fallback + hardcode" — but it
  means debugging why the din application is a no-op and validating the high-speed read path,
  not a mechanical port. Worth it only if 80 MHz adaptive robustness (temperature/board
  spread) is actually required; for a fixed board the constants are equivalent.

### "Do we get the same register values as the original code?"
Yes — and trivially so, because the values are fixed by (default config + FIX 2), not by a
real calibration. Any from-source bring-up that applies `{din_mode=1, din_num=0,
extra_dummy=2}` lands on byte-identical registers (`0x600030BC=0xB`, `0x600030C0=0x01249249`,
`0x600030C4=0`) and a working PSRAM. Temperature drift in the sweep is moot — the result is
already a temperature-independent constant.

## Recommendation (updated by the hardware test)

Implement **Option C**, now de-risked to near-certainty:
1. Readable Ada `s_init_psram` = the deterministic sequence (pins, CS timing 3/3/2, MR0
   write `lt=1/read_latency=2/drive=0`, connect probe `0x5a6b7c8d`, density decode, SPI0
   cache OPI-DDR phases) + the captured timing constants `din_mode=1, din_num=0,
   extra_dummy=2`. **No sweep.**
2. Retire `esp_psram_impl_octal.c.obj` + all four `mspi_timing_*.obj`. Keep
   `esp_rom_opiflash_pin_config` / `Cache_*` (ROM, not blobs) initially; de-ROM later.
3. Validate by diffing the new registers against this capture (must match exactly) and the
   PSRAM stress (`esp32s3_heaptest HEAP_PSRAM=1`).

Options A (40 MHz, fully deterministic) and B (port the sweep) remain documented above but
are not preferred: A halves bandwidth; B ports code that demonstrably does nothing here.

---

## Option C — STAGE 1 DONE (2026-06-24): four mspi_timing/gpio blobs retired

Replaced `mspi_timing_by_mspi_delay.c.obj`, `mspi_timing_config.c.obj`,
`mspi_timing_tuning.c.obj`, `gpio_periph.c.obj` with readable
`bootloader/mspi_timing_src.c` (~120 lines), providing exactly the 5 symbols the kept
`esp_psram_impl_octal.c.obj` imports from them:
- `GPIO_PIN_MUX_REG` — linear IO_MUX table (`0x60009004 + 4*n`).
- `mspi_timing_set_pin_drive_strength` — `FUN_DRV=3` on the 9 octal pads + SMEM clk drive.
- `mspi_timing_enter_low_speed_mode` — core 80 MHz, flash+PSRAM /4 (20 MHz), clear din.
- `mspi_timing_enter_high_speed_mode` — core 160 MHz, /2 (80 MHz), apply din=mode1, extra_dummy=2.
- `mspi_timing_psram_tuning` — **empty** (the sweep is the proven no-op).

Values from the live golden state + the blobs' own divider math:
`clkdiv = (N<<16)|(H<<8)|L`, N=L=div-1, H=div/2-1 → div4=`0x00030103`, div2=`0x00010001`;
single core-clk-sel `0x600030EC` (0=80 MHz, 2=160 MHz). The app build no longer links any
blob (`glue.c PSRAM_ENABLE=0`; it maps PSRAM via ROM `Cache_Dbus_MMU_Set` only).

**Validated (Meshnology LoRa AIOT board):** `octal PSRAM up rc=0 8 MB`; final regs byte-identical to golden
(din `0x01249249`, core `2`, clk `0x00010001`); `big.adb checksum=0x07f80000` deterministic
across 3 resets.

Gotchas fixed: `.data` must be 4-byte aligned in `boot.ld` (else ROM "Invalid image block");
the clk divider field order (N/L); a wrong low-speed clock hangs the ROM opiflash transaction
(diagnosed via the hung PC sitting in ROM near `esp_rom_opiflash_read_raw`).

**Remaining — STAGE 2:** retire `esp_psram_impl_octal.c.obj` (the chip-side MR programming via
ROM `esp_rom_opiflash_exec_cmd` + SPI0 cache-phase config). Higher risk: the ~13-arg
`exec_cmd` calls (MR0 write, `0x5a6b7c8d` connect probe, MR reads) must be exact; the
controller-side config can use the golden register values directly.

## Real 80 MHz din tune — FIX 2 RETIRED (2026-06-24)

We then replaced FIX 2's hardcoded `din_mode=1` with an actual per-board measurement.

**Why the IDF tuning fails (root cause, traced in v5.4.4 source):** `mspi_timing_psram_tuning`
drops the MSPI to **20 MHz** (`enter_low_speed_mode`) *before* the sweep and only restores
80 MHz *after* it. At 20 MHz the din sampling phase is irrelevant (huge eye), so all 14 table
configs read the reference back perfectly; the 160 MHz DTR selector treats an all-pass window
(`consecutive_length >= 6`) as "tuning fail" and returns `default_config_id = 5 = {din_mode=4,…}`
— which actually *fails* at 80 MHz. (Secondary: the sweep writes din to SPI0 but reads via a
SPI1 manual transaction.) So the "calibration" is a vendor-default lookup, and something must
override din_mode — that was FIX 2.

**The fix — `psram_tune_din()` in `psram_boot.c`:** sweep din at the real **80 MHz**, with the
readback over a **bounded SPI1 manual transaction** (`esp_rom_opiflash_exec_cmd`) so a wrong din
returns garbage instead of stalling the bus (the cache path stalls uncatchably — see the Option
B attempt). At 80 MHz this gives a real window. Measured live (and deterministic across resets):

```
mode 0,1 PASS | mode 2,3 fail (0x..76) | mode 4,5 fail (0x..e2) | mode 6,7 PASS   -> passmask 0xC3
```

The passing arc is circular `{6,7,0,1}`; we centre on it → **mode 0**, apply it to the SPI0
cache din, and the app `checksum=0x07f80000` validates it end-to-end. Notes:
- IDF's default (mode 4) sits dead-centre in the FAIL region — the 80 MHz tune correctly rejects
  what the 20 MHz tune hands back.
- FIX 2's mode 1 was a valid but *edge*-of-eye point; the measured centre (mode 0) has more margin.
- Falls back to mode 1 if the sweep is degenerate (empty or all-pass). din timing affects reads
  only and the bootloader runs from flash/IRAM, so retuning PSRAM din live is safe.

**Net:** the de-blobbed bring-up now does a genuine per-board din calibration with no magic
constant — strictly better than both the IDF blob (wrong default) and FIX 2 (edge point).

## Option C — STAGE 2 DONE (2026-06-24): the last blob retired, bring-up 100% from-source

Replaced `esp_psram_impl_octal.c.obj` with `bootloader/psram_impl_src.c`
(`psram_impl_enable_src` + `psram_impl_get_physical_size_src`). The chip-facing steps use
the ROM OPI helper exactly as the blob did; the controller config is written from the live
golden register state; clocks/din are `mspi_timing_src.c`:
- pins (IO_MUX CS `0x6000906c=0x00000f00`, SMEM clk drive `0x600033fc=0x0210105f`),
  CS timing (`0x600030dc=0x0400b18f`), ECC off (clear `0x60026058` bit 8).
- 20 MHz; SPI1 var-dummy (`0x600020e0|=2`) + `esp_rom_spi_set_dtr_swap_mode(1,0,0)`.
- **MR0** read-modify-write to `0x28` (lt=1, read_latency=2, drive_str=0) via
  `esp_rom_opiflash_exec_cmd(1, OPI_DTR=7, 0x4040 read / 0xC0C0 write, 16-bit cmd, 32-bit
  addr, CS=BIT(1))`.
- connect probe `0x5a6b7c8d` (write `0x8080` dummy 8, read `0x0000` dummy 18).
- 80 MHz; SPI0 cache phases (golden `SCTRL 0x01f7c479`, `SRAM_CMD 0x007c0000`,
  `DRD 0xf0000000`, `DWR 0xf0008080`, `SMEM_DDR 0x00003023`) + `Cache_Resume_DCache(0)`.
- size hardcoded 8 MB (the density read is elided; the connect probe proves presence).

Deleted `vendor_psram/` (all 5 blobs gone) and the now-dead leaf stubs in `psram_glue.c`.
**Validated (Meshnology LoRa AIOT board), 4/4 resets:** `octal PSRAM up rc=0 8 MB`, din tuned mode 0,
`checksum=0x07f80000`. The entire octal-PSRAM bring-up is now readable source + ROM calls.

## Cross-validated on a second board — genuine ESP32-S3-DevKitC (2026-06-24)

All of the above was developed on a **Meshnology LoRa AIOT board**. The finished
from-source bring-up was then run unchanged on a genuine **Espressif ESP32-S3-DevKitC**
(WROOM module). The bootloader now reads the device mode registers and reports what it
finds; on the DevKitC:

```
PSRAM: AP Memory octal DDR @80MHz, 64 Mbit (8 MB), dev gen 3, Vcc 3.0V
  latency: read 10-cyc (fixed), write 5-cyc;  MR0=28 MR1=0d MR2=93 MR3=60 MR4=40 MR8=05
octal PSRAM up: rc=0  8 MB
PSRAM din tuned @80MHz: passmask=0xc3 -> mode 0
checksum=0x07f80000      (deterministic across resets)
```

Same AP Memory 8 MB octal chip, and the per-board din tune **independently measured the
same window** (`0xc3` -> mode 0) — confirming it tracks a real, stable chip+controller
property, not a per-board fluke. The size is now decoded from the density mode-register
(no longer hardcoded), so the bring-up self-describes the part it finds (vendor, density,
voltage, read/write latency) and would adapt to a different-size octal PSRAM.
