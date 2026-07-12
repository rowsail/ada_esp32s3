# OTA firmware updates — design

**Goal.** A reusable **scaffold** for future ESP32-S3 apps that talk to a
**ThingsBoard** cloud over **MQTT** and support **OTA** (firmware-over-MQTT),
with a safe A/B slot bootloader and automatic rollback. New products start from
this template — connectivity (W5500 Ethernet and/or BG95 cellular), MQTT/TLS to
ThingsBoard, and a working OTA update path — and add their application logic on
top. The OTA *infrastructure* (A/B slots, boot-control, internal-flash
self-programming, image validation) is vendor-neutral SDK code in the public
repo; the **ThingsBoard client + the scaffold app** live in the private repo
alongside the MQTT examples.

The one piece that looked risky — self-programming the internal flash while
executing from it — is **already solved in production**: the PSR_Firmware
project's `settings_flash.c` / `psr_rom.ld` do exactly this cache-safe write
(see §7). The scaffold promotes that proven code into the SDK as the OTA
apply-path rather than inventing it.

This extends [`BOOTLOADER_STAGE0.md`](BOOTLOADER_STAGE0.md), which deliberately
dropped "OTA slot selection · anti-rollback" from the minimal bootloader. This
doc adds them back as a second stage.

---

## 1. How ThingsBoard OTA-over-MQTT works

Everything is plain MQTT publish/subscribe with an id embedded in the topic
string — no ThingsBoard-specific wire format.

1. **Connect** with the device **access token as the MQTT username** (empty
   password), over TLS (port 8883) for production.
2. **Learn the target firmware** — request shared attributes on
   `v1/devices/me/attributes/request/{reqId}` with payload
   `{"sharedKeys":"fw_title,fw_version,fw_size,fw_checksum,fw_checksum_algorithm"}`;
   the reply lands on `v1/devices/me/attributes/response/{reqId}`. Also
   subscribe to `v1/devices/me/attributes/response/+` and to live pushes on
   `v1/devices/me/attributes`.
3. **Decide** — if `fw_version`/`fw_title` differ from what is running, update.
4. **Download in chunks** — subscribe to `v2/fw/response/+/chunk/+`, then for
   each chunk `n` publish the desired chunk size (as a decimal string) to
   `v2/fw/request/{reqId}/chunk/{n}`; the binary chunk arrives on
   `v2/fw/response/{reqId}/chunk/{n}`. Loop until `fw_size` bytes are in.
5. **Verify** the assembled image against `fw_checksum` using
   `fw_checksum_algorithm` (default **SHA-256**; also MD5/SHA-384/SHA-512/CRC32/
   MURMUR3).
6. **Apply + report** — write the image, and publish telemetry to
   `v1/devices/me/telemetry` with `fw_state` transitioning
   `DOWNLOADING → DOWNLOADED → VERIFIED → UPDATING → UPDATED` (or `FAILED` with
   `fw_error`). After the reboot into the new image, report the new
   `current_fw_version`.

---

## 2. What already exists (≈85%)

| Capability | Where | Notes |
|---|---|---|
| MQTT 3.1.1/5, token-as-username, QoS, closure-free callbacks | `libs/mqtt` (private) | `Connect (User_Name => token)`, `Subscribe`, `On_Message`, `Publish`, `Pump` |
| TLS 1.3 for MQTTS | `libs/tls` + `MQTT.Client.Connect_Over` | app owns the session + pinned trust anchor |
| Connectivity | W5500 (public HAL) / BG95 (private) behind `GNAT.Sockets` | scaffold picks one or both; MQTT is transport-agnostic over the facade |
| **Cache-safe internal-flash erase/program/read + other-core parking** | **PSR_Firmware `settings_flash.c` + `psr_rom.ld`** | **production-proven**; the hard part of the apply-path — promote to SDK (§7) |
| Streaming checksums SHA-256/384/512, MD5, CRC32 | `GNAT.SHA256`… (embedded/full RTS) | incremental `Update`/`Digest` — feed as chunks arrive |
| Staging storage (optional) | `ESP32S3.W25Q` (32 MB NOR) and `ESP32S3.Ext4.FS.Append` | raw or streamed ext4 file, if staging before apply |
| A bootloader we fully own | `examples/common/bare/bootloader` | ~3.3 KB ZFP-Ada; loads app from a fixed offset |
| 16 MB internal flash | GD25Q128 on the board | only ~1 MB used; room for two 2 MB slots |

Typical app image is ~400 KB (range 250–830 KB), so slots and transfer times
are small.

### The one MQTT constraint

`MQTT.Max_Packet_Bytes = 1024` caps every inbound PUBLISH body. Two options:

