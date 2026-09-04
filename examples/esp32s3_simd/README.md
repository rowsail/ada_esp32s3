# PIE SIMD — vector kernels in inline assembly (ESP32-S3, no FreeRTOS)

The **`ESP32S3.SIMD`** library (`libs/esp32s3_simd`) on real silicon: a few
representative vector kernels whose inner loops are GNAT **inline assembly** over
the Xtensa LX7 **PIE** SIMD unit and its `q` registers.

Every kernel is checked against a plain scalar Ada reference and then timed
against it with the cycle counter, so each line reports **both** correctness and
the speed-up.

```
=== ESP32-S3 PIE SIMD on bare-metal Ada ===
240 MHz, vectors of 1024 elements, 64 iterations

Add  i32  SIMD=17840 scalar=71230 speedup=3.9x  PASS
Dot  i32  SIMD=18120 scalar=69880 speedup=3.8x  PASS
Add  f32  SIMD=17910 scalar=70450 speedup=3.9x  PASS
Copy i32  SIMD=9040 scalar=35120 speedup=3.8x  PASS
Cmp> i32  SIMD=17650 scalar=70020 speedup=3.9x  PASS

done.
```

`SIMD=` and `scalar=` are **cycle counts**, so lower is better and the numbers on
your board will differ. The `PASS` is what matters: it means the vector result
matched the scalar reference element for element. A `*** FAIL ***` means the
kernel is fast and wrong, which is the failure mode hand-written assembly
actually has.

## Two ESP32-S3 specifics that make this run

Neither is obvious, and without either one this example does not build or does
not execute — the book's *assembly-in-Ada* chapter covers both:

1. **The `ee.*` opcodes assemble** only via this repo's S3 **dynconfig overlay**
   (`crates/xtensa-dynconfig`). The stock Alire `xtensa-esp32-elf` assembler does
   not know the PIE instruction set; `XTENSA_GNU_CONFIG` is what teaches it.
2. **`start.S` enables the PIE coprocessor** — `CPENABLE` bit 3, `cop_ai`. The
   opcodes assemble without it and then fault at run time, because the
   coprocessor is disabled out of reset.

## A caveat

These sources are **vendored** from `rowsail/ada-esp32-s3-simd` (itself based on
`zliu43/esp_simd`), renamed into this repo's `ESP32S3` package tree. They are
experimental — see `libs/esp32s3_simd/src/README.md`.

## Build & flash

```sh
./x run esp32s3_simd                 # build + flash + monitor
```

Embedded profile. No wiring — watch the serial console.
