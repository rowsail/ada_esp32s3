#!/bin/bash
#  Formally prove -- with SPARK / GNATprove -- the HAL units marked
#  `with SPARK_Mode => On`.
#
#  Most units are proved at --level=1 to the "silver" standard: absence of
#  run-time errors (no overflow, no array-index-out-of-range, no division by
#  zero, all loops terminate).  A growing number go further and prove what the
#  code MEANS, not only that it cannot fault -- see the "beyond silver" list
#  below.  The distinction matters: silver says a router cannot crash on any
#  destination, gold/platinum says it picks the right interface.
#
#  Runs against the NATIVE host / prove projects, so there is no cross-target or
#  embedded-RTS friction: the proven units are pure logic (parsers, serializers,
#  checksums, routing/date math) whose run-time-error freedom is target-independent.
#
#  A unit joins the proof surface by carrying `with SPARK_Mode => On` on its spec
#  and body (I/O / access / raising ops at the boundary get `SPARK_Mode => Off`);
#  GNATprove then analyses the On subset automatically.
#
#  Currently proven (0 unproved checks; "PLATINUM"/"GOLD" marks the units whose
#  contracts specify behaviour rather than only bounding it):
#    ext4      -- Get_*/Put_* byte helpers, CRC32C (PLATINUM: the 256-entry table
#                 AND the table-driven walk are proved equal to the bit-at-a-time
#                 polynomial definition, for every seed and every input -- what
#                 stood behind them before was one known-answer vector), and
#                 Superblock/Inode/Group_Desc
#                 /Bitmap/Block_Map/Dir/File serialization + validation; plus the
#                 mkfs single-group layout geometry (bounded + internally consistent);
#                 and the '/'-separated path-component scanner (untrusted input --
#                 PLATINUM: a component holds no '/', only separators are skipped,
#                 the scan stops only at a separator, and it always makes PROGRESS,
#                 which is what makes a caller's walk over a hostile path terminate)
#    X509      -- the DER TLV reader AND the certificate parser (untrusted input)
#    Der_Sig   -- the ECDSA-Sig-Value DER r/s parse (untrusted input): no over-read,
#                 and (GOLD) on ANY rejection the output is all-zero -- so ignoring
#                 the Ok flag cannot leave attacker-chosen bytes in an r or s
#    P256      -- the whole secp256r1 stack: field + order arithmetic (Montgomery
#                 CIOS), Jacobian point add/double/scalar-mul, AND the ECDSA
#                 Verify and On_Curve compositions over them (untrusted input --
#                 an attacker supplies the key, the hash and the signature)
#    P384      -- the same stack at secp384r1.  The arithmetic is literally the
#                 same source (the generics ECC_Bignum + ECC_Curve, instantiated
#                 at twelve limbs), but GNATprove proves generic INSTANCES, not
#                 generics: P256's run says nothing about the twelve-limb one, so
#                 it has its own project and its own obligations.  NOT in this
#                 pass -- see the note at the bottom; it is far too slow
#    NMEA      -- the NMEA-0183 GPS-sentence parser (untrusted input)
#    Modbus    -- slave framing/dispatch (Process) and master PDU build/parse
#    NTP       -- To_UTC civil-date math (PLATINUM: the fields are proved to
#                 denote exactly the instant they were made from, by round-trip
#                 through a ghost days_from_civil, AND Day <= the month's real
#                 length -- without that second clause the round-trip alone still
#                 admits February 30th, which maps to the same day number as
#                 March 2nd.  Together they admit exactly one answer per input)
#    Net_Routes-- IPv4 longest-prefix-match routing (GOLD: Resolve never returns an
#                 interface that is not on a route covering the destination, and
#                 the ranking itself -- longest prefix, then lowest metric, winner
#                 beaten by NO eligible route rather than just by none seen so far
#                 -- is proved of Select_Route.  This is what decides Ethernet->
#                 cellular failover)
#    Endian    -- LE/BE byte join/split (PLATINUM: each Join is pinned to the
#                 positional sum that defines the byte order and each Split
#                 round-trips through it, so the contracts are the whole meaning)
#    TLSF      -- allocator size-class + bit math; bucket indices PROVABLY in
#                 range (beyond silver: functional postconditions, --level=4)
#    Heap_Guard-- malloc/calloc request-size + overflow guards; a wrapping size
#                 request can never yield a live under-sized buffer
#    SHT41     -- CRC-8 + datasheet conversions.  CRC8 is itself the bit-at-a-time
#                 definition, so there is nothing independent to check it against;
#                 the content is in CRC_Good, whose Post is an "iff" over EVERY
#                 3-byte group -- a gap there accepts corrupt sensor data as good
#    SD_SPI    -- CRC-7 command frame; likewise bitwise, so the Post pins the part
#                 callers depend on: the trailing byte is a well-formed frame
#                 terminator (CRC in bits 7..1, mandatory stop bit set)
#    PCF85063A -- BCD<->binary (PLATINUM for To_BCD: the result is well-formed
#                 packed BCD and decodes back to exactly the input, so a
#                 transposed nibble stops proving instead of showing up as a
#                 wrong wall-clock reading on hardware).  From_BCD additionally
#                 bounds what a MALFORMED register byte can produce, which is the
#                 case a chip that lost VBAT actually hands back
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
   #  GNATprove grades a check message low:, medium: or high:.  Grepping only the
   #  top two would pass a low: one silently, so the authority is the report's
   #  Unproved column below; this grep is here to SHOW what failed, not to decide.
   if echo "$out" | grep -qiE "low:|medium:|high:|: *error:"; then
      echo "$out" | grep -iE "low:|medium:|high:|: *error:"
      fail=1
   fi
   #  Take the report path from gnatprove itself ("Summary logged in ..."), not
   #  from a glob of the project directory: libs/tls holds six object dirs, and
   #  globbing there printed a stale run's numbers under a neighbour's heading.
   local report unproved
   report="$(echo "$out" | sed -n 's/^Summary logged in //p' | tail -1)"
   if [ -n "$report" ] && [ -f "$report" ]; then
      #  Assertions and Functional Contracts are the rows that move when a unit
      #  is specified rather than merely bounded, so show them alongside the
      #  run-time checks instead of only the silver row.
      sed -n '/SPARK Analysis results/,/^Total/p' "$report" \
         | grep -iE "Run-time Checks|Assertions|Functional Contracts|^Total"
      #  The Total row's last column is the number of unproved obligations, or
      #  "." for none.  Read it rather than trusting the severity grep above.
      unproved="$(sed -n '/SPARK Analysis results/,/^Total/p' "$report" \
                  | awk '/^Total/ { print $NF }' | tail -1)"
      case "$unproved" in
         ""|".") echo "  no unproved obligations" ;;
         *) echo "  UNPROVED obligations reported: $unproved"; fail=1 ;;
      esac
   else
      echo "  (no summary report found)"
      fail=1
   fi
   echo
}

