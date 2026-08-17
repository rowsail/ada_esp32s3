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

<p>The next four steps take the four you will reach for first and go through
them properly: <a href="12-gpio.html">GPIO</a> &mdash; the pin type, what is
atomic in silicon, and pin interrupts; <a href="13-i2c.html">I2C</a> &mdash;
session ownership, repeated START, and unbounded transfers;
<a href="14-spi.html">SPI</a> &mdash; per-device clock and mode on a shared host,
chip select three ways, and the DMA preconditions; and
<a href="15-uart.html">UART</a> &mdash; why it has no setup call, interrupt-driven
RX, and a pin-routing trap.</p>

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
slug="12-gpio",
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

<p class="note"><strong>Why the predicate is <code>Static_</code>.</strong>
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
slug="13-i2c",
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
<a href="12-gpio.html">GPIO page</a>.</p>

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
slug="14-spi",
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
<a href="13-i2c.html">I2C</a>'s: it releases the host on scope exit including
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
Same reason as the <a href="12-gpio.html">GPIO interrupt callback</a>: the HAL
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
slug="15-uart",
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

<p><a href="13-i2c.html">I2C</a> and <a href="14-spi.html">SPI</a> both have a
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

<p>Unlike <a href="13-i2c.html">I2C</a>, where an internal loopback is
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
slug="16-debugging",
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
slug="17-troubleshooting",
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
  font-weight: 650;
  font-size: 1.02rem;
  color: var(--fg);
  text-decoration: none;
  letter-spacing: -0.01em;
}
.masthead-inner a.brand:hover { color: var(--accent); }
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
}
.toc h2 {
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.09em;
  color: var(--fg-faint);
  margin: 0 0 0.7rem;
  font-weight: 650;
}
.toc ol { list-style: none; margin: 0; padding: 0; counter-reset: step; }
.toc li { counter-increment: step; margin: 0; }
.toc a {
  display: block;
  padding: 0.3rem 0.55rem 0.3rem 2.1rem;
  text-indent: -1.55rem;
  color: var(--fg-muted);
  text-decoration: none;
  border-left: 2px solid transparent;
  border-radius: 0 3px 3px 0;
}
.toc a::before {
  content: counter(step, decimal-leading-zero);
  color: var(--fg-faint);
  font-family: var(--mono);
  font-size: 0.78em;
  margin-right: 0.6rem;
}
.toc a:hover { color: var(--fg); background: var(--rule-soft); }
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
    <a class="brand" href="index.html">{site}</a>
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
    <p class="lede">{tagline} Seventeen short steps, one aspect each, from a
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
    library, 12 to 15 go deep on the four peripherals you will reach for first
    &mdash; GPIO, I2C, SPI and UART &mdash; and 16 and 17 are the debugger and
    what to do when something goes wrong.</p>

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
    "12-gpio":            "The pin type that rejects a pad which would hang the chip, what is atomic in silicon, and the interrupt callback rule.",
    "13-i2c":             "An RAII session that cannot leak the bus lock, repeated START, and why payload length never reaches your code.",
    "14-spi":             "Per-device clock and mode on a shared host, chip select three ways, and DMA rules enforced as preconditions.",
    "15-uart":            "No setup call by design, interrupt-driven RX with a buffer Ada makes you declare just so, and a routing trap.",
    "16-debugging":       "OpenOCD and GDB over the same USB cable, editor integration, and decoding a Guru Meditation.",
    "17-troubleshooting": "The failure modes worth recognising on sight, a cheat sheet, and where to read next.",
}


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

    def toc_html(current_slug):
        rows = []
        for p in PAGES:
            cls = ' class="current"' if p["slug"] == current_slug else ""
            aria = ' aria-current="page"' if p["slug"] == current_slug else ""
            rows.append(
                '      <li%s><a href="%s.html"%s>%s</a></li>'
                % (cls, p["slug"], aria, p["nav"])
            )
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
                       lambda m: sample(m.group(1)), p["body"]).rstrip(),
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
