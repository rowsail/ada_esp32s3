# SPARK proof surface

Formal proof (SPARK / GNATprove) of the **pure, bounded** HAL units — the
parsers, serializers, and checksums that handle untrusted or integrity-critical
data. This is the payoff surface for formal methods: proving *absence of
run-time errors* (no overflow, no buffer overrun, no division by zero, all loops
terminate) on the code most exposed to malformed input.

## Run it

```sh
book/prove/prove.sh        # gnatprove --level=2 (silver) over the SPARK_Mode => On units
```

Exits non-zero if any run-time check is unproved. `gnatprove` ships with the
Alire toolchain (`~/.alire/bin/gnatprove`).

## Proven so far (silver — 0 unproved checks)

| Unit | What | Project |
|------|------|---------|
| `ESP32S3.Ext4` | `Get_*`/`Put_*` byte serialization helpers | `ext4_host.gpr` |
| `ESP32S3.Ext4.CRC32C` | ext4 metadata checksum (Castagnoli) | `ext4_host.gpr` |
| `ESP32S3.Ext4.Superblock` | superblock `Encode` + queries (I/O ops `Off`) | `ext4_host.gpr` |
| `ESP32S3.Ext4.Inode` | inode `Decode`/`Encode` + queries (I/O ops `Off`) | `ext4_host.gpr` |
| `ESP32S3.Ext4.Group_Desc` | group-descriptor `Decode`/`Encode` (I/O ops `Off`) | `ext4_host.gpr` |
| `Modbus` | Modbus-TCP wire framing (MBAP + U16 pack/unpack) | `modbus_slave_host.gpr` |
| `ESP32S3.Endian` | LE/BE byte join/split primitives | `endian_host.gpr` |
| `X509.DER` | DER TLV reader — **untrusted certificate input** | `x509_prove.gpr` |

`X509.DER.Read` is the highest-value proof here: it parses attacker-controlled
certificate bytes, and proving it silver means **no buffer overrun on any malformed
or malicious DER** — a real security property, not just a crash guard. (It needed the
same constrained-index fix: `X509.Byte_Array` capped at 16 MiB so cursor arithmetic
provably cannot overflow while walking untrusted lengths.)

Two latent bugs found by proving these: the `Put_MBAP` overflow (above), and
`Superblock.Encode` checksumming an *absolute* `Buf (Base .. Base + …)` slice where
the writers use `Buf'First + offset` — wrong for a non-zero-based buffer, now
`Buf'First`-relative.

Proving `Modbus` already paid for itself: GNATprove found that `Put_MBAP` could
overflow on `PDU_Len + 1` for an unbounded `PDU_Len`, which drove the
precondition `PDU_Len <= Max_PDU` (the real protocol cap of 253 bytes).

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

## Remaining ext4 (next passes)

`dir` (variable-length directory entries — record iteration, not a fixed serializer),
`block_map`/`file` (extent + indirect-block math over I/O), and `bitmap` are the next
targets — larger because their logic interleaves with I/O and variable-length walking
rather than a straight fixed-offset record. Same factoring pattern, more per unit.

## Crypto / TLS (scouted; expensive, not done)

`libs/tls/p256.Verify` (ECDSA-P256 signature check) is SPARK-legal and gnatprove runs
against the *cross* `tls.gpr` directly (target setup works) — but proving it pulls in
the whole vendored **SPARKNaCl** elliptic-curve contract closure and did not converge in
200 s. Two gotchas noted for a dedicated pass: SPARK forbids `out` parameters on
functions (`Public_Key`/`ECDH`/`Sign` must be `SPARK_Mode => Off` or become procedures),
and the proof needs SPARKNaCl's lemmas to line up. High-value but a real time budget,
not a quick add. `cert_verify`'s RSA path is hardware (ESP32-S3 RSA accelerator) → `Off`.

The HAL-wide `Pre`/`Post` contracts (see the driver specs) use the same syntax
SPARK consumes, so they are the foundation this proof surface builds on.
