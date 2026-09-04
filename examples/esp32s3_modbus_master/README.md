# Modbus TCP master over the W5500 (ESP32-S3, no FreeRTOS)

A Modbus TCP **master** on the S3, over the W5500. It connects to a slave on the
LAN, reads holding registers and writes one back, reporting the `Status` of each
operation.

```
[modbus] Modbus TCP master (pinned to the W5500)
[modbus] connect to 192.168.1.10:1502
[modbus] connected to 192.168.1.10:1502
[modbus] holding 0..4 = 1000 1001 1002 1003 1004
[modbus] wrote 4242 -> read back 4242
[modbus] done.
```

The bundled slave seeds `holding[r] = 1000 + r`, so a working run prints
**1000..1004**. Every failure path names the `Status` that came back —
`read failed (status=...)`, `write holding[0]=4242 failed (status=...)`,
`read-back failed (status=...)` — because that enum is the library's whole error
vocabulary: `Modbus.Master` returns a status, it does not raise.

## Interface pinning

The connection is **pinned to the W5500** through a `Configure` hook
(`Net_Pin`). On a multi-NIC board — say Ethernet plus cellular — that confines
this traffic to the chosen link rather than letting the routing table pick.

The hook is closure-free and library-level by necessity: the runtime forbids
implicit dynamic code, so a nested callback that captured its environment would
need a stack trampoline and be rejected at compile time. It also keeps
`Modbus.Master` itself facade-only, which is what lets the same source run under
the `modbus_master_host` native test suite.

## Running it

On a host on the same LAN, start the bundled stdlib slave (it binds all
interfaces):

```sh
python3 libs/esp32s3_hal/test/modbus_master_host/modbus_slave.py 1502
```

Point `Slave_Host` in `src/main.adb` at that host, then:

```sh
./x run esp32s3_modbus_master        # build + flash + monitor
```

## Hardware

A W5500 Ethernet module on SPI2, wired as in `esp32s3_w5500`. Embedded profile.

## See also

`esp32s3_modbus_slave` is the other half — run both and point them at each other.
