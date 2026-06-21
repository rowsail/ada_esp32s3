# Research: a cross-platform IDE that scales down to a microcontroller

*Status: research / design note. Nothing here is built yet. The aim is to map
what it would take to build an editor + "external tools" IDE that runs across the
full spectrum — from a full desktop down to on a microcontroller with limited
memory — whose **defining feature is making it trivial to declare the external
tools that build / flash / run / monitor / debug a target.***

This note is grounded in what this repo already ships. The
[`./x` dispatcher](../TOOLING.md) plus the [VS Code](vscode-ada-esp32/) and
[Vim](vim-ada-esp32/) front-ends are, in miniature, exactly the architecture the
question is asking about: a single stable *actions* surface, wrapped by thin,
interchangeable editor integrations, with language intelligence delegated to a
separate server (ALS). The research below generalises that into a portable
design and compares a clean-room "tool definition" format against today's `./x`.

---

## 1. The core insight (already proven here)

[`TOOLING.md`](../TOOLING.md) states the principle the whole design rests on —
keep **two layers deliberately separate**:

1. **Language intelligence** (completion, diagnostics, go-to-def, hover) — comes
   from a *language server* (here, the Ada Language Server reading each `.gpr`).
   Works in any editor with an LSP client; no project-specific plugin needed.
2. **Actions** (build / flash / run / monitor / debug / clean / config) — come
   from *one stable command surface* (`./x`). Editors wrap these as tasks /
   launch configs; they never re-implement build logic.

Everything that follows is a generalisation of that split. The hard, valuable,
reusable parts (the build/flash logic, the language intelligence) live *outside*
any one editor. The editor is then a thin, replaceable shell — which is precisely
what lets the same idea run in VS Code, in Vim, and (the new ambition) on a
512 KB microcontroller.

The industry has independently converged on this "protocolise the hard part,
keep the editor thin" pattern three times over: **LSP** (abstract over
languages), **DAP** (abstract over debuggers), and **BSP** (abstract over build
tools). The missing fourth piece — and the heart of this request — is a
first-class, *declarative*, editor-agnostic way to **define the external tools**
themselves. That is the gap this design targets.

---

## 2. Prior art survey

### 2.1 Editor-agnostic protocols (the "thin editor" precedent)

| Protocol | Abstracts over | Client | Server | Relevance |
|---|---|---|---|---|
| **LSP** (Language Server Protocol) | programming *languages* | editor | language server | The model. One server (ALS) serves any LSP-capable editor. |
| **DAP** (Debug Adapter Protocol) | *debuggers* | editor | debug adapter | A debug server is written once, reused by every IDE. `probe-rs` ships a DAP server, so embedded debugging works in any DAP editor. |
| **BSP** (Build Server Protocol) | *build tools* | IDE / language server | build server | Complementary to LSP; lets an IDE ask a build tool to compile / run / test / debug without hard-coding the build system. |

The lesson: each protocol turned an **N editors × M tools** integration matrix
into **N + M**. The external-tool abstraction we want is the same move applied to
the "press a button → build/flash/monitor a board" workflow, which today every
embedded IDE re-implements per toolchain.

### 2.2 Tool / task definition models (the actual subject)

| System | Definition format | Verbs it knows | Notes |
|---|---|---|---|
| **VS Code `tasks.json`** | per-workspace JSON, declarative | arbitrary `shell`/`process` tasks + problem matchers | Editor-specific; not portable, but the *problem matcher* idea (regex → diagnostics) is worth stealing. |
| **PlatformIO `platformio.ini`** | declarative INI per project | build / upload / monitor / debug / test, per `[env:...]` | The closest existing thing to "declare a target, get build+flash+monitor+debug for free across 40+ platforms." Strong model; heavyweight (Python + SCons). |
| **`just` (justfile)** | declarative recipes, Make-like | arbitrary recipes w/ params, vars, env, OS detection | A *command runner*, not a build system — no timestamp tracking. Tiny, fast (Rust). Good ergonomic baseline for "easily define a tool." |
| **Cargo `runner`** | `.cargo/config.toml` key | `cargo run`/`test` delegate to a `runner` binary | One line turns `cargo run` into "flash + run on device" (this is how `probe-rs run` works). Minimalism worth noting. |
| **probe-rs / `cargo-embed`** | TOML (`Embed.toml`) | flash, GDB server, RTT terminal, reset | A *unified host tool*: one binary does flash + monitor (RTT) + debug for many probes/chips, and exposes DAP. Proof the verbs collapse into one tool. |
| **this repo's `./x`** | imperative Bash + `--json` discovery | list / new / build / flash / run / monitor / clean / config / debug | Stable surface, machine-readable discovery. The "tool definitions" are *hard-coded in Bash*; there is no data format a third party edits to add a target. |

