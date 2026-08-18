#!/bin/bash
# Prove the guide's Ada is real.
#
# Two passes, both cheap enough to run on every doc change:
#
#   1. COMPILE  every unit in samples/ against the embedded runtime, with the
#      HAL on the source path.  These files ARE the code the guide shows --
#      build.py inlines them -- so a sample that stops compiling is a page that
#      is lying.  Semantic check only (-gnatc): no link, no board, no binder.
#
#   2. QUOTE-CHECK the API names the driver pages mention against the HAL specs,
#      so a renamed subprogram surfaces as a failing check rather than as a
#      reader's confusing afternoon.
#
# Needs the cross toolchain and a generated runtime -- i.e. anything that has
# already built one example.  Exits non-zero on the first failure.
#
#   ./docs/check_samples.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"            # docs/
SITE="$HERE/adaformicrocontrollers.com"        # only the published files
REPO="$(cd "$HERE/.." && pwd)"
HAL="$REPO/libs/esp32s3_hal"
RTS="$REPO/crates/esp32s3_rts/embedded-esp32s3"

fail () { printf '\n\033[31mFAIL\033[0m  %s\n' "$*" >&2; exit 1; }

# ---- locate the cross compiler + the dynconfig plugin the Xtensa back end needs
GCC="$(command -v xtensa-esp32-elf-gcc || true)"
if [ -z "$GCC" ]; then
    GCC="$(ls -d "$HOME"/.local/share/alire/toolchains/gnat_xtensa_esp32_elf_*/bin/xtensa-esp32-elf-gcc 2>/dev/null | head -1)"
fi
[ -x "${GCC:-}" ] || fail "xtensa-esp32-elf-gcc not found (run any example's ./build.sh once, or source export.sh)"

if [ -z "${XTENSA_GNU_CONFIG:-}" ]; then
    XTENSA_GNU_CONFIG="$(find "$REPO/crates/xtensa-dynconfig" -name 'xtensa_esp32s3.so' 2>/dev/null | head -1)"
    export XTENSA_GNU_CONFIG
fi
[ -f "${XTENSA_GNU_CONFIG:-}" ] || fail "xtensa_esp32s3.so not built -- build any example once first"

[ -d "$RTS" ] || fail "no embedded runtime at $RTS -- build an embedded example once (e.g. ./x build i2c_loopback)"

# ---- pass 1: compile every sample -------------------------------------------
echo "== compiling docs/samples against the embedded runtime =="
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$HERE"/samples/*.ad? "$WORK"/

