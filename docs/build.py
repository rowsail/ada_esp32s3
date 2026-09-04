#!/usr/bin/env python3
"""Generate the static "Bare-Metal Ada on the ESP32-S3" step-by-step guide.

The deliverable is the plain .html files this writes next to it; this script
exists only so the sidebar table of contents and the prev/next links stay
consistent across every page.  Edit the prose below, then:

    python3 docs/build.py

Each page's prose is a plain HTML fragment in pages/<slug>.html; this file holds
only the page TABLE (slug, sidebar title, page title, standfirst) and the
template, which is what has to stay consistent across pages.  To edit wording,
open pages/<slug>.html; to add or reorder a page, edit PAGES below and add the
matching pages/<slug>.html.  Then:

    python3 docs/build.py

Everything is self-contained: no dependencies, no network, one shared
stylesheet (style.css), no JavaScript.
"""

import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))          # docs/
REPO = os.path.dirname(HERE)                              # the checkout root

#  Everything that gets PUBLISHED lives here and nothing else does, so putting
#  the site online is a plain directory copy -- no include/exclude filter to get
#  wrong.  (An earlier filter silently dropped ada.svg from the upload.)
SITE_DIR = os.path.join(HERE, "adaformicrocontrollers.com")

#  The pages' prose.  Source, not output: SITE_DIR is generated from it.
PAGES_DIR = os.path.join(HERE, "pages")

SITE = "Bare-Metal Ada on the ESP32-S3"
TAGLINE = "A step-by-step guide to running Ada on the ESP32-S3 with no ESP-IDF, no FreeRTOS, and no Python."

# --------------------------------------------------------------------------
# Pages.  slug, nav title (sidebar), page title, standfirst, body HTML.
# --------------------------------------------------------------------------

