/* esp32s3_qmi8658c example-specific console helpers.  All bare-boot (core
   bring-up, env entry, the L5 tick, clock) is shared in ../../common/bare/
   bare_glue.c.  The demo report uses the ROM USB-Serial-JTAG printf (the
   reliable console path for these bare examples); the Ada driver does all the
   register/I2C work and imports these as "native_imu_*".

   Notes on the ROM printf to the USB-serial-JTAG: it does NOT support the '+'
   (force-sign) flag, truncates a call past ~6 conversions, and -- because it
   does not block on a full FIFO -- drops output past the 64-byte FIFO depth in a
   single call.  So the per-sample line is formatted into a buffer (one "%s"
   conversion) AND kept under 64 bytes with compact labels (see the legend). */
extern int esp_rom_printf(const char *fmt, ...);

void native_imu_banner(void)
{
    esp_rom_printf("[imu] QMI8658C 6-axis IMU driver demo "
                   "(SDA=IO8  SCL=IO7)\n");
}

/* WHO_AM_I result: id = register value, addr = the 7-bit address it answered on,
   ok = matched the expected 0x05. */
void native_imu_whoami(int id, int addr, int ok)
{
    esp_rom_printf("[imu] who_am_i : 0x%02x @ 0x%02x  %s\n",
                   id, addr, ok ? "(QMI8658 present)" : "(unexpected!)");
}

void native_imu_no_device(void)
{
    esp_rom_printf("[imu] no QMI8658C found at 0x6B or 0x6A -- "
                   "check wiring/power.\n");
}

/* Column legend for the compact sample lines below. */
void native_imu_legend(void)
{
    esp_rom_printf("[imu] a=accel[mg]  |a|=total[m/s2]  g=gyro[mdps]\n");
}

/* On-chip temperature, in centi-degrees C (printed once, on its own line). */
void native_imu_temp(int t_cc)
{
    esp_rom_printf("[imu] temp[C]=%d.%02d\n",
                   t_cc / 100, (t_cc < 0 ? -t_cc : t_cc) % 100);
}

/* Outcome of a one-shot setup step: 0 reset, 1 configure. */
void native_imu_step(int code, int ok)
{
    static const char *const name[] = { "reset", "configure" };
    const char *m = (code >= 0 && code <= 1) ? name[code] : "?";
    esp_rom_printf("[imu] %-9s : %s\n", m, ok ? "OK" : "FAIL");
}

/* Append a right-justified signed decimal (width pad spaces) to p. */
static char *put_int(char *p, int v, int width)
{
    char tmp[12];
    int n = 0, pad;
    unsigned int u = (v < 0) ? (unsigned) (-v) : (unsigned) v;
    do { tmp[n++] = (char) ('0' + (u % 10u)); u /= 10u; } while (u);
    if (v < 0) tmp[n++] = '-';
    for (pad = width - n; pad > 0; pad--) *p++ = ' ';
    while (n) *p++ = tmp[--n];
    return p;
}

static char *put_str(char *p, const char *s) { while (*s) *p++ = *s++; return p; }

/* One sample: accel in milli-g, the accel magnitude |a| in centi-m/s2 (so it can
   be eyeballed against 9.81 m/s2 = 1 g at rest), and gyro in milli-dps.  Built
   into one buffer and printed with a single "%s" (see the note above). */
void native_imu_sample(int ax_mg, int ay_mg, int az_mg, int mag_cc,
                       int gx_mdps, int gy_mdps, int gz_mdps)
{
    char line[96], *p = line;
    int fr = (mag_cc < 0 ? -mag_cc : mag_cc) % 100;

    /* Kept under 64 bytes (see the note above): compact labels, fixed widths. */
    p = put_str(p, "[imu] a=");
    p = put_int(p, ax_mg, 6); p = put_int(p, ay_mg, 6); p = put_int(p, az_mg, 6);
    p = put_str(p, " |a|=");
    p = put_int(p, mag_cc / 100, 1);
    *p++ = '.'; *p++ = (char) ('0' + fr / 10); *p++ = (char) ('0' + fr % 10);
    p = put_str(p, " g=");
    p = put_int(p, gx_mdps, 7); p = put_int(p, gy_mdps, 7); p = put_int(p, gz_mdps, 7);
    *p = '\0';

    esp_rom_printf("%s\n", line);
}

void native_imu_done(void) { esp_rom_printf("[imu] done.\n"); }