### 2.3 Editor architectures that decouple core from front-end

- **Neovim** — the editor core speaks **MessagePack-RPC**; any process that can
  speak it can drive or *be* the UI. `nvim --embed` is a headless core; GUIs
  (Neovide, goneovim) and `vscode-neovim` are all just RPC clients. This is the
  canonical "one core, many front-ends, even remote" design.
- **Xi editor** — an explicit Rust *core* / front-end split over JSON-RPC. It
  proved the model is elegant but also that a *too-chatty* core↔UI protocol hurts
  latency — a cautionary tale for the on-device tier where every byte and context
  switch costs.
- **kilo** (antirez) — a complete terminal editor in **<1000 lines of C**, no
  ncurses, talking raw VT100 escapes. No external dependencies. This is the
  existence proof for the *bottom* of our spectrum: a usable editor core fits in
  a few KB of code and very little RAM.

### 2.4 Editors that already run *on* a microcontroller

- ESP32 "word processor" / **Micro Journal** style builds: a text editor running
  on the ESP32 itself, files on a microSD or synced to the cloud, simple key
  bindings (new file / save). These exist and work today.
- The constraint that shapes everything on-device: an ESP32(-S3) has ~**320 KB
  DRAM + 200 KB IRAM** of SRAM (≈160 KB statically allocatable, the rest heap);
  external **PSRAM** (this board has 8 MB) is the only way to hold a non-trivial
  edit buffer. The standard trick is to keep the working buffer in RAM/PSRAM and
  flush to flash/SD on a size/time threshold to spare flash write cycles.

**Takeaway:** every layer of this idea has a working precedent. Nobody has put
them together as *one portable design with a declarative external-tool format
that degrades gracefully from desktop to on-device.* That assembly is the
contribution.

---

## 3. The external-tool abstraction (the heart of the request)

### 3.1 Greenfield: a declarative "toolfile"

Define targets and the tools that act on them as **data**, not code, so a new
target needs no plugin and no Bash. A strawman (TOML; YAML/JSON-equivalent):

```toml
# ide.toml — one target, all five verbs declared as data
[target.esp32s3]
display = "ESP32-S3 (USB-JTAG)"
vars    = { port = "${env:ESPPORT:-/dev/ttyACM0}", elf = "app.elf" }

[target.esp32s3.build]
run     = "./x build ${example} --profile ${profile}"
problem = "gnat"            # named problem matcher → diagnostics

[target.esp32s3.flash]
run     = "./x flash ${example} -p ${port}"
needs   = ["build"]         # dependency / ordering

[target.esp32s3.monitor]
run     = "./x monitor -p ${port}"
kind    = "serial"          # frontend may attach a serial console widget
baud    = 115200

[target.esp32s3.run]
sequence = ["build", "flash", "monitor"]   # compose verbs

[target.esp32s3.debug]
kind     = "dap"            # frontend speaks DAP, not a raw command
adapter  = "gdb"
server   = "./tools/openocd.sh"            # how to bring up the gdbserver
gdb      = "./tools/gdb/.../xtensa-esp32s3-elf-gdb"
elf      = "${elf}"
```

Design properties that make tools *easy to define* and *portable*:

- **Five canonical verbs** — `build`, `flash`, `run`, `monitor`, `debug` — plus
  housekeeping (`clean`, `config`, `list`). These are the verbs the front-ends'
  buttons bind to; the names are fixed so a frontend never learns project-specific
  vocabulary. (This is exactly the set `./x` already exposes.)
- **Verbs are either a command or a protocol.** `build`/`flash`/`clean` are just
  commands. `monitor` declares a *kind* (`serial`/`rtt`/`log`) so a capable
  frontend can render it richly and a dumb one can just spawn it. `debug`
  declares `kind = "dap"` and defers to **DAP**, reusing the entire existing
  debugger ecosystem instead of reinventing it.
- **Variable substitution + capability negotiation.** `${example}`, `${port}`,
  `${profile}`, `${env:…}` keep the file declarative; the runner resolves them.
  A frontend advertises what it can do (serial widget? DAP? problem matchers?)
  and the runner degrades (e.g. no DAP → fall back to a raw `gdb` in a terminal,
  the same fallback `./x debug` already implements).
