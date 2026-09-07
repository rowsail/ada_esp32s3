# `full` runtime profile — full-Ada-tasking port (WORK IN PROGRESS)

This overlay turns the ESP32-S3 bareboard runtime from **Jorvik** (restricted
tasking) toward **full Ada tasking** — rendezvous, `select`, dynamic & nested
tasks, dynamic priorities, task attributes, and (the hard frontier) `abort` /
ATC. It is selected with `ESP32S3_RTS_PROFILE=full`; `light-tasking` and
`embedded` are untouched. bb-runtimes is untouched — everything lives here.

> **Status: M2 DONE — full tasking RUNS on hardware.** The full runtime builds
> + links (534 units) and a library-level task runs concurrently with the
> environment task on the ESP32-S3 (`examples/esp32s3_full_tasking`):
> the hand-written `s-taprop` (`Create_Task` with dynamic stack allocation,
> ceiling+Fair_Lock locks, `Sleep`/`Wakeup`, the BB-kernel scheduler) executes
> correctly — interleaved `[env]`/`[task]` output, clean boot, no panics.
> Two on-hardware fixes landed: the env task is passed as the idle task's
> creator in `Initialize_Idle` (the donor `Initialize_ATCB` dereferences the
> creator's domain), and `Create_Task` allocates the task's primary stack
> (the full runtime does not preallocate it). `s-binglo` supplies the
> binder-interface globals (`__gl_main_priority`, `__gnat_get_secondary_stack`,
> SEH/interrupt-state stubs) the donor `s-taskin` imports. Default profiles
> unaffected. **M3 essentially done**: protected-object entries (blocking/
> waking across tasks), `Ada.Task_Attributes`, and `Ada.Dynamic_Priorities` all
> run on HW (`examples/esp32s3_full_tasking`). The key fix was that
> `Sleep` must FULLY release the caller's ATCB lock (priority ceiling + Fair_-
> Lock) across the suspension and re-acquire on wakeup — matching the hosted
> condition-variable semantics; otherwise the waker (which takes that lock)
> deadlocked, hanging both protected-entry waits and the env task's activation
> wait. Known edge case: `Set_Priority` lowering the running task below its
> ready peers.
>
> **M4 DONE (HW):** rendezvous (entries/`accept`/entry calls), nested tasks +
> task hierarchy + termination (the master blocks until dependents terminate),
> and dynamic task allocation (`new`, `New_ATCB`/`Free_ATCB`) all run on
> hardware. Two fixes: `Exit_Task` must NOT return (`__gnat_start_thread` does
> `callx4` and never expects the wrapper to return) — it parks the thread;
> `Finalize_TCB` must NOT free a declared task's ATCB (it lives in the frame —
> freeing corrupts the stack).
>
> **Heap-exhaustion hardening (HW).** `Create_Task` guards `Alloc_Task_Stack`: a
> null return (heap full) sets `Succeeded := False` so `Activate_Tasks` raises
> `Tasking_Error` instead of running a task on a 0-based stack pointer. (CXD4009's
> "wild jump" was exactly this — heap exhaustion misread for hours as window-spill
> corruption: 6 concurrent 20 KB task stacks overran the bare DRAM heap.) And
> `Finalize_TCB` frees the *owned* primary stack via `__gnat_task_stack_free`
> (`examples/common/bare/boot/bare_heap.adb`, with a reaping-race handshake), so
> heap-allocated task stacks are reclaimed on termination rather than leaking
> across a multi-task batch.
>
> **M5 (abort) DONE for the common case (HW).** `abort` of a task that reaches
> an abort-completion point (a `delay` loop, a periodic task) works: the task
> raises `Abort_Signal`, terminates, and `'Terminated` goes `False -> True` —
> verified on silicon, with no regression to M1-M4.
>
> **Root cause (this was the whole blocker):** the bareboard inherits
> `System.Parameters.No_Abort = True` from Ravenscar/Jorvik, which compiles the
> abort machinery *out* of `s-tasini` — `Init_RTS` installs the real
> `Abort_Defer/Undefer` soft links only `if not No_Abort`, and
> `Defer_Abort`/`Undefer_Abort`/`Do_Pending_Action` short-circuit to no-ops. So
> `Abort_Signal` was never raised and every `abort` was silently dropped. The
> fix is one line — `gen_runtime.sh` patches `s-parame.ads` to
> `No_Abort := False` — which activates the (already-present, portable) GNARL
> abort path. *(An earlier write-up here blamed a "`Master_Of_Task <= 0`
> fall-through"; that was a measurement artifact of non-atomic cross-core
> single-char `Text_IO` traces — `Master_Of_Task` is correct (4/5 for declared/
> nested tasks) and tasks terminate cleanly via `Exit_Task`.)*
>
> **Abort — now prompt, and correct across cores (2026-06-10).** Earlier
> `Abort_Task` was a no-op, so abort was honoured only when the target reached a
> completion point on its own (and a long `delay until` aborted at its *natural
> expiry*). Fixed:
> 1. **Prompt delay-abort — DONE (same- *and* cross-core).** A task in `delay
>    until` is BB-`Delayed`, which `BB.Threads.Wakeup` cannot wake (it knows only
>    `Suspended`/`Runnable`). `STPO.Wakeup`/`Abort_Task` now route a `Delayed`
>    (or any cross-core) target to
>    `CPU_Primitives.Multiprocessors.Cancel_Delay`: same core → `Queues.Cancel_-
>    Alarm` (unlink the alarm, make `Runnable`); cross-core → `Request_Cross_-
>    Cancel` + `Poke_CPU`, and the target's `Run_Cross_Cancel` does the wake on
>    its own core. Abort of a 10 s `delay until`: **9.7 s → 0.005 s** same-core,
>    **0.004 s** cross-core. (`Enter_Kernel` masks only *local* interrupts, so
>    the per-CPU `Cross_Cancel` queue is `Fair_Lock`-protected.)
> 2. **Entry-blocked abort — works** (`CONFIG_ESP_SYSTEM_MEMPROT_FEATURE=n` is
>    the project default). A task parked on a never-opening protected entry
>    starts cleanly and `abort` terminates it (`'Terminated` False→True), 0
>    panics. The earlier `InstructionFetchError` / "Cache disabled" "stack
>    corruption" was the **W^X trampoline fault**, not a broken entry-cancel
>    path. Cross-core entry/abort wakeups use the same `Cancel_Delay` path.
> 3. **Cross-core task *start* — DONE (library-level *and* dynamic).** A task
>    pinned to another core now starts: the slaves are brought up lazily on the
>    env's first block (`STPO.Sleep` → idempotent `Start_All_CPUs`), and
>    `Queues.Insert` routes a cross-core insert onto an already-started CPU
>    through the same Poke path (`Initialize_Thread` inserts *last*, so the
>    hand-off sees a fully-built thread). Previously the env deadlocked:
>    full-tasking activation *waits*, but the binder starts the slaves only at
>    end-of-`adainit`. Verified on the full 307-test tasking sweep (220 PASS / 0
>    genuine FAIL, no regression).
>
> **Still missing:** aborting a task in a pure **CPU loop** with no completion
> point.  Priority-preemption itself *works* (HW-confirmed -- a higher-priority
> task preempts the spinning loop via the timer ISR), but abort *delivery* is
> cooperative: `Do_Pending_Action` raises `Abort_Signal` only when the task
> reaches a completion point (`delay` / entry / `Abort_Undefer`), and there is no
> asynchronous injection from the ISR.  So a deliberate no-yield compute loop
> records the pending abort but never delivers it.  Closing this needs a
> signal-frame-style async injection (redirect the preempted task to raise
> `Abort_Signal` with correct unwind linkage through the Xtensa windowed ABI,
> gated on `Deferral_Level = 0`) -- deep and delicate for a niche case, which is
> exactly why Ravenscar/Jorvik restrict abort.
>
> Concretely (both HW-verified) -- a loop with **no** completion point **cannot**
> be aborted; `abort` is recorded but never delivered, so it spins forever:
>
> ```ada
> task body Worker is
>    X : Long_Integer := 0;
> begin
>    loop
>       X := X + 1;          --  pure work: no delay / entry call / Abort_Undefer
>    end loop;               --  `abort Worker` never lands -> runs forever
> end Worker;
> ```
>
> Adding **any** completion point -- here a `delay` -- makes the very same loop
> abortable; the abort is delivered at that point and the task terminates:
>
> ```ada
> task body Worker is
>    X : Long_Integer := 0;
> begin
>    loop
>       X := X + 1;
>       delay until Clock + Milliseconds (1);   --  completion point: abort lands here
>    end loop;
> end Worker;
> ```
>
> (An entry call, `accept`, `select`, or an explicit `Abort_Undefer` works the
> same way -- any of them is a point at which the pending abort is checked.)

