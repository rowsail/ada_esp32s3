/* esp32s3_es8311 console helpers.  Shared bare-boot in ../../common/bare. */
extern int esp_rom_printf(const char *fmt, ...);

void native_es_banner(void)
{
    esp_rom_printf("[es8311] ES8311 codec: 440 Hz test tone on the DAC output "
                   "(I2C control + I2S audio)\n");
}

void native_es_init(int ok)
{
    esp_rom_printf("[es8311] codec init: %s\n",
                   ok ? "OK" : "FAILED (I2C no ACK? check address/wiring)");
}

void native_es_playing(void)
{
    esp_rom_printf("[es8311] playing 440 Hz... (connect a speaker/headphone to "
                   "the codec output)\n");
}

void native_es_listening(int gain_db)
{
    esp_rom_printf("[es8311] mic capture on (ADC PGA %d dB) -- play feeds the "
                   "speaker, mic should hear it\n", gain_db);
}

void native_es_captured(int peak, int freq)
{
    if (peak < 200) {
        esp_rom_printf("[es8311] captured: peak=%d (quiet -- no tone picked up?)"
                       "\n", peak);
    } else {
        esp_rom_printf("[es8311] captured: peak=%d  est tone=%d Hz\n", peak, freq);
    }
}
