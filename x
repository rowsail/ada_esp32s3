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
#    ./x flash   <example> [-p PORT] [-P PROF]   build + flash over USB ROM
#    ./x run     <example> [-p PORT] [-c CON] [-P PROF]  build + flash + monitor
#    ./x monitor [-p PORT] [-c CON]    open the serial console (115200)
#    ./x ports [--json]                the boards' serial ports, found by USB id,
#                                     and which ones flash/monitor would use
#    ./x clean   [<example>]           remove build artifacts (all if omitted)
#    ./x test    [host [SUITE]|lib|examples]  everything checkable without a board:
#                                     host suites, the libraries on all three
#                                     runtime profiles (warnings are failures),
#                                     and a build of every example
#    ./x analyze [<lib>] [--style] [--update-baseline]   static analysis
#                                     (adalang_analyzer): report findings NOT
#                                     already in tools/analyzer-baselines/.
#                                     Default = defects; --style = readability
#                                     (complexity, duplication, constructs that
#                                     obscure intent), its own baseline.
#                                     --do178c[=A|B|C|D] instead WRITES
#                                     per-objective DO-178C evidence reports to
#                                     build/do178c/ (a report, not a gate)
#    ./x analyze <example> [--style]   an example's own code: every finding
#    ./x analyze FILE.adb... [--style] those files, with their project for
#                                     context (an example's, a library's, ...)
#                                     (--gpr FILE: a project file other than
#                                     the one found -- see gpr_of_dir)
#    ./x prove [FILE...]               SPARK proof: the SDK's whole pass
#                                     (book/prove/prove.sh), or those files with
#                                     the proof project that lists each
#    ./x setup-analyzer [--check]      install adalang_analyzer (alr; builds
#                                     Libadalang, so it takes a while)
#    ./x stack   <example> [--top N] [--run]   static stack analysis (per-frame +
#                                      worst-case call chains); --run adds the
#                                      runtime high-water mark over serial
#    ./x mem     <example>             memory footprint: section sizes + bounds
#    ./x config <example> [show|--json]   show flash/PSRAM size (its board.ads)
#    ./x config <example> flash-size <SIZE>  set flash size (e.g. 4MB, 0x800000)
#    ./x config <example> psram-size <SIZE>  set PSRAM size (rebuilds its bootloader)
#    ./x setup-toolchain [--check]     one-time: the validated xtensa + native GNAT and
#                                     gprbuild (through alr, without changing its
#                                     default toolchain) and the xtensa-dynconfig
#                                     plugin; --check only reports (exit 1 if missing)
#    ./x setup-clipboard [--check]     Turbo Ada's system clipboard: install xclip or
#                                     wl-clipboard if the desktop needs one (sudo)
#    ./x setup-formatter [--check]     gnatformat for Turbo Ada's Edit | Format
#                                     (alr install gnatformat_bin; setup-toolchain does it)
#    ./x get-debug-tools               fetch pinned OpenOCD + GDB (for debugging)
#    ./x debug   <example> [-p PORT] [--smp] [--attach]   on-chip debug (OpenOCD+GDB)
#                                     --smp    : both LX7 cores as gdb threads (info threads)
#                                     --attach : post-mortem halt-in-place (no reset; a hang/crash)
#    ./x debug-server [-p PORT] [--smp]   OpenOCD alone, pinned to the board, until killed
#                                     (an IDE's own GDB connects to :3333)
#    ./x debug-info <example>          GDB=, ELF=, MAIN= for an IDE's debugger
#    ./x kill-openocd                  kill every OpenOCD (releases captured USB-JTAG ports)
#    ./x setup-device [-h]             one-time: install udev rule + groups for USB access (sudo)
#    ./x check-device [-p PORT]        report whether the board's port is accessible
#    ./x install-ide                   install the VS Code extension (committed .vsix; no Node)
#    ./x build-ide                     (maintainer) rebuild the committed .vsix (needs Node)
#    ./x install-vim                   symlink the Vim/Neovim plugin (auto-updates on git pull)
#    ./x turbo   [<example>] [FILE...] Turbo Ada: the Turbo C++ style text-mode IDE
#                                     (ide/turbo-ada; built on first use)
#    ./x env     <example|SUITE> [-P PROF] [--gpr FILE]   KEY=VALUE lines: the
#                                     environment a compile of the example (ESP32-S3)
#                                     or of a host test suite (native) needs (PATH,
#                                     GPR_FILE, ...); --gpr: a project file other
#                                     than the one found
#    ./x --machine <verb> ...          the verb's output with @x lines for IDEs
#                                     (stages, diagnostics, artifacts, result)
#    ./x docs                          build the HAL API reference PDF (libs/esp32s3_hal/docs/)
#
#  <example> accepts the short name (gpio0_blink) or the full dir
#  (esp32s3_gpio0_blink).
#
#  Ports.  PORT is the chip's USB-Serial/JTAG port (flash, debug, and the
#  default console): -p, else $ESPPORT, else the one Espressif USB/JTAG unit
#  plugged in.  CON is the console: -c, else $ESPCONSOLE, else "jtag" (= PORT);
#  "uart" is the board's USB-UART bridge (UART0: the boot log, and apps that
#  route the console there), or give a device.  With several boards attached
#  the choice is listed instead of guessed.
#
set -euo pipefail
#  BASH_SOURCE[0] (not $0) so ROOT is right when x is SOURCED as a library too
#  (tools/bin/esp32-ada sources us; $0 would be esp32-ada's path).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXROOT="$ROOT/examples"
CFG="$EXROOT/common/bare/config"
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

short () { echo "${1#esp32s3_}"; }

# -- host test suites (the native side) ---------------------------------------
#  libs/<lib>/test/<suite>/ with a run.sh: the library code built for the PC
#  with the native GNAT.  Named by <suite> (the directory names are unique).
host_suites () {   # every suite dir, sorted
    find "$ROOT/libs" -path '*/test/*/run.sh' 2>/dev/null | sort | while read -r r; do
        dirname "$r"
    done
}
resolve_suite () {   # $1 = suite name (or libs/.../test/<suite>) -> its dir, or nothing
    local n="${1%/}" d
    n="${n##*/}"
    [ -n "$n" ] || return 0
    for d in $(host_suites); do
        [ "$(basename "$d")" = "$n" ] && { echo "$d"; return 0; }
    done
    return 0
}   # full dir -> short label (esp32s3_jorvik_profile_test -> jorvik_profile_test)

