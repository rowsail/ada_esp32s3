#!/bin/bash
# Regenerate the ESP32-S3 register layer in svd/ from a CMSIS-SVD file using
# svd2ada (AdaCore), built from the LATEST source.  Run this MANUALLY after
# changing the SVD or the svd2ada options -- it is NOT part of the build; the
# generated output is committed so consumers never need svd2ada.
#
# SVD source: the official espressif/svd repo, pinned to a commit (currently
# ESP32-S3 SVD version 21).  This supersedes the older Arduino-bundled SVD (v12),
# whose only base-address defect (INTERRUPT_CORE1 = 0x600C2800) is fixed upstream
# here (0x600C2000) -- so no base patch is needed.  Override with a local file
# via ESP32S3_SVD=/path.svd.
#
# NOTE: the Alire-indexed svd2ada is too old -- it leaves %s template
# placeholders in dimensioned register arrays (e.g. RMT), which do not compile;
# so we build the current source instead.  Three post-processes follow: qualify
# System->Standard.System in the SYSTEM peripheral (case-insensitive name clash),
# give the peripheral objects explicit SPARK external-state aspects, and
# re-expand the flattened Apache header.
#
#   ./regenerate.sh            # fetches the pinned espressif/svd esp32s3.svd
#   ESP32S3_SVD=/path.svd ./regenerate.sh
#
# Root package is ESP32S3_Registers (NOT Interfaces.ESP32S3: GNAT forbids
# user-defined descendants of Interfaces outside the runtime).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$HERE/.svd2ada"
mkdir -p "$WORK"

# Pinned espressif/svd commit (esp32s3.svd v21); cached in .svd2ada/.
SVD_COMMIT="104da3c8e28a3c3a088c68a5ad1d31272b3d43ef"
SVD="${ESP32S3_SVD:-}"
if [ -z "$SVD" ]; then
    SVD="$WORK/esp32s3.svd"          # clean name -> clean "generated from" comment
    MARK="$WORK/.svd-commit"
    if [ "$(cat "$MARK" 2>/dev/null)" != "$SVD_COMMIT" ]; then
        echo "[regen] fetching espressif/svd esp32s3.svd @ ${SVD_COMMIT:0:10} ..."
        curl -fsSL "https://raw.githubusercontent.com/espressif/svd/$SVD_COMMIT/svd/esp32s3.svd" -o "$SVD"
        echo "$SVD_COMMIT" > "$MARK"
    fi
fi
[ -f "$SVD" ] || { echo "SVD not found: $SVD  (set ESP32S3_SVD=/path/to/esp32s3.svd)"; exit 1; }

# Build svd2ada from the latest AdaCore source (Alire resolves its xmlada dep).
# Cloned + built into .svd2ada/; cached after the first run.
SVD2ADA="$WORK/svd2ada-src/bin/svd2ada"
if [ ! -x "$SVD2ADA" ]; then
    echo "[regen] cloning + building svd2ada from source (one-time; needs network) ..."
    rm -rf "$WORK/svd2ada-src"; mkdir -p "$WORK"
    git clone --depth 1 https://github.com/AdaCore/svd2ada.git "$WORK/svd2ada-src"
    ( cd "$WORK/svd2ada-src" && alr -n build )
fi

echo "[regen] svd2ada: $SVD2ADA"
rm -rf "$HERE/svd"; mkdir -p "$HERE/svd"
"$SVD2ADA" "$SVD" -o "$HERE/svd" -p ESP32S3_Registers --boolean
echo "[regen] regenerated svd/ ($(ls "$HERE"/svd/*.ads | wc -l) packages) from $SVD"

# The SVD peripheral named "SYSTEM" generates package ESP32S3_Registers.SYSTEM;
# Ada is case-insensitive, so a bare `System.X` inside it resolves to that child
# (which has no such X) instead of Standard.System.  Qualify it so SYSTEM compiles.
sed -i -E "s/\\bSystem\\./Standard.System./g; s/\\bSystem'/Standard.System'/g" \
    "$HERE/svd/esp32s3_registers-system.ads"
echo "[regen] qualified System -> Standard.System in the SYSTEM peripheral"

# (The INTERRUPT_CORE1 base is correct in the v21 SVD -- 0x600C2000, shared with
# INTERRUPT_CORE0 -- so the base patch the old Arduino v12 SVD needed is gone.)

