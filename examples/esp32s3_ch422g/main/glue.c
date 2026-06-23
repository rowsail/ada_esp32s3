/* esp32s3_ch422g example console helpers.  Bare-boot is shared in
   ../../common/bare/bare_glue.c.  The Ada CH422G driver does the I2C work. */
extern int esp_rom_printf(const char *fmt, ...);

void native_ch_banner(void)
{
    esp_rom_printf("[ch422g] CH422G I2C I/O expander demo (read-only)\n");
    esp_rom_printf("[ch422g]   I2C0 SDA=IO8 SCL=IO9; addrs 0x24/0x23/0x38/0x26\n");
}

void native_ch_present(int ok)
{
    esp_rom_printf("[ch422g] probe 0x24 : %s\n", ok ? "ACK (present)" : "no ACK");
}

/* io = IO0..IO7 byte; ok = read succeeded. */
void native_ch_read(int io, int ok)
{
    if (!ok) { esp_rom_printf("[ch422g] read IO : bus error\n"); return; }
    esp_rom_printf("[ch422g] IO inputs = 0x%02x  IO7..IO0 = %d%d%d%d%d%d%d%d\n",
                   io & 0xff,
                   (io >> 7) & 1, (io >> 6) & 1, (io >> 5) & 1, (io >> 4) & 1,
                   (io >> 3) & 1, (io >> 2) & 1, (io >> 1) & 1, io & 1);
}
