# X.509 — validity window and hostname (SAN) matching (ESP32-S3, no FreeRTOS)

The two policy checks the TLS client applies to a parsed leaf certificate,
isolated on one embedded test certificate — **no chain and no signature crypto
here**, so a failure points at the policy rather than at the maths. **No external
hardware**: the certificate is compiled in.

```
[pol] X.509 validity + hostname (SAN) checks
[pol] parsed : PASS
[pol] SAN count = 2 : PASS
[pol] valid now (2025) : PASS
[pol] expired (2050) : PASS
[pol] not yet (2019) : PASS
[pol] exact match : PASS
[pol] case-insensitive : PASS
[pol] wrong host : PASS
[pol] wildcard match : PASS
[pol] wildcard no-label : PASS
[pol] wildcard 1 label : PASS
[pol] done
```

Every line must read `PASS` — meaning the check returned **what was expected**,
which for several cases is a rejection. The board then idles.

## Validity window

`notBefore <= now <= notAfter`, where **`now` is supplied by the caller** — from
NTP, an RTC, whatever the device trusts — rather than taken from the certificate.
That is the whole point: a device with no clock cannot tell an expired
certificate from a current one, so freshness has to be the device's decision.

The three cases cover in-window (`valid now (2025)`), past the window
(`expired (2050)`), and before it (`not yet (2019)`). The last one is easy to
forget and matters on a board whose clock has not been set yet: a device that
believes it is 1970 must not accept certificates on the grounds that they are not
expired.

## Hostname matching

Does a requested host match a `subjectAltName` **dNSName**, per RFC 6125?

| case | expects | why |
|---|---|---|
| `exact match` | accept | the baseline |
| `case-insensitive` | accept | DNS names are case-insensitive; `EXAMPLE.com` matches `example.com` |
| `wrong host` | **reject** | the check does something |
| `wildcard match` | accept | a single leftmost `*` label, e.g. `*.example.com` matching `api.example.com` |
| `wildcard no-label` | **reject** | `*.example.com` must not match bare `example.com` — there is no label to consume |
| `wildcard 1 label` | **reject** | `*` covers **one** label, so `*.example.com` must not match `a.b.example.com` |

The two wildcard rejections are the ones with security weight. A wildcard that
spans multiple labels turns one certificate into a wildcard for a whole subtree,
so `*.example.com` matching `evil.attacker.example.com` would be a real
compromise.

`SAN count = 2` confirms the parser found both names in the certificate — a
matcher that only ever examines the first entry would pass the exact-match case
and quietly fail everything else.

## Build & flash

```sh
./x run esp32s3_x509_policy          # build + flash + monitor
```

Runs under the **embedded** profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`).
No wiring.

## See also

`esp32s3_x509_chain` applies these checks as part of full chain validation;
`esp32s3_x509_kat` covers the DER parser underneath them.
