# Heartbeat — the minimal periodic task (ESP32-S3, no FreeRTOS)

The smallest thing that proves the runtime boots and the scheduler runs on
hardware. The environment task logs a 1 Hz heartbeat counter while a separate
library-level task in package `Blink` ticks at 100 ms. Both keep time with
`delay until` on the native CCOMPARE2 tick, so **a steady heartbeat is the
evidence** — two independent periods being juggled correctly.

```
[example] heartbeat 1
[example] heartbeat 2
[example] heartbeat 3
```

One line per second, counting up, forever. A stalled or irregular count means
the alarm or the scheduler is wrong; there is nothing else in this example to go
wrong.

`Blink.Periodic` does no I/O deliberately — the env task's heartbeat count is the
only console signal, so a second task that is silently *not* running still shows
up, as jitter in the 1 Hz line.

## Build & flash

```sh
./x run esp32s3_heartbeat            # build + flash + monitor
```

Runs on the default **light-tasking** profile, built against the pinned
`esp32s3_rts` crate. No wiring.

## See also

`esp32s3_delay_test` measures the alarm's accuracy rather than just its
liveness; `esp32s3_smp` puts a task on the second core.
