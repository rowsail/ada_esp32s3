/* esp32s3_psram: IDF-free octal-PSRAM bring-up + the example native.
 *
 * The bare boot is shared in ../../common/bare/bare_glue.c.  This file overrides
 * the weak bare_board_init() (called on core 0 before adainit) to bring up the
 * external octal PSRAM and map it into the CPU's data address space, so big.adb's
 * 1 MB array (Linker_Section .ext_ram.bss, placed at 0x3D000000 by psram.ld) is
 * backed by real PSRAM.
 *
 * Active path (PSRAM_ENABLE 0): our own 2nd-stage bootloader (../../common/bare/
 * bootloader) already brought the octal PSRAM up -- it runs from SRAM, so the MSPI
 * reconfig that crashed an app-side init is safe.  bare_board_init() here then does
 * ONLY the cache-MMU map, which must run AFTER the app's start.S (whose
 * Cache_Set_IDROM_MMU_Size wipes the d-bus MMU), using the ROM Cache_Dbus_MMU_Set.
 *
 * The PSRAM_ENABLE 1 block below is a retained (disabled) alternative that brings
 * PSRAM up app-side by calling prebuilt octal-PSRAM + MSPI-timing objects'
 * esp_psram_impl_enable() directly -- NOT the full esp_psram_init(), which would
 * drag in heap_caps/esp_mmu.  It needs those objects supplied via EXTRA_OBJS plus
 * the leaf stubs below; they are no longer vendored in-tree, so build it only if
 * you re-supply them. */
#include <stdint.h>
#include <stddef.h>

extern int esp_rom_printf(const char *fmt, ...);

/* ---- freestanding bits the vendored objects need (the light-tasking runtime
 * already provides memcpy, so only these). -------------------------------------*/
void *memset(void *d, int c, size_t n)
{ unsigned char *p = d; while (n--) *p++ = (unsigned char) c; return d; }
int memcmp(const void *a, const void *b, size_t n)
{ const unsigned char *x = a, *y = b; while (n--) { if (*x != *y) return *x - *y; x++; y++; } return 0; }
void abort(void) { esp_rom_printf("[psram] abort()\n"); for (;;) { } }
void __assert_func(const char *f, int l, const char *fn, const char *e)
{ esp_rom_printf("[psram] assert %s:%d %s: %s\n", f, l, fn, e); abort(); }

/* ---- leaf stubs the vendored objects reference (no IDF services here) -------- */
int  bootloader_flash_is_octal_mode_enabled(void) { return 0; }       /* flash is DIO */
void esp_cache_freeze_ext_mem_cache(void)         { }                  /* quiescent at init */
void esp_cache_unfreeze_ext_mem_cache(void)       { }
uint64_t esp_gpio_reserve(uint64_t mask)          { (void) mask; return 0; }
uint32_t esp_log_timestamp(void)                  { return 0; }
void spi_flash_set_rom_required_regs(void)        { }                  /* no SPI1 flash cmds after boot */
void spi_flash_set_vendor_required_regs(void)     { }
int  esp_log_default_level = 3;                                        /* ESP_LOG_INFO */

/* ---- example native: the env task reports the buffer's address + checksum ----
 * 0x3C/0x3D = external PSRAM data range; 0x3F = internal SRAM. */
void native_buf_report(unsigned addr, unsigned bytes, unsigned checksum)
{
    const char *where = ((addr >> 24) == 0x3c || (addr >> 24) == 0x3d) ? "PSRAM"
                      : ((addr >> 24) == 0x3f) ? "internal-SRAM" : "?";
    esp_rom_printf("[psram] buffer @ 0x%08x  %u bytes  checksum=0x%08x  (%s)\n",
                   addr, bytes, checksum, where);
}

/* ---- the bring-up: enable octal PSRAM, then map it to the array's vaddr ------ */
#define PSRAM_ENABLE 0   /* PSRAM is now brought up + mapped by our 2nd-stage bootloader
                            (common/bare/bootloader) -- it runs from SRAM so the MSPI
                            reconfig that crashed the app-side init is safe.  App side
                            is a no-op; the .ext_ram.bss array @0x3D000000 is already
                            backed by real PSRAM when main runs. */
#if PSRAM_ENABLE
extern int esp_psram_impl_enable(void);
extern int esp_psram_impl_get_physical_size(uint32_t *out_size_bytes);
extern int Cache_Dbus_MMU_Set(uint32_t ext_ram, uint32_t vaddr, uint32_t paddr,
                              uint32_t psize, uint32_t num, uint32_t fixed);

#define SOC_MMU_ACCESS_SPIRAM  (1u << 15)
#define PSRAM_VADDR            0x3D000000u      /* must match psram.ld ext_ram_seg */
#define PSRAM_MAP_PAGES        32u              /* 32 x 64 KB = 2 MB */

void bare_board_init(void)
{
    int rc = esp_psram_impl_enable();           /* SPI0 octal config + MSPI tuning */
    if (rc != 0) {
        esp_rom_printf("[psram] esp_psram_impl_enable FAILED rc=%d\n", rc);
        return;
    }
    uint32_t bytes = 0;
    esp_psram_impl_get_physical_size(&bytes);
    esp_rom_printf("[psram] octal SPIRAM up: %u MB physical\n", bytes >> 20);

    /* Map PSRAM physical 0 -> the array's d-bus vaddr (cache will fetch via SPI0). */
    rc = Cache_Dbus_MMU_Set(SOC_MMU_ACCESS_SPIRAM, PSRAM_VADDR, 0, 64, PSRAM_MAP_PAGES, 0);
    esp_rom_printf("[psram] Cache_Dbus_MMU_Set vaddr=0x%08x rc=%d (0=ok)\n",
                   PSRAM_VADDR, rc);
}
#else
void bare_board_init(void)
{
    /* The 2nd-stage bootloader already brought up the octal PSRAM
       (esp_psram_impl_enable, from SRAM -- no flash-XIP crash).  We do ONLY the
       cache-MMU map here: it must run AFTER the app's start.S, whose
       Cache_Set_IDROM_MMU_Size wipes the d-bus MMU (so a map in the bootloader
       would be lost).  SPIRAM access bit = 0x8000. */
    extern int  Cache_Dbus_MMU_Set(unsigned ext_ram, unsigned vaddr, unsigned paddr,
                                   unsigned psize, unsigned num, unsigned fixed);
    extern void Cache_Disable_DCache(void);
    extern void Cache_Enable_DCache(unsigned autoload);
    Cache_Disable_DCache();                                   /* MMU write needs cache off */
    int rc = Cache_Dbus_MMU_Set(0x8000u, 0x3D000000u, 0, 64, 32, 0);   /* SPIRAM, 2 MB */
    Cache_Enable_DCache(0);
    esp_rom_printf("[psram] mapped PSRAM @0x3D000000 rc=%d (bootloader did the bring-up)\n", rc);
}
#endif
