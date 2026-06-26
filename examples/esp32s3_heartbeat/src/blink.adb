pragma Warnings (Off);
with Ada.Real_Time; use Ada.Real_Time;

package body Blink is

   --  A second, faster periodic task (10 Hz) running alongside the env task's
   --  1 Hz heartbeat -- proves the scheduler juggles two independent periods.
   --  It does no I/O; the env task's heartbeat count is the only console signal.
   Tick_Period : constant Time_Span := Milliseconds (100);

   task Periodic;
   task body Periodic is
      Next : Time := Clock + Tick_Period;
   begin
      loop
         delay until Next;
         Next := Next + Tick_Period;
      end loop;
   end Periodic;

end Blink;
