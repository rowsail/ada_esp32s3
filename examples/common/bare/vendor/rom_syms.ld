/* ESP32-S3 mask-ROM function addresses the app uses (no ESP-IDF needed).
 * Addresses from ESP-IDF v5.4.4 components/esp_rom/esp32s3/ld/esp32s3.rom*.ld. */
PROVIDE ( ets_printf                = 0x400005d0 );
PROVIDE ( esp_rom_printf            = 0x400005d0 );
PROVIDE ( ets_set_appcpu_boot_addr  = 0x40000720 );
PROVIDE ( ets_update_cpu_frequency  = 0x40001a4c );
PROVIDE ( Cache_Invalidate_ICache_All = 0x400016d4 );
PROVIDE ( Cache_Disable_ICache       = 0x4000186c );
PROVIDE ( Cache_Enable_ICache        = 0x40001878 );
PROVIDE ( Cache_Disable_DCache       = 0x40001884 );
PROVIDE ( Cache_Enable_DCache        = 0x40001890 );
/* DCache maintenance by address, for GDMA <-> PSRAM coherency (ESP32S3.GDMA):
 * write back dirty lines before the DMA reads them, invalidate stale lines
 * after the DMA writes them. */
PROVIDE ( Cache_Invalidate_Addr      = 0x400016b0 );
PROVIDE ( rom_Cache_WriteBack_Addr   = 0x400016c8 );
PROVIDE ( rom_config_instruction_cache_mode = 0x40001a1c );
PROVIDE ( Cache_Set_ICache_Mode      = 0x40001620 );
PROVIDE ( Cache_Occupy_ICache_MEMORY = 0x40001980 );
PROVIDE ( Cache_Set_IDROM_MMU_Size   = 0x40001914 );
/* Octal-PSRAM bring-up (esp32s3_psram): the cache d-bus MMU mapper + the
 * ROM helpers the vendored esp_psram_impl_octal / mspi_timing objects call. */
PROVIDE ( Cache_Dbus_MMU_Set         = 0x400019b0 );
PROVIDE ( Cache_Resume_DCache        = 0x400018c0 );
PROVIDE ( esp_rom_opiflash_exec_cmd  = 0x400008b8 );
PROVIDE ( esp_rom_opiflash_read_raw  = 0x4004d9d4 );
PROVIDE ( esp_rom_spiflash_read      = 0x40000a20 );
PROVIDE ( esp_rom_spi_set_dtr_swap_mode = 0x4000093c );
PROVIDE ( rom_spiflash_legacy_data   = 0x3fceffe4 );   /* ROM spiflash descriptor (DRAM) */
