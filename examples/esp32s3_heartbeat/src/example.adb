pragma Warnings (Off);
with Interfaces.C;
with Ada.Real_Time; use Ada.Real_Time;
with Blink;
pragma Unreferenced (Blink);

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
   procedure Log (Marker : Interfaces.C.int);
   pragma Import (C, Log, "ada_log");
   use type Interfaces.C.int;

   --  How often the environment task emits a heartbeat (1 Hz).
   Heartbeat_Period : constant Time_Span := Seconds (1);

   Count : Interfaces.C.int := 0;
   Next  : Time := Clock + Heartbeat_Period;
begin
   loop
      delay until Next;
      Count := Count + 1;
      Log (Count);
      Next := Next + Heartbeat_Period;
   end loop;
end Example;
