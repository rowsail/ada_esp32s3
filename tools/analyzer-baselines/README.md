# adalang_analyzer baselines

Fingerprints of the static-analysis findings that were present when each
baseline was written. `./x analyze` filters them out, so it reports only what is
**new** — the point is a tripwire on regressions, not a clean-code claim.

## Running it

`adalang_analyzer` is an [Alire](https://alire.ada.dev) community crate (a
Libadalang-based analyzer by Spazio IT, GPL-3), not part of the toolchain this
repo pins, so `./x test` deliberately does not run it — a plain clone would fail
a check it cannot perform. Install it yourself:

```sh
alr install adalang_analyzer          # installs into ~/.alire/bin
export PATH="$HOME/.alire/bin:$PATH"

./x analyze                           # all libraries
./x analyze esp32s3_hal               # just one
./x analyze --update-baseline         # accept the current findings
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