# -- serial monitor -----------------------------------------------------------
monitor_tool () {  # pick the first available serial console for $1=port
    local port="$1"
    if [ -n "${ESP_MONITOR:-}" ]; then eval "$ESP_MONITOR"; return; fi
    if python3 -c 'import serial.tools.miniterm' 2>/dev/null; then
        # --eol CR: send just CR on Enter (miniterm defaults to CRLF, which the
        # line-oriented consoles on the device see as a spurious empty line).
        exec python3 -m serial.tools.miniterm --raw --eol CR "$port" "$BAUD"
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

# -- serial ports -------------------------------------------------------------
#  Found by USB vendor:product id (Linux sysfs), so nothing needs setting with
#  one board attached.  Two roles:
#    jtag  the ESP32-S3's own USB-Serial/JTAG unit (303a:1001): flashing,
#          OpenOCD, and the console unless the app moves it
#    uart  a USB-UART bridge wired to UART0 (WCH CH34x, Silicon Labs CP210x,
#          FTDI, Prolific): the ROM/bootloader log, and apps whose Console
#          package routes the console to a UART
port_usb_dir () {   # $1 = tty node -> its USB device's sysfs dir, or nothing
    local t d; t="$(basename "$(readlink -f "$1" 2>/dev/null)")"
    d="$(readlink -f "/sys/class/tty/$t/device" 2>/dev/null)" || return 0
    while [ -n "$d" ] && [ "$d" != / ] && [ ! -f "$d/idVendor" ]; do d="$(dirname "$d")"; done
    [ -f "$d/idVendor" ] && printf '%s' "$d"
    return 0
}
list_ports () {   # one line per board port: ROLE PATH VID:PID SERIAL PRODUCT...
    local p d id role
    for p in /dev/ttyACM* /dev/ttyUSB*; do
        [ -e "$p" ] || continue
        d="$(port_usb_dir "$p")"; [ -n "$d" ] || continue
        id="$(cat "$d/idVendor"):$(cat "$d/idProduct")"
        case "$id" in
            303a:1001)                        role=jtag ;;
            1a86:*|10c4:*|0403:*|067b:*)      role=uart ;;
            *)                                continue ;;
        esac
        printf '%s %s %s %s %s\n' "$role" "$p" "$id" \
            "$(cat "$d/serial" 2>/dev/null || echo -)" "$(cat "$d/product" 2>/dev/null || echo -)"
    done
}
pick_port () {   # $1 = role -> the one port with that role; dies listing them if ambiguous
    local role="$1" found n
    found="$(list_ports | awk -v r="$role" '$1 == r')"
    n="$(printf '%s' "$found" | grep -c . || true)"
    if [ "$n" = 1 ]; then printf '%s' "$found" | awk '{print $2}'; return 0; fi
    [ "$n" = 0 ] && return 1
    {   echo "x: several $( [ "$role" = jtag ] && echo 'ESP32-S3 USB/JTAG ports' || echo 'USB-UART bridges' ) -- which board?"
        printf '%s\n' "$found" | awk '{ printf "x:   %-14s %s  serial %s\n", $2, $3, $4 }'
        if [ "$role" = jtag ]; then echo "x: choose with -p PORT or \$ESPPORT (Turbo Ada: Options | Target)."
        else echo "x: choose with -c PORT or \$ESPCONSOLE (Turbo Ada: Options | Target)."; fi
    } >&2
    return 2
}
flash_port () {   # [$1 = -p value] -> the USB/JTAG (flash/debug) port
    [ -n "${1:-}" ] && { printf '%s' "$1"; return 0; }
    [ -n "${ESPPORT:-}" ] && { printf '%s' "$ESPPORT"; return 0; }
    local p rc=0
    p="$(pick_port jtag)" || rc=$?
    [ "$rc" = 2 ] && return 1
    [ -n "$p" ] && { printf '%s' "$p"; return 0; }
    #  No USB/JTAG unit: a board reached only through its UART bridge (esp_flash
    #  does the classic DTR/RTS auto-reset too), else the historical default.
    rc=0; p="$(pick_port uart)" || rc=$?
    [ "$rc" = 2 ] && return 1
    printf '%s' "${p:-/dev/ttyACM0}"
}
console_port () {   # $1 = -c value (may be empty), $2 = the flash port -> the console port
    local c="${1:-${ESPCONSOLE:-jtag}}" p rc=0
    case "$c" in
        jtag|usb|"") printf '%s' "$2" ;;
        uart)
            p="$(pick_port uart)" || rc=$?
            [ "$rc" = 2 ] && return 1
            [ -n "$p" ] || { echo "x: no USB-UART bridge found for the console (-c uart)" >&2; return 1; }
            printf '%s' "$p" ;;
        *) printf '%s' "$c" ;;
    esac
}
cmd_ports () {   # [--json]
    local lines fp cp
    lines="$(list_ports)"
    fp="$(flash_port 2>/dev/null)" || fp=""
    cp="$( [ -n "$fp" ] && console_port "" "$fp" 2>/dev/null)" || cp=""
    if [ "${1:-}" = "--json" ]; then
        printf '{"ports":['
        printf '%s\n' "$lines" | awk 'NF { if (n++) printf ","; p=""; for (i=5;i<=NF;i++) p=p (i>5?" ":"") $i;
            printf "{\"role\":\"%s\",\"path\":\"%s\",\"id\":\"%s\",\"serial\":\"%s\",\"product\":\"%s\"}", $1,$2,$3,$4,p }'
        printf '],"flash":"%s","console":"%s"}\n' "$fp" "$cp"
        return 0
    fi
    if [ -z "$lines" ]; then
        echo "no ESP32-S3 USB/JTAG port or USB-UART bridge found"
    else
        printf '%s\n' "$lines" | awk '{ p=""; for (i=5;i<=NF;i++) p=p " " $i;
            printf "%-5s %-14s %s  serial %s %s\n", $1, $2, $3, $4, p }'
    fi
    echo "flash:   ${fp:-(ambiguous: pass -p or set ESPPORT)}"
    echo "console: ${cp:-(ambiguous: pass -c or set ESPCONSOLE)}"
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
        echo "x:   plug in the ESP32-S3, or pass -p <port> / set \$ESPPORT ('./x ports' lists them)." >&2
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
    local port=""
    while [ $# -gt 0 ]; do case "$1" in -p|--port) port="$2"; shift 2;; *) shift;; esac; done
    port="$(flash_port "$port")" || exit 1
    if device_preflight "$port"; then
        echo "x: device OK: $port is accessible"
    else
        return $?
    fi
}

cmd_flash () {   # build (incremental) + flash: never an out-of-date app.bin
    local e port="" prof="auto"; e="$(resolve "${1:-}")"; shift || true
    while [ $# -gt 0 ]; do case "$1" in
        -p|--port) port="$2"; shift 2;;
        -P|--profile) prof="$2"; shift 2;;
        *) shift;; esac
    done
    valid_profile "$prof"
    port="$(flash_port "$port")" || exit 1
    device_preflight "$port" || exit $?
    cmd_build "$e" --profile "$prof"
    echo "x: flash $port" >&2
    ( cd "$EXROOT/$e" && bash flash.sh "$port" )
    #  Record the flashed board's USB-JTAG serial so `./x debug` / the openocd task
    #  pin to THIS board (not the first 303a device) -- see tools/openocd.sh.
    local s; s="$(serial_from_port "$port")"
    [ -n "$s" ] && printf '%s\n' "$s" > "$ROOT/tools/.jtag_serial"
}

cmd_monitor () {
    local port="" con=""
    while [ $# -gt 0 ]; do case "$1" in
        -p|--port) port="$2"; shift 2;;
        -c|--console) con="$2"; shift 2;;
        *) shift;; esac
    done
    con="${con:-${ESPCONSOLE:-jtag}}"
    case "$con" in jtag|usb) port="$(flash_port "$port")" || exit 1 ;; esac
    port="$(console_port "$con" "$port")" || exit 1
    device_preflight "$port" || exit $?
    echo "x: monitor $port @ $BAUD (Ctrl-C / Ctrl-A K to quit)" >&2
    monitor_tool "$port"
}

cmd_run () {   # build + flash + monitor
    local e port="" con="" prof="auto"; e="$(resolve "${1:-}")"; shift || true
    while [ $# -gt 0 ]; do case "$1" in
        -p|--port) port="$2"; shift 2;;
        -c|--console) con="$2"; shift 2;;
        -P|--profile) prof="$2"; shift 2;;
        *) shift;; esac
    done
    valid_profile "$prof"
    port="$(flash_port "$port")" || exit 1
    local cport; cport="$(console_port "$con" "$port")" || exit 1
    cmd_flash "$e" -p "$port" --profile "$prof"; cmd_monitor -p "$port" -c "$cport"
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
    local e elf gdb ocd_log ocd_pid port="" smp="" attach=""
    e="$(resolve "${1:-}")"; shift || true
    while [ $# -gt 0 ]; do case "$1" in
        -p|--port) port="$2"; shift 2;;
        --smp)     smp=1; shift;;        # both LX7 cores as gdb threads (info threads -> cpu0+cpu1)
        --attach)  attach=1; shift;;     # POST-MORTEM: halt in place (no reset), for a hang/crash
        *) shift;;
    esac; done
    port="$(flash_port "$port")" || exit 1
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
    #  Expanded NOW: the trap runs at script exit, after this function's
    #  locals are gone (set -u would fail on them, and OpenOCD -- holding the
    #  board's USB -- would be left running).
    trap "kill $ocd_pid 2>/dev/null; rm -f '$ocd_log'" EXIT
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

