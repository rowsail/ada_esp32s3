/* From-source replacement for the last vendored blob, esp_psram_impl_octal.c.obj
 * -- the octal-PSRAM chip bring-up.  Together with mspi_timing_src.c this makes
 * the whole PSRAM bring-up readable (only ROM functions remain).
 *
 * The chip-facing steps (mode-register program, connectivity probe) use the ROM
 * OPI helper esp_rom_opiflash_exec_cmd, exactly as the blob did; the controller-
 * side config (CS timing, ECC, SPI0 cache phases) is written from the live
 * "golden" register state captured over JTAG (see PSRAM_BRINGUP_RESEARCH.md), and
 * the clock/din steps are mspi_timing_src.c.  Order matters: pins/CS/ECC, then
 * 20 MHz, then the MR transactions, then 80 MHz, then the cache phases.
 */
#include <stdint.h>

extern int  esp_rom_printf(const char *fmt, ...);
extern void esp_rom_opiflash_exec_cmd(int spi_num, int mode, unsigned cmd, int cmd_bits,
    unsigned addr, int addr_bits, int dummy_bits,
    const void *mosi, int mosi_bits, void *miso, int miso_bits,
    unsigned cs_mask, int is_write_erase);
extern void esp_rom_spi_set_dtr_swap_mode(int spi_num, int wr, int rd);
extern void Cache_Resume_DCache(unsigned autoload);
extern void mspi_timing_enter_low_speed_mode(int control_both);
extern void mspi_timing_enter_high_speed_mode(int control_both);
extern void mspi_timing_psram_tuning(void);

#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))

#define OPI_DTR   7          /* ESP_ROM_SPIFLASH_OPI_DTR_MODE */
#define CS1       2u         /* BIT(1) -- the PSRAM chip select */

static uint32_t s_psram_size;   /* decoded from the density mode-register */

/* Read an octal-PSRAM mode register (or a pair: a 16-bit read returns MRn in the
 * low byte and MR(n+1) in the high byte). */
static unsigned read_mr(unsigned addr, int bits)
{
    unsigned char b[2] = { 0, 0 };
    esp_rom_opiflash_exec_cmd(1, OPI_DTR, 0x4040u, 16, addr, 32, 8, 0, 0, b, bits, CS1, 0);
    return (unsigned) b[0] | ((unsigned) b[1] << 8);
}

/* Read the device's mode registers, decode + print what the chip reports (vendor,
 * density/size, voltage, latency), and record the physical size.  Runs at the
 * slow clock, right after the connectivity probe. */
static void psram_report(void)
{
    unsigned r01 = read_mr(0x0, 16);   /* MR0 (low) + MR1 (high) */
    unsigned r23 = read_mr(0x2, 16);   /* MR2 (low) + MR3 (high) */
    unsigned mr4 = read_mr(0x4, 8);
    unsigned mr8 = read_mr(0x8, 8);
    unsigned mr0 = r01 & 0xFF, mr1 = (r01 >> 8) & 0xFF;
    unsigned mr2 = r23 & 0xFF, mr3 = (r23 >> 8) & 0xFF;

    unsigned vendor  = mr1 & 0x1F;
    unsigned density = mr2 & 0x07;
    unsigned devid   = (mr2 >> 3) & 0x03;
    unsigned rlat    = (mr0 >> 2) & 0x07;        /* read-latency code */
    unsigned lt      = (mr0 >> 5) & 0x01;        /* 1=fixed, 0=variable */
    unsigned wlat    = (mr4 >> 5) & 0x07;        /* write-latency code */
    unsigned vcc     = (mr3 >> 6) & 0x01;        /* 1=3.0V, 0=1.8V */

    const char *vname = (vendor == 0x0D) ? "AP Memory"
                      : (vendor == 0x1A) ? "UnilC" : "unknown";
    unsigned mbit;
    switch (density) {
        case 0x1: mbit = 32;  s_psram_size = 4u  << 20; break;
        case 0x3: mbit = 64;  s_psram_size = 8u  << 20; break;
        case 0x5: mbit = 128; s_psram_size = 16u << 20; break;
        case 0x7: mbit = 256; s_psram_size = 32u << 20; break;
        case 0x6: mbit = 512; s_psram_size = 64u << 20; break;
        default:  mbit = 0;   s_psram_size = 0;         break;
    }
    esp_rom_printf("[ada-free-boot] PSRAM: %s octal DDR @80MHz, %u Mbit (%u MB), "
                   "dev gen %u, Vcc %s\n",
                   vname, mbit, s_psram_size >> 20, devid + 1, vcc ? "3.0V" : "1.8V");
    esp_rom_printf("[ada-free-boot]   latency: read %u-cyc (%s), write %u-cyc;  "
                   "MR0=%02x MR1=%02x MR2=%02x MR3=%02x MR4=%02x MR8=%02x\n",
                   rlat * 2 + 6, lt ? "fixed" : "variable", wlat + 3,
                   mr0, mr1, mr2, mr3, mr4, mr8);
}

