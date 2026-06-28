#!/usr/bin/env bash
#
#  x -- one command surface for the bare-metal Ada / ESP32-S3 examples.
#
#  A thin, stable dispatcher over the per-example build.sh/flash.sh and the
#  config/ + monitor tooling, designed to be driven by a human OR an IDE plugin
#  (VS Code task, Eclipse launch, Vim :make).  Language features (completion,
#  diagnostics) come from the Ada Language Server via each example's .gpr -- this
#  script is only the *actions* surface.
#
#  Usage:
#    ./x list [--json]                 list examples (name, dir, profile)
#    ./x new|init <name>               scaffold a new bare project (examples/<name>)
#    ./x build   <example> [-P PROF]   build -> app.bin   (PROF: light-tasking|
#                                      embedded|full; default = the example's own)
#    ./x flash   <example> [-p PORT]   build (if needed) + flash over USB ROM
#    ./x run     <example> [-p PORT] [-P PROF]  build + flash + monitor
#    ./x monitor [-p PORT]             open the serial console (115200)
#    ./x clean   [<example>]           remove build artifacts (all if omitted)
#    ./x stack   <example> [--top N] [--run]   static stack analysis (per-frame +
#                                      worst-case call chains); --run adds the
#                                      runtime high-water mark over serial
#    ./x mem     <example>             memory footprint: section sizes + bounds
#    ./x config <example> [show|--json]   show flash/PSRAM size (its board.ads)
#    ./x config <example> flash-size <SIZE>  set flash size (e.g. 4MB, 0x800000)
#    ./x config <example> psram-size <SIZE>  set PSRAM size (rebuilds its bootloader)
#    ./x get-debug-tools               fetch pinned OpenOCD + GDB (for debugging)
#    ./x debug   <example> [-p PORT] [--smp] [--attach]   on-chip debug (OpenOCD+GDB)
#                                     --smp    : both LX7 cores as gdb threads (info threads)
#                                     --attach : post-mortem halt-in-place (no reset; a hang/crash)
#    ./x kill-openocd                  kill every OpenOCD (releases captured USB-JTAG ports)
#    ./x setup-device [-h]             one-time: install udev rule + groups for USB access (sudo)
#    ./x check-device [-p PORT]        report whether the board's port is accessible
#    ./x install-ide                   install the VS Code extension (committed .vsix; no Node)
#    ./x build-ide                     (maintainer) rebuild the committed .vsix (needs Node)
#    ./x install-vim                   symlink the Vim/Neovim plugin (auto-updates on git pull)
#    ./x docs                          build the HAL API reference PDF (libs/esp32s3_hal/docs/)
#
#  <example> accepts the short name (gpio0_blink) or the full dir
#  (esp32s3_gpio0_blink).  PORT defaults to $ESPPORT or /dev/ttyACM0.
#
set -euo pipefail
#  BASH_SOURCE[0] (not $0) so ROOT is right when x is SOURCED as a library too
#  (tools/bin/esp32-ada sources us; $0 would be esp32-ada's path).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXROOT="$ROOT/examples"
CFG="$EXROOT/common/bare/config"
PORT_DEFAULT="${ESPPORT:-/dev/ttyACM0}"
BAUD=115200

die () { echo "x: $*" >&2; exit 1; }

