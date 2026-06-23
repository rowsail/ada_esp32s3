/* esp32s3_gps_display example console helpers.  Bare-boot is shared in
   ../../common/bare/bare_glue.c.  The panel is the real output; the console
   mirrors each row pushed to the display so a live run can be verified over
   serial too (the panel is write-only). */
extern int esp_rom_printf(const char *fmt, ...);

/* 240x240 RGB565 Ada-mascot splash; the symbol ada_logo_rgb565 is imported by
   Ada (src/ada_logo.ads) and blitted at startup via ESP32S3.ST7789.Draw_Bitmap. */
#include "ada_logo.h"

void native_gd_banner(void)
{
    esp_rom_printf("[dash] multi-sensor dashboard -> ST7789 240x240\n");
    esp_rom_printf("[dash]   GPS  UART0 rx=44 tx=43 9600   (NMEA)\n");
    esp_rom_printf("[dash]   I2C0 sda=8 scl=7  SHT41 0x44 / RTC 0x51 / IMU 0x6b\n");
    esp_rom_printf("[dash]   LCD  SPI2  sclk=12 mosi=13 dc=16 cs=10 bl=6\n");
    esp_rom_printf("[dash]   cycling GPS / ENV / RTC / IMU, 5 s each\n");
}

/* s = the exact text line pushed to one display row (already framed by Ada). */
void native_gd_row(const char *s)
{
    esp_rom_printf("[dash] %s\n", s);
}
