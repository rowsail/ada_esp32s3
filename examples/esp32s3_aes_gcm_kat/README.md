# AES-GCM — authenticated encryption, known-answer test (ESP32-S3, no FreeRTOS)

Known-answer test for **`ESP32S3.AES.GCM`** (in `libs/esp32s3_hal`): AES-GCM
authenticated encryption driving the chip's **hardware AES block** for the block
cipher, with **GHASH and CTR in software**. Both AES-128 and AES-256 are
checked, and **no external hardware is involved** — the vectors are baked in.

```
[gcm] AES-GCM known-answer tests (HW AES block + SW GHASH/CTR)
[gcm] AES-128-GCM : PASS
[gcm] AES-256-GCM : PASS
[gcm] done
```

Both case lines must read `PASS`.

## What each case proves

A case is not a round trip. Encrypting and then decrypting your own output would
pass even if the implementation were consistently wrong, so each case checks
**against the vector in both directions**:

* **Encrypt** `Encrypt (Key, IV, AAD, P, ...)` must reproduce the expected
  ciphertext `C` **and** the expected 16-byte authentication tag `T`.
* **Decrypt** is fed the vector's own `C` and `T` — not the ciphertext just
  produced — and must both **authenticate** (`Ok` true) and recover the original
  plaintext `P`.

A line says `PASS` only when all four hold. Any mismatch prints `FAIL`.

The AAD (additional authenticated data) is covered by the tag but not encrypted,
which is what makes this AEAD rather than plain CTR: a tampered header is caught
even though it travels in clear.

## The vectors

Per case *N*: `KN` key, `IVN` nonce, `AN` AAD, `PN` plaintext, `CN` expected
ciphertext, `TN` expected tag.

They were generated with the Python **`cryptography`** library (`AESGCM`), which
produces `C` and `T` for a given `K`/`IV`/`A`/`P`. Re-run it on the `K`/`IV`/`A`/`P`
literals in `src/main.adb` to regenerate `C` and `T` and confirm them yourself.

## Using the driver

```ada
with ESP32S3.AES;     use ESP32S3.AES;
with ESP32S3.AES.GCM; use ESP32S3.AES.GCM;

Encrypt (Key, IV, AAD, Plain, Cipher, Tag);
Decrypt (Key, IV, AAD, Cipher, Tag, Plain_Out, Ok);
--  Ok is False when the tag does not authenticate.  Do not look at
--  Plain_Out in that case: it is unverified attacker-chosen data.
```

`Key` is a `Key_128` or `Key_256`, so a wrong-sized key is a compile-time error
rather than a silent fallback.

## Build & flash

```sh
./x run esp32s3_aes_gcm_kat          # build + flash + monitor
```

Built as the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`).
No wiring: the AES block is on-chip.
