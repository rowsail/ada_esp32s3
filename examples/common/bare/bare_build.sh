#!/bin/bash
# Shared IDF-free build for the bare ESP32-S3 examples.  No ESP-IDF / idf.py:
# gprbuild the Ada against the pinned esp32s3_rts runtime, compile the shared
# bare-boot (bare_glue.c + bare_boot.adb) + the example's own glue.c + the
# from-source Xtensa support (vendor/), link with the vendored linker scripts,
# package with our own Ada elf2image (../elf2image).
#
#   $1 = example directory (must contain main/build_ada.sh; main/glue.c optional
#        -- examples that format output via ESP32S3.Log need no example C glue)
#   $2 = the example's Ada main symbol, e.g. _ada_example (GNAT "_ada_<mainunit>")
# Produces $1/app.bin; flash it with bare_flash.sh.
set -e
EX="$(cd "$1" && pwd)"
ADA_MAIN="${2:?usage: bare_build.sh <example-dir> <_ada_mainsym>}"
BARE="$(cd "$(dirname "$0")" && pwd)"          # examples/common/bare
REPO="$(cd "$BARE/../../.." && pwd)"           # repo root
VENDOR="$BARE/vendor"
# Xtensa headers (xtensa_context.h, xtensa/coreasm|corebits, xtensa/config/*) are
# VENDORED under vendor/xtensa_include/ -- highint5.S's 13-header closure, so NO
# ESP-IDF install is needed to build.  Provenance + license: see that dir's README.
# Override with IDF_PATH=<esp-idf> to use a live IDF tree's headers instead.

# Toolchain (xtensa GNAT, gprbuild, native GNAT) on PATH -- Alire-free, resolved
# from $ESP32S3_ADA_TOOLCHAINS (default: Alire's dir; a bundle overrides it).
. "$REPO/tools/sdk-env.sh"
esp32s3_toolchain_on_path
# The xtensa-dynconfig core-config plugin (.so) is REQUIRED before anything below
# (gen_runtime + every compile/link read XTENSA_GNU_CONFIG).  On a fresh clone it
# hasn't been built yet, so build it here -- without Alire (scripts/setup.sh +
# `make -C xtensa-dynconfig`).  Needs a host C toolchain (see README prerequisites).
DYNDIR="$REPO/crates/xtensa-dynconfig"
DYNCFG="$DYNDIR/xtensa-dynconfig/xtensa_esp32s3.so"
esp32s3_build_dynconfig "$DYNDIR" "$DYNCFG"
export XTENSA_GNU_CONFIG="$(realpath "$DYNCFG")"
GCC=xtensa-esp32-elf-gcc

# Per-profile defaults so EVERY example builds under each runtime, without each
# example's build.sh having to set them.  The exception-capable embedded/full
# runtimes REFERENCE the C mem*/heap (memcpy from the exception machinery, malloc) --
# newlib provided these under IDF -- so they need HEAP_SIZE (-> bare_heap + bare_libc;
# otherwise the link fails with undefined memcpy/memmove/memset/memcmp) and a larger
# env-task stack for exception handling.  light-tasking is heap-less
# (No_Exception_Propagation; s-memory bump allocator) and stays bare.  Explicit
# HEAP_SIZE / ENV_STACK_SIZE env vars (e.g. the ACATS harness) still override.
case "${ESP32S3_RTS_PROFILE:-light-tasking}" in
    embedded|full) HEAP_SIZE="${HEAP_SIZE:-1}"
                   ENV_STACK_SIZE="${ENV_STACK_SIZE:-32768}" ;;
    *)             ENV_STACK_SIZE="${ENV_STACK_SIZE:-16384}" ;;   # light-tasking: heap-less
esac

# ---- per-project board config + 2nd-stage bootloader ---------------------------
# Each project OWNS its config/board.ads (flash + PSRAM size); it is REQUIRED (no
# global fallback).  Derive this project's board_config.{h,env} into .noidf/, then
# either reuse the prebuilt SDK-default bootloader (when the PSRAM size matches the
# default) or build a project-specific one -- PSRAM_Size is baked into the binary.
#  Each project's board.ads lives at its ROOT (older layouts under config/ still work).
PROJ_ADS="$EX/board.ads"; [ -f "$PROJ_ADS" ] || PROJ_ADS="$EX/config/board.ads"
[ -f "$PROJ_ADS" ] || { echo "[bare] $EX has no board.ads -- every project must declare" \
    "its own (run 'esp32-ada init' / './x new', or copy $BARE/config/board.ads.template)" >&2; exit 1; }
