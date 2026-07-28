#!/bin/bash
# Drive a stress soak over USB-JTAG: poll the on-board heartbeats/verdict
# and fail fast on a stall.  Usage: ./check.sh [seconds]  (default 600).
# Assumes the board is flashed with this example and running, and that
# OpenOCD's esp32s3-builtin config can reach it.
set -u
DUR=${1:-600}
HERE="$(cd "$(dirname "$0")" && pwd)"
ELF="$HERE/app.elf"
OCD_ROOT="${OPENOCD_ROOT:-$HOME/.espressif/tools/openocd-esp32/v0.12.0-esp32-20250422/openocd-esp32}"
NM="$(command -v xtensa-esp32s3-elf-nm || echo "$HOME/.espressif/tools/xtensa-esp-elf/esp-13.2.0_20240530/xtensa-esp-elf/bin/xtensa-esp32s3-elf-nm")"

sym () { printf 0x%s "$("$NM" "$ELF" | grep -w "$1" | awk '{print $1}')"; }
BEATS=$(sym __stress_beats); ROUND=$(sym __stress_round)
STALL=$(sym __stress_stalled); SEED=$(sym __stress_seed)

pgrep -x openocd >/dev/null || {
    setsid "$OCD_ROOT/bin/openocd" -s "$OCD_ROOT/share/openocd/scripts" \
        -c "set _ONLYCPU 0x1" -f board/esp32s3-builtin.cfg \
        >/tmp/stress_ocd.log 2>&1 &
    sleep 7
}

read_words () {  # addr count -> hex words on stdout
    (printf 'halt\n'; sleep 0.6; printf 'mdw %s %s\n' "$1" "$2"; sleep 0.8
     printf 'resume\n'; sleep 0.2) | timeout 10 nc localhost 4444 2>/dev/null |
    tr -d '\r' | grep -aoE '0x3fc[0-9a-f]+: [0-9a-f ]+' | cut -d: -f2
}

echo "seed: $(read_words "$SEED" 1 | awk '{print $1}')"
END=$((SECONDS + DUR)); LAST_ROUND=""
while [ $SECONDS -lt $END ]; do
    sleep 10
    STALLV=$(read_words "$STALL" 1 | awk '{print $1}')
    ROUNDV=$(read_words "$ROUND" 1 | awk '{print $1}')
    if [ "${STALLV:-0}" != "00000000" ] && [ -n "${STALLV:-}" ]; then
        echo "FAIL: heartbeat stalled, slot 0x$STALLV (see stress_state.ads)"
        echo "beats: $(read_words "$BEATS" 13 | tr '\n' ' ')"
        exit 1
    fi
    if [ -n "$LAST_ROUND" ] && [ "$ROUNDV" = "$LAST_ROUND" ]; then
        echo "FAIL: monitor round frozen at 0x$ROUNDV -- system-level freeze"
        exit 1
    fi
    LAST_ROUND="$ROUNDV"
    echo "t=${SECONDS}s round=0x$ROUNDV beats: $(read_words "$BEATS" 13 | tr '\n' ' ')"
done
echo "PASS: ${DUR}s, no stalls"
