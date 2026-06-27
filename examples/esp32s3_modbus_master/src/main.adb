--  What it demonstrates
--  ---------------------
--  A Modbus TCP *master* on the ESP32-S3 over the W5500: it connects to a slave on
--  the LAN, reads holding registers and writes one back, reporting each Status.
--  The connection is PINNED to the W5500 interface via a Configure hook (Net_Pin) --
--  on a multi-NIC board this confines the traffic to a chosen link.
--
--  Build & run
--  -----------
--  On a host on the same LAN, start the bundled stdlib slave (binds all interfaces):
--    python3 libs/esp32s3_hal/test/modbus_master_host/modbus_slave.py 1502
--  then point Slave_Host below at that host and:
--    ./x run esp32s3_modbus_master
--  The slave seeds holding[r] = 1000+r, so the board should print 1000..1004.
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Log;   use ESP32S3.Log;
with ESP32S3.W5500.DHCP;
with Modbus;        use Modbus;
with Modbus.Master;
with W5500_Dev;
with Net_Pin;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is
   package MM renames Modbus.Master;
   use type MM.Status;

   --  The LAN Modbus slave to poll (the dev host running modbus_slave.py).
   Slave_Host : constant String := "192.168.1.100";
   Slave_Port : constant := 1502;

   Lease : ESP32S3.W5500.DHCP.Lease_Info;
   Park  : constant Time_Span := Seconds (3600);

   S   : MM.Session;
   R   : MM.Status;
   Exc : Exception_Code;

   function Img (N : Integer) return String is
      Str : constant String := Integer'Image (N);
   begin
      return (if N < 0 then Str else Str (Str'First + 1 .. Str'Last));
   end Img;
begin
   delay until Clock + Milliseconds (200);
   Put_Line ("[modbus] Modbus TCP master (pinned to the W5500)");

   if not W5500_Dev.Bring_Up (Lease => Lease) then
      Put_Line ("[modbus] network bring-up failed -- stopping");
      loop
         delay until Clock + Park;
      end loop;
   end if;

   MM.Connect (S, Slave_Host, Port => Slave_Port,
               Configure => Net_Pin.Pin_Eth0'Access, Result => R);
   if R /= MM.OK then
      Put_Line ("[modbus] connect to " & Slave_Host & " failed");
      loop
         delay until Clock + Park;
      end loop;
   end if;
   Put_Line ("[modbus] connected to " & Slave_Host & ":" & Img (Slave_Port));

   --  Read holding 0..4.
   declare
      W : Word_Array (0 .. 4);
   begin
      MM.Read_Holding_Registers (S, Unit => 1, Addr => 0, Qty => 5,
                                 Into => W, Result => R, Exc => Exc);
      if R = MM.OK then
         Put ("[modbus] holding 0..4 =");
         for V of W loop
            Put (" " & Img (Integer (V)));
         end loop;
         New_Line;
      else
         Put_Line ("[modbus] read failed (status="
                   & MM.Status'Image (R) & ")");
      end if;
   end;

   --  Write holding[0] = 4242, read it back.
   MM.Write_Single_Register (S, 1, 0, 4242, R, Exc);
   declare
      W : Word_Array (0 .. 0);
   begin
      MM.Read_Holding_Registers (S, 1, 0, 1, W, R, Exc);
      if R = MM.OK then
         Put_Line ("[modbus] wrote 4242 -> read back " & Img (Integer (W (0))));
      end if;
   end;

   MM.Close (S);
   Put_Line ("[modbus] done.");
   loop
      delay until Clock + Park;
   end loop;
end Main;
