pragma Warnings (Off);
with Ada.Real_Time;   use Ada.Real_Time;
with ESP32S3.Log;     use ESP32S3.Log;
with ESP32S3.UART;
with ESP32S3.UART.Text;
with ESP32S3.Serial;

--  Bring core 1 up so both cores idle in waiti between delays -- this is the
--  full-idle case that the CCOUNT/CCOMPARE2 alarm could not wake.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

--  Delay-accuracy regression test for the SYSTIMER alarm.  The single env task
--  sleeps for a fixed interval, so between delays the whole system is idle
--  (both cores in waiti).  Each line prints the MEASURED elapsed time; with the
--  systimer alarm it must track the target (~1000 / 200 ms), NOT wake ~15-18 s
--  late (the CCOUNT-wrap symptom of the old alarm) or drift.
procedure Main is
   Con    : aliased ESP32S3.UART.Session;
   T0, T1 : Time;
   Targets : constant array (1 .. 4) of Integer := (1000, 200, 1000, 50);
begin
   ESP32S3.UART.Acquire (Con, ESP32S3.UART.UART0);
   ESP32S3.Serial.Set_Output (ESP32S3.UART.Text.As_Device (Con));
   Put_Line ("");
   Put_Line ("[delay-test] SYSTIMER alarm accuracy (idle-then-wake)");

   loop
      for I in Targets'Range loop
         T0 := Clock;
         delay until T0 + Milliseconds (Targets (I));
         T1 := Clock;
         Put ("[delay-test] target=");
         Put (Targets (I));
         Put ("ms  actual=");
         Put (Integer (To_Duration (T1 - T0) * 1000));
         Put_Line ("ms");
      end loop;
   end loop;
end Main;
