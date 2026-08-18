# The getting-started guide

A static, 56-step HTML walkthrough — from a blank machine to your own Ada
application — with a collapsible sidebar and prev/next on every page. No
JavaScript, no external requests, one stylesheet.

## Layout

```
docs/
  build.py                      the prose + the generator  (edit this)
  check_samples.sh              compile the samples, check the API, validate the HTML
  samples/                      real, compilable Ada, inlined into the pages
  adaformicrocontrollers.com/   THE SITE — generated, and nothing but publishables
```

**Everything that gets published lives in `adaformicrocontrollers.com/` and
nothing else does.** That is the point of the split: putting the site online is a
plain directory copy with no include/exclude filter to get wrong. An earlier
filtered upload silently dropped `ada.svg` and shipped a broken logo on every
page.

## Regenerating

The prose lives in `build.py`; the `.html` files are generated from it so the
navigation, step numbers and contents stay consistent. Edit the prose there,
then:

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
