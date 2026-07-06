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
| `ESP32S3.Ext4.CRC32C` | ext4 metadata checksum (Castagnoli) | `ext4_host.gpr` |
| `Modbus` | Modbus-TCP wire framing (MBAP + U16 pack/unpack) | `modbus_slave_host.gpr` |

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

The HAL-wide `Pre`/`Post` contracts (see the driver specs) use the same syntax
SPARK consumes, so they are the foundation this proof surface builds on.