# -- examples -----------------------------------------------------------------
list_dirs () {   # every examples/<dir> that has a build.sh, sorted
    for d in "$EXROOT"/*/; do
        [ -f "${d}build.sh" ] && basename "$d"
    done | sort
}

profile_of () {  # $1 = full dir name -> runtime profile
    local p
    p="$(grep -rhoE 'ESP32S3_RTS_PROFILE=[a-z-]+' \
            "$EXROOT/$1/build.sh" 2>/dev/null \
         | head -1 | cut -d= -f2 || true)"
    echo "${p:-light-tasking}"
}

valid_profile () {  # die unless $1 is a known profile or the "use the example's own" sentinel
    case "${1:-auto}" in
        ''|auto|default|light-tasking|embedded|full) return 0 ;;
        *) die "invalid --profile '$1' (light-tasking|embedded|full, or auto)" ;;
    esac
}
prof_env () {  # echo the ESP32S3_RTS_PROFILE override for `env`, or nothing for auto/default
    case "${1:-auto}" in ''|auto|default) ;; *) printf 'ESP32S3_RTS_PROFILE=%s' "$1" ;; esac
}
serial_from_port () {  # $1 = /dev/ttyACMx -> echo the USB-JTAG adapter serial (== ACM serial)
    local link tgt; tgt="$(readlink -f "$1" 2>/dev/null)" || return 0
    for link in /dev/serial/by-id/usb-Espressif_USB_JTAG_serial_debug_unit_*; do
        [ -e "$link" ] || continue
        [ "$(readlink -f "$link")" = "$tgt" ] && {
            basename "$link" | sed -E 's/.*debug_unit_(.+)-if[0-9]+$/\1/'; return 0; }
    done
    command -v udevadm >/dev/null 2>&1 && \
        udevadm info -q property -n "$1" 2>/dev/null | sed -n 's/^ID_SERIAL_SHORT=//p' | head -1
}

resolve () {     # accept short or full name -> full dir name (or die)
    local n="$1"
    [ -n "$n" ] || die "missing <example> (try './x list')"
    if   [ -d "$EXROOT/$n" ];          then echo "$n"
    elif [ -d "$EXROOT/esp32s3_$n" ];  then echo "esp32s3_$n"
    else die "no such example: $n (try './x list')"; fi
}

short () { echo "${1#esp32s3_}"; }   # full dir -> short label (esp32s3_jorvik_profile_test -> jorvik_profile_test)

# -- serial monitor -----------------------------------------------------------
monitor_tool () {  # pick the first available serial console for $1=port
    local port="$1"
    if [ -n "${ESP_MONITOR:-}" ]; then eval "$ESP_MONITOR"; return; fi
    if python3 -c 'import serial.tools.miniterm' 2>/dev/null; then
        exec python3 -m serial.tools.miniterm --raw "$port" "$BAUD"
    elif command -v picocom >/dev/null; then exec picocom -b "$BAUD" "$port"
    elif command -v screen  >/dev/null; then exec screen "$port" "$BAUD"
    else
        echo "x: no miniterm/picocom/screen found; raw cat fallback (Ctrl-C to quit)" >&2
        stty -F "$port" "$BAUD" raw -echo 2>/dev/null || true
        exec cat "$port"
    fi
}

# -- size parsing (for config) ------------------------------------------------
parse_size () {  # 4MB / 512KB / 0x800000 / 8388608 -> bytes
    local s="${1^^}" n
    case "$s" in
        *MB) n=$(( ${s%MB} * 1024 * 1024 )) ;;
        *M)  n=$(( ${s%M}  * 1024 * 1024 )) ;;
        *KB) n=$(( ${s%KB} * 1024 )) ;;
        *K)  n=$(( ${s%K}  * 1024 )) ;;
        0X*) n=$(( s )) ;;
        *)   n=$(( s )) ;;
    esac
    [ "$n" -gt 0 ] 2>/dev/null || die "bad size: $1"
    echo "$n"
}

ada_size_expr () {  # bytes -> a readable Ada constant expr + human comment
    local b="$1"
    if   (( b % (1024*1024) == 0 )); then echo "$(( b/1024/1024 )) * 1024 * 1024|$(( b/1024/1024 )) MB"
    elif (( b % 1024 == 0 ));        then echo "$(( b/1024 )) * 1024|$(( b/1024 )) KB"
    else echo "$b|$b bytes"; fi
}

set_const () {   # $1 = board.ads path, $2 = Flash_Size|PSRAM_Size, $3 = size string
    local ads="$1" name="$2" bytes expr human
    bytes="$(parse_size "$3")"
    IFS='|' read -r expr human <<<"$(ada_size_expr "$bytes")"
    [ -f "$ads" ] || die "missing $ads"
    sed -i -E "s|($name[[:space:]]*:[[:space:]]*constant[[:space:]]*:=).*;.*$|\1 $expr;     --  $human|" "$ads"
    echo "x: set $name = $expr  ($human)  in $ads"
    [ "$name" = PSRAM_Size ] && echo "x: rebuild to pick up the new-PSRAM bootloader (./x build <example>)" || true
}

read_const () {  # $1 = board.ads path, $2 = Flash_Size|PSRAM_Size -> bytes
    local ads="$1" tmp; tmp="$(mktemp -d)"
    bash "$CFG/gen_board_config.sh" "$ads" "$tmp" >/dev/null
    # shellcheck disable=SC1091
    . "$tmp/board_config.env"; rm -rf "$tmp"
    case "$2" in
        Flash_Size) echo "$BOARD_FLASH_SIZE" ;;
        PSRAM_Size) echo "$BOARD_PSRAM_SIZE" ;;
    esac
}

# -- commands -----------------------------------------------------------------
cmd_list () {
    if [ "${1:-}" = --json ]; then
        local first=1; printf '['
        for d in $(list_dirs); do
            [ $first -eq 1 ] || printf ','; first=0
            printf '{"id":"%s","name":"%s","dir":"examples/%s","profile":"%s"}' \
                   "$d" "$(short "$d")" "$d" "$(profile_of "$d")"
        done
        printf ']\n'
    else
        printf '%-22s %-14s %s\n' NAME PROFILE DIR
        for d in $(list_dirs); do
            printf '%-22s %-14s %s\n' "$(short "$d")" "$(profile_of "$d")" "examples/$d"
        done
    fi
}

cmd_build () {
    local e prof="auto"; e="$(resolve "${1:-}")"; shift || true
    while [ $# -gt 0 ]; do case "$1" in -P|--profile) prof="$2"; shift 2;; *) shift;; esac; done
    valid_profile "$prof"
    ( cd "$EXROOT/$e" && env $(prof_env "$prof") bash build.sh )
}

# -- device access ------------------------------------------------------------
#  A board may be plugged in yet unusable because the user lacks permission on the
#  port (raw USB / tty).  Distinguish "no device" from "no permission" and, for the
#  latter, print a STABLE marker line ("device not accessible") the IDE matches to
#  offer './x setup-device'.  Exit 13 == EACCES.
device_preflight () {  # $1 = port
    local port="$1"
    if [ ! -e "$port" ]; then
        echo "x: device not accessible: no such port $port" >&2
        echo "x:   plug in the ESP32-S3, or pass -p <port> / set \$ESPPORT." >&2
        return 1
    fi
    if [ ! -r "$port" ] || [ ! -w "$port" ]; then
        echo "x: device not accessible: $port -- permission denied." >&2
        echo "x:   run  ./x setup-device  (one-time, needs sudo) to grant access." >&2
        return 13
    fi
    return 0
}

cmd_setup_device () {  # install the udev rule + group membership (self-sudos)
    bash "$ROOT/tools/install-udev.sh" "$@"
}

cmd_check_device () {  # report port + USB-JTAG accessibility (human + IDE)
    local port="$PORT_DEFAULT"
    while [ $# -gt 0 ]; do case "$1" in -p|--port) port="$2"; shift 2;; *) shift;; esac; done
    if device_preflight "$port"; then
        echo "x: device OK: $port is accessible"
    else
        return $?
    fi
}

cmd_flash () {
    local e port="$PORT_DEFAULT"; e="$(resolve "${1:-}")"; shift || true
    while [ $# -gt 0 ]; do case "$1" in -p|--port) port="$2"; shift 2;; *) shift;; esac; done
    device_preflight "$port" || exit $?
    ( cd "$EXROOT/$e" && bash flash.sh "$port" )
    #  Record the flashed board's USB-JTAG serial so `./x debug` / the openocd task
    #  pin to THIS board (not the first 303a device) -- see tools/openocd.sh.
    local s; s="$(serial_from_port "$port")"
    [ -n "$s" ] && printf '%s\n' "$s" > "$ROOT/tools/.jtag_serial"
}

cmd_monitor () {
    local port="$PORT_DEFAULT"
    while [ $# -gt 0 ]; do case "$1" in -p|--port) port="$2"; shift 2;; *) shift;; esac; done
    device_preflight "$port" || exit $?
    echo "x: monitor $port @ $BAUD (Ctrl-C / Ctrl-A K to quit)" >&2
    monitor_tool "$port"
}

cmd_run () {   # build + flash + monitor
    local e port="$PORT_DEFAULT" prof="auto"; e="$(resolve "${1:-}")"; shift || true
    while [ $# -gt 0 ]; do case "$1" in
        -p|--port) port="$2"; shift 2;;
        -P|--profile) prof="$2"; shift 2;;
        *) shift;; esac
    done
    valid_profile "$prof"
    cmd_build "$e" --profile "$prof"; cmd_flash "$e" -p "$port"; cmd_monitor -p "$port"
}

cmd_clean () {
    local dirs
    if [ -n "${1:-}" ]; then dirs="$(resolve "$1")"; else dirs="$(list_dirs)"; fi
    for d in $dirs; do
        rm -f "$EXROOT/$d"/app.bin "$EXROOT/$d"/app.elf "$EXROOT/$d"/app.map \
              "$EXROOT/$d"/obj/app_main.o 2>/dev/null || true
        #  obj/    : gprbuild's Ada closure (.o/.ali) -- stale .ali keep OLD source
        #            paths after a dir rename (gprbuild reuses them) -> the app.elf
        #            carries pre-rename DWARF paths + old code; this is THE thing to
        #            clear after renaming an example.
        #  .noidf/ : the bare-boot C objects + the profile stamp.
        #  build/  : leftover ESP-IDF/CMake + old Alire output (vestigial on no-idf).
        rm -rf "$EXROOT/$d"/obj "$EXROOT/$d"/.noidf "$EXROOT/$d"/build 2>/dev/null || true
        echo "x: cleaned examples/$d"
    done
}

cmd_config () {   # config <example> [show|--json|flash-size SIZE|psram-size SIZE]
    local e ads tmp; e="$(resolve "${1:-}")"; shift || true
    ads="$EXROOT/$e/board.ads"; [ -f "$ads" ] || ads="$EXROOT/$e/config/board.ads"
    [ -f "$ads" ] || die "no board.ads for $e (every example owns one)"
    case "${1:-show}" in
        show|"")
            printf 'Flash_Size  %s bytes\nPSRAM_Size  %s bytes\n' \
                   "$(read_const "$ads" Flash_Size)" "$(read_const "$ads" PSRAM_Size)" ;;
        --json)
            tmp="$(mktemp -d)"; bash "$CFG/gen_board_config.sh" "$ads" "$tmp" >/dev/null
            . "$tmp/board_config.env"; rm -rf "$tmp"
            printf '{"flash_size":%s,"flash_size_str":"%s","psram_size":%s,"psram_pages":%s}\n' \
                   "$BOARD_FLASH_SIZE" "$BOARD_FLASH_SIZE_STR" "$BOARD_PSRAM_SIZE" "$BOARD_PSRAM_PAGES" ;;
        flash-size) set_const "$ads" Flash_Size "${2:?usage: x config <example> flash-size <SIZE>}" ;;
        psram-size) set_const "$ads" PSRAM_Size "${2:?usage: x config <example> psram-size <SIZE>}" ;;
        *) die "config: unknown '$1' (show|--json|flash-size|psram-size)" ;;
    esac
}

# -- debug --------------------------------------------------------------------
find_gdb () {  # the S3 needs the s3-specific GDB; the Alire esp32 (LX6) GDB fails
    local g                                  #  ("'g' packet too long" -- HW-verified)
    g="$ROOT/tools/gdb/xtensa-esp-elf-gdb/bin/xtensa-esp32s3-elf-gdb"   # fetched
    [ -x "$g" ] && { echo "$g"; return; }
    g="$(echo "$HOME"/.espressif/tools/xtensa-esp-elf-gdb/*/xtensa-esp-elf-gdb/bin/xtensa-esp32s3-elf-gdb 2>/dev/null | head -1)"
    [ -x "$g" ] && { echo "$g"; return; }
    command -v xtensa-esp32s3-elf-gdb >/dev/null && { echo xtensa-esp32s3-elf-gdb; return; }
    die "no xtensa-esp32s3-elf-gdb -- run './x get-debug-tools' to fetch it"
}

