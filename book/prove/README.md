# SPARK proof surface

Formal proof (SPARK / GNATprove) of the **pure, bounded** HAL units — the
parsers, serializers, and checksums that handle untrusted or integrity-critical
data. This is the payoff surface for formal methods: proving *absence of
run-time errors* (no overflow, no buffer overrun, no division by zero, all loops
terminate) on the code most exposed to malformed input.

## Run it

```sh
book/prove/prove.sh        # gnatprove --level=1 (silver) over the SPARK_Mode => On units
```

Exits non-zero if any run-time check is unproved. `gnatprove` ships with the
Alire toolchain (`~/.alire/bin/gnatprove`).

## Proven so far (silver — 0 unproved checks)

| Unit | What | Project |
|------|------|---------|
| `ESP32S3.Ext4` | `Get_*`/`Put_*` byte serialization helpers | `ext4_host.gpr` |
| `ESP32S3.Ext4.CRC32C` | ext4 metadata checksum (Castagnoli) | `ext4_host.gpr` |
| `ESP32S3.Ext4.Superblock` | superblock `Encode` + queries | `ext4_host.gpr` |
| `ESP32S3.Ext4.Inode` | inode `Decode`/`Encode` + queries | `ext4_host.gpr` |
| `ESP32S3.Ext4.Group_Desc` | group-descriptor `Decode`/`Encode` | `ext4_host.gpr` |
| `ESP32S3.Ext4.Bitmap` | bit set/clear/test math | `ext4_host.gpr` |
| `ESP32S3.Ext4.Block_Map` | direct/indirect + extent-node decode/validate | `ext4_host.gpr` |
| `ESP32S3.Ext4.Dir` | dir-entry header decode + name copy | `ext4_host.gpr` |
| `ESP32S3.Ext4.File` | EOF-clamped read/chunk size math | `ext4_host.gpr` |
| `ESP32S3.Ext4.Mkfs.Math` | mkfs single-group layout: inode count / table size / block positions bounded + consistent | `mkfs_math_prove.gpr` |
| `ESP32S3.Ext4.Path_Scan` | `/`-separated path-component scanner (untrusted input): never slices outside the string | `path_scan_prove.gpr` |
| `X509.DER` + `X509` | DER TLV reader **and the certificate parser** — **untrusted input** | `x509_prove.gpr` |
| `ESP32S3.GPS.NMEA` | NMEA-0183 GPS-sentence parser — **untrusted input** | `nmea_prove.gpr` |
| `DNS_Client.Parse` | DNS response parser incl. name-compression — **untrusted input** | `dns_prove.gpr` |
| `Chain_Verify` | cert chain-walking (sig checks `Off`) — **untrusted input** | `tls.gpr` (cross) |
| `Modbus` / `.Slave` / `.Master` | wire framing, slave `Process` dispatch, master PDU build/parse | `modbus_*_host.gpr` |
| `NTP_Client.To_UTC` | SNTP → UTC civil-date math | `ntp_prove.gpr` |
| `Net_Routes` | IPv4 longest-prefix-match routing | `net_routes_prove.gpr` |
| `ESP32S3.AES.GCM` | GHASH GF(2^128) multiply + CTR increment (block cipher HW `Off`) | `aes_gcm_prove.gpr` |
| `ESP32S3.SHT41` | CRC-8 + datasheet integer conversions | `sht41_prove.gpr` |
| `ESP32S3.SD_SPI` | CRC-7 command-frame checksum | `sd_spi_prove.gpr` |
| `ESP32S3.PCF85063A` | RTC packed BCD ↔ binary conversions | `pcf85063a_prove.gpr` |
| `ESP32S3.QMI8658C` | IMU sign-extension + sensitivity scaling | `qmi8658c_prove.gpr` |
| `ESP32S3.TLV2556` | ADC count → millivolts | `tlv2556_prove.gpr` |
| `ESP32S3.ES8311` | codec volume % → DAC register | `es8311_prove.gpr` |
| `ESP32S3.TWAI.Math` | CAN baud-rate prescaler / bit-timing | `twai_math_prove.gpr` |
| `ESP32S3.LEDC.Math` | LED-PWM clock divider (Q10.8) + Float duty scaling | `ledc_math_prove.gpr` |
| `ESP32S3.RMT.Math` | RMT tick divider | `rmt_math_prove.gpr` |
| `ESP32S3.MCPWM.Math` | motor-PWM period / prescale / dead-time + Float duty scaling | `mcpwm_math_prove.gpr` |
| `ESP32S3.Endian` | LE/BE byte join/split primitives | `endian_host.gpr` |

The last two groups are *pure math from hardware drivers*: the SHT41/SD_SPI/RTC/IMU/ADC/codec
helpers are marked `SPARK_Mode => On` in place (MMIO code stays unmarked); the TWAI/LEDC/RMT/MCPWM
timing arithmetic was **extracted** into pure `*.Math` sibling packages (behaviour-neutral — exact
expressions relocated, register writes untouched) so it could be proved in isolation.

