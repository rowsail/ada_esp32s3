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

echo "== every chip family the simulator can impersonate =="
#  The ROM protocol is NOT uniform across the family.  Each of these differs
#  from the modern default in at least one way the loader has to get right:
#  how the chip is identified at all, how many status bytes end a reply, how
#  long a FLASH_BEGIN payload it accepts, whether SPI_ATTACH exists, and
#  whether its erase size needs doctoring.
for chip in esp8266 esp32 esp32s2 esp32s3 esp32c3 esp32c6 esp32p4; do
   name=$(timeout 60 python3 ./fake_rom.py detect --chip "$chip" 2>&1 | sed -n 's/.*CHIP //p')
   if [ -n "$name" ]; then
      printf '  %-44s ok\n' "identified as $name"
   else
      printf '  %-44s FAILED\n' "identify $chip"; status=1
   fi

   out="$work/flashed_$chip.bin"
   if timeout 120 python3 ./fake_rom.py flash --image "$work/image.bin" \
         --out "$out" --chip "$chip" >"$work/log_$chip" 2>&1 \
      && cmp -s "$work/image.bin" "$out"; then
      printf '  %-44s ok\n' "  ... flashed byte-exact"
   else
      printf '  %-44s FAILED\n' "  ... flashed byte-exact"
      sed 's/^/    /' "$work/log_$chip" | head -6
      status=1
   fi
done

echo "== individual commands =="
run "read a target register (chip magic)"  0 regread
run "raise the baud rate"                  0 baud
run "read the target's flash MD5"          0 md5

echo "== emulating the auto-reset circuit for a PC's esptool =="
#  In pass-through mode the PC's esptool wiggles DTR/RTS at what it thinks is
#  an ordinary USB-serial bridge.  These replay its own sequences through the
#  emulated circuit; the simulator watches the control lines and decides
#  whether the target really ended up in its download loader.
run "esptool ClassicReset reaches the loader"  0 classic  --expect download
run "esptool UnixTightReset reaches the loader" 0 tight   --expect download
run "a terminal opening the port disturbs nothing" 0 terminal --expect untouched

echo "== failures the caller must be told about =="
run "a refused command is not success"     0 refuse  --mode refuse_begin
run "a silent target gives up, not hangs"  0 silent  --mode silent
run "fewer bytes than declared"            0 short
run "more bytes than declared"             0 overrun

echo "== the harness itself can fail =="
#  Three deliberate breakages of the per-chip handling, each rebuilt, run and
#  required to be CAUGHT.  Without these the chip table could quietly be
#  decoration: every scenario above would still pass if the loader ignored it
#  and the simulator never checked.
mutate () {   # mutate <description> <sed-expression> <scenario> [args...]
   local what=$1 edit=$2; shift 2
   cp "$loader" "$work/loader.bak"
   sed -i "$edit" "$loader"

   #  A mutation that did not apply -- a stale expression after the source was
   #  reworded -- would look exactly like one that was caught.  Check.
   if cmp -s "$loader" "$work/loader.bak"; then
      printf '  %-44s FAILED (mutation did not apply)\n' "$what"
      status=1
      cp "$work/loader.bak" "$loader"
      return
   fi
   #  Force the rebuild.  gprbuild's timestamp check is not fine-grained
   #  enough for back-to-back restore-then-mutate, and a skipped rebuild would
   #  ALSO look exactly like the mutation being caught.  The project is a
   #  handful of units; correctness is worth the second.

   local out build
   gprbuild -q -f -P esp_loader_host.gpr 2>"$work/build.err"; build=$?
   out=$(timeout 120 python3 ./fake_rom.py "$@" 2>&1); local got=$?
   if [ "$build" = 0 ] && [ "$got" != 0 ]; then
      printf '  %-44s ok\n' "$what"
   else
      printf '  %-44s FAILED (not caught)\n' "$what"
      [ "$build" != 0 ] && sed 's/^/    build: /' "$work/build.err" | head -5
      printf '%s\n' "$out" | sed 's/^/    /' | head -6
      status=1
   fi

   cp "$work/loader.bak" "$loader"
   gprbuild -q -f -P esp_loader_host.gpr 2>/dev/null
}

loader=../../src/esp_loader/esp32s3-esp_loader.adb
mutate "an ESP32 sent the long FLASH_BEGIN" \
   's/Extended : constant Boolean := S.Kind not in Esp32 | Esp8266;/Extended : constant Boolean := True;/' \
   flash --image "$work/image.bin" --chip esp32
mutate "an ESP32's four status bytes ignored" \
   's/S.Status_Bytes := (if S.Kind = Esp32 then 4 else Default_Status_Bytes);/S.Status_Bytes := Default_Status_Bytes;/' \
   refuse --mode refuse_begin --chip esp32
mutate "an ESP8266 erase size left undoctored" \
   's/      if Kind \/= Esp8266 then/      if True then/' \
   flash --image "$work/image.bin" --chip esp8266

#  The two halves of the auto-reset emulation, each removed in turn.  Without
#  the software capacitor ClassicReset lets the target out of reset a fraction
#  too early and it boots the application; without the cross-coupling a
#  terminal emulator resets the target just by opening the port.
loader=../../src/esp_loader/esp32s3-esp_loader-auto_reset.adb
mutate "reset released with no software RC" \
   's/if not C.Release_Pending then/if False then/' \
   classic --expect download
mutate "control lines mapped straight through" \
   's/RTS and then not DTR/RTS/; s/DTR and then not RTS/DTR/' \
   terminal --expect untouched

#  If the target's IO0 never goes low it never enters the loader, so nothing
#  should get past SYNC.  A pass here would mean the simulator is asleep.
run "a target that never enters the loader" 1 flash \
    --image "$work/image.bin" --mode ignore_boot

exit $status
