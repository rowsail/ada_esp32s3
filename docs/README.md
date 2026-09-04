# The getting-started guide

A static, 56-step HTML walkthrough — from a blank machine to your own Ada
application — with a collapsible sidebar and prev/next on every page. No
JavaScript, no external requests, one stylesheet.

## Layout

```
docs/
  pages/<slug>.html             THE PROSE — one HTML fragment per page (edit these)
  build.py                      the page table + the template + the generator
  check_samples.sh              compile the samples, check the API, validate the HTML
  samples/                      real, compilable Ada, inlined into the pages
  adaformicrocontrollers.com/   THE SITE — generated, and nothing but publishables
```

`build.py` holds the page **table** — slug, sidebar title, page title,
standfirst — and the template. That is what has to stay consistent across
pages, and it is the reason this generator exists. The prose is next door in
`pages/`, one fragment per page: `build.py` was ~6,000 lines when the two lived
together, and a wording change was a diff against a `.py` that no editor
believed was HTML. The two halves are checked against each other — a page in
`PAGES` with no `pages/<slug>.html`, or a file in `pages/` that no page claims,
fails the build rather than publishing silently.

**Everything that gets published lives in `adaformicrocontrollers.com/` and
nothing else does.** That is the point of the split: putting the site online is a
plain directory copy with no include/exclude filter to get wrong. An earlier
filtered upload silently dropped `ada.svg` and shipped a broken logo on every
page.

## Regenerating

Edit the wording in `pages/<slug>.html`. To add, remove or reorder a page, edit
`PAGES` in `build.py` **and** add the matching `pages/<slug>.html` — the
navigation, step numbers and contents are all derived from that table. Then:

```sh
python3 docs/build.py
```

It rewrites every page plus `index.html` and `style.css` into
`adaformicrocontrollers.com/`, and deletes pages left behind by a renamed or
removed step.

## Checking

```sh
./docs/check_samples.sh
```

Three passes:

1. **Compile** every unit in `samples/` against the `embedded` runtime with the
   HAL on the source path (`-gnatc`: semantic check only, no link, no board).
2. **Quote-check** the API names the driver pages document against the HAL
   specs, so a renamed subprogram fails here rather than confusing a reader.
3. **Validate** the generated HTML: balanced tags, escaped entities, resolving
   `href`/`src`, and numbering consistency (a page's filename must agree with
   the step number it prints, and a routing-table row with the slug it links
   to).

Pass 1 needs the cross toolchain and a generated runtime, so build any embedded
example once first (`./x build i2c_loopback`).

## Publishing

Because the site folder holds only publishables, no filter is needed:

```sh
rsync -avz -e ssh docs/adaformicrocontrollers.com/ \
    dh_rud5qa@adaformicrocontrollers.com:adaformicrocontrollers.com/
```

`rsync` writes to a temp file and renames, so it overwrites rather than appends.
That matters: an FTP client left in *resume* mode once appended each upload to
the previous one, leaving every file a 2–6× concatenation of itself — which HTML
tolerated but SVG did not, because an SVG with three roots is invalid XML.

## Why `samples/` exists

The Ada shown in steps 6, 14 and 16 is **inlined from `samples/` at generation
time** — one copy of each program, and it is the copy that gets compiled. The
guide therefore cannot show Ada that does not build.

This is not theoretical. Compiling them caught two defects that reading them had
not: the I2C bus scan passed a `Slave_Address` (a `Natural` subtype) to
`Put_Hex`, which takes an `Interfaces.Unsigned_32`; and the UART ring buffer was
shown without saying *where* it goes, when putting it in the obvious place fails
with `non-local pointer cannot point to local object`.

Add a sample by dropping a compilable unit in `samples/` and referencing it from
a page body as `{{sample:its_name.adb}}`.

## The examples catalogue

Step 12 is generated from `./x list --json` — the dispatcher's own view, so the
guide and the tooling cannot disagree about which examples exist — with each
description lifted from the example's own header comment, falling back to its
README title. A new example appears in the guide by existing.