> **FIXED — DRAM nested-function trampolines for frame-capturing task bodies.**
> *Root-caused and fixed via JTAG (OpenOCD + gdb).* When a task body **captures
> its enclosing subprogram's frame** — e.g. it calls a *sibling* task's entry
> (references that task object in `Main`), or declares a **local controlled
> type** — GNAT compiles the body as a **nested function** and stores a **GCC
> trampoline** in `Self_ID.Common.Task_Entry_Point`. That trampoline is built on
> the stack, i.e. in **internal DRAM** (`0x3FCx_xxxx`), which on the ESP32‑S3 is
> **not on the instruction bus** — so `Task_Wrapper`'s `callx8 Task_Entry_Point`
> faulted with `InstructionFetchError`. JTAG proof: `a8 = Task_Entry_Point =
> 0x3fceb13c` (DRAM); `x/16i` there showed a textbook trampoline
> (`entry a1,32; … l32r a8,(0x420001c0 <main__clientTKB>); movsp …`) loading the
> static chain and jumping to the real body in flash.
>
> **The fix** (`gen_runtime.sh` patches `s-taskin.adb` `Initialize_ATCB`): SRAM1
> is dual-mapped — its IRAM view is at **`+0x6F_0000`**
> (`SOC_DIRAM_IRAM_LOW − SOC_DIRAM_DRAM_LOW`). When `Task_Entry_Point` lands in
> the SRAM1 DRAM window (`0x3FC8_8000 .. 0x3FCF_0000`), re-point it at the IRAM
> alias so `callx8` fetches the *same* physical trampoline bytes through the
> instruction bus. Flash/PSRAM addresses pass through unchanged. Verified on HW:
> a dedicated **client task completes ~94k rendezvous** with a server task
> (`client_mark == server_mark`, no fault), and a task with a **local controlled
> object** runs and terminates cleanly. `-fno-trampolines` does *not* help (GNAT
> trampolines task bodies regardless) — confirmed by JTAG. (This also explains
> the M5 entry-blocked-abort fault — that victim task's body had an entry call,
> hence a trampoline.)
>
> **UPDATE (2026-06-05) — the "console-concurrency caveat" was a MISDIAGNOSIS.**
> The faults previously blamed on a `System.Text_IO` `is_tx_ready` race (two
> tasks writing the console, or one writing while another drives a rendezvous)
> were the SAME W^X trampoline fault above: the driving task is frame-capturing,
> so its body is a trampoline, which the ESP32-S3 memory-protection feature
> refused to execute. A/B-verified on HW: a dedicated client task + two tasks
> printing concurrently CRASH with `CONFIG_ESP_SYSTEM_MEMPROT_FEATURE` on and run
> cleanly with it **off** (now the project default — see
> `memory/esp32s3-memprot-default.md`). There is no `is_tx_ready` race; route
> output however you like once memprot is disabled.