prove "$T/ext4_host/ext4_host.gpr"                   "ext4 (helpers/CRC32C/Superblock/Inode/Group_Desc/Bitmap/Block_Map/Dir/File)"
prove "$T/mkfs_math_prove/mkfs_math_prove.gpr"       "ext4 mkfs single-group layout (geometry bounded + consistent)"
prove "$T/path_scan_prove/path_scan_prove.gpr"       "ext4 path-component scanner (untrusted path, in-bounds)"
prove "$T/x509_prove/x509_prove.gpr"                 "X509 DER + certificate parser (untrusted input)"
prove "$ROOT/libs/tls/der_sig_prove.gpr"             "ECDSA DER r/s signature parse (untrusted input)"
#  The TLS client's two reads of server-chosen bytes.  Level 2 because several
#  bounds here compare a length against a position derived from another length,
#  which z3 alone will not close.
prove "$ROOT/libs/tls/tls_scan_prove.gpr" \
      "TLS ServerHello + handshake-flight walk (untrusted input, pre-authentication)" \
      "--level=2 --timeout=30"
#  P-256 is the slowest unit in this pass (~2.5 min): a single verification runs
#  two 256-bit scalar multiplications, so the proof carries the CIOS inner loops
#  through Dbl/Add and Scalar_Mul.  It is native because the arithmetic is pure
#  limbs -- no register access, nothing target-specific.  Explicitly `-u p256.adb`:
#  SPARKNaCl is in the project only because the RFC-6979 signing glue names it,
#  and re-proving a vendored library that ships with its own proof setup is not
#  this script's job.
prove "$ROOT/libs/tls/p256_prove.gpr" \
      "P-256 field/point arithmetic + ECDSA Verify/On_Curve (untrusted input)" \
      "--level=1 --prover=z3 --timeout=10 -u p256.adb"
