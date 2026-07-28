--  RTS stress suite: a randomized tiny-delay storm (stress_storm) plus
--  cross-core wakeup ping-pong pairs (stress_pingpong), watched by an
--  on-board stall monitor (stress_monitor).  Heartbeats, the PRNG seed
--  and the verdict are exported RAM words -- run check.sh to drive a
--  soak over JTAG.  The environment task is just another heartbeat.

with Ada.Real_Time; use Ada.Real_Time;
with Interfaces;    use Interfaces;
with Stress_State;
with Stress_Storm;
with Stress_Pingpong;
with Stress_L3;
with Stress_Monitor;
pragma Unreferenced (Stress_Storm, Stress_Pingpong, Stress_L3, Stress_Monitor);

procedure Main is
begin
   loop
      delay until Clock + Milliseconds (500);
      Stress_State.Beats (Stress_State.Beat_Env) :=
        Stress_State.Beats (Stress_State.Beat_Env) + 1;
   end loop;
end Main;
