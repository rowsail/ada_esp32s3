# Writing an example — house style

The examples are documentation as much as code: people read them to learn the
HAL and the runtime. Write them to be understood on first read, with no need to
open the README or the book to follow along. This note is the bar; the cleanup
sweep brought the older examples up to it, and `./x new` / `esp32-ada init`
scaffold a new one already in this shape.

Reference examples to imitate: **`esp32s3_gdma_copy`** (a terse, clear driver
self-test) and **`esp32s3_full_tasking`** (a fuller header where the concept
needs it). **`esp32s3_gpio0_blink`** is the minimal end.

## The rules

1. **Open with a header comment** that answers, in order:
   - **What it demonstrates** — the one feature or driver, in a sentence or two.
   - **Build & run** — the `./x run <name>` line, and the profile if it is not
     the default light-tasking (e.g. "needs the full profile; build.sh sets
     `ESP32S3_RTS_PROFILE=full`").
   - **How to read the output** — what the console prints and what PASS looks
     like; note any line that only appears under a non-default condition.
   - **Hardware / wiring** — pins, external parts, loopback jumpers; "none
     (self-contained)" if there is no external hardware.
   Keep it proportional: a blink is three lines, a TLS client is a paragraph.

2. **Name every magic constant.** No bare `16#...#` / unexplained literal in the
   logic. Give it a `constant` with a comment on what it *is*:
   ```ada
   --  External-RAM (PSRAM) cache window on the S3 data bus.
   PSRAM_Window_Lo : constant Integer_Address := 16#3C00_0000#;
   ```
   The same goes for tuning numbers (PRNG multipliers, timeouts, register bit
   masks): name them, and say where they came from.

3. **Give known-answer / vector data a legend and a provenance.** Conventional
   terse names (crypto `K`/`IV`/`P`/`C`/`T`) are fine, but add a one-line legend
   mapping them, and cite where the vectors came from (a NIST file + count, or
   the exact script), so a reader can regenerate and trust them.

4. **One statement (and one declaration) per line.** No `A; B; C` packed onto a
   line, no single-line subprogram bodies. It reads slower than it saves.

5. **Spell names out — an abbreviation is not a name.** Anything carrying
   meaning gets a full, readable identifier: `Expander_Status`, not `ESt`;
   `Block_Device`, not `BD`; `Signed`, not `Sgn`; `Card_Status`, not `St`. Do
   **not** keep a cryptic short name and paper over it with a trailing comment —
   rename it. The only short names allowed are loop indices (`I`, `J`, `K`) and
   widely-recognised domain tokens that read *better* short than long: `Ok`,
   `Buf`, `MAC`, `DER`, `CRLF`, an I2C `SDA`/`SCL`, a protocol's own identifier
   (NMEA `GGA`/`RMC`). When in doubt, write it out. The same goes for a package
   rename: `package Expander renames ESP32S3.CH422G;` beats `package CH ...`.

6. **No mysterious names.** A name must say what the thing *is* or *does*, so a
   reader never has to hunt for its meaning. No opaque placeholders (`Data`,
   `Tmp`, `Thing`, `X`, `Val2`), no single letters outside a loop index, and no
   invented codename or tag whose meaning lives only in your head or in another
   file. The test: if learning what a name refers to means scrolling away, opening
   the datasheet, or running the code to watch what it holds, it is mysterious —
   rename it to the thing it actually is. (This is the flip side of rule 5:
   rule 5 forbids *shortening* a real name; this forbids a name that carries *no
   meaning* to shorten.)

7. **Put the "why" in the code, not only the README.** If understanding a line
   needs a fact (why this address means PSRAM, why this delay, why this order),
   state it inline. The example should stand alone.

8. **Don't change documented output to suit the rewrite.** Console strings that
   the example's README quotes are a contract — preserve them verbatim. Improve
   the code around them.

## Libraries: two conventions the examples rely on

These bind library APIs (`libs/`), which the examples then get to trust.

9. **One error vocabulary per layer.** A library API reports failure through a
   **status enumeration** (`MQTT.Client.Status`, `Net_Devices.Status`) — an enum
   names *what* went wrong and lets a caller `case` over it. A bare `Boolean`
   out-value is allowed only for a genuinely binary fact (`Resolve` either
   produced an address or did not); the moment two failure causes exist that a
   caller might treat differently, it must be an enum. **Exceptions are confined
   to the `GNAT.Sockets` facade**, whose contract mirrors desktop GNAT.Sockets
   (`Socket_Error`) so the same sources compile natively — and every library
   sitting on the facade must therefore catch `Socket_Error` on *every* socket
   call path, send included: unhandled, it is a board reset, not an error
   report. (Measured: a dead route once escaped `DNS_Client` through an
   unguarded `Send_Socket` and reboot-looped the board mid-failover.)

10. **State the concurrency contract at the spec.** Bare-metal code often
   relies on "one task owns this object" — fine, but write it down: what may
   be shared, what needs external serialisation, and what the library locks
   internally (the BG95's transaction lock; the socket pool's protected
   claim/release). If a package keeps benign global state (a port rotor, a
   transaction-id counter), say what concurrent use does to it.

## Before you commit

- Build it: `./x build <name>` (and on its real profile if non-default).
- If you touched an example with a README that quotes the console output, make
  sure the strings still match.