#  For an IDE that drives GDB itself (Turbo Ada's F7/F8 debugger): the server
#  on its own, and what to point GDB at.
cmd_debug_server () {   # [-p PORT] [--smp] -- OpenOCD in the foreground until killed
    local port="" smp=""
    while [ $# -gt 0 ]; do case "$1" in
        -p|--port) port="$2"; shift 2;;
        --smp)     smp=1; shift;;
        *) shift;;
    esac; done
    port="$(flash_port "$port")" || exit 1
    #  Flash breakpoints on (OpenOCD patches a BREAK into flash): as many
    #  breakpoints as wanted.  With flash support off each one takes one of the
    #  S3's two hardware breakpoints, and a third is accepted yet never fires.
    #  The flash probe that needs fails on a core idling in WAITI, so halt it at
    #  reset first -- the IDE resets it again anyway.
    ESPPORT="$port" ESP_FLASH_SIZE="${ESP_FLASH_SIZE:-auto}" ${smp:+ESP_RTOS=hwthread} \
        exec bash "$ROOT/tools/openocd.sh" -c "init" -c "reset halt"
}
debug_info () {   # $1 = project dir -> GDB=, ELF=, MAIN= lines
    local dir="$1" main=""
    [ -f "$dir/app.elf" ] || die "no $dir/app.elf -- build first"
    [ -f "$dir/.noidf/ada_main.used" ] && main="$(cat "$dir/.noidf/ada_main.used")"
    printf 'GDB=%s\nELF=%s\nMAIN=%s\n' "$(find_gdb)" "$dir/app.elf" "${main:-_ada_main}"
}
cmd_debug_info () {   # <example>
    local e; e="$(resolve "${1:-}")"
    debug_info "$EXROOT/$e"
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

    # Console serial-port selection: one clearly-named file per project (the main
    # `with`s it; edit src/console.adb to send the console to a UART).  Default is
    # the built-in USB-Serial/JTAG console.
    cp "$EXROOT/common/bare/config/console.ads.template" "$dir/src/console.ads"
    cp "$EXROOT/common/bare/config/console.adb.template" "$dir/src/console.adb"

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

--  Console serial-port selection -- edit src/console.adb to pick the port.
with Console;
pragma Unreferenced (Console);

--  <one line: what this example demonstrates>
--
--  Build & run:  ./x run <name>   (or, out of tree, esp32-ada run) -- build,
--                flash, and open the serial monitor.  Default embedded profile
--                (catchable contracts + RAII Session handles); change
--                ESP32S3_RTS_PROFILE in build.sh for light-tasking / full.
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
# Defaults to the embedded runtime profile (exception-capable: catchable
# contracts + RAII Session handles + a heap).  For light-tasking (heap-less, no
# finalization) or full, change ESP32S3_RTS_PROFILE below.
HERE="$(cd "$(dirname "$0")" && pwd)"
export ESP32S3_RTS_PROFILE=embedded
export HEAP_SIZE=65536 ENV_STACK_SIZE=65536
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

# -- toolchain setup ----------------------------------------------------------
#  Everything a build needs that is not in this repository: the validated
#  compilers and gprbuild (sdk-env.sh's KNOWN_GOOD versions), fetched through
#  Alire into its toolchain folder -- where sdk-env.sh looks -- and the
#  xtensa-dynconfig plugin (the core description the xtensa GNAT reads from
#  XTENSA_GNU_CONFIG; without it objects silently come out big-endian), built
#  from the vendored source in crates/xtensa-dynconfig.  Idempotent.
#
#  The downloads are selected with `alr toolchain --select --local` inside a
#  scratch workspace, so the user's own default toolchain is left alone.
setup_ws () {   # a throwaway Alire workspace for --local toolchain selection
    local base="${XDG_CACHE_HOME:-$HOME/.cache}/esp32s3-ada"
    if [ ! -f "$base/toolchain_ws/alire.toml" ]; then
        rm -rf "$base/toolchain_ws"; mkdir -p "$base"
        ( cd "$base" && alr -n init --bin toolchain_ws >/dev/null 2>&1 ) || return 1
    fi
    printf '%s' "$base/toolchain_ws"
}
dynconfig_le () {   # $1 = xtensa gcc: does it emit little-endian objects now?
    local t; t="$(mktemp -d)"
    printf 'int x;\n' > "$t/t.c"
    "$1" -c "$t/t.c" -o "$t/t.o" 2>/dev/null \
        && [ "$(od -An -tx1 -j5 -N1 "$t/t.o" | tr -d ' ')" = "01" ]
    local rc=$?; rm -rf "$t"; return $rc
}
#  The system clipboard, for Turbo Ada's Cut/Copy/Paste: the helper program
#  its desktop needs (ide/turbo-ada/src/turbo-clipboard.adb picks the same
#  way).  macOS (pbcopy), Windows and WSL (PowerShell) have one built in; a
#  terminal with no display (ssh) uses OSC 52 instead and needs none.
clipboard_helper () {   # the helper in use, or nothing
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null; then echo wl-copy
    elif [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null; then echo xclip
    elif [ -n "${DISPLAY:-}" ] && command -v xsel >/dev/null; then echo xsel
    elif command -v pbcopy >/dev/null; then echo pbcopy
    elif command -v powershell.exe >/dev/null || command -v powershell >/dev/null; then echo powershell
    fi
}
clipboard_package () {   # the package that would give this desktop one, or nothing
    [ -n "$(clipboard_helper)" ] && return 0
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then echo wl-clipboard
    elif [ -n "${DISPLAY:-}" ]; then echo xclip
    fi
}
package_install_command () {   # $1 = package: the command that installs it, or nothing
    local su=""
    [ "$(id -u)" = 0 ] || su="sudo "
    if command -v apt-get >/dev/null; then echo "${su}apt-get install -y $1"
    elif command -v dnf >/dev/null; then echo "${su}dnf install -y $1"
    elif command -v yum >/dev/null; then echo "${su}yum install -y $1"
    elif command -v pacman >/dev/null; then echo "${su}pacman -S --needed --noconfirm $1"
    elif command -v zypper >/dev/null; then echo "${su}zypper --non-interactive install $1"
    elif command -v apk >/dev/null; then echo "${su}apk add $1"
    fi
}
cmd_setup_clipboard () {   # [--check | --ask]
    #  --check: report only.  --ask: install if the user says so (on a
    #  terminal; else report).  Neither: install (sudo may ask a password).
    local mode="${1:-}" pkg how reply
    if [ -n "$(clipboard_helper)" ]; then
        echo "[setup]   clipboard helper  ok ($(clipboard_helper))"; return 0
    fi
    pkg="$(clipboard_package)"
    if [ -z "$pkg" ]; then
        echo "[setup]   clipboard helper  none needed (no display: the terminal's OSC 52)"; return 0
    fi
    how="$(package_install_command "$pkg")"
    echo "[setup]   clipboard helper  not installed (optional): $pkg${how:+ -- $how}"
    [ "$mode" = --check ] && return 0
    [ -n "$how" ] || { echo "[setup]   (no package manager known here: install $pkg yourself)"; return 1; }
    if [ "$mode" = --ask ]; then
        [ -t 0 ] && [ -t 1 ] || return 0
        printf '[setup]   install it now for Turbo Ada'\''s Cut/Copy/Paste? [y/N] '
        read -r reply || reply=""
        case "$reply" in y|Y|yes|Yes) ;; *) return 0;; esac
    fi
    echo "[setup] installing $pkg: $how"
    $how || { echo "[setup] could not install $pkg"; return 1; }
    echo "[setup]   clipboard helper  ok ($(clipboard_helper))"
}
#  gnatformat, for Turbo Ada's Edit | Format (the language server formats
#  with its own copy when it runs; this is the one the IDE uses without it).
#  Alire's binary release, into ~/.alire/bin like the other alr tools.
formatter_path () {   # the gnatformat in use, or nothing
    if command -v gnatformat >/dev/null; then command -v gnatformat
    elif [ -x "$HOME/.alire/bin/gnatformat" ]; then echo "$HOME/.alire/bin/gnatformat"
    fi
}
cmd_setup_formatter () {   # [--check]
    local f; f="$(formatter_path)"
    if [ -n "$f" ]; then echo "[setup]   gnatformat  ok ($f)"; return 0; fi
    echo "[setup]   gnatformat  not installed (optional): alr install gnatformat_bin"
    [ "${1:-}" = --check ] && return 0
    command -v alr >/dev/null || { echo "[setup]   (Alire's alr installs it: see QUICKSTART.md step 1)"; return 1; }
    case "$(uname -s)" in
        Linux|Darwin) ;;
        *) echo "[setup]   (no binary release for this system: 'alr install gnatformat' builds it)"; return 1 ;;
    esac
    echo "[setup] installing gnatformat: alr -n install gnatformat_bin"
    alr -n install gnatformat_bin || { echo "[setup] could not install gnatformat"; return 1; }
    echo "[setup]   gnatformat  ok ($(formatter_path))"
}
#  adalang_analyzer, for ./x analyze and Turbo Ada's Analyze file / project.
#  An Alire crate built from source (with Libadalang: many minutes), so the
#  set-up only installs it on a yes.
analyzer_path () {
    if command -v adalang_analyzer >/dev/null; then command -v adalang_analyzer
    elif [ -x "$HOME/.alire/bin/adalang_analyzer" ]; then echo "$HOME/.alire/bin/adalang_analyzer"
    fi
}
cmd_setup_analyzer () {   # [--check | --ask]
    local a reply; a="$(analyzer_path)"
    if [ -n "$a" ]; then echo "[setup]   adalang_analyzer  ok ($a)"; return 0; fi
    echo "[setup]   adalang_analyzer  not installed (optional): alr install adalang_analyzer"
    [ "${1:-}" = --check ] && return 0
    command -v alr >/dev/null || { echo "[setup]   (Alire's alr installs it: see QUICKSTART.md step 1)"; return 1; }
    if [ "${1:-}" = --ask ]; then
        [ -t 0 ] && [ -t 1 ] || return 0
        printf '[setup]   build and install it now (it builds Libadalang: many minutes)? [y/N] '
        read -r reply || reply=""
        case "$reply" in y|Y|yes|Yes) ;; *) return 0;; esac
    fi
    echo "[setup] installing adalang_analyzer: alr -n install adalang_analyzer"
    alr -n install adalang_analyzer || { echo "[setup] could not install adalang_analyzer"; return 1; }
    echo "[setup]   adalang_analyzer  ok ($(analyzer_path))"
}