mkdir -p "$EX/.noidf"
bash "$BARE/config/gen_board_config.sh" "$PROJ_ADS" "$EX/.noidf" >/dev/null
. "$EX/.noidf/board_config.env"      # BOARD_FLASH_SIZE(_STR) BOARD_PSRAM_SIZE BOARD_PSRAM_PAGES

# SDK default board config = the baseline the prebuilt default bootloader matches.
bash "$BARE/config/gen_board_config.sh" >/dev/null
DEF_PSRAM="$(. "$BARE/config/board_config.env"; echo "$BOARD_PSRAM_SIZE")"

bl_stale () {   # $1 = bootloader.bin, $2 = the board.ads it was built from
    [ -f "$1" ] || return 0
    for f in "$2" "$BARE/bootloader/build.sh" "$BARE/bootloader/src/"*.ad? \
             "$BARE/bootloader/"*.c "$BARE/bootloader/"*.S "$BARE/bootloader/"*.ld; do
        [ -e "$f" ] && [ "$f" -nt "$1" ] && return 0
    done
    return 1
}
if [ "$BOARD_PSRAM_SIZE" = "$DEF_PSRAM" ]; then
    DEFBL="$BARE/bootloader/bootloader.bin"
    if bl_stale "$DEFBL" "$BARE/config/board.ads"; then
        echo "[bare] 0/4  (re)build default 2nd-stage bootloader"
        bash "$BARE/bootloader/build.sh" >/dev/null
    fi
    cp "$DEFBL" "$EX/.noidf/bootloader.bin"
else
    PBL="$EX/.noidf/bootloader.bin"
    if bl_stale "$PBL" "$PROJ_ADS"; then
        echo "[bare] 0/4  build project bootloader (PSRAM=$BOARD_PSRAM_SIZE, default=$DEF_PSRAM)"
        BOARD_CFG_DIR="$EX/.noidf" BOOT_OBJ="$EX/.noidf/boot_obj" BOOT_OUT="$PBL" \
            bash "$BARE/bootloader/build.sh" >/dev/null
    fi
fi

# Profile-change invalidation.  app_main.o (the Ada closure) and the freestanding
# C objects are built against the SELECTED runtime; switching ESP32S3_RTS_PROFILE in
# the same example dir must rebuild them.  Otherwise an embedded/full app_main.o --
# which pulls in the DWARF unwinder (malloc/abort/free) -- gets linked into a
# heap-less light-tasking image and the link fails on undefined malloc/abort.
mkdir -p "$EX/.noidf"
PROF_STAMP="$EX/.noidf/.profile"; PROF_NOW="${ESP32S3_RTS_PROFILE:-light-tasking}"
if [ "$(cat "$PROF_STAMP" 2>/dev/null)" != "$PROF_NOW" ]; then
    [ -s "$PROF_STAMP" ] && echo "[bare]      runtime profile changed -> $PROF_NOW; rebuilding app"
    #  $EX/obj is gprbuild's Ada closure (.ali/.o, incremental); a stale tree built
    #  against the previous runtime mislinks under the new one, so clear it.
    rm -rf "$EX/obj"
    rm -f "$EX/main/app_main.o" "$EX/.noidf/bare_heap.o" "$EX/.noidf/bare_libc.o" \
          "$EX/app.bin" "$EX/app.elf"
fi
echo "$PROF_NOW" > "$PROF_STAMP"

# Recoverable stack-overflow -> catchable Storage_Error.  FULL profile only: the
# raise needs ZCX + GNARL's __gnat_stack_overflow_raise, and only full's s-taprop
# Enter_Task arms the watchpoint.  When on, bare_glue.c gets the arming hook
# (-DRECOVER_STACK_OVF) and stack_overflow.S (the xt_debugexception override that
# turns the stack-limit watchpoint into the raise) is compiled + linked.
SO_DEF=""; SO_OBJ=""
if [ "$PROF_NOW" = "full" ] && [ -z "${SO_OFF:-}" ]; then SO_DEF="-DRECOVER_STACK_OVF"; fi

