#!/bin/bash
# Build + run the on-device ext4 formatter (ESP32S3.Ext4.Mkfs) against a blank
# image, then cross-check the result with the host's e2fsck -- both straight
# after format and after OUR FS writes to it.  Also has our FS mount + list it.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

AL="$HOME/.local/share/alire/toolchains"
NATIVE="$(ls -d "$AL"/gnat_native_* 2>/dev/null | sort | tail -1)"
GPR="$(ls -d "$AL"/gprbuild_* 2>/dev/null | sort | tail -1)"
[ -n "$NATIVE" ] && PATH="$NATIVE/bin:$PATH"
[ -n "$GPR" ]    && PATH="$GPR/bin:$PATH"
PATH="/usr/sbin:/sbin:$PATH"
export PATH
command -v gprbuild >/dev/null || { echo "no native gprbuild found"; exit 1; }
command -v e2fsck   >/dev/null || { echo "no e2fsck (install e2fsprogs)"; exit 1; }

gprbuild -P mkfs_host.gpr -q

IMG="$(mktemp /tmp/mkfs_host.XXXXXX.img)"
trap 'rm -f "$IMG"' EXIT

check() { # $1 = scenario, $2 = size
   rm -f "$IMG"; truncate -s "$2" "$IMG"
   ./mkfs_host "$IMG" "$1" >/tmp/mkfs_host.out 2>&1 || {
      printf '  %-8s %-6s HARNESS FAIL\n' "$1" "$2"; sed 's/^/      /' /tmp/mkfs_host.out; return; }
   if e2fsck -f -n "$IMG" >/tmp/mkfs_host.fsck 2>&1; then
      printf '  %-8s %-6s e2fsck CLEAN\n' "$1" "$2"
   else
      printf '  %-8s %-6s e2fsck ERRORS:\n' "$1" "$2"
      grep -iE 'inode|block|bitmap|count|wrong|invalid|free|pass' /tmp/mkfs_host.fsck | sed 's/^/      /'
   fi
}

for SZ in 1M 8M 64M; do check format "$SZ"; done
check mount 8M
cat /tmp/mkfs_host.out | sed 's/^/      /'
check rw 8M
echo "done."