* **Small chunks (Phase 1 default).** Request ≤ ~900 B chunks (leaving room for
  the `v2/fw/response/{id}/chunk/{n}` topic + header). A 400 KB image ≈ 450
  request/response round-trips — fine for a one-off update.
* **Raise the cap.** The types allow up to 64 KiB (`Buffer_Index` is `0 ..
  65535`; the MQTT-5 Maximum-Packet-Size advertisement is a `U16`). Cost: the
  per-session `In_Buf` is inline in `Session` (more RAM), plus re-proving the
  SPARK size bound. Do this only if transfer time matters.

---

## 3. Architecture (layers, bottom-up)

```
  ┌───────────────────────────────────────────────────────────┐
  │  ThingsBoard OTA client  (private: libs/ota or example)    │  app protocol
  │   attribute req/resp · chunk pull · fw_state telemetry     │
  ├───────────────────────────────────────────────────────────┤
  │  OTA core          (public: libs/…/ota)                    │  vendor-neutral
  │   Begin/Write/Verify/Activate · streaming SHA-256          │
  ├──────────────────────────┬────────────────────────────────┤
  │  Internal-flash writer   │  Boot-control block             │  new SDK code
  │  (ROM erase/write,       │  (read/update active·pending·   │
  │   cache-safe, IRAM)      │   try-count·confirmed)          │
  ├──────────────────────────┴────────────────────────────────┤
  │  A/B bootloader     (public: bootloader/boot_main.adb)     │  slot select +
  │   pick slot · validate · rollback · confirm                │  rollback
  └───────────────────────────────────────────────────────────┘
```

The **OTA core** is deliberately transport- and cloud-agnostic: it exposes
`Begin_Update (size, expected_digest, algo)`, `Write (bytes)` (streams to the
inactive slot while updating the running SHA context), `Verify` (finalize +
compare), and `Activate` (set the boot-control pending slot). The ThingsBoard
client only speaks MQTT and feeds bytes in.

---

## 4. Flash layout (16 MB internal)

```
  0x000000  2nd-stage bootloader (our Ada, ~4 KB)
  0x008000  partition table (vendored; bootloader still parses image, not this)
  0x00D000  boot-control A ┐ ping-pong, one 4 KB sector each, crash-safe
  0x00E000  boot-control B ┘
  0x010000  SLOT A  (app)   — 2 MB reserved  → …0x210000
  0x210000  SLOT B  (app)   — 2 MB reserved  → …0x410000
  0x410000  free (~12 MB)   — optional golden/recovery image or scratch
```

The boot-control pair lives in the existing 32 KB gap between the partition
table (0x8000) and slot A (0x10000), so **the current single-slot layout is
unchanged** — slot A stays exactly where it is today. Nothing needs re-flashing
to adopt the scheme except the bootloader itself and writing an initial
boot-control block pointing at slot A.

### One build runs from either slot

The bootloader parses the image header and maps IROM/DROM through the cache MMU
from *the flash offset it is loading from*; IRAM/DRAM segments copy to fixed
SRAM. The virtual addresses (`0x42xxxxxx` / `0x3Cxxxxxx`) are slot-independent,
so **the same `app.bin` boots from A or B** with no dual-linking. The image is
position-independent in flash.

---

## 5. Boot-control block

A small fixed struct, written to whichever of the two ping-pong sectors is
stale, so a power loss mid-update never leaves an unreadable control block. Each
record carries a monotonically increasing sequence number and a CRC32; the
bootloader picks the valid record with the highest sequence.

```
  magic        : u32   -- 0x0TA0B007
  seq          : u32   -- higher = newer (ping-pong selector)
  active       : u8    -- slot currently "good" (0 = A, 1 = B)
  pending      : u8    -- slot to try next (== active if none pending)
  try_count    : u8    -- boot attempts left for `pending` before rollback
  confirmed    : u8    -- app set this after a healthy boot of `pending`
  slot_valid   : u8[2] -- image-present flag per slot
  reserved     : …
  crc32        : u32   -- over everything above
```

**State machine**

* *Idle:* `pending == active`, `confirmed == 1`. Bootloader loads `active`.
* *Update staged:* app wrote slot B, then set `pending = B`, `try_count = N`
  (e.g. 3), `confirmed = 0`, `seq++`. Reboot.
* *Trial boot:* bootloader sees `pending != active`, `confirmed == 0`,
  `try_count > 0` → decrement `try_count`, write back, load `pending`.
* *Confirm:* the new app reaches a health checkpoint (e.g. MQTT reconnected +
  reported `UPDATED`) and sets `active = pending`, `confirmed = 1`, `seq++`.