# Reusable Ada libraries (libs/*/) on GPR_PROJECT_PATH so any app can `with` them by
# name (e.g. `with "esp32s3_hal.gpr"`).  build_ada.sh inherits this and prepends the
# runtime crate.  Auto-discovered: drop libs/<name>/<name>.gpr, no build edit.
for __l in "$REPO"/libs/*/; do
    [ -d "$__l" ] && GPR_PROJECT_PATH="${__l%/}${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
done
export GPR_PROJECT_PATH

echo "[bare] 1/4  Ada -> app_main.o  ($(basename "$EX"), main=$ADA_MAIN)"
bash "$EX/main/build_ada.sh"

# The Ada main symbol the caller passed is a guess from the test-list line; for a
# multi-file test the real main unit can differ (e.g. C94004 -> c94004a).  When the
# build step resolved the actual main it records it here -- adopt it as the boot
# entry so the env body calls the right _ada_<unit>.
if [ -f "$EX/.noidf/ada_main.sym" ]; then
    NEW_MAIN="$(cat "$EX/.noidf/ada_main.sym")"
    if [ -n "$NEW_MAIN" ] && [ "$NEW_MAIN" != "$ADA_MAIN" ]; then
        echo "[bare]      Ada main override: $ADA_MAIN -> $NEW_MAIN"
        ADA_MAIN="$NEW_MAIN"
    fi
fi

echo "[bare] 2/4  compile bare-boot + example glue + assemble start/highint5/context"
if [ -n "${IDF_PATH:-}" ]; then                # optional: use a live IDF tree's headers
    XINC="-I$IDF_PATH/components/xtensa/include -I$IDF_PATH/components/xtensa/esp32s3/include"
else
    XINC="-I$VENDOR/xtensa_include"            # vendored headers (default, no IDF needed)
fi
# -g adds DWARF for source-level debugging (glue/boot/app_main); the debug sections
# are non-allocated, so app.bin is unaffected (elf2image drops them).
CFLAGS="-g -mlongcalls -ffunction-sections -fdata-sections -Os -Wall -nostdlib"
OBJ="$EX/.noidf"; mkdir -p "$OBJ"

# ENV_STACK_PSRAM=1 : place the env-task PRIMARY stack in a carved slice at the TOP
# of the bootloader-mapped PSRAM (0x3D000000 + BOARD_PSRAM_SIZE) and shrink the PSRAM
# heap to end below it.  Lets recursion / deep-elaboration tasks take a large primary
# stack with NO DRAM cost (the DRAM ada_env_stack array is then not emitted).  Safe at
# boot: the 2nd-stage bootloader maps PSRAM BEFORE start.S sets SP=__stack_end.  The
# default (unset) keeps the env stack in the DRAM ada_env_stack array, unchanged.
ENV_STACK_GLUE_DEF=""
STACK_START_SYM="ada_env_stack"
STACK_END_SYM="ada_env_stack+$ENV_STACK_SIZE"
PSRAM_HEAP_SIZE="${BOARD_PSRAM_SIZE:-0}"
if [ "${ENV_STACK_PSRAM:-0}" != 0 ]; then
    [ "${BOARD_PSRAM_SIZE:-0}" -gt 0 ] \
        || { echo "[bare] ENV_STACK_PSRAM=1 needs PSRAM_Size>0 in board.ads" >&2; exit 1; }
    [ "$ENV_STACK_SIZE" -lt "$BOARD_PSRAM_SIZE" ] \
        || { echo "[bare] ENV_STACK_SIZE ($ENV_STACK_SIZE) >= PSRAM size ($BOARD_PSRAM_SIZE)" >&2; exit 1; }
    PSRAM_BASE=$((0x3D000000))
    STACK_TOP=$(( PSRAM_BASE + BOARD_PSRAM_SIZE ))      # 16-aligned: PSRAM size is 2^n
    STACK_BOT=$(( STACK_TOP - ENV_STACK_SIZE ))
    STACK_START_SYM=$(printf '0x%x' "$STACK_BOT")
    STACK_END_SYM=$(printf '0x%x' "$STACK_TOP")
    PSRAM_HEAP_SIZE=$(( BOARD_PSRAM_SIZE - ENV_STACK_SIZE ))
    ENV_STACK_GLUE_DEF="-DENV_STACK_PSRAM"
    echo "[bare]      env stack -> PSRAM top ($ENV_STACK_SIZE B @ $STACK_START_SYM..$STACK_END_SYM); PSRAM heap -> $PSRAM_HEAP_SIZE B"
fi

$GCC $CFLAGS -DADA_MAIN="$ADA_MAIN" -DENV_STACK_SIZE="$ENV_STACK_SIZE" $ENV_STACK_GLUE_DEF $SO_DEF -c "$BARE/bare_glue.c" -o "$OBJ/bare_glue.o"
$GCC $CFLAGS -c "$BARE/bare_log.c" -o "$OBJ/bare_log.o"   # ESP32S3.Log shim (hal_log_*)
# Per-example C glue is optional (examples that log via ESP32S3.Log need none).
GLUE_OBJ=""
if [ -f "$EX/main/glue.c" ]; then
    $GCC $CFLAGS ${EXTRA_CFLAGS:-} -c "$EX/main/glue.c" -o "$OBJ/glue.o"   # $EXTRA_CFLAGS: example build options
    GLUE_OBJ="$OBJ/glue.o"
fi
# Boot-support shims (the former stubs.c) as ZFP Ada over the svd-derived
# ESP32S3_Registers: compile-only to a relocatable object (no binder/runtime,
# runs before adainit), then linked like any other .o.
( cd "$BARE/boot" && GPR_PROJECT_PATH="$REPO/crates/esp32s3_rts" \
    gprbuild -c -p -q -P bare_boot.gpr )
cp "$BARE/boot/obj/bare_boot.o" "$OBJ/bare_boot.o"
$GCC $CFLAGS         -c "$BARE/app_desc.c"  -o "$OBJ/app_desc.o"
$GCC $CFLAGS $XINC   -c "$BARE/start.S"     -o "$OBJ/start.o"
$GCC $CFLAGS $XINC   -c "$BARE/highint5.S"  -o "$OBJ/highint5.o"
if [ -n "$SO_DEF" ]; then          # full: recoverable stack-overflow override
    $GCC $CFLAGS $XINC -c "$BARE/stack_overflow.S" -o "$OBJ/stack_overflow.o"
    SO_OBJ="$OBJ/stack_overflow.o"
fi
# The Xtensa support (context save/restore, the vector table, the interrupt/
# exception dispatch tables) -- all built from the vendored IDF sources over our
# minimal xtensa_include shims (xtensa_rtos.h etc.), NOT prebuilt .obj.  Each
# resulting object is instruction-for-instruction identical to IDF's libxtensa.a
# copy (the "FreeRTOS coupling" was only symbol-name macros + 2 config defines).
#   - intr_asm needs portNUM_PROCESSORS for its per-core table size (IDF -D's it).
#   - intr.c is C and matches at -Og (IDF builds this component at -Og), not -Os.
$GCC $CFLAGS $XINC   -c "$VENDOR/xtensa_context.S"  -o "$OBJ/xtensa_context.o"
$GCC $CFLAGS $XINC   -c "$VENDOR/xtensa_vectors.S"  -o "$OBJ/xtensa_vectors.o"
$GCC $CFLAGS $XINC -DportNUM_PROCESSORS=2 -c "$VENDOR/xtensa_intr_asm.S" -o "$OBJ/xtensa_intr_asm.o"
$GCC ${CFLAGS/-Os/-Og} $XINC -c "$VENDOR/xtensa_intr.c" -o "$OBJ/xtensa_intr.o"

# Heap-using profiles (embedded/full): add the freestanding allocator + libc bits
# the runtime references (malloc/free/mem*/abort) that newlib provided under IDF.
LIB_OBJS=()
if [ -n "$HEAP_SIZE" ]; then
    #  HEAP_PSRAM=1 : arena in the bootloader-mapped PSRAM (0x3D000000, BOARD_PSRAM_SIZE)
    #  instead of the ~256 KB leftover DRAM -- gives multi-task / large-alloc tests MBs
    #  (fixes the CXD8002/CXD4007/CXD4009 OOM class).  Needs PSRAM_Size>0 in board.ads.
    HEAP_PS=""
    if [ "${HEAP_PSRAM:-0}" != 0 ]; then
        # BOARD_PSRAM_SIZE already comes from THIS project's board_config.env (above).
        # PSRAM_HEAP_SIZE = BOARD_PSRAM_SIZE, minus the env-stack slice if ENV_STACK_PSRAM.
        HEAP_PS="-DHEAP_PSRAM -DHEAP_PSRAM_SIZE=${PSRAM_HEAP_SIZE}u"
        echo "[bare]      heap -> PSRAM (${PSRAM_HEAP_SIZE} B @ 0x3D000000)"
    fi
    echo "[bare]      + heap ($HEAP_SIZE B) + freestanding libc (embedded/full profile)"
    $GCC $CFLAGS -DHEAP_SIZE="$HEAP_SIZE" $HEAP_PS -c "$BARE/bare_heap.c" -o "$OBJ/bare_heap.o"
    $GCC $CFLAGS                          -c "$BARE/bare_libc.c" -o "$OBJ/bare_libc.o"
    LIB_OBJS=("$OBJ/bare_heap.o" "$OBJ/bare_libc.o")
