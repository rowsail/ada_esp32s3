# X.509 — certificate signature verification (ESP32-S3, no FreeRTOS)

End-to-end verification of an X.509 signature as a known-answer test. It parses a
self-signed RSA-2048 certificate, SHA-256s the TBS (to-be-signed) region,
RSA-recovers the PKCS#1 block using the certificate's **own** public key, and
compares. Then it does the same to a copy with one signed byte flipped, which
must be **rejected**. **No external hardware**: the certificate is a compiled-in
vector and the RSA math runs on the on-chip accelerator.

```
[verify] self-signed RSA-2048 certificate signature
[verify] signature valid : PASS
[verify] tampered rejected : PASS
[verify] done
```

Both check lines must read `PASS`. `[verify] parse failed` replaces them only if
the bundled DER does not parse, which it should — the bytes are a fixed vector.

## Why a self-signed certificate

A self-signed certificate is signed by the key it carries, so the test needs no
external trust anchor and still exercises the entire path in one shot:

* the **DER parser** (`X509.Parse`) to find the TBS region, the signature, and
  the public key;
* **SPARKNaCl's SHA-256** to digest the TBS bytes;
* the **hardware RSA accelerator** (`ESP32S3.RSA.Mod_Exp`) to recover the PKCS#1
  block from the signature under *(N, e)*;
* the PKCS#1 v1.5 unpadding and digest comparison.

A `PASS` on the first line means all four agreed.

## Why the tampered case matters more

The second line is the one that has teeth. A verifier that returns `True`
unconditionally passes the first check and fails nothing else in the suite — and
would accept every forged certificate on the internet. Flipping a byte inside the
signed region changes the digest, so the recovered PKCS#1 block can no longer
match, and `tampered rejected : PASS` is the evidence that the comparison is real.

## Build & flash

```sh
./x run esp32s3_x509_verify          # build + flash + monitor
```

Needs the **embedded** profile; `build.sh` sets `ESP32S3_RTS_PROFILE=embedded`.
No wiring.

## See also

`esp32s3_x509_kat` covers the parser itself; `esp32s3_x509_chain` verifies a real
chain up to a trust anchor rather than a single self-signed certificate.
