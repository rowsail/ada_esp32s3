#!/usr/bin/env python3
"""Generate the static "Bare-Metal Ada on the ESP32-S3" step-by-step guide.

The deliverable is the plain .html files this writes next to it; this script
exists only so the sidebar table of contents and the prev/next links stay
consistent across every page.  Edit the prose below, then:

    python3 docs/guide/build.py

Everything is self-contained: no dependencies, no network, one shared
stylesheet (style.css), no JavaScript.
"""

import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))

SITE = "Bare-Metal Ada on the ESP32-S3"
TAGLINE = "A step-by-step guide to running Ada on the ESP32-S3 with no ESP-IDF, no FreeRTOS, and no Python."

# --------------------------------------------------------------------------
# Pages.  slug, nav title (sidebar), page title, standfirst, body HTML.
# --------------------------------------------------------------------------

PAGES = [

# ---------------------------------------------------------------- 01
dict(
slug="01-what-you-need",
nav="What you need",
title="What you need (and what you don't)",
lede="One board, one USB cable, and one package manager. No ESP-IDF, no "
     "<code>idf.py</code>, no esptool, no Python anywhere in the build or "
     "flash path.",
body="""
<p>Most ESP32 tutorials open by telling you to install a 400&nbsp;MB SDK. This
one does not. The whole toolchain here is <strong>Alire</strong>, the Ada
package manager, which fetches a cross-compiler for you. Everything else &mdash;
packaging the image, writing it to flash, reading the console &mdash; is done by
tools that live in this repository and are themselves written in Ada.</p>

<h2>Hardware</h2>

<ul>
  <li>An <strong>ESP32-S3</strong> devkit, using its <strong>native USB</strong>
      port &mdash; the one wired to the chip's built-in USB-Serial-JTAG
      controller. On most boards it is labelled <code>USB</code>, and the
      <em>other</em> one is labelled <code>UART</code>. Pick the native one: it
      carries the console <em>and</em> the debugger over a single cable.</li>
  <li>A <strong>data-carrying</strong> USB cable. A charge-only cable will
      enumerate nothing and waste an hour of your life.</li>
</ul>

<p>That is the minimum. An LED and a resistor on GPIO0 make the first example
visible, but the console output alone proves it works.</p>

<h2>Software</h2>

<ul>
  <li><strong>Alire</strong> (<code>alr</code>) &mdash; fetches three toolchains:
      the <code>gnat_xtensa_esp32_elf</code> cross-compiler for the chip, a
      native <code>gnat_native</code> for the host tools, and
      <code>gprbuild</code>.</li>
  <li><strong>git</strong>, with submodule support (the runtime lives partly in
      two submodules).</li>
  <li>A <strong>host C compiler</strong> &mdash; used exactly once, to build the
      <code>xtensa-dynconfig</code> core-config plugin the toolchain needs.</li>
</ul>

<p class="note"><strong>What you do <em>not</em> install:</strong> ESP-IDF,
<code>idf.py</code>, esptool, or Python. The build path uses none of them.
(<code>esptool</code> remains an optional fallback if you happen to have it and
prefer it &mdash; see <a href="07-build.html">what a build does</a>.)</p>

<h2>The big picture</h2>

<p>Two commands drive everything. Here is what they set in motion:</p>

<pre><code>  your Ada code  ─┐
  Ada RTS        ─┤  ./build.sh ─&gt; gprbuild (Alire xtensa GNAT) ─&gt; app_main.o
  (generated)     │             ─&gt; link (bare boot + vendored Xtensa support)
  bare boot (Ada) ┘             ─&gt; esp_elf2image (Ada)           ─&gt; app.bin
                                ─&gt; our 2nd-stage bootloader      ─&gt; bootloader.bin
                     ./flash.sh ─&gt; esp_flash (Ada, over USB ROM) ─&gt; board runs it
                                   0x0 bootloader | 0x8000 partitions | 0x10000 app</code></pre>

<p>The Ada runtime is <em>generated</em> on the first build and cached; you never
build it by hand. The two host tools (<code>esp_elf2image</code> and
<code>esp_flash</code>) are compiled once, also on the first build. That is why
the first build is slow and every one after it is fast.</p>

<h2>Ours, and what is vendored</h2>

<p>The <strong>2nd-stage bootloader is this project's own</strong>, not the
vendor's. It is built from <code>examples/common/bare/bootloader/</code> &mdash;
Ada (<code>boot_main</code>, <code>boot_psram</code>, <code>boot_glue</code>)
plus an assembly prologue and linker scripts &mdash; into its own
<code>bootloader.bin</code>, flashed at offset <code>0x0</code>. It is a separate
image, not something linked into your application.</p>

<p>What <em>is</em> vendored sits in <code>examples/common/bare/vendor/</code>,
originates from ESP-IDF v5.4.4, and is committed in-tree rather than fetched:
the Xtensa support (context save/restore, the vector table, interrupt tables),
compiled here from that IDF source and verified instruction-identical to IDF's
own build; the linker scripts and mask-ROM symbol addresses; a trivial
single-app partition table; and two genuine opaque blobs that cannot be built
from this tree &mdash; <code>libxt_hal.a</code>, the Cadence/Tensilica Xtensa
HAL, and <code>libgcc.a</code> for the 64-bit divide helpers.</p>

<p class="note">Those vendored files are the source of truth here and need no
ESP-IDF to build &mdash; nothing is required from an IDF install at build time.
The <em>only</em> reason to go back to ESP-IDF is a maintainer re-vendoring
against a different release.</p>

<h2>Time and platform</h2>

<p>Budget about <strong>15 minutes</strong>, most of it the one-time toolchain
download. The commands below are shown for Linux (Ubuntu/Debian). macOS is
similar but untested; on Windows, use WSL2.</p>
"""),

# ---------------------------------------------------------------- 02
dict(
slug="02-toolchain",
nav="Installing the toolchain",
title="Installing Alire and the toolchains",
lede="One download, one <code>PATH</code> line, two <code>alr toolchain</code> "
     "commands. This is the only thing you install on your machine.",
body="""
<h2>Install Alire</h2>

<pre><code>cd ~
wget https://github.com/alire-project/alire/releases/download/v2.1.0/alr-2.1.0-bin-x86_64-linux.zip
unzip alr-2.1.0-bin-x86_64-linux.zip -d ~/alire
export PATH="$HOME/alire/bin:$PATH"        # add to ~/.bashrc to make permanent
alr version                                # -&gt; alr version 2.1.0</code></pre>

<p>On an ARM64 host, take the <code>aarch64</code> asset instead. This guide was
validated with <strong>alr 2.1.0</strong> and <strong>GNAT 15.2</strong>.</p>

<p class="warn">Put that <code>export PATH=...</code> line in your
<code>~/.bashrc</code> now. Nearly every "<code>gprbuild</code>: command not
found" report traces back to a shell that never saw it.</p>

<h2>Select the three toolchains</h2>

<p>Two commands, because the native and cross toolchains are selected
separately:</p>

<pre><code>alr toolchain --select gnat_native gprbuild
alr toolchain --select gnat_xtensa_esp32_elf
alr toolchain                              # confirm all three are present</code></pre>

<p>Why three, when you are only compiling for one chip?</p>

<table>
  <thead><tr><th>Toolchain</th><th>What it is for</th></tr></thead>
  <tbody>
    <tr><td><code>gnat_xtensa_esp32_elf</code></td>
        <td>The cross-compiler. Turns your Ada into Xtensa LX7 code for the S3.</td></tr>
    <tr><td><code>gnat_native</code></td>
        <td>Builds the two <em>host</em> tools &mdash; the image packager and the
            serial flasher &mdash; which run on your PC, not the board.</td></tr>
    <tr><td><code>gprbuild</code></td>
        <td>The Ada build driver both of the above are invoked through.</td></tr>
  </tbody>
</table>

<p>That is the entire install. No SDK, no vendor installer, no environment
script to source before every session.</p>

<p class="next-hint">Next: get the code &mdash; and get the submodules with
it.</p>
"""),

# ---------------------------------------------------------------- 03
dict(
slug="03-clone",
nav="Getting the code",
title="Getting the code (submodules are not optional)",
lede="The Ada runtime is assembled from two git submodules. Clone without them "
     "and the first build fails with a message about "
     "<code>XTENSA_GNU_CONFIG</code> that will not obviously mean "
     "“you forgot <code>--recurse-submodules</code>”.",
body="""
<h2>Clone it</h2>

<pre><code>cd ~
git clone --recurse-submodules \\
    https://github.com/rowsail/ada_esp32s3.git
cd ada_esp32s3</code></pre>

<p>Already cloned it the ordinary way? Repair it in place:</p>

<pre><code>git submodule update --init --recursive</code></pre>

<h2>What the two submodules are</h2>

<ul>
  <li><strong><code>bb-runtimes</code></strong> &mdash; AdaCore's bare-board
      runtime sources, forked here to add an <code>esp32s3</code> board. This is
      the raw material the Ada runtime is generated from.</li>
  <li><strong><code>xtensa-dynconfig</code></strong> &mdash; the Xtensa
      core-configuration plugin that GNAT's Xtensa back end loads at runtime to
      learn the shape of this particular core. Building it is what needs the
      host C compiler, and it happens exactly once.</li>
</ul>

<h2>What is in the tree</h2>

<pre><code>crates/
  esp32s3_rts/      the GNAT runtime crate (3 profiles) + gen_runtime.sh
  bb-runtimes/      AdaCore bb-runtimes fork with the esp32s3 board (submodule)
  xtensa-dynconfig/ the Xtensa core-config plugin the toolchain needs
libs/
  esp32s3_hal/      the reusable peripheral HAL + pure-Ada ext4/FAT16
examples/           the flashable examples (each owns its board.ads)
  common/bare/      the shared FreeRTOS-free boot (bootloader, start.S, glue)
book/               the long-form guide (LaTeX sources + main.pdf)
x, export.sh        the ./x dispatcher and the esp32-ada launcher</code></pre>

<p>Two entry points matter for now. <code>./x</code> at the repository root
drives every example <em>inside</em> the clone. <code>export.sh</code> turns the
clone into an SDK you can build your own projects against from anywhere on disk
&mdash; that is <a href="10-own-project.html">step 10</a>.</p>

<p class="note">Nothing is downloaded at build time except the Alire toolchains
themselves. The one exception is the optional Wi-Fi driver, whose lower-MAC and
PHY blobs are Apache-2.0 binaries fetched (not committed) by
<code>tools/fetch-wifi-blobs.sh</code>, pinned to exact upstream commits and
verified by sha256.</p>
"""),

# ---------------------------------------------------------------- 04
dict(
slug="04-board",
nav="Board and serial port",
title="Plugging in the board and finding the port",
lede="Two things go wrong here and only here: the wrong USB socket, and "
     "permissions on <code>/dev/ttyACM0</code>. Both take one minute to settle "
     "before you build anything.",
body="""
<h2>Use the native USB port</h2>

<p>Plug the cable into the port wired to the chip's built-in
<strong>USB-Serial-JTAG</strong> controller, usually labelled <code>USB</code>.
Boards that also carry a separate CH343/CP210x bridge label that one
<code>UART</code>. The native port is the one that gives you the console and the
JTAG debugger over the same cable, so prefer it.</p>

<h2>Find the device node</h2>

<pre><code>ls /dev/ttyACM*        # usually /dev/ttyACM0</code></pre>

<p>Nothing there? Check <code>dmesg | tail</code> right after plugging in. A
silent <code>dmesg</code> means the cable is charge-only or the socket is the
wrong one.</p>

<h2>Grant yourself access, once</h2>

<pre><code>sudo usermod -aG dialout $USER          # then LOG OUT and back in</code></pre>

<p>The log-out is not optional &mdash; group membership is established at login.
Until then you will get <code>Permission denied</code> on
<code>/dev/ttyACM0</code> and be tempted to run the flasher under
<code>sudo</code>, which works but leaves root-owned build artifacts behind.</p>

<h2>Forcing download mode</h2>

<p>The flasher resets the board into the ROM download loader for you, by pulsing
DTR and RTS. Occasionally &mdash; a wedged application, a board mid-deep-sleep
&mdash; that does not take. Do it by hand:</p>

<ol>
  <li>Hold <strong>BOOT</strong>.</li>
  <li>Tap <strong>RESET</strong>.</li>
  <li>Release <strong>BOOT</strong>.</li>
</ol>

<p>The board is now sitting in the ROM loader waiting for a flash command, and
will stay there until you reset it again.</p>

<h2>Reading the console</h2>

<p>Any serial terminal at <strong>115200&nbsp;8N1</strong> works. The
<code>./x monitor</code> command in the next step picks one for you, but if you
would rather drive it yourself:</p>

<pre><code>screen /dev/ttyACM0 115200                 # quit: Ctrl-A then K
# or:  python3 -m serial.tools.miniterm /dev/ttyACM0 115200
# or:  cat /dev/ttyACM0</code></pre>

<p class="note">Set <code>ESPPORT</code> in your environment and every command in
this guide will pick it up, so you can drop the <code>-p</code> flag:
<code>export ESPPORT=/dev/ttyACM0</code>.</p>
"""),

# ---------------------------------------------------------------- 05
dict(
slug="05-first-blink",
nav="Your first blink",
title="Your first blink",
lede="One command builds a pure-Ada GPIO driver, packages a flash image, writes "
     "it over the chip's ROM bootloader, resets the board, and streams the "
     "console.",
body="""
<h2>Run it</h2>

<pre><code>./x list                                       # every example + its profile
./x run esp32s3_gpio0_blink -p /dev/ttyACM0    # build + flash + monitor</code></pre>

<p>The <code>esp32s3_</code> prefix is optional &mdash; <code>./x run
gpio0_blink</code> does the same thing. If <code>ESPPORT</code> is set, drop the
<code>-p</code> too.</p>

<p class="warn"><strong>The first build is slow.</strong> It builds the
<code>xtensa-dynconfig</code> plugin, generates the Ada runtime for the chosen
profile, and compiles the two host tools. Several minutes is normal. Every build
after that is incremental and takes seconds.</p>

<h2>What you should see</h2>

<pre><code>[C] GPIO0 blink (bare Ada driver, no FreeRTOS)
[gpio0] HIGH
[gpio0] low
[gpio0] HIGH
...</code></pre>

<p>That is a library-level Ada task toggling GPIO0 every 250&nbsp;ms &mdash; a
2&nbsp;Hz square wave on the pad &mdash; and printing each transition over the
USB-Serial-JTAG console. Wire an LED and a resistor from GPIO0 to GND, or put a
scope on the pin, to see it in the physical world.</p>

<p>There is no FreeRTOS underneath this. Its scheduler is not even linked. The
timing comes from the Ada runtime's own clock tick, and <code>delay until</code>
is served by the board-support layer's alarm &mdash; which is why the period is
exact rather than drifting.</p>

<h2>The verbs, separately</h2>

<p><code>./x run</code> is build + flash + monitor in one. When you want the
pieces:</p>

<pre><code>./x build   esp32s3_gpio0_blink            # cross-compile + link + package app.bin
./x flash   esp32s3_gpio0_blink -p /dev/ttyACM0
./x monitor -p /dev/ttyACM0                # just the serial console (115200)
./x clean   esp32s3_gpio0_blink</code></pre>

<p>And a handful that are easy to miss but worth knowing early:</p>

<table>
  <thead><tr><th>Command</th><th>What it does</th></tr></thead>
  <tbody>
    <tr><td><code>./x setup-device</code></td>
        <td><strong>One-time</strong>, with sudo: installs the udev rule and
            group membership for USB access &mdash; the scripted version of
            <a href="04-board.html">step 4</a>'s permissions.</td></tr>
    <tr><td><code>./x check-device [-p PORT]</code></td>
        <td>Reports whether the board's port is actually accessible. Run this
            before doubting your build.</td></tr>
    <tr><td><code>./x stack &lt;example&gt; [--top N] [--run]</code></td>
        <td>Static stack analysis, per frame &mdash; the counterpart to the
            measured figure in <a href="52-stack-usage.html">step 51</a>.</td></tr>
    <tr><td><code>./x mem &lt;example&gt;</code></td>
        <td>Memory footprint: section sizes and bounds.</td></tr>
    <tr><td><code>./x docs</code></td>
        <td>Builds and runs the HAL reference generator, producing
            <code>docs/HAL_Reference.pdf</code> from the driver specs.</td></tr>
    <tr><td><code>./x install-ide</code> / <code>build-ide</code></td>
        <td>Install the committed VS Code extension (no Node needed); the
            <code>build-</code> form rebuilds the <code>.vsix</code> and is for
            maintainers.</td></tr>
  </tbody>
</table>

<p>Each example is also buildable from its own directory with the
<code>./build.sh</code> and <code>./flash.sh</code> shims, if you prefer working
inside one:</p>

<pre><code>cd examples/esp32s3_gpio0_blink
./build.sh
./flash.sh /dev/ttyACM0                    # defaults to /dev/ttyACM0</code></pre>

<h2>Other examples worth running next</h2>

<table>
  <thead><tr><th>Example</th><th>What it shows</th></tr></thead>
  <tbody>
    <tr><td><code>esp32s3_heartbeat</code></td><td>Single-core heartbeat, <code>[ADA] N</code> at 1&nbsp;Hz</td></tr>
    <tr><td><code>esp32s3_psram</code></td><td>A 1&nbsp;MB static array placed in external PSRAM</td></tr>
    <tr><td><code>esp32s3_smp</code></td><td>Cross-core mailbox over a protected-object entry</td></tr>
    <tr><td><code>esp32s3_gdma_copy</code></td><td>GDMA memory-to-memory with an RAII channel handle</td></tr>
    <tr><td><code>esp32s3_crypto</code></td><td>Hardware SHA and AES checked against FIPS vectors</td></tr>
    <tr><td><code>esp32s3_embedded</code></td><td>The <code>embedded</code> profile: exceptions, finalization, dispatching</td></tr>
    <tr><td><code>esp32s3_full_tasking</code></td><td>The <code>full</code> profile: dynamic tasks, <code>abort</code>, rendezvous</td></tr>
  </tbody>
</table>

<p>The examples are written to be <em>read</em>. Each opens with a header saying
what it demonstrates, what the console should print, and what hardware (if any)
it needs; the magic numbers are named and the reasoning is in the code. Once
you have one running, the source is the next thing to look at.</p>
"""),

# ---------------------------------------------------------------- 06
dict(
slug="06-anatomy",
nav="Reset to Main",
title="What happens between reset and Main",
lede="Your blink worked. Here is every layer it went through, from the chip's "
     "mask ROM to the first line of your Ada &mdash; and what an RTOS would "
     "normally be doing that nothing here does.",
body="""
<h2>The layers, top to bottom</h2>

<table>
  <thead><tr><th>Layer</th><th>What it is</th></tr></thead>
  <tbody>
    <tr><td><strong>Your application</strong></td>
        <td>Ada packages and a <code>Main</code> procedure.</td></tr>
    <tr><td><strong>The HAL</strong></td>
        <td><code>libs/esp32s3_hal</code>: hand-written driver packages
            (<code>ESP32S3.*</code>) over a generated register layer
            (<code>ESP32S3_Registers.*</code>). Optional &mdash; a program may
            poke registers itself &mdash; but it is where the device knowledge
            lives.</td></tr>
    <tr><td><strong>The binder output</strong></td>
        <td><code>gnatbind</code> generates <code>b__main</code>, which
            elaborates every unit in dependency order and then calls
            <code>Main</code>.</td></tr>
    <tr><td><strong>The Ada runtime</strong></td>
        <td>The <code>System.*</code> and <code>Ada.*</code> bodies: secondary
            stack, exceptions, text I/O over the USB-serial console, and the
            tasking kernel &mdash; tasks, protected objects, delays,
            scheduling.</td></tr>
    <tr><td><strong>Board support</strong></td>
        <td>The silicon-specific bottom of the runtime: the Xtensa windowed
            context switch, interrupt entry/exit vectors, the clock tick, SMP
            scheduling and the inter-core interrupt. Ada plus a little assembly
            (<code>start.S</code>, <code>highint5.S</code>,
            <code>context_switch.S</code>). <em>This is the layer an
            off-the-shelf RTOS would otherwise provide.</em></td></tr>
    <tr><td><strong>2nd-stage bootloader</strong></td>
        <td>A minimal loader of our own that maps the flash cache/MMU, brings up
            the octal PSRAM, and jumps to the application image. It replaces the
            vendor's stock second-stage bootloader.</td></tr>
    <tr><td><strong>Mask ROM</strong></td>
        <td>On-chip, immutable. Loads the 2nd-stage bootloader from flash at
            reset.</td></tr>
  </tbody>
</table>

<h2>The boot path</h2>

<pre><code>ROM ─&gt; 2nd-stage bootloader ─&gt; start.S ─&gt; adainit ─&gt; Main
        cache/MMU, PSRAM      PLL, vectors,  elaboration
                              release core 1</code></pre>

<p><code>start.S</code> selects the 240&nbsp;MHz PLL, sets up the stack and the
interrupt vectors, and on the SMP examples releases the second core. Then the
runtime's startup calls <code>adainit</code>, which runs every package's
elaboration &mdash; and that is where library-level tasks like the blinker come
alive, <em>before</em> <code>Main</code> is entered. Finally
<code>Main</code> runs.</p>

<p>There is no vendor startup shim and no third-party scheduler in that chain.
The Ada runtime is the only scheduler and it is linked from source.</p>

<h2>Why the blink example's Main does nothing</h2>

<p>Look at <code>examples/esp32s3_gpio0_blink/src/main.adb</code> and you find
this:</p>

<pre><code>with Ada.Real_Time; use Ada.Real_Time;

--  The GPIO0 blink driver + its task live in package GPIO; withing it pulls the
--  task into the program so it elaborates and runs.
with GPIO;
pragma Unreferenced (GPIO);

procedure Main is
begin
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;</code></pre>

<p>The work is done by a library-level task inside package <code>GPIO</code>,
which starts at elaboration. <code>Main</code> becomes the environment task,
which here just parks forever. Withing a package you never call is how you pull
its tasks into the link closure; <code>pragma Unreferenced</code> tells the
compiler that is deliberate.</p>

<h2>A minimal application</h2>

<p>If you would rather do the work in the main procedure itself, this is a
complete program. (It is named <code>Blink_Min</code> here because it lives in
<code>docs/guide/samples/</code>, where <code>check_samples.sh</code> compiles
it against the embedded runtime on every doc change &mdash; rename it
<code>Main</code> in your own project.)</p>

{{sample:blink_min.adb}}

<p><code>delay until</code> is served by the board-support tick;
<code>ESP32S3.GPIO</code> is the HAL; everything links against the runtime
crate.</p>
"""),

# ---------------------------------------------------------------- 07
dict(
slug="07-build",
nav="What a build does",
title="What a build actually does",
lede="Five steps from your Ada to a flashable image, and two small host tools "
     "&mdash; both written in Ada &mdash; that replace <code>esptool</code> "
     "entirely.",
body="""
<h2>The five steps</h2>

<p><code>build.sh</code> sets the profile and heap size, then the shared
<code>bare_build.sh</code>:</p>

<ol>
  <li><strong>Regenerates or selects the runtime crate</strong> for the chosen
      profile. Cached after the first time.</li>
  <li><strong>Compiles your Ada</strong> against that pinned runtime with
      <code>gprbuild</code>, producing a <em>relocatable</em>
      <code>app_main.o</code> (with <code>Main</code> renamed to
      <code>_ada_main</code>).</li>
  <li><strong>Compiles the shared bare boot</strong> &mdash;
      <code>start.S</code>, the interrupt vectors, the heap, and a freestanding
      libc &mdash; plus the example's C console glue.</li>
  <li><strong>Links</strong> it all against the linker scripts into
      <code>app.elf</code>.</li>
  <li><strong>Packages</strong> <code>app.bin</code>: image header plus
      segments.</li>
</ol>

<p>Then <code>flash.sh</code> writes three images: the 2nd-stage bootloader, the
partition table, and <code>app.bin</code>.</p>

<h2><code>esp_elf2image</code> &mdash; ELF to flash image</h2>

<p>Turning <code>app.elf</code> into <code>app.bin</code> is more than a copy.
The on-flash format the ROM and our bootloader expect has:</p>

<ul>
  <li><strong>Segments</strong>: the ELF's allocated <code>PROGBITS</code>
      sections, merged where contiguous, each padded to a multiple of four.</li>
  <li><strong>A 24-byte header</strong>: the 8-byte common part (magic
      <code>16#E9#</code>, segment count, the flash-mode byte, the entry point)
      plus a 16-byte extended part.</li>
  <li><strong>Flash segments aligned to 64&nbsp;KB</strong>, with the RAM
      segments written <em>interleaved as the alignment padding</em> &mdash; the
      exact scheme the bootloader's MMU mapping relies on.</li>
  <li><strong>An XOR checksum</strong> (seed <code>16#EF#</code>) as the last
      byte of a 16-aligned block, and a <strong>SHA-256</strong> of the whole
      image appended.</li>
</ul>

<h2><code>esp_flash</code> &mdash; writing it to the chip</h2>

<p>The flasher speaks the chip's ROM serial bootloader protocol directly. It is
100&nbsp;% Ada: the OS serial interface (termios raw mode, the
<code>TIOCM*</code> DTR/RTS modem lines, poll/read/write) is bound to libc
through <code>Interfaces.C</code>, with no C source. The sequence, with no RAM
stub and no compression:</p>

<ol>
  <li><strong>Reset into download mode</strong> &mdash; the USB-JTAG DTR/RTS
      pulse.</li>
  <li><strong>SYNC</strong> &mdash; the handshake, repeated until the ROM
      answers.</li>
  <li><strong>SPI attach</strong> and <strong>set-params</strong> (flash
      geometry).</li>
  <li>Per file, <strong>flash_begin</strong> (erase) then
      <strong>flash_data</strong> in 1&nbsp;KB blocks, each carrying the ROM's
      XOR checksum.</li>
  <li><strong>flash_end</strong>, then a hard reset to run.</li>
</ol>

<p>A typical invocation writes the three images at their flash offsets:</p>

<pre><code>esp_flash -p /dev/ttyACM0 --flash-size 2MB \\
  0x0     bootloader.bin \\
  0x8000  partition-table.bin \\
  0x10000 app.bin</code></pre>

<p>A ~225&nbsp;KB image flashes in about three seconds. That is ROM speed &mdash;
no stub, no compression. Note that only <em>flash</em> is written; the external
PSRAM is mapped at runtime by the 2nd-stage bootloader.</p>

<h2>Everyday build tips</h2>

<table>
  <thead><tr><th>Goal</th><th>Command</th></tr></thead>
  <tbody>
    <tr><td>Rebuild after editing Ada</td><td><code>./build.sh</code> again, then <code>./flash.sh</code></td></tr>
    <tr><td>Force the Ada to rebuild</td><td><code>rm -f obj/app_main.o</code></td></tr>
    <tr><td>Force the runtime to regenerate</td><td><code>rm -rf crates/esp32s3_rts/*-esp32s3</code></td></tr>
    <tr><td>Use esptool instead (optional fallback)</td><td><code>ESP_USE_ESPTOOL=1 ./build.sh</code> (and <code>./flash.sh</code>)</td></tr>
  </tbody>
</table>
"""),

# ---------------------------------------------------------------- 08
dict(
slug="08-profiles",
nav="Runtime profiles",
title="Choosing a runtime profile",
lede="Three runtimes ship here, from a lean Jorvik kernel to the complete Ada "
     "tasking model. Picking one is a build-time switch, and most projects want "
     "the middle option.",
body="""
<h2>The three</h2>

<table>
  <thead><tr><th>Profile</th><th>Tasking model</th><th>What you get</th></tr></thead>
  <tbody>
    <tr><td><code>light-tasking</code></td>
        <td>Jorvik (Ravenscar+)</td>
        <td>Periodic tasks, protected objects, SMP. No exception propagation,
            no heap. The lean default.</td></tr>
    <tr><td><code>embedded</code></td>
        <td>Jorvik + ZCX</td>
        <td>Adds full exception propagation <em>with names</em>,
            controlled-type finalization, and a heap. <strong>The usual
            choice</strong> &mdash; the HAL's RAII handles need it.</td></tr>
    <tr><td><code>full</code></td>
        <td>Complete GNARL</td>
        <td>Lifts the Jorvik restrictions: rendezvous, selective
            <code>accept</code>, dynamic and nested tasks, dynamic priorities,
            <code>abort</code>, dynamic <code>Ada.Interrupts</code>.</td></tr>
  </tbody>
</table>

<p><code>light-tasking</code> and <code>embedded</code> both set
<code>pragma Profile (Jorvik)</code>; <code>full</code> is the unrestricted
runtime.</p>

<h2>Selecting one</h2>

<p>Per build, from the dispatcher &mdash; <code>auto</code> (the default) uses
whatever the example itself declares:</p>

<pre><code>./x run esp32s3_heartbeat --profile embedded -p /dev/ttyACM0
./x build esp32s3_heartbeat -P full</code></pre>

<p>Or permanently, for one project, by setting <code>ESP32S3_RTS_PROFILE</code>
in its <code>build.sh</code>. A freshly scaffolded project already contains that
line, set to <code>embedded</code>:</p>

<pre><code>export ESP32S3_RTS_PROFILE=embedded</code></pre>

<p><code>./x list</code> shows every example alongside the profile it was
written for.</p>

<h2>Which to pick</h2>

<p>Start with <strong><code>embedded</code></strong> unless you have a reason
not to. Named exceptions and finalization are worth their cost while you are
learning the board, and the HAL's RAII driver handles assume them.</p>

<p>Drop to <strong><code>light-tasking</code></strong> when you want the
smallest image and can live inside Jorvik: periodic tasks and protected objects
with no heap and no exception propagation. Move up to
<strong><code>full</code></strong> only when you specifically need rendezvous,
dynamically created tasks, or <code>abort</code>.</p>

<p class="note">Changing profile means regenerating a runtime, so the first
build under a new profile is slow again. That is expected, not a fault.</p>

<p>All three are exercised against the <strong>ACATS 4.2</strong> conformance
suite on real hardware, with zero genuine failures on every profile. What
remains non-passing is interactive tests, library units the bare runtime omits,
correct <code>NOT-APPLICABLE</code> results, or documented limitations &mdash;
the book's ACATS chapter has the breakdown.</p>
"""),

# ---------------------------------------------------------------- 09
dict(
slug="09-board-config",
nav="Board configuration",
title="Board configuration: <code>board.ads</code>",
lede="Flash size and PSRAM size are the two things the build has to be told "
     "about your board. They live in an Ada spec at the root of each project "
     "&mdash; there is no global config, and no <code>sdkconfig</code>.",
body="""
<h2>The file</h2>

<p>Every example owns one. Here is
<code>examples/esp32s3_gpio0_blink/board.ads</code>:</p>

<pre><code>package Board is
   Flash_Size : constant := 2 * 1024 * 1024;   --  total SPI flash
   PSRAM_Size : constant := 2 * 1024 * 1024;   --  external PSRAM @0x3D000000
end Board;</code></pre>

<p>It is ordinary Ada, not a config-file dialect, so it participates in the
build like any other spec. Edit it and rebuild &mdash; <code>build.sh</code>
regenerates the board config and the 2nd-stage bootloader automatically. There
is no separate step to remember.</p>

<h2>Or let the tooling edit it</h2>

<pre><code>./x config gpio0_blink show
./x config gpio0_blink flash-size 4MB
./x config gpio0_blink psram-size 8MB</code></pre>

<p>Sizes accept several spellings: <code>4MB</code>, <code>512KB</code>,
<code>0x800000</code>, <code>8388608</code>. For a project outside the repo, the
same verb exists on the launcher: <code>esp32-ada config psram-size 8MB</code>.</p>

<h2>Why PSRAM size changes the bootloader</h2>

<p>The 2nd-stage bootloader brings up the external octal PSRAM and maps it, so
the size is baked into it. A project whose <code>PSRAM_Size</code> differs from
the default gets its <strong>own</strong> bootloader built for it; projects that
match the default reuse the prebuilt one. That is why changing PSRAM size costs
a bootloader rebuild and changing flash size does not.</p>

<p class="note">If you are curious what that bring-up involves: it is entirely
from-source here, including a genuine 80&nbsp;MHz din-sampling timing sweep
rather than a vendor default. The write-up is in
<code>examples/common/bare/bootloader/PSRAM_BRINGUP_RESEARCH.md</code>.</p>

<h2>Machine-readable</h2>

<p>For editor plugins and scripts, both discovery commands emit JSON:</p>

<pre><code>./x list   --json
./x config --json
# {"flash_size":2097152,"flash_size_str":"2MB","psram_size":2097152,"psram_pages":32}</code></pre>
"""),

# ---------------------------------------------------------------- 10
dict(
slug="10-own-project",
nav="Your own project",
title="Your own project, outside the repo",
lede="Don't edit an example. Treat the repository as an SDK: source "
     "<code>export.sh</code> once, then scaffold a self-contained project "
     "anywhere on disk, with no runtime source copied in and no paths baked "
     "into any file.",
body="""
<h2>Source the SDK, scaffold, run</h2>

<pre><code>. ~/ada_esp32s3/export.sh   # once per shell (add to ~/.bashrc)
mkdir ~/myblink &amp;&amp; cd ~/myblink
esp32-ada init                        # scaffold app.gpr, board.ads, src/main.adb
#  ... edit src/main.adb ...
esp32-ada run -p /dev/ttyACM0         # build + flash + monitor</code></pre>

<p>That one <code>export.sh</code> does three things: it puts
<code>esp32-ada</code> on your <code>PATH</code>, exports
<code>ESP32S3_ADA_SDK</code> so a project anywhere can find the SDK, and adds the
runtime and HAL projects to <code>GPR_PROJECT_PATH</code> &mdash; so both
<code>gprbuild</code> <em>and</em> the Ada Language Server resolve
<code>with "esp32s3_rts.gpr"</code> with no path in your project.</p>

<h2>What <code>init</code> writes</h2>

<pre><code>myblink/
  app.gpr            # withs esp32s3_rts.gpr + esp32s3_hal.gpr (resolved by name)
  board.ads          # this project's flash / PSRAM sizes
  src/main.adb       # your code (procedure Main; boots both cores, then idles)
  build.sh flash.sh  # thin shims into the SDK's shared bare-boot
  .gitignore
  .vscode/           # ALS project + build/flash/run tasks driving esp32-ada</code></pre>

<p>Nothing from the SDK is copied in. <code>app.gpr</code> references the runtime
and HAL <em>by name</em>, and the build shims reach the shared bare-boot through
<code>$ESP32S3_ADA_SDK</code>. Check the folder into its own git repository if
you like; it stays portable. To use another SDK library, add
<code>with "&lt;name&gt;.gpr";</code> to <code>app.gpr</code> for anything under
the SDK's <code>libs/</code>.</p>

<p>A fresh project defaults to the <strong><code>embedded</code></strong>
profile, set by an <code>ESP32S3_RTS_PROFILE</code> line in its
<code>build.sh</code>. Change that line for <code>light-tasking</code> or
<code>full</code>.</p>

<h2>The verbs</h2>

<p>Every <code>esp32-ada</code> verb mirrors the matching <code>./x</code> one.
The only difference is the target: <code>./x build gpio0_blink</code> names an
example inside the clone, while <code>esp32-ada build</code> operates on the
folder you are standing in.</p>

<table>
  <thead><tr><th>Command</th><th>What it does</th></tr></thead>
  <tbody>
    <tr><td><code>esp32-ada init [<em>dir</em>]</code></td><td>Scaffold a project in <em>dir</em>, or the current folder.</td></tr>
    <tr><td><code>esp32-ada build [-P <em>prof</em>]</code></td><td>Build to <code>app.bin</code>.</td></tr>
    <tr><td><code>esp32-ada flash [-p <em>port</em>]</code></td><td>Build if needed, then flash over the USB ROM bootloader.</td></tr>
    <tr><td><code>esp32-ada run [-p <em>port</em>] [-P <em>prof</em>]</code></td><td>Build, flash, and open the serial monitor.</td></tr>
    <tr><td><code>esp32-ada monitor [-p <em>port</em>]</code></td><td>Just the serial console (115200).</td></tr>
    <tr><td><code>esp32-ada clean</code></td><td>Remove this project's build artifacts.</td></tr>
    <tr><td><code>esp32-ada config [show | flash-size <em>S</em> | psram-size <em>S</em>]</code></td><td>Show or set this project's sizes.</td></tr>
    <tr><td><code>esp32-ada debug [-p <em>port</em>]</code></td><td>On-chip debug (OpenOCD + GDB), halting at <code>Main</code>.</td></tr>
    <tr><td><code>esp32-ada kill-openocd</code></td><td>Kill every OpenOCD, releasing captured USB-JTAG ports.</td></tr>
    <tr><td><code>esp32-ada install-ide</code> / <code>install-vim</code></td><td>Install the VS Code extension / symlink the Vim plugin.</td></tr>
  </tbody>
</table>

<p><code>-p</code>/<code>--port</code> defaults to <code>$ESPPORT</code> or
<code>/dev/ttyACM0</code>; <code>-C <em>dir</em></code> runs as if from
<em>dir</em>.</p>

<h2>Lifting an example out of tree</h2>

<p class="warn">Copying a whole example directory elsewhere will <strong>not
build</strong>. Examples are wired to their location: an Alire path-pin in
<code>alire.toml</code>, a <code>&lt;name&gt;.gpr</code>, and build shims
relative to <code>examples/common/bare/</code>.</p>

<p>Scaffold a fresh project and bring the <em>sources</em> across instead. The
scaffold already supplies the <code>app.gpr</code>, board config and shims that
make them build:</p>

<pre><code>. /path/to/ada_esp32s3/export.sh
esp32-ada init ~/myblink &amp;&amp; cd ~/myblink
SDK=$ESP32S3_ADA_SDK
cp "$SDK"/examples/esp32s3_gpio0_blink/src/*.ad? src/   # the Ada sources, incl. main.adb
esp32-ada build
esp32-ada run -p /dev/ttyACM0</code></pre>

<p>Four things make that copy build cleanly:</p>

<ul>
  <li><strong>Only <code>src/</code> is yours.</strong> The scaffold's
      <code>app.gpr</code> already sets <code>Source_Dirs =&gt; "src"</code> and
      <code>Main =&gt; "main.adb"</code>, so the example's units drop straight
      in. Overwrite the scaffold's <code>src/main.adb</code>.</li>
  <li><strong>Match the profile.</strong> The scaffold defaults to
      <code>embedded</code>, which is what most examples assume. An example
      written for <code>light-tasking</code> (shown by <code>./x list</code> and
      in its README) needs the <code>ESP32S3_RTS_PROFILE</code> line
      changed.</li>
  <li><strong>Bring board config and C natives if customized.</strong> Copy the
      example's <code>board.ads</code> if it sets a non-default size, and its
      <code>glue.c</code> if it has C natives.</li>
  <li><strong>Extra libraries.</strong> If the example withs more of the SDK's
      <code>libs/</code> beyond the HAL, add the matching
      <code>with "&lt;name&gt;.gpr";</code>.</li>
</ul>

<p class="note">There is no fixed "project location" and no <code>idf.py</code>.
The SDK is found through <code>$ESP32S3_ADA_SDK</code>, so your project folder
lives wherever you want it.</p>
"""),

# ---------------------------------------------------------------- 11
dict(
slug="11-hal",
nav="Talking to hardware",
title="Talking to the hardware: the HAL",
lede="Twenty-five-plus drivers, each a private register engine hidden behind a "
     "task-safe gateway. Here is what using one looks like, and why they are "
     "shaped the way they are.",
body="""
<h2>Using it</h2>

<p>The HAL is a plain GPR library project &mdash;
<code>libs/esp32s3_hal/esp32s3_hal.gpr</code> &mdash; <strong>not an Alire
crate</strong>. It has no <code>alire.toml</code>, and nothing reaches it through
Alire's dependency graph; the runtime (<code>crates/esp32s3_rts</code>) is the
only crate here, path-pinned by each example. What you get instead is one line
in your own project file, resolved either of two ways:</p>

<pre><code>--  Standalone project: by name, via GPR_PROJECT_PATH (which export.sh sets)
with "esp32s3_hal.gpr";

--  In-repo example: by relative path, so the Ada Language Server resolves it
--  with no environment set at all
with "../../libs/esp32s3_hal/esp32s3_hal.gpr";</code></pre>

<p><code>export.sh</code> puts <code>crates/esp32s3_rts</code> and every
directory under <code>libs/</code> on <code>GPR_PROJECT_PATH</code>, so the
by-name form resolves for <code>gprbuild</code> <em>and</em> for the Ada Language
Server. Adding a library to the SDK needs no edit anywhere: dropping
<code>libs/&lt;name&gt;/&lt;name&gt;.gpr</code> in is enough. The HAL's units
compile against the same runtime and the same profile as whatever consumes them
&mdash; the project reads <code>ESP32S3_RTS_PROFILE</code> itself and keys its
object directory by it.</p>

<p>Then <code>with</code> the driver you want. This is the whole body of the
blink example's GPIO package &mdash; a real, complete driver client:</p>

<pre><code>with System;
with Ada.Real_Time; use Ada.Real_Time;

with ESP32S3.GPIO;
with ESP32S3.Log; use ESP32S3.Log;

package body GPIO is

   Pin : constant ESP32S3.GPIO.Pin_Id := 0;

   --  Library-level task: toggle GPIO0 every 250 ms (2 Hz square wave) on core 0,
   --  logging each transition over the USB-Serial-JTAG console.
   task Blinker
     with Priority =&gt; System.Priority'Last - 1, CPU =&gt; 1;

   task body Blinker is
      Period : constant Time_Span := Milliseconds (250);
      Next   : Time;
      High   : Boolean := False;
   begin
      ESP32S3.GPIO.Configure (Pin, ESP32S3.GPIO.Output,
                              Drive =&gt; ESP32S3.GPIO.Drive_Strong);
      Next := Clock + Period;
      loop
         delay until Next;
         High := not High;
         ESP32S3.GPIO.Write (Pin, High);
         Put_Line ("[gpio0] " &amp; (if High then "HIGH" else "low "));
         Next := Next + Period;
      end loop;
   end Blinker;

end GPIO;</code></pre>

<p>Three things in there are worth noticing.</p>

<ul>
  <li><strong><code>CPU =&gt; 1</code></strong> pins the task to a core. This is
      a genuinely dual-core SMP runtime; tasks can be pinned per core and
      protected-object entries work <em>across</em> cores.</li>
  <li><strong><code>Next := Next + Period</code></strong>, not
      <code>Clock + Period</code>. Absolute deadlines do not accumulate drift.
      The interrupt-backed <code>delay until</code> gives exact, stable
      periods.</li>
  <li><strong>No register pokes.</strong> Everything goes through
      <code>ESP32S3.GPIO</code>, which is where the device knowledge lives.</li>
</ul>

<h2>How the drivers are shaped</h2>

<p>Each driver is a thin <em>private</em> register "engine" hidden behind a
task-safe gateway &mdash; either a protected object or a limited-controlled RAII
handle. Concurrent access from several tasks is therefore safe by construction
rather than by convention, and a driver handle releases its peripheral when it
goes out of scope.</p>

<p class="warn"><strong>The profile decides what the HAL even contains.</strong>
The RAII-handle drivers &mdash; SPI, I2C, UART, GDMA, MCPWM &mdash; are built on
controlled types, and <code>light-tasking</code> forbids those
(<code>No_Finalization</code>), so the HAL project <em>excludes those sources</em>
under that profile; so are the ext4 and FAT16 filesystems and the ESP
serial-bootloader client. What remains under <code>light-tasking</code> is the
lock-free subset: GPIO, RNG, temperature. The drivers <em>target</em>
<a href="08-profiles.html"><code>embedded</code></a>, where full exception
propagation lets their <code>-gnata</code> contracts &mdash; the GPIO valid-pin
predicate, for one &mdash; raise something you can catch.</p>

<p>Under the drivers sits a generated register layer,
<code>ESP32S3_Registers.*</code>, produced by svd2ada from the vendor's SVD
description &mdash; typed record fields with representation clauses, not
<code>volatile uint32_t*</code> arithmetic.</p>

<h2>What is available</h2>

<p>GPIO, SPI, I2C, UART, GDMA, I2S, LEDC, RMT, PCNT, SDM, MCPWM, general-purpose
timers, ADC, capacitive touch, RTC and RTC-IO, LCD (i80), TWAI/CAN, hardware
crypto (SHA/AES), RNG, and SD over both SPI and the native SDHOST. Alongside
them, a pure-Ada ext2/3/4 filesystem with a JBD2 journal, and a pure-Ada FAT16
reader and formatter for media a PC has to be able to mount.</p>

<p>Most drivers ship with a self-test under <code>examples/</code> that needs no
wiring &mdash; internal loopback or GPIO sampling. Running the one for the
peripheral you are about to use is the fastest way to confirm your board before
you write any code against it.</p>

<p><a href="12-examples.html">Step 12</a> catalogues all 96 examples &mdash;
which one to run for each peripheral, and under which profile. The steps after
it go through the peripherals one at a time. The
four you will reach for first come first &mdash; <a href="13-gpio.html">GPIO</a>,
<a href="14-i2c.html">I2C</a>, <a href="15-spi.html">SPI</a> and
<a href="16-uart.html">UART</a> &mdash; then the engine they and everything else
are built on, <a href="17-gdma.html">GDMA</a>:</p>

<table>
  <thead><tr><th>Step</th><th>Peripheral</th><th>Why it has its own page</th></tr></thead>
  <tbody>
    <tr><td>13</td><td><a href="13-gpio.html">GPIO</a></td><td>The pin type, what is atomic in silicon, interrupts and the trampoline rule</td></tr>
    <tr><td>14</td><td><a href="14-i2c.html">I2C</a></td><td>Session ownership, repeated START, unbounded transfers</td></tr>
    <tr><td>15</td><td><a href="15-spi.html">SPI</a></td><td>Per-device clock and mode, chip select three ways, DMA preconditions</td></tr>
    <tr><td>16</td><td><a href="16-uart.html">UART</a></td><td>No setup call, interrupt-driven RX, a pin-routing trap</td></tr>
    <tr><td>17</td><td><a href="17-gdma.html">GDMA</a></td><td>Channels as a claimed resource, and the buffer rules PSRAM's cache imposes</td></tr>
    <tr><td>18</td><td><a href="18-i2s.html">I2S</a></td><td>No CPU FIFO at all, gapless looping, capture under playback</td></tr>
    <tr><td>19</td><td><a href="19-lcd.html">LCD</a></td><td>Command-driven i8080 and continuously-refreshed RGB</td></tr>
    <tr><td>20</td><td><a href="20-twai.html">TWAI/CAN</a></td><td>Identifier widths kept apart by type, and the bus-off trap</td></tr>
    <tr><td>21</td><td><a href="21-rmt.html">RMT</a></td><td>Arbitrary pulse trains; IR, WS2812, 1-Wire</td></tr>
    <tr><td>22</td><td><a href="22-ledc-sdm.html">LEDC &amp; SDM</a></td><td>PWM dimming, and density modulation that filters to analog</td></tr>
    <tr><td>23</td><td><a href="23-mcpwm.html">MCPWM</a></td><td>Dead-time and hardware fault shutdown</td></tr>
    <tr><td>24</td><td><a href="24-timers-pcnt.html">Timers &amp; PCNT</a></td><td>A 54-bit timer with an alarm, and edge counters that wrap</td></tr>
    <tr><td>25</td><td><a href="25-analog.html">ADC &amp; touch</a></td><td>Fixed-pin channels, attenuation, and relative touch detection</td></tr>
    <tr><td>26</td><td><a href="26-rtc.html">RTC &amp; deep sleep</a></td><td>Waking is a reset; retained memory and pad hold</td></tr>
    <tr><td>27</td><td><a href="27-crypto.html">Crypto &amp; RNG</a></td><td>SHA/AES/RSA, MD5's specific job, and the RNG caveat</td></tr>
    <tr><td>28</td><td><a href="28-sd.html">SD cards</a></td><td>Two hosts, one block API, different profile requirements</td></tr>
    <tr><td>29</td><td><a href="29-chip-id.html">Temperature &amp; MAC</a></td><td>Die temperature, and the four factory addresses</td></tr>
  </tbody>
</table>

<p>Steps 29 to 38 then cover the <strong>external devices</strong> the SDK ships
drivers for &mdash; parts on your board rather than inside the chip, each built
on one of the buses above:</p>

<table>
  <thead><tr><th>Step</th><th>Device</th><th>What it is</th></tr></thead>
  <tbody>
    <tr><td>30</td><td><a href="30-display-touch.html">ST7789 &amp; GT911</a></td><td>SPI display and capacitive touch controller</td></tr>
    <tr><td>31</td><td><a href="31-es8311.html">ES8311</a></td><td>Mono audio codec: I2C control, I2S audio</td></tr>
    <tr><td>32</td><td><a href="32-sensors.html">QMI8658C &amp; SHT41</a></td><td>6-axis IMU, and temperature/humidity</td></tr>
    <tr><td>33</td><td><a href="33-pcf85063a.html">PCF85063A</a></td><td>Real-time clock with an alarm</td></tr>
    <tr><td>34</td><td><a href="34-expanders.html">TCA9555, CH422G, HC595</a></td><td>Port expanders and a shift register</td></tr>
    <tr><td>35</td><td><a href="35-tx1812.html">TX1812</a></td><td>Addressable RGB LEDs</td></tr>
    <tr><td>36</td><td><a href="36-memory.html">W25Q, 24C, FRAM</a></td><td>NOR flash, EEPROM catalogue, FRAM</td></tr>
    <tr><td>37</td><td><a href="37-tlv2556.html">TLV2556</a></td><td>External 12-bit SPI ADC</td></tr>
    <tr><td>38</td><td><a href="38-gps.html">GPS</a></td><td>NMEA receiver as a background service</td></tr>
    <tr><td>39</td><td><a href="39-w5500.html">W5500</a></td><td>Ethernet with a hardwired TCP/IP stack</td></tr>
  </tbody>
</table>

<p>Steps 39 to 43 are the <strong>networking stack</strong> above those
interfaces &mdash; chip-neutral, so the same application code runs over Ethernet,
Wi-Fi or anything else registered as a NIC:</p>

<table>
  <thead><tr><th>Step</th><th>Layer</th><th>What it gives you</th></tr></thead>
  <tbody>
    <tr><td>40</td><td><a href="40-net-stack.html">Sockets &amp; routing</a></td><td>One socket API over several NICs, longest-prefix routing, failover</td></tr>
    <tr><td>41</td><td><a href="41-dns-ntp.html">DNS &amp; NTP</a></td><td>Name resolution and time, portable between host and board</td></tr>
    <tr><td>42</td><td><a href="42-tls.html">TLS 1.3</a></td><td>A full client handshake and chain validation, no C library</td></tr>
    <tr><td>43</td><td><a href="43-wifi.html">Wi-Fi</a></td><td>Pure Ada around the fetched radio blobs, WPA2 handshake included</td></tr>
    <tr><td>44</td><td><a href="44-modbus.html">Modbus TCP</a></td><td>Industrial master and slave over the facade</td></tr>
    <tr><td>45</td><td><a href="45-ftp.html">FTP</a></td><td>Streamed client, and a server over your filesystems</td></tr>
  </tbody>
</table>

<p>Steps 45 to 51 are the rest of the SDK &mdash; storage, filesystems, text and
the standalone tools:</p>

<table>
  <thead><tr><th>Step</th><th>Component</th><th>What it gives you</th></tr></thead>
  <tbody>
    <tr><td>46</td><td><a href="46-block-dev.html">Block devices &amp; wear levelling</a></td><td>The vtable the filesystems sit on, and an FTL that spreads flash wear</td></tr>
    <tr><td>47</td><td><a href="47-ext4.html">ext4</a></td><td>Read/write ext2/3/4 with JBD2 replay and on-device mkfs</td></tr>
    <tr><td>48</td><td><a href="48-fat16.html">FAT16</a></td><td>The filesystem a PC can mount, read-only by design</td></tr>
    <tr><td>49</td><td><a href="49-console-fonts.html">Console, text &amp; fonts</a></td><td>Formatted output with no hosted runtime; panel-independent glyphs</td></tr>
    <tr><td>50</td><td><a href="50-esp-loader.html">Esp_Loader</a></td><td>Program another ESP32 from the board</td></tr>
    <tr><td>51</td><td><a href="51-simd.html">SIMD (PIE)</a></td><td>128-bit vector kernels in inline assembly</td></tr>
    <tr><td>52</td><td><a href="52-stack-usage.html">Stack measurement</a></td><td>Stack painting, to catch what static analysis cannot see</td></tr>
  </tbody>
</table>

<p class="warn"><strong>Verify on your own board.</strong> The drivers were
exercised on an ESP32-S3 during development, but nothing has been re-verified as
it ships. A few components &mdash; the SD drivers, the temperature sensor, the
filesystems' on-device paths, the ESP serial-bootloader client &mdash; are
explicitly host-verified or smoke-tested only. The repository's <em>Testing
status</em> table says which is which; treat every driver as needing
confirmation on your hardware before you rely on it.</p>

<h2>Console output</h2>

<p><code>ESP32S3.Log</code> is the formatted-output path the examples use
(<code>Put</code>, <code>Put_Line</code>, <code>Put_Hex</code>,
<code>Put_Fixed</code>&hellip;) over the USB-Serial-JTAG console. On the
<code>embedded</code> and <code>full</code> profiles
<code>Ada.Text_IO</code> is available too, routed to the same console by the
runtime.</p>
"""),

# ---------------------------------------------------------------- 12
dict(
slug="12-examples",
nav="The examples",
title="The examples: all 96 of them",
lede="Most need no wiring, most tell you PASS or FAIL, and each one is the "
     "fastest way to find out whether a peripheral works on <em>your</em> "
     "board before you write a line against it.",
body="""
<h2>How to use them</h2>

<p>Every example builds and runs the same way, and the short name is
enough:</p>

<pre><code>./x list                       # names, profiles, directories
./x run gpio0_blink            # build + flash + monitor
./x run i2c_loopback -p /dev/ttyACM0</code></pre>

<p class="note"><strong>Run the self-test before writing code.</strong> When a
driver page here says a peripheral works, that is a claim about the authors'
board. The matching example is how you turn it into a claim about yours &mdash;
and most need <em>no external wiring at all</em>, using internal loopback or a
pad the chip samples itself.</p>

<p>They are also meant to be <em>read</em>. Each opens with a header saying what
it demonstrates, what the console should print, and what hardware it needs;
magic numbers are named and the reasoning is in the code.
<code>examples/STYLE.md</code> records the bar, with
<code>esp32s3_gpio0_blink</code> and <code>esp32s3_gdma_copy</code> as the
models.</p>

<p class="warn"><strong>Mind the profile column.</strong> An example built for
<code>embedded</code> will not build under <code>light-tasking</code> &mdash; the
RAII driver handles need finalization (<a href="08-profiles.html">step 8</a>).
That is the first thing to check when a copied example fails to compile.</p>

<h2>The catalogue</h2>

<p>Generated from <code>./x list --json</code> and the examples' own headers, so
it cannot drift from what the repository actually contains. The last column
links to the step that explains the thing being demonstrated.</p>

{{examples}}
"""),

dict(
slug="13-gpio",
nav="GPIO in depth",
title="GPIO in depth",
lede="A pin type that refuses to name a pad which would hang the chip, three "
     "operations that are atomic in hardware, two that are not, and pin "
     "interrupts with one rule you cannot break.",
body="""
<h2>The type that stops you first</h2>

<p>Most GPIO APIs take an integer. This one takes a subtype whose predicate
encodes which pads exist and which are already spoken for:</p>

<pre><code>type Pad_Number is range -1 .. 48;

No_Pin : constant Pad_Number := -1;      --  an optional line, left unrouted

subtype Pin_Id is Pad_Number range 0 .. 48
  with Static_Predicate =&gt; Pin_Id in 0 .. 21 | 38 .. 48;

subtype Optional_Pin is Pad_Number
  with Static_Predicate =&gt; Optional_Pin in -1 | 0 .. 21 | 38 .. 48;</code></pre>

<p>Pads <strong>22&hellip;25</strong> do not exist on the ESP32-S3. Pads
<strong>26&hellip;37</strong> are bonded to the in-package SPI flash and octal
PSRAM. Driving any of them hangs the chip &mdash; not an exception you can catch,
a dead board. So they are not in the subtype.</p>

<p class="note"><strong>Why it is a <code>Static_Predicate</code> and not a
dynamic one.</strong>
Because it is static, naming a reserved pad as a <em>compile-time</em> value is a
<strong>compile error</strong> (<code>static expression fails static predicate
check</code>), not a runtime surprise. That only bites if the value is static
&mdash; so declare your pin constants as <code>Pin_Id</code>, not as untyped
numerals, and you get the check:</p>

<pre><code>Led : constant ESP32S3.GPIO.Pin_Id := 30;   --  rejected at COMPILE time (PSRAM pad)
Led : constant                     := 30;   --  just an integer; no check here</code></pre>

<p>A value computed at run time is checked by the subtype predicate instead,
wherever assertions are enabled (<code>-gnata</code>, which the HAL project turns
on). There is deliberately no <code>Predicate_Failure</code> message: supplying
one would drag in <code>Ada.Exceptions</code>, which the
<code>light-tasking</code> runtime does not provide.</p>

<h2>Configuring a pad</h2>

<pre><code>procedure Configure
  (Pin   : Pin_Id;
   Mode  : Pin_Mode;                        --  Input | Output
   Pull  : Pull_Mode      := Floating;      --  Floating | Pull_Up | Pull_Down
   Drive : Drive_Strength := Drive_Medium);</code></pre>

<p><code>Drive_Strength</code> is the IO_MUX <code>FUN_DRV</code> field &mdash;
<code>Drive_Weak</code>, <code>Drive_Medium</code>, <code>Drive_Strong</code>,
<code>Drive_Strongest</code>, roughly 5 / 10 / 20 / 40&nbsp;mA. Output pads get
their driver enabled; input pads get the input buffer enabled.</p>

<p class="warn"><strong><code>Configure</code> is for plain software GPIO
only.</strong> It always routes the pad through the GPIO matrix as a
software-controlled pin (IO_MUX <code>MCU_SEL = 1</code>, GPIO output index 256).
Routing a pad to a <em>peripheral</em> signal is the job of that peripheral's own
<code>Configure_Pins</code> &mdash; <code>ESP32S3.I2C.Configure_Pins</code>,
<code>ESP32S3.SPI</code>'s, and so on &mdash; which programs the matrix directly.
Calling <code>GPIO.Configure</code> on a pad you have handed to a peripheral
takes it back.</p>

<h2>What is atomic, and what is not</h2>

<table>
  <thead><tr><th>Operation</th><th>Mechanism</th><th>Concurrency</th></tr></thead>
  <tbody>
    <tr><td><code>Set (Pin)</code></td><td>Hardware W1TS bank</td><td>Atomic in silicon &mdash; safe to call concurrently as-is</td></tr>
    <tr><td><code>Clear (Pin)</code></td><td>Hardware W1TC bank</td><td>Atomic in silicon</td></tr>
    <tr><td><code>Write (Pin, On)</code></td><td>W1TS or W1TC</td><td>Atomic in silicon</td></tr>
    <tr><td><code>Read (Pin)</code></td><td>A plain load</td><td>Pure read &mdash; always safe</td></tr>
    <tr><td><code>Configure (…)</code></td><td>Read-modify-write</td><td>Serialised through a protected object</td></tr>
    <tr><td><code>Toggle (Pin)</code></td><td>Read-modify-write</td><td>Serialised through a protected object</td></tr>
  </tbody>
</table>

<p>The write-1-to-set and write-1-to-clear banks are why the first three need no
lock at all: the CPU never reads the output register, so two tasks driving two
different pins cannot lose each other's update. <code>Configure</code> and
<code>Toggle</code> must read before they write, so they take the lock.</p>

<p class="note">The lock keeps the <em>registers</em> consistent, not your
<em>intent</em>. Two tasks driving the same pin still race over what the pin
should be; that is the application's problem, and no driver can solve it for
you. Note also that the protected object means this package needs a tasking
runtime &mdash; every profile here has one.</p>

<h2>Pin interrupts</h2>

<p>The GPIO peripheral has exactly <strong>one</strong> interrupt source: the OR
of every pin's latched status. <code>ESP32S3.GPIO.Interrupts</code> owns that
source, routes it to the runtime's level-2 device slot
(<code>Ada.Interrupts.Names.Device_L2_1</code>, CPU_INT 20), and demuxes by
status to call your per-pin action. It takes a level-2 rather than a level-3
slot because on an RGB-LCD board both L3 slots are already spoken for &mdash; the
LCD engine's relock and the GDMA end-of-frame.</p>

<pre><code>type Trigger is (Rising_Edge, Falling_Edge, Any_Edge, Low_Level, High_Level);
type Callback is access procedure;

procedure Enable (Pin : Pin_Id; On : Trigger; Action : Callback)
  with Pre =&gt; Action /= null;

procedure Disable (Pin : Pin_Id);</code></pre>

<p>Jorvik attaches handlers statically, so you never pass an ISR &mdash; you
register a callback that the module's own ISR invokes. The pin's input buffer
must be on, which <code>GPIO.Configure</code> already arranges.</p>

<h2>The one rule you cannot break</h2>

<p class="warn"><strong>The callback must be closure-free and
library-level.</strong> On this target, stacks live in the data-bus SRAM window,
whose instruction-bus alias is a <em>different address</em>. A GNAT
<strong>trampoline</strong> &mdash; the small stack stub emitted when you take
<code>'Access</code> of a <em>nested</em> subprogram that references up-level
variables &mdash; is therefore not executable, and calling it faults with
<code>InstrFetchProhibited</code>: a silent hang, not a clean error.</p>

<p>The cure is a restriction that makes the compiler <em>reject</em> the
trampoline at the <code>'Access</code> line instead of emitting one:</p>

<pre><code>pragma Restrictions (No_Implicit_Dynamic_Code);</code></pre>

<p class="warn"><strong>Whether you already have it depends on your
profile.</strong> Compiling a nested callback that captures a local, against each
runtime in turn:</p>

<table>
  <thead><tr><th>Profile</th><th>Without the restriction</th><th>With it</th></tr></thead>
  <tbody>
    <tr><td><code>light-tasking</code></td>
        <td><strong>Rejected</strong> — the restriction is implicit in this runtime</td>
        <td>Rejected</td></tr>
    <tr><td><code>embedded</code></td>
        <td><strong>Compiles clean</strong> — and faults on hardware</td>
        <td>Rejected</td></tr>
    <tr><td><code>full</code></td>
        <td><strong>Compiles clean</strong> — and faults on hardware</td>
        <td>Rejected</td></tr>
  </tbody>
</table>

<p>So on <code>embedded</code> and <code>full</code> — the profiles this guide
recommends — nothing stops you by default. The HAL opts itself in, which is why
driver code is safe; your own project is not until you do the same. It is two
steps.</p>

<p><strong>1. Create <code>no_dynamic_code.adc</code></strong> next to your
<code>app.gpr</code>, containing exactly one line:</p>

<pre><code>pragma Restrictions (No_Implicit_Dynamic_Code);</code></pre>

<p><strong>2. Name it in <code>app.gpr</code>'s <code>Compiler</code>
package</strong> — one attribute, alongside the switches the scaffold already
wrote. The path is relative to the project file:</p>

<pre><code>   package Compiler is
      for Switches ("Ada") use ("-O2", "-g");
      for Local_Configuration_Pragmas use "no_dynamic_code.adc";   --  &lt;-- add this
   end Compiler;</code></pre>

<p>From then on the mistake is a build error naming the file that forbade it,
pointing at the exact column of the <code>'Access</code>:</p>

<pre><code>u.adb:9:24: error: violation of restriction "No_Implicit_Dynamic_Code"
                   at no_dynamic_code.adc:1</code></pre>

<p>Under <code>light-tasking</code>, where the restriction is already implicit,
the same mistake reads <code>violation of implicit restriction</code> and names
no file.</p>

<h2>The idiom that works</h2>

<p>A library-level package holding an atomic flag, with the real work done by a
task. This is the shape used by the in-tree interrupt clients:</p>

<pre><code>--  imu_irq.ads -- library level, no enclosing subprogram, no closure
package IMU_IRQ is
   Fired : Boolean := False
     with Atomic, Volatile;

   procedure Handler;
end IMU_IRQ;

--  imu_irq.adb
package body IMU_IRQ is
   procedure Handler is
   begin
      Fired := True;   --  latch only; the task does the slow work
   end Handler;
end IMU_IRQ;</code></pre>

<p>The callback runs in <strong>interrupt context</strong>, inside a protected
action at the level-2 ceiling. Keep it short; do not call a lower-ceiling
protected object; do not block; and do not touch a slow bus like I2C from
inside it. Set an <code>Atomic</code> flag or a
<code>Suspension_Object</code>, and let a normal task at task level do the
rest.</p>
"""),

# ---------------------------------------------------------------- 13
dict(
slug="14-i2c",
nav="I2C in depth",
title="I2C in depth",
lede="A master you cannot use wrongly: the raw registers are unreachable, the "
     "host is owned by an RAII session that releases itself even through an "
     "exception, and payload length is not a thing you have to think about.",
body="""
<h2>Why you cannot reach the registers</h2>

<p>The unsynchronised register driver lives in a <em>private child</em>,
<code>ESP32S3.I2C.Engine</code>, which cannot be <code>with</code>ed from outside
that subtree. <code>ESP32S3.I2C</code> is the only interface an application sees,
so the raw primitives cannot be called by accident. Access to the hardware is
always mediated.</p>

<h2>One-time setup</h2>

<p>Call these once per host at startup, single-threaded, before any task contends
for the bus:</p>

<pre><code>procedure Setup (Host : I2C_Host; Clock_Hz : Positive := 100_000);

procedure Configure_Pins
  (Host : I2C_Host; Scl : ESP32S3.GPIO.Pin_Id; Sda : ESP32S3.GPIO.Pin_Id);</code></pre>

<p><code>I2C_Host</code> is <code>I2C0</code> or <code>I2C1</code>.
<code>Configure_Pins</code> routes SCL and SDA to physical pads as open-drain
lines <em>with the internal pull-ups enabled</em>, so a quick bring-up needs no
external resistors. The pin arguments are <code>Pin_Id</code>, so a reserved pad
is rejected at compile or run time exactly as on the
<a href="13-gpio.html">GPIO page</a>.</p>

<p class="note">Internal pull-ups are weak. They are fine on a short bench wire
at 100&nbsp;kHz; put real resistors on a production bus, especially at
400&nbsp;kHz or with any cable length.</p>

<h2>Ownership: the Session</h2>

<p>Each host is guarded by a protected object, and <code>Acquire</code> hands out
a <code>Session</code> that owns it exclusively. Other tasks suspend in
<code>Acquire</code> until it is released.</p>

<pre><code>type Session is limited private;    --  limited: cannot be copied
                                   --  controlled: releases itself on scope exit</code></pre>

<p>Because <code>Session</code> is a controlled type, it releases the host
<strong>automatically on scope exit &mdash; including during exception
unwinding</strong>. A fault between <code>Acquire</code> and <code>Release</code>
cannot leak the lock and wedge every other task on the bus. <code>Release</code>
remains available to hand the host back early, and is idempotent.</p>

<p>Two exceptions enforce the ordering, rather than letting misuse fail
quietly:</p>

<table>
  <thead><tr><th>Exception</th><th>Raised when</th></tr></thead>
  <tbody>
    <tr><td><code>Not_Initialized</code></td>
        <td><code>Acquire</code> on a host that was never <code>Setup</code>.</td></tr>
    <tr><td><code>Not_Owned</code></td>
        <td>A transaction attempted with a session that holds no host. Both
            <code>Write</code> and <code>Read</code> reach the hardware through
            one ownership-checked gateway, so this fails loudly.</td></tr>
  </tbody>
</table>

<p>The API also carries contracts: <code>Acquire</code> has
<code>Post =&gt; Is_Held (S)</code>, the transactions have
<code>Pre =&gt; Is_Held (S)</code>, and <code>Release</code> has
<code>Post =&gt; not Is_Held (S)</code>.</p>

<p class="note">The protected object arbitrates <em>ownership only</em>. The
blocking transaction itself runs <strong>outside</strong> the lock &mdash; the
lock is never held across the bus busy-wait, so a slow device cannot stall the
protected object.</p>

<h2>The three transactions</h2>

<pre><code>procedure Write
  (S : Session; Addr : Slave_Address; Data : Byte_Array;
   Success : out Boolean; Check_Ack : Boolean := True);

procedure Read
  (S : Session; Addr : Slave_Address; Data : out Byte_Array;
   Success : out Boolean);

procedure Write_Read
  (S : Session; Addr : Slave_Address; Tx : Byte_Array;
   Rx : out Byte_Array; Success : out Boolean);</code></pre>

<ul>
  <li><strong><code>Write</code></strong> &mdash; START, <code>Addr&lt;&lt;1 |
      W</code>, the data bytes, STOP. <code>Success</code> is True only if the
      slave ACKed the address and every byte.</li>
  <li><strong><code>Read</code></strong> &mdash; START, <code>Addr&lt;&lt;1 |
      R</code>, then <code>Data'Length</code> bytes, ACKing all but the last and
      NACKing the last, STOP. A zero-length read returns
      <code>Success =&gt; False</code>.</li>
  <li><strong><code>Write_Read</code></strong> &mdash; one transaction with a
      <strong>REPEATED START</strong> between the phases and no STOP separating
      them, so the slave sees a single command. This is what a "write the
      register index, then read it back" device requires, and it is precisely
      what back-to-back <code>Write</code> then <code>Read</code> calls
      <em>cannot</em> express.</li>
</ul>

<h2>Length is not your problem</h2>

<p>The package exports a constant that is easy to misread:</p>

<pre><code>Max_Transfer : constant := 32;   --  the FIFO depth -- NOT a transfer limit</code></pre>

<p>All three transactions take payloads of <strong>any length</strong>. The
driver refills the transmit FIFO (or drains the receive FIFO) mid-transaction
using the command FSM's <code>END</code> opcode, which pauses the sequence with
the bus still held. The length is therefore invisible on the wire: a 200-byte
write is still <em>one</em> START&hellip;STOP transaction.</p>

<p>That matters more than it sounds. For a device where a STOP means
end-of-command &mdash; an EEPROM page write, say &mdash; a driver that silently
split at 32 bytes would produce a subtly corrupt device, not an error.</p>

<h2>Scanning the bus</h2>

<p>Passing a <code>Data</code> array of length zero does not skip the
transaction &mdash; it sends a complete one with no payload: START, the
address byte, then STOP. Nothing is written to the device, so the only thing
the exchange can tell you is whether something out there pulled SDA low to
acknowledge its address. That answer arrives in <code>Success</code>, which is
exactly what a bus scan needs, so scanning is the same call in a loop over the
address range:</p>

{{sample:i2c_scan.adb}}

<p>Two details in there are easy to get wrong. <code>(1 .. 0 =&gt; 0)</code> is
how you write a null array aggregate &mdash; a range whose upper bound is below
its lower one. And <code>Slave_Address</code> is a <code>Natural</code> subtype
while <code>Put_Hex</code> takes an <code>Interfaces.Unsigned_32</code>, so the
conversion is required; without it the compiler says
<code>expected type "Interfaces.Unsigned_32", found type
"Standard.Integer"</code>.</p>

<p><code>Check_Ack =&gt; False</code> on <code>Write</code> does the opposite:
it clocks the whole transaction out regardless of whether anything answers,
which is how the self-test exercises the bus with no device attached.</p>

<h2>The self-test, and what it cannot prove</h2>

<p><code>./x run esp32s3_i2c_loopback</code> needs no wiring and no device. It
checks three things: that an ACK-checked write to an absent address correctly
reports NACK; that the same write with <code>Check_Ack =&gt; False</code> runs to
completion; and that a session which goes out of scope through an
<em>exception</em> still releases its host, so a following <code>Acquire</code>
does not deadlock.</p>

<p class="warn"><strong>There is no internal loopback for I2C, and there cannot
be.</strong> SDA is a bidirectional open-drain (wired-AND) node: both ends must
drive <em>and</em> read the same wire. The ESP32-S3's GPIO matrix gives each pad
exactly one output source, so two on-chip controllers cannot be wired-AND onto
one pad. Cross-coupling two pads breaks the master's mandatory write-readback; a
single shared pad breaks the slave's mandatory ACK. Verifying the read direction
and the ACK handshake needs a real shared bus &mdash; an external device, or a
jumper tying two pads together.</p>

<p class="note">The controlled <code>Session</code> needs finalization, so I2C is
part of the HAL's <a href="08-profiles.html"><code>embedded</code></a> subset and
is excluded under <code>light-tasking</code>. The loopback example's
<code>build.sh</code> sets <code>ESP32S3_RTS_PROFILE=embedded</code>
accordingly.</p>
"""),

# ---------------------------------------------------------------- 14
dict(
slug="15-spi",
nav="SPI in depth",
title="SPI in depth",
lede="One host, several devices, each with its own clock, mode and chip select "
     "&mdash; applied per hold rather than per host. Plus a DMA transfer whose "
     "alignment rules are preconditions, not comments.",
body="""
<h2>Two hosts, and two that are not offered</h2>

<pre><code>type SPI_Host is (SPI2, SPI3);</code></pre>

<p>SPI0 and SPI1 are the flash and PSRAM controllers. They are deliberately
absent from the type &mdash; you cannot name them, so you cannot take out the
memory your program is executing from. As with I2C, the raw register driver is a
private child (<code>ESP32S3.SPI.Engine</code>) that cannot be
<code>with</code>ed from outside the subtree.</p>

<h2>What is per-host and what is per-device</h2>

<p>This is the design decision that shapes the whole API. Bring-up splits in
two:</p>

<pre><code>--  Per HOST, once at startup, single-threaded:
procedure Setup (Host : SPI_Host);                --  master mode + claim a GDMA channel

procedure Configure_Pins                          --  the SHARED wires
  (Host : SPI_Host;
   Sclk : ESP32S3.GPIO.Optional_Pin;
   Mosi : ESP32S3.GPIO.Optional_Pin;
   Miso : ESP32S3.GPIO.Optional_Pin;
   Cs   : ESP32S3.GPIO.Optional_Pin := No_Pin);</code></pre>

<p>Notice what is <em>not</em> there: <strong>mode and clock</strong>. Those are
properties of a <em>device</em>, not of the bus, so they are applied at
<code>Acquire</code> under the exclusive hold. A flash at mode 0 and 8&nbsp;MHz
and a display at mode 3 and 40&nbsp;MHz can therefore share one host without
either one reprogramming the controller underneath the other:</p>

<pre><code>procedure Acquire
  (S         : in out Session;
   Host      : SPI_Host;
   Mode      : SPI_Mode := 0;                  --  0 .. 3, this device's
   Clock_Hz  : Positive := 1_000_000;          --  this device's
   Sclk, Mosi, Miso : ESP32S3.GPIO.Optional_Pin := No_Pin;
   CS_Pin    : ESP32S3.GPIO.Optional_Pin := No_Pin;
   Select_CB : CS_Select := null;
   Ctx       : System.Address := System.Null_Address)
with Post =&gt; Is_Held (S);</code></pre>

<p>The <code>Sclk</code>/<code>Mosi</code>/<code>Miso</code> arguments are
normally left as <code>No_Pin</code>, meaning "keep the host's routing". Set them
only for the rare device wired to a <em>different</em> set of pads on the same
controller; the GPIO matrix is then re-routed for the duration of that hold.</p>

<p>The session is the same limited, controlled RAII handle as
<a href="14-i2c.html">I2C</a>'s: it releases the host on scope exit including
during exception unwinding, <code>Release</code> is available (and idempotent)
to hand it back early, and <code>Not_Initialized</code> /
<code>Not_Owned</code> enforce the ordering. One addition worth knowing:</p>

<pre><code>pragma Assertion_Policy (Pre =&gt; Check);   --  in the spec of ESP32S3.SPI itself</code></pre>

<p>The SPI (and GDMA) specs pin their own assertion policy, so their
preconditions are checked whether or not the build enables assertions
generally.</p>

<h2>Chip select, three ways</h2>

<p>"Chip select" is not always one pin, so the driver takes it three ways, in
order of preference:</p>

<table>
  <thead><tr><th>You pass</th><th>What happens</th><th>Use it when</th></tr></thead>
  <tbody>
    <tr><td><code>CS_Pin =&gt; 21</code></td>
        <td>The driver drives that GPIO itself as an active-low software select:
            configures the pad as an output, parks it deselected, and holds it
            low across the whole transaction.</td>
        <td><strong>The common case.</strong> One device, one plain GPIO.</td></tr>
    <tr><td><code>Select_CB =&gt; …, Ctx =&gt; …</code></td>
        <td>The driver calls your procedure with <code>Active =&gt; True</code>
            before the bytes move and <code>False</code> when the transaction
            ends.</td>
        <td>The select is not one GPIO &mdash; several pins into a 3:8 decoder,
            an I/O-expander line.</td></tr>
    <tr><td>Neither</td>
        <td>The host's single hardware CS0, routed by
            <code>Configure_Pins</code>, toggles per <code>Transfer</code>.</td>
        <td>A single device that can live with per-transfer CS.</td></tr>
  </tbody>
</table>

<p>With <code>CS_Pin</code> or <code>Select_CB</code>, hardware CS0 is
<em>suppressed</em> for that hold, so it cannot disturb another device sharing
the bus.</p>

<h2>The callback rules, and why</h2>

<pre><code>type CS_Select is access procedure (Ctx : System.Address; Active : Boolean);</code></pre>

<p class="warn"><strong>It must be library-level with no captured state.</strong>
Same reason as the <a href="13-gpio.html">GPIO interrupt callback</a>: the HAL
builds under <code>No_Implicit_Dynamic_Code</code>, so a closure would emit a
GNAT trampoline that faults on the S3. Per-device state travels in
<code>Ctx</code> instead &mdash; that is exactly what the parameter is for.</p>

<p class="warn"><strong>It must be fast, non-blocking, and must not raise.</strong>
It runs while the bus lock is held, and again at scope exit during
finalization. Drive the line and return: no <code>delay</code>, no
<code>Acquire</code>, no I2C round-trip to an expander that might block.</p>

<h2>Holding CS across a multi-phase command</h2>

<p>Most SPI devices expect one command to arrive as opcode, then address, then
data, with CS held low throughout. If CS dropped between those phases the device
would see three separate commands. So bracket them:</p>

<pre><code>Select_Device (S, True);
Transfer (S, Opcode'Address,  Rx'Address, 1);
Transfer (S, Address'Address, Rx'Address, 3);
Transfer (S, Data'Address,    Rx'Address, N);
Select_Device (S, False);</code></pre>

<p><code>Select_Device</code> is a no-op for a hardware-CS session, where the
peripheral toggles CS0 per transfer anyway. And if an exception escapes between
the two calls, <code>Finalize</code> deselects <em>before</em> releasing the
host &mdash; a fault can never leave a device asserted on a bus another task is
about to take.</p>

<h2>Transfers are DMA, and the rules are preconditions</h2>

<pre><code>procedure Transfer (S : Session; Tx, Rx : System.Address; Length : Natural)
with Pre =&gt; Is_Held (S) and then Length in 1 .. 4095;

procedure Transfer (S : Session; Tx, Rx : ESP32S3.GDMA.DMA_Buffer; Length : Natural)
with Pre =&gt; Is_Held (S) and then Length in 1 .. 4095
            and then Length &lt;= Tx'Length and then Length &lt;= Rx'Length
            and then Tx'Length mod ESP32S3.GDMA.DMA_Alignment = 0
            and then Rx'Length mod ESP32S3.GDMA.DMA_Alignment = 0;</code></pre>

<p>Every transfer is full-duplex and blocking: <code>Tx</code> shifts out on
MOSI while MISO is captured into <code>Rx</code>. The 4095-byte ceiling is one
DMA descriptor; the precondition catches an out-of-range length that the engine
would otherwise drop <em>silently</em>.</p>

<p>Prefer the second overload. <code>DMA_Buffer</code> carries
<code>Alignment =&gt; 32</code>, so declaring one gets you an aligned start for
free, and the precondition additionally requires the buffer <em>footprint</em> to
be a whole number of 32-byte cache lines:</p>

<pre><code>Tx_Buf : ESP32S3.GDMA.DMA_Buffer (0 .. 63);   --  64 = 2 whole cache lines
Rx_Buf : ESP32S3.GDMA.DMA_Buffer (0 .. 63);</code></pre>

<p class="note"><strong>Why the size rule, not just alignment.</strong> Cache
maintenance for these buffers operates on whole 32-byte lines. A buffer whose
length is not a multiple of 32 shares its last line with whatever is next in
memory, so invalidating it would reach into a neighbouring object. The
precondition makes that unrepresentable rather than a rare corruption. Transfer
buffers live in internal SRAM.</p>

<h2>Changing speed mid-hold</h2>

<pre><code>procedure Set_Clock (Host : SPI_Host; Hz : Positive);   --  ~80 kHz .. 80 MHz</code></pre>

<p>For a device that changes speed <em>within</em> one hold &mdash; the classic
case being an SD card, which must complete its initialisation handshake slowly
and then run fast. It re-programs only the bit clock, with no GDMA re-claim.</p>

<h2>Proving the bus with no wiring</h2>

<pre><code>procedure Enable_Loopback (Host : SPI_Host; Pad : ESP32S3.GPIO.Pin_Id);</code></pre>

<p>Routes MOSI back to MISO through a single pad, so
<code>./x run esp32s3_spi_loopback</code> exercises the real data path &mdash;
clock divider, mode, DMA in both directions &mdash; with nothing attached. Two
in-tree examples then show the shared-bus pattern against real silicon:
<code>esp32s3_w25q</code> (a 32&nbsp;MB NOR flash) and
<code>esp32s3_tlv2556</code> (a 12-bit ADC), each with its CS on an ordinary
GPIO the driver drives.</p>
"""),

# ---------------------------------------------------------------- 15
dict(
slug="16-uart",
nav="UART in depth",
title="UART in depth",
lede="The one driver here with no setup call at all: you cannot touch a port "
     "you do not hold. Plus interrupt-driven RX, an Ada declaration that must "
     "be written a particular way, and a pin-routing trap.",
body="""
<h2>Three ports, all of them yours</h2>

<pre><code>type UART_Port is (UART0, UART1, UART2);</code></pre>

<p>On most ESP32 boards UART0 is the ROM console and effectively spoken for.
Not here: this runtime puts the console on the USB-Serial-JTAG peripheral, so
<strong>UART0's pads are free to repurpose</strong> like any other port.</p>

<h2>No setup call &mdash; ownership comes first</h2>

<p><a href="14-i2c.html">I2C</a> and <a href="15-spi.html">SPI</a> both have a
port-level <code>Setup</code> you call before anyone contends. UART deliberately
has none. <code>Acquire</code> takes the port <em>and</em> shapes it in one
call, and every later configuration call requires the held session:</p>

<pre><code>Acquire (S, UART1);                           --  bare: 115200 8-N-1
Acquire (S, UART1, Tx =&gt; 17, Rx =&gt; 16);       --  full-duplex link
Acquire (S, UART1, Rx =&gt; 18);                 --  RX only (e.g. a GPS)
Acquire (S, UART1, Tx =&gt; 17, Rx =&gt; 16,
                   Rts =&gt; 19, Cts =&gt; 20);     --  + RTS/CTS flow control</code></pre>

<p>The parameters are typed rather than numeric, so a nonsense frame format does
not reach the hardware: <code>Baud : Baud_Rate</code> (300 .. 5_000_000),
<code>Bits : Data_Bits</code> (5 .. 8), <code>Parity : Parity_Mode</code>
(<code>None</code>, <code>Even</code>, <code>Odd</code>) and
<code>Stop : Stop_Bits</code> (<code>One</code>, <code>Two</code>).</p>

<p>So changing a setting requires owning the port and can never race another
task. There is no way to reconfigure a UART somebody else is mid-transfer on,
because there is no API that takes a port instead of a session.</p>

<p class="note"><strong><code>Acquire</code> sets the full state.</strong> The
first <code>Acquire</code> of a port creates the controller; every
<code>Acquire</code> then re-applies baud, frame format and pin routing. A
session does <em>not</em> inherit the previous holder's settings &mdash; you get
exactly what you asked for, defaulting to 115200 8-N-1 with nothing routed.</p>

<h2>Flow control</h2>

<p>Passing <code>Rts</code> enables RX flow control: the controller drives RTS to
pause the peer once our RX FIFO reaches <code>Rx_Flow_Threshold</code> bytes of
its 128. Passing <code>Cts</code> enables TX flow control: the transmitter only
sends while the peer asserts CTS. Inputs (RX, CTS) get an internal pull-up, so an
idle line reads high rather than floating.</p>

<h2>The pin-routing trap</h2>

<p class="warn"><strong><code>No_Pin</code> does two different things at
once.</strong> In <code>Configure_Pins</code> (and in
<code>Reconfigure</code>), <code>No_Pin</code> means "leave this line's
<em>routing</em> alone" &mdash; which is what <code>Acquire</code>'s defaults
rely on. But the flow-control enable bits are written in full every time, so
that same <code>No_Pin</code> still turns that line's <strong>flow control
off</strong>. If you re-route TX and RX on a link that had RTS/CTS, and do not
name RTS and CTS again, you keep the wires and lose the flow control.</p>

<p>A second, subtler one: a named output line <strong>moves</strong>. The pad it
used to drive is released back to a pulled-up input so it stops transmitting.
That is necessary because the GPIO matrix selects an output <em>per pad</em>, not
per signal &mdash; without the release, the old pad would go on driving TXD
alongside the new one.</p>

<h2>Full state versus one attribute</h2>

<table>
  <thead><tr><th>Call</th><th>Effect</th></tr></thead>
  <tbody>
    <tr><td><code>Reconfigure (S, …)</code></td>
        <td>Re-applies the <strong>whole</strong> baud + frame + routing state on
            the held port, without releasing it. An omitted attribute returns to
            its default; an omitted pin is unrouted.</td></tr>
    <tr><td><code>Set_Baud</code>, <code>Set_Data_Bits</code>,
            <code>Set_Parity</code>, <code>Set_Stop_Bits</code></td>
        <td>Read-modify-write of <strong>just</strong> that attribute, effective
            immediately, leaving everything else (including routing)
            untouched.</td></tr>
    <tr><td><code>Set_Inversion</code></td>
        <td>Inverts (or un-inverts) each line's polarity independently. Sets the
            full state of all four lines, so an omitted one is cleared.</td></tr>
  </tbody>
</table>

<p>Reach for the finer setters when you mean "change one thing" &mdash;
<code>Reconfigure</code> with a single argument silently resets the rest.</p>

<h2>Interrupt-driven RX</h2>

<p>Polled <code>Read</code> is fine for a device that answers when spoken to. It
is not fine for one that streams asynchronously &mdash; a modem, a GPS &mdash;
because a burst can overflow the 128-byte hardware FIFO between your calls.
<code>Enable_Buffered_Rx</code> switches the port to an RX interrupt (FIFO-full
plus byte-timeout) that drains the FIFO into a ring buffer the instant bytes
arrive; <code>Read</code> and <code>Available</code> then serve from that
buffer.</p>

<p>The buffer is caller-owned &mdash; you pass an
<code>Rx_Buffer_Access</code> &mdash; and its size <em>is</em> the ring depth. It must
outlive the port and must be library-level, because the RX ISR writes it &mdash;
never a stack object.</p>

<p class="warn"><strong>Declare it without bounds.</strong> This is a real Ada
constraint, not a style preference:</p>

<p>It goes in a package, not in your procedure. Declaring it inside the
subprogram that calls <code>Enable_Buffered_Rx</code> fails with
<code>non-local pointer cannot point to local object</code> &mdash; the language
enforcing the same lifetime rule the ISR needs:</p>

{{sample:uart_buf.ads}}

<pre><code>--  then, anywhere:
ESP32S3.UART.Enable_Buffered_Rx (ESP32S3.UART.UART1, Uart_Buf.Ring'Access);</code></pre>

<p>Get it wrong and the compiler tells you precisely, which is worth
recognising because the error lands on the <code>'Access</code> line while the
actual mistake is up at the declaration:</p>

<pre><code>ring.ads:8:04: warning: aliased object has explicit bounds
ring.ads:8:04: warning: declare without bounds (and with explicit initialization)
ring.ads:8:04: warning: for use with unconstrained access
ring.ads:10:28: error: object subtype must statically match designated subtype</code></pre>

<p>Call it once at startup, single-threaded, before any task acquires the port;
it brings the port up itself if nothing has acquired it yet.</p>

<h2>Repairing a skewed RX FIFO</h2>

<pre><code>procedure Repair_Rx (S : Session);</code></pre>

<p>An RX FIFO overflow can leave the hardware's read and write pointers skewed,
after which the port serves correct bytes in the wrong order &mdash; a rotation,
not a corruption, which is far more confusing to debug than dropped data.
<code>Repair_Rx</code> re-aligns them. It is cheap and safe on a quiet line and a
no-op when the pointers are already sane, so it costs nothing to call after a
suspected overrun.</p>

<h2>Transfers</h2>

<ul>
  <li><strong><code>Write (S, Data)</code></strong> pushes to the TX FIFO,
      waiting for room. It returns once every byte is <em>queued</em> &mdash; not
      necessarily shifted out of the pin. Do not power something down or drop
      the line immediately after it returns.</li>
  <li><strong><code>Read (S, Data, Count)</code></strong> reads up to
      <code>Data'Length</code> bytes, waiting briefly for each, and reports how
      many actually arrived. A short read is a timeout, not an error &mdash;
      always use <code>Count</code>, never assume the buffer filled.</li>
  <li><strong><code>Available (S)</code></strong> is the number of bytes waiting
      now.</li>
  <li><strong><code>Release (S)</code></strong> hands the port back early, for a
      session whose scope outlives its use of the link. It is idempotent, and
      scope exit does it for you &mdash; so it is a convenience, never an
      obligation.</li>
</ul>

<h2>A loopback that actually works on-chip</h2>

<pre><code>procedure Enable_Loopback (S : Session; On : Boolean := True);</code></pre>

<p>Unlike <a href="14-i2c.html">I2C</a>, where an internal loopback is
<em>impossible</em> because SDA is a wired-AND node, UART is push-pull and
unidirectional &mdash; so the controller's internal TX&rarr;RX loopback proves
the whole real data path: baud divider, frame format, TX FIFO, RX FIFO, with no
pins and no wiring.</p>

<p><code>./x run esp32s3_uart_loopback</code> runs three tests on that basis:
a known buffer at 115200 8-N-1 written and read back byte-exact; hardware RTS/CTS
flow control, with RTS matrix-looped to CTS so the CTS-gated transmitter
visibly stalls at a low threshold and then drains intact; and per-line
inversion, where inverting only TX breaks the link and inverting RX as well
makes both ends agree again.</p>
"""),

# ---------------------------------------------------------------- 16
dict(
slug="17-gdma",
nav="GDMA",
title="GDMA: the DMA engine everything else borrows",
lede="Five channel pairs, assigned at run time rather than wired per "
     "peripheral &mdash; and a buffer type whose rules exist because PSRAM is "
     "reached through a cache.",
body="""
<h2>Channels are a resource, not a fixture</h2>

<p>The S3 has one AHB GDMA block with <strong>five channel pairs</strong>
(0&nbsp;..&nbsp;4). Each pair has an independent transmit (OUT) and receive (IN)
path, and either can be wired to any peripheral through the GDMA crossbar. A
channel is therefore something you <em>claim</em>, not something a peripheral
owns:</p>

<pre><code>type Channel_Id is mod 5;
type Peripheral is (Mem2Mem, SPI2, SPI3, UHCI0, I2S0, I2S1, LCD_CAM, AES, SHA, ADC_DAC, RMT);

procedure Claim (C : in out Channel; Peri : Peripheral);
function  Is_Valid (C : Channel) return Boolean;
procedure Release (C : in out Channel);</code></pre>

<p><code>Claim</code> goes through a protected allocator, so two tasks can never
be handed the same channel. The <code>Channel</code> handle is limited
(non-copyable, so it cannot be aliased into another task) and controlled (it
releases on scope exit, including on an exception, so a channel cannot leak or
be reused through a stale copy). If all five are busy, <code>Claim</code> leaves
the handle invalid rather than raising &mdash; check <code>Is_Valid</code>.</p>

<p class="note">Once you hold a channel, only you touch its registers and
descriptors, so the transfer operations themselves need no further locking. This
is the same ownership pattern as <a href="15-spi.html">SPI</a> and
<a href="14-i2c.html">I2C</a>, and for the same reason.</p>

<h2>Why a buffer type exists</h2>

<p>DMA needs DMA-capable memory, and on this chip that is not a single rule:</p>

<ul>
  <li><strong>Internal SRAM</strong> always qualifies, at any alignment.</li>
  <li><strong>External PSRAM</strong> qualifies only when the buffer is
      cache-line (32-byte) aligned &mdash; the GDMA reaches PSRAM
      <em>through</em> the DCache, so the driver writes back and invalidates
      around each transfer.</li>
  <li><strong>Flash <code>.rodata</code></strong> is excluded. A
      <code>constant</code> aggregate still cannot be DMA'd.</li>
</ul>

<pre><code>DMA_Alignment : constant := 32;

type DMA_Buffer is array (Natural range &lt;&gt;) of Interfaces.Unsigned_8
  with Alignment =&gt; DMA_Alignment;

function Is_DMA_Capable (A : System.Address) return Boolean;</code></pre>

<p class="warn"><strong>Alignment is only half of it.</strong> The type carries
the aligned <em>start</em>; the operations' preconditions additionally demand a
whole-cache-line <em>size</em>. That is not implied by alignment and it matters:
the PSRAM write-back/invalidate rounds the region <strong>up</strong> to a whole
line, so a buffer ending mid-line would have the maintenance touch its
neighbour &mdash; discarding an adjacent object's dirty cached write. Size the
payload up to a multiple of 32 (128 bytes for 100 useful ones).</p>

<p>Hence the calling convention: <strong>pass the whole buffer plus a transfer
length</strong>, never a slice. Slicing to the length would fail the size
precondition, while the whole line-multiple buffer keeps every rounded
maintenance op inside itself.</p>

<pre><code>procedure Copy (C : Channel; Dst, Src : DMA_Buffer; Length : Natural)
with Pre =&gt; Length &lt;= Src'Length and then Length &lt;= Dst'Length
            and then Src'Length mod DMA_Alignment = 0
            and then Dst'Length mod DMA_Alignment = 0;</code></pre>

<p>These preconditions are pinned on with
<code>pragma Assertion_Policy (Pre =&gt; Check)</code> in the spec, so they hold
even when the build has assertions off &mdash; a buffer in flash or unaligned
PSRAM corrupts the transfer <em>silently</em>, which is exactly the failure worth
paying a check for.</p>

<h2>The three shapes of transfer</h2>

<table>
  <thead><tr><th>Call</th><th>Behaviour</th></tr></thead>
  <tbody>
    <tr><td><code>Copy</code></td>
        <td>Blocking memory-to-memory, completed by looping one channel's OUT
            path into its own IN path. Buffers <em>and</em> the driver's
            descriptors must be in internal SRAM, because the descriptor link
            address is a 20-bit field.</td></tr>
    <tr><td><code>Start</code></td>
        <td>Arms a single-buffer peripheral transfer in one
            <code>Direction</code> and returns immediately. You configure and
            start the peripheral separately; the GDMA moves data as the
            peripheral raises its DMA request.</td></tr>
    <tr><td><code>Start_Loop</code></td>
        <td>A single descriptor whose link points back at itself, so the engine
            replays the buffer forever with no gap between passes and no CPU
            involvement after the kick. Never completes on its own.</td></tr>
  </tbody>
</table>

<p><code>Direction</code> is <code>Mem_To_Periph</code> (the OUT path reads RAM
and feeds the peripheral) or <code>Periph_To_Mem</code>. A single descriptor
caps at <code>Max_Transfer</code> = 4095 bytes, the hardware's 12-bit
buffer-size field &mdash; which is where <a href="15-spi.html">SPI</a>'s
1&nbsp;..&nbsp;4095 precondition comes from.</p>

<h2>Beyond one descriptor: the framebuffer path</h2>

<p>For a buffer larger than 4095 bytes there is a chained ring: up to
<code>Max_Chain</code> = 256 descriptors that between them cover the buffer, the
last linking back to the first. This is the display path &mdash; stream an LCD
framebuffer to <code>LCD_CAM</code> continuously. The buffer may live in PSRAM
(32-byte aligned) and is written back before the loop starts. After the CPU draws
into a live framebuffer, <code>Flush</code> pushes the changes out so the running
DMA re-reads them.</p>

<p class="note">The descriptor ring is one shared internal-SRAM array, so exactly
one chained loop runs at a time.</p>

<h2>Completion, and an interrupt you must not take</h2>

<p>Completion is interrupt-driven rather than polled: <code>Wait</code> suspends
the calling task and the channel's end-of-transfer interrupt wakes it.</p>

<p class="warn">This driver <strong>owns <code>Device_L3_1</code>
(CPU_INT&nbsp;27)</strong>. An application must not attach its own handler
there. It is a level-3 slot rather than a level-2 one because the LCD RGB bounce
refill runs from this completion ISR and has to preempt the level-2 devices to
make its deadline.</p>

<h2>Proving the coherency path</h2>

<pre><code>type Self_Test_Result is (Passed_PSRAM, Passed_SRAM, Failed, No_Channel);
function Self_Test (Buf_A, Buf_B : System.Address) return Self_Test_Result;</code></pre>

<p>A memory-to-memory round trip between two buffers <em>of your choosing</em>,
which reports which memory it actually exercised. Hand it PSRAM buffers (from a
task whose stack is in PSRAM) and a <code>Passed_PSRAM</code> result means the
cache write-back/invalidate path really works on your board &mdash; not merely
that DMA works in SRAM. Buffers must be 32-byte aligned and at least 64 bytes.</p>
"""),

dict(
slug="18-i2s",
nav="I2S audio",
title="I2S: audio that only moves by DMA",
lede="The S3's I2S has no CPU FIFO at all &mdash; samples reach the wire only "
     "through the DMA crossbar. That single fact shapes the whole API, "
     "including gapless playback and capture that runs underneath it.",
body="""
<h2>No FIFO, so no polled path</h2>

<p>Two controllers, <code>I2S0</code> and <code>I2S1</code>. Unlike the
<a href="16-uart.html">UART</a>, neither has a CPU-accessible FIFO: data flows
<em>only</em> through <a href="17-gdma.html">GDMA</a>. So bringing a port up
claims a GDMA channel, and that is a heavyweight, once-per-port resource &mdash;
which is why acquisition works slightly differently here:</p>

<p class="note">The <strong>first</strong> <code>Acquire</code> of a port opens
it at the given configuration and claims its channel. Later <code>Acquire</code>
calls <em>reuse it as-is</em> &mdash; they do not re-open the port and do not
inherit a new configuration. To change the audio format on a port you already
hold, call <code>Reconfigure</code> (which re-claims the channel). This is the
opposite of <a href="16-uart.html">UART</a>, where every <code>Acquire</code>
re-applies the full state.</p>

<pre><code>procedure Acquire
  (S           : in out Session;
   Port        : I2S_Port;
   Sample_Rate : Positive     := 16_000;
   Bits        : Sample_Bits  := Bits_16;      --  Bits_8 | 16 | 24 | 32
   Mode        : I2S_Mode     := Standard;     --  Standard | PDM
   Bclk, Ws, Dout, Din, Mclk : ESP32S3.GPIO.Optional_Pin := No_Pin);</code></pre>

<p>Every pin is optional, so a link routes only what it uses &mdash; omit
<code>Din</code> for a TX-only DAC, omit <code>Dout</code> for an RX-only
microphone. <code>Mclk</code> drives a codec's master-clock input and exists
only on I2S0; leave it unrouted for codecs that clock from BCLK.</p>

<h2>Typed sample buffers</h2>

<pre><code>type PCM_8  is array (Natural range &lt;&gt;) of Interfaces.Integer_8;
type PCM_16 is array (Natural range &lt;&gt;) of Interfaces.Integer_16;
type PCM_32 is array (Natural range &lt;&gt;) of Interfaces.Integer_32;</code></pre>

<p>The element type fixes the on-wire width, so the driver derives the byte count
itself &mdash; no caller-side <code>* 2</code> &mdash; and the typed
<code>Write</code>/<code>Read</code>/<code>Transfer</code> <strong>check the
buffer's width against the port's configured <code>Bits</code></strong>. They are
signed two's-complement, as PCM is. A <code>PCM_32</code> buffer carries both 24-
and 32-bit samples, since both occupy a 32-bit slot. For already-framed bytes or
an opaque bit pattern there are <code>*_Raw</code> primitives, including
<code>DMA_Buffer</code> overloads with the usual alignment and size
preconditions.</p>

<h2>Standard and PDM are the same buffers</h2>

<p><code>I2S_Mode</code> selects what sits between the buffer and the wire:</p>

<ul>
  <li><strong><code>Standard</code></strong> &mdash; ordinary I2S/TDM. The PCM
      buffer appears verbatim on the data line, BCLK and WS framed. BCLK is
      <code>Sample_Rate * Bits * 2</code>.</li>
  <li><strong><code>PDM</code></strong> &mdash; the hardware sigma-delta
      converters are inserted. On TX, PCM2PDM turns each sample into a 1-bit
      pulse-density stream for a class-D amp or an RC low-pass; on RX, PDM2PCM
      decimates a PDM microphone back to PCM. The serial clock runs at
      <code>Sample_Rate * 128</code>, the oversample ratio.</li>
</ul>

<p>The DMA still moves ordinary PCM either way, so your transfer calls are
unchanged &mdash; only the on-wire format differs.</p>

<p class="warn">The PDM converters <strong>high-pass filter</strong>, removing
DC. A constant level does not survive a PDM round trip, so do not write a
self-test that expects one to.</p>

<h2>Gapless playback</h2>

<p>Three escalating options, all built on the GDMA behaviour from the previous
step:</p>

<table>
  <thead><tr><th>Call</th><th>What it gives you</th></tr></thead>
  <tbody>
    <tr><td><code>Write</code> / <code>Read</code> / <code>Transfer</code></td>
        <td>One blocking buffer, up to 4095 bytes.
            <code>Transfer</code> is full duplex &mdash; shift out and capture
            simultaneously, same length.</td></tr>
    <tr><td><code>Start_Continuous</code></td>
        <td>A self-looping descriptor replays one buffer forever with
            <strong>no gap</strong> and no CPU involvement. The buffer must stay
            valid, live in internal SRAM, and should hold a whole number of wave
            periods so the wrap is seamless. <code>Stop</code> ends it.</td></tr>
    <tr><td><code>Start_Stream</code> + <code>Await_Half</code></td>
        <td>Gapless double-buffered streaming: the two halves of one buffer loop
            forever, and <code>Await_Half</code> tells you which half the
            hardware has finished so you can refill the other. This is how you
            play audio longer than a buffer.</td></tr>
  </tbody>
</table>

<h2>Capturing while playing</h2>

<p><code>Read</code> drives the receive path as a transaction. When a continuous
transmit is already running, use <code>Capture</code> instead &mdash; it fills a
buffer <em>without disturbing the TX path</em>, so recording can run underneath
playback. There is a streaming mirror of it too, the receive counterpart of
<code>Start_Stream</code>.</p>

<h2>Self-test without wiring</h2>

<pre><code>procedure Enable_Loopback (S : Session; Pad : ESP32S3.GPIO.Pin_Id);</code></pre>

<p>TX and RX share WS and BCK internally through the hardware
<code>SIG_LOOPBACK</code> bit, with the data line looped through one pad, so
<code>./x run esp32s3_i2s_loopback</code> proves the real DMA path in both
directions byte-exact with nothing attached. <code>Configured_Bits</code> reports
the width the held port is currently set to, which is what the typed transfers
check against.</p>
"""),

dict(
slug="19-lcd",
nav="LCD (i80 / RGB)",
title="LCD: two very different display modes",
lede="One controller, two personalities &mdash; a command-driven 8-bit i8080 "
     "bus that streams a buffer on demand, and a continuously-refreshed RGB "
     "panel that never stops.",
body="""
<h2>The i8080 mode</h2>

<p><code>ESP32S3.LCD</code> drives the LCD half of the LCD_CAM controller as an
8-bit Intel-8080 parallel master: a byte buffer is streamed out the data bus, one
byte per pixel clock, over <a href="17-gdma.html">GDMA</a>. It suits any 8-bit
parallel sink, not only displays.</p>

<pre><code>type Data_Pins is array (0 .. 7) of ESP32S3.GPIO.Optional_Pin;

procedure Acquire
  (S       : in out Session;
   Pclk_Hz : Positive  := 1_000_000;
   Data    : Data_Pins := (others =&gt; No_Pin);
   Pclk    : ESP32S3.GPIO.Optional_Pin := No_Pin);</code></pre>

<p>The pixel clock is quantised: you get
<code>20&nbsp;MHz / round (20&nbsp;MHz / Pclk_Hz)</code>, so ask for a divisor of
20&nbsp;MHz if the exact rate matters. Unlike <a href="18-i2s.html">I2S</a>,
bringing the controller up does <strong>not</strong> tie up a GDMA channel &mdash;
<code>Transmit</code> claims one only for the duration of a transfer, so the
channel is available to other peripherals between frames.</p>

<pre><code>procedure Transmit (S : Session; Tx : ESP32S3.GDMA.DMA_Buffer;
                    Length : Natural; Ok : out Boolean);</code></pre>

<p>Blocking, 1&nbsp;..&nbsp;4095 bytes (the single-descriptor limit again), buffer
in internal SRAM, with the usual <code>DMA_Buffer</code> alignment and
whole-cache-line size preconditions. <code>Enable_Clock_Out</code> free-runs the
pixel clock on a pad with no data transaction, which is how you check the clock
divider on a scope before trusting a panel.</p>

<h2>The RGB mode</h2>

<p>A TFT panel driven by continuous HSYNC / VSYNC / DE / PCLK timing, rather than
by commands. This is a different discipline: the panel must be refreshed forever,
so the framebuffer streams from a chained GDMA descriptor ring
(<a href="17-gdma.html">step 16</a>), which is exactly why that ring exists.</p>

<pre><code>type RGB_Data_Pins  is array (0 .. 15) of ESP32S3.GPIO.Optional_Pin;
type RGB_Signal_Map is array (0 .. 15) of Natural;

type RGB_Config is record
   H_Sync, V_Sync : Positive;          --  sync pulse widths
   Two_Byte       : Boolean := True;   --  True: 16-bit RGB565; False: 8-bit
   DE_Idle_High   : Boolean := False;  --  DE is usually active-high, so idle low
   --  ... plus the porches, from the panel datasheet
end record;

procedure Acquire_RGB (S : in out Session; Config : RGB_Config; Pins : RGB_Pins);</code></pre>

<p>Horizontal widths and porches are in pixel clocks; vertical ones in lines
&mdash; copy them from the panel's datasheet. <code>RGB_Signal_Map</code> says
which <code>LCD_DATA_OUT</code> signal drives each panel data line, for boards
whose wiring is not in the obvious order.</p>

<p class="note"><code>Acquire_RGB</code> <strong>initialises</strong> the
peripheral &mdash; enables the controller, sets the timing and routes the pins.
Starting the continuous refresh from a framebuffer is a separate call afterwards.
Splitting the two lets you get the timing right on a scope before committing a
framebuffer to it.</p>

<p>The camera-receive half of LCD_CAM is not covered by this driver.</p>
"""),

dict(
slug="20-twai",
nav="TWAI (CAN)",
title="TWAI: CAN 2.0, with the bus-off trap",
lede="Standard and extended frames as separate types so a 29-bit identifier "
     "cannot reach an 11-bit frame &mdash; and an error state that a "
     "single-node bench setup walks straight into.",
body="""
<h2>One controller, three modes</h2>

<p>TWAI &mdash; Two-Wire Automotive Interface &mdash; is CAN 2.0, on an
SJA1000-compatible controller. A real bus needs an external transceiver on the
TX/RX pins.</p>

<pre><code>type Bus_Mode is (Normal, Listen_Only, Self_Test);</code></pre>

<ul>
  <li><strong><code>Normal</code></strong> drives a real bus.</li>
  <li><strong><code>Listen_Only</code></strong> never transmits and never
      acknowledges &mdash; a passive sniffer that cannot perturb traffic.</li>
  <li><strong><code>Self_Test</code></strong> transmits and self-receives
      <em>without needing an external acknowledgement</em>. With
      <code>Enable_Loopback</code> tying TX back to RX through one pad, that
      gives a complete wiring-free self-test.</li>
</ul>

<h2>Identifiers that cannot be mixed up</h2>

<pre><code>subtype Standard_Id is Interfaces.Unsigned_32 range 0 .. 16#7FF#;        --  11-bit
subtype Extended_Id is Interfaces.Unsigned_32 range 0 .. 16#1FFF_FFFF#;  --  29-bit

type Standard_Frame is record
   Id     : Standard_Id  := 0;
   Remote : Boolean      := False;
   Length : Data_Length  := 0;        --  0 .. 8
   Data   : Data_Bytes   := (others =&gt; 0);
end record;
--  Extended_Frame is the same shape with an Extended_Id.</code></pre>

<p>Each frame type carries its own identifier subtype, so the identifier is
range-checked against the standard it belongs to, and <code>Send</code> is
overloaded on the frame type. <strong>You cannot put a 29-bit identifier in a
standard frame</strong> &mdash; it is a compile-time or constraint error, not a
malformed frame on the wire.</p>

<p><code>Remote =&gt; True</code> makes it a remote-transmission request: it
carries the identifier and the requested length but no data, and a node owning
that identifier is expected to answer with a data frame.</p>

<h2>Receiving, two ways</h2>

<p>Polled, where the sender chooses the width so you must ask:</p>

<pre><code>function  Available   (S : Session) return Boolean;
function  Is_Extended (S : Session) return Boolean;   --  ask BEFORE choosing an overload
procedure Receive (S : Session; F : out Standard_Frame; Got : out Boolean);
procedure Receive (S : Session; F : out Extended_Frame; Got : out Boolean);</code></pre>

<p>Or interrupt-driven, which is the shape you want for a real bus:</p>

<pre><code>procedure Enable_Rx_Interrupt (S : Session);   --  needs the Session
procedure Get (F : out Queued_Frame);          --  does NOT -- call it from another task
function  Rx_Overruns return Natural;</code></pre>

<p>A <code>Queued_Frame</code> carries its own width, so the consumer can tell a
standard frame from an extended one without asking the controller. Note the
asymmetry: <code>Enable_Rx_Interrupt</code> touches the controller and so needs
the held session, but <code>Get</code> deliberately does not &mdash; it is meant
to be called from a <em>different</em> task, typically a decode task separate
from the one that owns the port. <code>Rx_Overruns</code> counts what the queue
dropped, which is the number to watch when you suspect your decoder is too
slow.</p>

<h2>The bus-off trap</h2>

<pre><code>type Bus_State is (Active, Warning, Bus_Off);

function  Health  (S : Session) return Bus_State;
procedure Recover (S : Session);</code></pre>

<p class="warn"><strong>A single node on a bench goes bus-off.</strong>
<code>Active</code> is normal and <code>Warning</code> means an error counter has
passed the warning limit, but <code>Bus_Off</code> means the node took
<em>itself</em> off the bus after too many transmit errors &mdash; and the
classic way to cause that is transmitting in <code>Normal</code> mode with no
other node present to acknowledge. A bus-off node neither sends nor receives
until <code>Recover</code> rejoins it. If your first CAN experiment goes deaf
after a few frames, check <code>Health</code> before suspecting wiring, and use
<code>Self_Test</code> mode when there is nothing else on the bus.</p>
"""),

dict(
slug="21-rmt",
nav="RMT pulses",
title="RMT: an arbitrary pulse generator",
lede="Sequences of {level, duration} symbols in hardware &mdash; IR remotes, "
     "WS2812 LED strings, 1-Wire, and any timing you would otherwise "
     "bit-bang badly.",
body="""
<h2>Symbols, not bits</h2>

<p>RMT transmits and receives sequences of pulses. The unit is a
<strong>symbol</strong>: two consecutive {level, duration} pairs packed into one
32-bit word, laid out to match the hardware exactly:</p>

<pre><code>type Tick_Count is range 0 .. 32_767;          --  15-bit duration

type RMT_Symbol is record
   Level0    : Boolean    := False;
   Duration0 : Tick_Count := 0;
   Level1    : Boolean    := False;
   Duration1 : Tick_Count := 0;
end record;

for RMT_Symbol use record
   Duration0 at 0 range  0 .. 14;
   Level0    at 0 range 15 .. 15;
   Duration1 at 0 range 16 .. 30;
   Level1    at 0 range 31 .. 31;
end record;
for RMT_Symbol'Size use 32;</code></pre>

<p>The representation clause is the point: you write ordinary Ada record fields
and the compiler lays them out bit-exactly as the symbol RAM expects, so there is
no shifting or masking anywhere in your code. Durations are in channel ticks,
and a tick is <code>1 / Resolution_Hz</code> &mdash; set the resolution to
1_000_000 and a tick is one microsecond, which is how IR protocol timings are
usually written down.</p>

<h2>Eight channels, split by direction</h2>

<pre><code>type TX_Index is range 0 .. 3;
type RX_Index is range 0 .. 3;

type TX_Channel is limited private;
type RX_Channel is limited private;</code></pre>

<p>Channels 0&nbsp;..&nbsp;3 transmit and 4&nbsp;..&nbsp;7 receive, each with a
48-symbol RAM block. They are claimed handles &mdash; limited, controlled, released
on scope exit &mdash; and <strong>TX and RX are distinct types</strong>, so the
two cannot be confused at a call site.</p>

<h2>Borrowing RAM for longer bursts</h2>

<p><code>Configure</code> takes a <code>Blocks</code> parameter of
1&nbsp;..&nbsp;4, giving the channel that many consecutive 48-symbol RAM
blocks.</p>

<p class="warn"><code>Blocks &gt; 1</code> <strong>borrows the RAM of the
higher-numbered TX channels</strong>. Claiming two blocks on channel 0 consumes
channel 1's memory, so channel 1 is no longer usable. That is a real constraint
on how many independent pulse trains you can run at once, and it is invisible
unless you know to look for it.</p>

<p>Beyond the symbol RAM, a longer burst is streamed by refilling the RAM in
halves as it drains, so <code>Transmit</code> is not limited to what fits &mdash;
it just costs CPU attention during the burst.</p>

<pre><code>procedure Transmit (C : TX_Channel; Symbols : Symbol_Array);   --  blocking</code></pre>

<h2>Receiving</h2>

<pre><code>procedure Start   (C : RX_Channel);                                        --  arm
procedure Receive (C : RX_Channel; Into : out Symbol_Array; Count : out Natural);</code></pre>

<p><code>Start</code> arms the receiver and should be called <em>just</em> before
the incoming burst; <code>Receive</code> blocks until reception ends and reports
how many symbols were captured. Reception ends on an idle threshold, so a
protocol whose inter-frame gap is shorter than your threshold will run two
bursts together.</p>

<p><code>./x run esp32s3_rmt_loopback</code> exercises both directions with a
TX channel driving an RX channel through one pad &mdash; no IR LED, no
receiver.</p>
"""),

dict(
slug="22-ledc-sdm",
nav="LEDC &amp; sigma-delta",
title="LEDC and sigma-delta: the simple outputs",
lede="Eight PWM channels for dimming and clean square waves, and eight "
     "1-bit density-modulated outputs that become analog with one resistor "
     "and one capacitor.",
body="""
<h2>LEDC: PWM without the motor-control machinery</h2>

<p>Eight low-speed channels fed by four timers. A channel picks a timer &mdash;
which sets its frequency and duty resolution &mdash; and drives a GPIO with a
duty cycle you change at run time. This is the "dim an LED, generate a clean
PWM" block; for dead-time, fault inputs and capture, see
<a href="23-mcpwm.html">MCPWM</a>.</p>

<pre><code>type Channel_Index is range 0 .. 7;
subtype Resolution   is Positive range 1 .. 14;      --  duty-cycle bits
subtype Duty_Percent is Float range 0.0 .. 100.0;

procedure Claim  (C : in out Channel; Index : Channel_Index);
procedure Configure (C : ...; Freq : ...; Bits : Resolution; Pin : ...);
procedure Set_Duty  (C : Channel; Percent : Duty_Percent);
procedure Stop      (C : Channel);</code></pre>

<p>Two constraints are worth knowing before you pick numbers.</p>

<p class="warn"><strong>Resolution and frequency trade against each
other:</strong> <code>freq_max = 80&nbsp;MHz / 2**Bits</code>. Fourteen bits of
duty resolution caps you under 5&nbsp;kHz; a 100&nbsp;kHz carrier leaves about
nine bits. Choose <code>Bits</code> for the dimming smoothness you actually need,
not the maximum.</p>

<p class="warn"><strong>A channel uses timer <code>Index mod 4</code>.</strong>
Channels 0 and 4 share a timer, as do 1 and 5, and so on &mdash; so two channels
four apart cannot run at different frequencies. Spread channels across
0&nbsp;..&nbsp;3 when you need independent rates.</p>

<p><code>Set_Duty</code> takes effect at the next period, so it is safe to call
while running &mdash; no glitch, no partial-update flicker. The handle is limited
and controlled as everywhere else here, and finalization <em>stops the output</em>
as well as releasing the channel, so a leaked handle cannot keep driving a
pad.</p>

<h2>Sigma-delta: analog for the price of an RC filter</h2>

<p>Eight channels in the GPIO sigma-delta unit. Each emits a high-frequency
pulse stream whose average density is set by a signed 8-bit value; pass it
through an external RC low-pass and you have a cheap analog output &mdash; LED
dimming, a bias voltage, simple audio.</p>

<pre><code>type Channel_Index is range 0 .. 7;
subtype Density_Percent is Float range 0.0 .. 100.0;

procedure Configure   (C : ...; Pin : ...; Carrier_Hz : ...);   --  starts at 0 %
procedure Set_Density (C : Channel; Percent : Density_Percent); --  one register write</code></pre>

<p>The distinction from LEDC matters when choosing between them. LEDC varies the
<em>width</em> of a pulse at a fixed frequency, so its output has energy at the
PWM frequency and its harmonics. Sigma-delta varies the <em>density</em> of
fixed-width pulses, pushing quantisation noise up in frequency where a simple
filter removes it &mdash; which is why it makes a better analog voltage and why
the same technique appears inside <a href="18-i2s.html">I2S</a>'s PDM mode.</p>

<p><code>Set_Density</code> is a single register write, so it is cheap enough to
call from a sample loop.</p>
"""),

dict(
slug="23-mcpwm",
nav="MCPWM",
title="MCPWM: PWM that can shut itself down",
lede="Complementary outputs with dead-time so a half-bridge is never shorted, "
     "a chopper carrier, and a fault input that forces the pins safe in "
     "hardware &mdash; without waiting for your code.",
body="""
<h2>What makes it different from LEDC</h2>

<p>Two units, each with three independent generator channels and three capture
channels. A generator channel is one timer plus one operator producing an
edge-aligned PWM on output A: high at the start of each period, low when the
up-counting timer reaches the duty comparator.</p>

<pre><code>type MCPWM_Unit    is (MCPWM0, MCPWM1);
type Channel_Index is (Ch0, Ch1, Ch2);

procedure Claim (C : in out Channel; Unit : MCPWM_Unit; Index : Channel_Index);
procedure Configure_Channel (...; Freq : ...; Complement_Pin : ... );  --  ~10 Hz .. 10 MHz
procedure Start (C : Channel);
procedure Stop  (C : Channel);
procedure Set_Duty (C : Channel; Percent : Duty_Percent);</code></pre>

<p><code>Set_Duty</code> is a single atomic register write. <code>Stop</code>
halts the timer and the output <em>stays in its current state</em> &mdash; which
is not necessarily the safe state, so think about which level your hardware wants
before stopping a running bridge.</p>

<h2>Complementary output and dead-time</h2>

<p>Pass <code>Complement_Pin</code> and the channel drives a half-bridge or
H-bridge pair: the A output plus an inverted B output from the same PWM, with
programmable <strong>dead-time</strong> inserted between their edges so the two
are never high together.</p>

<p class="note">That dead-time is the whole reason this peripheral exists. In a
half-bridge, both transistors conducting at once is a direct short across the
supply &mdash; "shoot-through" &mdash; which destroys the bridge in microseconds.
Software cannot be trusted to sequence the edges; the hardware inserts the gap.</p>

<h2>Carrier modulation</h2>

<pre><code>subtype Carrier_Prescale is Natural range 0 .. 15;
subtype Carrier_Duty     is Natural range 1 .. 7;
subtype Carrier_Pulse    is Natural range 0 .. 15;

procedure Set_Carrier (...);</code></pre>

<p>Chops the PWM output with a high-frequency carrier. This is what drives a
gate-drive transformer (which cannot pass DC) or an IR emitter that expects a
modulated burst.</p>

<h2>Fault inputs: the safety feature</h2>

<pre><code>type Fault_Input is (Fault0, Fault1, Fault2);
type Fault_Mode  is (One_Shot, Cycle_By_Cycle);
type Trip_Action is (No_Change, Force_Low, Force_High);

procedure Configure_Fault  (Input : ...; Pin : ...; Active_High : ...);
procedure Protect_Channel  (C : ...; Input : Fault_Input; Action : Trip_Action);</code></pre>

<p>A fault pin &mdash; an over-current comparator, a driver's fault flag &mdash;
forces the channel's A and B outputs to a chosen state <strong>in
hardware</strong>. No interrupt latency, no scheduler, no chance that your task
was busy elsewhere.</p>

<table>
  <thead><tr><th>Mode</th><th>Behaviour</th></tr></thead>
  <tbody>
    <tr><td><code>Cycle_By_Cycle</code></td>
        <td>The output is forced while the fault is asserted and resumes on its
            own once it clears. For recoverable conditions such as a current
            limit.</td></tr>
    <tr><td><code>One_Shot</code></td>
        <td>The trip <em>latches</em>. The outputs stay forced until you
            explicitly clear it, and clearing only re-enables them if the fault
            has actually gone. For conditions that should require a deliberate
            decision to restart.</td></tr>
  </tbody>
</table>

<p>Set <code>Trip_Action</code> to the level that is safe for <em>your</em>
hardware &mdash; <code>Force_Low</code> is right for a low-side switch, but not
universally.</p>
"""),

dict(
slug="24-timers-pcnt",
nav="Timers &amp; pulse counting",
title="Timers and pulse counting",
lede="A 54-bit counter with an alarm, and four edge counters &mdash; the two "
     "ways to measure time and events without the CPU watching.",
body="""
<h2>General-purpose timers</h2>

<p>Two timer groups, TIMG0 and TIMG1. Each has one 54-bit up/down counter clocked
from the APB clock through a 16-bit prescaler, with a programmable alarm. (The
per-group watchdogs are separate and this driver does not touch them.)</p>

<pre><code>type Timer_Index is range 0 .. 1;          --  0 = TIMG0, 1 = TIMG1
type Ticks is new Interfaces.Unsigned_64;

procedure Configure (T : in out Timer; Tick_Hz : Positive := 1_000_000);
procedure Start (T : Timer);
procedure Stop  (T : Timer);
procedure Reset (T : Timer);              --  reload to 0, running or not
function  Value (T : Timer) return Ticks; --  latched, then read

procedure Set_Alarm    (T : Timer; At_Ticks : Ticks);
function  Alarm_Fired  (T : Timer) return Boolean;
procedure Clear_Alarm  (T : Timer);</code></pre>

<p>The default 1&nbsp;MHz tick makes <code>Value</code> read directly in
microseconds. Fifty-four bits at that rate is a bit over five centuries, so
wrap-around is not a design consideration.</p>

<p><code>Value</code> latches before reading, which matters on a 54-bit counter
sampled by a 32-bit CPU: without the latch you could catch the low word after a
carry and the high word before it, and read a time that never existed.</p>

<p class="note"><strong>This is not the runtime's clock.</strong>
<code>Ada.Real_Time.Clock</code> and <code>delay until</code> are served by the
runtime's own tick on the systimer &mdash; see
<a href="06-anatomy.html">step 6</a>. These timers are an independent
measurement resource for your application, which is exactly what makes them
useful for cross-checking the runtime: <code>./x run esp32s3_timer_count</code>
does that against the wall clock.</p>

<p><code>Alarm_Fired</code> stays set until <code>Clear_Alarm</code>, so a polled
loop cannot miss the event between samples.</p>

<h2>PCNT: counting edges</h2>

<p>Four counter units, each counting into a signed 16-bit counter as edges arrive
on its input pin. The classic uses are a tachometer, a flow meter, or a
quadrature encoder.</p>

<pre><code>type Unit_Index is range 0 .. 3;

procedure Configure (U : in out Unit; Pin : ESP32S3.GPIO.Pin_Id;
                     Both_Edges : Boolean := False);
function  Count (U : Unit) return Integer;   --  signed; wraps at +/- 32768</code></pre>

<p>By default each rising edge counts; <code>Both_Edges</code> counts falling
ones too, doubling the resolution of a symmetric signal.</p>

<p class="warn"><strong>The counter is 16-bit and wraps at ±32768.</strong> On a
fast input that is not long: 10&nbsp;kHz overflows in about three seconds. Poll
often enough to catch every wrap, or the count you accumulate will be wrong in a
way that looks plausible.</p>

<p>This driver exposes the common "count edges on a pin" case; the per-unit
direction-control input and the threshold-event comparators are left at their
pass-through defaults.</p>
"""),

dict(
slug="25-analog",
nav="ADC &amp; touch",
title="Analog in: the SAR ADC and capacitive touch",
lede="Two 12-bit converters on fixed pins, and fourteen touch channels that "
     "measure a pad's capacitance by counting &mdash; both living in the RTC "
     "domain.",
body="""
<h2>The SAR ADC</h2>

<p>Two units, each with up to ten 12-bit channels on <em>fixed</em> GPIOs. The
mapping is not configurable, so the pin decides the channel:</p>

<pre><code>ADC1 channel n -&gt; GPIO (n + 1)     --  ch0 = GPIO1  .. ch9 = GPIO10
ADC2 channel n -&gt; GPIO (n + 11)    --  ch0 = GPIO11 .. ch9 = GPIO20

function Channel_Pin (Unit : ADC_Unit; Ch : Channel_Index)
  return ESP32S3.GPIO.Pin_Id;      --  ask, rather than hard-code the arithmetic</code></pre>

<p>Conversions are software-triggered single shots through the RTC controller,
each returning a raw 12-bit code:</p>

<pre><code>type Attenuation is (Db_0, Db_2_5, Db_6, Db_12);   --  ~1.1 V .. ~3.3 V full scale
subtype Raw_Value is Natural range 0 .. 4095;

function Read (R : Reader; Ch : Channel_Index;
               Atten : Attenuation := Db_12) return Raw_Value;</code></pre>

<p>Attenuation is per channel and per read, so one unit can serve a 1&nbsp;V
sensor and a 3.3&nbsp;V divider without reconfiguration between them. The default
<code>Db_12</code> gives roughly the full 3.3&nbsp;V range; a lower attenuation
on a small signal buys real resolution.</p>

<p class="note"><strong>The result is a raw code, not a voltage.</strong> The
driver does not pretend to give you volts, because an accurate conversion needs
the per-chip calibration data and the attenuation curve is not linear at the
extremes. <code>Cal_Code</code> exposes the self-calibrated initial code and
<code>Last_Done</code> whether the most recent conversion completed &mdash; both
diagnostics for deciding whether a reading is trustworthy.</p>

<h2>Capacitive touch</h2>

<p>Fourteen channels on GPIO1&nbsp;..&nbsp;GPIO14, and the numbering is the one
mnemonic you need: <strong>touch channel n is wired to GPIO n</strong>.</p>

<pre><code>type Channel is range 1 .. 14;
function Pad (Ch : Channel) return ESP32S3.GPIO.Pin_Id;

procedure Setup;                    --  bring the controller up, start the FSM
procedure Enable (Ch : Channel);    --  put the pad in touch mode, add to the scan
function  Read (Ch : Channel) return Natural;     --  latest raw count</code></pre>

<p>Each channel measures its pad's self-capacitance by counting charge/discharge
cycles in a fixed window. A finger near the pad raises the capacitance and
changes the count. An FSM scans the enabled channels continuously on the RTC
timer, so <code>Read</code> returns the latest sample rather than triggering
one &mdash; it never blocks.</p>

<p>Detection is relative, not absolute: <code>Touched</code> compares a channel's
current count against a reference you supply. That reference is
board-specific &mdash; pad size, overlay thickness and stray capacitance all move
it &mdash; so sample a known-untouched value at startup rather than hard-coding
a threshold from someone else's board.</p>

<p class="note">Touch needs no tasking runtime: it is register pokes into the
RTC/SENS domain, so unlike most of the HAL it works under
<code>light-tasking</code> too.</p>
"""),

dict(
slug="26-rtc",
nav="RTC, hold &amp; deep sleep",
title="RTC, pad hold and deep sleep",
lede="Deep sleep is not a pause &mdash; the chip resets and re-runs from the "
     "start. What survives is RTC memory, and the pads you explicitly told to "
     "hold their level.",
body="""
<h2>The mental model that matters</h2>

<p class="warn"><strong>Waking from deep sleep is a reset, not a resume.</strong>
The digital core &mdash; CPU and main RAM &mdash; is powered down; only the RTC
domain stays alive. On wake the chip <em>restarts from the beginning</em>: your
<code>Main</code> runs again from the top, every variable re-elaborated. Nothing
in ordinary RAM survives. Code written as though sleep were a blocking delay will
be wrong in a way that looks like a spontaneous reboot.</p>

<p>Two things do survive: data you deliberately put in RTC memory, and RTC pads
you told to hold.</p>

<h2>Retained memory</h2>

<pre><code>subtype Word_Index is Natural range 0 .. Slow_Memory_Size / 4 - 1;

function  Read  (Index : Word_Index) return Interfaces.Unsigned_32;
procedure Write (Index : Word_Index; Value : Interfaces.Unsigned_32);</code></pre>

<p>There is also a generic typed retained object: instantiate it once per stored
item and it gives you a distinct slot with a real type, rather than making you
hand-manage word indices and remember which one held what. Prefer that for
anything beyond a single counter.</p>

<h2>Knowing why you are running</h2>

<pre><code>type Wake_Cause is ...;                       --  power-on, timer, RTC-GPIO, ...
function Last_Wake       return Wake_Cause;
function Raw_Reset_Cause return Natural;      --  5 = deep-sleep wake
function Raw_Wake_Cause  return Natural;</code></pre>

<p>Because every wake re-runs your program, the first thing it usually has to do
is ask <em>why</em>: a cold power-on initialises state, a timer wake continues a
duty cycle, a pin wake handles an event. That branch is the shape of nearly every
low-power application.</p>

<h2>Entering sleep</h2>

<pre><code>procedure Deep_Sleep_For (Wake_After : Duration);   --  timer wake
--  plus a variant that sleeps until an RTC-capable pin reaches a level (EXT1)</code></pre>

<p class="note">These <strong>do not return</strong>. If one does, the sleep FSM
rejected the request &mdash; and <code>Raw_Reject_Cause</code> tells you why.
Treat a return as an error path, not as normal control flow, because that is
exactly what it is.</p>

<h2>Pad hold: keeping a line asserted through the reset</h2>

<p>GPIO0&nbsp;..&nbsp;GPIO21 are RTC-capable. The headline feature of
<code>ESP32S3.RTC_IO</code> is <strong>hold</strong>: latch a pad at its current
output level so it keeps driving while the rest of the chip changes &mdash;
including through deep sleep and across the reset that waking causes.</p>

<pre><code>subtype RTC_Pin is ESP32S3.GPIO.Pin_Id range 0 .. 21;

procedure Hold    (Pin : RTC_Pin);
procedure Release (Pin : RTC_Pin);
function  Is_Held (Pin : RTC_Pin) return Boolean;
procedure Set_Pull (Pin : RTC_Pin; Mode : Pull_Mode);   --  No_Pull | Up | Down</code></pre>

<p>This is how you keep a load enabled or a peripheral's reset line asserted
while you sleep &mdash; without it, every pad returns to a default input at the
moment of sleep and your board resets its own sensors.</p>

<p class="warn"><strong>A held pad ignores ordinary GPIO writes until you
<code>Release</code> it.</strong> On the run after a wake, a pin that refuses to
change is almost always one you held before sleeping and have not released.</p>

<p class="note">Neither package needs a tasking runtime &mdash; both are register
pokes &mdash; and RTC-IO works under every runtime profile.</p>
"""),

dict(
slug="27-crypto",
nav="Crypto &amp; RNG",
title="Hardware crypto, and one honest caveat",
lede="SHA, AES and RSA acceleration behind protected objects, MD5 for a "
     "specific non-cryptographic job &mdash; and a random number generator "
     "that is not a CSPRNG on this runtime.",
body="""
<h2>SHA</h2>

<pre><code>function Hash_1   (Data : Byte_Array) return SHA1_Digest;     --  20 bytes
function Hash_224 (Data : Byte_Array) return SHA224_Digest;
function Hash_256 (Data : Byte_Array) return SHA256_Digest;</code></pre>

<p>One shared accelerator, so a protected object serialises the message-load /
start / read handshake and concurrent <code>Hash</code> calls from different
tasks are safe. All three variants share the 512-bit block and padding, differing
only in hardware mode and digest length. The block also does SHA-384/512, which
use a 1024-bit block and are not exposed here.</p>

<h2>AES, and a silicon limitation worth a contract</h2>

<pre><code>type Block     is array (0 .. 15) of Interfaces.Unsigned_8;
subtype Key_128 is Key_Bytes (0 .. 15);
subtype Key_256 is Key_Bytes (0 .. 31);

function Supported_Key (Key : Key_Bytes) return Boolean;
function Encrypt_ECB   (Key : Key_Bytes; Plain : Block) return Block;</code></pre>

<p class="warn"><strong>The S3's AES supports 128- and 256-bit keys only.</strong>
There is no 192-bit support on this silicon &mdash; selecting "AES-192" makes the
engine <em>silently fall back to AES-128 on the first 16 key bytes</em>, which
would produce ciphertext that looks fine and is not what you asked for. The
<code>Supported_Key</code> precondition turns that into a contract violation
instead. 192-bit keys exist only on the original ESP32.</p>

<p>What is exposed is single-block ECB, deliberately: it is the primitive, not a
mode you should be encrypting messages with directly. Build CBC, CTR or GCM on
top of it.</p>

<h2>RSA</h2>

<pre><code>type Word_Array is array (Natural range &lt;&gt;) of Word;   --  little-endian limbs

procedure Mod_Exp (X, Y, M, R2 : Word_Array; Z : out Word_Array; Ok : out Boolean);
procedure Mod_Exp (X, Y, M     : Word_Array; Z : out Word_Array; Ok : out Boolean);</code></pre>

<p>Big-integer modular exponentiation, <code>Z = X**Y mod M</code>, up to
4096-bit &mdash; the core of RSA signature verification. The hardware does
Montgomery exponentiation; the driver computes <code>M'</code> itself, and the
second overload derives <code>R2</code> for you as well. Operands are
little-endian 32-bit limb arrays, all the same length. It is lock-free and
ZFP-safe: a sequence of register accesses with no tasking and no heap.</p>

<h2>MD5, and why it is here</h2>

<p class="note">MD5 is long broken as a cryptographic hash and this package does
not pretend otherwise. It earns its place because the ESP32 ROM loader's
<code>SPI_FLASH_MD5</code> command speaks it: after writing an image, the target
hashes what its flash actually holds, this computes what it <em>should</em> hold,
and comparing them is what lets "programmed OK" mean something. An integrity
check against accident, not against an adversary.</p>

<p>It is streaming (<code>Reset</code> / <code>Update</code> /
<code>Hex_Digest</code>), pure Ada, no heap, no tasking &mdash; so it runs on the
light runtime too.</p>

<h2>The RNG caveat</h2>

<pre><code>--  Read is a single atomic 32-bit register load; Fill writes a buffer.</code></pre>

<p>Each read of the RNG data register returns a fresh 32-bit value. It is
Preelaborate, heap-free, finalization-free and task-safe by construction &mdash;
the one peripheral that keeps every one of those properties at once.</p>

<p class="warn"><strong>Do not treat it as a CSPRNG as it stands.</strong> The
TRM wants an active entropy source for cryptographic-quality output &mdash; the
RF subsystem, which this bare runtime does not start, or SAR-ADC bootloader
entropy. Without one it still produces varying values from internal clock jitter,
which is fine for dithering, non-secret identifiers, test data or seeding a
software PRNG. It is not fine for keys. Also avoid reading in a tight loop faster
than the hardware refreshes, or successive words may correlate.</p>

<p class="note">A related trap: this is the <em>RNG peripheral</em> register, not
esp-idf's <code>WDEV_RND_REG</code>. That one only yields entropy with the RF
clock domain up, so on this runtime it reads a constant &mdash; a mistake that
would look like working code returning the same "random" number forever.</p>
"""),

dict(
slug="28-sd",
nav="SD cards",
title="SD cards: two hosts, one API shape",
lede="The universal SPI transport and the native SD bus &mdash; different "
     "speeds, different profile requirements, and the same 512-byte logical "
     "block interface.",
body="""
<h2>Two routes to the same card</h2>

<table>
  <thead><tr><th></th><th><code>SD_SPI</code></th><th><code>SDMMC</code></th></tr></thead>
  <tbody>
    <tr><td>Bus</td>
        <td>The SPI master, 4 lines</td>
        <td>The real SD bus: clock, bidirectional command line, 1 or 4 data lines</td></tr>
    <tr><td>Data path</td>
        <td>Through <a href="15-spi.html">SPI</a> (and its GDMA)</td>
        <td>PIO/FIFO &mdash; the CPU pushes each 512-byte block through the controller's FIFO</td></tr>
    <tr><td>Speed</td>
        <td>Lower</td>
        <td>Faster; how you reach an SDHC/SDXC card at speed</td></tr>
    <tr><td>Profile</td>
        <td><strong>embedded / full only</strong> (uses the SPI Session's finalization)</td>
        <td><strong>every profile</strong>, light-tasking included</td></tr>
  </tbody>
</table>

<p>That last row is the surprise, and it falls out of the implementation: because
<code>SDMMC</code> moves data in PIO with no GDMA and no descriptors, it needs no
finalization &mdash; a library-level protected object serialises the single
shared controller. So the <em>faster</em> host is also the one available on the
lean runtime.</p>

<h2>The shared API shape</h2>

<pre><code>type Block         is array (0 .. 511) of Interfaces.Unsigned_8;
type Block_Address is new Interfaces.Unsigned_32;</code></pre>

<p>Both are addressed in <strong>512-byte logical blocks (LBA)</strong>, always.
SDHC and SDXC cards use block addressing while older SDSC cards use byte
addressing; that difference is resolved inside the driver, so it never reaches
your code. Both also initialise the card at ≤400&nbsp;kHz as the SD specification
requires, then switch to <code>Data_Clock_Hz</code> &mdash; which is precisely
what <a href="15-spi.html">SPI</a>'s <code>Set_Clock</code> mid-hold exists
for.</p>

<h2>Why SD-over-SPI needs a GPIO chip select</h2>

<p class="note">The chip select is driven as a <strong>plain GPIO</strong>, not
the SPI peripheral's hardware CS. The SD protocol needs CS held asserted across a
whole command / response / data sequence, and the peripheral's own CS pulses per
transfer &mdash; which the protocol cannot use. This is the concrete case behind
the <code>CS_Pin</code> option on <a href="15-spi.html">SPI's
<code>Acquire</code></a>.</p>

<p><code>SD_SPI</code> layers the SD "SPI mode" command protocol on top of the
task-safe SPI master: CMD0, CMD8, CMD58, ACMD41, CMD17, CMD24 and CRC7. Every
operation takes the SPI host's session for the whole transaction, so concurrent
callers serialise.</p>

<pre><code>type Card_Kind is (Unknown, SD_V1, SD_V2_SC, SD_V2_HC);</code></pre>

<p><code>SDMMC</code> has two slots (<code>Slot1</code>, <code>Slot2</code>), one
card each, and a selectable <code>Bus_Width</code> of <code>Width_1</code> or
<code>Width_4</code>. Its lines route through the GPIO matrix, so any free pins
will do.</p>

<p class="warn">Both drivers are marked in the repository's testing table as
<strong>compiles, no-card smoke test only</strong>. They are the ones to verify
against a real card before relying on them &mdash; see
<a href="11-hal.html">step 11</a>.</p>
"""),

dict(
slug="29-chip-id",
nav="Temperature &amp; MAC",
title="Chip identity: die temperature and the eFuse MAC",
lede="Two small packages that answer questions about the silicon itself &mdash; "
     "how hot it is, and what addresses the factory gave it.",
body="""
<h2>The on-chip temperature sensor</h2>

<p class="warn"><strong>It reports die temperature, not ambient air.</strong> The
chip self-heats under load, so an idle board typically reads a few degrees above
room temperature and a busy one considerably more. Using it as a room thermometer
will give you a plausible, wrong answer.</p>

<p>Accuracy is roughly ±1&nbsp;°C after the part's factory trim, and is best near
the middle of the selected measurement range &mdash; so pick the
<code>Measure_Range</code> that brackets your expected readings rather than the
widest one:</p>

<pre><code>procedure Initialize (Span : Measure_Range := Range_Minus10_80);</code></pre>

<p><code>Initialize</code> is optional: the first <code>Read</code> brings the
sensor up with the default range if you skip it. The sensor is owned by a
protected object, so concurrent reads from different tasks serialise
automatically &mdash; each busy-waits microseconds for its conversion under that
lock.</p>

<p class="note">Bring-up is more involved than it looks, which is why it is worth
having a driver for: gate the SAR peripheral clock, pulse-reset it, open the
analog REGI2C bus, program the sensor's DAC range over that bus through a ROM
call, then power the sensor up. Every reading then drives a dump-out/ready
handshake to latch a fresh conversion before sampling.</p>

<h2>The factory MAC addresses</h2>

<p>Espressif allocates each part a block of <strong>four</strong>
universally-administered addresses. The eFuse base is the Wi-Fi station MAC, and
the others are derived from it:</p>

<pre><code>type MAC_Address is array (0 .. 5) of Interfaces.Unsigned_8;

function Base           return MAC_Address;   --  = Wi-Fi station
function Wi_Fi_Station  return MAC_Address;   --  base + 0
function Wi_Fi_SoftAP   return MAC_Address;   --  base + 1
--  Bluetooth  = base + 2
--  Ethernet   = base + 3</code></pre>

<p>The practical use on a board with no Wi-Fi: give a
<strong>W5500 Ethernet controller the <code>Ethernet</code> address</strong>
instead of a hand-picked one. That is a real, manufacturer-assigned, globally
unique MAC &mdash; which matters the moment two of your boards end up on the same
network segment, and is free.</p>

<p class="note">Every routine is a pure read of the eFuse shadow registers, which
are latched at reset. No clock, no driver state, no initialisation &mdash; so
these are safe to call from anywhere, at any time, under any profile.</p>
"""),

dict(
slug="30-display-touch",
nav="Display &amp; touch",
title="ST7789 display and GT911 touch",
lede="A write-only SPI display that cannot be probed, and a touch controller "
     "whose I2C address depends on a pin level at reset &mdash; the two halves "
     "of a touchscreen, each with its own trap.",
body="""
<h2>ST7789: no reads, no probe</h2>

<p class="warn"><strong>The panel never talks back.</strong> The ST77xx SPI
interface is write-only as wired here, so there is no status read and no way to
probe for the device. If nothing appears, the driver cannot tell you whether the
panel is absent, mis-wired or simply off &mdash; you get silence either way.
Check wiring before suspecting code.</p>

<p>Three GPIOs are driven directly by the driver: <strong>DC</strong>
(data/command), <strong>CS</strong>, and an optional <strong>RST</strong>. Pass
<code>No_Pin</code> for RST and it falls back to a software reset.</p>

<pre><code>type Color is mod 2**16;                                   --  RGB565, MSB-first
function RGB (R, G, B : Natural) return Color;             --  each 0 .. 255
type Color_Array is array (Natural range &lt;&gt;) of Color;      --  row-major
type Rotation is (Rot_0, Rot_90, Rot_180, Rot_270);</code></pre>

<p>Bring-up is <code>Setup</code> (records the wiring and geometry, brings the
SPI host up in mode 0) then <code>Acquire</code> for an exclusive session, then
<code>Init</code> to run the power-on sequence.</p>

<pre><code>procedure Init         (S : Session);
procedure Display_On   (S : Session);
procedure Set_Rotation (S : Session; Rot : Rotation);        --  sets MADCTL
procedure Invert       (S : Session; On : Boolean);
procedure Sleep        (S : Session; On : Boolean);

procedure Fill        (S : Session; C : Color);
procedure Fill_Rect   (S : Session; X, Y, W, H : Natural; C : Color);
procedure Set_Pixel   (S : Session; X, Y : Natural; C : Color);
procedure Draw_Bitmap (S : Session; X, Y, W, H : Natural; Pixels : Color_Array);</code></pre>

<h2>Two levels of locking</h2>

<p class="note">The display has <em>two</em> guards, not one. The
<code>Session</code> owns the <strong>display</strong> exclusively, while each
operation locks the <strong>SPI host</strong> only for its own transfer &mdash;
so another device on the same bus can interleave between your drawing calls, and
a long <code>Fill</code> does not monopolise the bus.</p>

<p>Those per-display guards are a fixed library-level array keyed by the CS pin,
since a GPIO uniquely identifies one display. That is why no protected object
lives inside a <code>Device</code>, and why <code>Device</code> values are cheap
to hold.</p>

<h2>GT911: the address is decided at reset</h2>

<p>A Goodix 5-point capacitive controller on I2C. It is a
<strong>16-bit-register</strong> device: every transaction sends the register
address MSB-first, then reads or writes a run of bytes from the chip's
auto-incrementing pointer. Multi-byte values inside the map &mdash; coordinates,
firmware version, output range &mdash; are <em>little</em>-endian, so the address
and the payload disagree about byte order.</p>

<p class="warn"><strong>The chip latches its I2C address from the INT level while
RST is released:</strong> INT low gives <code>0x5D</code> (the usual module
strapping), INT high gives <code>0x14</code>. This driver never drives INT or
RST, because on many boards RST is not even on an ESP pin &mdash; the Waveshare
ESP32-S3-Touch-LCD-7 routes it through a <a href="34-expanders.html">CH422G</a>
expander with INT weakly low. Releasing reset is therefore board wiring you do
once at startup, <em>before</em> touching the chip. Get the order wrong and the
part answers at the other address, which looks exactly like a dead device.</p>

<h2>Reading touches</h2>

<pre><code>type Touch_State is record ... end record;    --  up to 5 points, each with a track id
type Status is (OK, Bus_Error);

procedure Read_Touches (Dev : Device; State : out Touch_State; Result : out Status);
procedure Read_Product_Id, Read_Firmware_Version, Read_Resolution ...</code></pre>

<p>The chip scans continuously and latches one report per scan cycle: a status
register with a buffer-ready flag and point count, then up to five
track-id/X/Y/size records. <code>Read_Touches</code> drains one report
<em>and re-arms the latch</em> by writing the flag back to zero &mdash; so
forgetting to call it stalls further reports rather than queueing them.</p>

<p>The INT line pulses on every fresh report. Attach a handler with the
<code>.Interrupts</code> child and call <code>Read_Touches</code> from a task it
wakes &mdash; remembering the <a href="13-gpio.html">callback rules</a>: latch a
flag in the handler, do the I2C work at task level, never from the ISR.</p>

<p>Like <a href="14-i2c.html">I2C</a>'s other clients, the driver hard-codes no
wiring: you tell <code>Setup</code> the host, the SDA/SCL pins, the optional INT
pin and the address, and each operation opens a short-lived controlled session
for one complete transaction.</p>
"""),

dict(
slug="31-es8311",
nav="ES8311 codec",
title="ES8311: the audio codec",
lede="Control over I2C, audio over I2S, and a clocking relationship you have "
     "to get right &mdash; the ESP is the master, the codec follows.",
body="""
<h2>Two buses, one device</h2>

<p>The Everest ES8311 is a low-power mono codec that is <strong>controlled over
I2C and carries audio over I2S</strong>. Both have to be right before a sound
comes out, which is what makes it a more instructive device than it first
looks.</p>

<pre><code>subtype Address is ESP32S3.I2C.Slave_Address;   --  0x18 with CE/AD0 low, 0x19 with CE high</code></pre>

<h2>The clocking relationship</h2>

<p class="note">The ESP is the <strong>I2S master</strong> and generates MCLK,
BCLK and WS; the codec runs as an <strong>I2S slave</strong> clocked from that
MCLK. The driver fixes <code>MCLK = 256 &times; Sample_Rate</code> with 16-bit
samples, and the register coefficients are calculated for that ratio &mdash; it
is rate-independent, but not ratio-independent. This is why
<a href="18-i2s.html">I2S</a>'s <code>Mclk</code> pin exists and why it is only
available on I2S0.</p>

<pre><code>procedure Setup (...; Sample_Rate : ...; Sda, Scl : ...; Asdout : ... := No_Pin;
                 Ok : out Boolean);</code></pre>

<p><code>Ok</code> is False if the codec never ACKed on I2C &mdash; the first
thing to check is the address strap, since <code>0x18</code> and
<code>0x19</code> differ only by the CE pin. <code>Asdout</code> is the codec's
ADC data-out (the ESP's data-<em>in</em>): leave it <code>No_Pin</code> for
output only, or wire it to bring up the microphone path as well, with PGA gain
in 6&nbsp;dB steps from 0 to 42&nbsp;dB.</p>

<h2>Playing</h2>

<p>Audio output goes through a limited, controlled <code>Output</code> handle
that owns the I2S port exclusively and releases it on scope exit. The playback
calls mirror <a href="18-i2s.html">I2S</a>'s exactly, because they are built on
them:</p>

<table>
  <thead><tr><th>Call</th><th>Use</th></tr></thead>
  <tbody>
    <tr><td><code>Play</code></td><td>One blocking buffer.</td></tr>
    <tr><td><code>Play_Continuous</code></td><td>Self-looping DMA &mdash; a steady tone with no CPU involvement and no gap at the wrap.</td></tr>
    <tr><td><code>Play_Stream</code> + <code>Await_Half</code></td><td>Gapless double-buffered playback: refill the half the hardware is not reading.</td></tr>
    <tr><td><code>Capture</code> / <code>Capture_Stream</code> + <code>Await_Capture_Half</code></td><td>The microphone path, including while playback runs.</td></tr>
    <tr><td><code>Duplex</code></td><td>Play and record simultaneously.</td></tr>
  </tbody>
</table>

<pre><code>procedure Set_Volume (Percent : Natural; Ok : out Boolean);   --  0 .. 100, after Setup</code></pre>

<p class="note">The register-init sequence and clock coefficients are ported from
Espressif's own <code>es8311</code> driver &mdash; this is one place where the
"from scratch" claim is honestly a port, because the sequence is a hardware
recipe rather than a design decision.</p>
"""),

dict(
slug="32-sensors",
nav="IMU &amp; environment",
title="Sensors: the QMI8658C IMU and SHT41",
lede="One register-mapped device and one command-based device &mdash; the two "
     "shapes almost every I2C sensor takes, and how each reports that its "
     "reading is trustworthy.",
body="""
<h2>The shared shape</h2>

<p>Every I2C device driver here follows the same pattern, and it is worth stating
once because it repeats across the rest of these pages:</p>

<p class="note"><strong>The driver hard-codes no board wiring.</strong> You tell
<code>Setup</code> which host, which SDA/SCL pins, optionally which INT pin, and
the address; the <code>Device</code> remembers them. Each operation then opens a
<em>short-lived</em> <a href="14-i2c.html">I2C session</a> for one complete
transaction and lets it release the host on scope exit. So devices share a bus
safely, and a fault mid-transaction cannot leak the lock. A <code>Device</code>
is limited — it owns the wiring it was set up with and cannot be copied.</p>

<h2>QMI8658C: a register-mapped IMU</h2>

<p>A 6-axis part — 3-axis accelerometer plus 3-axis gyroscope. SA0 selects
address <code>0x6A</code> or <code>0x6B</code>.</p>

<pre><code>type Accel_Range is (Range_2G, Range_4G, Range_8G, Range_16G);
type Gyro_Range  is ...;
type Output_Rate is ...;
type Axes        is record ... end record;
type Status      is (OK, Bus_Error);

procedure Read_Accelerometer (Dev : Device; A : out Axes; Result : out Status);
procedure Read_Gyroscope     (Dev : Device; G : out Axes; Result : out Status);
procedure Read_Temperature   (Dev : Device; Raw : out Interfaces.Integer_16; Result : out Status);
procedure Data_Ready (Dev : Device; Accel, Gyro : out Boolean; Result : out Status);</code></pre>

<p>Reads use the chip's auto-incrementing address pointer, set by
<code>Configure</code> via <code>CTRL1.ADDR_AI</code>: a one-byte write sets the
pointer and the following read streams from it. The driver runs the device
little-endian (<code>CTRL1.BE = 0</code>).</p>

<p class="warn"><strong>Raw counts are not physical units, and the scale depends
on the range you configured.</strong> That is what these two are for:</p>

<pre><code>function Accel_LSB_Per_G   (Dev : Device) return Positive;
function Gyro_LSB_Per_DPS  (Dev : Device) return Positive;</code></pre>

<p>Ask the device rather than hard-coding a divisor, and changing
<code>Accel_Range</code> later cannot silently scale every reading wrong. Both are
SPARK-mode functions.</p>

<h2>SHT41: a command-based sensor</h2>

<p class="note"><strong>The SHT4x has no registers at all.</strong> A measurement
is: write a one-byte command, wait the conversion time, read six bytes. That is a
genuinely different protocol shape from the IMU, and it is why the driver exposes
<code>Measure</code> rather than register accessors.</p>

<pre><code>type Precision   is (Low, Medium, High);
type Measurement is record ... end record;
type Status      is (OK, Bus_Error, CRC_Error);

procedure Measure (...);
procedure Read_Serial_Number (...);
procedure Reset (Dev : Device; Result : out Status);</code></pre>

<p><code>Precision</code> trades conversion time against noise. The six returned
bytes are two CRC-8-protected words, and the driver checks them — hence the third
<code>Status</code> value:</p>

<p class="warn"><code>CRC_Error</code> is <em>not</em> <code>Bus_Error</code>. The
device ACKed and returned data, but the checksum failed — so the wiring is
probably fine and you are looking at interference, an over-long cable, or too
fast a bus. Treat it as "retry", not "device missing".</p>

<p>There is no interrupt line: the sensor is read on request.</p>
"""),

dict(
slug="33-pcf85063a",
nav="PCF85063A RTC",
title="PCF85063A: a clock that tells you when not to trust it",
lede="BCD calendar registers, a programmable alarm, and one flag that answers "
     "the only question that matters after a power loss.",
body="""
<h2>The typed calendar</h2>

<p>A small fixed-address (<code>0x51</code>) real-time clock. The time is not a
blob of BCD bytes in the API — every field is a constrained subtype, so an
impossible date cannot be constructed:</p>

<pre><code>subtype Year_Number   is Natural range 2000 .. 2099;
subtype Month_Number  is Natural range 1 .. 12;
subtype Day_Number    is Natural range 1 .. 31;
subtype Hour_Number   is Natural range 0 .. 23;      --  24-hour mode only
subtype Minute_Number is Natural range 0 .. 59;
subtype Second_Number is Natural range 0 .. 59;

type Weekday is (Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday);
type Time is record ... end record;</code></pre>

<p class="note">Day-of-week is worth knowing about: in the chip it is just a free
0&nbsp;..&nbsp;6 counter that nothing validates against the date. The
<code>Weekday</code> naming is a convention the driver applies, not something the
hardware enforces — so the chip will happily tell you a Tuesday that isn't
one if something wrote it wrong.</p>

<h2>The flag that matters</h2>

<pre><code>procedure Get_Time (Dev : Device; T : out Time;
                    Valid : out Boolean; Result : out Status);</code></pre>

<p class="warn"><strong><code>Valid</code> is the whole point of using an RTC
chip.</strong> It reflects the oscillator-stop flag: <code>False</code> means
power was lost and the time it just handed you is meaningless. A clock that
returns a plausible-looking wrong time is worse than one that admits it does not
know, so branch on <code>Valid</code> before believing <code>T</code> — that is
the difference between resuming a schedule and corrupting a log.</p>

<p><code>Set_Time</code> stops the clock around the write, as the datasheet
requires, and clears the flag.</p>

<h2>The rest</h2>

<ul>
  <li><strong>Alarm</strong> on second, minute, hour, day or weekday — any
      subset — asserting an active-low open-drain INT line. Attach it with the
      <code>.Interrupts</code> child, observing the
      <a href="13-gpio.html">callback rules</a>: latch in the handler, do the
      I2C read in a task.</li>
  <li><strong><code>Stop_Clock</code></strong> halts the counters via
      <code>Control_1.STOP</code> without changing the loaded time.</li>
  <li><strong><code>Reset</code></strong> returns every register to its power-on
      default, which also stops the clock.</li>
</ul>

<p>Reads use the auto-incrementing pointer, and the pointer survives the STOP
between the two transactions — so a one-byte write followed by a separate read
streams correctly without needing
<a href="14-i2c.html">repeated START</a>. Up to 400&nbsp;kHz.</p>
"""),

dict(
slug="34-expanders",
nav="Port expanders",
title="Port expanders: TCA9555, CH422G and HC595",
lede="Three ways to buy more pins, and three quite different bargains &mdash; "
     "per-pin control, an all-or-nothing direction bit, and a shift register "
     "with no readback at all.",
body="""
<h2>Two levels of locking, again</h2>

<p>The two I2C expanders share the pattern the
<a href="30-display-touch.html">ST7789</a> uses: a <code>Session</code> owns the
<strong>device</strong>, while the <strong>I2C host</strong> is locked only for
each transaction. The per-device guards live in a fixed library-level array
keyed by (host, strap value), <em>not</em> inside the <code>Device</code> record
&mdash; a protected object there would be a local PO, which this runtime
forbids.</p>

<h2>TCA9555 &mdash; the conventional one</h2>

<pre><code>subtype Hardware_Address is Natural range 0 .. 7;    --  three strap pins
type Pin_Number is range 0 .. 15;                    --  P0 = 0..7, P1 = 8..15
type Port_Value is mod 2**16;
type Direction  is (Output, Input);
type Pin_State  is (Low, High);</code></pre>

<p>Sixteen pins in two 8-bit ports, per-pin direction, three address straps so up
to eight can share a bus, and an interrupt output with a <code>.Interrupts</code>
child. If you want an expander that behaves the way you expect, this is it.</p>

<h2>CH422G &mdash; the one that will surprise you</h2>

<p>Eight bidirectional pins plus four output-only ones. Same locking shape, very
different chip:</p>

<p class="warn"><strong>It is not a register-pointer device.</strong> Each
operation is a single-byte transaction to a <em>fixed, function-specific I2C
address</em>: <code>0x24</code> system config, <code>0x23</code> write OC
outputs, <code>0x38</code> write IO outputs, <code>0x26</code> read IO inputs.
One consequence follows immediately &mdash; there are no address straps and
<strong>only one CH422G per bus</strong>, so <code>Setup</code> takes no
address.</p>

<p class="warn"><strong>Direction is global.</strong> A single <code>IO_OE</code>
bit makes <em>all</em> of IO0..IO7 inputs or <em>all</em> of them outputs. There
is no per-pin direction. If you need three inputs and five outputs from one
CH422G, you cannot have it.</p>

<pre><code>type IO_Direction is (Inputs, Outputs);    --  all of IO0..IO7, together
type OC_Drive     is (Push_Pull, Open_Drain);   --  all of OC0..OC3, together</code></pre>

<p class="note">The config, OC and IO-output registers <strong>cannot be read
back</strong> &mdash; only the IO pins can, via RD-IO. So the driver keeps a
shadow initialised to the datasheet's power-on defaults (IO inputs, OC high,
push-pull). That shadow is only correct if the chip really is at its defaults
when you start, so a warm restart without a power cycle can leave the driver's
idea of the outputs out of step with reality. The chip also has no interrupt
output, hence no <code>.Interrupts</code> child.</p>

<p>This is the expander that holds the GT911's reset line on the Waveshare
ESP32-S3-Touch-LCD-7 &mdash; see <a href="30-display-touch.html">step 31</a> for
why that ordering matters.</p>

<h2>HC595 &mdash; a shift register on the SPI bus</h2>

<p>Not I2C at all: any number of 74HC595s daisy-chained (each chip's QH' into the
next chip's SER), giving <code>N * 8</code> outputs from three wires.</p>

<pre><code>type Controller (Chips : Positive) is limited private;

procedure Set_Output   (C : in out Controller; Index : Natural; On : Boolean);
procedure Set_Byte     (C : in out Controller; Chip : Natural; Value : Byte);
procedure Update       (C : in out Controller);        --  shift out + latch
procedure Write_Output (C : in out Controller; Index : Natural; On : Boolean);
procedure Clear_All / Set_All (C : in out Controller);</code></pre>

<p>The driver keeps a shadow of the intended state; <code>Update</code> shifts
the whole string out in chain order and pulses RCLK to latch it. So
<code>Set_Output</code> is buffered and <code>Write_Output</code> is
set-then-update &mdash; batch your changes and call <code>Update</code> once
rather than paying a full string shift per bit.</p>

<p class="note">It borrows the SPI host per <code>Update</code> <strong>with no
chip select asserted</strong>, so other devices on the bus are undisturbed. The
application must <code>Setup</code> and <code>Configure_Pins</code> the shared
SPI host first &mdash; the expander does not own it.</p>
"""),

dict(
slug="35-tx1812",
nav="TX1812 LEDs",
title="TX1812: addressable LEDs from RMT symbols",
lede="A single-wire LED family driven by generating its pulse train in "
     "hardware &mdash; and a strip whose whole memory footprint is fixed at "
     "elaboration.",
body="""
<h2>Timing as data</h2>

<p>The TX1812 &mdash; like the WS2812 "NeoPixel" family &mdash; is a single-wire,
daisy-chainable RGB LED. Twenty-four bits of colour are clocked in MSB-first as a
precisely timed pulse train: a <code>1</code> is long-high/short-low, a
<code>0</code> is short-high/long-low, and a low period over 80&nbsp;µs latches
the frame.</p>

<p>That is exactly the job <a href="21-rmt.html">RMT</a> exists for. The driver
generates the waveform as <strong>one RMT symbol per data bit</strong>, so the
timing is produced by hardware rather than by a delay loop that an interrupt
could disturb.</p>

<h2>A strip is sized at elaboration</h2>

<pre><code>type Color is record ... end record;
type Strip (Count : Positive) is limited private;</code></pre>

<p class="note">The <code>Count</code> discriminant fixes the whole footprint:
a <code>Strip</code> carries both the <code>Count</code>-pixel colour buffer
<em>and</em> the <code>Count * 24</code> RMT-symbol frame buffer. Declaring
<code>Panel : Strip (64)</code> reserves all of it at elaboration &mdash; no
heap &mdash; and the linker verifies it fits. You find out at link time that a
strip is too big for your RAM, not at run time.</p>

<pre><code>procedure Acquire (...; Channel : ...; Pin : ...; Blocks : ...);
function  Is_Valid (S : Strip) return Boolean;
procedure Set     (S : in out Strip; Index : Positive; C : Color);   --  buffered
procedure Set_All (S : in out Strip; C : Color);                     --  buffered
procedure Show    (S : in out Strip);                                --  clock out + latch
procedure Release (S : in out Strip);</code></pre>

<p>A <code>Strip</code> is a claimed handle in the usual style: it takes an RMT
transmit channel on <code>Acquire</code> and releases it on scope exit.
<code>Set</code> and <code>Set_All</code> only write the buffer; nothing reaches
the LEDs until <code>Show</code>.</p>

<h2>The limitation, stated plainly</h2>

<p class="warn"><strong>This driver currently drives a single LED.</strong> The
underlying <code>RMT.Transmit</code> sends at most what fits in the channel's
symbol RAM, so the practical case is <code>Strip (Count =&gt; 1)</code>; passing
<code>Blocks</code> (1&nbsp;..&nbsp;4) borrows extra RMT RAM for roughly
<code>Blocks * 2</code> LEDs &mdash; and borrowing blocks costs you the
higher-numbered RMT channels, as <a href="21-rmt.html">step 20</a> explains.</p>

<p>A longer string needs RMT wrap/refill support, which is a later step. The API
is already shaped for it &mdash; <code>Count</code>, per-pixel <code>Set</code>
&mdash; so only <code>Show</code>'s transport changes when it lands. Worth
knowing before you design a panel around it.</p>
"""),

dict(
slug="36-memory",
nav="Flash, EEPROM &amp; FRAM",
title="Off-chip memory: NOR flash, EEPROM and FRAM",
lede="Three non-volatile technologies with three different bargains &mdash; and "
     "a family catalogue that turns a whole product line into one shared "
     "driver plus a geometry.",
body="""
<h2>W25Q: SPI NOR flash</h2>

<p>Winbond W25Q-series, targeting the W25Q256FV (32&nbsp;MB, JEDEC ID
<code>EF 40 19</code>), on a general-purpose <a href="15-spi.html">SPI</a> host
with an <strong>application-driven chip select</strong> through the CS callback
&mdash; so it shares a bus with other devices.</p>

<pre><code>procedure Initialize          (Dev : Flash; OK : out Boolean);
procedure Read_Identification (Dev : Flash; ID : out JEDEC_ID);
function  Capacity_Bytes      (ID : JEDEC_ID) return Address;
procedure Read         (Dev : Flash; Addr : Address; Data : out Byte_Array);
procedure Erase_Sector (Dev : Flash; Addr : Address);
procedure Program_Page (Dev : Flash; Addr : Address; Data : Byte_Array);</code></pre>

<p class="warn"><strong>Over 16&nbsp;MB means 4-byte addressing.</strong>
<code>Initialize</code> puts the chip into 4-byte address mode (opcode
<code>0xB7</code>) once at startup, after which the <em>standard</em> opcodes
&mdash; Read <code>0x03</code>, Page-Program <code>0x02</code>, Sector-Erase
<code>0x20</code> &mdash; each take four address bytes, which is what the FV
datasheet prescribes. The FV has <strong>no</strong> dedicated 4-byte
program/erase opcodes; the <code>0x12</code>/<code>0x21</code>/<code>0xDC</code>
set is a later W25Q256JV addition, and issuing them here is <em>silently
ignored</em> &mdash; a failure that leaves your data unwritten with no error.</p>

<p>Flash is erase-before-write: sectors erase to all-ones, and a page program can
only clear bits. That asymmetry is why the API has both
<code>Erase_Sector</code> and <code>Program_Page</code> rather than a
<code>Write</code>.</p>

<h2>The 24C EEPROM catalogue</h2>

<p>Every part in the family &mdash; ST M24Cxx, Microchip 24AAxx/24LCxx, Atmel
AT24Cxx, onsemi CAT24Cxx &mdash; speaks the same protocol: device-type code
<code>1010</code>, a big-endian word address, page writes that <em>wrap</em>
inside the page rather than advancing, a ~5&nbsp;ms program cycle that NACKs
everything until it finishes, and a random read that turns the bus around on a
<a href="14-i2c.html">repeated START</a>.</p>

<p class="note">So a part is <strong>nothing but a geometry</strong>.
<code>ESP32S3.EEPROM_24C.Driver</code> implements the protocol once, and each
part is a child instantiation &mdash;
<code>with ESP32S3.EEPROM_24C.M24C64;</code> costs you one part, not the whole
catalogue.</p>

<p>Two traps the catalogue exists to encode:</p>

<p class="warn"><strong>Page size varies by vendor at the low end.</strong> ST's
M24C01/M24C02 have a 16-byte page; Atmel's and Microchip's 1K/2K parts have 8.
Guessing wrong does not fail loudly &mdash; the write wraps inside the page and
<em>silently overwrites what you just wrote</em>. Hence separate AT24C01 and
AT24C02 entries.</p>

<p class="warn"><strong>High address bits eat chip-enable pins.</strong> A part
whose array outruns its word address folds the surplus bits into the low bits of
its own device-select byte, costing a strap each: E0, then E1, then E2. A 24C16
folds three and has <em>no strap left</em> &mdash; only one can sit on a bus. The
driver derives this from capacity and address width rather than taking it as a
parameter. Microchip's 24LC1025 is the one part that breaks the rule, putting its
block bit in the high position instead.</p>

<p class="warn"><strong>Only parts marked <code>Verified</code> have been run
against real silicon.</strong> The rest are transcribed from datasheets &mdash;
the protocol is shared so they are very likely right, but nobody has watched them
on a scope. Each instance re-exports its status as
<code>Hardware_Verified</code> and says so in its spec banner.</p>

<h2>FRAM: non-volatile RAM</h2>

<p>Fujitsu MB85RS and Cypress/Infineon FM25 over SPI (and MB85RC/FM24 over I2C).
The distinction from EEPROM is the interesting part:</p>

<p class="note"><strong>FRAM is byte-writable, has no page boundary, and has no
program cycle at all</strong> &mdash; a write is committed as it is clocked in.
None of the EEPROM ceremony applies: no page-wrap trap, no ~5&nbsp;ms NACK-until-
done wait, no erase. If you are logging frequently, that difference is the whole
reason to pay for FRAM.</p>

<p>Because the read/write protocol is identical across manufacturers, parts are
keyed by <strong>density rather than part number</strong>:
<code>with ESP32S3.FRAM_SPI.Kbit_256;</code>. Only the identity command differs
by vendor, so <code>Read_Device_ID</code> returns the raw bytes rather than
pretending to decode them.</p>

<p>Address width follows density: 16&nbsp;Kbit&nbsp;..&nbsp;512&nbsp;Kbit use two
address bytes, 1&nbsp;Mbit uses three, and the 4&nbsp;Kbit parts use
<em>one</em>, with the ninth address bit carried in bit 3 of the opcode &mdash;
the legacy 25040 convention.</p>

<p class="warn">Status: <strong>no FRAM part has been run against real silicon
yet</strong>. These are datasheet-derived.</p>
"""),

dict(
slug="37-tlv2556",
nav="TLV2556 ADC",
title="TLV2556: a pipelined external ADC",
lede="Twelve bits and eleven channels over SPI &mdash; where the result you "
     "read belongs to the channel you asked for <em>last</em> time.",
body="""
<h2>The pipeline</h2>

<p>The TLV2556 is a 12-bit, 11-channel, 200-kSPS ADC with an internal reference,
on SPI mode 0. Each I/O cycle clocks an 8-bit command in on DATA&nbsp;IN &mdash;
top four bits select the analog input or a command, low four are configuration
register 1 &mdash; while <em>simultaneously</em> clocking the previous
conversion's result out on DATA&nbsp;OUT, MSB first.</p>

<p class="warn"><strong>The converter is pipelined:</strong> the result of a
channel you address now arrives on the <em>next</em> cycle. Read the datasheet's
timing naively and you will attribute every sample to the wrong channel &mdash; a
bug that produces entirely plausible numbers.</p>

<p><code>Read</code> hides this by priming the conversion, waiting it out, then
reading it back, so the value you get belongs to the channel you asked for.</p>

<pre><code>type Sample       is range 0 .. 4095;
type Analog_Input is ...;                                   --  11 channels
type Reference    is (Internal_4096mV, Internal_2048mV, External);</code></pre>

<p>The internal reference is the reason to choose this part over the
<a href="25-analog.html">on-chip SAR ADC</a>: a known 4.096&nbsp;V or
2.048&nbsp;V full scale gives you an absolute voltage, where the ESP's own ADC
gives a raw code needing per-chip calibration.</p>

<h2>Sharing the bus</h2>

<p>Like <a href="36-memory.html">W25Q</a>, chip select is application-driven
through an <a href="15-spi.html">SPI <code>CS_Select</code> callback</a>
(active-low here), so the ADC shares a bus with other devices. The driver always
uses 16-clock (2-byte) transfers with unipolar, MSB-first output.</p>

<p class="note">The in-tree example is a genuinely good bring-up test: it runs a
<strong>reference-independent self-test</strong> &mdash; asking the chip for its
internal zero, half-scale and full-scale conversions and checking they come back
as 0, 2048 and 4095. That proves the SPI framing, the pipeline handling and the
converter itself without needing a known voltage on any input pin.</p>
"""),

dict(
slug="38-gps",
nav="GPS receiver",
title="GPS: a background service, not a device handle",
lede="The one driver here you do not poll through a handle. A task owns the "
     "UART, decodes NMEA continuously, and publishes into a protected store "
     "that timestamps its own staleness.",
body="""
<h2>A different shape entirely</h2>

<p class="note">Every other device driver in this guide hands you a
<code>Device</code> and lets you poll it. This one does not. It is a
<strong>singleton background service</strong>: a library-level task owns one
<a href="16-uart.html">UART</a> for its lifetime, continuously reads the
receiver's NMEA-0183 stream, decodes it, and publishes results into a protected
store. The application just reads that store. There is no handle.</p>

<p>That follows from the device: a GPS talks whenever it likes, so something has
to be listening the whole time. This is the concrete case for
<a href="16-uart.html">interrupt-driven RX</a> &mdash; a receiver that streams
asynchronously is exactly what would overflow a polled FIFO.</p>

<pre><code>procedure Setup (...);          --  call once at startup; Rx is the only pin needed

function Current_Position return Position_Reading;
function Current_Fix      return Fix_Reading;
function Current_Time     return Time_Reading;
function Current_Date     return Date_Reading;
--  ... plus velocity, signal and PPS readings</code></pre>

<h2>Why a fix is one record</h2>

<p class="warn"><strong>Latitude and longitude are a single
<code>Position</code> record updated by one protected action.</strong> Split
across two variables, a reader could catch a new latitude with an old longitude
&mdash; a coordinate that describes somewhere you have never been, with nothing
to signal it is wrong. Every published value is written and read under the
store's lock, so a reader never sees a half-updated value, and a fix is always a
consistent pair.</p>

<h2>Staleness is explicit</h2>

<p>Each value group carries the <code>Ada.Real_Time.Time</code> at which it was
last refreshed, and the driver <strong>only refreshes a group from a valid
sentence</strong> &mdash; a lost fix is not written at all.</p>

<p class="warn">So a stale group keeps its <em>old</em> timestamp rather than
being cleared, and <code>Current_Position</code> will happily return a position
from twenty minutes ago that reads as perfectly plausible. Compare
<code>Age (R.Updated_At)</code> against your own tolerance before trusting any
reading. The API cannot decide for you how old is too old &mdash; that depends on
whether you are tracking a ship or a pedestrian.</p>

<pre><code>type Fix_Quality is (No_Fix, GPS_Fix, DGPS_Fix);
type Fix_Type    is (Fix_None, Fix_2D, Fix_3D);
type GNSS_System is (GPS, GLONASS, Galileo, BeiDou, QZSS, Other);</code></pre>

<p>The satellite list and <code>GNSS_System</code> reflect that a modern receiver
tracks several constellations at once. Uses the controlled UART session plus a
task and protected objects, so it is embedded/full only.</p>
"""),

dict(
slug="39-w5500",
nav="W5500 Ethernet",
title="W5500: Ethernet with the stack on the chip",
lede="A hardwired TCP/IP controller with eight hardware sockets &mdash; and a "
     "layered driver that ends up looking like GNAT.Sockets.",
body="""
<h2>The stack is not yours</h2>

<p>The WIZnet W5500 is an SPI slave carrying an on-chip 10/100 PHY, a MAC,
<strong>and a hardwired TCP/IP stack</strong> exposing eight independent hardware
sockets. You are not writing a TCP implementation against it; you are driving one
that already exists in silicon.</p>

<p>The driver is built in layers, which is worth knowing because it decides
which package you should be reaching for:</p>

<table>
  <thead><tr><th>Layer</th><th>What it gives you</th></tr></thead>
  <tbody>
    <tr><td><code>ESP32S3.W5500</code></td>
        <td>The SPI frame transport, hardware/software reset, common registers
            (identity, network config) and PHY link status.</td></tr>
    <tr><td><code>.Sockets</code></td>
        <td>The socket engine: TCP and UDP over the eight hardware sockets, with
            a self-contained <code>Socket</code> handle and a
            <code>Status</code> error model.</td></tr>
    <tr><td><code>.DHCP</code></td>
        <td>A minimal DHCP client &mdash; a software protocol over UDP, so it
            sits above the socket engine rather than in the chip.</td></tr>
    <tr><td><code>.Net_Device</code></td>
        <td>The W5500 as a concrete <code>Net_Devices.Device</code>, so it can
            back the chip-neutral <code>GNAT.Sockets</code> facade.</td></tr>
    <tr><td><code>.Interrupts</code></td>
        <td>The INTn line. The base layer configures it as a pulled-up input but
            does not use it &mdash; the first pass is polling.</td></tr>
  </tbody>
</table>

<h2>The SPI frame, and why CS is a GPIO</h2>

<p>Every access is one frame in Variable Length Data Mode: a 16-bit offset, a
control byte, then N data bytes, with the offset auto-incrementing inside the
frame. VDM keeps the bus shareable rather than demanding an exclusive
transaction per register.</p>

<p class="note">CS is driven as a <strong>plain GPIO, not routed to the SPI
peripheral</strong> &mdash; exactly as with <a href="28-sd.html">SD over
SPI</a> &mdash; because it has to be held low across all three phases of the
frame, and the peripheral's own CS pulses per transfer. Another concrete case for
<a href="15-spi.html">SPI's <code>CS_Pin</code></a>. The chip runs in SPI mode
0.</p>

<h2>Two levels of concurrency</h2>

<p>Each frame takes the SPI host's session for its own transfer and releases it
&mdash; the "lock the bus only as long as necessary" idiom shared with the other
SPI drivers &mdash; so every W5500 access is atomic against any other task or
device on that bus.</p>

<p>The socket layer then adds <strong>per-socket ownership</strong> on top. The
eight sockets are genuinely independent, so different tasks can drive different
sockets simultaneously, with the transport serialising the shared bus
underneath. That is the arrangement that makes a multi-socket application
straightforward rather than a locking exercise.</p>

<h2>What is not there yet</h2>

<ul>
  <li><strong>Polling, not interrupts.</strong> The blocking operations
      &mdash; <code>Connect</code>, and <code>Send</code>'s completion &mdash;
      poll. INTn is wired and configured but unused at this layer.</li>
  <li><strong>DHCP has no renewal.</strong> <code>Acquire_Lease</code> is
      one-shot; call it again before the lease expires, because nothing will do
      it for you and the failure mode is a silently dead network.</li>
</ul>

<p>A useful pairing: give the W5500 its address from
<a href="29-chip-id.html">the eFuse MAC block</a>'s <code>Ethernet</code> entry
&mdash; a real manufacturer-assigned address rather than one you invented, which
matters as soon as two of your boards share a segment.</p>
"""),

dict(
slug="40-net-stack",
nav="The network stack",
title="The chip-neutral network stack",
lede="One <code>GNAT.Sockets</code> subset, several possible NICs, and a "
     "routing table that fails traffic over when a link drops &mdash; so "
     "networking code does not name the hardware carrying it.",
body="""
<h2>The contract a NIC must satisfy</h2>

<p><code>Net_Devices.Device</code> is the chip-neutral interface. Each interface
chip provides one concrete implementation; the facade keeps a registry and
dispatches, so a board can carry <strong>more than one NIC, of different types,
in a single binary</strong>.</p>

<pre><code>type IPv4_Address is array (0 .. 3) of Octet;
type MAC_Address  is array (0 .. 5) of Octet;
subtype Port_Number  is Interfaces.Unsigned_16;
type Interface_Id is range 0 .. Max_Interfaces - 1;

type Status    is (OK, Not_Open, Closed_By_Peer, Timed_Out, Refused, No_Space, Error);
type Transport is (TCP, UDP);
type Device    is limited interface;</code></pre>

<p class="note">This is the <strong>offloaded-stack</strong> model: the device
provides TCP and UDP sockets directly, addressed by an index the device maps to
its own per-socket state &mdash; the <a href="39-w5500.html">W5500</a> has eight
hardware sockets, for instance. A raw-MAC chip cannot satisfy this interface as
it stands; it needs a software TCP/IP stack implementing it, which is exactly
what the <a href="43-wifi.html">Wi-Fi</a> side does.</p>

<h2>Writing ordinary Ada networking code</h2>

<p><code>GNAT.Sockets</code> here is a bare-metal subset of the standard package.
Code written against the desktop API &mdash; <code>Create_Socket</code>,
<code>Bind</code>, <code>Listen</code>, <code>Accept</code>,
<code>Connect</code>, <code>Send</code>, <code>Receive</code>,
<code>Close</code>, and the stream over a socket &mdash; compiles and runs
unchanged within that subset. That is why <a href="41-dns-ntp.html">DNS_Client
and NTP_Client</a> are the same source on a desktop and on the board.</p>

<h2>Routing and failover</h2>

<p><code>Net_Routes</code> is a small IPv4 table for boards with more than one
interface. Selection is: among routes whose destination matches
<strong>and whose interface is up</strong>, take the longest prefix, then the
lowest metric.</p>

<pre><code>procedure Add_Route   (...);
procedure Set_Default (Iface : Interface_Id; Metric : Natural := 100);
procedure Configure   (Is_Up : Up_Query);      --  liveness is INJECTED</code></pre>

<p>So a wired interface at metric 10 and a cellular one at metric 100 give you
automatic failover: traffic prefers wired and falls back to cellular only when
wired is down. Liveness is injected rather than wired to a particular stack,
which keeps the table pure logic &mdash; and host-testable against a mock
up-state.</p>

<p>Register interfaces with <code>Add_Interface</code> (the first is the
default). An unpinned socket follows the table per destination: TCP at
<code>Connect_Socket</code>, UDP <em>per datagram</em> at the
<code>To</code>-form of <code>Send_Socket</code>. <code>Set_Interface</code> pins
a socket to one interface, fail-closed.</p>

<h2>The concurrency contract</h2>

<p class="warn"><strong>A <code>Socket_Type</code> value has exactly one owning
task.</strong> Nothing serialises concurrent operations on the same socket, and
the routing forms may re-home it mid-call. Different sockets <em>may</em> be
driven from different tasks &mdash; slot claim/release is a protected object and
per-socket state belongs to that socket alone &mdash; but sharing one socket
between tasks is your bug to avoid, not the library's to prevent.</p>

<p>Register interfaces and configure routes during bring-up, before tasks start
using sockets. Requires the embedded or full profile.</p>
"""),

dict(
slug="41-dns-ntp",
nav="DNS &amp; NTP",
title="DNS and NTP: portable by construction",
lede="Two clients written entirely against <code>GNAT.Sockets</code>, so the "
     "same source runs on a desktop and on the board &mdash; and one shared "
     "concurrency wrinkle worth knowing.",
body="""
<h2>One line to resolve a name</h2>

<pre><code>function Resolve (...) return ...;    --  Net_Resolver</code></pre>

<p><code>Net_Resolver</code> turns a host name into an address whatever is
carrying the traffic. Resolution is <strong>a real DNS query of our own</strong>
&mdash; a UDP A-record request that <code>DNS_Client</code> issues over
<a href="40-net-stack.html">GNAT.Sockets</a> &mdash; so it works identically over
Ethernet, Wi-Fi, cellular, or whatever the routing table points at.</p>

<p class="note"><strong>Why not use the modem's own resolver?</strong> Because
one was tried and removed. The BG95's <code>AT+QIDNSGIP</code> silently refused
answers whose shape it did not like &mdash; a CNAME chain onto several A records
failed where a bare A record resolved. Doing DNS ourselves means one code path
with predictable behaviour, rather than a per-modem set of quirks.</p>

<p><code>DNS_Client</code> offers both <code>Resolve</code> (UDP) and
<code>Resolve_TCP</code>, the latter for answers too large for a datagram.
<code>NTP_Client.Query</code> is the same shape &mdash; a UDP query reading the
transmit timestamp out of the reply &mdash; with <code>To_UTC</code> to convert
it.</p>

<h2>Portability is the point</h2>

<p>Neither client contains anything chip-specific. On the board you call
<code>GNAT.Sockets.Initialize (Device)</code> once during bring-up; on a desktop
sockets are always usable. The same source then compiles in both places, which
is what lets these be tested on a host rather than only on hardware.</p>

<h2>The shared wrinkle</h2>

<p class="warn"><strong>Both keep package-global rotors</strong> &mdash; the
transaction id and the default source port for DNS, a source-port counter for
NTP. Concurrent calls from several tasks corrupt nothing, but two in-flight
queries can land on the same source port, and one then fails its reply check.
That surfaces as a <em>failed lookup</em>, not an exception or corruption. If you
resolve from more than one task, either serialise the calls or accept the
retry.</p>

<p class="note">The source-port rotation is not incidental &mdash; a fixed source
port is what made an earlier cellular setup fail, because the carrier's NAT
poisoned the flow. Rotating ports is a deliberate hardening measure, and the
collision above is its small cost.</p>

<h2>Encrypted DNS</h2>

<p>Plain DNS is readable by anything on the path, and on a shared or hostile
network the names a device looks up leak what it is doing.
<code>DNS_TLS</code> adds the two encrypted transports over the
<a href="42-tls.html">pure-Ada TLS 1.3 stack</a>:</p>

<table>
  <thead><tr><th>Transport</th><th>How</th></tr></thead>
  <tbody>
    <tr><td><strong>DoT</strong> (RFC 7858)</td>
        <td>The ordinary DNS message, inside TLS, on port 853.</td></tr>
    <tr><td><strong>DoH</strong> (RFC 8484)</td>
        <td>A minimal HTTP/1.1 <code>POST</code> of
            <code>application/dns-message</code> over HTTPS, port 443 &mdash;
            so it survives networks that block 853.</td></tr>
  </tbody>
</table>

<p class="note"><strong>The message bytes are the same proven ones every
transport shares.</strong> Only the carriage differs, so the parser and builder
under UDP, TCP, DoT and DoH are one implementation with one set of tests
(<a href="53-testing.html">step 52</a>) &mdash; not four chances to get a
message wrong.</p>

<p class="warn">Trust stays with the <em>application</em>, exactly as in the
HTTPS examples: the caller establishes the TCP connection and supplies the trust
anchors. The resolver does not carry a built-in root store or decide for you
which resolver is trustworthy. Note also that a root-pinned DoT or DoH endpoint
may need <a href="42-tls.html">P-384</a> rather than P-256, depending on whose
certificate chain you are anchoring to.</p>
"""),

dict(
slug="42-tls",
nav="TLS 1.3",
title="TLS 1.3, in Ada, with no C library",
lede="A complete client handshake &mdash; ECDHE, AEAD, certificate chain "
     "validation to a pinned root, and session resumption &mdash; with every "
     "line of crypto in Ada or the chip's own accelerators.",
body="""
<h2>What it actually does</h2>

<p>The headline claim is easy to under-read, so here is the pipeline the
in-tree <code>esp32s3_tls_weather</code> example runs end to end against a live
public server:</p>

<pre><code>DNS -&gt; TCP connect :443 -&gt; TLS 1.3 handshake
   (X25519 ECDHE, AES-128-GCM, HKDF, RSA-PSS CertificateVerify, Finished)
-&gt; validate the server's chain to a PINNED root (ISRG Root X1)
-&gt; encrypted HTTP GET -&gt; decrypt and parse the reply</code></pre>

<p>No external C TLS library is involved. The crypto is Ada &mdash; SPARKNaCl
plus this repository's own P-256/P-384 &mdash; over the
<a href="27-crypto.html">chip's SHA and AES accelerators</a>.</p>

<h2>The client surface</h2>

<pre><code>type Session is limited private;

procedure Hello (...);                                --  ClientHello / ServerHello
function  Keys_Ready            (S : Session) return Boolean;
function  Have_Server_Cert      (S : Session) return Boolean;
function  Server_Cert_Verify_OK (S : Session) return Boolean;
function  Server_Finished_OK    (S : Session) return Boolean;
function  Ready                 (S : Session) return Boolean;

procedure Send (S : in out Session; Sock : GNAT.Sockets.Socket_Type; Data : Byte_Array);
procedure Recv (...);

function  Has_Ticket          (S : Session) return Boolean;
function  Server_Accepted_PSK (S : Session) return Boolean;
procedure Resume (...);</code></pre>

<p>The handshake state is inspectable rather than a single opaque boolean, which
matters when a connection fails: you can tell "the certificate chain was
rejected" from "the server never finished" from "we never got keys at all".</p>

<p class="note"><code>Hello</code> runs the <strong>whole</strong> handshake,
not just the opening exchange &mdash; ClientHello, ServerHello, the key schedule,
the server's encrypted flight (EncryptedExtensions, Certificate,
CertificateVerify, Finished) and our Finished. When it returns,
<code>Ready</code> reports the application channel is open.</p>

<p>A detail worth copying if you ever write a client: the ClientHello sends a
<strong>key_share entry for both x25519 and P-256</strong>, not just the
preferred one. Offering only one group costs a HelloRetryRequest round trip
whenever the server prefers the other. Both paths are hardware-verified &mdash;
a P-256-only ClientHello completes a handshake just as an x25519 one does.</p>

<h2>Chain validation is the hard part</h2>

<pre><code>function Validate (Chain, Anchors : Cert_List; Host : String;
                   Now : X509.Time_64) return Result;</code></pre>

<p>A handshake that completes proves you are talking to <em>somebody</em>. What
makes it TLS is <code>Chain_Verify</code>, which puts the pieces together:</p>

<ul>
  <li>per-link signature verification;</li>
  <li>validity dates &mdash; hence the <code>Now</code> parameter, and hence why
      <a href="41-dns-ntp.html">NTP</a> is not optional;</li>
  <li>hostname matching;</li>
  <li>the X.509 v3 usage extensions &mdash; <code>basicConstraints</code>,
      <code>keyUsage</code>, <code>extKeyUsage</code>;</li>
  <li>anchoring to a <strong>pinned</strong> set of roots, not a system trust
      store, because there isn't one.</li>
</ul>

<p class="note">The <code>Now</code> parameter is the detail worth internalising:
without a real clock, certificate expiry cannot be checked, and a chain that
expired years ago validates happily. On a board that means fetching the time
before you can meaningfully verify anything &mdash; which is why NTP comes first
in the pipeline above.</p>

<h2>The elliptic curves</h2>

<pre><code>function Verify     (Pub_X, Pub_Y, Hash, R, S : Bytes_32) return Boolean;
function Public_Key (Priv : Bytes_32; Pub_X, Pub_Y : out Bytes_32) return Boolean;
function ECDH       (...);
function Sign       (Priv, Hash : Bytes_32; R, S : out Bytes_32) return Boolean;</code></pre>

<p>P-256 and P-384 are pure Ada with no chip dependency. Two implementation
choices are worth noting because they are the right ones:</p>

<ul>
  <li><strong>Signing is deterministic per RFC 6979</strong>, so it needs no
      per-signature randomness. Given <a href="27-crypto.html">the RNG caveat</a>
      &mdash; no real entropy source on this runtime &mdash; that is not a
      stylistic preference, it removes a way to leak the private key.</li>
  <li>Verification and ECDH operate entirely on public values, so ordinary
      variable-time code is fine there; the sensitive arithmetic is Montgomery
      (CIOS) with constants derived on the fly, and points are Jacobian.</li>
</ul>

<p>Examples: <code>esp32s3_tls_hello</code> (handshake),
<code>esp32s3_tls_weather</code> (real-world HTTPS),
<code>esp32s3_tls_resume</code> (session resumption), plus
<code>esp32s3_wifi_tls</code> over the radio.</p>
"""),

dict(
slug="43-wifi",
nav="Wi-Fi",
title="Wi-Fi: pure Ada around three binary blobs",
lede="The one place the from-scratch claim has an asterisk &mdash; and the "
     "asterisk is smaller, and better fenced, than you would expect.",
body="""
<h2>What is a blob and what is not</h2>

<p>The radio's MAC and PHY are undocumented, so the driver runs Espressif's
closed libraries (<code>libnet80211</code>, <code>libpp</code>,
<code>libphy</code>, <code>libcore</code>). Everything <em>around</em> them is
Ada written against the embedded (Jorvik) runtime:</p>

<table>
  <thead><tr><th>Ours, in Ada</th><th>What it does</th></tr></thead>
  <tbody>
    <tr><td><code>.OS_Adapter</code>, <code>.RTOS</code></td>
        <td>Maps the blobs' RTOS calls onto Jorvik tasks &mdash; so
            <strong>FreeRTOS still never runs</strong>.</td></tr>
    <tr><td><code>.PHY</code></td><td>PHY/RF calibration, and persisting calibration data.</td></tr>
    <tr><td><code>.Supplicant</code></td><td>The WPA2-PSK 4-way handshake.</td></tr>
    <tr><td><code>.IP</code>, <code>.DHCP</code>, <code>.Net_Device</code></td>
        <td>A software TCP/IP stack presenting the radio as a
            <a href="40-net-stack.html">Net_Device</a>.</td></tr>
    <tr><td><code>.Interrupt</code>, <code>.Port</code>, <code>.Core_Shim</code></td>
        <td>The interrupt, timer and core glue the blobs expect.</td></tr>
    <tr><td><code>.Sniffer</code></td><td>Promiscuous-mode capture.</td></tr>
  </tbody>
</table>

<p class="note">The blobs are <strong>Apache-2.0 and fetched, not committed</strong>
&mdash; <code>tools/fetch-wifi-blobs.sh</code> pins them to exact upstream
commits and verifies each by sha256. So the repository still contains no opaque
vendor binary for Wi-Fi; you choose to download them.</p>

<h2>The supplicant is ours, deliberately</h2>

<p>The 4-way handshake is pure Ada: derive the PMK with PBKDF2-HMAC-SHA1, run the
handshake (PTK via SHA1-PRF, MIC via HMAC-SHA1, GTK via AES key-unwrap), and
reply with message 2 of 4.</p>

<p class="warn">That placement is the security-relevant part. Doing the handshake
in Ada means <strong>your PSK and the derived keys never pass through blob
code</strong> &mdash; the blob is handed an already-established association, not
your passphrase. A driver that let the closed library do WPA2 would be trusting
it with the one secret that matters.</p>

<h2>Using it</h2>

<pre><code>type Auth_Mode is ...;
type AP_Record is record ... end record;
type AP_List   is array (Positive range &lt;&gt;) of AP_Record;

procedure Initialize (...);
procedure Scan       (...);
procedure Connect    (...);
function  Connected        return Boolean;
function  Current_Channel  return Natural;</code></pre>

<p class="warn"><strong>Not re-entrant.</strong> This package drives a single
radio and one caller &mdash; typically the environment task &mdash; owns it. Do
not call <code>Scan</code> and <code>Connect</code> from two tasks.</p>

<p class="note"><code>Connect</code> returns as soon as the association is
<em>started</em>. The association and the 4-way handshake then run to completion
on the internal Wi-Fi task, so poll <code>Connected</code> to learn when the link
is actually up. Treating <code>Connect</code>'s return as "we are on the network"
is the mistake to avoid.</p>

<p>The version-locked C structs stay in the body; the spec exposes clean Ada
records, so a blob update cannot ripple into your code. Examples run scan,
promiscuous sniffing, DNS, HTTP and full HTTPS over the radio.</p>
"""),

dict(
slug="44-modbus",
nav="Modbus TCP",
title="Modbus TCP: master and slave",
lede="An industrial protocol on the socket facade &mdash; and a library that "
     "deliberately owns none of your data.",
body="""
<h2>The data model, not stored here</h2>

<p>Modbus is big-endian on the wire, with four tables: coils (1-bit read/write),
discrete inputs, input registers and holding registers.</p>

<p class="note"><strong>This library never stores any of them.</strong> The
application owns its data: the master fills caller-supplied buffers, and the
slave is implemented by <em>deriving</em> from <code>Modbus.Slave.Server</code>
and overriding the accessors. That is the right split for an embedded device
&mdash; your registers are usually views onto real state (a sensor reading, a
relay's position), not a block of memory that happens to be addressed twice.</p>

<h2>Master and slave</h2>

<ul>
  <li><strong><code>Modbus.Master</code></strong> &mdash; the client. Reads and
      writes the four tables against a remote device, returning a status rather
      than raising, so a dropped link is an ordinary control-flow case.</li>
  <li><strong><code>Modbus.Slave</code></strong> &mdash; the server. You derive
      the tagged type and put your data in the extension, so the library never
      needs to know its shape or size.</li>
</ul>

<h2>Written against the facade</h2>

<p>Like <a href="41-dns-ntp.html">DNS and NTP</a>, Modbus is written entirely
against <a href="40-net-stack.html">GNAT.Sockets</a>, so the same source runs on
a desktop and on the board. That is what makes an industrial protocol testable
without a PLC on the bench: run the slave on a host, point a standard Modbus
client at it, and you have exercised the wire format before any hardware is
involved.</p>

<p>On a multi-interface board, a Modbus connection follows
<a href="40-net-stack.html">the routing table</a> like any other socket, or can
be pinned to one interface &mdash; which is what you want when the PLC network is
deliberately separate from the internet-facing one.</p>
"""),

dict(
slug="45-ftp",
nav="FTP",
title="FTP: client and server",
lede="Outbound-only transfers streamed through a callback, and an anonymous "
     "server that exposes your filesystems to a desktop &mdash; both on the "
     "socket facade.",
body="""
<h2>The client: passive, binary, streamed</h2>

<p>A small RFC 959 client written entirely against
<a href="40-net-stack.html">GNAT.Sockets</a>, so like
<a href="41-dns-ntp.html">DNS and NTP</a> the same source runs on a desktop and
on the board.</p>

<p class="note"><strong>Passive mode only, deliberately.</strong> An embedded
client should only ever make <em>outbound</em> connections, so every transfer
asks the server to listen (PASV) and the client connects to it. No listening
socket, and NAT/firewall friendly. A session uses two sockets at a time &mdash;
the persistent control connection plus one transient data connection per
transfer &mdash; comfortably within the <a href="39-w5500.html">W5500</a>'s
eight.</p>

<p class="warn"><strong>Transfers are streamed through a caller callback</strong>,
so a file never has to be held whole in RAM &mdash; which on a board with a few
hundred KB is the difference between working and not. As with every callback in
this HAL, the sink and source must obey the
<a href="13-gpio.html">closure-free rule</a>: library-level, no captured state,
context passed explicitly.</p>

<p>Transfers are binary (<code>TYPE I</code>). There is no ASCII mode, which is
the right call &mdash; ASCII mode's line-ending translation silently corrupts
every non-text file.</p>

<h2>The server: your filesystems, over the network</h2>

<p>An anonymous passive-mode server that exposes one or more
<a href="47-ext4.html">ext4</a> filesystems, so a desktop FTP client can browse,
download, upload and manage the board's files.</p>

<p>Filesystems are presented through <code>ESP32S3.Ext4.VFS</code>: register each
under a name <em>before</em> calling <code>Run</code>, and they appear as
top-level directories in one tree &mdash; <code>/flash</code>, <code>/sd</code>.
The virtual root lists the mount names. Adding a second storage device later is
one more <code>VFS.Add</code> call and nothing else changes.</p>

<p class="warn"><strong>Anonymous</strong> means exactly that: no authentication.
This is for a bench, a closed lab network or a deliberately isolated segment
&mdash; not for anything reachable from a wider network. If the board is on a
routable network, pin the socket to the interface you intend
(<a href="40-net-stack.html"><code>Set_Interface</code></a>) rather than letting
the routing table choose.</p>
"""),

dict(
slug="46-block-dev",
nav="Block devices &amp; wear levelling",
title="Block devices and wear levelling",
lede="One abstraction the filesystems talk to, thin adapters underneath it, "
     "and a filter in the middle that stops a hot metadata block from killing "
     "one sector of your flash.",
body="""
<h2>A vtable, not a tagged type</h2>

<pre><code>type Sector       is array (0 .. 511) of Interfaces.Unsigned_8;
type Sector_Index is new Interfaces.Unsigned_64;

type Read_Proc  is access procedure (Ctx : System.Address; LBA : Sector_Index; Data : out Sector);
type Write_Proc is access procedure (Ctx : System.Address; LBA : Sector_Index; Data : Sector);
type Count_Func is access function  (Ctx : System.Address) return Sector_Index;</code></pre>

<p><code>ESP32S3.Block_Dev</code> is a record of access-to-subprogram plus an
opaque context &mdash; mirroring lwext4's <code>ext4_blockdev</code> vtable.
<strong>No tagging, no finalization, swappable at run time.</strong> That keeps
it usable from anywhere and makes a device something you can substitute in a
test.</p>

<p>Behind it sit thin adapters: <code>SD_SPI_Source</code> and
<code>SDMMC_Source</code> for <a href="28-sd.html">SD cards</a>,
<code>W25Q_Source</code> for <a href="36-memory.html">SPI NOR flash</a>, and a
file-backed device in the host test harness &mdash; which is what lets the whole
filesystem stack be developed and tested on a PC.</p>

<p class="note">The error model is Ada's: the primitive Read/Write
<strong>raise</strong> <code>Ada.IO_Exceptions.Device_Error</code> on a hardware
failure, with the adapters converting the SD driver's <code>Status</code> enum
into that raise. So a media error propagates rather than being quietly returned
and ignored.</p>

<h2>The wear-levelling filter</h2>

<p>Flash wears out per erase block. A filesystem writes some blocks far more
often than others &mdash; an ext4 metadata block, say &mdash; so without
intervention one physical sector dies long before the rest of the chip.</p>

<p><code>Block_Dev.WL</code> is a <strong>Block_Dev over a Block_Dev</strong>: it
takes the raw medium and presents a smaller logical device whose sectors are
remapped so that, over time, every logical 4&nbsp;KB block visits every physical
4&nbsp;KB block. Because it is a plain filter it carries no flash-specific code
and runs unchanged on the host, where it is brute-force tested.</p>

<pre><code>--  a typical stack, bottom to top
W25Q flash  ->  Block_Dev.W25Q_Source  ->  Block_Dev.WL  ->  Ext4</code></pre>

<p class="note"><strong>O(1) state:</strong> just a move counter &mdash; there is
no per-block map to keep in RAM or rebuild at mount. A move erases the
destination block in one shot through the lower device's optional
<code>Erase_Sectors</code> before copying, so each move costs exactly one
erase.</p>

<p class="warn"><strong>This is <em>dynamic</em> wear levelling only.</strong> It
bounds how unevenly <em>write</em> activity wears the chip, but it does not
actively relocate cold, never-written blocks &mdash; so data you write once and
never touch keeps its physical block out of rotation. That is sufficient for a
32&nbsp;MB part; it is not the same guarantee as static wear levelling.</p>

<p>Config blocks are rewritten once per move, which is their wear cost. Raising
<code>Update_Rate</code> trades levelling aggressiveness for less move and config
overhead.</p>
"""),

dict(
slug="47-ext4",
nav="ext4 filesystem",
title="ext4: a real filesystem, in Ada",
lede="A from-scratch ext2/3/4 implementation with JBD2 journal replay, an "
     "on-device formatter, and an error model that is simply Ada's.",
body="""
<h2>Scope</h2>

<p><code>ESP32S3.Ext4</code> is a reimplementation of lwext4 in pure Ada: read
<em>and</em> write &mdash; create, write, truncate, mkdir, rmdir, unlink, rename,
link &mdash; with metadata checksums and JBD2 journal replay. It is pure logic
over <a href="46-block-dev.html">Block_Dev</a>, so it also compiles host-native
and is developed against a harness that checks every operation against
<code>mke2fs</code>, <code>debugfs</code> and <code>e2fsck</code>.</p>

<p>The pieces are separate children rather than one monolith: superblock, group
descriptors, inodes, bitmaps, block map, block cache, directories, paths, files,
the writer, the journal, mkfs, and a VFS layer that presents several mounted
volumes as one tree.</p>

<h2>The error model is Ada's</h2>

<p class="note">Operations <strong>raise</strong> rather than returning status
codes, and the IO-family exceptions are the standard ones from
<code>Ada.IO_Exceptions</code> &mdash; chosen so a future
<code>Ada.Streams.Stream_IO</code> bridge maps cleanly &mdash; plus a few
filesystem-specific additions. That is a deliberate departure from the
<code>Status</code>-out-parameter style used by the
<a href="14-i2c.html">bus drivers</a>, and it is the right one here: a
filesystem call has many more failure modes than a bus transaction, and threading
them all through return values would drown the call sites.</p>

<h2>Journal replay</h2>

<p>The JBD2 journal lives in inode 8 as a regular file. On a volume whose
superblock has the <code>RECOVER</code> incompat flag set, pending committed
transactions are replayed into the filesystem before normal use, then the journal
is reset and the flag cleared &mdash; which is what makes a power loss survivable
rather than corrupting.</p>

<p class="warn">Two things to know. The journal's on-disk structures are
<strong>big-endian</strong>, unlike the rest of ext &mdash; a genuine trap when
reading the code. And only the classic non-checksummed format is handled (ext3,
and ext4 with <code>^metadata_csum</code>); a checksummed journal (CSUM_V2/V3)
raises <code>Unsupported_Feature</code> rather than guessing.</p>

<h2>Formatting on the device</h2>

<p><code>Ext4.Mkfs</code> lays down a fresh minimal ext4 directly on a
Block_Dev: one block group, a root directory and <code>lost+found</code>, no
journal, no <code>metadata_csum</code>. The result mounts read-write with this
filesystem and passes the host's <code>e2fsck</code> &mdash; which is the claim
worth making, because it means the format is genuinely correct rather than merely
self-consistent.</p>

<p class="note">It writes only metadata and the two directory blocks, leaving
data blocks untouched (the filesystem initialises each as it is allocated). So
formatting a 32&nbsp;MB part is fast, but it also means <code>Mkfs</code> is not
an erase &mdash; old file contents remain on the medium until overwritten.</p>

<p class="warn">Targets the embedded/full runtimes: it needs exceptions,
finalization, secondary stack and a heap.</p>
"""),

dict(
slug="48-fat16",
nav="FAT16",
title="FAT16: the filesystem a PC can read",
lede="Deliberately narrow &mdash; read-only, FAT16 only, long filenames "
     "supported &mdash; because its whole job is being mountable by an operating "
     "system you do not control.",
body="""
<h2>Why it exists alongside ext4</h2>

<p><a href="47-ext4.html">ext4</a> is the better filesystem, but only Linux
mounts it. When a device exposes its storage over USB mass storage it appears as
a removable drive, and if it is formatted FAT then Windows, macOS and Linux all
mount it with no driver and no ceremony: the user drops files on it and the
device reads them back.</p>

<p>That single use case sets the whole design.</p>

<h2>The deliberate limits</h2>

<table>
  <thead><tr><th>Choice</th><th>Reason</th></tr></thead>
  <tbody>
    <tr><td><strong>Read only</strong></td>
        <td>The PC writes; the device reads. Nothing here needs to write, so
            nothing here can corrupt a volume the user cares about.</td></tr>
    <tr><td><strong>FAT16 only</strong></td>
        <td>FAT12 and FAT32 volumes are <em>recognised and rejected</em> rather
            than misread, so wrongly formatted media fails loudly instead of
            returning plausible rubbish.</td></tr>
    <tr><td><strong>Long filenames (VFAT)</strong></td>
        <td>Because a user dropping files on a drive will not respect 8.3, and
            silently mangling their names is not acceptable.</td></tr>
  </tbody>
</table>

<p class="note">"Recognised and rejected" is the part worth copying as a design
habit. A FAT32 volume read as FAT16 does not fail &mdash; it returns entries
that look like files. Refusing is strictly better than a plausible wrong
answer.</p>

<h2>Formatting</h2>

<p><code>Fat16.Mkfs</code> is a separate child that lays down an empty volume on
blank media. It chooses 4&nbsp;KB clusters aligned to the NOR erase unit, so the
block layer's read-modify-write stays one erase per cluster written &mdash;
the filesystem's geometry chosen to suit the medium underneath it.</p>

<p>It reads from either an MBR-partitioned disk (what Windows expects on a USB
stick) or a bare boot sector at LBA 0, and sits on
<a href="46-block-dev.html">Block_Dev</a> like everything else, so the same
sources run over SPI NOR flash, an SD card, or a file-backed device in the test
harness.</p>

<p class="warn">Host-verified only. The development harness makes three
independent implementations agree about every volume &mdash; this code, the
host's <code>dosfstools</code>, and a FAT16 writer written from the
specification rather than from this source &mdash; but the on-device path wants
checking on your own hardware.</p>
"""),

dict(
slug="49-console-fonts",
nav="Console, text &amp; fonts",
title="Console output, text and fonts",
lede="There is no <code>Ada.Text_IO</code> console on this target, so printing "
     "a number is a design decision &mdash; and drawing a glyph is a separate "
     "one that knows nothing about your panel.",
body="""
<h2>Printing without a hosted runtime</h2>

<p><code>ESP32S3.Log</code> is the formatted-output path the examples use. It
routes through the ROM <code>printf</code> via fixed-signature C wrappers linked
into every example, so you format <em>in Ada</em> rather than hand-writing a
<code>glue.c</code> helper per message:</p>

<pre><code>procedure Put       (S : String);
procedure Put       (C : Character);
procedure Put_Line  (S : String := "");
procedure New_Line;
procedure Put       (N : Integer; Width : Natural := 0; Pad : Character := ' ');
procedure Put_Unsigned (N : Interfaces.Unsigned_32);
procedure Put_Hex   (N : Interfaces.Unsigned_32; Width : Natural := 0);
procedure Put_Fixed (...);</code></pre>

<p class="note">Strings are passed to C NUL-terminated, built in a small
<em>stack</em> buffer &mdash; no secondary stack, no heap. That is what keeps this
usable from the lean profiles where <code>Ada.Text_IO</code> is unavailable, and
why it is safe to call from places a heap allocation would not be. Each call is
one short <code>esp_rom_printf</code>.</p>

<p>Remember the type rule this implies, which
<a href="14-i2c.html">the bus-scan sample</a> ran into:
<code>Put_Hex</code> takes an <code>Interfaces.Unsigned_32</code>, so an
<code>Integer</code>-family value needs an explicit conversion.</p>

<h2>Fonts, separated from panels</h2>

<p><code>ESP32S3.Fonts</code> is a panel-independent data model for proportional
bitmap fonts. A <code>Font</code> is a light descriptor that <em>points</em> at
flat glyph-atlas arrays generated offline by
<code>libs/esp32s3_hal/tools/gen_font.py</code>: per-glyph metrics (advance,
size, bearings, byte offset) plus packed coverage.</p>

<p class="note"><strong>This package has no display dependency at all.</strong>
It models glyph data and reads it through accessors; the rasterising and blitting
live in the generic <code>ESP32S3.Fonts.Render</code>, instantiated per panel
&mdash; <code>ESP32S3.ST7789.Fonts</code> being the worked case. So an atlas and
its <code>Font</code> values are reusable across panels unchanged, and adding a
new display type does not mean regenerating fonts.</p>

<p>Two coverage encodings are supported, which is how the same model serves both
crisp 1-bit glyphs and anti-aliased ones. The atlas being generated
<em>offline</em> is the important structural choice: no font parsing, no
rasteriser and no heap on the device &mdash; just indexed lookups into a constant
array.</p>
"""),

dict(
slug="50-esp-loader",
nav="Programming another ESP32",
title="Esp_Loader: your board as the programmer",
lede="The ESP32 serial ROM protocol spoken as the <em>host</em>, so a jig or a "
     "product can flash another ESP32 &mdash; and none of them can run Python.",
body="""
<h2>The device-side twin of esptool</h2>

<p>This is the same protocol the SDK's own <code>espflash</code> host tool speaks
from a PC (<a href="07-build.html">step 7</a>), implemented so that <em>the board
itself</em> is the programmer. A production jig, a field programmer, or a product
that reflashes its own daughterboard all need exactly this, and none of them can
run Python.</p>

<p>Every exchange is a SLIP frame (<code>0xC0</code> delimited,
<code>0xDB</code> escaped) carrying a command and payload; the target answers
with the same opcode and a status pair.</p>

<p class="note">Only the ROM loader is spoken &mdash; no downloadable stub &mdash;
so there is no compression and no stub-only command. That costs transfer time and
nothing else: raise the rate with <code>Set_Baud</code> and a megabyte moves in a
few seconds.</p>

<h2>Streaming, so a megabyte costs a kilobyte</h2>

<p><code>Begin_Image</code> declares the length, <code>Write</code> takes whatever
chunks the source produces, and full 1&nbsp;KB blocks go out as they fill.
Flashing a megabyte therefore costs a kilobyte of RAM &mdash; and a truncated
source is an <em>error</em> rather than a corrupt target, because the declared
length is checked against what arrived.</p>

<h2>Knowing what you are talking to</h2>

<p class="warn"><strong>The ROM protocol is not uniform across the family, and
guessing wrong corrupts flash rather than failing cleanly.</strong> The original
ESP32 ends every reply with four status bytes instead of two; the ESP32 and
ESP8266 take a shorter <code>FLASH_BEGIN</code> payload; the ESP8266 has no
<code>SPI_ATTACH</code> at all, plus a bug in how it sizes an erase.</p>

<p>So <code>Connect</code> identifies the target first &mdash; via
<code>GET_SECURITY_INFO</code> where the chip supports it (S3 and later), and the
magic register otherwise. A chip newer than the table still connects, as
<code>Unknown</code>, driven with the modern defaults.</p>

<h2>Pass-through: the auto-reset circuit in software</h2>

<p><code>Esp_Loader.Auto_Reset</code> is the circuit every ESP dev board has,
implemented in software. When a board sits between a PC and a target as a
USB-serial bridge, esptool on the PC expects to reach the target's ROM loader by
wiggling DTR and RTS &mdash; this makes that work.</p>

<p class="note">It reproduces the real circuit's <strong>cross-coupling</strong>,
so a terminal emulator asserting both lines on open does not reset the target,
and it emulates the capacitor so esptool's <code>ClassicReset</code> (which moves
the lines one at a time) works regardless of what the target board has on its EN
pin. Those two details are the difference between "usually works" and "works".</p>

<p><code>Serial_Link</code> is the ready-made transport over a UART and two
GPIOs, and <a href="27-crypto.html">MD5</a> is here for
<code>SPI_FLASH_MD5</code>: the target hashes what its flash actually holds and
you compare, so "programmed OK" means something.</p>

<p class="warn">Host-verified only, against a simulated ROM that validates every
frame and impersonates each chip family in turn (with the per-chip handling
deliberately broken three ways to prove the checks bite). The real ROM's timing
still wants a target board on a real UART.</p>
"""),

dict(
slug="51-simd",
nav="SIMD (PIE)",
title="SIMD: the PIE vector unit",
lede="128-bit vector kernels with the inner loops written as GNAT inline "
     "assembly &mdash; vendored, experimental, and honest about it.",
body="""
<h2>What it is</h2>

<p><code>ESP32S3.SIMD</code> exposes the S3's <strong>PIE</strong> SIMD extension
&mdash; the Xtensa LX7's 128-bit <code>q0</code>&ndash;<code>q7</code> registers
&mdash; with the inner loops written as GNAT inline assembly
(<code>System.Machine_Code</code>) inside Ada bodies.</p>

<p>Application code <code>with</code>s the facade; the per-type kernels live in
children by element family:</p>

<table>
  <thead><tr><th>Child</th><th>Element type</th></tr></thead>
  <tbody>
    <tr><td><code>ESP32S3.SIMD.I8</code></td><td><code>Integer_8</code></td></tr>
    <tr><td><code>ESP32S3.SIMD.I16</code></td><td><code>Integer_16</code></td></tr>
    <tr><td><code>ESP32S3.SIMD.I32</code></td><td><code>Integer_32</code></td></tr>
    <tr><td><code>ESP32S3.SIMD.F32</code></td><td><code>IEEE_Float_32</code></td></tr>
  </tbody>
</table>

<pre><code>procedure Add   (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector);
procedure Sub   (A, B : SIMD_F32_Vector; Result : in out SIMD_F32_Vector);
procedure Mul_Scalar (...);
procedure MAC   (...);
function  Sum         (A : SIMD_F32_Vector) return IEEE_Float_32;
function  Dot_Product (A, B : SIMD_F32_Vector) return IEEE_Float_32;
procedure Ceil  (A : SIMD_F32_Vector; Result : in out SIMD_F32_Vector; Max_Val : IEEE_Float_32);
procedure Floor (...);
procedure Neg / Abs_Val (...);</code></pre>

<p>Contracts on these are intentionally explicit &mdash; the preconditions state
the length and aliasing rules rather than leaving them to a comment.</p>

<h2>Read this before you depend on it</h2>

<p class="warn"><strong>Status: experimental / beta.</strong> Correctness is
validated for a <em>subset</em> of operations through the benchmark harness; edge
cases and operation interactions are not systematically exercised. The library's
own README says not to rely on it in safety-critical contexts without independent
verification, and repeating that here rather than quietly omitting it is the
point.</p>

<p class="note"><strong>Provenance:</strong> vendored from
<code>rowsail/ada-esp32-s3-simd</code>, itself based on the low-level
implementation ideas of the upstream <code>zliu43/esp_simd</code> project. It is
not original work of this SDK, and the vendoring is recorded rather than
blurred.</p>

<h2>Enabling the coprocessor</h2>

<p>PIE is coprocessor 3. The bare boot's <code>start.S</code> sets
<code>CPENABLE = 0x09</code> to enable it &mdash; so unlike most of the HAL, this
library depends on a startup detail rather than only on its own registers. If you
port the boot code, that bit has to come with it or every kernel faults.</p>
"""),

dict(
slug="52-stack-usage",
nav="Stack measurement",
title="Stack usage: measuring what analysis cannot see",
lede="Static worst-case analysis cannot see the prebuilt runtime, the C "
     "startup, ISRs or hand-written assembly. Painting the stack can.",
body="""
<h2>How it works</h2>

<p>Fill the unused part of a stack with a sentinel word, run the workload, then
scan for the lowest word the program actually overwrote. The gap between that and
the top is the peak depth ever reached.</p>

<p>This is the <strong>measured</strong> counterpart to the static
<code>x stack</code> worst-case analysis &mdash; and it is the only way to
account for the parts static analysis structurally cannot see: the prebuilt
runtime, the C startup, interrupt service routines, and hand-written
assembly.</p>

<h2>The direction of the error</h2>

<p class="note">A sentinel-valued word that the program legitimately wrote looks
pristine, so the scan stops at the <strong>first</strong> overwritten word from
the bottom. That means it can only ever be <em>conservative</em>: it never
under-reports the peak. Read the figure as "at least this much was used", never
as an exact high-water mark.</p>

<p class="warn">The measurement is only as good as the workload. A run that never
takes the deep path reports a comfortable number that means nothing about the
path you did not exercise &mdash; so drive a <em>real</em> workload, including
the error paths and the interrupt load, before believing the headroom.</p>

<h2>Why both approaches</h2>

<p>Use the static analysis to find the theoretical worst case in code it can see,
and this to catch what it cannot. Agreement between them is meaningful evidence;
a measured figure that exceeds the static bound means the static model is missing
a path, which is worth knowing before it is a
<a href="55-debugging.html">stack overflow on hardware</a>.</p>

<p class="note">The runtime already guards the running task with a hardware
watchpoint a redzone above its stack limit, re-armed on every context switch
(<a href="55-debugging.html">step 44</a>). That catches an overflow precisely when
it happens; this tells you how close you were before it did.</p>
"""),

dict(
slug="53-testing",
nav="Testing &amp; proof",
title="Testing and proof: reproducing the claims",
lede="Thirty-two harnesses run on your PC, not the board. Half check "
     "behaviour against the host's own tools; half prove absence of run-time "
     "errors outright.",
body="""
<h2>Why so much runs on the host</h2>

<p>Most of what this SDK does is pure logic over a thin hardware seam &mdash; a
filesystem over <a href="46-block-dev.html">Block_Dev</a>, a DNS message
builder over <a href="40-net-stack.html">GNAT.Sockets</a>, a clock-divider
calculation. Logic like that is target-independent, so it can be exercised on a
PC in a second rather than flashed and watched over a serial cable.</p>

<p class="note">That split is deliberate and it tells you where a bug lives. The
<code>ext4_host</code> harness builds the <em>same</em> filesystem sources the
firmware uses &mdash; its project's <code>Source_Files</code> whitelist pulls in
every portable unit and omits only the on-target block adapters. So a bug that
reproduces on the host is a real filesystem bug, and one that appears
<em>only</em> on target points at the SD/SPI layer instead.</p>

<h2>Running a host test</h2>

<p>Each harness under <code>libs/esp32s3_hal/test/</code> carries its own
<code>run.sh</code>, which finds the Alire native toolchain itself:</p>

<pre><code>bash libs/esp32s3_hal/test/endian_host/run.sh
bash libs/esp32s3_hal/test/ext4_host/run.sh</code></pre>

<p>The first is instant and self-contained:</p>

<pre><code>ESP32S3.Endian equivalence check:
  little-endian join/split . PASS ( 4096 cases)
  big-endian 32 join/split . PASS ( 4096 cases)
  big-endian 16 join/split . PASS ( 65536 cases)</code></pre>

<p>The second needs <code>e2fsprogs</code>, because it does something better than
checking its own answers &mdash; it cross-checks every volume against the Linux
kernel's own <code>e2fsck</code>:</p>

<pre><code>  dirgrow        e2fsck CLEAN
      dirgrow: 400 files + 101 replaced, missing 0
  stream         e2fsck CLEAN
      stream: 205500 bytes via Append, readback OK</code></pre>

<p>The same pattern recurs: <code>fat16_host</code> makes three independent
implementations agree (this code, <code>dosfstools</code>, and a writer written
from the specification), <code>modbus_*_host</code> talk to a standard client,
and <code>esp_loader_host</code> drives a simulated ROM that validates every
frame and impersonates each chip family in turn.</p>

<table>
  <thead><tr><th>Harness</th><th>Checked against</th></tr></thead>
  <tbody>
    <tr><td><code>ext4_host</code>, <code>mkfs_host</code>, <code>wl_host</code></td><td><code>mke2fs</code> / <code>debugfs</code> / <code>e2fsck</code></td></tr>
    <tr><td><code>fat16_host</code></td><td><code>dosfstools</code>, plus a spec-derived writer</td></tr>
    <tr><td><code>dns_host</code>, <code>ftp_host</code>, <code>modbus_*_host</code></td><td>Real servers and clients on the host</td></tr>
    <tr><td><code>esp_loader_host</code></td><td>A simulated ROM, deliberately broken three ways</td></tr>
    <tr><td><code>repclause_host</code>, <code>endian_host</code></td><td>An arithmetic reference &mdash; bit layouts and byte order</td></tr>
  </tbody>
</table>

<h2>Proof, not just testing</h2>

<p>A test shows the cases you thought of pass. SPARK proves a property holds for
<em>every</em> input. The proof projects run at
<code>--level=1</code> &mdash; "silver": no overflow, no array index out of
range, no division by zero, and all loops terminate.</p>

<pre><code>cd libs/esp32s3_hal/test/ledc_math_prove
gnatprove -P ledc_math_prove.gpr --level=1 --report=statistics</code></pre>

<p>Which reports, per check, what was proved and by which solver:</p>

<pre><code>esp32s3-ledc-math.adb:27:18: info: division check proved (Z3)
esp32s3-ledc-math.ads:17:13: info: implicit aspect Always_Terminates on
                                   "Clock_Divider" has been proved
esp32s3-ledc-math.ads:19:19: info: postcondition proved (Z3)
esp32s3-ledc-math.ads:26:19: info: postcondition proved (altergo)</code></pre>

<p class="note">Note the last two: these are not only absence of run-time errors
but <strong>postconditions</strong> &mdash; the divider really does produce a
frequency within tolerance, for every input, not merely for the values someone
tried.</p>

<h2>How a unit joins the proof surface</h2>

<p>A unit is proven by carrying <code>with SPARK_Mode =&gt; On</code> on its spec
and body; I/O, access types and raising operations at the boundary get
<code>SPARK_Mode =&gt; Off</code>, and GNATprove analyses the On subset
automatically.</p>

<p>That is why the proven parts are the shapes they are &mdash; parsers,
serialisers, checksums, routing and date arithmetic, clock-divider maths. The
<code>*_math</code> children exist precisely so the arithmetic can be separated
from the register writes and proven on its own: <code>LEDC.Math</code>,
<code>MCPWM.Math</code>, <code>RMT.Math</code>, <code>TWAI.Math</code>,
<code>Ext4.Mkfs.Math</code>. The driver body that writes registers stays
unmarked.</p>

<p class="warn">Proof at silver level says the code cannot fail at run time and
meets its stated contracts. It does <strong>not</strong> say the contract is the
one you wanted, nor that the hardware behaves as the datasheet claims. It
complements the hardware self-tests in the examples; it does not replace
them.</p>

<p><code>book/prove/prove.sh</code> runs the proof across every unit marked for
it, if you want the whole surface rather than one project.</p>
"""),

dict(
slug="54-runtime",
nav="The runtime itself",
title="The runtime: how it is built, ported and proven conformant",
lede="Three profiles generated from a forked bb-runtimes board, a porting "
     "checklist that is shorter than you would expect &mdash; and an ACATS "
     "sweep that grades the result one test per image.",
body="""
<h2>Where the runtime comes from</h2>

<p><a href="08-profiles.html">Step 8</a> covered <em>choosing</em> a profile.
This is where they come from. The runtime is not vendored as a binary: it is
<strong>generated</strong> from a fork of AdaCore's <code>bb-runtimes</code>
carrying a new <code>esp32s3</code> board, and built on demand by
<code>gen_runtime.sh</code> as the crate's Alire pre-build action.</p>

<pre><code>ESP32S3_RTS_PROFILE=embedded   # light-tasking | embedded | full
#  -> crates/esp32s3_rts/embedded-esp32s3/  (adainclude + adalib)</code></pre>

<p>Two things it needs, both supplied for you:
<code>XTENSA_GNU_CONFIG</code>, set by the <code>xtensa_dynconfig</code>
dependency, which selects the ESP32-S3 core configuration (little-endian, 64
address registers, FPU); and the cross toolchain plus <code>gprbuild</code> on
<code>PATH</code>. It is idempotent &mdash; it regenerates only when the output
is missing.</p>

<p class="note">The crate is <strong>not published</strong>. You consume it via
an Alire <em>pin</em>, which is why every example's <code>alire.toml</code>
carries a <code>[[pins]]</code> entry pointing at
<code>crates/esp32s3_rts</code>, and why an out-of-tree project resolves it
through <code>GPR_PROJECT_PATH</code> instead
(<a href="10-own-project.html">step 10</a>).</p>

<h2>The trap that will bite you</h2>

<p class="warn"><strong>Editing a runtime source does not rebuild
anything.</strong> The heavy compile-and-archive step runs only when the output
is missing, so changing a file under <code>bb-runtimes/</code> or
<code>full_overlay/</code> leaves the previous archive in place &mdash; the next
build links the old one and <em>your change silently does nothing</em>. The
book records that this has caught the authors more than once.</p>

<p>Delete the archives to force the rebuild:</p>

<pre><code>rm crates/esp32s3_rts/&lt;profile&gt;-esp32s3/adalib/libgnat.a \
   crates/esp32s3_rts/&lt;profile&gt;-esp32s3/adalib/libgnarl.a</code></pre>

<p>Or remove the generated tree entirely, as
<a href="07-build.html">step 7</a>'s tips suggest.</p>

<h2>Three profiles, three <code>system.ads</code></h2>

<p>The profiles differ by restriction set, expressed as different
<code>system-xi-xtensa-*.ads</code> variants:
<code>light-tasking</code> adds <code>No_Exception_Propagation</code> and
<code>No_Finalization</code>; <code>embedded</code> lifts both (ZCX);
<code>full</code> is the unrestricted GNARL, built from an <em>overlay plus
patches</em> on top of the same board.</p>

<p>The register packages are separate again: <code>ESP32S3_Registers.*</code> is
generated from the chip's SVD by svd2ada, not hand-written &mdash; which is why
<a href="13-gpio.html">the drivers</a> get typed record fields with
representation clauses instead of shift-and-mask.</p>

<h2>Porting to another Xtensa SoC</h2>

<p>The structure makes the checklist short:</p>

<ol>
  <li>Add a board class under <code>bb-runtimes/xtensa/</code> &mdash; target
      triple, clock, interrupt range, SMP flag.</li>
  <li>Supply the five <code>__&lt;board&gt;</code> bodies: parameters, board
      support, console, reset, interrupt names.</li>
  <li>Write the two <code>system-xi-xtensa-*.ads</code> variants, or reuse these
      if the restriction set is the same.</li>
  <li>Regenerate the register packages from that chip's SVD.</li>
  <li>Point <code>gen_runtime.sh</code> at the new board name.</li>
</ol>

<p class="note">What that list deliberately excludes is the boot path &mdash; the
2nd-stage loader, clock and cache bring-up, PSRAM
(<a href="06-anatomy.html">step 6</a>). Those are chip-specific and are the
larger job; the <em>runtime</em> port is the small half.</p>

<h2>ACATS: conformance, not confidence</h2>

<p>A hand-written runtime either implements Ada or approximates it, and the
difference is not something a test suite of your own devising can settle. So the
runtime is run against the <strong>official ACATS 4.2</strong> suite on real
hardware.</p>

<table>
  <thead><tr><th>Profile</th><th>Test list</th><th>PASS</th><th>Genuine failures</th></tr></thead>
  <tbody>
    <tr><td><code>light-tasking</code></td><td><code>jorvik_hw_runnable</code> (846)</td><td>~700</td><td><strong>0</strong></td></tr>
    <tr><td><code>embedded</code></td><td><code>jorvik_hw_runnable</code> (846)</td><td>840+</td><td><strong>0</strong></td></tr>
    <tr><td><code>full</code></td><td><code>full_applicable</code> (1,518)</td><td>1,286+</td><td><strong>0</strong></td></tr>
  </tbody>
</table>

<p class="warn">"Zero genuine failures" needs its qualifier stated, not buried:
every non-passing test is an <em>interactive</em> test needing a bench-generated
stimulus, a build-drop (a library unit the bare runtime omits), a correct
<code>NOT-APPLICABLE</code>, or a documented limitation. That is a different
claim from "everything passes", and the honest version is the useful one.</p>

<h2>How the sweep works</h2>

<p>The interesting engineering is the harness. Each test becomes
<strong>one image containing exactly one test</strong>, built in parallel, then
flashed and graded across a pool of boards. Two details make it work:</p>

<ul>
  <li>The grade has to come <em>off the chip</em>. ACATS'
      <code>Report</code> package prints <code>PASSED</code>/<code>FAILED</code>,
      and <code>ACATS/target/report.adb</code> routes each grade line through the
      USB-Serial-JTAG console so the runner can read it.</li>
  <li><strong>The grader must not trust the test id</strong> printed in the
      output &mdash; the suffix letter breaks an exact-id match. Because each
      image contains exactly one test, the runner knows which test it flashed
      and grades on that instead.</li>
</ul>

<p class="note">The ACATS suite and its sweep harness
(<code>acats_build.py</code>, <code>acats_run.py</code>, the
<code>ACATS/</code> tree) are <strong>not shipped in this distribution</strong>
&mdash; they live in the development repository. The book's ACATS chapter has the
full breakdown if you want the detail.</p>
"""),

dict(
slug="55-debugging",
nav="Debugging",
title="Debugging: GDB over the same cable",
lede="The USB-Serial-JTAG port is both the console and a JTAG debug interface, "
     "so one cable gets you breakpoints, both cores as GDB threads, and a live "
     "halt on a hung board.",
body="""
<h2>Fetch the tools, once</h2>

<pre><code>./x get-debug-tools      # pinned, SHA-256-verified OpenOCD + xtensa-esp32s3-elf-gdb
./x debug gpio0_blink    # build, flash, start OpenOCD, attach GDB, rest at Main</code></pre>

<p>Both are debug-only downloads; build, flash and run need neither.</p>

<p class="warn">The S3 needs the <strong>S3-specific</strong>
<code>xtensa-esp32s3-elf-gdb</code>. The Alire crate's esp32 (LX6) GDB silently
fails on it &mdash; hardware-confirmed. <code>./x debug</code> selects the right
one for you, which is the main reason to go through it rather than invoking GDB
by hand.</p>

<h2>Two options that matter on this target</h2>

<ul>
  <li><strong><code>--smp</code></strong> exposes <em>both</em> LX7 cores as GDB
      threads, so <code>info threads</code> shows what each core is doing.
      Essential for a cross-core hang.</li>
  <li><strong><code>--attach</code></strong> halts the board <em>in place</em>
      without resetting it, so you can examine a live hang or crash exactly
      where it stopped.</li>
</ul>

<p>From there it is ordinary GDB on <code>app.elf</code>: breakpoints,
<code>step</code>, <code>print</code>, <code>backtrace</code>. When you are done,
<code>./x kill-openocd</code> releases the USB-JTAG port &mdash; a captured port
is the usual reason the next flash fails.</p>

<h2>In the editor</h2>

<p>The split is deliberate and worth understanding: <strong>the Ada Language
Server provides language features</strong> (completion, diagnostics,
go-to-definition, hover) by reading a project's <code>.gpr</code> file, and
<strong><code>./x</code> provides the actions</strong>. Any editor with an LSP
client gets the first for free; the editor integration only has to wrap the
second.</p>

<ul>
  <li><strong>VS Code</strong> &mdash; install the AdaCore <em>Ada &amp;
      SPARK</em> extension for ALS, and <em>Native Debug</em>
      (<code>webfreak.debug</code>) for debugging (cppdbg cannot walk the Xtensa
      stack). The committed <code>.vscode/tasks.json</code> gives you
      <code>Ada: build</code> (with a GNAT problem matcher), <code>flash</code>,
      <code>monitor</code>, <code>run</code> and <code>clean</code>;
      <code>launch.json</code> gives <code>Ada: debug (OpenOCD + GDB)</code>.
      <kbd>Ctrl-Shift-B</kbd> builds, <kbd>F5</kbd> debugs.</li>
  <li><strong>Vim / Neovim</strong> &mdash; the repository ships a plugin, and
      one command installs it by symlinking it into Vim's and Neovim's native
      package directory (so <code>git pull</code> updates it in place):
      <pre><code>./x install-vim          # or, from a standalone project:  esp32-ada install-vim</code></pre>
      Restart Vim and you get <code>:AdaEsp32New</code>,
      <code>:AdaEsp32Build</code>, <code>:AdaEsp32Flash</code> and friends; they
      auto-detect whether you are inside the repo (<code>./x</code>) or a
      standalone project (<code>app.gpr</code> + <code>build.sh</code>) by
      searching upward. Prefer to wire it yourself:
      <pre><code>" vim-plug
Plug '/path/to/ada_esp32s3/ide/vim-ada-esp32'
" or, with no plugin manager:
set runtimepath^=/path/to/ada_esp32s3/ide/vim-ada-esp32</code></pre>
      For language features, point your LSP client at the
      <code>ada_language_server</code> binary that ships inside the AdaCore
      toolchain &mdash; with <code>nvim-lspconfig</code> that is
      <code>require('lspconfig').als.setup{}</code>, having launched Neovim from
      a shell that sourced <code>export.sh</code> so
      <code>GPR_PROJECT_PATH</code> resolves the runtime and HAL projects.</li>
</ul>

<h2>Post-mortem: decoding a Guru Meditation</h2>

<p>An unhandled fault prints a register dump and a backtrace of
program-counter values over the console. You do not need a live debugger to read
it &mdash; turn the addresses back into source:</p>

<pre><code>xtensa-esp32s3-elf-addr2line -fe build/app.elf 0x4200abcd 0x4200ef01</code></pre>

<p>In the dump, <strong><code>EXCVADDR</code></strong> is the faulting data
address and <strong><code>EXCCAUSE</code></strong> the reason: a
<code>LoadStoreError</code> is a bad data access; an
<code>InstructionFetchError</code> is a wild jump, usually a corrupted stack or a
stray pointer. Flash, reproduce, decode &mdash; that loop localises most faults
without attaching anything.</p>

<h2>What the runtime catches for you</h2>

<p>Before you reach for a tool at all: every profile guards the <em>running</em>
task with a hardware watchpoint a redzone above its stack limit, and the context
switch re-arms it for the incoming thread on every switch. An overflowing write
therefore faults <em>precisely</em>, at the instruction that did it, instead of
silently corrupting a neighbouring task's stack and failing somewhere
unrelated.</p>
"""),

# ---------------------------------------------------------------- 13
dict(
slug="56-troubleshooting",
nav="Troubleshooting &amp; next steps",
title="Troubleshooting, and where to go next",
lede="The failure modes worth recognising on sight, a one-screen cheat sheet, "
     "and the parts of the project to read once the board is blinking.",
body="""
<h2>Troubleshooting</h2>

<table>
  <thead><tr><th>Symptom</th><th>Cause and fix</th></tr></thead>
  <tbody>
    <tr><td><code>gprbuild</code> or the cross-GNAT not found</td>
        <td>A toolchain is missing, or <code>PATH</code> lost Alire. Recheck
            <a href="02-toolchain.html">step 2</a> and <code>alr toolchain</code>.</td></tr>
    <tr><td><code>XTENSA_GNU_CONFIG unset</code>, or a missing <code>bb-runtimes</code></td>
        <td>Submodules were never fetched:
            <code>git submodule update --init --recursive</code>.</td></tr>
    <tr><td><code>Permission denied</code> on <code>/dev/ttyACM0</code></td>
        <td>Add yourself to <code>dialout</code>, then <em>log out and back
            in</em>.</td></tr>
    <tr><td>No <code>/dev/ttyACM0</code> appears at all</td>
        <td>Wrong socket (use the native <strong>USB</strong> port, not
            <strong>UART</strong>), or a charge-only cable. Check
            <code>dmesg | tail</code>.</td></tr>
    <tr><td>The flasher never connects</td>
        <td>Force download mode: hold <strong>BOOT</strong>, tap
            <strong>RESET</strong>, release <strong>BOOT</strong>. Also check no
            OpenOCD still holds the port &mdash;
            <code>./x kill-openocd</code>.</td></tr>
    <tr><td>The board resets or panics in a loop</td>
        <td>The bare boot runs with memory protection (W^X) off, which the Ada
            task-body trampolines require. Every example ships
            <code>CONFIG_ESP_SYSTEM_MEMPROT_FEATURE=n</code>; rebuild clean.</td></tr>
    <tr><td>The first build takes forever</td>
        <td>Expected. It generates the Ada runtime and builds the host tools.
            Later builds are incremental.</td></tr>
    <tr><td>Console shows nothing, or garbage</td>
        <td>115200 8N1 on the native USB port; confirm which
            <code>/dev/ttyACM*</code> is the board.</td></tr>
    <tr><td>A build error you cannot parse</td>
        <td>Bare-metal GNAT complains about constructs the runtime omits; the
            book's Debugging chapter has a section decoding those
            messages.</td></tr>
  </tbody>
</table>

<h2>One-screen cheat sheet</h2>

<pre><code># --- one-time setup (no ESP-IDF, no esptool, no Python) ---
wget .../alr-2.1.0-bin-x86_64-linux.zip &amp;&amp; unzip -d ~/alire alr-*.zip
export PATH="$HOME/alire/bin:$PATH"
alr toolchain --select gnat_native gprbuild
alr toolchain --select gnat_xtensa_esp32_elf
git clone --recurse-submodules https://github.com/rowsail/ada_esp32s3.git
cd ada_esp32s3
sudo usermod -aG dialout $USER          # then log out/in

# --- build, flash, watch an example ---
./x list
./x run gpio0_blink -p /dev/ttyACM0

# --- or start your own app in any folder ---
. ~/ada_esp32s3/export.sh    # ESP32S3_ADA_SDK + esp32-ada on PATH
mkdir ~/myblink &amp;&amp; cd ~/myblink &amp;&amp; esp32-ada init
esp32-ada run -p /dev/ttyACM0           # build + flash + monitor</code></pre>

<h2>Where to go next</h2>

<ul>
  <li><strong>Read an example.</strong> They are written to be read, not just
      run. <code>esp32s3_gpio0_blink</code> and <code>esp32s3_gdma_copy</code>
      are the house-style models; <code>examples/STYLE.md</code> records the
      bar.</li>
  <li><strong>Run the self-test for a peripheral you care about</strong> before
      writing code against it. Most need no wiring.</li>
  <li><strong>The book</strong> (<code>book/main.pdf</code>, LaTeX sources
      alongside it) is the long-form design write-up: the kernel and context
      switch, the interrupt model, the HAL's design rules, the filesystems, the
      ACATS conformance work, and the full-profile limitations.</li>
  <li><strong><code>TOOLING.md</code></strong> for editor integration in
      depth, including the JSON discovery interface if you want to write a
      plugin.</li>
</ul>

<p>You now have a bare-metal Ada program running on both cores of an ESP32-S3,
built and flashed by a toolchain you could describe in one sentence. That was
the point.</p>
"""),
]

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
  .toc {
    position: static;
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

  <nav class="toc" aria-label="Guide contents">
    <a class="home" href="index.html">&larr; Guide home</a>
    <h2>The steps</h2>
    <ol>
{toc}
    </ol>
  </nav>

  <main>
{content}
  </main>

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

    root = os.path.dirname(os.path.dirname(HERE))
    try:
        out = subprocess.run([os.path.join(root, "x"), "list", "--json"],
                             capture_output=True, text=True, cwd=root, timeout=120)
        rows = json.loads(out.stdout)
    except Exception as exc:                      # noqa: BLE001 - report and stop
        raise SystemExit("cannot read ./x list --json (%s) -- run build.py from a"
                         " checkout with the dispatcher present" % exc)

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
                for noise in (
                        " on the bare-metal ESP32-S3 (no FreeRTOS, no IDF)",
                        " on the bare-metal ESP32-S3 (no FreeRTOS, IDF)",
                        " -- bare-metal ESP32-S3 (no FreeRTOS, no IDF)",
                        " (bare-metal ESP32-S3)", " -- bare-metal ESP32-S3",
                        " on the bare-metal ESP32-S3",
                        " (ESP32-S3, no FreeRTOS, no IDF)",
                        " for the bare-metal ESP32-S3"):
                    text = text.replace(noise, "")
                text = re.sub(r"\s*\(no FreeRTOS[^)]*\)?$", "", text)
                text = re.sub(r"\s+", " ", text).strip(" ,;:-")
                return text.rstrip(".")

        #  Some examples open straight into `with` clauses with no header
        #  comment.  Fall back to the README's title, whose shape is
        #  "# esp32s3_name -- what it is".
        readme = os.path.join(root, d, "README.md")
        if os.path.exists(readme):
            with open(readme, errors="ignore") as fh:
                head = fh.readline().lstrip("# ").strip()
            for dash in ("\u2014", "\u2013", " -- "):
                if dash in head:
                    return head.split(dash, 1)[1].strip().rstrip(".")
            #  No dash: the whole title is the description.
            if head and not head.lower().startswith("esp32s3_"):
                return head.rstrip(".")
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
        with open(os.path.join(HERE, p["slug"] + ".html"), "w") as f:
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
    with open(os.path.join(HERE, "index.html"), "w") as f:
        f.write(index_html)

    with open(os.path.join(HERE, "style.css"), "w") as f:
        f.write(CSS)

    #  Drop generated pages left behind by an earlier run (a renamed or removed
    #  slug), so the directory only ever holds the current set.
    keep = {p["slug"] + ".html" for p in PAGES} | {"index.html"}
    stale = [f for f in os.listdir(HERE) if f.endswith(".html") and f not in keep]
    for f in stale:
        os.remove(os.path.join(HERE, f))
        print("removed stale page %s" % f)

    print("wrote index.html, style.css, and %d step pages in %s" % (n, HERE))


if __name__ == "__main__":
    build()
