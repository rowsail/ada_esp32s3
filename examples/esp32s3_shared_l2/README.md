# esp32s3_shared_l2 — two drivers on one level-2 interrupt

Ada allows exactly **one** protected handler per `Interrupt_ID`, and the
ESP32-S3 has only two dispatched device slots at level 2 (CPU_INT 19 and 20).
The buffered UART receiver and the TWAI (CAN) receiver both wanted CPU_INT 19,
so an image containing both raised `Program_Error` inside
`System.BB.Interrupts` at **elaboration** — a boot loop, before `main` ran.

`ESP32S3.Shared_L2` owns the slot instead, and drivers *register* with it. On
each interrupt every registered service is called and looks at its own
peripheral's status — exactly what the runtime's `Level2_Dispatch` already does
for the kernel's tick and cross-core poke on CPU_INT 21.

This example is the proof: it drives **both** receivers at once.

## Run

```sh
./x run esp32s3_shared_l2
```

## Expected output

```
=== ESP32S3.Shared_L2: two receivers on CPU_INT 19 ===
[uart] buffered RX over the shared slot: got 9 of 9 bytes  PASS
[twai] CAN RX over the shared slot: frame matched  PASS
[shared] tenants= 2  dispatches= 11
[shared] done: both receivers ran on one interrupt.
```

`tenants= 2` with a non-zero `dispatches` is the whole claim: two drivers were
serviced through one protected handler on one interrupt.

## Hardware / wiring

None. The UART uses the controller's internal TX→RX loopback and the TWAI its
self-test mode with a GPIO-matrix loopback, so both receive their own
transmissions on-chip.

## Verified

Run on hardware, both PASS. The counterfactual was checked too: putting the
TWAI receiver back to attaching directly — the second claim on the slot — makes
this same image die before the runtime comes up, never reaching the banner.
