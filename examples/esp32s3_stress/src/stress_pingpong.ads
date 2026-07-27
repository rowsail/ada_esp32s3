--  Test 3: cross-core wakeup ping-pong.  Task pairs pinned to opposite
--  cores wake each other as fast as they can: two pairs through
--  suspension objects (the Cross_Wakeup delegation + poke path) and one
--  through a protected entry whose barrier the other core opens (the
--  entry-queue wakeup path).  A lost wakeup leaves both sides suspended
--  and the pair's heartbeats freeze -- which the monitor catches.  The
--  pairs run below the storm's priorities so the storm preempts them
--  constantly.

package Stress_Pingpong is

   task Ping_A1 with
     Priority => 6, CPU => 1,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

   task Ping_B1 with
     Priority => 6, CPU => 2,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

   task Ping_A2 with
     Priority => 7, CPU => 1,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

   task Ping_B2 with
     Priority => 7, CPU => 2,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

   task Entry_A with
     Priority => 8, CPU => 1,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

   task Entry_B with
     Priority => 8, CPU => 2,
     Storage_Size => 4096, Secondary_Stack_Size => 512;

end Stress_Pingpong;
