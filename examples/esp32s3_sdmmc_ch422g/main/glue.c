/* esp32s3_sdmmc_ch422g console helpers.  Shared bare-boot in ../../common/bare. */
extern int esp_rom_printf(const char *fmt, ...);

static const char *kind_name(int k)
{
    switch (k) {        /* ESP32S3.SDMMC.Card_Kind'Pos */
    case 0: return "Unknown"; case 1: return "SDSC"; case 2: return "SDHC/SDXC";
    default: return "?";
    }
}
static const char *status_name(int s)
{
    switch (s) {        /* ESP32S3.SDMMC.Status'Pos */
    case 0: return "OK";           case 1: return "No_Card";
    case 2: return "Unusable";     case 3: return "Init_Timeout";
    case 4: return "Cmd_Timeout";  case 5: return "Cmd_CRC";
    case 6: return "Read_Error";   case 7: return "Write_Error";
    default: return "?";
    }
}

void native_sd_banner(void)
{
    esp_rom_printf("[sd] SD card via SDMMC 1-bit, DAT3/CD held high by CH422G IO4\n");
    esp_rom_printf("[sd]   SDMMC: CLK=IO12 CMD=IO11 D0=IO13   CH422G: I2C0 SDA=8 SCL=9\n");
}

/* ok = the CH422G drove its IO bank (IO4=1, others low). */
void native_sd_exio(int ok)
{
    esp_rom_printf("[sd] CH422G IO bank -> 0x10 (DAT3 high) : %s\n",
                   ok ? "OK" : "I2C error");
}

void native_sd_init(int status, int kind)
{
    esp_rom_printf("[sd] init: %s   card: %s\n", status_name(status), kind_name(kind));
}

/* Decoded CID + capacity. */
void native_sd_id(int mid, const char *oem, const char *pnm,
                  int rmaj, int rmin, unsigned serial, int year, int month)
{
    esp_rom_printf("[sd] CID: mfr=0x%x  oem=%s  name=%s  rev %d.%d\n",
                   mid & 0xff, oem, pnm, rmaj, rmin);
    esp_rom_printf("[sd]      serial=0x%x  manufactured %d-%d\n",
                   serial, year, month);
}

void native_sd_cap(unsigned mb)
{
    esp_rom_printf("[sd] capacity: %u MB  (~%u.%u GB)\n",
                   mb, mb / 1024, (mb % 1024) * 10 / 1024);
}

void native_sd_caps(int max_mhz, unsigned ccc, int rbl,
                    int spec_maj, int spec_min, int bus4, int hs)
{
    esp_rom_printf("[sd] caps: spec %d.%d  default-speed max %d MHz  "
                   "High-Speed %s  4-bit %s\n",
                   spec_maj, spec_min, max_mhz, hs ? "yes" : "no",
                   bus4 ? "yes" : "no");
    esp_rom_printf("[sd]        cmd-classes 0x%x  read-block %d B\n",
                   ccc & 0xfff, rbl);
}

void native_sd_speed(int active_mhz, int hs_active)
{
    esp_rom_printf("[sd] running: %d MHz  (High Speed %s)\n",
                   active_mhz, hs_active ? "ON" : "off");
}

/* block 0 first bytes + the 0x55AA boot signature at offset 510. */
void native_sd_read(int status, int b0, int b1, int b2, int b3, int sig_ok)
{
    if (status != 0) { esp_rom_printf("[sd] read block 0: %s\n", status_name(status)); return; }
    esp_rom_printf("[sd] read block 0: OK   first bytes = %02x %02x %02x %02x   "
                   "boot sig 0x55AA: %s\n", b0, b1, b2, b3, sig_ok ? "present" : "absent");
}

void native_sd_done(void) { esp_rom_printf("[sd] done.\n"); }
