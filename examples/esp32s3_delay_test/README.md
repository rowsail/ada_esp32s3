# Delay accuracy — the SYSTIMER alarm, idle-then-wake (ESP32-S3, no FreeRTOS)

A regression test for the runtime's alarm. The single environment task sleeps for
a fixed interval, so **between delays the whole system is idle** — core 1 is
brought up specifically so both cores sit in `waiti`. Each line prints the
**measured** elapsed time.

```
[delay-test] SYSTIMER alarm accuracy (idle-then-wake)
[delay-test] target=1000 ms  actual=1000 ms
[delay-test] target=200 ms  actual=200 ms
```

`actual` must track `target`. Two specific failures are what this exists to
catch:

* **waking ~15–18 s late** — the CCOUNT-wrap symptom of the old alarm. A
  CCOUNT/CCOMPARE2 alarm cannot wake a fully idle system reliably, and the
  both-cores-in-`waiti` setup here is exactly the case that exposed it.
* **drift** — `actual` creeping away from `target` over many iterations.

This is why the test bothers to start core 1: with anything else running, some
other interrupt wakes the CPU and the broken alarm looks fine.

## Build & flash

```sh
./x run esp32s3_delay_test           # build + flash + monitor
```

Embedded profile (`build.sh` sets `ESP32S3_RTS_PROFILE=embedded`). No wiring.
