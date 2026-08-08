#!/bin/bash
#  Host test for ESP32S3.Fat16 (libs/esp32s3_hal/src/fat16).
#
#      ./run_tests.sh
#
#  Three independent opinions have to agree about every volume:
#
#    1. the Ada code under test (ESP32S3.Fat16.Mkfs writes, ESP32S3.Fat16 reads),
#    2. the host's own dosfstools -- fsck.fat checks what we wrote, mkfs.fat
#       writes volumes we must read,
#    3. reference_writer.py, a FAT16 writer written from the specification
#       rather than from the Ada source, which injects the files.
#
#  A bug that only one of the three believes in shows up as a disagreement.
set -u

here=$(cd "$(dirname "$0")" && pwd)
work="${TMPDIR:-/tmp}/fat16_test.$$"
mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

#  Locate a native Ada toolchain (Alire layout) + dosfstools, the same way the
#  other host harnesses in this directory do.
alire="$HOME/.local/share/alire/toolchains"
native=$(ls -d "$alire"/gnat_native_* 2>/dev/null | sort -V | tail -1)
gprbuild_dir=$(ls -d "$alire"/gprbuild_* 2>/dev/null | sort -V | tail -1)
[ -n "$native" ] && PATH="$native/bin:$PATH"
[ -n "$gprbuild_dir" ] && PATH="$gprbuild_dir/bin:$PATH"
PATH="/usr/sbin:/sbin:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found" >&2; exit 2; }

command -v fsck.fat >/dev/null || { echo "need dosfstools (fsck.fat)" >&2; exit 2; }
command -v mkfs.fat >/dev/null || { echo "need dosfstools (mkfs.fat)" >&2; exit 2; }

gprbuild -q -P "$here/fat16_host.gpr" || exit 1

#  fsck.fat takes a filesystem, not a disk image: on a partitioned image it
#  would read the partition table as a boot sector.  Carve the partition out
#  first (offset 2048 sectors, the alignment our formatter uses).
fsck_partition () {
   dd if="$1" of="$work/part.img" bs=512 skip=2048 status=none || return 2
   fsck.fat -n "$work/part.img"
}
tool="$here/fat16_test"
inject="$here/reference_writer.py"

status=0
check () {   # check <description> <expected-exit> -- <command...>
   local what=$1 want=$2; shift 3
   local out; out=$("$@" 2>&1); local got=$?
   if [ "$got" = "$want" ]; then
      printf '  %-46s ok\n' "$what"
   else
      printf '  %-46s FAILED (exit %s, wanted %s)\n' "$what" "$got" "$want"
      [ -n "$out" ] && printf '%s\n' "$out" | sed 's/^/      /'
      status=1
   fi
}

expect_status () {   # expect_status <description> <image> <wanted-word>
   local what=$1 image=$2 want=$3
   local out; out=$("$tool" info "$image" 2>&1)
   if printf '%s' "$out" | grep -q "$want"; then
      printf '  %-46s ok\n' "$what"
   else
      printf '  %-46s FAILED (got: %s)\n' "$what" "$out"
      status=1
   fi
}

# -- the payloads every volume gets ------------------------------------------
mk_payloads () {
   head -c 716800 /dev/urandom > "$work/app.bin"
   head -c 21504  /dev/urandom > "$work/bootloader.bin"
   head -c 3072   /dev/urandom > "$work/partition-table.bin"
   printf '0x00000 bootloader.bin\n0x10000 app.bin\n' > "$work/flash.txt"
   head -c 4096   /dev/urandom > "$work/nested.bin"
   : > "$work/empty.bin"
   #  A name that needs four long-name slots, plus one at the 255 limit.
   long_name="a-deliberately-overlong-firmware-image-name-for-the-programmer.bin"
   limit_name=$(printf 'x%.0s' $(seq 1 251)).bin
}

fill () {   # fill <image>
   local image=$1
   python3 "$inject" "$image" put /bootloader.bin      "$work/bootloader.bin"      || return 1
   python3 "$inject" "$image" put /partition-table.bin "$work/partition-table.bin" || return 1
   python3 "$inject" "$image" put /app.bin             "$work/app.bin"             || return 1
   python3 "$inject" "$image" put /flash.txt           "$work/flash.txt"           || return 1
   python3 "$inject" "$image" put "/$long_name"        "$work/bootloader.bin"      || return 1
   python3 "$inject" "$image" put "/$limit_name"       "$work/flash.txt"           || return 1
   python3 "$inject" "$image" mkdir /firmware                                      || return 1
   python3 "$inject" "$image" put /firmware/nested.bin "$work/nested.bin"          || return 1
   python3 "$inject" "$image" put /empty.bin           "$work/empty.bin"           || return 1
}

