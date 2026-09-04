# X.509 — certificate-chain validation (ESP32-S3, no FreeRTOS)

Exercises **`Chain_Verify.Validate`** (in `libs/tls`): the trust *policy* layered
on top of the signature crypto. Each case feeds the validator an ordered chain
(leaf first), a set of pinned trust anchors, a host name and a wall-clock time,
and asserts the verdict. Between them the cases reach **every distinct `Result`
the validator can return**. **No external hardware** — the certificates are
embedded.

```
[chain] certificate-chain validation (leaf <- CA, pinned root)
[chain] leaf+CA, pinned CA : PASS
[chain] leaf only, anchor CA : PASS
[chain] wrong hostname : PASS
[chain] expired (2050) : PASS
[chain] broken link : PASS
[chain] untrusted root : PASS
[chain] non-CA issuer : PASS
[chain] leaf EKU clientAuth : PASS
[chain] Ed25519 chain : PASS
[chain] RSA-SHA384 chain : PASS
[chain] RSA-SHA512 chain : PASS
[chain] done
```

Every line must read `PASS`, which means **the verdict matched the one expected
for that case** — not that the chain was accepted. Most of these cases expect a
*rejection*. A mismatch prints `FAIL (<actual Result>)` so you can see what the
validator said instead. The board then idles.

## The cases

| case | expected verdict | what it pins down |
|---|---|---|
| `leaf+CA, pinned CA` | `Valid` | the happy path: a leaf signed by a CA that is pinned |
| `leaf only, anchor CA` | `Valid` | the server need not send the root; anchoring the leaf directly to its pinned issuer works |
| `wrong hostname` | `Name_Mismatch` | a cryptographically perfect chain for *someone else's* name is not a valid chain for yours |
| `expired (2050)` | `Expired` | evaluation outside the validity window, using the caller's clock |
| `broken link` | `Bad_Signature` | a forged link — the leaf presented as its own issuer |
| `untrusted root` | `Untrusted_Root` | the chain verifies internally but ends somewhere not pinned |
| `non-CA issuer` | `Not_A_CA` | the issuer's signature verifies, but its `basicConstraints` says `cA=FALSE` |
| `leaf EKU clientAuth` | `Bad_Key_Usage` | the leaf's `extKeyUsage` permits only client authentication, so it may not be a server |
| `Ed25519 chain` | `Valid` | the same policy over an Ed25519 chain |
| `RSA-SHA384 chain` | `Valid` | RSA with SHA-384 links |
| `RSA-SHA512 chain` | `Valid` | RSA with SHA-512 links |

The last three matter because the default fixtures are RSA-with-SHA-256; a
validator that only ever sees one signature algorithm can hard-code it without
anyone noticing.

`non-CA issuer` and `leaf EKU clientAuth` are the two that separate a real
validator from a signature checker. In both, every signature in the chain
verifies — the certificate is rejected because of what it *says about itself*.

## Build & flash

```sh
./x run esp32s3_x509_chain           # build + flash + monitor
```

Runs under the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`).
No wiring.

## See also

`esp32s3_x509_policy` isolates the validity-window and hostname checks;
`esp32s3_tls_weather` runs this validator against a real server's real chain, up
to the real ISRG Root X1.
