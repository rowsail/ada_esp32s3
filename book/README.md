# The book — *Bare-Metal Ada on the ESP32-S3*

A LaTeX book documenting this project: why Ada suits microcontrollers, how it
makes register and bit-field programming safe, the anatomy of an Ada application
from `Main` down to the boot ROM, the three runtime profiles, how to build and
run on the ESP32-S3, a guide to every peripheral driver (with worked examples),
and how to use the pure-Ada ext4 filesystem.

## Build

```sh
make            # -> main.pdf  (needs pdflatex + makeindex; runs several passes)
make clean
```

A CI workflow (`.github/workflows/book.yml`) builds the same PDF in a TeX Live
container. Pushing a version tag (`v*`) publishes it as a GitHub Release;
dispatching the workflow by hand uploads it as a build artifact.

## Layout

| File | Chapters |
|------|----------|
| `main.tex` | preamble, title page, table of contents |
| `ch_foundations.tex` | Why Ada for microcontrollers; register addressing; bit fields |
| `ch_anatomy.tex` | Anatomy of an Ada application; the runtime profiles; building & running |
| `ch_hal.tex` | HAL conventions; GPIO, RNG, Temperature, SPI, I2C, UART |
| `ch_hal2.tex` | GDMA, MCPWM, I2S, LEDC, RMT, PCNT, SDM, TWAI, Timer, LCD, ADC |
| `ch_hal3.tex` | RTC, RTC-IO, Touch, SHA, AES |
| `ch_driver_design.tex` | How to write a task-safe driver (Engine / ownership gateway); why and benefits |
| `ch_storage.tex` | SD\_SPI, SDMMC, ext4; ext4 on raw SPI NOR flash (W25Q, wear leveling, on-device mkfs) |
| `ch_networking.tex` | GNAT.Sockets over the W5500; DNS, NTP, the weather example |
| `ch_tls.tex` | Pure-Ada TLS 1.3 (HTTPS) — SPARKNaCl + HW crypto, X.509, ECDHE |
| `ch_psram.tex` | Bringing up the octal PSRAM; the 80 MHz din-timing tune |
| `ch_heap.tex` | `malloc`/`free` in Ada via the O(1) TLSF allocator |
| `ch_gnarl_gnull.tex` | The GNARL/GNULL two-layer tasking runtime architecture |
| `ch_app_internal.tex` | Appendix B — reference for every on-chip peripheral driver |
| `ch_app_external.tex` | Appendix C — reference for every external-device driver |