# Give every peripheral object explicit SPARK external-state aspects.
#
# svd2ada already marks the peripheral record type Volatile, so SPARK does see
# a bank as external state.  What it does not do is say WHICH KIND, and the
# default when the four aspects are left unstated is all True -- the most
# conservative reading, in which a read is itself a state change.
#
# That default costs something concrete: SPARK rejects any Volatile_Function
# over a bank outright ("function ... with volatile input global ... with
# effective reads is not allowed in SPARK"), and a volatile function is the
# standard way to bring a hardware reading into a contract.  Supplying the
# aspects is what makes that legal.  Measured on a probe reading GPIO_Periph:
# rejected before, fully proved after.
#
# The aspects are inert for code generation -- the firmware binary is
# byte-identical with and without them.
#
# A post-process rather than a hand edit, for the reason the other two here
# are: line 1 of this script is "rm -rf $HERE/svd", so an edit made in svd/ is
# gone the next time anyone regenerates.
#
# The aspects apply to the OBJECT, and a peripheral is one object, so a bank
# gets ONE characterisation covering all its registers.  That forces a choice
# on Effective_Reads, and the two directions are not symmetric:
#
#   False on a bank whose reads consume is UNSOUND -- SPARK would then believe
#         that reading a FIFO twice yields the same byte.
#   True  on a bank whose reads do not consume is merely the default: it
#         rejects some valid code and accepts nothing invalid.
#
# So a bank keeps True if ANY register in it has a consuming read.  The list
# below is by inspection of the generated registers, not by name:
#
#   I2C0/I2C1  DATA.FIFO_RDATA        USB_DEVICE  EP1  (the console FIFO)
#   RMT        CHDATA                 SDHOST      BUFFIFO
#   UART0/1/2  FIFO.RXFIFO_RD_BYTE
#
# Banks whose names suggest a FIFO but whose reads do NOT consume, so they are
# deliberately absent: DMA (INFIFO_*/OUTFIFO_* are counters and status), TWAI0
# (DATA_0..12 is a buffer window; the FIFO advances on the RELEASE_BUF command,
# not on the read), USB0 (GDFIFOCFG is configuration -- the DWC-OTG FIFO
# windows are outside the bank), and SPI/I2S/LCD_CAM/UHCI/USB_WRAP (status and
# configuration only).
#
# Volatile is repeated on the object although the type already carries it:
# redundant today, and a safety net if svd2ada ever stops emitting it, since
# the other three aspects are only meaningful on a volatile object.
python3 - "$HERE/svd" <<'ANNOT'
import glob, re, sys

#  Banks holding at least one register whose READ consumes.
CONSUMING = {"I2C0", "I2C1", "RMT", "SDHOST",
             "UART0", "UART1", "UART2", "USB_DEVICE"}

#  svd2ada emits the "with" line at either 3 or 5 spaces of indent, so the
#  indent is captured and the added aspects are lined up under "Import".
decl = re.compile(
    r"^(   (\w+)_Periph : aliased \w+_Peripheral\n"
    r"( +)with Import, Address => \w+_Base);$",
    re.M)

def replace(match):
    pad = " " * (len(match.group(3)) + len("with "))
    reads = "True" if match.group(2) in CONSUMING else "False"
    return (match.group(1) + ", Volatile,\n"
            + pad + "Async_Readers    => True,\n"
            + pad + "Async_Writers    => True,\n"
            + pad + "Effective_Reads  => " + reads + ",\n"
            + pad + "Effective_Writes => True;")

files = objects = 0
for path in sorted(glob.glob(sys.argv[1] + "/*.ads")):
    src = open(path, encoding="utf-8").read()
    out, n = decl.subn(replace, src)
    if n:
        open(path, "w", encoding="utf-8").write(out)
        files += 1
        objects += n

#  Every bank must end up annotated: a missed one silently reverts to the
#  all-True default, which is exactly what this step exists to refine.
#  Counted over the final text rather than over the substitutions, so a re-run
#  on an already annotated tree is a no-op and not an error.
declared = annotated = 0
for path in glob.glob(sys.argv[1] + "/*.ads"):
    text = open(path, encoding="utf-8").read()
    declared += text.count("_Periph : aliased")
    annotated += text.count("Effective_Writes => True;")
if annotated != declared:
    sys.exit("[regen] ERROR: %d of %d peripheral objects annotated -- the "
             "declaration shape svd2ada emits has changed"
             % (annotated, declared))
print("[regen] annotated %d peripheral objects in %d files for SPARK "
      "(%d already annotated)" % (objects, files, declared - objects))
ANNOT

# svd2ada flattens the SVD's Apache-2.0 header onto a single line.  Apache-2.0
# requires the notice be retained; re-expand it to a readable comment block (the
# license obligation is unchanged either way -- this is purely cosmetic).
python3 - "$HERE/svd" <<'PY'
import glob, sys, re
def tidy(year):
    return f"""--  Copyright {year} Espressif Systems (Shanghai) PTE LTD
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License."""
# Match the flattened one-line header for any copyright year.
flat = re.compile(r"^--  Copyright (\d{4}) Espressif Systems .*limitations under the License\.$")
n = 0
for f in glob.glob(sys.argv[1] + "/*.ads"):
    lines = open(f, encoding="utf-8").read().split("\n")
    out = []
    for l in lines:
        m = flat.match(l)
        out.append(tidy(m.group(1)) if m else l)
    if out != lines:
        open(f, "w", encoding="utf-8").write("\n".join(out)); n += 1
print(f"[regen] tidied the Apache header in {n} file(s)")
PY