PAGES = [
    dict(slug="01-what-you-need",
         nav="What you need",
         title="What you need (and what you don't)",
         lede="One board, one USB cable, and one package manager. No ESP-IDF, no <code>idf.py</code>, no esptool, no Python anywhere in the build or flash path."),
    dict(slug="02-toolchain",
         nav="Installing the toolchain",
         title="Installing Alire and the toolchains",
         lede="One download, one <code>PATH</code> line, two <code>alr toolchain</code> commands. This is the only thing you install on your machine."),
    dict(slug="03-clone",
         nav="Getting the code",
         title="Getting the code",
         lede="Two ways in: unzip a tagged release, or clone the repository. There are no submodules to remember &mdash; whatever the older instructions say."),
    dict(slug="04-board",
         nav="Board and serial port",
         title="Plugging in the board and finding the port",
         lede="Two things go wrong here and only here: the wrong USB socket, and permissions on <code>/dev/ttyACM0</code>. Both take one minute to settle before you build anything."),
    dict(slug="05-first-blink",
         nav="Your first blink",
         title="Your first blink",
         lede="One command builds a pure-Ada GPIO driver, packages a flash image, writes it over the chip's ROM bootloader, resets the board, and streams the console."),
    dict(slug="06-anatomy",
         nav="Reset to Main",
         title="What happens between reset and Main",
         lede="Your blink worked. Here is every layer it went through, from the chip's mask ROM to the first line of your Ada &mdash; and what an RTOS would normally be doing that nothing here does."),
    dict(slug="07-build",
         nav="What a build does",
         title="What a build actually does",
         lede="Five steps from your Ada to a flashable image, and two small host tools &mdash; both written in Ada &mdash; that replace <code>esptool</code> entirely."),
    dict(slug="08-profiles",
         nav="Runtime profiles",
         title="Choosing a runtime profile",
         lede="Three runtimes ship here, from a lean Jorvik kernel to the complete Ada tasking model. Picking one is a build-time switch, and most projects want the middle option."),
    dict(slug="09-board-config",
         nav="Board configuration",
         title="Board configuration: <code>board.ads</code>",
         lede="Flash size and PSRAM size are the two things the build has to be told about your board. They live in an Ada spec at the root of each project &mdash; there is no global config, and no <code>sdkconfig</code>."),
    dict(slug="10-own-project",
         nav="Your own project",
         title="Your own project, outside the repo",
         lede="Don't edit an example. Treat the repository as an SDK: source <code>export.sh</code> once, then scaffold a self-contained project anywhere on disk, with no runtime source copied in and no paths baked into any file."),
    dict(slug="11-hal",
         nav="Talking to hardware",
         title="Talking to the hardware: the HAL",
         lede="Twenty-five-plus drivers, each a private register engine hidden behind a task-safe gateway. Here is what using one looks like, and why they are shaped the way they are."),
    dict(slug="12-examples",
         nav="The examples",
         title="The examples: all 96 of them",
         lede="Most need no wiring, most tell you PASS or FAIL, and each one is the fastest way to find out whether a peripheral works on <em>your</em> board before you write a line against it."),
    dict(slug="13-gpio",
         nav="GPIO in depth",
         title="GPIO in depth",
         lede="A pin type that refuses to name a pad which would hang the chip, three operations that are atomic in hardware, two that are not, and pin interrupts with one rule you cannot break."),
    dict(slug="14-i2c",
         nav="I2C in depth",
         title="I2C in depth",
         lede="A master you cannot use wrongly: the raw registers are unreachable, the host is owned by an RAII session that releases itself even through an exception, and payload length is not a thing you have to think about."),
    dict(slug="15-spi",
         nav="SPI in depth",
         title="SPI in depth",
         lede="One host, several devices, each with its own clock, mode and chip select &mdash; applied per hold rather than per host. Plus a DMA transfer whose alignment rules are preconditions, not comments."),
    dict(slug="16-uart",
         nav="UART in depth",
         title="UART in depth",
         lede="The one driver here with no setup call at all: you cannot touch a port you do not hold. Plus interrupt-driven RX, an Ada declaration that must be written a particular way, and a pin-routing trap."),
    dict(slug="17-gdma",
         nav="GDMA",
         title="GDMA: the DMA engine everything else borrows",
         lede="Five channel pairs, assigned at run time rather than wired per peripheral &mdash; and a buffer type whose rules exist because PSRAM is reached through a cache."),
    dict(slug="18-i2s",
         nav="I2S audio",
         title="I2S: audio that only moves by DMA",
         lede="The S3's I2S has no CPU FIFO at all &mdash; samples reach the wire only through the DMA crossbar. That single fact shapes the whole API, including gapless playback and capture that runs underneath it."),
    dict(slug="19-lcd",
         nav="LCD (i80 / RGB)",
         title="LCD: two very different display modes",
         lede="One controller, two personalities &mdash; a command-driven 8-bit i8080 bus that streams a buffer on demand, and a continuously-refreshed RGB panel that never stops."),
    dict(slug="20-twai",
         nav="TWAI (CAN)",
         title="TWAI: CAN 2.0, with the bus-off trap",
         lede="Standard and extended frames as separate types so a 29-bit identifier cannot reach an 11-bit frame &mdash; and an error state that a single-node bench setup walks straight into."),
    dict(slug="21-rmt",
         nav="RMT pulses",
         title="RMT: an arbitrary pulse generator",
         lede="Sequences of {level, duration} symbols in hardware &mdash; IR remotes, WS2812 LED strings, 1-Wire, and any timing you would otherwise bit-bang badly."),
    dict(slug="22-ledc-sdm",
         nav="LEDC &amp; sigma-delta",
         title="LEDC and sigma-delta: the simple outputs",
         lede="Eight PWM channels for dimming and clean square waves, and eight 1-bit density-modulated outputs that become analog with one resistor and one capacitor."),
    dict(slug="23-mcpwm",
         nav="MCPWM",
         title="MCPWM: PWM that can shut itself down",
         lede="Complementary outputs with dead-time so a half-bridge is never shorted, a chopper carrier, and a fault input that forces the pins safe in hardware &mdash; without waiting for your code."),
    dict(slug="24-timers-pcnt",
         nav="Timers &amp; pulse counting",
         title="Timers and pulse counting",
         lede="A 54-bit counter with an alarm, and four edge counters &mdash; the two ways to measure time and events without the CPU watching."),
    dict(slug="25-analog",
         nav="ADC &amp; touch",
         title="Analog in: the SAR ADC and capacitive touch",
         lede="Two 12-bit converters on fixed pins, and fourteen touch channels that measure a pad's capacitance by counting &mdash; both living in the RTC domain."),
    dict(slug="26-rtc",
         nav="RTC, hold &amp; deep sleep",
         title="RTC, pad hold and deep sleep",
         lede="Deep sleep is not a pause &mdash; the chip resets and re-runs from the start. What survives is RTC memory, and the pads you explicitly told to hold their level."),
    dict(slug="27-crypto",
         nav="Crypto &amp; RNG",
         title="Hardware crypto, and one honest caveat",
         lede="SHA, AES and RSA acceleration behind protected objects, MD5 for a specific non-cryptographic job &mdash; and a random number generator that is not a CSPRNG on this runtime."),
    dict(slug="28-sd",
         nav="SD cards",
         title="SD cards: two hosts, one API shape",
         lede="The universal SPI transport and the native SD bus &mdash; different speeds, different profile requirements, and the same 512-byte logical block interface."),
    dict(slug="29-chip-id",
         nav="Temperature &amp; MAC",
         title="Chip identity: die temperature and the eFuse MAC",
         lede="Two small packages that answer questions about the silicon itself &mdash; how hot it is, and what addresses the factory gave it."),
    dict(slug="30-display-touch",
         nav="Display &amp; touch",
         title="ST7789 display and GT911 touch",
         lede="A write-only SPI display that cannot be probed, and a touch controller whose I2C address depends on a pin level at reset &mdash; the two halves of a touchscreen, each with its own trap."),
    dict(slug="31-es8311",
         nav="ES8311 codec",
         title="ES8311: the audio codec",
         lede="Control over I2C, audio over I2S, and a clocking relationship you have to get right &mdash; the ESP is the master, the codec follows."),
    dict(slug="32-sensors",
         nav="IMU &amp; environment",
         title="Sensors: the QMI8658C IMU and SHT41",
         lede="One register-mapped device and one command-based device &mdash; the two shapes almost every I2C sensor takes, and how each reports that its reading is trustworthy."),
    dict(slug="33-pcf85063a",
         nav="PCF85063A RTC",
         title="PCF85063A: a clock that tells you when not to trust it",
         lede="BCD calendar registers, a programmable alarm, and one flag that answers the only question that matters after a power loss."),
    dict(slug="34-expanders",
         nav="Port expanders",
         title="Port expanders: TCA9555, CH422G and HC595",
         lede="Three ways to buy more pins, and three quite different bargains &mdash; per-pin control, an all-or-nothing direction bit, and a shift register with no readback at all."),
    dict(slug="35-tx1812",
         nav="TX1812 LEDs",
         title="TX1812: addressable LEDs from RMT symbols",
         lede="A single-wire LED family driven by generating its pulse train in hardware &mdash; and a strip whose whole memory footprint is fixed at elaboration."),
    dict(slug="36-memory",
         nav="Flash, EEPROM &amp; FRAM",
         title="Off-chip memory: NOR flash, EEPROM and FRAM",
         lede="Three non-volatile technologies with three different bargains &mdash; and a family catalogue that turns a whole product line into one shared driver plus a geometry."),
    dict(slug="37-tlv2556",
         nav="TLV2556 ADC",
         title="TLV2556: a pipelined external ADC",
         lede="Twelve bits and eleven channels over SPI &mdash; where the result you read belongs to the channel you asked for <em>last</em> time."),
    dict(slug="38-gps",
         nav="GPS receiver",
         title="GPS: a background service, not a device handle",
         lede="The one driver here you do not poll through a handle. A task owns the UART, decodes NMEA continuously, and publishes into a protected store that timestamps its own staleness."),
    dict(slug="39-w5500",
         nav="W5500 Ethernet",
         title="W5500: Ethernet with the stack on the chip",
         lede="A hardwired TCP/IP controller with eight hardware sockets &mdash; and a layered driver that ends up looking like GNAT.Sockets."),
    dict(slug="40-net-stack",
         nav="The network stack",
         title="The chip-neutral network stack",
         lede="One <code>GNAT.Sockets</code> subset, several possible NICs, and a routing table that fails traffic over when a link drops &mdash; so networking code does not name the hardware carrying it."),
    dict(slug="41-dns-ntp",
         nav="DNS &amp; NTP",
         title="DNS and NTP: portable by construction",
         lede="Two clients written entirely against <code>GNAT.Sockets</code>, so the same source runs on a desktop and on the board &mdash; and one shared concurrency wrinkle worth knowing."),
    dict(slug="42-tls",
         nav="TLS 1.3",
         title="TLS 1.3, in Ada, with no C library",
         lede="A complete client handshake &mdash; ECDHE, AEAD, certificate chain validation to a pinned root, and session resumption &mdash; with every line of crypto in Ada or the chip's own accelerators."),
    dict(slug="43-wifi",
         nav="Wi-Fi",
         title="Wi-Fi: pure Ada around three binary blobs",
         lede="The one place the from-scratch claim has an asterisk &mdash; and the asterisk is smaller, and better fenced, than you would expect."),
    dict(slug="44-modbus",
         nav="Modbus TCP",
         title="Modbus TCP: master and slave",
         lede="An industrial protocol on the socket facade &mdash; and a library that deliberately owns none of your data."),
    dict(slug="45-ftp",
         nav="FTP",
         title="FTP: client and server",
         lede="Outbound-only transfers streamed through a callback, and an anonymous server that exposes your filesystems to a desktop &mdash; both on the socket facade."),
    dict(slug="46-block-dev",
         nav="Block devices &amp; wear levelling",
         title="Block devices and wear levelling",
         lede="One abstraction the filesystems talk to, thin adapters underneath it, and a filter in the middle that stops a hot metadata block from killing one sector of your flash."),
    dict(slug="47-ext4",
         nav="ext4 filesystem",
         title="ext4: a real filesystem, in Ada",
         lede="A from-scratch ext2/3/4 implementation with JBD2 journal replay, an on-device formatter, and an error model that is simply Ada's."),
    dict(slug="48-fat16",
         nav="FAT16",
         title="FAT16: the filesystem a PC can read",
         lede="Deliberately narrow &mdash; read-only, FAT16 only, long filenames supported &mdash; because its whole job is being mountable by an operating system you do not control."),
    dict(slug="49-console-fonts",
         nav="Console, text &amp; fonts",
         title="Console output, text and fonts",
         lede="There is no <code>Ada.Text_IO</code> console on this target, so printing a number is a design decision &mdash; and drawing a glyph is a separate one that knows nothing about your panel."),
    dict(slug="50-esp-loader",
         nav="Programming another ESP32",
         title="Esp_Loader: your board as the programmer",
         lede="The ESP32 serial ROM protocol spoken as the <em>host</em>, so a jig or a product can flash another ESP32 &mdash; and none of them should have to run Python."),
    dict(slug="51-simd",
         nav="SIMD (PIE)",
         title="SIMD: the PIE vector unit",
         lede="128-bit vector kernels with the inner loops written as GNAT inline assembly &mdash; vendored, experimental, and honest about it."),
    dict(slug="52-stack-usage",
         nav="Stack measurement",
         title="Stack usage: measuring what analysis cannot see",
         lede="Static worst-case analysis cannot see the prebuilt runtime, the C startup, ISRs or hand-written assembly. Painting the stack can."),
    dict(slug="53-testing",
         nav="Testing &amp; proof",
         title="Testing and proof: reproducing the claims",
         lede="Thirty-two harnesses run on your PC, not the board. Half check behaviour against the host's own tools; half prove absence of run-time errors outright."),
    dict(slug="54-runtime",
         nav="The runtime itself",
         title="The runtime: how it is built, ported and proven conformant",
         lede="Three profiles generated from a forked bb-runtimes board, a porting checklist that is shorter than you would expect &mdash; and an ACATS sweep that grades the result one test per image."),
    dict(slug="55-debugging",
         nav="Debugging",
         title="Debugging: GDB over the same cable",
         lede="The USB-Serial-JTAG port is both the console and a JTAG debug interface, so one cable gets you breakpoints, both cores as GDB threads, and a live halt on a hung board."),
    dict(slug="56-troubleshooting",
         nav="Troubleshooting &amp; next steps",
         title="Troubleshooting, and where to go next",
         lede="The failure modes worth recognising on sight, a one-screen cheat sheet, and the parts of the project to read once the board is blinking."),
]


