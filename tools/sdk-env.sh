# Alire-free toolchain + dynconfig helpers for the ESP32-S3 Ada SDK.
# SOURCE this file (do not execute).
#
# Resolves the xtensa cross GNAT, gprbuild and native GNAT from a configurable
# search root and puts them on PATH, and builds the xtensa-dynconfig core-config
# plugin -- all WITHOUT Alire.  `alr` is never invoked.
#
#   ESP32S3_ADA_TOOLCHAINS   search root holding the gnat_*/gprbuild_* dirs.
#                            Default: Alire's install dir (existing dev boxes).
#                            A self-contained bundle sets this to its own
#                            toolchains/, or ships $ESP32S3_ADA_SDK/toolchains/.
#
# Note: the very first dynconfig build still clones its upstream source over the
# network; vendor it for a fully offline bundle (Phase 2).

: "${ESP32S3_ADA_TOOLCHAINS:=$HOME/.local/share/alire/toolchains}"
if [ -n "${ESP32S3_ADA_SDK:-}" ] && [ -d "$ESP32S3_ADA_SDK/toolchains" ]; then
    ESP32S3_ADA_TOOLCHAINS="$ESP32S3_ADA_SDK/toolchains"   # bundled toolchain wins
fi
export ESP32S3_ADA_TOOLCHAINS

# --- Known-good toolchain ------------------------------------------------------
#
# The bare runtime is a patch series against specific GNAT/bb-runtimes sources
# (crates/esp32s3_rts/full_overlay/patches), and a compiler bump can change
# bare-metal codegen.  These are the versions the boards were validated on.
#
# They are PREFERRED, not required: esp32s3_tc_bin_pref below picks the recorded
# version when it is installed and the newest available otherwise, warning in
# that case.  A newer compiler stays usable -- but a box that has the validated
# one uses it, rather than whatever happens to sort last.  (CI hit exactly that:
# setup-alire brings its own newer native GNAT, so pinning at install time was
# not enough and the runners were building with an unvalidated compiler.)
ESP32S3_GNAT_KNOWN_GOOD="15.2.1"      # gnat_xtensa_esp32_elf + gnat_native
ESP32S3_GPRBUILD_KNOWN_GOOD="26.0.1"
export ESP32S3_GNAT_KNOWN_GOOD ESP32S3_GPRBUILD_KNOWN_GOOD

# Newest bin/ under the search root matching glob $1 (or empty if none).
esp32s3_tc_bin () { ls -d "$ESP32S3_ADA_TOOLCHAINS"/$1/bin 2>/dev/null | sort -V | tail -1; }

# bin/ for crate $1: the known-good version $2 if that one is installed, else
# the newest $1 there is.
esp32s3_tc_bin_pref () {
    local exact
    exact="$(ls -d "$ESP32S3_ADA_TOOLCHAINS"/"$1"_"$2"_*/bin 2>/dev/null | head -1)"
    if [ -n "$exact" ]; then
        printf '%s' "$exact"
    else
        esp32s3_tc_bin "$1"'_*'
    fi
}

# Put gprbuild + the xtensa cross GNAT + native GNAT on PATH (idempotent), and
# export ESP32S3_GPRBUILD_BIN / ESP32S3_GNAT_NATIVE_BIN for callers that need an
# explicit native-first PATH (the native host tools).
esp32s3_toolchain_on_path () {
    ESP32S3_GPRBUILD_BIN="$(esp32s3_tc_bin_pref gprbuild "$ESP32S3_GPRBUILD_KNOWN_GOOD")"
    ESP32S3_GNAT_XTENSA_BIN="$(esp32s3_tc_bin_pref gnat_xtensa_esp32_elf "$ESP32S3_GNAT_KNOWN_GOOD")"
    ESP32S3_GNAT_NATIVE_BIN="$(esp32s3_tc_bin_pref gnat_native "$ESP32S3_GNAT_KNOWN_GOOD")"
    export ESP32S3_GPRBUILD_BIN ESP32S3_GNAT_XTENSA_BIN ESP32S3_GNAT_NATIVE_BIN
    local d
    for d in "$ESP32S3_GPRBUILD_BIN" "$ESP32S3_GNAT_XTENSA_BIN" "$ESP32S3_GNAT_NATIVE_BIN"; do
        [ -n "$d" ] || continue
        case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH" ;; esac
    done
    export PATH
    esp32s3_check_toolchain
}

