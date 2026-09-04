# P-256 — pure-Ada ECDSA and ECDH, known-answer test (ESP32-S3, no FreeRTOS)

Known-answer test for **`P256`** (in `libs/tls`), the pure-Ada secp256r1
implementation that authenticates ECDSA certificates and performs ECDHE key
agreement in this repo's TLS 1.3 client. **No hardware acceleration and no C** —
the S3 has no ECC engine, so this is Ada field arithmetic — and **no external
wiring**; the vectors are baked in.

```
[p256] ECDSA P-256 verify KAT
[p256] genuine signature  -> VALID (PASS)
[p256] tampered hash      -> INVALID (PASS)
[p256] deterministic sign -> MATCH (PASS)
[p256] ECDH public key    -> MATCH (PASS)
[p256] ECDH shared secret -> MATCH (PASS)
[p256] result: ALL PASS
```

**Read the parenthesis, not the word before it.** `INVALID (PASS)` on the
tampered line is the correct result: the verifier was *supposed* to reject that
signature. Every line ends in `(PASS)` on a good run, and the last line reads
`ALL PASS`.

## What each line proves

**`genuine signature`** — `P256.Verify` accepts a real signature over a real
digest under the matching public key. The baseline: the verifier works at all.

**`tampered hash`** — one bit of the digest is flipped and the *same* signature
is offered again. A verifier that accepts is worse than useless, so this is the
line that distinguishes a working verifier from one that returns `True`
unconditionally. Its expected outcome is `INVALID`.

**`deterministic sign`** — `P256.Sign` must reproduce the **RFC 6979**
deterministic signature for a known key and digest *bit for bit*. Determinism is
what makes signing testable: an ECDSA signature with a random nonce differs every
time and can only be checked by verifying it, which would not catch a biased
nonce generator. RFC 6979 derives the nonce from the key and message, so there is
exactly one correct answer.

**`ECDH public key`** — `P256.Public_Key` reproduces the published public point
for a known private scalar (scalar multiplication of the base point).

**`ECDH shared secret`** — `P256.ECDH` reproduces the known shared secret against
a known peer public key. Both sides deriving the same X-coordinate is the
standard ECDH cross-check.

## The vectors

All values are 32-byte big-endian field or scalar values:

| name | meaning |
|---|---|
| `Qx`, `Qy` | the signer's public key (the point *Q = d·G*) |
| `Hash` | the SHA-256 digest that was signed |
| `R`, `S` | the ECDSA signature pair over `Hash` |
| `D` | our ECDH private scalar |
| `MyX`, `MyY` | our public key (*D·G*) — the expected `Public_Key` output |
| `PeerX`, `PeerY` | the peer's public key point |
| `Shared` | the expected ECDH shared secret (X-coordinate of *D·Peer*) |

The ECDSA key, hash and signature came from OpenSSL (`openssl ecparam -name
prime256v1`, then `openssl dgst -sha256 -sign`) and were confirmed with
`openssl dgst -verify`. The ECDH pairs and shared secret likewise came from
OpenSSL (two `prime256v1` keys plus `openssl pkeyutl -derive`).

## Build & flash

```sh
./x run esp32s3_p256_kat             # build + flash + monitor
```

Built as the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`).
No wiring — everything is baked-in test data.

## See also

`esp32s3_x509_verify` and `esp32s3_tls_weather` put these primitives to work:
authenticating a real server certificate and completing a real TLS 1.3 handshake.