rc=0
for f in "$WORK"/*.adb "$WORK"/*.ads; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    #  A spec with a matching body is compiled via the body.
    if [ "${base##*.}" = "ads" ] && [ -e "${f%.ads}.adb" ]; then continue; fi
    if out=$("$GCC" -c -gnatc --RTS="$RTS" -I"$WORK" -I"$HAL/src" -I"$HAL/svd" "$f" 2>&1); then
        printf '  ok    %s\n' "$base"
    else
        printf '  ERROR %s\n%s\n' "$base" "$out"
        rc=1
    fi
done
[ $rc -eq 0 ] || fail "a guide sample does not compile (see above)"

# ---- pass 2: the API names the pages quote must still exist ------------------
echo "== checking quoted API names against the HAL specs =="
python3 - "$SITE" "$HAL" <<'PY' || exit 1
import sys, os

here, hal = sys.argv[1], sys.argv[2]

#  An explicit manifest, deliberately: scraping identifiers out of the HTML
#  drags in Ada keywords, project-file attributes, names from OTHER packages and
#  the samples' own locals, and a check that cries wolf is a check somebody
#  disables.  This says "these pages document these names" -- a floor, not a
#  ceiling.  Add a name when a page starts documenting it.
#
#      page          spec(s) it documents            names it must still find
MANIFEST = [
    ("13-gpio.html", ["esp32s3-gpio.ads", "esp32s3-gpio-interrupts.ads"], """
        Pad_Number No_Pin Pin_Id Optional_Pin Pin_Mode Pull_Mode Drive_Strength
        Drive_Weak Drive_Medium Drive_Strong Drive_Strongest Configure Toggle
        Trigger Rising_Edge Falling_Edge Any_Edge Low_Level High_Level
        Callback Enable Disable Read Write Set Clear"""),

    ("14-i2c.html", ["esp32s3-i2c.ads"], """
        I2C_Host I2C0 I2C1 Slave_Address Byte_Array Max_Transfer Session
        Is_Held Setup Configure_Pins Not_Initialized Not_Owned Acquire
        Write Read Write_Read Release Check_Ack Engine"""),

    ("15-spi.html", ["esp32s3-spi.ads", "esp32s3-gdma.ads"], """
        SPI_Host SPI2 SPI3 SPI_Mode CS_Select Select_Device Set_Clock
        Enable_Loopback Transfer Setup Configure_Pins Acquire Release Is_Held
        Not_Initialized Not_Owned Clock_Hz CS_Pin Select_CB Ctx
        DMA_Buffer DMA_Alignment Assertion_Policy"""),

    ("16-uart.html", ["esp32s3-uart.ads"], """
        UART_Port UART0 UART1 UART2 Baud_Rate Data_Bits Parity_Mode Stop_Bits
        Rx_Buffer_Access Enable_Buffered_Rx Acquire Reconfigure Set_Baud
        Set_Data_Bits Set_Parity Set_Stop_Bits Set_Inversion Configure_Pins
        Repair_Rx Available Write Read Release Enable_Loopback
        Rx_Flow_Threshold Byte_Array Session"""),
]

bad = []
for page, specs, names in MANIFEST:
    page_path = os.path.join(here, page)
    if not os.path.exists(page_path):
        bad.append("%s is missing -- regenerate with build.py" % page)
        continue
    html = open(page_path).read()
    spec_src = "".join(open(os.path.join(hal, "src", s)).read() for s in specs)
    for n in names.split():
        if n not in spec_src:
            bad.append("%s documents '%s', which no longer exists in %s"
                       % (page, n, ", ".join(specs)))
        elif n not in html:
            bad.append("%s no longer mentions '%s' (page rewritten? update the manifest)"
                       % (page, n))

if bad:
    print("\n".join("  " + b for b in bad))
    sys.exit(1)
print("  ok    every documented API name still exists in the specs")
PY

# ---- pass 3: the generated HTML is well-formed ------------------------------
#  A bare "&" in a page title reaches every sidebar and pager on every page, so
#  one careless nav= string is 200 broken entities.  It has happened twice.
echo "== validating the generated HTML =="
python3 - "$SITE" <<'PYHTML' || exit 1
import glob, os, re, sys, html.parser

here = sys.argv[1]

class Tags(html.parser.HTMLParser):
    VOID = {"meta", "link", "br", "img", "hr", "input"}
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack, self.err = [], []
    def handle_starttag(self, tag, attrs):
        if tag not in self.VOID:
            self.stack.append(tag)
    def handle_endtag(self, tag):
        if not self.stack:
            self.err.append("stray </%s>" % tag)
        elif self.stack[-1] != tag:
            self.err.append("expected </%s>, got </%s> at line %d"
                            % (self.stack[-1], tag, self.getpos()[0]))
        else:
            self.stack.pop()

bad = []
pages = sorted(glob.glob(os.path.join(here, "*.html")))
if not pages:
    bad.append("no generated pages -- run build.py")

for path in pages:
    name = os.path.basename(path)
    src = open(path).read()
    t = Tags(); t.feed(src)
    for e in t.err:
        bad.append("%s: %s" % (name, e))
    if t.stack:
        bad.append("%s: unclosed %s" % (name, ", ".join(t.stack)))
    for m in re.finditer(r"&(?!#?\w+;)", src):
        ctx = src[max(0, m.start() - 40):m.start() + 15].replace("\n", " ")
        bad.append("%s: bare '&' -- ...%s..." % (name, ctx))
    #  Numbering drift: a page's filename must agree with the step number it
    #  prints, and a routing-table row's number must agree with the slug it
    #  links to.  Renumbering has silently desynchronised both before.
    m = re.match(r"(\d+)-", name)
    step = re.search(r"Step (\d+) of (\d+)", src)
    if m and step and m.group(1) != step.group(1):
        bad.append("%s: filename says step %s, page says step %s"
                   % (name, m.group(1), step.group(1)))
    for row in re.finditer(r'<tr><td>(\d+)</td><td><a href="(\d+)-', src):
        if row.group(1) != row.group(2):
            bad.append("%s: table row numbered %s links to step %s"
                       % (name, row.group(1), row.group(2)))

    for attr in ("href", "src"):
        for m in re.finditer(r'%s="([^"]+)"' % attr, src):
            ref = m.group(1)
            if ref.startswith(("http", "data:", "#")):
                continue
            if not os.path.exists(os.path.join(here, ref.split("#")[0])):
                bad.append("%s: dead %s %s" % (name, attr, ref))

if bad:
    print("\n".join("  " + b for b in bad[:25]))
    if len(bad) > 25:
        print("  ... and %d more" % (len(bad) - 25))
    sys.exit(1)
print("  ok    %d pages: tags balanced, entities escaped, links resolve, numbering consistent" % len(pages))
PYHTML

printf '\n\033[32mPASS\033[0m  the guide compiles, its API is current, and the HTML is sound\n'
