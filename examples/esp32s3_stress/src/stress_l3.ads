--  Test 4: fire a software level-3 interrupt (SW_L3 = CPU_INT 29) at a high
--  rate on core 0, underneath the cross-core ping-pong.  This is the L3 slot
--  the RGB-LCD bounce refill occupies in engmon; a pending L3 fires the
--  instant INTLEVEL permits, so it lands inside the Level2_Dispatch poke
--  path's ceiling-restore Change_Priority.  Before the poke-ceiling fix
--  (raise the ceiling to Interrupt_Priority'Last) it preempted that restore
--  mid-requeue and self-looped core 0's ready queue; with the fix the ceiling
--  masks it across the poke.  The handler's own heartbeat (Beat_L3) proves L3
--  delivery keeps flowing under load; a wedged scheduler freezes it.

package Stress_L3 is

   task L3_Driver with
     Priority => 9, CPU => 1,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

end Stress_L3;