cmd_get_openocd     () { bash "$ROOT/tools/get-openocd.sh" "$@"; }
cmd_get_gdb         () { bash "$ROOT/tools/get-gdb.sh" "$@"; }
cmd_get_debug_tools () { cmd_get_openocd "$@"; cmd_get_gdb "$@"; }

cmd_debug () {
    local e elf gdb ocd_log ocd_pid port="$PORT_DEFAULT" smp="" attach=""
    e="$(resolve "${1:-}")"; shift || true
    while [ $# -gt 0 ]; do case "$1" in
        -p|--port) port="$2"; shift 2;;
        --smp)     smp=1; shift;;        # both LX7 cores as gdb threads (info threads -> cpu0+cpu1)
        --attach)  attach=1; shift;;     # POST-MORTEM: halt in place (no reset), for a hang/crash
        *) shift;;
    esac; done
    elf="$EXROOT/$e/app.elf"
    [ -f "$elf" ] || die "no $elf -- run './x build $(short "$e")' first"
    gdb="$(find_gdb)"
    ocd_log="$(mktemp)"
    echo "x: starting OpenOCD${smp:+ (dual-core/SMP)} ..." >&2
    #  ESPPORT -> openocd.sh pins the adapter serial to THIS board (else it falls
    #  back to tools/.jtag_serial from the last flash, or no pin for a single board).
    #  --smp -> ESP_RTOS=hwthread so BOTH cores show up as gdb threads (essential
    #  for a dual-core hang: one core may have crashed while the other idles).
    ESPPORT="$port" ${smp:+ESP_RTOS=hwthread} bash "$ROOT/tools/openocd.sh" >"$ocd_log" 2>&1 &
    ocd_pid=$!
    trap '[ -n "${ocd_pid:-}" ] && kill "$ocd_pid" 2>/dev/null; rm -f "$ocd_log"' EXIT
    # wait for the gdb server (or OpenOCD death)
    for _ in $(seq 1 50); do
        grep -q "Listening on port 3333" "$ocd_log" 2>/dev/null && break
        kill -0 "$ocd_pid" 2>/dev/null || { sed 's/^/openocd: /' "$ocd_log" >&2; die "OpenOCD exited (see above)"; }
        sleep 0.2
    done
    if [ -n "$attach" ]; then
        #  Post-mortem: freeze the running target in place (do NOT reset -- that would
        #  wipe the crash/hang).  With --smp, 'info threads' then shows both cores.
        echo "x: GDB ($gdb) -> :3333  on $(short "$e")  (POST-MORTEM: halted in place; 'info threads', 'thread 2', 'bt')" >&2
        "$gdb" "$elf" \
            -ex "target remote :3333" \
            -ex "monitor halt" \
            -ex "info threads" || true
    else
        echo "x: GDB ($gdb) -> :3333  on $(short "$e")  (armed tbreak app_main; 'c' to run to entry)" >&2
        "$gdb" "$elf" \
            -ex "target remote :3333" \
            -ex "monitor reset halt" \
            -ex "tbreak app_main" || true
    fi
}