#  Each page's BODY lives in pages/<slug>.html, not in this file.  The prose is
#  the bulk of the guide -- this table used to carry ~5,000 lines of it as Python
#  string literals, which meant every wording change was a diff against a .py,
#  no editor knew it was HTML, and the metadata that this script actually exists
#  to keep consistent (the sidebar order, the prev/next chain) was buried in it.
#  Metadata here, prose next door.
def load_bodies():
    for page in PAGES:
        path = os.path.join(PAGES_DIR, page["slug"] + ".html")
        if not os.path.exists(path):
            raise SystemExit("build.py: no body for page %r (expected %s)"
                             % (page["slug"], path))
        with open(path, encoding="utf-8") as f:
            page["body"] = f.read()

    #  A body file with no page is a page somebody removed from PAGES and left
    #  on disk, or a slug typo -- either way it would silently never publish.
    known = {p["slug"] + ".html" for p in PAGES}
    orphans = sorted(f for f in os.listdir(PAGES_DIR)
                     if f.endswith(".html") and f not in known)
    if orphans:
        raise SystemExit("build.py: pages/ has files no page claims: %s"
                         % ", ".join(orphans))

# --------------------------------------------------------------------------
# Template
# --------------------------------------------------------------------------

CSS = """/* Bare-Metal Ada on the ESP32-S3 -- shared stylesheet.
   Light and dark, one set of custom properties, no JavaScript. */

:root {
  --bg:        #fbfbf9;
  --panel:     #f3f2ee;
  --fg:        #1d1f21;
  --fg-muted:  #5c6066;
  --fg-faint:  #8b9096;
  --rule:      #e0dfd9;
  --rule-soft: #ebeae5;
  --accent:    #9a3412;
  --accent-bg: #fdf1ea;
  --code-bg:   #f4f3ef;
  --code-fg:   #24292f;
  --note-bg:   #f1f5f9;
  --note-edge: #64748b;
  --warn-bg:   #fdf4e7;
  --warn-edge: #b45309;
  --mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas,
          "Liberation Mono", monospace;
  --sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
          "Helvetica Neue", Arial, sans-serif;
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg:        #16181c;
    --panel:     #1c1f24;
    --fg:        #e3e5e8;
    --fg-muted:  #a2a8b0;
    --fg-faint:  #767d86;
    --rule:      #2b2f36;
    --rule-soft: #23262c;
    --accent:    #f0a882;
    --accent-bg: #2a1d17;
    --code-bg:   #1b1e23;
    --code-fg:   #dfe2e6;
    --note-bg:   #1a2028;
    --note-edge: #7c8ba1;
    --warn-bg:   #241d13;
    --warn-edge: #d08b2c;
  }
}

* { box-sizing: border-box; }

html { -webkit-text-size-adjust: 100%; }

body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: var(--sans);
  font-size: 17px;
  line-height: 1.65;
}

a { color: var(--accent); text-decoration-thickness: 1px; text-underline-offset: 2px; }
a:hover { text-decoration-thickness: 2px; }

/* ---- masthead ---- */

.masthead {
  border-bottom: 1px solid var(--rule);
  background: var(--panel);
}
.masthead-inner {
  max-width: 1120px;
  margin: 0 auto;
  padding: 1.1rem 1.5rem;
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.35rem 1rem;
}
.masthead-inner a.brand {
  display: inline-flex;
  align-items: center;
  gap: 0.55rem;
  font-weight: 650;
  font-size: 1.02rem;
  color: var(--fg);
  text-decoration: none;
  letter-spacing: -0.01em;
}
.masthead-inner a.brand:hover { color: var(--accent); }

/* The Ada mascot is drawn with black outlines, which disappear on a dark
   ground.  Inverting lightness and rotating the hue back keeps the blues
   roughly themselves while lifting the linework off the background. */
.logo { display: block; width: 30px; height: 30px; flex: none; }
@media (prefers-color-scheme: dark) {
  .logo { filter: invert(1) hue-rotate(180deg); }
}
.masthead .tagline {
  color: var(--fg-faint);
  font-size: 0.82rem;
}

/* ---- layout ---- */

.wrap {
  max-width: 1120px;
  margin: 0 auto;
  padding: 2.4rem 1.5rem 4rem;
  display: grid;
  grid-template-columns: 15.5rem minmax(0, 1fr);
  gap: 3rem;
  align-items: start;
}
/* The nav comes AFTER main in the source (so narrow screens get the article
   first); place it explicitly to keep it on the left here. */
.wrap > .toc  { grid-column: 1; grid-row: 1; }
.wrap > main  { grid-column: 2; grid-row: 1; }

/* ---- sidebar ---- */

.toc {
  position: sticky;
  top: 2rem;
  font-size: 0.88rem;
  /* 45 steps is taller than most viewports, and a sticky element that
     overflows simply clips -- the last entries become unreachable.  Bound it
     to the visible height and let it scroll on its own. */
  max-height: calc(100vh - 4rem);
  overflow-y: auto;
  overscroll-behavior: contain;   /* don't chain to the page at either end */
  scrollbar-width: thin;
  scrollbar-color: var(--rule) transparent;
  padding-right: 0.35rem;         /* room for the bar, so it can't cover text */
}
/* WebKit/Blink: match the slim, low-contrast Firefox treatment above. */
.toc::-webkit-scrollbar { width: 8px; }
.toc::-webkit-scrollbar-track { background: transparent; }
.toc::-webkit-scrollbar-thumb {
  background: var(--rule);
  border-radius: 4px;
}
.toc:hover::-webkit-scrollbar-thumb { background: var(--fg-faint); }
.toc h2 {
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.09em;
  color: var(--fg-faint);
  margin: 0 0 0.7rem;
  font-weight: 650;
}
.toc > ol { list-style: none; margin: 0; padding: 0; }
.toc ol { list-style: none; margin: 0; padding: 0; }

/* Collapsible sections.  The step counter lives on the OUTER list so numbering
   stays continuous across groups -- a closed group must not renumber the ones
   after it. */
.toc-group { margin: 0 0 0.15rem; }
.toc details > summary {
  list-style: none;                 /* replace the default marker below */
  cursor: pointer;
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
  padding: 0.3rem 0.2rem;
  font-size: 0.78rem;
  font-weight: 650;
  letter-spacing: 0.02em;
  color: var(--fg-muted);
  border-radius: 4px;
  user-select: none;
}
.toc details > summary::-webkit-details-marker { display: none; }
.toc details > summary::before {
  content: "▸";                 /* literal glyph: a CSS hex escape here would be eaten as octal by Python */
  font-size: 0.7em;
  color: var(--fg-faint);
  transition: transform 0.12s ease;
}
.toc details[open] > summary::before { transform: rotate(90deg); }
.toc details > summary:hover { background: var(--rule-soft); color: var(--fg); }
.toc-range {
  margin-left: auto;
  font-family: var(--mono);
  font-size: 0.9em;
  font-weight: 400;
  color: var(--fg-faint);
}
.toc details li { margin: 0; }
.toc > ol > li { margin: 0; }
.toc ol a {
  display: block;
  padding: 0.3rem 0.55rem 0.3rem 2.1rem;
  text-indent: -1.55rem;
  color: var(--fg-muted);
  text-decoration: none;
  border-left: 2px solid transparent;
  border-radius: 0 3px 3px 0;
}
.toc ol a::before {
  content: attr(data-step);
  color: var(--fg-faint);
  font-family: var(--mono);
  font-size: 0.78em;
  margin-right: 0.6rem;
}
.toc ol a:hover { color: var(--fg); background: var(--rule-soft); }
.toc li.current > a {
  color: var(--accent);
  font-weight: 600;
  border-left-color: var(--accent);
  background: var(--accent-bg);
}
.toc li.current > a::before { color: var(--accent); }
.toc .home {
  display: block;
  margin-bottom: 1.1rem;
  padding-bottom: 0.9rem;
  border-bottom: 1px solid var(--rule);
  color: var(--fg-muted);
  text-decoration: none;
  font-size: 0.85rem;
}
.toc .home:hover { color: var(--accent); }

/* ---- article ---- */

main { min-width: 0; max-width: 44rem; }

.eyebrow {
  font-family: var(--mono);
  font-size: 0.76rem;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--fg-faint);
  margin: 0 0 0.5rem;
}

h1 {
  font-size: 2.05rem;
  line-height: 1.18;
  letter-spacing: -0.02em;
  margin: 0 0 0.85rem;
  font-weight: 680;
}
h1 code { font-size: 0.92em; background: none; padding: 0; }

.lede {
  font-size: 1.12rem;
  line-height: 1.55;
  color: var(--fg-muted);
  margin: 0 0 2rem;
  padding-bottom: 1.6rem;
  border-bottom: 1px solid var(--rule);
}

h2 {
  font-size: 1.24rem;
  letter-spacing: -0.01em;
  margin: 2.4rem 0 0.7rem;
  font-weight: 650;
}

p, ul, ol, table { margin: 0 0 1.1rem; }
li { margin: 0.28rem 0; }
ul, ol { padding-left: 1.4rem; }

code {
  font-family: var(--mono);
  font-size: 0.87em;
  background: var(--code-bg);
  padding: 0.12em 0.34em;
  border-radius: 3px;
}

pre {
  background: var(--code-bg);
  color: var(--code-fg);
  border: 1px solid var(--rule);
  border-radius: 6px;
  padding: 0.95rem 1.1rem;
  overflow-x: auto;
  margin: 0 0 1.3rem;
  line-height: 1.5;
}
pre code {
  background: none;
  padding: 0;
  font-size: 0.845rem;
  white-space: pre;
}

kbd {
  font-family: var(--mono);
  font-size: 0.8em;
  border: 1px solid var(--rule);
  border-bottom-width: 2px;
  border-radius: 4px;
  padding: 0.08em 0.4em;
  background: var(--panel);
}

.table-scroll { overflow-x: auto; margin: 0 0 1.3rem; }

table {
  border-collapse: collapse;
  width: 100%;
  font-size: 0.93rem;
}
th, td {
  text-align: left;
  vertical-align: top;
  padding: 0.55rem 0.8rem 0.55rem 0;
  border-bottom: 1px solid var(--rule-soft);
}
th {
  font-size: 0.74rem;
  text-transform: uppercase;
  letter-spacing: 0.07em;
  color: var(--fg-faint);
  border-bottom: 1px solid var(--rule);
  font-weight: 650;
}
td code { font-size: 0.85em; }

/* ---- callouts ---- */

p.note, p.warn {
  padding: 0.85rem 1.05rem;
  border-left: 3px solid;
  border-radius: 0 5px 5px 0;
  font-size: 0.95rem;
  margin: 0 0 1.3rem;
}
p.note { background: var(--note-bg); border-color: var(--note-edge); }
p.warn { background: var(--warn-bg); border-color: var(--warn-edge); }

p.next-hint {
  color: var(--fg-faint);
  font-style: italic;
  font-size: 0.95rem;
}

/* ---- pager ---- */

.pager-top {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  font-size: 0.84rem;
  margin-bottom: 1.6rem;
}
.pager-top a { color: var(--fg-muted); text-decoration: none; }
.pager-top a:hover { color: var(--accent); }

.pager {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  margin-top: 3.2rem;
  padding-top: 1.8rem;
  border-top: 1px solid var(--rule);
}
.pager a {
  display: block;
  padding: 0.85rem 1rem;
  border: 1px solid var(--rule);
  border-radius: 6px;
  text-decoration: none;
  color: var(--fg);
  background: var(--panel);
}
.pager a:hover { border-color: var(--accent); }
.pager .dir {
  display: block;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--fg-faint);
  margin-bottom: 0.18rem;
}
.pager .name { font-weight: 600; font-size: 0.96rem; line-height: 1.3; }
.pager .next { text-align: right; grid-column: 2; }
.pager .prev { grid-column: 1; }

/* ---- index page ---- */

.index-list { list-style: none; padding: 0; counter-reset: step; margin: 0; }
.index-list li {
  counter-increment: step;
  border-bottom: 1px solid var(--rule-soft);
  padding: 0.95rem 0;
  margin: 0;
}
.index-list a {
  font-size: 1.06rem;
  font-weight: 600;
  text-decoration: none;
  color: var(--fg);
}
.index-list a:hover { color: var(--accent); }
.index-list a::before {
  content: counter(step, decimal-leading-zero);
  font-family: var(--mono);
  font-size: 0.78em;
  font-weight: 400;
  color: var(--fg-faint);
  margin-right: 0.85rem;
}
.index-list p { margin: 0.2rem 0 0 2.65rem; color: var(--fg-muted); font-size: 0.95rem; }

.start-cta {
  display: inline-block;
  margin: 0.4rem 0 2rem;
  padding: 0.6rem 1.15rem;
  background: var(--accent);
  color: var(--bg);
  border-radius: 6px;
  font-weight: 600;
  text-decoration: none;
  font-size: 0.95rem;
}
.start-cta:hover { opacity: 0.88; }

footer.site {
  border-top: 1px solid var(--rule);
  margin-top: 3rem;
  padding-top: 1.2rem;
  color: var(--fg-faint);
  font-size: 0.82rem;
}

/* ---- narrow screens ---- */

@media (max-width: 860px) {
  body { font-size: 16px; }
  .wrap {
    grid-template-columns: minmax(0, 1fr);
    gap: 2rem;
    padding: 1.6rem 1.15rem 3rem;
  }
  .wrap > .toc, .wrap > main { grid-column: 1; grid-row: auto; }
  .toc {
    position: static;
    margin-top: 2.5rem;
    border-top: 1px solid var(--rule);
    padding-top: 1.4rem;
    background: var(--panel);
    border: 1px solid var(--rule);
    border-radius: 8px;
    padding: 1rem 1.1rem;
    max-height: none;      /* a static panel must not scroll inside itself */
    overflow-y: visible;
  }
  main { max-width: none; }
  h1 { font-size: 1.65rem; }
  .lede { font-size: 1.03rem; }
  .pager { grid-template-columns: 1fr; }
  .pager .next, .pager .prev { grid-column: 1; text-align: left; }
}
"""

PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title_text} &middot; {site}</title>
<meta name="description" content="{desc}">
<link rel="stylesheet" href="style.css">
</head>
<body>

<header class="masthead">
  <div class="masthead-inner">
    <a class="brand" href="index.html"><img class="logo" src="ada.svg" alt="" width="30" height="30">{site}</a>
    <span class="tagline">{tagline}</span>
  </div>
</header>

<div class="wrap">

  <main>
{content}
  </main>

  <!-- After <main> in the source on purpose: on a narrow screen the nav then
       falls BELOW the article instead of pushing it off the first screen.  On
       wide screens the grid placement below puts it back on the left. -->
  <nav class="toc" aria-label="Guide contents">
    <a class="home" href="index.html">&larr; Guide home</a>
    <h2>The steps</h2>
    <ol>
{toc}
    </ol>
  </nav>

</div>

</body>
</html>
"""

INDEX_BODY = """
    <p class="eyebrow">Start here</p>
    <h1>{site}</h1>
    <p class="lede">{tagline} Fifty-six short steps, one aspect each, from a
    blank machine to your own Ada application running on both cores.</p>

    <p>The ESP32-S3 is normally programmed through Espressif's ESP-IDF: a large
    C SDK, a Python build front end, and FreeRTOS underneath everything. This
    guide takes a different route. The runtime here owns both cores &mdash; the
    context switch, the interrupt vectors, the clock tick, the SMP scheduler and
    the inter-core interrupt are all its own, written in Ada and a little Xtensa
    assembly. FreeRTOS never runs; its scheduler is not even linked. The
    toolchain you install is one package manager.</p>

    <p>Each page below covers exactly one thing, and each links to the next.
    Steps 1 to 5 get an LED blinking. Steps 6 to 9 explain what you just did and
    how to configure it. Steps 10 and 11 are your own project and the driver
    library, and step 12 catalogues the 96 examples. Steps 13 to 29 are the
    chip's own peripherals and 30 to 39 the
    external devices the SDK drives &mdash; start with whichever your board
    actually has. Steps 40 to 45 are the networking stack, from sockets up
    through TLS and Wi-Fi, and 46 to 52 the storage, filesystems and standalone
    tools. Steps 53 and 54 are the test harnesses and the runtime itself, and
    55 and 56 the debugger and what to do when something goes wrong.</p>

    <p>The SDK lives at
    <a href="https://github.com/rowsail/ada_esp32s3">github.com/rowsail/ada_esp32s3</a>.
    Grab it as a <a href="https://github.com/rowsail/ada_esp32s3/releases">tagged
    release archive</a> or clone it &mdash; <a href="03-clone.html">step 3</a>
    covers both. The same release page carries <strong><em>Bare-Metal Ada on the
    ESP32-S3</em></strong>, the book: this guide gets you running and explains
    each driver, while the book is the long-form design write-up behind it.</p>

    <a class="start-cta" href="01-what-you-need.html">Begin with step 01 &rarr;</a>

    <h2>Contents</h2>
    <ol class="index-list">
{items}
    </ol>

    <footer class="site">
      <p>Drawn from the project's own <code>QUICKSTART.md</code>,
      <code>TOOLING.md</code>, and the book in <code>book/</code>. Where this
      guide and the source repository disagree, the repository is right.</p>
    </footer>
