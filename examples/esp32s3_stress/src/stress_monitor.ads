--  The on-board stall detector: snapshots every heartbeat each period and
--  records the first slot that stopped advancing (Stress_State.Stalled,
--  sticky).  Runs above every stressed task so a wedged subject cannot
--  starve it; if the monitor's own Round counter freezes, the SYSTEM froze
--  (tick or scheduler dead) -- check.sh treats that as failure too.

package Stress_Monitor is

   task Monitor with
     Priority => 20, CPU => 1,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

end Stress_Monitor;