cmd_setup_toolchain () {   # [--check]
    local check=0
    [ "${1:-}" = "--check" ] && check=1
    . "$ROOT/tools/sdk-env.sh"
    local missing=() spec name ver dir n_bad=0
    echo "[setup] toolchains in $ESP32S3_ADA_TOOLCHAINS"
    for spec in "gnat_xtensa_esp32_elf=$ESP32S3_GNAT_KNOWN_GOOD" \
                "gnat_native=$ESP32S3_GNAT_KNOWN_GOOD" \
                "gprbuild=$ESP32S3_GPRBUILD_KNOWN_GOOD"; do
        name="${spec%%=*}"; ver="${spec#*=}"
        dir="$(ls -d "$ESP32S3_ADA_TOOLCHAINS/${name}_${ver}_"*/bin 2>/dev/null | head -1 || true)"
        if [ -n "$dir" ]; then
            echo "[setup]   $name $ver  ok"
        else
            echo "[setup]   $name $ver  missing"; missing+=("$spec")
        fi
    done
    local dyncfg="$ROOT/crates/xtensa-dynconfig/xtensa-dynconfig/xtensa_esp32s3.so"
    if [ -f "$dyncfg" ]; then
        echo "[setup]   xtensa-dynconfig plugin  ok"
    else
        echo "[setup]   xtensa-dynconfig plugin  missing"
    fi
    if [ "$check" = 1 ]; then
        cmd_setup_formatter --check
        cmd_setup_analyzer --check
        cmd_setup_clipboard --check
        [ ${#missing[@]} -eq 0 ] && [ -f "$dyncfg" ] && { echo "[setup] ready"; return 0; }
        echo "[setup] not ready: run './x setup-toolchain'"; return 1
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        if [ -n "${ESP32S3_ADA_SDK:-}" ] && [ -d "$ESP32S3_ADA_SDK/toolchains" ]; then
            die "the bundled toolchains/ lacks ${missing[*]} -- it is a bundle, not something to download into"
        fi
        command -v alr >/dev/null \
            || die "Alire (alr) is needed to download ${missing[*]}: see QUICKSTART.md step 1, or let Turbo Ada fetch it"
        local alr_tc
        alr_tc="$(alr version 2>/dev/null | sed -n 's/^toolchain folder: *//p')"
        if [ -n "$alr_tc" ] && [ "$(cd "$alr_tc" 2>/dev/null && pwd -P)" != "$(cd "$ESP32S3_ADA_TOOLCHAINS" 2>/dev/null && pwd -P)" ]; then
            echo "[setup] note: alr keeps toolchains in $alr_tc; this SDK looks in $ESP32S3_ADA_TOOLCHAINS" >&2
            echo "[setup]       (set ESP32S3_ADA_TOOLCHAINS=$alr_tc)" >&2
        fi
        local ws; ws="$(setup_ws)" || die "could not make an Alire workspace for the download"
        for spec in "${missing[@]}"; do
            echo "[setup] downloading $spec (alr; your default toolchain is not changed)"
            ( cd "$ws" && alr -n toolchain --select --local "$spec" ) || die "alr could not fetch $spec"
        done
        for spec in "${missing[@]}"; do
            name="${spec%%=*}"; ver="${spec#*=}"
            ls -d "$ESP32S3_ADA_TOOLCHAINS/${name}_${ver}_"*/bin >/dev/null 2>&1 \
                || die "alr fetched $spec into ${alr_tc:-its toolchain folder}, not $ESP32S3_ADA_TOOLCHAINS (set ESP32S3_ADA_TOOLCHAINS)"
        done
    fi

    esp32s3_toolchain_on_path >/dev/null
    esp32s3_export_dynconfig "$ROOT" || die "could not build the xtensa-dynconfig plugin (needs gcc + make)"
    echo "[setup]   xtensa-dynconfig plugin  $XTENSA_GNU_CONFIG"

    #  The proof that matters: the cross compiler, with the plugin, emits
    #  little-endian objects.
    local gcc="$ESP32S3_GNAT_XTENSA_BIN/xtensa-esp32-elf-gcc"
    [ -x "$gcc" ] || die "no xtensa-esp32-elf-gcc in $ESP32S3_GNAT_XTENSA_BIN"
    dynconfig_le "$gcc" || die "$gcc does not produce little-endian ESP32-S3 objects with $XTENSA_GNU_CONFIG"
    echo "[setup] xtensa GNAT + dynconfig: little-endian ESP32-S3 objects"
    #  Optional, so never a reason to fail the set-up.  gnatformat comes from
    #  Alire, into the user's own ~/.alire/bin; the clipboard helper is a
    #  system package, so only on a yes (here on a terminal, or Turbo Ada's
    #  offer after it).
    cmd_setup_formatter || true
    cmd_setup_analyzer --ask || true
    cmd_setup_clipboard --ask || true
    echo "[setup] ready"
}

# -- Turbo Ada ----------------------------------------------------------------
#  The Turbo C++ style IDE in ide/turbo-ada.  A native host tool, built on demand
#  like tools/stack_report (incremental, so a no-op once compiled); it drives
#  this same ./x for build/flash/run, so it adds no build logic of its own.
TADA="$ROOT/ide/turbo-ada/bin/tada"
build_tada () {
    ( . "$ROOT/tools/sdk-env.sh" && esp32s3_toolchain_on_path \
      && gprbuild -q -p -j0 -P "$ROOT/ide/turbo-ada/turbo_ada.gpr" ) \
      || die "could not build ide/turbo-ada (needs the native GNAT toolchain:
   alr toolchain --select gnat_native gprbuild)"
}
cmd_turbo () {   # [<example>] [FILE...] -- open the IDE on an example, or on the SDK
    local dir="$ROOT"
    if [ -n "${1:-}" ] && [ "${1#-}" = "$1" ] && [ ! -e "$1" ]; then
        dir="$EXROOT/$(resolve "$1")"; shift
    fi
    build_tada
    exec "$TADA" -C "$dir" "$@"
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
    local e top=12 run="" port=""
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
        port="$(flash_port "$port")" || exit 1
        device_preflight "$port" || exit $?
        local cport; cport="$(console_port "" "$port")" || exit 1
        echo
        echo "x: flashing + capturing runtime high-water mark (look for 'stack:' lines)..." >&2
        ( cd "$EXROOT/$e" && bash flash.sh "$port" ) >/dev/null 2>&1 || die "flash failed"
        #  Pure-bash capture: let the USB-serial-JTAG re-enumerate after the reset,
        #  read the console raw for ~20 s, then surface any "stack:" report lines.
        local cap; cap="$(mktemp)"
        sleep 2
        stty -F "$cport" "$BAUD" raw -echo 2>/dev/null || true
        timeout 20 cat "$cport" > "$cap" 2>/dev/null || true
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

# -- test ---------------------------------------------------------------------
# Everything that can be checked without a board, in one command.  There are
# three kinds and they are all cheap; before this existed each lived only in its
# own run.sh and nothing ran the set, which is how a broken example and a HAL
# that would not build under its own default profile both survived in the tree.
#
#   ./x test            host suites + all three HAL profiles + every example
#   ./x test host       just the native host suites (seconds; no cross compiler)
#   ./x test lib        just the HAL/library builds, all three runtime profiles
#   ./x test examples   just the examples
#
# Warnings are failures for the libraries: the HAL builds clean under -gnatwa
# (see its .gpr), and that only stays true if something enforces it.  The
# machine-generated register layer in svd/ is exempt -- it is not hand-written
# and is already exempt from -gnatw.v for the same reason.
#  Static analysis with adalang_analyzer (an Alire crate: a Libadalang-based
#  analyzer).  Deliberately NOT part of `./x test`: the tool is not in the
#  toolchain this repo pins, so a plain clone would fail a check it cannot run.
#
#  Every finding present when a baseline was written is filtered out, so this
#  reports only what is NEW.  The committed baselines are not an assertion that
#  the code is clean -- the 2026-09 triage found the recommended rule set is
#  dominated by false positives here (Asm output operands read as uninitialized,
#  `return`/`raise` after a Free read as use-after-free, defensive out-parameter
#  initialisation read as a dead store).  They are a "no new findings" tripwire.
#  Checks the --recommended preset does not enable, added to the default gate.
#
#  They came from the automotive profile, which used to be a mode of its own.
#  It is not worth one: of its twelve checks only TWO overlapped --style, and
#  the other ten are what is listed here -- correctness rules, not conformance
#  ones, so they belong in the default gate rather than behind a flag nobody
#  remembers to pass.  (`--recommended` and `-checks=` compose, so this is
#  additive.)
#
#  The first six normally find nothing at all, which is the point: they are the
#  copy-paste and logic-error detectors, they cost no baseline entries while
#  they stay empty, and a new one appearing is a real signal.
#
#  Exception_Propagation is deliberately NOT here.  It looks like a correctness
#  rule and reports only 12 findings under the full --automotive profile, but
#  enabled on its own it reports 1274 in the HAL alone: it fires on every call
#  that can transitively raise, which in a stack that signals errors WITH
#  exceptions (ext4 raises No_Space / Corrupt / Use_Error by design) is very
#  nearly every call.  It is a restriction, not a defect detector.
ANALYZE_EXTRA_CHECKS="\
Constant_Condition,Overlapping_Case_Ranges,Duplicate_Boolean_Operand,\
Unreachable_Case_Alternative,Floating_Equality,Non_Short_Circuit_Condition,\
Global_Contract_Mismatch,Volatile_Atomic_Consistency,\
Library_Level_Initialization,Missing_Loop_Variant"


#  Style, comprehensibility and complexity: the "is this code readable" view,
#  as opposed to "is it correct" (the default gate).  Chosen by MEASURING all
#  126 checks rather than by name -- four plausible-sounding rules were dropped
#  once their findings were read:
#
#    Naming_Convention  1868 findings, and every one of them is the SAME
#                       objection -- "one-character identifier used" (R, V, I,
#                       K).  One house-style disagreement repeated, not 1868
#                       insights.
#    Magic_Number       2940 in hand-written source, spread over 185 files.
#                       Register and protocol constants are this codebase's
#                       idiom; the count grows with every driver written.
#    No_Multiple_Return 180.  Single-exit dogma; an early return is usually the
#                       clearer construct, not the worse one.
#    Long_Line          Hand-written source is already inside it -- p99 is 90
#                       columns and NOTHING exceeds 120 -- so every finding
#                       would come from generated svd/.  Formatting is
#                       gnatformat's job anyway.
#
#  25 of the 34 below currently find nothing at all.  That is the good part:
#  they cost no baseline entries while they stay quiet, and each one is a
#  distinct way for code to become harder to follow.
ANALYZE_STYLE_CHECKS="\
Cyclomatic_Complexity,Deep_Nesting,Too_Many_Parameters,Generic_Instantiation_Limit,\
Dependency_Limit,Circular_Package_Dependency,Duplicate_Subprogram,Repeated_Statement,\
Shadowed_Declaration,Unnecessary_Else_After_Return,Null_Statement,\
Redundant_If_Boolean_Return,Redundant_Boolean_Comparison,Redundant_Final_Return,\
Redundant_Abs,Redundant_Unary_Minus,Redundant_Type_Conversion,Ineffective_Operation,\
Constant_Result_Operation,Duplicate_With_Clause,Duplicate_Exception_Choice,\
Duplicate_Condition,Same_Operand,Identical_Case_Alternative,Identical_Branches,\
Unreachable_Code,Unused_Variable,Missing_Overriding_Indicator,\
Reraise_Discards_Occurrence,Inefficient_String_Concatenation,Empty_If_Body,\
Empty_Else_Body,No_Goto,No_Label"

#  Analysis of an application's own code -- an example, a standalone project,
#  or some files of either (or of a library) -- for the command line and
#  Turbo Ada's Analyze file / Analyze project.  The gate's checks (--style:
#  its style set), the project for name resolution, and no baseline: every
#  finding is shown, compiler-style (file:line:col: warning: ... [Check])
#  with the analyzer's rule, advice and source lines under it.
need_analyzer () {
    command -v adalang_analyzer > /dev/null 2>&1 && return 0
    #  alr install's home, when it is not on PATH (an IDE started from a menu).
    [ -x "$HOME/.alire/bin/adalang_analyzer" ] && { PATH="$HOME/.alire/bin:$PATH"; return 0; }
    cat >&2 <<'MSG'
analyze: adalang_analyzer is not installed.

  It is an Alire crate (https://github.com/mmartign/AdaLang_Analyzer), not
  part of the pinned toolchain.  './x setup-analyzer' installs it (it builds
  Libadalang, so it takes a while), or by hand:

      alr install adalang_analyzer          # installs into ~/.alire/bin
      export PATH="$HOME/.alire/bin:$PATH"
MSG
    return 127
}
gpr_of_dir () {   # $1 = dir: its project file, or nothing
    #  The one rule (Turbo Ada's too): alire.toml's first project-files entry,
    #  else <crate name>.gpr; else app.gpr; else the first *.gpr in name
    #  order that is not a *_prove.gpr.
    local g best="" m
    if [ -f "$1/alire.toml" ]; then
        m="$(sed -n 's/^[[:space:]]*project-files[[:space:]]*=[[:space:]]*\[[[:space:]]*"\([^"]*\)".*/\1/p' \
             "$1/alire.toml" | head -1)"
        [ -n "$m" ] || m="$(sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
             "$1/alire.toml" | head -1).gpr"
        [ -f "$1/$m" ] && { echo "$1/$m"; return 0; }
    fi
    for g in "$1"/*.gpr; do
        [ -f "$g" ] || continue
        case "$g" in *_prove.gpr) continue ;; esac
        if [ -z "$best" ] || [ "$(basename "$g")" = app.gpr ]; then best="$g"; fi
    done
    [ -n "$best" ] && echo "$best"
}
gpr_given () {   # $1 = --gpr FILE (relative to $2, a dir, when not absolute): it, checked
    local g="$1"
    case "$g" in /*) ;; *) g="$2/$g" ;; esac
    [ -f "$g" ] || die "no such project file: $1"
    echo "$(cd "$(dirname "$g")" && pwd -P)/$(basename "$g")"
}
gpr_above () {   # $1 = a source file: the nearest project file in its dir or above
    local d; d="$(cd "$(dirname "$1")" && pwd -P)" || return 1
    while :; do
        gpr_of_dir "$d" && return 0
        [ "$d" = / ] && return 1
        d="$(dirname "$d")"
    done
}
gpr_profile () {   # $1 = project file: the runtime profile to resolve it under
    local dir; dir="$(dirname "$1")"
    case "$(cd "$dir" && pwd -P)/" in
        "$(cd "$ROOT/libs" && pwd -P)"/*)
            #  A library: its widest profile, as the gate uses.
            profiles_of_lib "$1" | tr ' ' '\n' | grep -vx light-tasking | head -1 ;;
        *)  #  An application: the profile its build.sh builds with.
            local p; p="$(grep -hoE 'ESP32S3_RTS_PROFILE=[a-z-]+' "$dir/build.sh" 2>/dev/null \
                          | head -1 | cut -d= -f2 || true)"
            echo "${p:-light-tasking}" ;;
    esac
}
analyze_app () {   # $1 = project file, $2 = 1 for --style, rest = files (none: all its sources)
    local gpr="$1" style="$2" prof checks f rc
    shift 2
    need_analyzer || return
    prof="$(gpr_profile "$gpr")"
    if [ "$style" = 1 ]; then checks="-checks=$ANALYZE_STYLE_CHECKS"
    else checks="--recommended -checks=$ANALYZE_EXTRA_CHECKS"; fi
    if [ $# -gt 0 ]; then
        echo "== static analysis ($([ "$style" = 1 ] && echo style || echo defects)) of $(for f in "$@"; do printf '%s ' "$(basename "$f")"; done)[$(basename "$gpr"), $prof] =="
    else
        echo "== static analysis ($([ "$style" = 1 ] && echo style || echo defects)) of $(basename "$(dirname "$gpr")") [$(basename "$gpr"), $prof] =="
    fi
    #  GPR_PROJECT_PATH, for the SDK libraries a project withs.
    . "$ROOT/export.sh" > /dev/null 2>&1
    local out kept n dropped; out="$(mktemp)"
    ( cd "$(dirname "$gpr")" && adalang_analyzer -P"$gpr" -XESP32S3_RTS_PROFILE="$prof" \
          $checks "$@" ) > "$out" 2>&1 && rc=0 || rc=$?
    #  1: findings (the report says which); anything else: it failed.
    if [ "$rc" -gt 1 ]; then
        cat "$out"; rm -f "$out"
        echo "analyze: adalang_analyzer failed (status $rc)" >&2
        return "$rc"
    fi
    #  Each finding is a line "/abs/f.adb:L:C: warning: ..." with indented
    #  lines under it.  Files given: the analyzer may report on the whole
    #  project whatever files it is given, so keep only theirs.  Always: a
    #  "with X;" that the file marks "pragma Unreferenced (X);" is there for
    #  X's elaboration (a library-level task, say), which the analyzer's
    #  Unused_With_Clause does not know -- drop that finding, and say so.
    kept="$( { [ $# -gt 0 ] && printf '%s\n' "$@" || true; } | awk -v all=$(( $# == 0 )) '
        function kept_for_elaboration(file, line,   l, k, unit, src, i) {
            k = 0
            while ((getline l < file) > 0) src[++k] = l
            close(file)
            unit = src[line]
            if (!sub(/^[ \t]*with[ \t]+/, "", unit)) return 0
            sub(/[ \t;,].*/, "", unit)
            for (i = 1; i <= k; i++)
                if (tolower(src[i]) ~ ("pragma[ \t]+unreferenced[ \t]*\\([ \t]*" tolower(unit) "[ \t]*\\)"))
                    return 1
            return 0
        }
        FILENAME == "-" { want[$0] = 1; next }
        /^\// {
            f = $0; sub(/:[0-9]+:[0-9]+:.*/, "", f)
            keep = all || (f in want)
            if (keep && $0 ~ /\[Unused_With_Clause\]/) {
                l = $0; sub(/^[^:]*:/, "", l); sub(/:.*/, "", l)
                if (kept_for_elaboration(f, l + 0)) { keep = 0; dropped++ }
            }
        }
        /^\// || /^  / { if (keep) print; next }
        { keep = 0; if (all) print }
        END { if (dropped) print "(" dropped " Unused_With_Clause finding(s) left out: a with kept for elaboration, marked pragma Unreferenced)" }
        ' - "$out")"
    rm -f "$out"
    n="$(printf '%s\n' "$kept" | grep -c '^/' || true)"
    [ -n "$kept" ] && printf '%s\n\n' "$kept"
    echo "$n finding$([ "$n" = 1 ] || echo s)"
    #  An IDE (--machine) reads the findings as warnings: they are what it
    #  asked for, not a failure.
    [ "$n" = 0 ] || [ "${X_MACHINE:-}" = 1 ]
}
analyze_files () {   # $1 = 1 for --style, $2 = the project file ("": found), rest = source files
    local style="$1" given="$2" f gpr="" g abs=()
    shift 2
    for f in "$@"; do
        [ -f "$f" ] || die "analyze: no such file: $f"
        abs+=("$(cd "$(dirname "$f")" && pwd -P)/$(basename "$f")")
        [ -z "$given" ] || continue
        g="$(gpr_above "$f")" || die "analyze: no project file (.gpr) above $f"
        [ -z "$gpr" ] || [ "$gpr" = "$g" ] || die "analyze: $f is in another project ($g)"
        gpr="$g"
    done
    [ -z "$given" ] || gpr="$given"
    analyze_app "$gpr" "$style" "${abs[@]}"
}

#  SPARK proof.  The SDK proves its SPARK units against NATIVE projects (the
#  host suites' and the *_prove.gpr ones), which list the sources they cover;
#  book/prove/prove.sh runs the whole pass.
proof_project_of () {   # $1 = a source file: the native project that lists it, or nothing
    local b g; b="$(basename "$1")"
    for g in "$ROOT"/libs/*/*_prove.gpr "$ROOT"/libs/*/test/*/*.gpr; do
        [ -f "$g" ] || continue
        grep -q "\"$b\"" "$g" && { echo "$g"; return 0; }
    done
    return 1
}
cmd_prove () {   # [FILE...]: the SDK's whole proof pass, or those files with their proof projects
    command -v gnatprove >/dev/null 2>&1 || [ -x "$HOME/.alire/bin/gnatprove" ] || {
        echo "x prove: gnatprove is not installed (alr install gnatprove)" >&2; return 127; }
    export PATH="$HOME/.alire/bin:$PATH"
    if [ $# -eq 0 ]; then
        bash "$ROOT/book/prove/prove.sh"; return
    fi
    local f g rc=0
    for f in "$@"; do
        [ -f "$f" ] || die "prove: no such file: $f"
        g="$(proof_project_of "$f")" || {
            echo "prove: no proof project lists $(basename "$f") -- it is not in the SDK's proof pass" >&2
            rc=1; continue; }
        echo "== prove $(basename "$f") [$(basename "$g")] =="
        #  Full paths in its messages, so they lead back to the file.
        ( cd "$(dirname "$g")" && gnatprove -P "$g" --level=1 --prover=z3 --timeout=10 -j0 \
              --output=oneline --report=fail -u "$(basename "$f")" -cargs -gnatef ) || rc=$?
    done
    return "$rc"
}

cmd_analyze () {
    local update=0 only="" style=0 do178="" a files=() given=""
    while [ $# -gt 0 ]; do
        a="$1"; shift
        case "$a" in
            --gpr)                      given="$(gpr_given "${1:-}" "$PWD")"; shift ;;
            --gpr=*)                    given="$(gpr_given "${a#--gpr=}" "$PWD")" ;;
            --update-baseline|--update) update=1 ;;
            --style)                    style=1 ;;
            --do178c)                   do178=A ;;
            --do178c=[ABCD])            do178="${a#--do178c=}" ;;
            --do178c=*) echo "x analyze: --do178c level must be A, B, C or D" >&2; return 2 ;;
            -*) echo "x analyze: unknown option: $a" >&2; return 2 ;;
            *.adb|*.ads|*.ada) files+=("$a") ;;
            *)  only="$a" ;;
        esac
    done

    #  Source files, or an example: its own code, every finding (no baseline).
    local lib_gpr=""
    [ -n "$only" ] && lib_gpr="$(ls "$ROOT"/libs/*/"$only".gpr 2>/dev/null | head -1 || true)"
    if [ ${#files[@]} -gt 0 ] || { [ -n "$only" ] && [ -z "$lib_gpr" ] \
            && { [ -d "$EXROOT/$only" ] || [ -d "$EXROOT/esp32s3_$only" ]; }; }; then
        if [ "$update" = 1 ] || [ -n "$do178" ]; then
            echo "x analyze: --update-baseline and --do178c are for the libraries" >&2; return 2
        fi
        if [ ${#files[@]} -gt 0 ]; then
            [ -z "$only" ] || { echo "x analyze: files or an example, not both" >&2; return 2; }
            analyze_files "$style" "$given" "${files[@]}"
        else
            local e g; e="$(resolve "$only")"
            g="$given"
            [ -n "$g" ] || g="$(gpr_of_dir "$EXROOT/$e")" || die "no .gpr in $EXROOT/$e"
            analyze_app "$g" "$style"
        fi
        return
    fi

    #  Which rule set, and which baseline it is measured against.  The two modes
    #  keep SEPARATE baselines: they enable different checks, so one set of
    #  fingerprints cannot stand in for the other.
    local checks suffix label
    if [ "$style" = 1 ]; then
        checks="-checks=$ANALYZE_STYLE_CHECKS"
        suffix=".style"
        label="style / comprehensibility / complexity"
    else
        checks="--recommended -checks=$ANALYZE_EXTRA_CHECKS"
        suffix=""
        label="defects"
    fi

    if ! command -v adalang_analyzer > /dev/null 2>&1; then
        cat >&2 <<'MSG'
x analyze: adalang_analyzer is not on PATH.

  It is an Alire community crate, not part of the pinned toolchain:

      alr install adalang_analyzer          # installs into ~/.alire/bin
      export PATH="$HOME/.alire/bin:$PATH"
MSG
        return 127
    fi

    #  export.sh, not sdk-env.sh: loading a project that imports another BY NAME
    #  needs GPR_PROJECT_PATH, and resolving the cross compiler needs the xtensa
    #  toolchain on PATH -- the same reasons build_lib_clean sources it.
    . "$ROOT/export.sh" > /dev/null 2>&1

    #  DO-178C is a REPORT mode, not a gate, and the numbers are why.  Of the
    #  9551 findings its Level A profile reports here, 8756 are per-subprogram
    #  process obligations -- Missing_Requirement_Trace (1866, "no low-level
    #  requirement trace") and Complete_Initialization (5474) dominate -- which
    #  grow with every subprogram written.  A baseline over that would need
    #  rewriting constantly and would signal nothing.  Only 120 of the 9551 are
    #  additive as code quality (Cyclomatic_Complexity, Deep_Nesting), and those
    #  are in the --automotive tripwire above, where they are stable.
    #
    #  What IS worth having is the artefact: a per-objective evidence report that
    #  is honest about its own scope ("verification support only; not a
    #  compliance determination") and names the objectives it cannot speak to at
    #  all -- structural coverage, requirements-based testing, object-code
    #  verification, DO-330 tool qualification.
    if [ -n "$do178" ]; then
        if [ "$style" = 1 ] || [ "$update" = 1 ]; then
            echo "x analyze: --do178c takes no other mode flag and no --update-baseline" >&2
            return 2
        fi
        local out_dir="$ROOT/build/do178c"
        mkdir -p "$out_dir"
        echo "== DO-178C Level $do178 evidence reports (verification support, NOT a compliance determination) =="
        local gpr name prof ran=0
        for gpr in "$ROOT"/libs/*/[a-z]*.gpr; do
            [ -f "$gpr" ] || continue
            case "$(basename "$gpr")" in *_prove.gpr) continue ;; esac
            name="$(basename "${gpr%.gpr}")"
            [ -z "$only" ] || [ "$only" = "$name" ] || continue
            ran=$((ran + 1))
            prof="$(profiles_of_lib "$gpr" | tr ' ' '\n' | grep -vx light-tasking | head -1)"
            adalang_analyzer -P"$gpr" -XESP32S3_RTS_PROFILE="$prof" \
                --do178c="$do178" --compliance-report=do178c \
                --compliance-report-format=markdown \
                --compliance-report-output="$out_dir/$name.md" \
                > /dev/null 2>&1 || true
            if [ -s "$out_dir/$name.md" ]; then
                printf '  \033[32mok\033[0m    %-14s [%s]  -> build/do178c/%s.md\n' \
                       "$name" "$prof" "$name"
                #  The objective table is the point; show its open-finding column.
                sed -n '/^| Objective /,/^$/p' "$out_dir/$name.md" \
                    | awk -F'|' 'NR>2 && NF>3 {gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$5);
                                               printf "          %-26s open findings: %s\n", $2, $5}'
            else
                printf '  \033[31mFAIL\033[0m  %-14s [%s]  no report written\n' "$name" "$prof"
            fi
        done
        if [ "$ran" = 0 ]; then
            echo "x analyze: no such library: $only" >&2; return 2
        fi
        echo
        echo "Reports in build/do178c/ (gitignored).  They are evidence INPUT, not a"
        echo "pass/fail: read the scope caveat at the top of each one."
        return 0
    fi

    local base_dir="$ROOT/tools/analyzer-baselines"
    mkdir -p "$base_dir"

    local failures=0 ran=0 gpr name prof base rc
    local log; log="$(mktemp -d)"; trap 'rm -rf "$log"' RETURN

    if [ "$update" = 1 ]; then
        echo "== static analysis, $label (rewriting baselines) =="
    else
        echo "== static analysis, $label (findings not already in tools/analyzer-baselines/) =="
    fi

    for gpr in "$ROOT"/libs/*/[a-z]*.gpr; do
        [ -f "$gpr" ] || continue
        case "$(basename "$gpr")" in *_prove.gpr) continue ;; esac
        name="$(basename "${gpr%.gpr}")"
        [ -z "$only" ] || [ "$only" = "$name" ] || continue
        ran=$((ran + 1))

        #  The WIDEST profile the library supports: esp32s3_hal scopes
        #  Source_Dirs to ("src","svd") under light-tasking, so analysing that
        #  profile would silently cover 102 of its 329 files.
        prof="$(profiles_of_lib "$gpr" | tr ' ' '\n' | grep -vx light-tasking | head -1)"
        base="$base_dir/$name$suffix.baseline"

        if [ "$update" = 1 ]; then
            adalang_analyzer -P"$gpr" -XESP32S3_RTS_PROFILE="$prof" \
                $checks --write-baseline="$base" > "$log/out" 2>&1 || true
            printf '  \033[32mok\033[0m    %-14s [%s]  baseline: %s finding(s)\n' \
                   "$name" "$prof" "$({ grep -cv '^#' "$base" 2>/dev/null || true; })"
            continue
        fi

        if [ -f "$base" ]; then
            adalang_analyzer -P"$gpr" -XESP32S3_RTS_PROFILE="$prof" \
                $checks --baseline="$base" > "$log/out" 2>&1 && rc=0 || rc=$?
        else
            echo "  ..    $name: no baseline yet; run './x analyze $name$([ "$style" = 1 ] && echo ' --style') --update-baseline'"
            adalang_analyzer -P"$gpr" -XESP32S3_RTS_PROFILE="$prof" \
                $checks > "$log/out" 2>&1 && rc=0 || rc=$?
        fi

        if [ "$rc" = 0 ]; then
            printf '  \033[32mok\033[0m    %-14s [%s]  %s\n' "$name" "$prof" \
                   "$(grep -m1 'Baseline matches:' "$log/out" || echo 'no findings')"
        else
            printf '  \033[31mNEW\033[0m   %-14s [%s]\n' "$name" "$prof"
            #  Show the findings themselves, not the trailing summary block.
            grep -E '^/.*: (warning|error):' "$log/out" \
                | sed 's|^'"$ROOT"/'||;s|^|        |' | head -40 || true
            failures=$((failures + 1))
        fi
    done

    if [ "$ran" = 0 ]; then
        echo "x analyze: no such library: $only" >&2; return 2
    fi
    echo
    if [ "$failures" = 0 ]; then
        printf '\033[32mPASS\033[0m  %s librar%s, no new findings\n' \
               "$ran" "$([ "$ran" = 1 ] && echo y || echo ies)"
    else
        printf '\033[31mFAIL\033[0m  %s of %s librar%s %s new findings\n' \
               "$failures" "$ran" "$([ "$ran" = 1 ] && echo y || echo ies)" \
               "$([ "$failures" = 1 ] && echo has || echo have)"
        echo "      Triage them; if they are noise, re-baseline with --update-baseline."
    fi
    return "$failures"
}

cmd_test () {
    local what="${1:-all}"
    local failures=0 ran=0
    local log; log="$(mktemp -d)"; trap 'rm -rf "$log"' RETURN

    run_one () {   # $1 = label, rest = command
        local label="$1"; shift
        ran=$((ran + 1))
        if "$@" > "$log/out" 2>&1; then
            printf '  \033[32mok\033[0m    %s\n' "$label"
        else
            printf '  \033[31mFAIL\033[0m  %s\n' "$label"
            sed 's/^/        /' "$log/out" | tail -20
            failures=$((failures + 1))
        fi
    }

    #  Host suites: every libs/*/test/*/run.sh, Turbo Ada's, plus the bare-boot
    #  heap test.  `./x test host SUITE` runs just that one.
    local only=""
    [ "$what" = host ] && only="${2:-}"
    if [ "$what" = all ] || [ "$what" = host ]; then
        echo "== host test suites =="
        local r
        for r in $(find "$ROOT/libs" "$ROOT/ide/turbo-ada" -path '*/test/*/run.sh' | sort) \
                 "$ROOT/examples/common/bare/boot/test/run.sh"; do
            [ -f "$r" ] || continue
            if [ -n "$only" ] && [ "$(basename "$(dirname "$r")")" != "${only##*/}" ]; then
                continue
            fi
            run_one "$(echo "${r#$ROOT/}" | sed 's|/run.sh$||')" bash "$r"
        done
    fi

    #  Library builds, warnings fatal, on every profile the library supports.
    if [ "$what" = all ] || [ "$what" = lib ]; then
        echo "== libraries (every supported runtime profile; warnings are failures) =="
        local prof gpr
        for gpr in "$ROOT"/libs/*/[a-z]*.gpr; do
            [ -f "$gpr" ] || continue
            case "$(basename "$gpr")" in *_prove.gpr) continue ;; esac
            for prof in $(profiles_of_lib "$gpr"); do
                run_one "$(basename "${gpr%.gpr}")  [$prof]" \
                        build_lib_clean "$gpr" "$prof"
            done
        done
    fi

    if [ "$what" = all ] || [ "$what" = examples ]; then
        #  The Wi-Fi examples with a network in them read wifi_credentials.ads,
        #  which is deliberately gitignored so a real SSID and PSK can never be
        #  committed.  That means it does not exist on a fresh clone or in CI,
        #  and five examples cannot COMPILE without it.  Seed the placeholders
        #  from the committed .template: this slice builds, it does not
        #  associate, and the template exists to be copied.  A file already
        #  there -- yours, with a real network in it -- is never touched.
        local tmpl
        for tmpl in "$EXROOT"/*/src/wifi_credentials.ads.template; do
            [ -e "$tmpl" ] || continue
            if [ ! -e "${tmpl%.template}" ]; then
                cp "$tmpl" "${tmpl%.template}"
                echo "  ..    seeded $(basename "$(dirname "$(dirname "$tmpl")")")/src/wifi_credentials.ads from its template"
            fi
        done
        echo "== examples =="
        local e
        for e in $(list_dirs); do
            run_one "$(short "$e")" bash "$ROOT/x" build "$(short "$e")"
        done
    fi

    echo
    if [ "$failures" -eq 0 ]; then
        printf '\033[32mPASS\033[0m  %d checks\n' "$ran"
    else
        printf '\033[31mFAIL\033[0m  %d of %d checks\n' "$failures" "$ran"
        return 1
    fi
}

# Which runtime profiles a library supports, read from the library itself: its
# .gpr declares the LOWEST profile it works on as the default of
# external ("ESP32S3_RTS_PROFILE", ...), and the profiles are ordered
# light-tasking < embedded < full by capability, so a library is testable on its
# default and everything above it.  A .gpr that names no profile is treated as
# embedded -- it inherits whatever its consumer picks, and a library with no
# opinion is not a light-tasking library.  Adding a library needs no edit here.
profiles_of_lib () {
    local dflt
    dflt="$(sed -nE 's/.*external *\( *"ESP32S3_RTS_PROFILE" *, *"([a-z-]+)".*/\1/p' "$1" \
            | head -1)"
    case "${dflt:-embedded}" in
        light-tasking) echo "light-tasking embedded full" ;;
        embedded)      echo "embedded full" ;;
        full)          echo "full" ;;
        *)             echo "embedded" ;;
    esac
}