verify_reads () {   # verify_reads <image> <label>
   local image=$1 tag=$2

   local listing; listing=$("$tool" list "$image")
   for want in bootloader.bin partition-table.bin app.bin flash.txt "$long_name" "$limit_name" firmware; do
      if printf '%s\n' "$listing" | grep -Fq -- "$want"; then
         printf '  %-46s ok\n' "$tag: lists $(printf '%.30s' "$want")"
      else
         printf '  %-46s FAILED\n' "$tag: lists $(printf '%.30s' "$want")"
         printf '%s\n' "$listing" | sed 's/^/      /'
         status=1
      fi
   done

   #  The directory must be reported as one, with the right size on files.
   if printf '%s\n' "$listing" | grep -q "^DIR .* firmware$"; then
      printf '  %-46s ok\n' "$tag: firmware is a directory"
   else
      printf '  %-46s FAILED\n' "$tag: firmware is a directory"; status=1
   fi
   if printf '%s\n' "$listing" | grep -q "^FILE  *716800 app.bin$"; then
      printf '  %-46s ok\n' "$tag: app.bin size"
   else
      printf '  %-46s FAILED\n' "$tag: app.bin size"; status=1
   fi

   #  Byte-for-byte extraction, including the multi-cluster 700 KB image.
   for pair in "/app.bin:app.bin" "/bootloader.bin:bootloader.bin" \
               "/partition-table.bin:partition-table.bin" "/flash.txt:flash.txt" \
               "/firmware/nested.bin:nested.bin" "/empty.bin:empty.bin"; do
      local path=${pair%%:*} src=${pair##*:}
      if "$tool" cat "$image" "$path" "$work/out" >/dev/null 2>&1 \
         && cmp -s "$work/out" "$work/$src"; then
         printf '  %-46s ok\n' "$tag: $path byte-exact"
      else
         printf '  %-46s FAILED\n' "$tag: $path byte-exact"; status=1
      fi
   done

   #  Case-insensitive matching, and a path that is not there.
   if "$tool" readall "$image" /app.bin "$work/out" >/dev/null 2>&1 \
      && cmp -s "$work/out" "$work/app.bin"; then
      printf '  %-46s ok\n' "$tag: whole-file read"
   else
      printf '  %-46s FAILED\n' "$tag: whole-file read"; status=1
   fi

   check "$tag: case-insensitive open"  0 -- "$tool" cat "$image" /APP.BIN "$work/out"
   check "$tag: missing file rejected"  1 -- "$tool" cat "$image" /nope.bin "$work/out"
   check "$tag: directory is not a file" 1 -- "$tool" cat "$image" /firmware "$work/out"
}

mk_payloads

# ---------------------------------------------------------------------------
echo "== our own mkfs, 32 MB, partitioned =="
image="$work/ours.img"
head -c 33554432 /dev/zero > "$image"
check "format"            0 -- "$tool" format "$image" ESPPROG
check "fsck.fat agrees"   0 -- fsck_partition "$image"
expect_status "label read back" "$image" "ESPPROG"
expect_status "4 KB clusters"   "$image" "cluster_bytes 4096"
check "fill via the reference writer" 0 -- bash -c "$(declare -f fill); work=$work; long_name='$long_name'; limit_name='$limit_name'; inject=$inject; fill $image"
check "fsck.fat agrees after filling" 0 -- fsck_partition "$image"
verify_reads "$image" "ours"

# ---------------------------------------------------------------------------
echo "== mkfs.fat, no partition table (a bare superfloppy) =="
image="$work/superfloppy.img"
head -c 33554432 /dev/zero > "$image"
check "mkfs.fat -F 16"    0 -- mkfs.fat -F 16 -S 512 -n HOSTMADE "$image"
expect_status "mounts"    "$image" "label         HOSTMADE"
check "fill via the reference writer" 0 -- bash -c "$(declare -f fill); work=$work; long_name='$long_name'; limit_name='$limit_name'; inject=$inject; fill $image"
check "fsck.fat agrees after filling" 0 -- fsck.fat -n "$image"
verify_reads "$image" "superfloppy"

# ---------------------------------------------------------------------------
echo "== mkfs.fat inside a partition (what Windows writes to a stick) =="
image="$work/hostpart.img"
head -c 33554432 /dev/zero > "$image"
#  Borrow our own formatter for the partition table, then let mkfs.fat lay the
#  filesystem inside that partition -- so the table is ours and the volume is
#  the host's, and the reader has to follow the offset.
"$tool" format "$image" TABLEONLY
check "mkfs.fat --offset 2048" 0 -- mkfs.fat -F 16 -S 512 --offset 2048 -n HOSTPART "$image" 31744
check "fsck.fat agrees with the host volume" 0 -- fsck_partition "$image"
expect_status "follows the partition offset" "$image" "label         HOSTPART"
check "fill via the reference writer" 0 -- bash -c "$(declare -f fill); work=$work; long_name='$long_name'; limit_name='$limit_name'; inject=$inject; fill $image"
verify_reads "$image" "hostpart"

# ---------------------------------------------------------------------------
echo "== volumes we must refuse rather than misread =="
image="$work/fat32.img"
head -c 268435456 /dev/zero > "$image"
mkfs.fat -F 32 -S 512 "$image" >/dev/null 2>&1
expect_status "FAT32 rejected as UNSUPPORTED" "$image" "UNSUPPORTED"

image="$work/fat12.img"
head -c 1474560 /dev/zero > "$image"
mkfs.fat -F 12 -S 512 "$image" >/dev/null 2>&1
expect_status "FAT12 rejected as UNSUPPORTED" "$image" "UNSUPPORTED"

image="$work/blank.img"
head -c 33554432 /dev/zero > "$image"
expect_status "blank flash rejected as NOT_FORMATTED" "$image" "NOT_FORMATTED"

image="$work/garbage.img"
head -c 33554432 /dev/urandom > "$image"
expect_status "random bytes rejected" "$image" "NOT_FORMATTED\|UNSUPPORTED\|BAD_DATA"

exit $status