"""

BLURBS = {
    "01-what-you-need":   "The board, the cable, the one package manager &mdash; and the four things you are not installing.",
    "02-toolchain":       "Installing Alire and selecting the cross, native and build toolchains.",
    "03-clone":           "Cloning the repository with its two submodules, and what is in the tree.",
    "04-board":           "The native USB port, the device node, serial permissions, and forcing download mode.",
    "05-first-blink":     "One command builds, flashes and monitors a pure-Ada GPIO driver at 2&nbsp;Hz.",
    "06-anatomy":         "Every layer between the mask ROM and your first line of Ada, and why <code>Main</code> can be empty.",
    "07-build":           "The five build steps, and the two Ada host tools that replace esptool.",
    "08-profiles":        "light-tasking, embedded, full &mdash; what each gives you and which to pick.",
    "09-board-config":    "Flash and PSRAM size in <code>board.ads</code>, and why PSRAM size rebuilds the bootloader.",
    "10-own-project":     "Scaffolding a standalone project anywhere on disk with <code>export.sh</code> and <code>esp32-ada</code>.",
    "11-hal":             "Using the peripheral drivers, how they are shaped, and what still needs verifying on your board.",
    "12-examples":        "All 96 examples: what each shows, which profile it needs, and where it is explained.",
    "13-gpio":            "The pin type that rejects a pad which would hang the chip, what is atomic in silicon, and the interrupt callback rule.",
    "14-i2c":             "An RAII session that cannot leak the bus lock, repeated START, and why payload length never reaches your code.",
    "15-spi":             "Per-device clock and mode on a shared host, chip select three ways, and DMA rules enforced as preconditions.",
    "16-uart":            "No setup call by design, interrupt-driven RX with a buffer Ada makes you declare just so, and a routing trap.",
    "17-gdma":            "Five channel pairs claimed at run time, and the buffer rules PSRAM's cache imposes.",
    "18-i2s":             "Audio with no CPU FIFO: DMA-only transfers, gapless looping, and capture underneath playback.",
    "19-lcd":             "A command-driven i8080 bus and a continuously-refreshed RGB panel from one controller.",
    "20-twai":            "CAN 2.0 with identifier widths the type system keeps apart, and the bus-off trap.",
    "21-rmt":             "Arbitrary {level, duration} pulse trains for IR, WS2812 and 1-Wire.",
    "22-ledc-sdm":        "Eight PWM channels for dimming, and eight density-modulated outputs that filter to analog.",
    "23-mcpwm":           "Dead-time, a chopper carrier, and fault inputs that force the pins safe in hardware.",
    "24-timers-pcnt":     "A 54-bit timer with an alarm, and four edge counters that wrap sooner than you think.",
    "25-analog":          "The SAR ADC on fixed pins, and touch channels that count their way to a reading.",
    "26-rtc":             "Deep sleep resets the chip; what survives is RTC memory and the pads you held.",
    "27-crypto":          "SHA, AES and RSA acceleration, MD5 for flash verification, and why the RNG is not a CSPRNG here.",
    "28-sd":              "SPI transport versus the native SD bus, and why the faster one runs on the lean runtime.",
    "29-chip-id":         "Die temperature (not ambient) and the four factory MACs in eFuse.",
    "30-display-touch":   "A write-only SPI panel you cannot probe, and a touch chip whose address is set at reset.",
    "31-es8311":          "Control over I2C, audio over I2S, and the 256x MCLK ratio the codec depends on.",
    "32-sensors":         "A register-mapped IMU and a command-based humidity sensor, and how each flags a bad reading.",
    "33-pcf85063a":       "A typed BCD calendar, an alarm, and the oscillator-stop flag that says do not trust me.",
    "34-expanders":       "Per-pin control, an all-or-nothing direction bit, and a shift register with no readback.",
    "35-tx1812":          "LED timing generated as RMT symbols, with the strip sized at elaboration.",
    "36-memory":          "NOR flash, the 24C EEPROM catalogue and FRAM \u2014 three technologies, three bargains.",
    "37-tlv2556":         "A pipelined SPI ADC whose result belongs to the previous request.",
    "38-gps":             "A background task decoding NMEA into a protected store that timestamps its own staleness.",
    "39-w5500":           "Ethernet with the TCP/IP stack in silicon, layered up to a GNAT.Sockets facade.",
    "40-net-stack":       "One GNAT.Sockets subset over several possible NICs, with longest-prefix routing and failover.",
    "41-dns-ntp":         "DNS and NTP written against the socket facade, so the same source runs on host and board.",
    "42-tls":             "A complete TLS 1.3 client in Ada: ECDHE, chain validation to a pinned root, resumption.",
    "43-wifi":            "Pure Ada around three fetched Apache-2.0 blobs, with the WPA2 handshake kept out of them.",
    "44-modbus":          "Industrial master and slave on the socket facade, owning none of your data.",
    "45-ftp":             "Outbound-only streamed transfers, and an anonymous server over your ext4 volumes.",
    "46-block-dev":       "One vtable the filesystems talk to, and a filter that spreads flash wear.",
    "47-ext4":            "A from-scratch ext2/3/4 with JBD2 replay, on-device mkfs, and Ada exceptions.",
    "48-fat16":           "Read-only, FAT16-only, long filenames \u2014 the filesystem a PC can mount.",
    "49-console-fonts":   "Formatted output with no hosted runtime, and glyph data that knows nothing about panels.",
    "50-esp-loader":      "Your board as the programmer: the ROM protocol, streamed, with per-chip quirks handled.",
    "51-simd":            "128-bit PIE kernels in inline assembly \u2014 vendored, and honestly labelled beta.",
    "52-stack-usage":     "Stack painting: the measured counterpart to static analysis, conservative by design.",
    "53-testing":         "Thirty-two harnesses that run on your PC \u2014 cross-checked against the host's own tools, and SPARK-proven.",
    "54-runtime":         "Where the three profiles come from, the rebuild trap, porting, and the ACATS grade.",
    "55-debugging":       "OpenOCD and GDB over the same USB cable, editor integration, and decoding a Guru Meditation.",
    "56-troubleshooting": "The failure modes worth recognising on sight, a cheat sheet, and where to read next.",
}


#  Sidebar sections: (title, first step, last step).  build() checks these cover
#  PAGES exactly, so adding a page without extending a range fails loudly
#  instead of silently dropping it out of the navigation.
TOC_GROUPS = [
    ("Getting started",     1, 12),
    ("Chip peripherals",   13, 29),
    ("External devices",   30, 39),
    ("Networking",         40, 45),
    ("Storage &amp; files",    46, 48),
    ("Text &amp; tooling",     49, 52),
    ("Testing &amp; proof", 53, 54),
    ("Debugging",          55, 56),
]


#  ---------------------------------------------------------------------------
#  The examples catalogue is GENERATED from the repository, not typed out here:
#  `./x list --json` is the same source of truth the dispatcher uses, and each
#  one-line description is lifted from the example's own header comment.  So a
#  new example appears in the guide by existing, and none can silently rot.
#  ---------------------------------------------------------------------------

#  Which guide step explains the thing an example demonstrates.  Matched longest
#  prefix first, so "w5500_dns" beats "w5500".
EXAMPLE_STEP = [
    ("gpio0_blink", "13-gpio"), ("gpio", "13-gpio"),
    ("i2c", "14-i2c"), ("spi_loopback", "15-spi"), ("uart", "16-uart"),
    ("gdma", "17-gdma"), ("i2s", "18-i2s"), ("lcd", "19-lcd"),
    ("twai", "20-twai"), ("rmt", "21-rmt"),
    ("ledc", "22-ledc-sdm"), ("sdm_output", "22-ledc-sdm"),
    ("mcpwm", "23-mcpwm"), ("timer", "24-timers-pcnt"), ("pcnt", "24-timers-pcnt"),
    ("adc_read", "25-analog"), ("touch", "25-analog"),
    ("rtc", "26-rtc"), ("rtcio", "26-rtc"),
    ("crypto", "27-crypto"), ("aes", "27-crypto"), ("rsa", "27-crypto"),
    ("sparknacl", "27-crypto"), ("p256", "27-crypto"),
    ("sd_spi", "28-sd"), ("sdmmc", "28-sd"),
    ("mac", "29-chip-id"), ("temperature", "29-chip-id"),
    ("st7789", "30-display-touch"), ("gt911", "30-display-touch"),
    ("b612", "49-console-fonts"),
    ("es8311", "31-es8311"),
    ("qmi8658c", "32-sensors"), ("sht41", "32-sensors"),
    ("pcf85063a", "33-pcf85063a"),
    ("tca9555", "34-expanders"), ("ch422g", "34-expanders"), ("hc595", "34-expanders"),
    ("tx1812", "35-tx1812"),
    ("w25q", "36-memory"), ("m24c64", "36-memory"), ("fram", "36-memory"),
    ("tlv2556", "37-tlv2556"),
    ("gps", "38-gps"),
    ("w5500", "39-w5500"), ("multinic", "40-net-stack"),
    ("dns_secure", "41-dns-ntp"), ("dns", "41-dns-ntp"), ("ntp", "41-dns-ntp"),
    ("tls", "42-tls"), ("x509", "42-tls"),
    ("wifi", "43-wifi"), ("modbus", "44-modbus"),
    ("ftp", "45-ftp"),
    ("wl", "46-block-dev"), ("ext4", "47-ext4"), ("fat16", "48-fat16"),
    ("stack_usage", "52-stack-usage"), ("simd", "51-simd"),
    ("smp", "08-profiles"), ("embedded", "08-profiles"), ("full_", "08-profiles"),
    ("rendezvous", "08-profiles"), ("exceptions", "08-profiles"),
    ("heartbeat", "05-first-blink"), ("psram", "09-board-config"),
    ("heaptest", "09-board-config"),
    ("intr_levels", "55-debugging"), ("shared_l2", "55-debugging"),
    ("delay_test", "55-debugging"), ("stress", "55-debugging"),
]


def esc(t):
    return t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def example_catalogue():
    """(name, profile, description, step-slug or None) for every example.

    Reads `./x list --json` -- the dispatcher's own view -- so the guide and the
    tooling can never disagree about what exists.
    """
    import json
    import subprocess

    root = REPO
    try:
        out = subprocess.run([os.path.join(root, "x"), "list", "--json"],
                             capture_output=True, text=True, cwd=root, timeout=120)
        rows = json.loads(out.stdout)
    except Exception as exc:                      # noqa: BLE001 - report and stop
        raise SystemExit("cannot read ./x list --json (%s) -- run build.py from a"
                         " checkout with the dispatcher present" % exc)

    def tidy(text):
        """Drop the boilerplate every example repeats.

        "on the bare-metal ESP32-S3, no FreeRTOS, no IDF" is true of all 96 and
        so distinguishes none of them -- in a table where every row is an
        ESP32-S3 example it is pure column width.  Applied to BOTH sources of a
        description (the header comment and the README title), because a reader
        cannot tell which one a given row came from and should not be able to.
        """
        for noise in (
                " on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)",
                " on the bare-metal ESP32-S3 (no FreeRTOS, IDF)",
                " -- bare-metal ESP32-S3 (no FreeRTOS, no IDF)",
                " (bare-metal ESP32-S3)", " -- bare-metal ESP32-S3",
                " on the bare-metal ESP32-S3",
                " (ESP32-S3, no FreeRTOS, no IDF)",
                " for the bare-metal ESP32-S3"):
            text = text.replace(noise, "")
        text = re.sub(r"\s*\((?:ESP32-S3, )?no FreeRTOS[^)]*\)?$", "", text)
        text = re.sub(r"\s+", " ", text).strip(" ,;:-")
        return text.rstrip(".")

    def describe(d):
        """First sentence of the example's header comment, tidied.

        Header comments wrap, so one line is usually a truncated clause --
        accumulate until the sentence ends.  Then drop the boilerplate every
        example repeats ("on the bare-metal ESP32-S3, no FreeRTOS, no IDF"),
        which is true of all 96 and so distinguishes none of them.
        """
        import glob as _g

        for pat in ("src/main.adb", "src/*.adb"):
            for f in sorted(_g.glob(os.path.join(root, d, pat))):
                parts, started = [], False
                with open(f, errors="ignore") as fh:
                    for line in fh:
                        if not line.startswith("--"):
                            if line.strip() == "" and not started:
                                continue
                            break
                        t = line[2:].strip()
                        if not t or set(t) <= set("=-_ "):
                            if started:
                                break
                            continue
                        low = t.lower()
                        if not started and low.startswith(
                                ("what it demonstrates", "what this", "build",
                                 "output", "hardware")):
                            continue
                        started = True
                        parts.append(t)
                        if t.endswith("."):
                            break
                if not parts:
                    continue
                text = re.split(r"(?<=[a-z0-9)])\.\s", " ".join(parts))[0]
                return tidy(text)

        #  Some examples open straight into `with` clauses with no header
        #  comment.  Fall back to the README's title, whose shape is
        #  "# esp32s3_name -- what it is".
        readme = os.path.join(root, d, "README.md")
        if os.path.exists(readme):
            with open(readme, errors="ignore") as fh:
                head = fh.readline().lstrip("# ").strip()
            for dash in ("\u2014", "\u2013", " -- "):
                if dash in head:
                    return tidy(head.split(dash, 1)[1].strip())
            #  No dash: the whole title is the description.
            if head and not head.lower().startswith("esp32s3_"):
                return tidy(head)
        #  Left blank on purpose: these examples have neither a header comment
        #  nor a README, so there is nothing to quote.  Better an empty cell
        #  than an invented one -- the fix belongs in the example.
        return ""

    cat = []
    for r in rows:
        name = r["name"]
        step = None
        for key, slug in sorted(EXAMPLE_STEP, key=lambda kv: -len(kv[0])):
            if key in name:
                step = slug
                break
        cat.append((name, r.get("profile", ""), describe(r["dir"]), step))
    return sorted(cat)


def sample(name):
    """Inline a file from samples/ -- the same file check_samples.sh compiles.

    The guide therefore cannot show Ada that does not build: there is one copy,
    and it is the compiled one."""
    with open(os.path.join(HERE, "samples", name)) as f:
        text = f.read().rstrip("\n")
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return '<pre><code>%s</code></pre>' % text


def strip_tags(s):
    return re.sub(r"<[^>]+>", "", s)


def build():
    load_bodies()
    n = len(PAGES)
    #  Ranges must cover PAGES exactly and in order, so adding a page without
    #  extending a group fails loudly instead of vanishing from the sidebar.
    covered = []
    for _, first, last in TOC_GROUPS:
        covered.extend(range(first, last + 1))
    if covered != list(range(1, n + 1)):
        raise SystemExit("TOC_GROUPS covers %d steps but there are %d pages"
                         " -- extend a range in TOC_GROUPS" % (len(covered), n))

    def toc_html(current_slug):
        """Sidebar contents, grouped into collapsible sections.

        A flat list of 45 entries is taller than most viewports.  Bounding it
        and letting it scroll keeps every entry REACHABLE, but on a late page
        the highlighted entry then starts below the fold -- you arrive unable to
        see where you are.  Grouping fixes that with no JavaScript: <details>
        collapses the sections you are not in, and the section holding the
        current page is rendered open.
        """
        rows = []
        for title, first, last in TOC_GROUPS:
            members = PAGES[first - 1:last]
            here = any(m["slug"] == current_slug for m in members)
            #  On the index (no current page) open the first group only, so the
            #  reader sees where to start rather than a wall of closed sections.
            open_attr = " open" if here or (current_slug is None and first == 1) else ""
            rows.append('      <li class="toc-group">')
            rows.append('        <details%s>' % open_attr)
            rows.append('          <summary>%s<span class="toc-range">%d&ndash;%d</span></summary>'
                        % (title, first, last))
            rows.append('          <ol>')
            for m in members:
                cls = ' class="current"' if m["slug"] == current_slug else ""
                aria = ' aria-current="page"' if m["slug"] == current_slug else ""
                step_no = PAGES.index(m) + 1
                rows.append('            <li%s><a href="%s.html" data-step="%02d"%s>%s</a></li>'
                            % (cls, m["slug"], step_no, aria, m["nav"]))
            rows.append('          </ol>')
            rows.append('        </details>')
            rows.append('      </li>')
        return "\n".join(rows)

    # -- step pages -------------------------------------------------------
    for i, p in enumerate(PAGES):
        prev_p = PAGES[i - 1] if i > 0 else None
        next_p = PAGES[i + 1] if i < n - 1 else None

        top_prev = (
            '<a href="%s.html">&larr; %s</a>' % (prev_p["slug"], prev_p["nav"])
            if prev_p
            else '<a href="index.html">&larr; Guide home</a>'
        )
        top_next = (
            '<a href="%s.html">%s &rarr;</a>' % (next_p["slug"], next_p["nav"])
            if next_p
            else '<a href="index.html">All steps &rarr;</a>'
        )

        pager = []
        if prev_p:
            pager.append(
                '      <a class="prev" href="%s.html">'
                '<span class="dir">&larr; Previous</span>'
                '<span class="name">%s</span></a>'
                % (prev_p["slug"], prev_p["nav"])
            )
        else:
            pager.append(
                '      <a class="prev" href="index.html">'
                '<span class="dir">&larr; Back</span>'
                '<span class="name">Guide home</span></a>'
            )
        if next_p:
            pager.append(
                '      <a class="next" href="%s.html">'
                '<span class="dir">Next &rarr;</span>'
                '<span class="name">%s</span></a>'
                % (next_p["slug"], next_p["nav"])
            )
        else:
            pager.append(
                '      <a class="next" href="index.html">'
                '<span class="dir">Finished &rarr;</span>'
                '<span class="name">Back to the contents</span></a>'
            )

        body = p["body"]
        if "{{examples}}" in body:
            cat = example_catalogue()
            t = ['<div class="table-scroll">', '<table>',
                 '  <thead><tr><th>Example</th><th>Profile</th>'
                 '<th>What it shows</th><th>Step</th></tr></thead>', '  <tbody>']
            for name, prof, d, step in cat:
                link = ('<a href="%s.html">%s</a>' % (step, step.split("-")[0])
                        if step else "&mdash;")
                t.append('    <tr><td><code>%s</code></td><td><code>%s</code></td>'
                         '<td>%s</td><td>%s</td></tr>'
                         % (name, prof, esc(d), link))
            t += ['  </tbody>', '</table>', '</div>']
            body = body.replace("{{examples}}", "\n".join(t))

        content = (
            '    <nav class="pager-top">%s%s</nav>\n'
            '    <p class="eyebrow">Step %02d of %d</p>\n'
            "    <h1>%s</h1>\n"
            '    <p class="lede">%s</p>\n'
            "%s\n"
            '    <nav class="pager">\n%s\n    </nav>\n'
            % (
                top_prev,
                top_next,
                i + 1,
                n,
                p["title"],
                p["lede"],
                re.sub(r"\{\{sample:([\w.]+)\}\}",
                       lambda m: sample(m.group(1)), body).rstrip(),
                "\n".join(pager),
            )
        )

        html = PAGE.format(
            title_text=strip_tags(p["title"]),
            site=SITE,
            tagline=TAGLINE,
            desc=strip_tags(p["lede"]).replace('"', "&quot;").strip(),
            toc=toc_html(p["slug"]),
            content=content,
        )
        with open(os.path.join(SITE_DIR, p["slug"] + ".html"), "w") as f:
            f.write(html)

    # -- index ------------------------------------------------------------
    items = "\n".join(
        '      <li><a href="%s.html">%s</a><p>%s</p></li>'
        % (p["slug"], strip_tags(p["title"]), BLURBS.get(p["slug"], ""))
        for p in PAGES
    )
    index_html = PAGE.format(
        title_text="Start here",
        site=SITE,
        tagline=TAGLINE,
        desc=strip_tags(TAGLINE),
        toc=toc_html(None),
        content=INDEX_BODY.format(site=SITE, tagline=TAGLINE, items=items),
    )
    with open(os.path.join(SITE_DIR, "index.html"), "w") as f:
        f.write(index_html)

    with open(os.path.join(SITE_DIR, "style.css"), "w") as f:
        f.write(CSS)

    #  Drop generated pages left behind by an earlier run (a renamed or removed
    #  slug), so the directory only ever holds the current set.
    keep = {p["slug"] + ".html" for p in PAGES} | {"index.html"}
    stale = [f for f in os.listdir(SITE_DIR) if f.endswith(".html") and f not in keep]
    for f in stale:
        os.remove(os.path.join(SITE_DIR, f))
        print("removed stale page %s" % f)

    print("wrote index.html, style.css, and %d step pages in %s" % (n, SITE_DIR))


if __name__ == "__main__":
    build()
