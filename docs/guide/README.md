# The getting-started guide (`docs/guide/`)

A static, 17-step HTML walkthrough — from a blank machine to your own Ada
application — with a sidebar table of contents and prev/next on every page. No
JavaScript, no external requests, one stylesheet. Open `index.html` in a browser,
or serve the directory; it is also ready to publish as GitHub Pages as-is.

## Regenerating

The prose lives in `build.py`; the `.html` files are generated from it so that
the navigation, step numbers and table of contents stay consistent. Edit the
prose there, then:

```sh
python3 docs/guide/build.py
```

It rewrites every page plus `index.html` and `style.css`, and deletes pages left
behind by a renamed or removed step.

## Checking

```sh
./docs/guide/check_samples.sh
```

Two passes, both fast:

1. **Compile** every unit in `samples/` against the `embedded` runtime with the
   HAL on the source path (`-gnatc`: semantic check only, no link and no board).
2. **Quote-check** the API names the driver pages document against the HAL
   specs, so a renamed subprogram fails here instead of confusing a reader.

It needs the cross toolchain and a generated runtime, so build any embedded
example once first (`./x build i2c_loopback`). It finds the compiler and the
`xtensa_esp32s3.so` dynconfig plugin itself.

## Why `samples/` exists

The Ada that steps 6, 13 and 15 display is **inlined from `samples/` at
generation time** — one copy of each program, and it is the copy that gets
compiled. The guide therefore cannot show Ada that does not build.

This is not theoretical. Compiling the samples caught two defects that reading
them had not:

- the I2C bus scan passed a `Slave_Address` (a `Natural` subtype) to `Put_Hex`,
  which takes an `Interfaces.Unsigned_32` — a type error;
- the UART ring buffer was shown without saying *where* it goes, and putting it
  in the obvious place (the procedure that calls `Enable_Buffered_Rx`) fails with
  `non-local pointer cannot point to local object`, because the RX ISR writes it
  and it has to outlive every scope.

Add a sample by dropping a compilable unit in `samples/` and referencing it from
a page body as `{{sample:its_name.adb}}`.

## Layout

```
build.py            the prose + the generator (edit this)
check_samples.sh    compile the samples, quote-check the API names
samples/            real, compilable Ada, inlined into the pages
style.css           generated
index.html          generated
NN-*.html           generated (17 steps)
```