* *Rollback:* if the new app crashes/hangs before confirming, the next boot sees
  `try_count == 0` and `confirmed == 0` → mark `slot_valid[pending] = 0`, set
  `pending = active`, load the last-good slot. The bad image never sticks.

The rollback depends on *not confirming* — so a boot loop that never reaches the
confirm point is caught by `try_count`, and an image that boots but is unhealthy
is caught by the app's own checkpoint logic.

---

## 6. Bootloader changes (`boot_main.adb`)

Today it hardcodes `App_Offset = 0x10000` and jumps. The change:

1. Read + validate both boot-control sectors (ROM `esp_rom_spiflash_read` — the
   bootloader already links it); pick the live record.
2. Apply the trial/rollback logic above to choose `slot` and (if trialling)
   write back the decremented `try_count`.
3. Set `App_Offset` to that slot's base; the existing segment-load + MMU-map +
   jump path is unchanged.
4. Optional cheap integrity gate before jumping: verify the chosen slot's image
   magic (already done) and, if we store a per-slot CRC in boot-control, a CRC of
   the image — else fall through to the other slot.

Est. ~150 lines added to code we own; no new ROM dependencies for the *read*
side (write is app-side only — see §7).

---

## 7. Internal-flash writer — reuse the Block_Dev stack, add only the backend

**Do not write a bespoke flash writer.** Saving data to flash already exists on
this board: the interpreters/shell persist to `/flash` = ext4 over
`ESP32S3.Block_Dev` (`Read`/`Write`/`Count`/`Erase` vtable) →
`Block_Dev.W25Q_Source` → `ESP32S3.W25Q`. All the sector alignment, streaming,
and (if ever wanted) filesystem logic lives above that vtable and is reusable
unchanged.

So the internal flash becomes **another `Block_Dev` source** —
`ESP32S3.Block_Dev.Int_Flash_Source`, mirroring `W25Q_Source` (a `Source` type,
`Configure`, `Make return Device`). The OTA core writes to a `Block_Dev.Device`
and neither knows nor cares whether the backend is the W25Q or the internal
slot. The **only genuinely new code** is the thin backend behind the vtable:
`Read` = ROM `esp_rom_spiflash_read` (already used by the bootloader);
`Write`/`Erase` = ROM `esp_rom_spiflash_write`/`erase_sector` inside a cache-safe
IRAM window. Everything else is shared with the existing "save to flash" path.

**Why not just stage to the W25Q and boot that (reuse everything, write nothing)?**
Because the ESP32-S3 executes app code XIP from the **internal** MSPI flash only
— it cannot fetch instructions from the SPI2-attached W25Q. Staging the download
to the W25Q/ext4 is fine and free (Phase 1 does exactly that), but to *run* the
new image it must land in an internal slot. That last hop is the irreducible new
bit below; there is no existing analog only because the external W25Q is an
ordinary SPI2 peripheral with no XIP-coherency concern, whereas the flash you
execute from does.

The backend — **already written, in production, in PSR_Firmware.** That project
persists its settings to a reserved internal-flash sector, and to do so it
solved this exact problem. `settings_flash.c` (IRAM-placed, `.iram1.psrflash`)
provides:

* `psr_settings_flash_save (addr, src, len)` — mask interrupts (`rsil 15`),
  **suspend both I- and D-cache** (ROM `rom_Cache_Suspend_ICache/DCache` +
  `Cache_Resume_*`), `esp_rom_spiflash_unlock` → `erase_sector` → `write`,
  restore. Only mask-ROM code runs in the window.
* `psr_settings_flash_read (addr, dst, len)` — same, read side.
* **Other-core parking** — `psr_park_spin()` (IRAM) plus the
  `psr_park_request`/`psr_parked` handshake, driven by a top-priority Ada task
  pinned to the other core. This is the piece I'd flagged as unproven; it is
  shipping. `Settings.Save` (Ada) drives it and freezes the system for the
  ~50–100 ms erase+program.
* `psr_rom.ld` — the exact ROM entry points:
  ```
  esp_rom_spiflash_erase_sector = 0x400009fc     esp_rom_spiflash_unlock = 0x40000a2c
  esp_rom_spiflash_write        = 0x40000a14     rom_Cache_Suspend_ICache = 0x4000189c
  esp_rom_spiflash_read         = 0x40000a20     Cache_Resume_ICache      = 0x400018a8
                                                 rom_Cache_Suspend_DCache = 0x400018b4
                                                 Cache_Resume_DCache      = 0x400018c0
  ```

**What the scaffold adds** to this proven base is modest:

