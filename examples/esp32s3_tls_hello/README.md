# Pure-Ada TLS 1.3 — handshake walkthrough (ESP32-S3, no FreeRTOS)

A complete TLS 1.3 client handshake done entirely in Ada — **no external C TLS
library** — against a TLS server on your own LAN, printing the intermediate state
as it goes. This is the diagnostic sibling of `esp32s3_tls_weather`: same client,
same crypto, but a server you control and far more visible working.

The full flight runs: **X25519 ECDHE** → **HKDF key schedule** → **AES-128-GCM**
record protection → server **CertificateVerify** (RSA-PSS) and **Finished** → our
own client Finished → chain validation to a pinned root → an encrypted HTTP GET
and the decrypted response.

```
[tls] pure-Ada TLS 1.3 client over the W5500
[tls] connecting to 192.168.1.10:4433
[tls] ServerHello: cipher suite = 0x1301
[tls] server key share = 3b8a...
[tls] handshake opening OK
[tls] client_random=...
[tls] s_hs_secret=...
[tls] c_hs_secret=...
[tls] encrypted handshake decrypted + authenticated (Finished seen)
[tls] server cert parsed; host match=yes
[tls] ready=yes
[tls] peer authenticated=yes
[tls] sent HTTP GET (encrypted)
[tls] decrypted response:
...
```

`handshake opening FAILED`, `encrypted handshake decrypt FAILED` or
`[tls] could not connect` tell you how far it got. The secrets are printed in
NSS key-log format so a capture can be decrypted in Wireshark alongside — which
is the fastest way to find out which side disagrees.

## Reading the progress

Each line marks a stage that can fail independently, which is the point of
printing them:

| line | what it means if you got this far |
|---|---|
| `ServerHello: cipher suite` | the server accepted our ClientHello and picked a suite we offered |
| `server key share` | ECDHE succeeded; both sides have a shared secret |
| `handshake opening OK` | the key schedule produced keys the server's records decrypt under |
| `encrypted handshake ... (Finished seen)` | every record authenticated and a Finished arrived — this alone proves the keys are right |
| `server cert parsed; host match` | the DER parsed and the SAN matched the requested host |
| `peer authenticated` | CertificateVerify *and* Finished both checked out |
| `ready=yes` | the application channel is open |

`peer authenticated` requires **CertificateVerify**, not just Finished. Finished
proves the ECDHE agreement; only CertificateVerify proves the peer holds the
private key for the certificate it presented. Without that check, a full
(non-PSK) handshake would accept a man in the middle forwarding somebody else's
certificate.

## Hardware & the server

A **W5500** Ethernet module wired per `w5500_dev.adb`; the board takes the static
IP **192.168.1.50**. You need a TLS 1.3 server on the LAN — for example:

```sh
openssl s_server -tls1_3 -accept 4433 -cert c.pem -key k.pem
```

Set `Server_IP`, `Server_Port` and `Host` in `src/main.adb` to match, and pin
that server's root certificate in `trust_anchors.ads`.

## Build & flash

```sh
./x run esp32s3_tls_hello            # build + flash + monitor
```

Uses the **embedded** profile, selected by `build.sh`
(`ESP32S3_RTS_PROFILE=embedded`).

## See also

`esp32s3_tls_weather` is the same client against the real internet;
`esp32s3_tls_resume` adds session resumption.
