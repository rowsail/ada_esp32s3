# adalang_analyzer baselines

Fingerprints of the static-analysis findings that were present when each
baseline was written. `./x analyze` filters them out, so it reports only what is
**new** — the point is a tripwire on regressions, not a clean-code claim.

## Two rule sets, two baselines

`./x analyze` runs the **defects** set against `<lib>.baseline`.
`./x analyze --style` runs the readability set against `<lib>.style.baseline`.
They enable different checks, so neither baseline can stand in for the other.

The defects set is `--recommended` **plus ten checks that preset does not
enable** (`ANALYZE_EXTRA_CHECKS` in `./x`). Six of those ten normally find
nothing at all — `Constant_Condition`, `Overlapping_Case_Ranges`,
`Duplicate_Boolean_Operand`, `Unreachable_Case_Alternative`,
`Floating_Equality`, `Non_Short_Circuit_Condition` — which is exactly why they
are carried: zero baseline cost while they stay quiet, and they are the rules
that catch copy-paste and logic errors. The other four are
`Global_Contract_Mismatch`, `Volatile_Atomic_Consistency`,
`Library_Level_Initialization` and `Missing_Loop_Variant`.

### There used to be an `--automotive` mode

Those ten came from it. It is not worth a mode of its own: of its twelve checks
only **two** overlapped `--style` (`Redundant_Abs`, `Redundant_Unary_Minus`),
and the other ten are correctness rules, not conformance ones — so they belong
in the default gate rather than behind a flag nobody remembers to pass.

What is *not* carried is the rest of that profile, and the numbers are why. The
full `--automotive` profile reports **39,511 findings** across these four
libraries — 41x the recommended set — because most of it is MISRA/AUTOSAR
*restrictions* that a bare-metal register HAL cannot satisfy by construction:

| rule | n | why |
|---|---:|---|
| `Magic_Number` | 25,531 | every register offset and bit literal; 65% of the total |
| `Complete_Initialization` | 5,474 | "no explicit initializer" on `aliased X_Register` fields |
| `Naming_Convention` | 3,162 | a different house style |
| `Representation_Clause_Policy` | 1,671 | a register HAL is *made* of rep clauses |
| `Address_Clause` | 136 | memory-mapped registers are the whole point |
| `No_Dynamic_Allocation`, `No_Tasking`, `No_Controlled_Type`, … | 119 | this SDK ships three tasking profiles, controlled RAII sessions and a heap |

`Exception_Propagation` is deliberately excluded too, and the reason is a trap
worth recording: it reports only **12** findings under the full automotive
profile, but enabled on its own it reports **1,274** in the HAL alone. It fires
on every call that can transitively raise, which in a stack that signals errors
*with* exceptions (ext4 raises `No_Space` / `Corrupt` / `Use_Error` by design)
is very nearly every call. It is a restriction, not a defect detector.

### Why none of the folded-in findings are bugs

- **`Volatile_Atomic_Consistency` (161)** — "volatile declaration has no
  atomic/full-access policy". The SVD peripheral *records* carry `Volatile`, and
  the policy lives where it matters: **1,551 register types carry
  `Volatile_Full_Access`**. The rule flags the enclosing record, which does not
  need it. Kept anyway: a *new* volatile declaration without a policy is worth
  being told about.
- **`Global_Contract_Mismatch` (31, all in `libs/tls`)** — "global `One` is read
  but its Global contract mode does not allow it". `One` is a *constant*; under
  SPARK RM 6.1.4 a constant without variable inputs is not a Global item, so
  `Global => null` is correct, and gnatprove agrees.
- **`Non_Short_Circuit_Condition` (8)** — all plain Booleans with no side effects
  (`RINT_Bits` is a single register snapshot, so `or` reads nothing extra).
- **`Library_Level_Initialization` (15)** — library-level initializers containing
  calls, i.e. elaboration-order hazards. Worth watching in this repo specifically.
- **`Missing_Loop_Variant` (11)** — SPARK loops that prove partial correctness but
  not termination.
- **`Floating_Equality` (1)** — `if Magnitude /= 0.0` guarding a normalisation
  loop, where comparing exactly against zero is the correct test.

## `--style`: the readability view

`./x analyze --style` is the "is this code followable" view, as opposed to "is it
correct" (`--recommended`) or "does it conform" (`--automotive`). 34 checks, its
own baseline, **514 findings** — and **25 of the 34 currently find nothing**,
which is the good part: they cost no baseline entries while they stay quiet, and
each is a distinct way for code to become harder to read.