* **Promote it to the SDK.** Move `settings_flash.c` + `psr_rom.ld` into the HAL
  (e.g. `ESP32S3.Int_Flash`), so every app — settings persistence *and* OTA —
  shares one audited copy instead of each carrying its own.
* **Multi-sector streaming + slot targeting.** `settings_flash.c` does one 4 KB
  sector; OTA writes a ~250 KB image, so loop erase+program across the inactive
  slot's sectors as chunks arrive (the `Save` freeze becomes many short freezes,
  or one bulk write with the other core parked throughout — a tuning choice).
* **Wrap as a `Block_Dev` source.** Expose the promoted driver as
  `Block_Dev.Int_Flash_Source` (mirrors `W25Q_Source`) so the OTA image writer,
  alignment and streaming all come from the existing stack (§ above).
* **Scope guard.** Refuse any write inside the running slot — only ever the
  inactive slot and the boot-control sectors.

So the "one real risk" is retired: the cache-safe write and core-parking are
production code. The remaining work is generalising it (multi-sector, slot-aware,
SDK-resident) and the bootloader A/B logic (§6) — no unproven silicon dance.

---

## 8. ThingsBoard OTA client (private)

A closure-free state machine over the existing MQTT primitives (the handler only
records; the main loop acts after `Pump` returns — the established pattern):

* `Connect_Over` TLS with `User_Name => access_token`.
* `Subscribe` to the attribute-response and `v2/fw/response/+/chunk/+` filters.
* Publish the shared-attribute request; parse `fw_*` from the JSON reply with the
  existing `libs/json` pull parser.
* If newer: `OTA.Begin_Update`, then loop — request chunk `n`, on receipt
  `OTA.Write` it (streams to flash + SHA), request `n+1` — until `fw_size`.
* `OTA.Verify` against `fw_checksum`; `OTA.Activate`; publish `fw_state` at each
  transition; reboot; confirm after the healthy reconnect.

MURMUR3 is the only ThingsBoard checksum with no existing impl — trivially added
if needed, but SHA-256 is the default and already streaming.

---

## 9. Phased plan

**Phase 1 — MVP, existing code only (no bootloader/flash-write work).**
Implement the full ThingsBoard client and *stage* the verified image to the
W25Q/ext4, reporting real `fw_state` telemetry. Proves the entire cloud→device
pipeline (attributes, chunking, streaming SHA-256, telemetry) against a live
ThingsBoard, stopping one step short of applying. Almost entirely wiring
existing parts.

**Phase 2 — the last mile.**
1. Add ROM flash symbols; add `Block_Dev.Int_Flash_Source` (mirrors
   `W25Q_Source`) whose backend does cache-safe IRAM erase/program; unit-prove
   erase/program on a scratch region **outside** both slots. The OTA core and
   streaming come for free from the existing Block_Dev stack.
2. Add the boot-control block + the A/B/rollback logic to `boot_main.adb`;
   verify slot-select and forced-rollback on hardware.
3. Point the OTA core's `Write/Activate` at the inactive internal slot; end-to-end
   update + rollback test.

**Phase 3 (optional).** Raise `Max_Packet_Bytes` for bigger chunks; signed
images (the P-256/P-384 verify already exists); anti-rollback via a version
floor in boot-control.

---

## 10. Risks & decisions

* **Internal-flash self-program while XIP** — **retired.** This was the one real
  risk; PSR_Firmware's `settings_flash.c` already does the cache-safe IRAM
  erase/program *and* the other-core parking in production (§7). The scaffold
  generalises proven code (multi-sector, slot-aware) rather than proving new
  silicon behaviour. The residual is ordinary engineering: confirm a full-image
  write across the inactive slot round-trips, and pick the freeze granularity
  (many short parks vs one long one) against the app's timing needs.
* **Chunk size vs the 1 KB cap** — start with small chunks (no code change);
  raise the cap only if transfer time is unacceptable.
* **Confirm/health definition** — what counts as a "healthy" boot for confirm?
  Proposal: MQTT reconnected and `UPDATED` telemetry accepted. Tunable per app.
* **Power-loss safety** — ping-pong boot-control + seq/CRC handles a loss during
  the control update; a loss mid-image-write just leaves the inactive slot
  invalid (never selected). Both are safe by construction.

## 11. Open questions

* One firmware image per device type, or per device? (ThingsBoard supports both;
  affects nothing on-device — same protocol.)
* Cellular (BG95) OTA — same protocol, slower; want it in scope for Phase 1?
* Do we want a golden/recovery image in the ~12 MB free region as a last-resort
  fallback the bootloader can always reach?
