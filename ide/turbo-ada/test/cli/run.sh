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
# The user's options (recent files and projects, the SDK) go here, not in
# the real ~/.config.  Not XDG_CONFIG_HOME: that would move alr's settings
# (its toolchain choice) too.
export TURBO_ADA_CONFIG="$W/config"
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

# Project | Viewer: folders and sources (gprinspect, in alr's environment).
if command -v alr >/dev/null; then
    cp demo.adb "$W/src/demo.adb"
    echo "lsp.enabled=0" > "$W/.turbo_ada"
    "$CLI" -C "$W" ui src/demo.adb --script "$HERE/project.txt"
    echo "project viewer: ok"
else
    echo "project viewer: skipped (no alr)"
fi

# Project | Project file: a second .gpr, chosen; the choice is kept and used.
sed 's/project Demo is/project Demo_Tests is/; s/end Demo;/end Demo_Tests;/' \
    "$W/demo.gpr" > "$W/demo_tests.gpr"
echo "lsp.enabled=0" > "$W/.turbo_ada"
"$CLI" -C "$W" ui src/demo.adb --script "$HERE/gprfile.txt"
grep -qx "gpr=$W/demo_tests.gpr" "$W/.turbo_ada"
"$CLI" -C "$W" project info | grep -q "^gpr: *$W/demo_tests.gpr"
rm "$W/demo_tests.gpr"
echo "lsp.enabled=0" > "$W/.turbo_ada"
echo "project file: ok"

# Search in files, Replace in files, File | Reopen.
echo "lsp.enabled=0" > "$W/.turbo_ada"
"$CLI" -C "$W" ui src/demo.adb --script "$HERE/search.txt"
echo "search in files: ok"

# Project | New project: an Ada program without Alire (a GPR project), built
# and run.  Its own folder, outside the crate.
G="$(mktemp -d)"
trap 'rm -rf "$W" "$G"' EXIT
"$CLI" -C "$G" ui --script "$HERE/newgpr.txt"
[ -f "$G/hello_gpr/hello_gpr.gpr" ] && [ -x "$G/hello_gpr/bin/hello_gpr" ]
"$CLI" -C "$G/hello_gpr" project info | grep -q "^kind: *GPR project"
echo "gpr project: ok"

# Project | New project: an esp32-ada project in a folder made for it (the
# remembered location goes in a scratch config, not the user's).  Outside
# the crate above, or the IDE would start in that.
N="$(mktemp -d)"
trap 'rm -rf "$W" "$G" "$N"' EXIT
# A fresh config: New project would start in the location the GPR test used.
TURBO_ADA_CONFIG="$W/config-new" "$CLI" -C "$N" ui --script "$HERE/newproject.txt"
[ -f "$N/boards/blinky/app.gpr" ] && [ -f "$N/boards/blinky/src/main.adb" ]
grep -qx "new.location=$N/boards" "$W/config-new/options"
echo "new project: ok"

# Project | Get ESP32-S3 SDK, with no network: the Location holds an SDK
# already (a link to this one), so it is used, not cloned.  Toolchain: no;
# ~/.bashrc (a scratch HOME): yes.
mkdir -p "$N/home" "$N/sdks"
ln -s "$(cd "$HERE/../../../.." && pwd)" "$N/sdks/ada_esp32s3"
HOME="$N/home" TURBO_ADA_CONFIG="$W/config2" "$CLI" -C "$N" ui \
    -e "key Alt-P" -e "key K" -e "wait-for Get ESP32-S3 SDK" -e "key Alt-L" -e "key Ctrl-Y" \
    -e "type $N/sdks" -e "key Enter" -e "wait-for Use that one?" -e "key Enter" \
    -e "wait-for Set up its toolchain now?" -e "key Esc" -e "wait-for bashrc" -e "key Enter" -e quit
grep -qx "sdk.path=$N/sdks/ada_esp32s3" "$W/config2/options"
grep -qx ". $N/sdks/ada_esp32s3/export.sh >/dev/null" "$N/home/.bashrc"
echo "get sdk: ok"

# Compile | Analyze file, through alr's environment (an Alire crate).
if command -v alr >/dev/null && { command -v adalang_analyzer >/dev/null \
        || [ -x "$HOME/.alire/bin/adalang_analyzer" ]; }; then
    cp messy.adb "$W/src/messy.adb"
    echo "lsp.enabled=0" > "$W/.turbo_ada"
    PATH="$PATH:$HOME/.alire/bin" "$CLI" -C "$W" ui src/messy.adb --script "$HERE/analyze.txt"
    echo "analyze: ok"
else
    echo "analyze: skipped (no adalang_analyzer or alr)"
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
    echo "lsp.enabled=0" > "$W/.turbo_ada"
    "$CLI" -C "$W" ui src/demo.adb --script "$HERE/run.txt"
    echo "run in the output window: ok"
else
    echo "ui debug: skipped (no alr for the IDE's Make)"
fi