| what it surfaces | n | worst case |
|---|---:|---|
| `Shadowed_Declaration` | 204 | an inner name hiding an outer one |
| `Cyclomatic_Complexity` | 75 | **44** in `x509.adb:302` (threshold 10) |
| `Null_Statement` | 66 | `null;` with no effect |
| `Duplicate_Subprogram` | 53 | identical bodies |
| `Too_Many_Parameters` | 45 | **15** in `esp32s3-es8311.adb:63` (threshold 6) |
| `Deep_Nesting` | 45 | depth **10** in `esp32s3-ext4-journal.adb:31` (threshold 4) |
| `Unnecessary_Else_After_Return` | 17 | an `else` after a returning branch |
| `Ineffective_Operation`, `Identical_Branches`, `Redundant_Type_Conversion` | 9 | |

Thresholds are the tool's defaults (complexity 10, nesting 4, parameters 6) and
are adjustable with `-complexity-threshold`, `-nesting-threshold` and
`-parameter-threshold` if the baseline should be tightened over time.

### Four rules deliberately left out, having read their findings

The set was chosen by **measuring all 126 checks**, not by reading names. These
four sound like exactly what a style mode wants, and are not:

| rule | n | why not |
|---|---:|---|
| `Naming_Convention` | 1,868 | every single one is the *same* objection — "one-character identifier used" (`R`, `V`, `I`, `K`). One house-style disagreement repeated, not 1,868 insights. |
| `Magic_Number` | 2,940 (hand-written) | spread over 185 files. Register and protocol constants are this codebase's idiom, and the count grows with every driver. |
| `No_Multiple_Return` | 180 | single-exit dogma. An early return is usually the *clearer* construct. |
| `Long_Line` | 490–778 | hand-written source is already inside any sane limit — p99 is **90** columns and **nothing exceeds 120** — so every finding comes from generated `svd/`. Formatting is gnatformat's job. |

Some checks (`Duplicate_Subprogram`, `Identical_Branches`, `Ineffective_Operation`,
`Redundant_Type_Conversion`) appear in both this baseline and the recommended one.
That is deliberate: `--style` is meant to stand alone as a view, so fixing one of
those means re-baselining both.

## DO-178C: a report, not a gate

`./x analyze --do178c[=A|B|C|D]` writes a per-objective evidence report per
library into `build/do178c/` (gitignored). There is **no DO-178C baseline**, and
that is deliberate.

Level A reports 9,551 findings here, and the breakdown is the argument:

| category | n | |
|---|---:|---|
| process / evidence obligations | 8,756 | `Missing_Requirement_Trace` (1,866 — "subprogram has no DO-178C low-level requirement trace"), `Complete_Initialization` (5,474), `Missing_Depends_Contract` (821), `Missing_Global_Contract` (595) |
| restrictions | 307 | `No_Compiler_Extensions`, `No_Dynamic_Allocation`, `No_Dispatching_Call`, … |
| already covered by the two modes above | 368 | `Uninitialized_Output`, `Dead_Store`, `Function_Side_Effect`, … |
| **genuinely additive** | **120** | `Cyclomatic_Complexity` (75), `Deep_Nesting` (45) |

Those last 120 are the only part worth gating on, and they are now in the
`--style` set, where they are stable. Everything else either
duplicates an existing mode or grows with every subprogram written — a baseline
over `Missing_Requirement_Trace` would need rewriting on every commit and would
signal nothing.

Two things worth knowing about the profile:

- **Levels A and B enable the identical rule set**; they differ only in the
  recorded structural-coverage objective (MC/DC vs decision). C is a 5-rule
  subset at statement coverage. **D enables nothing at all.**
- **`No_Compiler_Extensions` and `Missing_Loop_Variant` contradict each other**:
  the first flags `pragma Loop_Invariant` as implementation-defined, the second
  demands the matching `pragma Loop_Variant`. Both are in the Level A profile.

The report is worth generating anyway because it is honest about its own limits.
It states its scope up front ("verification support only; not a compliance
determination"), notes that its objective labels are the tool's own
non-normative paraphrase rather than DO-178C's normative text, and lists what it
cannot speak to at all: structural coverage, requirements-based testing,
object-code verification, and DO-330 tool qualification. Treat it as evidence
*input* for a certification process, never as a result.

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
./x analyze --update-baseline         # accept the current findings
./x analyze --style                   # readability: complexity, duplication, clarity
./x analyze --style --update-baseline
./x analyze --do178c                  # DO-178C evidence reports -> build/do178c/
./x analyze --do178c=C tls            # one library, at Level C
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