# -- scaffold a new project ---------------------------------------------------
cmd_new () {
    local name="${1:-}"
    [ -n "$name" ] || die "usage: ./x new <name>   (lowercase letter first, then [a-z0-9_])"
    case "$name" in
        [!a-z]*|*[!a-z0-9_]*) die "invalid name '$name' -- lowercase letter first, then [a-z0-9_]";;
    esac
    local dir="$EXROOT/$name"
    [ -e "$dir" ] && die "examples/$name already exists"
    # Also reject a name that an existing example already answers to via the
    # esp32s3_ prefix (resolve() would otherwise shadow it).
    [ -e "$EXROOT/esp32s3_$name" ] && \
        die "name '$name' clashes with the existing example esp32s3_$name"
    mkdir -p "$dir/src"

    # Every project owns its board.ads (flash + PSRAM size); no global config.
    cp "$EXROOT/common/bare/config/board.ads.template" "$dir/board.ads"

    cat > "$dir/alire.toml" <<EOF
name = "$name"
description = "Bare-metal Ada ESP32-S3 application"
version = "0.1.0-dev"
licenses = "Apache-2.0"
project-files = ["app.gpr"]

[[depends-on]]
esp32s3_rts = "*"

[[pins]]
esp32s3_rts = { path = "../../crates/esp32s3_rts" }
xtensa_dynconfig = { path = "../../crates/xtensa-dynconfig" }
EOF

    cat > "$dir/app.gpr" <<'EOF'
