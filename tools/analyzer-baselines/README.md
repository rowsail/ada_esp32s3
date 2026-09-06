# adalang_analyzer baselines

Fingerprints of the static-analysis findings that were present when each
baseline was written. `./x analyze` filters them out, so it reports only what is
**new** — the point is a tripwire on regressions, not a clean-code claim.

## Two rule sets, two baselines

`./x analyze` runs the **recommended** set against `<lib>.baseline`.
`./x analyze --automotive` runs a curated slice of the automotive profile
against `<lib>.automotive.baseline`. They enable different checks, so neither
baseline can stand in for the other.

The full `--automotive` profile is **not** what that flag runs here. As the tool
ships it, that profile reports **39,511 findings** across these four libraries —
41x the recommended set — because most of it is MISRA/AUTOSAR *restrictions*
that a bare-metal register HAL cannot satisfy by construction:

| rule | n | why |
|---|---:|---|
| `Magic_Number` | 25,531 | every register offset and bit literal; 65% of the total |
| `Complete_Initialization` | 5,474 | "no explicit initializer" on `aliased X_Register` fields, where one would be meaningless for memory-mapped hardware |
| `Naming_Convention` | 3,162 | a different house style |
| `Representation_Clause_Policy` | 1,671 | a register HAL is *made* of rep clauses |
| `Address_Clause` | 136 | memory-mapped registers are the whole point |
| `No_Dynamic_Allocation`, `No_Tasking`, `No_Controlled_Type`, `No_Dispatching_Call`, … | 119 | restrictions this SDK deliberately does not adopt — it ships three tasking profiles, controlled RAII sessions and a heap |

So `--automotive` here means the subset that makes **correctness** claims rather
than conformance ones (the list lives in `ANALYZE_AUTOMOTIVE_CHECKS` in `./x`).
Six of the thirteen normally find nothing at all — `Constant_Condition`,
`Overlapping_Case_Ranges`, `Duplicate_Boolean_Operand`,
`Unreachable_Case_Alternative`, `Redundant_Abs`, `Redundant_Unary_Minus` — which
is exactly why they are worth carrying: they cost no baseline entries while they
stay empty, and they are the rules that catch copy-paste and logic errors.

`Exception_Propagation` is deliberately excluded, and the reason is a trap worth
recording: it reports only **12** findings under the full automotive profile, but
enabled on its own it reports **1,274** in the HAL alone. It fires on every call
that can transitively raise, which in a stack that signals errors *with*
exceptions (ext4 raises `No_Space` / `Corrupt` / `Use_Error` by design) is very
nearly every call. It is a restriction, not a defect detector.

### What is in the automotive baseline, and why none of it is a bug

- **`Volatile_Atomic_Consistency` (161)** — "volatile declaration has no
  atomic/full-access policy". The SVD peripheral *records* carry `Volatile`, and
  the policy lives where it matters: **1,551 register types carry
  `Volatile_Full_Access`**. The rule flags the enclosing record, which does not
  need it. The driver-side cases are plain aligned 32-bit scalars, where volatile
  alone already yields a single load. Kept anyway: a *new* volatile declaration
  without a policy is worth being told about.
- **`Global_Contract_Mismatch` (31, all in `libs/tls`)** — "global `One` is read
  but its Global contract mode does not allow it". `One` is a *constant*; under
  SPARK RM 6.1.4 a constant without variable inputs is not a Global item, so
  `Global => null` is correct. gnatprove, which actually proves that package,
  agrees.
- **`Non_Short_Circuit_Condition` (8)** — all plain Booleans with no side effects
  (`RINT_Bits` is a single register snapshot, so `or` reads nothing extra).
- **`Library_Level_Initialization` (15)** — library-level initializers containing
  calls, i.e. elaboration-order hazards. Worth watching in this repo specifically.
- **`Missing_Loop_Variant` (11)** — SPARK loops that prove partial correctness but
  not termination.
- **`Floating_Equality` (1)** — `if Magnitude /= 0.0` guarding a normalisation
  loop, where comparing exactly against zero is the correct test.

## Running it

`adalang_analyzer` is an [Alire](https://alire.ada.dev) community crate (a
Libadalang-based analyzer by Spazio IT, GPL-3), not part of the toolchain this
repo pins, so `./x test` deliberately does not run it — a plain clone would fail
a check it cannot perform. Install it yourself:

```sh
alr install adalang_analyzer          # installs into ~/.alire/bin
export PATH="$HOME/.alire/bin:$PATH"

./x analyze                           # all libraries, recommended set
./x analyze esp32s3_hal               # just one
./x analyze --automotive              # the correctness slice of the automotive profile
./x analyze --update-baseline         # accept the current findings
./x analyze --automotive --update-baseline
```

Exit status is non-zero when anything new appears, so it drops straight into a
hook or a CI job that installs the crate.

## Why these are baselines and not a to-do list

The findings behind these fingerprints were triaged in full in September 2026:
953 of them across 381 files, and **not one was a real defect**. Each
high-severity class turned out to be a systematic false positive with an
identifiable cause:

| Class | Why it fires here |
|---|---|
| `Uninitialized_Read` | the variable is written through an `Asm` output constraint, which the analyzer does not model |
| `Use_After_Free` | every `Free` is followed by `return` or `raise`; those are not treated as ending the path |
| `Uninitialized_Output` | the initialise-outs-then-early-return idiom |
| `Overwritten_Assignment`, `Dead_Store` | defensive `out`-parameter initialisation; array-element reads through an indexed loop are not tracked |
| `Exception_Swallowed` | deliberate best-effort `Close_Socket`, and "one bad client never kills the server" |
| `Swappable_Parameters` | crypto operands (`A, B : Blk`) — 415 of them, pure noise on this codebase |
| `Aliasing_Between_Parameters` | real aliasing in `ESP32S3.SIMD`, but safe: the kernel reads each 16-byte lane before writing the matching output lane |

So do not treat a baselined finding as a known bug. If a **new** one appears,
triage it on its merits; if it is more of the same noise, re-baseline.

## What the tool is actually good for here

The empty rule classes, which is where the signal was: across all four
libraries there are **zero** `Constant_Condition`, `Overlapping_Case_Ranges`,
`Duplicate_Boolean_Operand`, `Unreachable_Case_Alternative`, `Redundant_Abs`
and `Redundant_Unary_Minus` findings. Those are the rules that catch copy-paste
and logic errors. They are *not* in `--recommended`, so ask for them by name:

```sh
adalang_analyzer -Plibs/esp32s3_hal/esp32s3_hal.gpr -XESP32S3_RTS_PROFILE=embedded \
  -checks=Constant_Condition,Overlapping_Case_Ranges,Duplicate_Boolean_Operand,\
Unreachable_Case_Alternative,Shadowed_Declaration,Floating_Equality
```

It also earned its keep once already: it spotted that ten peripheral drivers had
each grown a private copy of the same GPIO-matrix routing helper, now
`ESP32S3.GPIO.Route_Out`.

## The profile trap

`./x analyze` always selects the **widest** profile a library supports, and you
should too when invoking the tool by hand. `esp32s3_hal.gpr` scopes
`Source_Dirs` to `("src", "svd")` under `light-tasking`, so analysing the
default profile silently covers 102 of its 329 files.
