# esp32s3_rts

A native **dual-core SMP Ada (GNAT Jorvik/Ravenscar)** bare-metal runtime for
the **ESP32-S3** (Xtensa LX7), generated from the forked `bb-runtimes` esp32s3
board.  Hardware-validated: SMP scheduler on both cores, own VECBASE / tick /
interrupt dispatch (FreeRTOS is not linked at all), 240 MHz,
idiomatic `pragma Attach_Handler` interrupt handlers, and hardware
single-precision FPU preserved across context switches.

This crate is **not published**; consume it via an Alire **pin**.

## Using it (Alire pin)

In your project's `alire.toml`:

```toml
[[depends-on]]
esp32s3_rts = "*"

[[pins]]
esp32s3_rts = { path = "<path>/crates/esp32s3_rts" }
xtensa_dynconfig       = { path = "<path>/crates/xtensa-dynconfig" }
```

In your project file:

```ada
with "esp32s3_rts.gpr";

project My_App is
   for Target use "xtensa-esp32-elf";
   for Runtime ("Ada") use Esp32s3_Rts.Runtime_Path;
   --  ... build to a relocatable object (-Wl,-r -nostdlib) ...
end My_App;
```

`alr build` runs the crate's pre-build action (`gen_runtime.sh`), which uses the
`xtensa_dynconfig` dependency (it sets `XTENSA_GNU_CONFIG` to the ESP32-S3 core
config) and the `gnat_xtensa_esp32_elf` toolchain to generate + archive the
`light-tasking-esp32s3` runtime, then exposes its path as
`Esp32s3_Rts.Runtime_Path`.

See `examples/esp32s3_heartbeat/` for a minimal consumer that builds against it.

## What this crate is NOT

It packages the **Ada runtime** only.  Running on hardware also needs the
ESP-IDF coexistence layer (CMake project, `glue.c`, the VECBASE/tick takeover,
`highint5.S`, the cross-core poke + interrupt-matrix wiring) -- see
`examples/common/bare/` for the complete, hardware-validated boot to copy.

## Requirements

- The forked `bb-runtimes` submodule at `../bb-runtimes` (provides the esp32s3
  board + `build_rts.py`).
- `gnat_xtensa_esp32_elf` (^15) toolchain and `xtensa_dynconfig` (both resolved
  by Alire).
- `python3` (for `build_rts.py`).
