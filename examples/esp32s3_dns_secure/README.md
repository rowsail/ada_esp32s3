# esp32s3_dns_secure — one name, four DNS transports

Resolves a single host name four ways over the W5500, to demonstrate every
DNS transport the SDK implements:

| Transport | Port | RFC | Package |
|-----------|------|-----|---------|
| UDP | 53 | 1035 | `DNS_Client.Resolve` |
| TCP | 53 | 7766 | `DNS_Client.Resolve_TCP` |
| DoT (DNS-over-TLS) | 853 | 7858 | `DNS_TLS.Resolve_DoT` |
| DoH (DNS-over-HTTPS) | 443 | 8484 | `DNS_TLS.Resolve_DoH` |

All four build the same proven query bytes (`DNS_Client.Wire`) and walk the
reply with the same proven parser (`DNS_Client.Parse`); only the carriage
differs.

The plain UDP/TCP legs use the network's own resolver (from the DHCP lease):
reachable by both, and not subject to the common policy of filtering external
port-53 traffic. The DoT/DoH legs go to Google Public DNS (`dns.google`,
8.8.8.8) — which those encrypted transports are precisely designed to reach
*through* such filtering, being indistinguishable from ordinary HTTPS.

## The pinned anchor

DoT/DoH authenticate `dns.google`'s leaf under a pinned intermediate,
`DoT_Anchor.WE2_DER` (Google Trust Services "WE2", P-256). Pinning the
issuing intermediate rather than a root is a demo simplification: the public
DoT roots are P-384 ECC, which the current TLS stack does not verify yet; the
leaf verifies under WE2 with ECDSA-P256-SHA256, which it does. Regenerate the
anchor when WE2 rotates:

    echo | openssl s_client -connect 8.8.8.8:853 -servername dns.google \
        -showcerts 2>/dev/null > chain.pem
    # take the SECOND certificate (the intermediate), then:
    openssl x509 -in that_cert.pem -outform DER | \
        <the byte-array formatter in the commit that added this example>

## Build & run

    ./x run esp32s3_dns_secure

Expect one `[dns] <transport>: example.com = a.b.c.d` line per transport and
`4 of 4 transports resolved`.
