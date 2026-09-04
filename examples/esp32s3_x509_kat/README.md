# X.509 — DER certificate parser, known-answer test (ESP32-S3, no FreeRTOS)

Known-answer test for **`X509.Parse`** (in `libs/esp32s3_hal`), the bounds-checked
DER walk that reads a certificate. It parses a known self-signed RSA-2048
certificate compiled into the image, checks each extracted field against values
precomputed on the host, and then feeds it **malformed and hostile input** to
confirm the parser rejects what it should. **No external hardware**: X509 is pure
byte handling with no chip dependency.

```
[x509] parse a self-signed RSA-2048 certificate
[x509] structure valid : PASS
[x509] serial : PASS
[x509] notAfter : PASS
[x509] notAfter UTC : PASS
[x509] RSA modulus : PASS
[x509] RSA exponent : PASS
[x509] reject 4-byte length overflow : PASS
[x509] unknown NON-critical extension accepted : PASS
[x509] unknown CRITICAL extension rejected : PASS
[x509] done
```

Every line must read `PASS`. If `structure valid` fails the per-field lines are
skipped — the certificate did not parse at all, so there are no fields to compare.

## What the checks cover

**The fields** — `serial`, `notAfter` and its tag, and the RSA public key's
`modulus` and `exponent`, each compared byte for byte against the host-computed
value. Recovering them exactly is what the rest of the stack depends on: the
modulus and exponent *are* the key a signature is verified under.

**`notAfter UTC`** checks the *tag*, not just the bytes. X.509 encodes times as
either `UTCTime` (two-digit year) or `GeneralizedTime` (four-digit), and reading
one as the other silently shifts an expiry by a century.

**`reject 4-byte length overflow`** — a DER length field that declares more bytes
than the buffer holds. This is the classic certificate-parser vulnerability: a
parser that trusts the declared length reads off the end of the certificate. The
expected result is a *rejection*.

**The two extension checks** are the X.509 criticality rule, and they must go
opposite ways. An unknown extension marked **non-critical** must be *accepted*
and ignored; an unknown extension marked **critical** must cause the certificate
to be *rejected*, because the issuer has said the certificate cannot be safely
used without understanding it. A parser that ignores criticality accepts
certificates it does not actually understand.

## Build & flash

```sh
./x run esp32s3_x509_kat             # build + flash + monitor
```

Runs under the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`).
No wiring.

## See also

`esp32s3_x509_verify` verifies the signature on a parsed certificate;
`esp32s3_x509_chain` walks a chain to a trust anchor; `esp32s3_x509_policy`
covers the name and usage constraints.
