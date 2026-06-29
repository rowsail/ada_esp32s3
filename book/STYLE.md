# Writing the book — house style

The chapters are meant to be *read*, not just referred to — but several have drifted
into over-compressed, hard-to-parse prose (heavy noun phrases, inverted sentences,
verbs stranded from their subjects). This note is the bar. The goal in one line:

> **Manual-grade clarity, civilian warmth.** Write at the sentence level like a good
> technical manual — short, active, one idea at a time. Keep the book's narrator at
> the paragraph level.

Borrow the *discipline* of a Simplified Technical English manual (ASD-STE100); do
**not** borrow its flat, impersonal register. The engaged voice — the
`From C / ESP-IDF` asides, the concrete examples, the occasional wry line — is an
asset and stays. The fix is at the sentence, not the personality.

## The reader

Assume one specific person:

> An experienced **C / systems programmer**, new to Ada and to bare-metal work.
> Technically fluent — knows what a stack, a cache, an interrupt is — but **not**
> expected to untangle clever syntax.

So: you *may* assume the domain knowledge. You may **not** assume the reader will
parse a 30-word sentence with three embedded clauses. When in doubt, the reader knows
the subject and not your sentence — fix the sentence.

## The target

A measurable bar, the way a manual sets one:

- Sentences **under ~25 words**. Split anything longer; there is almost always a full
  stop hiding in it.
- Roughly **US reading grade 10–12**. Plain words win.
- One idea per sentence; one topic per paragraph.

## The rules

1. **Active voice, subject–verb–object.** Name the actor, then say what it does.
   *"A restricted runtime's guarantees attach to the package"* — not *"the package is
   where the guarantees … attach."*

2. **Keep subject and verb together.** Do not bury the verb behind an embedded clause.
   The reader holds the subject in memory waiting for the verb; the longer the wait,
   the clumsier.
   - Bad: *"The package is also where the guarantees a restricted runtime cares about
     attach."* (verb `attach` is five words from its subject, and stranded)
   - Good: *"A restricted runtime's guarantees attach to the package, too."*

3. **No fronted `where … <verb at the end>` with a heavy subject.** This inversion is
   fine with a *light* subject (*"the package is where elaboration runs"*) and breaks
   with a heavy one. It is the single most common tell in this book — see *The tells*.

4. **Lead with the topic, not a long modifier.** Don't open a sentence with a clause
   the reader must hold until the real subject arrives.

5. **One term per concept; define it once, reuse it.** Do not elegantly-vary
   (`callback` / `hook` / `handler` for the same thing). Expand every acronym at first
   use (the glossary is the backstop, not the first line of defence).

6. **Plain word over clever word.** If a flourish costs the reader a beat of
   comprehension, cut it. Vivid is good; cute-but-slow is not.

7. **Prefer a full stop to a dash/semicolon chain.** Two ideas joined by `--` or `;`
   are often two sentences. Chain at most two clauses; a third idea starts a new
   sentence.

8. **Read it aloud.** If you run out of breath, backtrack, or have to re-read to find
   the verb, the sentence fails — rewrite it.

## Connectives: so, because, and, but

- **Keep the causal `so`** (*"the spec is fixed, so clients don't recompile"*). It is
  the plainest way to show consequence and fits the warm register; `therefore` /
  `thus` are stiffer and colder. Do **not** hunt it down — the book uses it well.
- **Starting with `Because` (or causal `So`) is fine**, as long as the sentence
  *completes*: *"Because clients see only the spec, the body can change freely."* The
  "never start with because" rule is a myth; it only guards against fragments
  (*"Because it was raining."* — no main clause). `And` / `But` openers are allowed
  too, and often crisper than "Additionally" / "However" — sparingly.
- **Vary the causal forms.** *"X, so Y"*, *"Because X, Y"* and *"Y because X"* say the
  same thing with different emphasis — front the cause when the cause is the point.
  Don't open three sentences running the same way.
- **Prune only the intensifier `so`** (*"so cleanly," "so important"*): name the
  specific thing or cut it. (*"so far"* = "up to now" is a fine idiom, not an
  intensifier.)

## Keep the voice (do not strip these)

- The `\cnote{...}` **From C / ESP-IDF** asides.
- The em-dash gloss that *defines in passing* — *"a PDU — a function code and its
  data"* — used in moderation (rule 7 still applies).
- A warm topic sentence, a concrete worked example, a dry aside. Personality lives at
  the paragraph level; clarity is enforced at the sentence level.

## The tells (grep / read for these)

When editing, these patterns are where clumsiness hides:

- A fronted **`where` / `what` / `how`** clause whose verb lands at the very end, far
  from its subject (rule 3).
- A sentence **over ~30 words** — almost always splittable.
- **Stacked reduced relatives**: *"the X a Y does Z"* — a dropped `that` plus a
  delayed verb.
- **Three or more `--` / `;` segments** packing several ideas into one sentence
  (rule 7).
- **Nominalised "is the place/way where X happens"** instead of *"X happens"* (rule 1).

## Process

1. This standard first (you are reading it).
2. Pilot it on the **Packages** chapter (`ch_packages.tex`) as the worked example.
3. Then sweep chapter by chapter, using *The tells* as the checklist so the edits are
   mechanical and reviewable, not subjective.
