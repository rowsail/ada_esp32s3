# RSA accelerator — modular exponentiation, known-answer test (ESP32-S3, no FreeRTOS)

Known-answer test for **`ESP32S3.RSA`** (in `libs/esp32s3_hal`), the driver for
the chip's hardware RSA/MPI unit. It runs `Z = X^Y mod M` — which *is* an RSA
signature verify — at 2048 bits against a fixed vector, and again at the engine's
maximum 4096 bits. **No external hardware**: the modexp engine is on-chip.

```
[rsa] ESP32-S3 RSA accelerator KAT (2048-bit, then 4096-bit)
[rsa] host-R2 : PASS
[rsa] soft-R2 : PASS
[rsa] 4096-bit: 12345**3 mod (2**4096 - 5)
[rsa] 4096-bit: PASS  (137 ms, includes software R^2)
[rsa] done
```

The millisecond figure is informational — it will differ on your board — and is
not a pass criterion. A `FAIL` means the hardware finished but the answer did not
match; `hardware did not complete (timeout)` means the accelerator never
signalled done inside the bounded wait, which is a hardware fault, not a wrong
answer.

## What each line proves

**`host-R2`** — the 2048-bit modexp `Z = X^65537 mod M` with the Montgomery
constant *R²* supplied by the host. This is exactly an RSA-2048 signature verify:
recovering the padded hash from a signature `X` under the public key `(M, e=65537)`.

**`soft-R2`** — the same exponentiation, but the driver computes *R²* itself in
software from `M`. This is the path that matters in practice, because a modulus
that arrives at run time — out of an X.509 certificate, say — comes with no
precomputed constant. Both lines must produce the *same* answer, which also
cross-checks that the `R2` literal in the source is the right constant for `M`.

**`4096-bit`** — the widest operand the engine supports. The answer needs no
vector: `12345³` is vastly smaller than `2⁴⁰⁹⁶ − 5`, so the modular reduction is
the identity and the result must be exactly the cube in its low 64 bits with
every other limb zero. That makes the widest path checkable without carrying a
4096-bit literal in the source, and it necessarily exercises the software-*R²*
route (nothing supplies a constant for that modulus).

## The vectors

Every operand is a 64-word little-endian limb array (2048 bits):

| name | meaning |
|---|---|
| `M_Mod` | the RSA public modulus *N* — odd, as every RSA modulus is |
| `X_Base` | the base: the signature value being exponentiated |
| `Y_Exp` | the public exponent *e* = 65537, the conventional RSA "F4" |
| `R2` | *R² mod M* with *R* = 2²⁰⁴⁸ — an optimisation input, recomputable from `M` |
| `Z_Want` | the expected result *X^Y mod M* |

They were computed on the host (Python/OpenSSL bignum) for a fixed RSA-2048 key.
No generator script is committed, so they are carried as literals — but the
`soft-R2` line recomputes `R2` from `M` on-chip independently, so a wrong `R2`
would show up as the two lines disagreeing.

## Using the driver

```ada
with ESP32S3.RSA; use ESP32S3.RSA;

Mod_Exp (X => Base, Y => Exponent, M => Modulus, Z => Result, Ok => Ok);
--  Ok is False only if the engine never signalled completion.  Operands are
--  little-endian Word_Array limbs, all the same length; the modulus must be odd.
--  Pass R2 to skip the software Montgomery-constant computation.
```

## Build & flash

```sh
./x run esp32s3_rsa_kat              # build + flash + monitor
```

Built as the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`).
No wiring.
