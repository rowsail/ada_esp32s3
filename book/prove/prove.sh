#!/bin/bash
#  Formally prove -- with SPARK / GNATprove at --level=2 ("silver": absence of
#  run-time errors: no overflow, no array-index-out-of-range, no division by
#  zero, all loops terminate) -- the HAL units marked `with SPARK_Mode => On`.
#
#  Runs against the NATIVE host test projects, so there is no cross-target or
#  embedded-RTS friction: the proven units are pure logic (parsers, serializers,
#  checksums) whose run-time-error freedom is target-independent.
#
#  A unit joins the proof surface simply by carrying `with SPARK_Mode => On` on
#  its spec and body; GNATprove then analyses it (and only it) automatically.
#
#  Currently proven (silver, 0 unproved checks):
#    * ESP32S3.Ext4.CRC32C   -- ext4 metadata checksum        (ext4_host.gpr)
#    * Modbus                -- Modbus-TCP wire framing        (modbus_slave_host.gpr)
#
#  gnatprove is provided by the Alire toolchain (~/.alire/bin/gnatprove).
export PATH="$HOME/.alire/bin:$PATH"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$ROOT/libs/esp32s3_hal/test"
fail=0

prove () {  #  $1 = project file, $2 = label
   echo "=== prove: $2 ==="
   local out
   out="$(gnatprove -P "$1" --level=2 --report=fail -j0 --output=oneline 2>&1)"
   if echo "$out" | grep -qiE "medium:|high:|: *error:"; then
      echo "$out" | grep -iE "medium:|high:|: *error:"
      fail=1
   else
      echo "  no unproved run-time checks"
   fi
   sed -n '/SPARK Analysis results/,/^Total/p' \
      "$(dirname "$1")/obj/gnatprove/gnatprove.out" 2>/dev/null \
      | grep -iE "Run-time Checks|^Total"
   echo
}

prove "$T/ext4_host/ext4_host.gpr"                 "ext4 CRC32C"
prove "$T/modbus_slave_host/modbus_slave_host.gpr" "Modbus framing"

echo "PROVE_EXIT: $fail"
exit $fail