fi

# Example-provided extra link inputs (esp32s3_psram: the vendored IDF
# octal-PSRAM + MSPI-timing objects via $EXTRA_OBJS, and a linker fragment for the
# PSRAM .ext_ram.bss region via $EXTRA_LD).  Unquoted on purpose (word-split paths).
EXTRA_LD_ARGS=""; [ -n "$EXTRA_LD" ] && EXTRA_LD_ARGS="-T $EXTRA_LD"

echo "[bare] 3/4  link -> app.elf"
#  light-tasking's s-memory.adb is a bump allocator that imports __heap_start /
#  __heap_end; point them at the leftover-DRAM arena (--defsym below).  embedded/
#  full instead call C malloc -> bare_heap.c and never reference these symbols, so
#  defining them unconditionally is harmless for those profiles.
$GCC -nostdlib -no-pie \
    -T "$VENDOR/memory.ld" -T "$VENDOR/sections.ld" -T "$VENDOR/rom_syms.ld" $EXTRA_LD_ARGS \
    -Wl,-e,_start -Wl,-Map="$EX/app.map" \
    -Wl,--defsym=__stack_start=$STACK_START_SYM \
    -Wl,--defsym=__stack_end=$STACK_END_SYM \
    -Wl,--defsym=__core1_stack_end=core1_stack+8192 \
    -Wl,--defsym=__heap_start=_heap_low_start \
    -Wl,--defsym=__heap_end=_bare_heap_top \
    -o "$EX/app.elf" \
    "$EX/main/app_main.o" "$OBJ/bare_glue.o" "$OBJ/bare_log.o" $GLUE_OBJ "$OBJ/bare_boot.o" "$OBJ/app_desc.o" \
    "$OBJ/start.o" "$OBJ/highint5.o" $SO_OBJ "${LIB_OBJS[@]}" $EXTRA_OBJS \
    "$OBJ/xtensa_context.o" "$OBJ/xtensa_vectors.o" \
    "$OBJ/xtensa_intr_asm.o" "$OBJ/xtensa_intr.o" \
    "$VENDOR/libxt_hal.a" "$VENDOR/libgcc.a"