# Version embedded in an Alire toolchain directory name: gnat_native_15.2.1_<hash>
esp32s3_tc_version () {
    local d="${1:-}"
    [ -n "$d" ] || return 0
    basename "$(dirname "$d")" | sed -nE 's/^[a-z0-9_]+_([0-9]+(\.[0-9]+)*)_[0-9a-f]+$/\1/p'
}

esp32s3_check_toolchain () {
    [ -n "${ESP32S3_ADA_SKIP_TOOLCHAIN_CHECK:-}" ] && return 0
    local v
    v="$(esp32s3_tc_version "$ESP32S3_GNAT_XTENSA_BIN")"
    if [ -n "$v" ] && [ "$v" != "$ESP32S3_GNAT_KNOWN_GOOD" ]; then
        echo "[sdk] note: xtensa GNAT $v (validated on $ESP32S3_GNAT_KNOWN_GOOD)" >&2
    fi
    v="$(esp32s3_tc_version "$ESP32S3_GNAT_NATIVE_BIN")"
    if [ -n "$v" ] && [ "$v" != "$ESP32S3_GNAT_KNOWN_GOOD" ]; then
        echo "[sdk] note: native GNAT $v (validated on $ESP32S3_GNAT_KNOWN_GOOD)" >&2
    fi
    v="$(esp32s3_tc_version "$ESP32S3_GPRBUILD_BIN")"
    if [ -n "$v" ] && [ "$v" != "$ESP32S3_GPRBUILD_KNOWN_GOOD" ]; then
        echo "[sdk] note: gprbuild $v (validated on $ESP32S3_GPRBUILD_KNOWN_GOOD)" >&2
    fi
    return 0
}

# Build the xtensa-dynconfig plugin (the XTENSA_GNU_CONFIG .so) without Alire,
# if the output is missing.  This runs exactly what `alr build` ran for the
# crate: its pre-build actions (scripts/setup.sh + `make -C xtensa-dynconfig`).
#   $1 = crate dir (.../crates/xtensa-dynconfig)   $2 = expected .so path
esp32s3_build_dynconfig () {
    local dyndir="$1" dyncfg="$2"
    [ -f "$dyncfg" ] && return 0
    echo "[sdk] building xtensa-dynconfig plugin (one-time, Alire-free)"
    ( cd "$dyndir" && bash ./scripts/setup.sh && make -C xtensa-dynconfig CC=gcc )
}

# Export XTENSA_GNU_CONFIG for the SDK checkout rooted at $1, building the
# plugin first if it is missing.
#
# WHY THIS IS NOT OPTIONAL: the Xtensa back end reads XTENSA_GNU_CONFIG to learn
# the core's configuration -- endianness included.  Without it the compiler does
# not fail; it silently emits BIG-endian objects.  The HAL keeps one object
# directory per profile, shared by every consumer, so a single `gprbuild -P
# esp32s3_hal.gpr` in a shell that lacks the variable poisons obj-<profile> and
# every later example dies at LINK time with
#
#     ld: ... compiled for a big endian system and target is little endian
#     ld: cross-endian linking for ... esp32s3.o not supported
#
# -- a message that points at the linker, nowhere near the cause.  export.sh
# advertises that a shell which sourced it can run gprbuild directly, so it must
# set this too, not only bare_build.sh.
esp32s3_export_dynconfig () {
    local root="$1"
    local dyndir="$root/crates/xtensa-dynconfig"
    local dyncfg="$dyndir/xtensa-dynconfig/xtensa_esp32s3.so"
    esp32s3_build_dynconfig "$dyndir" "$dyncfg" || return 1
    [ -f "$dyncfg" ] || return 1
    XTENSA_GNU_CONFIG="$(cd "$(dirname "$dyncfg")" && pwd)/$(basename "$dyncfg")"
    export XTENSA_GNU_CONFIG
}