# Build one library project under one profile and fail on ANY warning.
# gprbuild's exit status ignores warnings, so the output is searched instead;
# svd/ is excluded (machine-generated, see cmd_test's header).
build_lib_clean () {
    local gpr="$1" prof="$2" out
    #  export.sh, not just sdk-env.sh: a library may import another BY NAME
    #  (esp32s3_wifi.gpr does), which needs GPR_PROJECT_PATH, and every xtensa
    #  compile needs XTENSA_GNU_CONFIG.
    . "$ROOT/export.sh" > /dev/null 2>&1
    [ -n "${XTENSA_GNU_CONFIG:-}" ] || { echo "no xtensa-dynconfig"; return 1; }
    #  The runtime for this profile is GENERATED, not committed (from
    #  crates/esp32s3_rts/packs/*.tar.zst).  An example build gets there via
    #  build_ada.sh; a library build has no such path, so on a fresh clone every
    #  library failed with "invalid runtime directory ...-esp32s3" before this.
    #  gen_runtime.sh is idempotent -- it regenerates only when the output is
    #  missing -- so this costs nothing on a warm tree.
    out="$(ESP32S3_RTS_PROFILE="$prof" bash "$ROOT/crates/esp32s3_rts/gen_runtime.sh" 2>&1)" || {
        printf '%s\n' "$out"; return 1; }
    out="$(ESP32S3_RTS_PROFILE="$prof" gprbuild -p -q -P "$gpr" -j"$(nproc)" 2>&1)" || {
        printf '%s\n' "$out"; return 1; }
    local warned
    warned="$(printf '%s\n' "$out" | grep 'warning:' | grep -v '^esp32s3_registers' || true)"
    [ -z "$warned" ] || { printf '%s\n' "$warned"; return 1; }
}

