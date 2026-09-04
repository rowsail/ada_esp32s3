# `libs/` — reusable Ada libraries (drivers, middleware)

Shared Ada libraries that **any** project — an in-repo example *or* a standalone
`esp32-ada` project anywhere on disk — uses with a single `with` in its `.gpr`, the
same way it uses the runtime. No copying, no `Source_Dirs`, no relative paths.

```
libs/
  esp32s3_hal/        the peripheral-driver HAL: ESP32S3.GPIO + the svd register layer
    esp32s3_hal.gpr   ->  with "esp32s3_hal.gpr";
    src/  svd/  …
  <your_lib>/         middleware, a logger, a CLI, a protocol stack, …
    <your_lib>.gpr    ->  with "<your_lib>.gpr";
    src/
```

## Using a library

In the consuming project's `.gpr`:

```ada
with "esp32s3_hal.gpr";          -- standalone: by name, via GPR_PROJECT_PATH (export.sh)
-- in an in-repo example, use the relative form so ALS needs no environment:
with "../../libs/esp32s3_hal/esp32s3_hal.gpr";
```
then in the code, `with ESP32S3.GPIO;` (etc.). `gprbuild` compiles only the units in
your `main`'s closure, so unused library code costs nothing in `app.bin`.

`esp32-ada init` / `./x new` already add the HAL `with` to a new project's `app.gpr`.

## Adding a new library

1. `mkdir libs/<name>` with a `src/` and any other source dirs.
2. Add `libs/<name>/<name>.gpr` modelled on `esp32s3_hal/esp32s3_hal.gpr`:
   ```ada
   with "../../crates/esp32s3_rts/esp32s3_rts.gpr";
   project <Name> is
      for Target use "xtensa-esp32-elf";
      for Runtime ("Ada") use Esp32s3_Rts.Runtime_Path;
      for Source_Dirs use ("src");
      for Object_Dir use "obj-" & external ("ESP32S3_RTS_PROFILE", "light-tasking");
   end <Name>;
   ```
3. That's it — **no build-script edits**. `export.sh` and `bare_build.sh` discover
   `libs/*/` automatically and put each on `GPR_PROJECT_PATH`, so projects can
   `with "<name>.gpr";` immediately (re-`source export.sh` in an existing shell).
4. `./x test lib` picks the new library up automatically too. It builds every
   `libs/*/<name>.gpr` on each profile the project supports — read from the
   default of its own `external ("ESP32S3_RTS_PROFILE", ...)`, so the `.gpr`
   above (defaulting to `light-tasking`) is claiming it works on all three;
   default it to `"embedded"` if the library needs finalization, exceptions or
   the secondary stack. **Warnings fail that build**, so prefer
   `("-O2", "-g", "-gnatwa", "-gnatwJ", "-gnatw.V")` in its `Compiler` package
   (what `esp32s3_hal.gpr` and `tls.gpr` use, and what their headers explain).

The per-profile `Object_Dir` (`obj-<profile>`) keeps a library's objects separate
across runtime profiles, since the same library is shared by many consumers.