with "../../crates/esp32s3_rts/esp32s3_rts.gpr";
with "../../libs/esp32s3_hal/esp32s3_hal.gpr";   --  ESP32S3.GPIO + the svd register layer

--  Bare-metal Ada application for the dual-core ESP32-S3 runtime.  Builds the
--  Ada into a relocatable object (ada_app.o) the bare-boot link pulls in.  Relative
--  `with`s so the Ada Language Server resolves them with no environment.
project App is
   for Target use "xtensa-esp32-elf";
   for Runtime ("Ada") use Esp32s3_Rts.Runtime_Path;
   for Source_Dirs use ("src");
   for Object_Dir use "obj";
   for Main use ("main.adb");

   package Builder is
      for Executable ("main.adb") use "ada_app.o";
   end Builder;

   package Binder is
      for Switches ("Ada") use ("-D8k", "-Q2", "-Mada_main");
   end Binder;

   package Compiler is
      for Switches ("Ada") use ("-O2", "-g");
   end Compiler;

   package Linker is
      for Default_Switches ("Ada") use ("-Wl,-r", "-nostdlib");
   end Linker;
end App;
EOF

    cat > "$dir/src/main.adb" <<'EOF'
pragma Warnings (Off);
with Ada.Real_Time; use Ada.Real_Time;