**~740 run-time checks discharged, 0 unproved.** The **untrusted-input parsers** are the
highest-value proofs — `X509` (certificates), `NMEA` (GPS sentences), `DNS` (resolver
replies, incl. self-referential name-compression pointers), `Chain_Verify` (cert chains),
and the `Modbus` slave/master (peer PDUs) all now provably have **no buffer overrun,
overflow, or infinite loop on any malformed or malicious input** — a real security
property rather than a crash guard.

### Bugs / hardening found by proving

- `Put_MBAP` could overflow on `PDU_Len + 1` (unbounded `PDU_Len`) → drove
  `Pre => PDU_Len <= Max_PDU` (the 253-byte protocol cap).
- `Superblock.Encode` checksummed an *absolute* `Buf (Base .. Base + …)` slice where the
  writers use `Buf'First + offset` — wrong for a non-zero-based buffer; now `Buf'First`-relative.
- `X509.Host_Matches`/`Name_Matches` could index out of range on a hostile `Certificate`
  whose SAN slices don't match the buffer or whose `SAN_Count > Max_SAN` — now guarded.
- `Chain_Verify.Validate` dereferenced `Chain(I).Data.all` with no null/empty guard — a
  caller-supplied chain with a null or zero-length cert `Data` would crash; now treated as
  `Malformed`.
- `SHT41.CRC_Good`'s `while I + 2 <= Data'Last` overflowed in the guard and underflowed on
  an empty buffer — rewritten as a group-count loop.

Five real defects surfaced by proving — all on the untrusted-input / malformed-input paths.

## Adding a unit

1. Put `with SPARK_Mode => On` on the package spec **and** body.
2. Ensure a native host project in `libs/esp32s3_hal/test/` compiles it (the
   proof runs there, avoiding cross-target/RTS setup).
3. `book/prove/prove.sh` and triage: strengthen preconditions (as with
   `Put_MBAP`) or add loop invariants until 0 unproved.

## Not SPARK (stays `SPARK_Mode => Off` / unmarked)

The driver, DMA, session, and register layers are **out of the SPARK subset** by
construction and are excluded, not "not yet done":

- **Controlled types** — the RAII `Session`/`Finalize` bus pattern (spi/i2c/uart/i2s).
- **Access-to-subprogram callbacks** — interrupt handlers, hooks, dispatching drivers.
- **Volatile memory-mapped registers** and machine-code/intrinsics (cache ops, SIMD).
- **I/O + dynamic memory** — e.g. `Block_Cache`/`Block_Dev` (`Unchecked_Deallocation`,
  `Device_Error`), which is why the ext4 *serializers* above `crc32c` need SPARK_Mode
  boundaries drawn around their I/O before they can be proven — a larger, separate effort.

## The constrained-index refactor (done)

The enabler for all the ext4 proofs: `ESP32S3.Ext4.Byte_Array` was
`array (Natural range <>)`, so its `'Length` could be 2**31 and overflowed `Integer` —
SPARK could not discharge an `Off + N <= B'Length` precondition. Capping the index
(`subtype Buffer_Index is Natural range 0 .. 2**24 - 1`; ext4 works one block at a time,
16 MiB is far above any real buffer) makes `'Length` provably fit an `Integer`, so the
clean `Off <= B'Length - N` preconditions on `Get_*`/`Put_*` discharge. The change is
source-compatible (whole HAL compiles; ext4 host harness e2fsck-CLEAN unchanged).

## The factoring pattern (applied to superblock / inode / group_desc)

Each fixed-layout metadata serializer had its buffer<->record step embedded *inside* an
I/O op (`Read`/`Write` over `Block_Cache`). The pattern that proves them:

1. Extract a pure `Decode (Raw) return Info` and `Encode (Info, Raw)` (offset-bounded
   `Pre => Raw'Length >= N`) from the I/O op; the op then just does I/O + calls them.
2. Mark the package `SPARK_Mode => On`, and the ops that take `Volume.Context` /
   `Block_Dev.Device` or `raise` (`Read`/`Write`/`Locate`/`Verify_Csum` …)
   `SPARK_Mode => Off`.