int psram_impl_enable_src(void);
int psram_impl_enable_src(void)
{
    /* s_init_psram_pins: route the CS1 pad + pad drive (golden). */
    REG(0x6000906Cu) = 0x00000F00u;   /* IO_MUX GPIO26 -> SPICS1, FUN_DRV=3   */
    REG(0x600033FCu) = 0x0210105Fu;   /* SPI0 SPI_MEM_DATE: SMEM SPICLK drive */

    /* s_set_psram_cs_timing: CS hold/setup=3, hold-delay=2. */
    REG(0x600030DCu) = 0x0400B18Fu;   /* SPI_MEM_SPI_SMEM_AC_REG(0) */

    /* s_configure_psram_ecc (ECC off): clear ACE0 ECC-enable (bit 8). */
    REG(0x60026058u) &= ~(1u << 8);   /* SYSCON_SRAM_ACE0_ATTR_REG */

    /* Drop to 20 MHz for the mode-register transactions. */
    mspi_timing_enter_low_speed_mode(1);

    /* SPI1 variable-dummy + no DTR byte-swap (the MR transactions need this). */
    REG(0x600020E0u) |= 2u;           /* SPI_MEM_DDR_REG(1): SPI_FMEM_VAR_DUMMY */
    esp_rom_spi_set_dtr_swap_mode(1, 0, 0);

    /* Program MR0: read-modify-write the low 6 bits to lt=1 (fixed latency),
       read_latency=2, drive_str=0  ->  0x28. */
    unsigned char mr[2] = { 0, 0 };
    esp_rom_opiflash_exec_cmd(1, OPI_DTR, 0x4040u, 16, 0, 32, 8, 0, 0, mr, 16, CS1, 0);
    mr[0] = (unsigned char) ((mr[0] & ~0x3Fu) | 0x28u);
    esp_rom_opiflash_exec_cmd(1, OPI_DTR, 0xC0C0u, 16, 0, 32, 0, mr, 16, 0, 0, CS1, 0);

    /* Connectivity probe: write 0x5a6b7c8d, read it back. */
    unsigned wr = 0x5A6B7C8Du, rd = 0;
    esp_rom_opiflash_exec_cmd(1, OPI_DTR, 0x8080u, 16, 0, 32, 8, &wr, 32, 0, 0, CS1, 0);
    esp_rom_opiflash_exec_cmd(1, OPI_DTR, 0x0000u, 16, 0, 32, 18, 0, 0, &rd, 32, CS1, 0);
    if (rd != wr) {
        esp_rom_printf("[ada-free-boot] PSRAM connect FAIL: rd=0x%08x\n", rd);
        return -1;
    }

    psram_report();    /* read + print vendor / density / latency (still slow clock) */

    mspi_timing_psram_tuning();            /* no-op */
    mspi_timing_enter_high_speed_mode(1);  /* 80 MHz */
    /* spi_flash_set_rom/vendor_required_regs: no-op stubs, skipped. */

    /* s_config_psram_spi_phases: SPI0 cache OPI-DDR config (golden, final-state). */
    REG(0x60003044u) = 0x007C0000u;   /* SPI_MEM_SRAM_CMD_REG : octal cmd/addr/data */
    REG(0x60003048u) = 0xF0000000u;   /* SPI_MEM_SRAM_DRD_CMD : read cmd 0x0000     */
    REG(0x6000304Cu) = 0xF0008080u;   /* SPI_MEM_SRAM_DWR_CMD : write cmd 0x8080    */
    REG(0x600030E4u) = 0x00003023u;   /* SPI_MEM_SPI_SMEM_DDR : DDR en + var dummy  */
    REG(0x60003040u) = 0x01F7C479u;   /* SPI_MEM_CACHE_SCTRL : usr cmd/addr/dummy/OCT */
    Cache_Resume_DCache(0);
    return 0;
}

/* Physical size as decoded from the density mode-register by psram_report(). */
int psram_impl_get_physical_size_src(uint32_t *out);
int psram_impl_get_physical_size_src(uint32_t *out)
{
    if (!out) return -1;
    *out = s_psram_size;
    return s_psram_size ? 0 : -1;
}
