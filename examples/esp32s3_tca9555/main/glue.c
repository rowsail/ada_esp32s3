/* esp32s3_tca9555 example-specific console helpers.  Bare-boot is shared in
   ../../common/bare/bare_glue.c.  The Ada TCA9555 driver does all the I2C work. */
extern int esp_rom_printf(const char *fmt, ...);

void native_tca_banner(void)
{
    esp_rom_printf("[gpio] TCA9555 16-bit I2C GPIO expander demo "
                   "(0x20, SDA=IO8 SCL=IO7)\n");
}

void native_tca_probe(int inputs, int ok)
{
    esp_rom_printf("[gpio] probe   : inputs=0x%04x  %s\n",
                   inputs & 0xffff, ok ? "(present)" : "(no ACK!)");
}

void native_tca_no_device(void)
{
    esp_rom_printf("[gpio] no TCA9555 found at 0x20 -- check wiring/power.\n");
}

/* Output-register write -> read-back (pins stay inputs, so nothing is driven). */
void native_tca_outreg(int wrote, int got, int ok)
{
    esp_rom_printf("[gpio] out-reg : wrote=0x%04x read=0x%04x  %s\n",
                   wrote & 0xffff, got & 0xffff, ok ? "PASS" : "FAIL");
}

/* Single-pin read-modify-write of the output register. */
void native_tca_pin(int pin, int wrote, int got, int ok)
{
    esp_rom_printf("[gpio] pin %-2d  : set=%d  out-bit=%d  %s\n",
                   pin, wrote, got, ok ? "PASS" : "FAIL");
}

/* Polarity-inversion register write -> read-back. */
void native_tca_polreg(int wrote, int got, int ok)
{
    esp_rom_printf("[gpio] pol-reg : wrote=0x%04x read=0x%04x  %s\n",
                   wrote & 0xffff, got & 0xffff, ok ? "PASS" : "FAIL");
}

void native_tca_done(void) { esp_rom_printf("[gpio] done.\n"); }