# -- machine-readable output (--machine) --------------------------------------
#  `./x --machine <verb> ...` (and `esp32-ada --machine <verb> ...`) prints the
#  verb's usual output with these lines added or rewritten, so an IDE can read
#  a build instead of guessing from free text.  Each starts with "@x " so it
#  cannot be mistaken for tool output; everything else passes through as is.
#
#    @x protocol 1                the first line (the format's version)
#    @x stage N/M TEXT            a build stage began        (was "[bare] N/M TEXT")
#    @x diag SEV FILE:L:C: TEXT   a compiler diagnostic      (was "file:l:c: TEXT")
#                                 SEV is error|warning|style|info; FILE is absolute
#    @x artifact KIND PATH        something the verb made    (elf, bin)
#    @x result ok|fail STATUS     the last line; STATUS is the verb's exit status
#
#  Interactive verbs (run, monitor, debug) ignore --machine.
MACHINE=""
MACHINE_DIRS=""   # where a diagnostic's file name is looked for, in order

machine_resolve () {   # $1 = a file name as a tool printed it -> absolute path
    local f="$1" d hit
    case "$f" in /*) [ -e "$f" ] && { printf '%s' "$f"; return; } ;; esac
    for d in $MACHINE_DIRS; do
        if [ -e "$d/$f" ]; then
            printf '%s/%s' "$(cd "$(dirname "$d/$f")" && pwd)" "$(basename "$f")"; return
        fi
    done
    #  gprbuild prints a source by its simple name; find it under the dirs.
    for d in $MACHINE_DIRS; do
        hit="$(find "$d" -name "$(basename "$f")" -not -path '*/obj*' \
                    -not -path '*/.noidf/*' -print -quit 2>/dev/null)"
        [ -n "$hit" ] && { printf '%s' "$hit"; return; }
    done
    printf '%s' "$f"
}

machine_filter () {
    local line sev text
    local diag='^([^ :]+\.(adb|ads|ada|gpr|c|h|S|s|ld)):([0-9]+):(([0-9]+):)? ?(.*)$'
    local stage='^\[bare\] ([0-9]+/[0-9]+) +(.*)$'
    while IFS= read -r line; do
        if [[ "$line" =~ $stage ]]; then
            printf '@x stage %s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        elif [[ "$line" =~ $diag ]]; then
            text="${BASH_REMATCH[6]}"
            case "$text" in
                error:*|"fatal error:"*) sev=error ;;
                warning:*)               sev=warning ;;
                "(style)"*)              sev=style ;;
                info:*|note:*)           sev=info ;;
                *)                       sev=error ;;   # GNAT < 13: no "error:"
            esac
            printf '@x diag %s %s:%s:%s: %s\n' "$sev" \
                "$(machine_resolve "${BASH_REMATCH[1]}")" "${BASH_REMATCH[3]}" \
                "${BASH_REMATCH[5]:-1}" "$text"
        else
            printf '%s\n' "$line"
        fi
    done
}

machine_run () {   # $1 = dir holding the artifacts ("" = none); rest = the command
    local art="$1" rc
    shift
    echo "@x protocol 1"
    set +e
    ( set -e; export X_MACHINE=1; "$@" ) 2>&1 | machine_filter
    rc=${PIPESTATUS[0]}
    set -e
    if [ "$rc" = 0 ] && [ -n "$art" ]; then
        [ -f "$art/app.elf" ] && echo "@x artifact elf $art/app.elf"
        [ -f "$art/app.bin" ] && echo "@x artifact bin $art/app.bin"
    fi
    echo "@x result $([ "$rc" = 0 ] && echo ok || echo fail) $rc"
    return "$rc"
}

# -- the environment of one application's compile (env) -----------------------
#  What gprbuild, gnatls or the Ada Language Server need to process an app's
#  project WITHOUT going through build.sh: the toolchain on PATH, the xtensa
#  core-config plugin, the runtime for the profile generated, and the runtime
#  crate and every libs/*/ on GPR_PROJECT_PATH -- the same steps bare_build.sh
#  and build_ada.sh take before their gprbuild.  Printed as KEY=VALUE lines;
#  progress goes to stderr.
app_env () {   # $1 = project dir, $2 = profile (auto = the project's build.sh), $3 = its .gpr ("": found)
    local dir="$1" prof="$2" gpr="${3:-}" l
    if [ "$prof" = auto ] || [ -z "$prof" ]; then
        prof="$(grep -hoE 'ESP32S3_RTS_PROFILE=[a-z-]+' "$dir/build.sh" 2>/dev/null \
                | head -1 | cut -d= -f2 || true)"
        prof="${prof:-light-tasking}"
    fi
    [ -n "$gpr" ] || gpr="$(gpr_of_dir "$dir")" || die "no .gpr in $dir"
    (
        export ESP32S3_RTS_PROFILE="$prof"
        . "$ROOT/tools/sdk-env.sh"
        esp32s3_toolchain_on_path >&2
        esp32s3_export_dynconfig "$ROOT" >&2 || die "could not build the xtensa-dynconfig plugin"
        for l in "$ROOT"/libs/*/; do
            [ -d "$l" ] && GPR_PROJECT_PATH="${l%/}${GPR_PROJECT_PATH:+:$GPR_PROJECT_PATH}"
        done
        GPR_PROJECT_PATH="$ROOT/crates/esp32s3_rts:$GPR_PROJECT_PATH"
        bash "$ROOT/crates/esp32s3_rts/gen_runtime.sh" >&2
        printf 'PATH=%s\n' "$PATH"
        printf 'GPR_PROJECT_PATH=%s\n' "$GPR_PROJECT_PATH"
        printf 'XTENSA_GNU_CONFIG=%s\n' "$XTENSA_GNU_CONFIG"
        printf 'ESP32S3_RTS_PROFILE=%s\n' "$prof"
        printf 'TARGET=esp32s3\n'
        printf 'GPR_FILE=%s\n' "$gpr"
        printf 'PROJECT_DIR=%s\n' "$dir"
    )
}
suite_env () {   # $1 = suite dir, $2 = its .gpr ("": found): the native toolchain first, the project
    local dir="$1" gpr="${2:-}"
    [ -n "$gpr" ] || gpr="$(gpr_of_dir "$dir")" || die "no .gpr in $dir"
    (
        . "$ROOT/tools/sdk-env.sh"
        esp32s3_toolchain_on_path >&2
        printf 'PATH=%s\n' "$ESP32S3_GNAT_NATIVE_BIN:$ESP32S3_GPRBUILD_BIN:$PATH"
        printf 'TARGET=native\n'
        printf 'GPR_FILE=%s\n' "$gpr"
        printf 'PROJECT_DIR=%s\n' "$dir"
    )
}
cmd_env () {   # <example|SUITE> [-P PROF] [--gpr FILE]
    local name="${1:-}" s e prof="auto" gpr="" dir; shift || true
    while [ $# -gt 0 ]; do
        case "$1" in
            -P|--profile) prof="$2"; shift 2 ;;
            --gpr)        gpr="$2"; shift 2 ;;
            --gpr=*)      gpr="${1#--gpr=}"; shift ;;
            *) shift ;;
        esac
    done
    s="$(resolve_suite "$name")"
    if [ -n "$s" ] && [ ! -d "$EXROOT/$name" ] && [ ! -d "$EXROOT/esp32s3_$name" ]; then
        [ -z "$gpr" ] || gpr="$(gpr_given "$gpr" "$s")"
        suite_env "$s" "$gpr"; return
    fi
    e="$(resolve "$name")"; dir="$EXROOT/$e"
    [ -z "$gpr" ] || gpr="$(gpr_given "$gpr" "$dir")"
    valid_profile "$prof"
    app_env "$dir" "$prof" "$gpr"
}

# -- dispatch -----------------------------------------------------------------
# Skipped when this file is SOURCED (not executed) -- the standalone-project
# launcher `tools/bin/esp32-ada` sources x to reuse its helpers (monitor_tool,
# serial_from_port, find_gdb, cmd_config, ...) without re-running the dispatch.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if [ "${1:-}" = "--machine" ]; then MACHINE=1; shift; fi
  cmd="${1:-}"; shift || true
  if [ -n "$MACHINE" ]; then
      #  The example (when the verb takes one) is where diagnostics and
      #  artifacts are looked for; then the libraries and the shared boot.
      ex_dir=""
      case "$cmd" in
          build|flash|clean|stack|mem|memory|config|cfg)
              [ -n "${1:-}" ] && ex_dir="$( (resolve "$1") 2>/dev/null || true)"
              [ -n "$ex_dir" ] && ex_dir="$EXROOT/$ex_dir" ;;
      esac
      MACHINE_DIRS="$ex_dir $ROOT/libs $EXROOT/common $ROOT/tools"
      case "$cmd" in
          build|flash)  machine_run "$ex_dir" "$0" "$cmd" "$@"; exit $? ;;
          clean|test|analyze|prove|stack|mem|memory|config|cfg|kill-openocd|setup-toolchain)
                        machine_run "" "$0" "$cmd" "$@"; exit $? ;;
      esac
  fi
  case "$cmd" in
    list)            cmd_list "$@" ;;
    new|init)        cmd_new "$@" ;;   # init is an alias of new (matches esp32-ada)
    build)           cmd_build "$@" ;;
    flash)           cmd_flash "$@" ;;
    run)             cmd_run "$@" ;;
    monitor|mon)     cmd_monitor "$@" ;;
    clean)           cmd_clean "$@" ;;
    test)            cmd_test "$@" ;;
    analyze)         cmd_analyze "$@" ;;
    prove)           cmd_prove "$@" ;;
    stack)           cmd_stack "$@" ;;
    mem|memory)      cmd_mem "$@" ;;
    config|cfg)         cmd_config "$@" ;;
    setup-toolchain)    cmd_setup_toolchain "$@" ;;
    setup-clipboard)    cmd_setup_clipboard "$@" ;;
    setup-formatter)    cmd_setup_formatter "$@" ;;
    setup-analyzer)     cmd_setup_analyzer "$@" ;;
    get-debug-tools)    cmd_get_debug_tools "$@" ;;
    get-openocd)        cmd_get_openocd "$@" ;;
    get-gdb)            cmd_get_gdb "$@" ;;
    debug)              cmd_debug "$@" ;;
    kill-openocd)       cmd_kill_openocd "$@" ;;
    setup-device)       cmd_setup_device "$@" ;;
    check-device)       cmd_check_device "$@" ;;
    ports)              cmd_ports "$@" ;;
    debug-server)       cmd_debug_server "$@" ;;
    debug-info)         cmd_debug_info "$@" ;;
    install-ide)        cmd_install_ide "$@" ;;
    build-ide)          cmd_build_ide "$@" ;;
    install-vim)        cmd_install_vim "$@" ;;
    turbo|tada)         cmd_turbo "$@" ;;
    env)                cmd_env "$@" ;;
    docs)               cmd_docs "$@" ;;
    ""|-h|--help|help)
        sed -n '3,/^set -euo/p' "$0" | sed '$d; s/^#  \{0,1\}//; s/^#//' ;;
    *) die "unknown command '$cmd' (try './x help')" ;;
  esac
fi
