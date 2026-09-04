# TLS 1.3 — session resumption with a PSK ticket (ESP32-S3, no FreeRTOS)

The resumption half of the pure-Ada TLS 1.3 client. Two connections are made to
the same server:

1. **Connection 1** does a full handshake and, while draining the response,
   captures the server's **NewSessionTicket** and derives its resumption PSK.
2. **Connection 2** calls `TLS_Client.Resume`, which offers that ticket as a
   `pre_shared_key` extension with its binder — **PSK-with-(EC)DHE**, so a fresh
   `key_share` still goes out. If the server accepts, the second handshake is
   *resumed*: no Certificate flight at all.

```
[resume] TLS 1.3 session resumption (PSK) over the W5500
[resume] full handshake: OK
[resume] resumption ticket captured: yes
[resume] resumed handshake: OK (no Certificate flight when resumed)
[resume] server accepted PSK (resumed): yes
[resume] second (resumed) exchange done
[resume] result: PASS
```

The last line is the verdict: `PASS` needs both a ticket from connection 1 and
the server accepting it on connection 2. `[resume] could not connect (1)` / `(2)`
name which of the two connections failed to reach the server at all.

## Why the answer can legitimately be "no"

`server accepted PSK: no` is a **server** decision, not a client bug. A server
may decline a ticket because it expired, because its ticket key rotated, or
because it simply chose not to — and the client must then fall back to a full
handshake, which is exactly what happens. Resumption is an optimisation; a
correct client never *depends* on it.

Note that a fresh `key_share` is offered alongside the PSK. That is deliberate:
PSK-only resumption gives no forward secrecy, so a compromise of the ticket key
would retroactively expose the resumed session. PSK-with-(EC)DHE keeps forward
secrecy and still skips the certificate flight, which is the expensive part on a
microcontroller.

**No certificate pinning here** — the focus is resumption, so any server
certificate works. Chain validation lives in `esp32s3_tls_weather` and
`esp32s3_x509_chain`.

## Hardware & the server

A **W5500** Ethernet module; the board takes static IP **192.168.1.50**. You need
a LAN TLS 1.3 server that issues *and* accepts tickets:

```sh
openssl s_server -tls1_3 -accept 4433 -cert c.pem -key k.pem -www
```

## Build & flash

```sh
./x run esp32s3_tls_resume           # build + flash + monitor
```

Embedded profile, set by `build.sh`.

## See also

`esp32s3_tls_hello` for the full handshake it resumes from.
