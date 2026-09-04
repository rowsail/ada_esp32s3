# Modbus TCP slave over the W5500 (ESP32-S3, no FreeRTOS)

A Modbus TCP **slave** on the S3, over the W5500, serving holding registers and
coils that live in **the application's own storage** — `Modbus.Slave` keeps no
register tables of its own.

```
[modbus] ext4-free Modbus TCP slave (holding regs + coils)
[modbus] serving on 192.168.1.74:502
```

The board prints its DHCP address; then from a host on the same LAN:

```sh
python3 examples/esp32s3_modbus_slave/modbus_master.py <board-ip>
```

`holding[r]` is seeded to `1000 + r` and the coils alternate, so the first poll
shows recognisable values, and writes are reflected on read-back.

## Where the registers live

This is the design point worth copying. `Modbus.Slave` owns **no data**. You
derive from the tagged `Modbus.Slave.Server` — here `Slave_Dev` — and your
override reads and writes your own storage. The library does the framing, the
function-code dispatch and the exception responses; it never decides what a
register *is*.

That matters on a device, because a register almost always *is* something else
already: a GPIO, a sensor reading, a setpoint in a control loop. A library that
insisted on holding the array would force you to mirror it, and then keep the
mirror in sync.

`pymodbus` works as a client too, if you have it — the bundled script only needs
the standard library.

## Hardware

A W5500 Ethernet module on SPI2, wired as in `esp32s3_w5500`, on a LAN with a
DHCP server. Embedded profile.

## See also

`esp32s3_modbus_master` is the other half.
