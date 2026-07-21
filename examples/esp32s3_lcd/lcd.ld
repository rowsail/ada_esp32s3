/* IDF-free external-PSRAM region for esp32s3_lcd (supplements the shared
 * memory.ld/sections.ld via an extra -T).  fb.adb's two 768 KB framebuffers
 * (FB0/FB1, RGB565 800x480) live in .ext_ram.bss -- 1.5 MB, comfortably inside
 * this 2 MB window.  The 2nd-stage bootloader brings the octal PSRAM up;
 * src/lcd_board.adb (bare_board_init) maps PSRAM physical 0 -> this d-bus vaddr
 * with the ROM Cache_Dbus_MMU_Set (after start.S wipes the d-bus MMU), after
 * which the framebuffers are backed by real PSRAM and the GDMA streams them.
 * 0x3D000000 is a free, 64 KB-aligned slot in the cached external d-bus window
 * SOC_EXTRAM_DATA (0x3C000000..0x3E000000), clear of the flash rodata at 0x3C02xxxx. */
MEMORY
{
  ext_ram_seg (RW) : org = 0x3D000000, len = 0x200000     /* 2 MB window into PSRAM */
}

SECTIONS
{
  .ext_ram.bss (NOLOAD) :
  {
    . = ALIGN(32);
    _ext_ram_bss_start = ABSOLUTE(.);
    *(.ext_ram.bss .ext_ram.bss.*)
    . = ALIGN(32);
    _ext_ram_bss_end = ABSOLUTE(.);
  } > ext_ram_seg
}
