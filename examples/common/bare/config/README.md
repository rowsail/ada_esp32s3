# Board config — per-project flash & PSRAM size

Each **project** owns its `board.ads` at its root (flash + PSRAM size); there is no
global board config. The files here are the **SDK default**:

- **`board.ads`** — the default values, used only as (1) the host tools' compiled-in
  fallback and (2) the baseline the prebuilt default bootloader matches.
- **`board.ads.template`** — what `esp32-ada init` / `./x new` copy into a new project.

```ada
package Board is
   Flash_Size : constant := 2 * 1024 * 1024;   --  total SPI flash
   PSRAM_Size : constant := 2 * 1024 * 1024;   --  external PSRAM mapped @0x3D000000
end Board;
```

`bare_build.sh` reads the **project's** `board.ads` (its root; older `config/board.ads`
still works), derives `board_config.{h,env}` into the project's `.noidf/`, and either
reuses the SDK default bootloader (when `PSRAM_Size` matches) or builds a project-specific
one. Edit a project's file directly or via `./x config <example> …` / `esp32-ada config …`.

## Who reads it

| Consumer | How |
|---|---|
| `elf2image` (Ada) | `--flash-size <bytes>` from the project (compiled-in `Board.Flash_Size` = fallback only) |
| `esp_flash` (Ada) | `--flash-size <bytes>` from the project (fallback `Board.Flash_Size`) |
| bootloader `boot_psram.adb` (Ada) | `build.sh` reads `BOARD_PSRAM_PAGES` (= `PSRAM_Size`/64 KB) out of `board_config.h` and generates a `board_cfg.ads` on the bootloader's source path |
| build/flash scripts (shell) | source the project's `.noidf/board_config.env` → `BOARD_*` |

`gen_board_config.sh <board.ads> <outdir>` derives `board_config.{h,env}`; the
generated files (and per-project copies under `.noidf/`) are git-ignored.

## Notes / scope

- **Changing `PSRAM_Size`** is picked up automatically: the next `./x build` (or
  `bare_build.sh`) rebuilds + re-vendors the IDF-free 2nd-stage bootloader (it is
  what maps PSRAM at boot), so `./x flash` uses the updated one. The psram example's
  own data window (`examples/esp32s3_psram/psram.ld`) is an independent
  reservation; keep it `<= PSRAM_Size`.
- **`Flash_Size`** is a runtime hint (the real chip size is auto-detected); it sizes
  the image header and the `SPI_SET_PARAMS` geometry.
- **Processor selection is out of scope** here — it's a deeper retarget (dynconfig
  `.so`, linker scripts, `start.S`, register addresses) and lives in the build
  scripts / runtime, not this file.
