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

**Cold-start TCP.** The first W5500 TCP connect to an off-subnet host after
bring-up can fail once — the chip fails a SYN sent before the gateway's ARP
entry exists, rather than waiting for ARP; a retry succeeds. The example
primes that entry with a throwaway connect before the reported legs, so the
first result is not the one that eats the cold start. (An application would
normally get this for free: `Net_Resolver` retries, and any real reconnect
loop retries.)

**NTP.** A single UDP round trip to a public NTP server can be lost, and
DoT/DoH need trusted time for the certificate-validity check, so the clock
sync is retried a few times.

## The pinned anchor

DoT/DoH authenticate `dns.google`'s leaf under a pinned intermediate,
`DoT_Anchor.WE2_DER` (Google Trust Services "WE2", P-256). Pinning the
issuing intermediate rather than a root is a demo simplification: the public
DoT roots are P-384 ECC, which the current TLS stack does not verify yet; the
leaf verifies under WE2 with ECDSA-P256-SHA256, which it does. Regenerate the
anchor when WE2 rotates:

    echo | openssl s_client -connect 8.8.8.8:853 -servername dns.google \
        -showcerts 2>/dev/null > chain.pem
    # take the SECOND certificate (the intermediate), convert to DER, and
    # reformat as the Ada byte array in dot_anchor.ads.

## Build & run

    ./x run esp32s3_dns_secure

Expect one `[dns] <transport>: example.com = a.b.c.d` line per transport and
`4 of 4 transports resolved`.