## Why a port is required (the Jorvik floor)

You cannot get below Jorvik by editing restrictions. `pragma Profile (Jorvik)`
sets internal "restricted run-time" state that GNAT's `rtsfind` / protected-
object expansion depends on; replacing it with its *documented-equivalent*
explicit pragmas — even the complete 16-restriction set — makes **every**
protected object fail to compile (`construct not allowed in this configuration`
/ `"" is undefined`). And Ada has no pragma to drop a single restriction from a
profile. So the only way past Jorvik is to provide the **full GNARL tasking
runtime** so GNAT selects it (no profile pragma needed) — i.e. this port.
(Details in `memory/jorvik-restriction-floor.md`.)

## Architecture

The full GNARL is OS-portable; only the `System.Task_Primitives` layer
(`s-taprop`/`s-taspri`/`s-osinte`) is target-specific. So the port is:

1. **Import, version-matched**, from `gnat_native_15.2.1` (the host GNAT — same
   GCC 15.2.0 as our cross-compiler), the portable full units: full `s-taskin`
   (1232-line ATCB with the rendezvous/abort/master fields), `s-tassta` (full
   task stages), `s-tasren` (rendezvous), full `s-tpobop`/`s-tpoben`/`s-tasque`,
   `s-solist`, `a-dynpri`, `a-tasatt`/`s-tataat`, plus their closure
   (`s-stausa`, `s-tadeca`, `s-tadert`, `s-tasinf`, …). Resolve unit→file with
   the predefined-unit naming (`System.Stack_Usage` → `s-stausa`), **not**
   `gnatkr` (which does generic krunching only).
