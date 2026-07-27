with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;    use Interfaces;
with Stress_State;  use Stress_State;

package body Stress_Monitor is

   Period : constant Time_Span := Milliseconds (2000);
   --  Longer than the slowest legitimate beat interval (env: 500 ms).
   --  A watch-filtered diagnostic ring needs no tighter latency: a wedged
   --  thread generates no further events, so its tail is preserved.

   task body Monitor is
      Previous : Beat_Array := (others => 0);
      Next_At  : Time := Clock + Period;
      Warmup   : Boolean := True;
   begin
      loop
         delay until Next_At;
         Next_At := Next_At + Period;

         --  First sweep only refreshes the baseline: during it the tasks
         --  are still activating and a not-yet-started task would latch a
         --  false stall.

         if Warmup then
            Warmup := False;
            Previous := Beats;
            Beats (Beat_Monitor) := Beats (Beat_Monitor) + 1;
            Round := Round + 1;
            goto Next_Sweep;
         end if;

         for Slot in Beats'Range loop
            if Slot /= Beat_Monitor
              and then Beats (Slot) = Previous (Slot)
              and then Stalled = 0
            then
               Stalled := Unsigned_32 (Slot);
            end if;
            Previous (Slot) := Beats (Slot);
         end loop;

         Beats (Beat_Monitor) := Beats (Beat_Monitor) + 1;
         Round := Round + 1;

         <<Next_Sweep>>
      end loop;
   end Monitor;

end Stress_Monitor;
