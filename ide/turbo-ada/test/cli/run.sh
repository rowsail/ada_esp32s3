#!/bin/bash
# tada-cli: Turbo Ada headless.  project info on a scratch crate, the IDE
# driven by a script (ui), and -- with gdb (and alr, for the IDE's Make) --
# a debug session both ways: through the IDE's keys and through tada-cli
# debug.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# The validated native GNAT + gprbuild (tools/sdk-env.sh), native first.
. "$HERE/../../../../tools/sdk-env.sh"
esp32s3_toolchain_on_path >/dev/null
PATH="$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }

gprbuild -P ../../turbo_ada.gpr -q -p
CLI="$HERE/../../bin/tada-cli"

# A scratch Alire crate (the language server off: nothing in the background).
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/src"
cp demo.adb "$W/src/"
cat > "$W/alire.toml" <<'TOML'
name = "demo"
description = "tada-cli test"
version = "0.1.0-dev"
authors = ["test"]
maintainers = ["test <test@example.com>"]
maintainers-logins = ["test"]
executables = ["demo"]
TOML
cat > "$W/demo.gpr" <<'GPR'
project Demo is
   for Source_Dirs use ("src");
   for Object_Dir use "obj";
   for Exec_Dir use "bin";
   for Main use ("demo.adb");
   package Compiler is
      for Default_Switches ("Ada") use ("-g", "-O0");
   end Compiler;
end Demo;
GPR
echo "lsp.enabled=0" > "$W/.turbo_ada"

"$CLI" -C "$W" project info --json | grep -q '"target": "native"'
echo "project info: ok"

"$CLI" -C "$W" ui src/demo.adb --script "$HERE/ui.txt"
grep -q "^breakpoints=.*demo.adb:15" "$W/.turbo_ada"
echo "ui: ok"

# The system clipboard, as a file: the options name the helper commands.
printf 'Hello from outside\r\nline two\r\n' > "$W/clip"
cp demo.adb "$W/src/demo.adb"
cat > "$W/.turbo_ada" <<OPT
lsp.enabled=0
clipboard.copy=cat > "$W/clip"
clipboard.paste=cat "$W/clip"
OPT
"$CLI" -C "$W" ui src/demo.adb --script "$HERE/clipboard.txt"
[ "$(cat "$W/clip")" = "procedure Demo is" ]
echo "clipboard: ok"

# Edit | Format, with gnatformat itself (no language server).
FMT="$(command -v gnatformat || { [ -x "$HOME/.alire/bin/gnatformat" ] && echo "$HOME/.alire/bin/gnatformat"; } || true)"
if [ -n "$FMT" ]; then
    cp messy.adb "$W/src/messy.adb"
    echo "lsp.enabled=0" > "$W/.turbo_ada"
    "$CLI" -C "$W" ui src/messy.adb --script "$HERE/format.txt"
    (cd "$W/src" && "$FMT" --check --no-project messy.adb)
    echo "format: ok"
else
    echo "format: skipped (no gnatformat)"
fi

if ! command -v gdb >/dev/null; then
    echo "debug: skipped (no gdb)"
    exit 0
fi
(cd "$W" && gprbuild -P demo.gpr -q -p)
"$CLI" -C "$W" debug --no-build --break demo.adb:15 --watch Total \
    --script "$HERE/debug.txt" > "$W/debug.log"
grep -q "^| I = 3  Total = 1$" "$W/debug.log"
grep -q "^exited normally$" "$W/debug.log"
echo "debug: ok"

if command -v alr >/dev/null; then
    echo "lsp.enabled=0" > "$W/.turbo_ada"     # without the first test's breakpoint
    "$CLI" -C "$W" ui src/demo.adb --script "$HERE/ui-debug.txt"
    echo "ui debug: ok"
else
    echo "ui debug: skipped (no alr for the IDE's Make)"
fi
