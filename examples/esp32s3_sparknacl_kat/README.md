# SPARKNaCl — formally-verified crypto on the S3, known-answer test (no FreeRTOS)

Runs the vendored, **formally-verified SPARKNaCl** primitives (`crates/sparknacl`)
on this target and checks each against a published vector. It is the foundation
result for the pure-Ada TLS stack: proven-correct code is only useful if it also
computes correct answers *on this chip*, with this compiler, at this word size.
**No external hardware** — the vectors are compiled in and the RNG is on-chip.

```
[kat] SPARKNaCl known-answer tests (pure Ada/SPARK on the S3)
[kat] SHA-256(abc)   : PASS
[kat] X25519 RFC7748 : PASS
[kat] RNG (entropy on): 3f8a1c04 9b2e77d1 c05a4e63
[kat] done
```

Both check lines must read `PASS`. The three RNG words **differ on every run and
from each other** — that is the point of printing them.

## What each line proves

**`SHA-256(abc)`** — `SPARKNaCl.Hashing.SHA256` against the canonical
`SHA-256("abc")` digest. The hash under TLS 1.3's transcript and key schedule.

**`X25519 RFC7748`** — `SPARKNaCl.Scalar.Mult`, Curve25519 scalar multiplication,
against the vector from **RFC 7748 §5.2**. This is the ECDHE key agreement the
TLS client's default `x25519` group depends on.

**`RNG (entropy on)`** — three words from `ESP32S3.RNG` after
`Enable_Entropy_Source`. Not a known-answer test (there is no expected value for
a random number); it is a liveness check. Three *identical* words, or the same
three across reboots, would mean the entropy source is not running — and a
CSPRNG that is stuck is a silent, total failure of every key it produces.

## Build & flash

```sh
./x run esp32s3_sparknacl_kat        # build + flash + monitor
```

Needs the **embedded** profile, not the default light-tasking; `build.sh` sets
`ESP32S3_RTS_PROFILE=embedded`. No wiring.

## See also

`esp32s3_p256_kat` covers the other curve (P-256, this repo's own
implementation); `esp32s3_tls_weather` uses both to complete a real handshake.
