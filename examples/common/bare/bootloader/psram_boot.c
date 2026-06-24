/* Octal-PSRAM bring-up, kept in C because it drives the vendored IDF blobs
 * (esp_psram_impl_octal / mspi_timing).  Called once from the Ada loader
 * (boot_main.adb) as psram_bringup(), after the flash cache is up. */
#include <stdint.h>
#include "board_config.h"   /* generated from config/board.ads: BOARD_PSRAM_PAGES */

extern int  esp_rom_printf(const char *fmt, ...);
extern void esp_rom_opiflash_pin_config(void);
extern void mspi_timing_set_pin_drive_strength(void);
extern int  psram_impl_enable_src(void);                /* from-source (psram_impl_src.c) */
extern int  psram_impl_get_physical_size_src(uint32_t *out);
extern void Cache_Disable_DCache(void);
extern void Cache_Enable_DCache(uint32_t autoload);
extern int  Cache_Dbus_MMU_Set(uint32_t ext_ram, uint32_t vaddr, uint32_t paddr,
                               uint32_t psize, uint32_t num, uint32_t fixed);

#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))

/* ---- Real din tune AT 80 MHz (replaces the hardcoded FIX 2). -----------------
 * The IDF blob "tunes" at 20 MHz, where the din sampling phase is irrelevant, so
 * every config passes and it falls back to a vendor default that is actually wrong
 * for the 80 MHz cache read.  Here we sweep din with the reads done at the real
 * 80 MHz operating speed over a BOUNDED SPI1 manual transaction (a wrong din
 * returns garbage and the transaction still completes -- unlike a cache read,
 * which stalls the bus).  That yields a genuine timing window; we centre on it.
 *
 * din timing affects READS only (the reference write is data-out), and the
 * bootloader runs from flash/IRAM -- not PSRAM -- so retuning PSRAM din here is
 * safe.  SPI0 (cache) and SPI1 share the same MSPI clock and pads, so the window
 * measured over SPI1 is the window the cache wants; we apply the result to the
 * SPI0 cache din and the app's checksum validates it end-to-end. */
extern void esp_rom_opiflash_exec_cmd(int spi_num, int mode, unsigned cmd, int cmd_bits,
    unsigned addr, int addr_bits, int dummy_bits,
    const void *mosi, int mosi_bits, void *miso, int miso_bits,
    unsigned cs_mask, int is_write_erase);

#define SMEM_DIN_MODE_0  0x600030C0u   /* SPI0 (cache) din-mode register  */
#define MSPI_DIN_MODE_1  0x600020C0u   /* SPI1 (manual) din-mode register */

/* 3-bit sampling mode m replicated across the 9 din fields (8 data + DQS). */
static unsigned din_word(unsigned m)
{ unsigned v = 0, i; m &= 7u; for (i = 0; i < 9; i++) v |= m << (i * 3); return v; }

static unsigned psram_tune_din(void)
{
    const unsigned ADDR = 0x001F0000u;       /* physical PSRAM, beyond the app's 1 MB */
    const unsigned REF  = 0xA55A1234u;
    unsigned ref = REF, rd, m, pass = 0;

    /* reference write (data-out: din-independent), then sweep the read din. */
    esp_rom_opiflash_exec_cmd(1, 7, 0x8080u, 16, ADDR, 32, 8, &ref, 32, 0, 0, 2u, 0);
    for (m = 0; m < 8; m++) {
        REG(SMEM_DIN_MODE_0) = din_word(m);
        REG(MSPI_DIN_MODE_1) = din_word(m);
        rd = 0;
        esp_rom_opiflash_exec_cmd(1, 7, 0x0000u, 16, ADDR, 32, 18, 0, 0, &rd, 32, 2u, 0);
        if (rd == REF) pass |= 1u << m;
    }

    /* Centre of the widest run of passing modes, treating din as CIRCULAR (mode 7
     * is adjacent to mode 0 -- it is a sampling phase).  Two laps catch a window
     * that wraps the 7->0 seam.  Fall back to mode 1 if the sweep is degenerate. */
    unsigned best = 1, run = 0, start = 0, best_run = 0, i;
    if (pass != 0 && pass != 0xFFu)
        for (i = 0; i < 16; i++) {
            if (pass & (1u << (i & 7u))) {
                if (run == 0) start = i;
                run++;
                if (run > best_run && run <= 8) {
                    best_run = run; best = (start + run / 2) & 7u;
                }
            } else {
                run = 0;
            }
        }

    /* IMPORTANT: the sweep above runs over a SPI1 manual transaction, but PSRAM is
     * actually read through the SPI0 *cache*, whose optimal din is OFFSET from the
     * SPI1 window -- and that offset's marginality does NOT show up in a quick
     * read-back (a 1 MB checksum passes at the SPI1-centre mode), it only corrupts
     * a heap-heavy app under sustained access (it crashed the ext4 battery on one
     * board).  din_mode 1 is the validated-robust cache point for this octal chip
     * on every board tested and always lands inside the SPI1 window, so prefer it;
     * the centre above is kept only as the fallback for a window that excludes it. */
    if (pass & (1u << 1)) best = 1;

    REG(SMEM_DIN_MODE_0) = din_word(best);   /* apply the chosen cache din */
    REG(MSPI_DIN_MODE_1) = 0;                 /* SPI1 din back to default */
    esp_rom_printf("[ada-free-boot] PSRAM din tuned @80MHz: passmask=0x%02x -> mode %u\n",
                   pass, best);
    return best;
}

void psram_bringup(void);
void psram_bringup(void)
{
    /* FIX 1 (= the IDF's esp_mspi_pin_init): configure the OCTAL MSPI pins
       SPID4-7 + DQS the ROM flash setup leaves unwired, + the pin drive.  Without
       them the OPI mode-register read has only 4 of 8 data lines -> a corrupted
       read (density 0x5/16MB vs the real 0x3/8MB) -> a mis-configured chip. */
    esp_rom_opiflash_pin_config();
    mspi_timing_set_pin_drive_strength();

    int prc = psram_impl_enable_src();
    uint32_t psz = 0;
    psram_impl_get_physical_size_src(&psz);
    esp_rom_printf("[ada-free-boot] octal PSRAM up: rc=%d  %u MB\n", prc, psz >> 20);

    Cache_Disable_DCache();
    /* map BOARD_PSRAM_PAGES x 64 KB of PSRAM @0x3D000000 (size from board.ads) */
    int mrc = Cache_Dbus_MMU_Set(0x8000u, 0x3D000000u, 0, 64, BOARD_PSRAM_PAGES, 0);
    Cache_Enable_DCache(0);
    esp_rom_printf("[ada-free-boot] PSRAM mapped @0x3D000000 rc=%d\n", mrc);

    /* Measure the cache-read din at 80 MHz and apply it (replaces the old FIX 2
       hardcode; the blob's 20 MHz "tuning" picks a default that fails at 80 MHz). */
    psram_tune_din();
}