prove "$T/nmea_prove/nmea_prove.gpr"                 "NMEA GPS-sentence parser (untrusted input)"
prove "$T/dns_prove/dns_prove.gpr"                   "DNS response parser (untrusted input)"
prove "$T/modbus_slave_host/modbus_slave_host.gpr"   "Modbus slave (framing + Process)"
prove "$T/modbus_master_host/modbus_master_host.gpr" "Modbus master (PDU build/parse)"
#  To_UTC is specified by round-trip through its own inverse, so the proof has to
#  carry Hinnant's civil-from-days arithmetic (a chain of integer divisions by
#  146097 / 1460 / 36524 / 365 / 153) through the equality.  z3 alone at level 1
#  does not close it; the full prover set at level 2 does, in a few seconds.
prove "$T/ntp_prove/ntp_prove.gpr" \
      "NTP To_UTC civil-date math (round-trips through days_from_civil)" \
      "--level=2 --prover=z3,cvc5,altergo --timeout=60"
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

#  P-384 (libs/tls/p384_prove.gpr) is proven silver too -- 135 obligations, 0
#  unproved -- but it is NOT in this pass.  Twelve-limb CIOS is a much larger
#  verification condition than eight, and Mont_Mul alone dominates the run: ~13
#  minutes against P-256's ~2.5, which is five times the cost of the current
#  slowest unit for a result that moves only when P-256's does.  To check it:
#    gnatprove -P libs/tls/p384_prove.gpr --level=1 --prover=z3 --timeout=10 \
#      -j0 --report=fail -u p384.adb
#  The bodies it proves are the SAME SOURCE P-256 proves here (ECC_Bignum and
#  ECC_Curve, instantiated at twelve limbs instead of eight), so this pass still
#  covers the code; what the P-384 run adds is that the twelve-limb instance of
#  it discharges too.
#
#  Cert chain-walking (libs/tls/chain_verify) is also proven silver, but via the
#  CROSS tls.gpr (target xtensa) + the SPARKNaCl closure -- slow to re-verify, so it
#  is not in this fast native pass.  To check it:
#    source export.sh; export ESP32S3_RTS_PROFILE=embedded \
#      XTENSA_GNU_CONFIG=.../xtensa_esp32s3.so
#    gnatprove -P libs/tls/tls.gpr --level=1 --prover=z3 -j0 -u chain_verify.adb
#
#  P256's Verify and On_Curve used to sit outside the subset, on the grounds that
#  their composition needed postcondition contracts on the field primitives -- a
#  lemma-level effort.  It did not: what blocked them was INLINING.  GNATprove
#  inlines a contract-less local subprogram into its caller, so Verify's
#  verification condition swallowed Mont_Mul's nested CIOS loops through Dbl/Add
#  and Scalar_Mul's 256 iterations, and did not converge.  Giving each primitive
#  `Global => null` -- true of every one of them, and the weakest contract that
#  exists -- makes the call opaque, and the whole unit proves in less time than
#  it took with Verify excluded.  Only Public_Key/ECDH/Sign remain Off, because a
#  SPARK function may not have out parameters; that is a shape problem, not a
#  proof one.

echo "PROVE_EXIT: $fail"
exit $fail
