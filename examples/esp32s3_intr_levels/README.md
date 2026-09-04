# Interrupt levels — vector regression test (ESP32-S3, no FreeRTOS)

Xtensa interrupt-priority handling and **context preservation** across the L2,
L3 and L5 vectors. This is a regression test for the hardest thing an interrupt
vector has to get right: giving the preempted code back exactly the registers it
had.

A low-priority "victim" holds register-resident state across a tight loop — four
floating-point accumulators computing the exact identity
`X := X * Loop_Mul * Loop_Inv` (the two factors read once from `Volatile` cells,
so the optimiser keeps them in F registers with **no in-loop memory traffic**),
plus a `THREADPTR` sentinel. Each batch it fires the L2 and L3 device interrupts,
which preempt it through `__gnat_level2_vector` / `__gnat_level3_vector`, while
the L5 timer tick preempts it asynchronously throughout.

**If any vector failed to save and restore the preempted context, an accumulator
or `THREADPTR` comes back wrong** — and the run logs `911`.

```
[intr] 100017
[intr] 200017
[intr] 300006
[intr] 100034
[intr] 200034
[intr] 300007
```

Every line is `[intr] <n>`, and the **leading digit** says which counter it is
(the value is added to a 100 000-spaced base):

| prefix | meaning |
|---|---|
| `1xxxxx` | cumulative L2 handler count |
| `2xxxxx` | cumulative L3 handler count |
| `3xxxxx` | clean-batch counter |

**PASS** is L2 and L3 climbing together alongside the clean-batch counter, with
**no `911`**. A `911` means a vector lost the preempted context.

## The level ↔ CPU_INT mapping

The S3 fixes each CPU interrupt at one priority level, so the levels are chosen
by picking the interrupt:

* **L2** = `Device_L2_0` = CPU_INT 19
* **L3** = `Device_L3_0` = CPU_INT 23
* **L5** = the always-firing timer tick

L4 has no vector on this port (`EXCSAVE_4` is scratch for L5), and L1 carries no
asynchronous interrupts here. The book's *The Context Switch* chapter has the
full picture.

## A constraint worth knowing

The handlers are **library-level protected objects**, and they have to be. The
runtime forbids implicit dynamic code (`No_Implicit_Dynamic_Code`), so a nested
handler — which GNAT would implement with a stack trampoline — is rejected at
compile time. On this target that is a feature: those trampolines land on a
non-executable stack and fault silently when called.

## Build & flash

```sh
./x run esp32s3_intr_levels          # build + flash + monitor
```

Needs the **embedded** profile, which `build.sh` selects: `pragma Attach_Handler`
and the `Ada.Interrupts` layer need the Jorvik interrupt machinery.

**No hardware.** The L2/L3 interrupts are software-fired through the `FROM_CPU`
interrupt-matrix sources; the L5 tick is the runtime timer.
