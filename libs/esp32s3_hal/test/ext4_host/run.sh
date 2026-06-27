#!/bin/bash
# Build the native ext4 host harness and exercise it against file-backed ext4
# images, cross-checking each with the host's own e2fsck.
#
# Requirements:
#   * a NATIVE GNAT + gprbuild (the Alire toolchains are auto-discovered below,
#     or put gprbuild/gnatmake on PATH yourself)
#   * mkfs.ext4 + e2fsck (e2fsprogs; usually in /usr/sbin)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

# --- locate a native Ada toolchain (Alire layout) + e2fsprogs ---
AL="$HOME/.local/share/alire/toolchains"
NATIVE="$(ls -d "$AL"/gnat_native_* 2>/dev/null | sort | tail -1)"
GPR="$(ls -d "$AL"/gprbuild_* 2>/dev/null | sort | tail -1)"
[ -n "$NATIVE" ] && PATH="$NATIVE/bin:$PATH"
[ -n "$GPR" ]    && PATH="$GPR/bin:$PATH"
PATH="/usr/sbin:/sbin:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }
command -v mkfs.ext4 >/dev/null || { echo "no mkfs.ext4 (install e2fsprogs)"; exit 1; }

gprbuild -P ext4_host.gpr -q

IMG="$(mktemp /tmp/ext4_host.XXXXXX.img)"
trap 'rm -f "$IMG"' EXIT
fresh() { rm -f "$IMG"; truncate -s 64M "$IMG"; mkfs.ext4 -q -F -O ^metadata_csum -b 4096 "$IMG"; }

# A no-journal volume (mkfs -O ^has_journal): the FS commits by flushing the
# cache + superblock directly instead of journaling (ESP32S3.Ext4.FS.Commit).
fresh_nojournal() {
   rm -f "$IMG"; truncate -s 64M "$IMG"
   mkfs.ext4 -q -F -O ^metadata_csum,^has_journal -b 4096 "$IMG"
}

run_scenario() { # $1 = scenario, $2 = label
   if ! ./ext4_host "$IMG" "$1" >/tmp/ext4_host.out 2>&1; then
      # harness exits non-zero on a phantom free (double-free bug)
      printf '  %-14s HARNESS FAIL: %s\n' "$2" \
             "$(grep -i 'PHANTOM' /tmp/ext4_host.out | head -1)"
   elif e2fsck -f -n "$IMG" >/tmp/ext4_host.fsck 2>&1; then
      printf '  %-14s e2fsck CLEAN\n' "$2"
   else
      printf '  %-14s e2fsck ERRORS:\n' "$2"
      grep -iE 'wrong|invalid|unattached|deleted' /tmp/ext4_host.fsck | sed 's/^/      /'
   fi
}

# Scenarios mirror examples/esp32s3_ext4_write and the re-run drift hunt.
echo "journaled:"
for S in one two rerun battery dirty_battery stream; do fresh; run_scenario "$S" "$S"; done
grep -h '^stream:' /tmp/ext4_host.out | sed 's/^/      /'

echo "double-indirect (Append/Truncate/Unlink > 4 MiB):"
for S in dindirect dtrunc dunlink; do
   fresh; run_scenario "$S" "$S"
   grep -hE "^(dindirect|dtrunc|dunlink):" /tmp/ext4_host.out | sed 's/^/      /'
done

echo "no-journal:"
for S in one two battery stream; do fresh_nojournal; run_scenario "$S" "$S"; done
grep -h '^stream:' /tmp/ext4_host.out | sed 's/^/      /'
echo "done."
