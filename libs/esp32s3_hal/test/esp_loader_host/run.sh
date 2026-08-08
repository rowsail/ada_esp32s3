#!/bin/bash
#  Host test for ESP32S3.Esp_Loader (libs/esp32s3_hal/src/esp_loader).
#
#      ./run.sh
#
#  The protocol is transport-agnostic, so the very sources the firmware
#  compiles are driven here against fake_rom.py -- a simulated ESP32 ROM
#  bootloader written from the protocol description rather than from the Ada
#  source.  It sits on the other side of a pipe, watches the target's control
#  lines, and is strict about every frame it is sent: direction, length field,
#  block checksum, sequence number, block size, 0xFF padding, and whether the
#  target was actually reset into download mode before being spoken to.
#
#  No hardware.  What this canNOT prove is the real ROM's quirks -- for that,
#  a target board has to be on the other end of a real UART.
set -u

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"

#  Locate a native Ada toolchain (Alire layout), as the other harnesses do.
alire="$HOME/.local/share/alire/toolchains"
native=$(ls -d "$alire"/gnat_native_* 2>/dev/null | sort -V | tail -1)
gprbuild_dir=$(ls -d "$alire"/gprbuild_* 2>/dev/null | sort -V | tail -1)
[ -n "$native" ] && PATH="$native/bin:$PATH"
[ -n "$gprbuild_dir" ] && PATH="$gprbuild_dir/bin:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found" >&2; exit 2; }
command -v python3  >/dev/null || { echo "no python3" >&2; exit 2; }

gprbuild -q -P esp_loader_host.gpr || exit 1

work=$(mktemp -d "${TMPDIR:-/tmp}/esp_loader_test.XXXXXX")
trap 'rm -rf "$work"' EXIT

status=0
run () {   # run <description> <expected-exit> <scenario> [extra args...]
   local what=$1 want=$2 scenario=$3; shift 3
   local out; out=$(timeout 120 python3 ./fake_rom.py "$scenario" "$@" 2>&1)
   local got=$?
   if [ "$got" = "$want" ]; then
      printf '  %-44s ok\n' "$what"
   else
      printf '  %-44s FAILED (exit %s, wanted %s)\n' "$what" "$got" "$want"
      printf '%s\n' "$out" | sed 's/^/    /'
      status=1
   fi
}

echo "== a complete flashing run =="
#  Deliberately not a multiple of the 1 KB block, so the last block is partial
#  and has to be padded; and big enough to need several hundred blocks.
head -c 200000 /dev/urandom > "$work/image.bin"
run "connect, configure, stream, finish" 0 flash \
    --image "$work/image.bin" --out "$work/flashed.bin"

if cmp -s "$work/image.bin" "$work/flashed.bin"; then
   printf '  %-44s ok\n' "what the target received is byte-exact"
else
   printf '  %-44s FAILED\n' "what the target received is byte-exact"
   status=1
fi

echo "== individual commands =="
run "read a target register (chip magic)"  0 regread
run "raise the baud rate"                  0 baud
run "read the target's flash MD5"          0 md5

echo "== failures the caller must be told about =="
run "a refused command is not success"     0 refuse  --mode refuse_begin
run "a silent target gives up, not hangs"  0 silent  --mode silent
run "fewer bytes than declared"            0 short
run "more bytes than declared"             0 overrun

echo "== the harness itself can fail =="
#  If the target's IO0 never goes low it never enters the loader, so nothing
#  should get past SYNC.  A pass here would mean the simulator is asleep.
run "a target that never enters the loader" 1 flash \
    --image "$work/image.bin" --mode ignore_boot

exit $status
