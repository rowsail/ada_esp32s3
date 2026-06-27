--  What it demonstrates
--  ---------------------
--  A Modbus TCP *slave* on the ESP32-S3 over the W5500: it serves holding
--  registers and coils that live in the application's own storage (Slave_Dev) --
--  the Modbus.Slave library keeps no register tables.  A desktop Modbus master
--  (pymodbus, or the bundled modbus_master.py) can poll and write them.
--
--  Build & run
--  -----------
--    ./x run esp32s3_modbus_slave
--  The board prints its DHCP IP; then from a host on the same LAN:
--    python3 examples/esp32s3_modbus_slave/modbus_master.py <board-ip>
--  Holding[r] is seeded to 1000+r and coils alternate, so the first poll shows
--  recognisable values; writes are reflected on read-back.
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.W5500.DHCP;
with Modbus;
with Modbus.Slave;
with W5500_Dev;
with Slave_Dev;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   Lease : ESP32S3.W5500.DHCP.Lease_Info;
   Park  : constant Time_Span := Seconds (3600);
   Dev   : Slave_Dev.Device;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[modbus] ext4-free Modbus TCP slave (holding regs + coils)");

   if not W5500_Dev.Bring_Up (Lease => Lease) then
      Put_Line ("[modbus] network bring-up failed -- stopping");
      loop
         delay until Clock + Park;
      end loop;
   end if;

   Dev.Seed;
   Put_Line ("[modbus] serving on " & W5500_Dev.Image (Lease.IP)
             & ":502  (unit 1; holding 0..63 = 1000+r, coils alternate)");

   --  Serves one client at a time, forever.
   Modbus.Slave.Run (Dev, Port => Modbus.Default_Port);
end Main;