3. Nested closure helpers over the buffer (group_desc's `Ptr`/`Cnt`) need their own
   offset `Pre` too.

This is behaviour-neutral (ext4 host harness e2fsck-CLEAN throughout) and found a real
bug in `superblock` (the absolute-vs-`Buf'First` CRC slice).

## GNATprove / GNAT-15 gotchas (learned the hard way)

- **Unbounded `'Length` overflow** — an `array (Natural range <>)` byte buffer has `'Length`
  up to 2**31, which overflows `Integer`, defeating `Off + N <= B'Length`. Fix: constrain the
  index subtype (`0 .. 2**24 - 1`) — applied to `ESP32S3.Ext4.Byte_Array` and `X509.Byte_Array`.
  Where you can't edit the array's package (Modbus), pin the buffer to exact bounds at the
  proof boundary instead.
- Write offset preconditions as `Off <= B'Length - N`, **never** `Off + N <= B'Length` (the
  addition itself can overflow).
- A **function with `out`/`in out` params is not legal SPARK** — convert to a procedure, or give
  it an explicit declaration carrying `SPARK_Mode => Off` (a body-only `Off` is *not* honored for
  the profile-legality check inside an `On` package).
- **`SPARK_Mode => Off` conflicts with a `Post` aspect** on a spec in an `On` package — use spec-On
  + body-`Off` for those, or mark only the pure helpers `On` and leave the package unmarked.
- An **expression function's** aspect goes *after* the `is (...)`.
- Provers stall on nonlinear ops: replace `2 ** k` with `Shift_Left (1, k)` and variable-exponent
  `10 ** p` with a closed-form `case` function.
- SPARK forbids renaming a slice with **variable** bounds — bind the bounds as `constant`s first.
- **`Float`→integer conversion of a nonlinear product** (e.g. `Natural (Float (Max) * Percent /
  100.0)` in `Set_Duty`): the SMT solvers derive *neither* conversion bound from the product, will
  not carry a *variable* `Float (Max)` bound through the conversion, and will not rule out a NaN.
  Fix: bind the product to a local `Raw : Float`, then convert only inside a two-sided guard
  against **static literal** bounds — `if Raw >= 0.0 and then Raw <= 16_384.0 then Natural (Raw)`.
  The guard supplies both bounds directly and, since every comparison is False for NaN, excludes
  NaN too; it holds for every legal input, so the saturating `else` is dead code (behaviour-neutral).

## The boundary — what is left, and why it is out of reach

The proof surface now covers **all the pure, separable logic in the HAL** — every fixed-offset
serializer, untrusted-input parser, checksum, and conversion, plus the timing/PWM arithmetic that
was extractable. What remains is genuinely out of reach:

- **Would need extraction, deferred** — ext4 `journal`/`block_dev` wear-levelling bury their logic
  in access-type buffers + `Unchecked_Deallocation` + variable-length replay. (The
  `twai`/`ledc`/`rmt`/`mcpwm` integer timing math, the `ledc`/`mcpwm` `Set_Duty` Float duty scaling,
  and the `mkfs` single-group layout geometry were all extracted into `*.Math` siblings and proved —
  see the table. `mkfs`'s remaining code is the block-buffer serialization + I/O, which stays `Off`.)
- **Out of the subset by construction** — the register/MMIO drivers (SPI/I2C/UART/I2S/GDMA/GPIO…,
  volatile), the hardware crypto accelerators (SHA/AES-ECB/RSA), controlled-type bus sessions
  (`Finalize`), access-to-subprogram callbacks, `fonts` (`Unchecked_Conversion` to access),
  `mac` (needs the EFUSE register layer), `stack_usage` (`System.Address` ordering).
- **Partially proved — `p256` field/point arithmetic done, `Verify`/`On_Curve` deferred.** The
  P-256 primitives (modular add/sub, Montgomery multiply/inverse, Jacobian double/add, scalar-mul,
  byte conversions) are `SPARK_Mode => On` and prove silver (0 unproved run-time checks, via the
  cross `tls.gpr`). `Verify`/`On_Curve` — and the `out`-parameter `Public_Key`/`ECDH`/`Sign` plus
  the SPARKNaCl hashing glue — carry `SPARK_Mode => Off`: see the Crypto / TLS note below.

## Crypto / TLS

`libs/tls/p256` is `SPARK_Mode => On` and its P-256 **field and point arithmetic proves silver**
(0 unproved run-time checks) against the *cross* `tls.gpr` — the modular/Montgomery field ops,
Jacobian point double/add, scalar multiply, and the big-endian byte conversions can raise no
run-time error. What stays `Off`, and why:
- `Verify` / `On_Curve` — each chains dozens of `Mont_Mul`/`FMul`/point calls. The primitives are
  proved individually, but proving the *composition* needs postcondition contracts on them so the
  prover reasons from contracts instead of inlining the nonlinear modular arithmetic (otherwise it
  does not converge). That is a dedicated lemma-level effort — deferred, not a harvest.
- `Public_Key`/`ECDH`/`Sign` — SPARK forbids `out` parameters on *functions*, so these must be
  `Off` (or become procedures); `Sign` also uses the SPARKNaCl HMAC/SHA-256 hashing glue.
- `cert_verify`'s RSA path is hardware (ESP32-S3 RSA accelerator) → `Off`.

To re-check: `gnatprove -P libs/tls/tls.gpr --level=2 --prover=z3,cvc5,altergo -j0 -u p256.adb`.

The HAL-wide `Pre`/`Post` contracts (see the driver specs) use the same syntax
SPARK consumes, so they are the foundation this proof surface builds on.