--  Bring up core 1 (pull the SMP slave-start entry into the link closure).
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

--  <one line: what this example demonstrates>
--
--  Build & run:  ./x run <name>   (or, out of tree, esp32-ada run) -- build,
--                flash, and open the serial monitor.  Default light-tasking
--                profile; set ESP32S3_RTS_PROFILE in build.sh if you need more.
--  Output:       <what the console prints; what success looks like>.
--  Hardware:     <none (self-contained), or the pins / external parts needed>.
--
--  Fill the header in as you write -- see the SDK's examples/STYLE.md for the
--  house style, and esp32s3_gpio0_blink / esp32s3_gdma_copy as worked models.
--
--  The runtime comes up on both cores (the bare-boot prints "[C] Ada runtime up
--  on both cores"); this environment task then idles.  Start adding code:
--  library-level tasks (Jorvik requires them at library level; pin with
--  CPU => 1 for core 0, CPU => 2 for core 1), protected interrupt handlers
--  (Ada.Interrupts.Names + Attach_Handler), peripheral drivers.
procedure Main is
begin
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
EOF

    cat > "$dir/build.sh" <<'EOF'
#!/bin/bash
# IDF-free build via the shared bare-boot (examples/common/bare).
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/../common/bare/bare_build.sh" "$HERE" "_ada_main"
EOF

    cat > "$dir/flash.sh" <<'EOF'
#!/bin/bash
# Flash via the vendored 2nd-stage bootloader + app.bin (esptool).  $1 = port.
HERE="$(cd "$(dirname "$0")" && pwd)"
exec bash "$HERE/../common/bare/bare_flash.sh" "$HERE" "$1"
EOF

    cat > "$dir/.gitignore" <<'EOF'
/obj/
/.noidf/
/app.bin
/app.elf
/app.map
EOF

    chmod +x "$dir/build.sh" "$dir/flash.sh"
    echo "x: created examples/$name"
    echo "   edit your code:           examples/$name/src/main.adb"
    echo "   build + flash + monitor:  ./x run $name"
}

# -- release the adapter -------------------------------------------------------
cmd_kill_openocd () {
    # A stray OpenOCD keeps the board's built-in USB-JTAG adapter open, which
    # blocks any new OpenOCD ("cannot connect to OpenOCD") AND holds the matching
    # /dev/ttyACM serial port.  pkill -x (EXACT match) -- never -f, which would
    # match this script's own command line and SIGKILL the shell.
    if pkill -x openocd 2>/dev/null; then
        echo "x: killed running OpenOCD -- USB-JTAG / serial ports released"
    else
        echo "x: no OpenOCD running -- nothing to kill"
    fi
}

# -- VS Code extension --------------------------------------------------------
IDE_VSIX="$ROOT/ide/vscode-ada-esp32/vscode-ada-esp32.vsix"
cmd_install_ide () {   # install the committed extension -- NO Node needed
    command -v code >/dev/null || die "the VS Code 'code' CLI isn't on PATH (in VS Code: \
Ctrl-Shift-P -> 'Shell Command: Install code command')"
    [ -f "$IDE_VSIX" ] || die "no prebuilt extension at $IDE_VSIX -- run './x build-ide' (needs Node) or 'git pull'"
    code --install-extension "$IDE_VSIX" --force
    echo "x: installed the Ada ESP32 extension -- reload VS Code (Developer: Reload Window)"
}
cmd_build_ide () {     # (maintainer) rebuild the committed .vsix from source -- needs Node/npm
    command -v npm >/dev/null || die "npm not found -- needed to rebuild the extension (users just run install-ide)"
    ( cd "$(dirname "$IDE_VSIX")" && npm install && npm run package )
    echo "x: rebuilt $IDE_VSIX -- commit it (it's tracked), then './x install-ide'"
}

