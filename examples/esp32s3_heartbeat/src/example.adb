with Ada.Real_Time; use Ada.Real_Time;
with Blink;
pragma Unreferenced (Blink);
with ESP32S3.Log;   --  buffered console (was the ada_log esp_rom_printf glue)

--  What it demonstrates: the minimal periodic heartbeat.  Built against the
--  pinned esp32s3_rts crate, the environment task logs a 1 Hz heartbeat counter
--  while package Blink runs a separate 100 ms library-level task.  Both keep
--  time with `delay until` (the native CCOMPARE2 tick), so a steady heartbeat on
--  the console confirms the crate runtime boots and the scheduler runs on
--  hardware.
--
--  Build & run: `./x run esp32s3_heartbeat` (default light-tasking profile).
--
--  Output: once per second the console prints "[example] heartbeat <n>" with an
--  incrementing count, e.g. "[example] heartbeat 1", "[example] heartbeat 2",
--  ...  A steadily advancing count is the pass condition.
--
--  Hardware / wiring: none (self-contained); output is over the
--  USB-Serial-JTAG console.

procedure Example is
   --  How often the environment task emits a heartbeat (1 Hz).
   Heartbeat_Period : constant Time_Span := Seconds (1);

   Count : Natural := 0;
   Next  : Time := Clock + Heartbeat_Period;
begin
   loop
      delay until Next;
      Count := Count + 1;
      ESP32S3.Log.Put ("[example] heartbeat ");
      ESP32S3.Log.Put (Count);
      ESP32S3.Log.New_Line;
      Next := Next + Heartbeat_Period;
   end loop;
end Example;
