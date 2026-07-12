# esp32s3_dns_secure — one name, four DNS transports

Resolves a single host name four ways over the W5500, to demonstrate every
DNS transport the SDK implements. All four legs speak to Google Public DNS:

| Transport | Endpoint | RFC | Package |
|-----------|----------|-----|---------|
| UDP | 8.8.8.8:53 | 1035 | `DNS_Client.Resolve` |
| TCP | 8.8.8.8:53 | 7766 | `DNS_Client.Resolve_TCP` |
| DoT (DNS-over-TLS) | 8.8.8.8:853 | 7858 | `DNS_TLS.Resolve_DoT` |
| DoH (DNS-over-HTTPS) | dns.google:443 | 8484 | `DNS_TLS.Resolve_DoH` |

All four build the same proven query bytes (`DNS_Client.Wire`) and walk the
reply with the same proven parser (`DNS_Client.Parse`); only the carriage
differs.

## Two hardware notes

**Cold-start TCP.** The first W5500 TCP *connection* after bring-up completes
its connect and its send but never receives the reply — the response read
times out, and the second connection (and every one after) works at once.
It is measurably *not* ARP (UDP to off-subnet hosts succeeds before it) and
*not* the connect (which establishes); it is specific to the chip's first TCP
socket use, and the root cause is not yet pinned down. The example absorbs it
with a throwaway priming connection before the reported legs. (An application
gets this for free: `Net_Resolver`'s retry ladder, and any reconnect loop,
try again.)

**NTP.** A single UDP round trip to a public NTP server can be lost, and
DoT/DoH need trusted time for the certificate-validity check, so the clock
sync is retried a few times.

## The pinned root

DoT/DoH validate the full served chain up to a pinned P-384 **root**,
`DoT_Anchor.Root_DER` (Google Trust Services GTS Root R4): leaf ← WE2
(ECDSA-P256-SHA256) ← GTS Root R4 (ECDSA-P384-SHA384). The P-384 anchor step
exercises `libs/tls/p384` — ECDSA verification on the NIST P-384 curve, in
pure Ada — which is what lets a P-384 root be pinned at all (the major public
DoT roots are P-384 ECC). Regenerate the anchor when R4 rotates:

    echo | openssl s_client -connect 8.8.8.8:853 -servername dns.google \
        -showcerts 2>/dev/null > chain.pem
    # take the THIRD certificate (the root), convert to DER, and
    # reformat as the Ada byte array in dot_anchor.ads.

## Build & run

    ./x run esp32s3_dns_secure

Expect one `[dns] <transport>: example.com = a.b.c.d` line per transport and
`4 of 4 transports resolved`.
