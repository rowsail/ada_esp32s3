# esp32s3_stress -- RTS stress suite

Manufactures the coincidences that have historically broken bareboard
runtimes, and detects failure without a console:

* **Tiny-delay storm** (`stress_storm`): four tasks (one on core 1) issue
  randomized overdue / zero-length / sub-millisecond `delay until`s mixed
  with busy-spins, hammering systimer re-arming, the alarm queue and
  preemption at random instruction boundaries.  Two share a priority for
  the FIFO-within-priorities paths.
* **Cross-core ping-pong** (`stress_pingpong`): two suspension-object
  pairs and one protected-entry pair, each split across the cores, wake
  each other at full rate underneath the storm.  A lost cross-core wakeup
  freezes a pair's heartbeats.
* **Stall monitor** (`stress_monitor`): sweeps every heartbeat each 2 s
  and latches the first stalled slot in `__stress_stalled`; its own
  `__stress_round` freezing means the system itself froze.

Everything is observable over USB-JTAG: `./build.sh`, flash `app.bin`,
then `./check.sh [seconds]` polls the verdict words and prints
PASS/FAIL.  `__stress_seed` (boot CCOUNT) makes a failing run's random
schedule reproducible.  Builds under the embedded profile by default;
`ESP32S3_RTS_PROFILE=full ./build.sh` exercises the full runtime's
heap-allocated tasking on the same source.