2. **Write a *full* bareboard `s-taprop`** over the existing BB kernel
   (`s-bbthre`, `s-bbtime`, `s-bbsuei`, context switch). The restricted one has
   15 ops; the full interface needs ~45. The 30 to add, triaged:
   - *Easy* (map to existing BB primitives): lock family (`Write/Read_Lock`,
     `Unlock`, `Initialize/Finalize_Lock`, `Lock_RTS/Unlock_RTS`), suspension
     objects (`Set_True/False`, `Suspend_Until_True`), `Yield`, `Set_Ceiling`,
     `Environment_Task`, `Is_Valid_Task`, `RT_Resolution`, `Current_State`.
   - *Moderate*: `New_ATCB`/`Free_ATCB`/`Finalize_TCB`/`Exit_Task` (dynamic
     ATCB + stack allocation — needs `Preallocated_Stacks = False` + a stack
     pool), `Timed_Delay`/`Timed_Sleep`.
   - *Hard frontier*: `Abort_Task`/`Stop_Task`/`Stop_All_Tasks`/`Suspend_Task`/
     `Resume_Task` — asynchronous abort/ATC; needs BB-kernel support to
     interrupt a running task and raise `Abort_Signal`.
3. **`system.ads`**: drop the profile pragma so GNAT selects the full runtime;
   keep the target parameters + dispatching/locking policies.

## Milestones (each HW-verifiable)

- **M1** — full source tree stands up; the runtime library compiles + archives.
- **M2** — one library-level task (no profile pragma) links + runs on HW
  (proves `Create_Task`/activation/`Self`/`Sleep` over the BB kernel).
- **M3** — protected objects + `Ada.Dynamic_Priorities` + `Ada.Task_Attributes`.
- **M4** — rendezvous (`accept`/entry calls) + dynamic & nested tasks +
  termination.
- **M5** — `abort` / ATC / `select`-with-terminate (hard; may end up partial).

## Files here

- `gnat/system.ads` — the full-tasking system spec (no profile; WIP).
- `gnarl/` — the imported + adapted full GNARL units and the bareboard full
  `s-taprop` (populated as the port proceeds).

`gen_runtime.sh` synthesizes `full-esp32s3/` by cloning the embedded source tree
and overlaying these files.