- **Machine-readable discovery is mandatory, not bolted on.** `runner list
  --json` / `runner describe <target> --json` so *any* frontend (or an LLM, or a
  CI script) can populate menus with zero hard-coding. This repo already does
  this (`./x list --json`, `./x config --json`) and both the VS Code and Vim
  front-ends consume it — proof the contract works.
- **Problem matchers** (named regex → `file:line:col: severity: msg`
  diagnostics) so build output becomes navigable even without a language server.
  The GNAT matcher already used in `.vscode/tasks.json` is the template.

### 3.2 How today's `./x` maps onto it (the comparison asked for)

| Concern | `./x` today | Proposed toolfile |
|---|---|---|
| Where tools are defined | hard-coded in `x` (Bash `case` per subcommand) | declarative `ide.toml` data, per target |
| Adding a new board/target | edit Bash, ship a new `x` | add a `[target.*]` block; no code |
| Verb set | list/new/build/flash/run/monitor/clean/config/debug | same five canonical verbs + housekeeping |
| Discovery | `./x list --json`, `./x config --json` | `runner list/describe --json` (generalised) |
| Variable handling | env vars (`$ESPPORT`, `ESP32S3_RTS_PROFILE`) + flags | `${…}` substitution incl. `env:` and defaults |
| Debug | bespoke OpenOCD+GDB orchestration in Bash, with fallbacks | `kind="dap"` → reuse DAP; raw-gdb fallback retained |
| Monitor | picks miniterm/picocom/screen/cat at runtime | `kind="serial"` + baud; frontend or runner picks |
| Frontends | VS Code ext + Vim plugin call `./x` | same frontends call the generic runner |
| Portability of the *logic* | tied to Bash + a POSIX host | runner is the only thing that must be ported per host |

**The pragmatic path:** `./x` is *already* the runner; it is just imperative and
single-project. The migration is (a) teach `x` to read an `ide.toml` so targets
are data, and (b) keep `--json` discovery as the stable contract. The VS Code and
Vim front-ends barely change because they already speak "call the dispatcher,
parse its JSON." In other words, the greenfield design and the existing model are
*the same architecture at different levels of generality* — which is the strongest
possible evidence the design is right.

### 3.3 Where this differs from BSP

BSP already standardises "IDE ↔ build tool." Why not just adopt it? BSP is
JSON-RPC, stateful, and assumes a long-lived server connection — appropriate on a
desktop, **too heavy for the on-device tier** and overkill for "shell out to a
flash command." The toolfile above is deliberately a *static declaration* that a
~1-file runner can interpret with no live server. On capable hosts the runner can
*additionally* speak BSP/LSP/DAP outward; on the microcontroller it interprets
the same toolfile with a few hundred lines of C. **One declaration, two
execution strategies** is what buys the spectrum.

---

## 4. The cross-platform / memory spectrum

Treat "runs everywhere" as **tiers of the same core**, each dropping capabilities
the previous one assumed, never forking the codebase.

```
        ┌─────────────────────────── shared, portable EDITOR CORE ───────────────────────────┐
        │  buffer/rope · cursor/selection · undo · file I/O · keymap · toolfile interpreter    │
        └───────▲──────────────────────────▲───────────────────────────────▲──────────────────┘
                │ frontend API (draw cmds / RPC)                            │
   ┌────────────┴───────┐      ┌────────────┴────────────┐       ┌──────────┴───────────────┐
   │  Tier 0: Desktop   │      │  Tier 1: TUI / modest    │       │  Tier 2: On-device (MCU)  │
   │  GUI or VS Code/   │      │  host, SBC, Raspberry Pi  │       │  ESP32-S3 + screen/serial │
   │  Vim front-end     │      │  (terminal, VT100)        │       │  edit buffer in PSRAM     │
   │  LSP+DAP+BSP out   │      │  LSP optional, DAP via    │       │  no LSP; toolfile run    │
   │  full toolfile     │      │  external tool            │       │  *on-host over the wire* │
   └────────────────────┘      └───────────────────────────┘      └───────────────────────────┘
```

### Tier 0 — Desktop (full)
Either reuse an existing host (the path this repo took: VS Code + Vim front-ends
over `./x` + ALS) or a dedicated GUI. Speaks LSP/DAP/BSP outward; runs the full
toolfile locally; rich problem matchers, serial/RTT widgets, integrated debugger.
**This already exists here.**

