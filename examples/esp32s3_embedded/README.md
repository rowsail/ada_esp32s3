# esp32s3_embedded — embedded runtime profile demo

A flashable example that runs Ada on both ESP32-S3 cores under the bare-boot
GNARL Ada runtime (no ESP-IDF, no FreeRTOS) and exercises the three features the
**`embedded`** runtime profile adds over the default **`light-tasking`** profile:

1. **Tagged dispatching** — a class-wide array of library-level `Shape`s is
   walked with dispatching `Name`/`Area` calls.
2. **Controlled-type finalization** — a `Resource` (a `Limited_Controlled`
   type) is finalized both on scope exit and when a heap object is released
   with `Unchecked_Deallocation`.
3. **Exception propagation** — an exception is raised and caught across a frame,
   and its real `Exception_Name` / `Exception_Message` are printed (needs the
   ZCX unwinder and the exception name table).

Under the default light-tasking profile a raised exception resets the board and
finalization/registration are restricted away; this example deliberately selects
the embedded profile to show them working.

## Build & run

```
./x run embedded      # build + flash + monitor
```

The repo's `./x` dispatcher drives the IDF-free bare-boot flow (use
`./x build|flash|monitor embedded` for the individual steps). There is no
`idf.py`, `sdkconfig`, `CMakeLists.txt`, `menuconfig` or FreeRTOS. At boot our
own 2nd-stage bootloader sets up flash-XIP cache/MMU and jumps to `_start`
(`start.S`), which selects the 240 MHz PLL and calls `start_c()`
(`bare_boot.adb`); that hands off to `bare_glue.adb`'s `app_main`, which owns
both cores directly — core 0 runs the env task, core 1 is cold-started into the
GNARL slave scheduler. FreeRTOS never runs.

This example's `build.sh` sets the env knobs — `ESP32S3_RTS_PROFILE=embedded`
plus a larger `HEAP_SIZE`/`ENV_STACK_SIZE` (the unwinder and finalizers need the
headroom) — then execs the shared `examples/common/bare/bare_build.sh`. The Ada
(`app.gpr`) is compiled to `obj/app_main.o` by the shared
`examples/common/bare/build_ada.sh`. Selecting the `embedded` profile pulls in
the freestanding heap/libc the exception machinery references (newlib is not
linked).

ZCX exception support does **not** depend on any IDF `CONFIG_…` knob. The
linker script brackets the `.eh_frame` block with `__eh_frame_start`, and the
bare-boot registers the DWARF unwind frames itself before any exception can be
raised: `bare_glue.adb` calls `bare_register_eh_frames`, whose strong override
(`bare_crt.adb`, exception-capable profiles only) calls `__register_frame` on
`__eh_frame_start`. For the light-tasking profile that hook is a weak no-op.

Expected console transcript:

```
[C] Ada runtime up on both cores
=== ESP32-S3 embedded profile demo ===
[1] tagged dispatching:
    circle area = 75
    rectangle area = 24
    circle area = 12
[2] controlled finalization:
    [resource initialized]
    (R in scope)
    [resource 1 finalized]
    [resource initialized]
    (P on heap)
    [resource 2 finalized]
[3] exception propagation:
    caught MAIN.MY_ERROR (deliberate)
=== demo complete; environment task now idles ===
```

## Note on local vs library-level types

`Shapes` and `Resources` are declared at **library level** on purpose. The
ESP32-S3 stack lives in DRAM, which is not executable, so a tagged/controlled
type declared *inside a subprogram* — whose dispatch-table thunk GNAT emits as a
trampoline on the stack — faults when dispatched/finalized. Library-level types
put their dispatch tables in flash and work correctly. See the *Runtime
profiles* note in the repository `README.md` for the full root cause and the
`pragma Restrictions (No_Implicit_Dynamic_Code)` build-time guard.
