#!/bin/bash
#  Formally prove -- with SPARK / GNATprove at --level=1 ("silver": absence of
#  run-time errors: no overflow, no array-index-out-of-range, no division by
#  zero, all loops terminate) -- the HAL units marked `with SPARK_Mode => On`.
#
#  Runs against the NATIVE host / prove projects, so there is no cross-target or
#  embedded-RTS friction: the proven units are pure logic (parsers, serializers,
#  checksums, routing/date math) whose run-time-error freedom is target-independent.
#
#  A unit joins the proof surface by carrying `with SPARK_Mode => On` on its spec
#  and body (I/O / access / raising ops at the boundary get `SPARK_Mode => Off`);
#  GNATprove then analyses the On subset automatically.
#
#  Currently proven (silver, 0 unproved checks):
#    ext4      -- Get_*/Put_* byte helpers, CRC32C, and Superblock/Inode/Group_Desc
#                 /Bitmap/Block_Map/Dir/File serialization + validation
#    X509      -- the DER TLV reader AND the certificate parser (untrusted input)
#    Der_Sig   -- the ECDSA-Sig-Value DER r/s parse (untrusted input): no over-read
#    NMEA      -- the NMEA-0183 GPS-sentence parser (untrusted input)
#    Modbus    -- slave framing/dispatch (Process) and master PDU build/parse
#    NTP       -- To_UTC civil-date math
#    Net_Routes-- IPv4 longest-prefix-match routing
#    Endian    -- LE/BE byte join/split
#    TLSF      -- allocator size-class + bit math; bucket indices PROVABLY in
#                 range (beyond silver: functional postconditions, --level=4)
#    Heap_Guard-- malloc/calloc request-size + overflow guards; a wrapping size
#                 request can never yield a live under-sized buffer
#    LEDC/MCPWM-- Set_Duty Float duty scaling: the Float->count conversion has no
#                 range error / NaN for any Percent (0 .. 100)
#
#  gnatprove is provided by the Alire toolchain (~/.alire/bin/gnatprove).
export PATH="$HOME/.alire/bin:$PATH"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$ROOT/libs/esp32s3_hal/test"
fail=0

prove () {  #  $1 = project file, $2 = label, $3 = gnatprove tuning (optional)
   echo "=== prove: $2 ==="
   local tune="${3:---level=1 --prover=z3 --timeout=10}"
   local out
   out="$(gnatprove -P "$1" $tune -j0 --report=fail --output=oneline 2>&1)"
   if echo "$out" | grep -qiE "medium:|high:|: *error:"; then
      echo "$out" | grep -iE "medium:|high:|: *error:"
      fail=1
   else
      echo "  no unproved run-time checks"
   fi
   #  the object dir varies per project (obj / obj-prove); glob for the report.
   sed -n '/SPARK Analysis results/,/^Total/p' \
      "$(dirname "$1")"/obj*/gnatprove/gnatprove.out 2>/dev/null \
      | grep -iE "Run-time Checks|^Total"
   echo
}

prove "$T/ext4_host/ext4_host.gpr"                   "ext4 (helpers/CRC32C/Superblock/Inode/Group_Desc/Bitmap/Block_Map/Dir/File)"
prove "$T/x509_prove/x509_prove.gpr"                 "X509 DER + certificate parser (untrusted input)"
prove "$ROOT/libs/tls/der_sig_prove.gpr"             "ECDSA DER r/s signature parse (untrusted input)"
prove "$T/nmea_prove/nmea_prove.gpr"                 "NMEA GPS-sentence parser (untrusted input)"
prove "$T/dns_prove/dns_prove.gpr"                   "DNS response parser (untrusted input)"
prove "$T/modbus_slave_host/modbus_slave_host.gpr"   "Modbus slave (framing + Process)"
prove "$T/modbus_master_host/modbus_master_host.gpr" "Modbus master (PDU build/parse)"
prove "$T/ntp_prove/ntp_prove.gpr"                   "NTP To_UTC civil-date math"
prove "$T/net_routes_prove/net_routes_prove.gpr"     "Net_Routes longest-prefix match"
prove "$T/aes_gcm_prove/aes_gcm_prove.gpr"           "AES-GCM GHASH GF(2^128) + CTR"
prove "$T/sht41_prove/sht41_prove.gpr"               "SHT41 CRC-8 + datasheet conversions"
prove "$T/sd_spi_prove/sd_spi_prove.gpr"             "SD_SPI CRC-7 command frame"
prove "$T/pcf85063a_prove/pcf85063a_prove.gpr"       "PCF85063A RTC BCD<->binary"
prove "$T/qmi8658c_prove/qmi8658c_prove.gpr"         "QMI8658C IMU sign/sensitivity"
prove "$T/tlv2556_prove/tlv2556_prove.gpr"           "TLV2556 ADC count->mV"
prove "$T/es8311_prove/es8311_prove.gpr"             "ES8311 codec volume register"
prove "$T/twai_math_prove/twai_math_prove.gpr"       "TWAI CAN baud prescaler"
prove "$T/ledc_math_prove/ledc_math_prove.gpr"       "LEDC clock divider + Float duty scaling"
prove "$T/rmt_math_prove/rmt_math_prove.gpr"         "RMT tick divider"
prove "$T/mcpwm_math_prove/mcpwm_math_prove.gpr"     "MCPWM period/prescale/dead-time + Float duty"
prove "$T/endian_host/endian_host.gpr"               "Endian join/split"

#  TLSF allocator locate-math lives with the bare boot support, not the HAL, and
#  proves BEYOND silver -- the functional postcondition that Mapping/Mapping_Search
#  always yield in-range bucket indices needs --level=4 + the full prover set.
prove "$ROOT/examples/common/bare/boot/tlsf_math_prove.gpr" \
      "TLSF allocator size-class + bit math (bucket indices in range)" \
      "--level=4 --prover=z3,cvc5,altergo --timeout=60"

#  malloc/calloc request-size guards: a wrapping size request can never yield a
#  live under-sized buffer (the classic calloc integer-overflow class).
prove "$ROOT/examples/common/bare/boot/heap_guard_prove.gpr" \
      "malloc/calloc request-size + overflow guards (Heap_Guard)" \
      "--level=3 --prover=z3,cvc5,altergo --timeout=30"

#  Cert chain-walking (libs/tls/chain_verify) is also proven silver, but via the
#  CROSS tls.gpr (target xtensa) + the SPARKNaCl closure -- slow to re-verify, so it
#  is not in this fast native pass.  To check it:
#    source export.sh; export ESP32S3_RTS_PROFILE=embedded \
#      XTENSA_GNU_CONFIG=.../xtensa_esp32s3.so
#    gnatprove -P libs/tls/tls.gpr --level=1 --prover=z3 -j0 -u chain_verify.adb

echo "PROVE_EXIT: $fail"
exit $fail
