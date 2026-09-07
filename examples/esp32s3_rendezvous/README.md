# esp32s3_rendezvous — Ada task rendezvous on the ESP32-S3

Demonstrates the Ada **rendezvous** (synchronous task-to-task message passing —
task entries / `accept` / entry calls) on the bare-metal dual-core ESP32-S3,
running on the **`full`** runtime profile
(`crates/esp32s3_rts/full_overlay`), which carries the complete GNARL
tasking kernel with no Jorvik restrictions. Rendezvous, `select`, and entries
are all forbidden under Ravenscar/Jorvik.

A `Calculator` server task exports three entries — `Add`, `Sub`, `Stop` — and
serves them with a **selective accept** (`select … or accept … end select`),
waiting for whichever entry is called next. The environment task (`Main`'s body)
is the client: it calls each entry and gets the result back through an `out`
parameter. The accept body runs while the caller is suspended in the rendezvous.

```
./x run rendezvous
```

Expected output:

```
[calc] server ready -- waiting for a rendezvous
=== Ada task rendezvous on ESP32-S3 (full tasking) ===
    [calc] Add ( 10, 5 ) => 15
[main] 10 + 5 = 15
    [calc] Sub ( 10, 5 ) => 5
[main] 10 - 5 = 5
    [calc] Add ( 100, 23 ) => 123
[main] 100 + 23 = 123
[calc] stopped -- terminating
[main] done.
```

What this exercises (all impossible under Jorvik): a task **entry** with `in`/
`out` parameters, the **`accept` body** executing with the caller blocked, a
**selective accept** over several entries, and a parameterless rendezvous
(`Stop`) that lets the server task terminate.

## Build / runtime notes

Same bare-metal setup as `esp32s3_full_tasking`: there is **no ESP-IDF** in the
loop. Our own 2nd-stage bootloader sets up cache/MMU and jumps to `_start`
(`start.S`) → 240 MHz PLL → `start_c()` (`bare_boot.adb`) → `app_main()`
(`examples/common/bare/boot/bare_glue.adb`), which takes over **both** cores; FreeRTOS
never runs (it never starts). Core 0 becomes the Ada environment task; core 1 is
cold-started straight into the GNARL slave scheduler. `bare_glue` provides the
env-task stack (`ada_env_stack`, sized by `ENV_STACK_SIZE`) and, for the
exception-capable profiles, the Ada heap (`HEAP_SIZE`); every Ada task's own
stack is carved from that heap, not placed by a per-example hook. This example
has no `glue.c` of its own (it logs through `ESP32S3.Log`).

PSRAM placement is **not** an `sdkconfig` / `CONFIG_SPIRAM*` edit: the PSRAM size
that the bootloader maps at `0x3D000000` lives in `board.ads` (`PSRAM_Size`), and
where the heap / env stack actually land is chosen by `build.sh` env knobs
(`HEAP_PSRAM=1` puts the heap arena in PSRAM, `ENV_STACK_PSRAM=1` the env stack) —
both consumed by the shared `examples/common/bare/bare_build.sh`. This demo sets
neither, so its heap is the leftover internal DRAM. The build itself is driven by
`./x run rendezvous`: the per-example `build.sh` sets `HEAP_SIZE` /
`ENV_STACK_SIZE` and execs `bare_build.sh`; the Ada is compiled to a relocatable
`obj/app_main.o` by the shared `examples/common/bare/build_ada.sh` against the
pinned runtime crate, on the **`full`** runtime profile
(`ESP32S3_RTS_PROFILE=full`, consumed by `gen_runtime.sh`).

## Two former "limitations" — both fixed by disabling W^X

This demo uses the environment task as the client only for simplicity. Two things
that earlier docs called separate limitations are gone, and were in fact the
**same bug**:

1. A **dedicated client task** (two separately declared tasks) was said to
   "corrupt memory during activation/handoff."
2. **Console output from multiple tasks** ("console concurrency") was said to
   fault, forcing all `Put_Line` onto one task.

Both were the **ESP32‑S3 W^X memory-protection feature** refusing to execute the
GCC nested-function **trampoline** a frame-capturing client-task body needs: the
trampoline is written as data (on the DRAM stack, re-pointed to its SRAM1 IRAM
alias `+0x6F_0000` by `gen_runtime.sh`) and then executed, which W^X forbids —
faulting with "Cache disabled but cached memory region accessed." On the
bare-boot there is no `sdkconfig` and the **memory-protection (PMS) feature is
simply never turned on** — neither the 2nd-stage bootloader nor `bare_boot`
arms it — so the IRAM-alias trampoline executes freely; with that, a dedicated
client task **and** concurrent multi-task console output both run cleanly
(A/B-verified on HW). Root cause: `memory/full-profile-acats.md` and
`crates/esp32s3_rts/full_overlay/README.md`.