# 4/4: package app.elf -> app.bin with our OWN Ada elf2image (byte-identical to
# `esptool elf2image --chip esp32s3 --flash_mode dio --flash_freq 80m --flash_size
# 2MB`, verified across all examples) -- so packaging needs no esptool.  The host
# tool is built once with the Alire native GNAT.  Set ESP_USE_ESPTOOL=1 to fall back.
echo "[bare] 4/4  package -> app.bin"
#  BOARD_FLASH_SIZE(_STR) come from THIS project's board_config.env (sourced above);
#  pass the size explicitly so the image header matches the project's board.ads
#  (the host tool's compiled-in Board.Flash_Size is only its fallback default).
if [ -n "${ESP_USE_ESPTOOL:-}" ]; then
    ESPTOOL="esptool.py"; command -v esptool.py >/dev/null || ESPTOOL="python3 -m esptool"
    $ESPTOOL --chip esp32s3 elf2image --flash_mode dio --flash_freq 80m \
        --flash_size "${BOARD_FLASH_SIZE_STR:-2MB}" -o "$EX/app.bin" "$EX/app.elf"
else
    E2I="$BARE/elf2image/esp_elf2image"
    [ -x "$E2I" ] || echo "[bare]      building the Ada elf2image host tool (one-time) ..."
    #  Always run gprbuild: it's incremental, so it rebuilds the tool when its
    #  source changed, and no-ops otherwise.
    #  Native GNAT first so the host tool links with native gcc, not the cross.
    ( cd "$BARE/elf2image" \
        && PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH" gprbuild -q -P esp_elf2image.gpr )
    "$E2I" "$EX/app.elf" "$EX/app.bin" --flash-size "$BOARD_FLASH_SIZE"
fi
echo "[bare] done: $EX/app.bin"