cmd_install_vim () {   # symlink the Vim plugin into Vim's + Neovim's native package dir
    local src="$ROOT/ide/vim-ada-esp32" n=0 d
    [ -d "$src/plugin" ] || die "no Vim plugin at $src"
    if command -v vim >/dev/null; then
        d="$HOME/.vim/pack/ada-esp32/start"; mkdir -p "$d"
        ln -sfn "$src" "$d/vim-ada-esp32"; echo "x: linked Vim  -> $d/vim-ada-esp32"; n=1
    fi
    if command -v nvim >/dev/null; then
        d="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/ada-esp32/start"; mkdir -p "$d"
        ln -sfn "$src" "$d/vim-ada-esp32"; echo "x: linked Neovim -> $d/vim-ada-esp32"; n=1
    fi
    [ "$n" = 1 ] || die "neither 'vim' nor 'nvim' on PATH"
    #  It's a SYMLINK into the repo, so unlike the .vsix it self-updates:
    echo "x: restart Vim to load it.  'git pull' updates the plugin in place (no reinstall)."
}

# -- docs ---------------------------------------------------------------------
cmd_docs () {   # build + run the HAL reference generator -> docs/HAL_Reference.pdf
    local hal="$ROOT/libs/esp32s3_hal"
    local docs="$hal/docs"
    . "$ROOT/tools/sdk-env.sh"
    esp32s3_toolchain_on_path
    gprbuild -q -P "$docs/gen_reference.gpr" || die "gen_reference build failed"
    "$docs/gen_reference" "$hal"
}

# -- stack & memory analysis --------------------------------------------------
#  Static stack analysis uses GCC's -fstack-usage / -fcallgraph-info, emitted only
#  when STACK_ANALYSIS=1 (a normal build is byte-identical).  --run additionally
#  flashes the example and captures its runtime high-water-mark report over serial
#  (the example must call ESP32S3.Stack_Usage.Report).
# The static analyser is a native Ada host tool (tools/stack_report), built on
# demand exactly like the HAL doc generator -- no Python.  esp32s3_toolchain_on_path
# puts gprbuild + the native GNAT on PATH; the build is incremental, so this is a
# no-op once compiled.  Done in a subshell so x's own PATH is left untouched.
build_stack_tool () {
    ( . "$ROOT/tools/sdk-env.sh" && esp32s3_toolchain_on_path \
      && gprbuild -q -P "$ROOT/tools/stack_report/stack_report.gpr" ) \
      || die "could not build tools/stack_report (need the native GNAT toolchain)"
}

cmd_stack () {
    local e top=12 run="" port="$PORT_DEFAULT"
    e="$(resolve "${1:-}")"; shift || true
    while [ $# -gt 0 ]; do case "$1" in
        --top) top="$2"; shift 2;;
        --run) run=1; shift;;
        -p|--port) port="$2"; shift 2;;
        *) shift;;
    esac; done
    build_stack_tool
    echo "x: stack analysis build of $(short "$e") (STACK_ANALYSIS=1, forces rebuild)..." >&2
    cmd_clean "$e" >/dev/null
    ( cd "$EXROOT/$e" && env STACK_ANALYSIS=1 $(prof_env auto) bash build.sh ) \
        >/dev/null 2>&1 || die "analysis build failed (try: STACK_ANALYSIS=1 ./x build $(short "$e"))"
    "$ROOT/tools/stack_report/stack_report" "$EXROOT/$e/obj" --top "$top" \
        || die "stack_report failed"
    if [ -n "$run" ]; then
        device_preflight "$port" || exit $?
        echo
        echo "x: flashing + capturing runtime high-water mark (look for 'stack:' lines)..." >&2
        ( cd "$EXROOT/$e" && bash flash.sh "$port" ) >/dev/null 2>&1 || die "flash failed"
        #  Pure-bash capture: let the USB-serial-JTAG re-enumerate after the reset,
        #  read the console raw for ~20 s, then surface any "stack:" report lines.
        local cap; cap="$(mktemp)"
        sleep 2
        stty -F "$port" "$BAUD" raw -echo 2>/dev/null || true
        timeout 20 cat "$port" > "$cap" 2>/dev/null || true
        if grep -qi "stack:" "$cap"; then
            grep -i "stack:" "$cap" | sed 's/^/   /'
        else
            echo "   (no 'stack:' report seen -- does this example call ESP32S3.Stack_Usage.Report?)"
        fi
        rm -f "$cap"
    fi
}