### Tier 1 — TUI on a modest host / SBC
A terminal editor in the spirit of **kilo**: VT100, no heavy GUI toolkit, small
binary. Same core, same toolfile, same `--json` discovery. Language features are
*optional* (attach an LSP if the host can afford it; otherwise rely on problem
matchers for navigable errors). Debug via the external `gdb`/DAP tool, exactly
like the Vim front-end's `termdebug` path already does. Runs comfortably on a Pi.

### Tier 2 — On-device (the hard, defining tier)
The editor runs *on the MCU* (this repo's whole runtime + HAL + ext4 FS make this
plausible — there is already on-device storage and a console). Realities:

- **Memory:** keep the active edit buffer in **PSRAM** (8 MB here), not the
  scarce ~320 KB SRAM; a rope/gap-buffer over PSRAM with an SRAM-resident working
  window. Flush to the **ext4 SD card** (this repo's filesystem) on a size/time
  threshold to spare flash. kilo-class footprint (single-digit KB of code) is the
  budget.
- **Display/input:** the existing **LCD (i80)** driver + a USB/serial or matrix
  keyboard; or, with *no* screen, edit over the **serial monitor** itself
  (line-oriented). The "Micro Journal"/ESP32-word-processor projects show this is
  viable.
- **The build/flash tools cannot run on the chip.** An MCU can't host GNAT/GCC.
  So at this tier the toolfile's verbs are **executed on a companion host over
  the wire**: the on-device editor sends "build/flash/monitor target X" to the
  same runner running on a paired PC (this is exactly Neovim's remote-core idea,
  and probe-rs's "debug on a separate host" model). The *editor* is on-device;
  the *toolchain* stays on the host. `monitor` is the one verb that is naturally
  on-device (it's the chip's own serial/RTT output).
- **What gets dropped:** no in-process LSP, no DAP client, no GUI toolkit;
  navigation via problem matchers and tags rather than semantic analysis.

### What scales, what is dropped

| Capability | Tier 0 | Tier 1 | Tier 2 |
|---|---|---|---|
| Edit buffer | unlimited | host RAM | PSRAM-backed, windowed |
| Toolfile interpreter | local | local | **remote (host) execution** |
| `monitor` (serial/RTT) | rich widget | terminal | native (chip's own UART) |
| Language intelligence | LSP (ALS) | LSP optional | none (matchers/tags) |
| Debug | DAP / GDB | external GDB | host-driven, view-only |
| Frontend | GUI / VS Code / Vim | VT100 TUI | LCD or serial line editor |

---

## 5. What it would take — a phased estimate

1. **Formalise the toolfile + discovery contract** (small). Define `ide.toml`'s
   schema and `runner list/describe --json`. Teach the existing `./x` to read
   targets from data instead of hard-coded Bash. *Leverages what's here; mostly a
   refactor.* This alone delivers the "easily define external tools" goal on the
   desktop.
2. **Stabilise the frontend contract** (small). Point the VS Code + Vim
   front-ends at the generic `--json` surface (they already nearly do). Document
   it so a third frontend is a weekend, not a rewrite.
3. **Tier-1 TUI editor** (medium). A kilo-class terminal editor that embeds the
   toolfile interpreter and discovery. No new toolchain work — it drives the same
   runner. Optional LSP/DAP client behind feature flags.
4. **Extract a portable core** (medium). Pull buffer/undo/keymap/toolfile-interp
   into a dependency-light library (C or `no_std`-friendly) with a frontend API
   that is *draw-commands out, events in* (Neovim's lesson) — but **batchy, not
   chatty** (Xi's lesson) so it survives a slow on-device link.
5. **Tier-2 on-device editor** (large, research-grade). Port the core onto this
   runtime: PSRAM-backed buffer, LCD/serial frontend, ext4 persistence, and a
   thin **wire protocol to a host-side runner** for build/flash/debug. This is
   where the real risk and the real novelty live.

Effort is front-loaded with low-risk wins (1–2 are mostly already done here) and
back-loaded with the genuinely hard, novel part (5).

---

## 6. Risks & open questions

- **On-device value vs. cost.** Editing source *on* the MCU is a striking demo,
  but the toolchain must stay on a host anyway — so is the win a true field-edit
  capability, or a novelty? Worth pinning down the actual use case (field tweaks?
  teaching? air-gapped labs?) before funding Tier 2.
- **Core/frontend protocol granularity.** Too chatty kills the on-device link
  (Xi); too coarse kills desktop responsiveness. The protocol must be tier-aware
  (batch redraws, coalesce events).
- **Language intelligence below Tier 0.** LSP is the right answer where it fits,
  but it is heavy. Need a credible "matchers + tags" fallback so Tiers 1–2 are
  not unusable.
- **Toolfile expressiveness vs. simplicity.** The whole pitch is "easy to define
  a tool." Every feature added to the format (conditionals, matrices, includes)
  erodes that. Hold the line at "declarative data + `${vars}` + named matchers;"
  escape to a script when you truly need logic (the `just`/Cargo-`runner`
  philosophy).
- **Don't reinvent DAP/LSP/BSP.** For language and debug, *adopt the standards*
  on capable tiers; only the **external-tool/verb layer** is genuinely missing
  and worth inventing.

---

## 7. Recommendation

The cheapest, highest-value first step is **not** to build a new editor — it is
to **promote `./x` from hard-coded Bash to a declarative-toolfile runner with a
stable `--json` discovery contract** (steps 1–2). That immediately delivers the
stated headline goal ("very easily define external tools to build/flash/run/
monitor/debug a target") on every desktop editor this repo already supports,
with almost no new surface area. The portable TUI core (3–4) is a natural,
low-risk follow-on that reuses that contract. Only the **on-device tier (5)**
needs real research — and even there, the architecture is "editor on the chip,
toolchain on a host," which keeps it tractable.

In short: the architecture the question asks for is the one this repo is *already
half-way to.* The work is generalising the tool layer into data and extracting
the editor core — not starting over.

---

## Sources

- [Build Server Protocol](https://build-server-protocol.github.io/) and its
  [FAQ](https://build-server-protocol.github.io/docs/overview/faq) — LSP/BSP/DAP
  relationship and the N×M→N+M motivation.
- [Debug Adapter Protocol overview (Scala)](https://www.chris-kipp.io/blog/the-debug-adapter-protocol-and-scala).
- [probe.rs](https://probe.rs/) · [cargo-embed](https://probe.rs/docs/tools/cargo-embed/)
  · [probe-rs debugger / DAP](https://probe.rs/docs/tools/debugger/) — unified
  host flash/RTT/GDB tool exposing DAP.
- [PlatformIO project config (`platformio.ini`)](https://docs.platformio.org/en/latest/projectconf/index.html)
  and [VS Code integration / task runner](https://docs.platformio.org/en/latest/integration/ide/vscode.html).
- [`just` command runner](https://github.com/RustWorks/just-command-runner) and
  [usage](https://developerlife.com/2023/08/28/justfile/) — declarative recipes,
  command-runner (not build-system) philosophy.
- [Cargo configuration `runner`](https://doc.rust-lang.org/cargo/reference/config.html).
- [Neovim Remote UI architecture](https://github.com/neovim/neovim/wiki/Remote-UI-architecture/17b74699e44531433a702f1e7b7a0904086c193a)
  — MessagePack-RPC core/frontend split, embeddable headless core.
- [Xi editor discussion](https://news.ycombinator.com/item?id=11576527) —
  Rust core / front-end JSON-RPC split and its latency lessons.
- [antirez/kilo](https://github.com/antirez/kilo) and
  ["Writing an editor in <1000 lines"](https://antirez.com/news/108) — minimal,
  dependency-free terminal editor (existence proof for the bottom tier).
- [ESP32 word processor / Micro Journal](https://www.hackster.io/news/this-esp32-runs-a-word-processor-complete-with-screen-and-keyboard-f8944a2157c4)
  and [Hackaday coverage](https://hackaday.com/2024/04/05/esp32-provides-distraction-free-writing-experience/)
  — editors running on the ESP32 itself.
- [ESP-IDF RAM usage](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/performance/ram-usage.html)
  and [memory types](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/memory-types.html)
  — the SRAM/PSRAM budget that constrains the on-device tier.
- This repo: [`TOOLING.md`](../TOOLING.md), the [`./x` dispatcher](../x), the
  [VS Code extension](vscode-ada-esp32/src/extension.ts), and the
  [Vim plugin](vim-ada-esp32/plugin/ada_esp32.vim) — the existing
  "ALS for language + `./x` for actions, thin front-ends" architecture this
  design generalises.
</content>
</invoke>