#  Memory footprint: section sizes from the linked ELF + the heap-arena / PSRAM
#  bounds from the example's board.ads.  A one-screen "where did the RAM/flash go".
cmd_mem () {
    local e elf; e="$(resolve "${1:-}")"; shift || true
    elf="$EXROOT/$e/app.elf"
    [ -f "$elf" ] || { echo "x: building $(short "$e") first..." >&2; cmd_build "$e" >/dev/null; }
    . "$ROOT/tools/sdk-env.sh"; esp32s3_toolchain_on_path
    echo "== Section sizes ($(short "$e")) -- loaded sections only =="
    #  Skip ELF metadata (debug/comment/xtensa props) and the *dummy* sections the
    #  ESP32-S3 linker inserts purely to align the flash-cache MMU mapping (they
    #  reserve address space, not real storage).  Classify the rest by placement.
    xtensa-esp32-elf-size -A "$elf" | awk '
        $1 ~ /^\.(debug|comment|xtensa|xt\.|note|symtab|strtab|shstrtab)/ {next}
        $1 ~ /dummy/ {next}
        $2 ~ /^[0-9]+$/ && $2+0 > 0 && $1 ~ /^\./ {
            name=$1; sz=$2;
            if      (name ~ /^\.iram/)                 { iram+=sz;  cls="IRAM (RAM)" }
            else if (name ~ /^\.ext_ram/)              { psram+=sz; cls="PSRAM" }
            else if (name ~ /bss|noinit/)              { bss+=sz;   cls="DRAM .bss" }
            else if (name ~ /^\.dram.*data/)           { dram+=sz;  cls="DRAM .data" }
            else if (name ~ /rodata/)                  { rodata+=sz;cls="flash rodata" }
            else                                       { code+=sz;  cls="flash code" }
            printf "   %-22s %9d B   %s\n", name, sz, cls
        }
        END {
            printf "\n   flash (code + rodata + IRAM image): %9d B\n", code+rodata+iram;
            printf "   RAM   DRAM .data ............ %9d B  (copied from flash at boot)\n", dram;
            printf "   RAM   DRAM .bss / stacks ..... %9d B  (zero-init, not in flash)\n", bss;
            printf "   RAM   IRAM ................... %9d B  (instructions in RAM)\n", iram;
            printf "   RAM   total .................. %9d B\n", dram+bss+iram;
            if (psram>0) printf "   PSRAM reserved .............. %9d B\n", psram;
        }'
    echo
    echo "== Configured bounds (board.ads) =="
    ( cd "$ROOT" && ./x config "$(short "$e")" 2>/dev/null ) | sed 's/^/   /'
}

# -- dispatch -----------------------------------------------------------------
# Skipped when this file is SOURCED (not executed) -- the standalone-project
# launcher `tools/bin/esp32-ada` sources x to reuse its helpers (monitor_tool,
# serial_from_port, find_gdb, cmd_config, ...) without re-running the dispatch.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  cmd="${1:-}"; shift || true
  case "$cmd" in
    list)            cmd_list "$@" ;;
    new|init)        cmd_new "$@" ;;   # init is an alias of new (matches esp32-ada)
    build)           cmd_build "$@" ;;
    flash)           cmd_flash "$@" ;;
    run)             cmd_run "$@" ;;
    monitor|mon)     cmd_monitor "$@" ;;
    clean)           cmd_clean "$@" ;;
    stack)           cmd_stack "$@" ;;
    mem|memory)      cmd_mem "$@" ;;
    config|cfg)         cmd_config "$@" ;;
    get-debug-tools)    cmd_get_debug_tools "$@" ;;
    get-openocd)        cmd_get_openocd "$@" ;;
    get-gdb)            cmd_get_gdb "$@" ;;
    debug)              cmd_debug "$@" ;;
    kill-openocd)       cmd_kill_openocd "$@" ;;
    setup-device)       cmd_setup_device "$@" ;;
    check-device)       cmd_check_device "$@" ;;
    install-ide)        cmd_install_ide "$@" ;;
    build-ide)          cmd_build_ide "$@" ;;
    install-vim)        cmd_install_vim "$@" ;;
    docs)               cmd_docs "$@" ;;
    ""|-h|--help|help)
        sed -n '3,36p' "$0" | sed 's/^#  \{0,1\}//; s/^#//' ;;
    *) die "unknown command '$cmd' (try './x help')" ;;
  esac
fi
