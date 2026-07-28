--  Shared, JTAG-readable state: every stress task owns one heartbeat slot
--  and increments it each iteration; the monitor task (stress_monitor.adb)
--  and the host-side check.sh watch the slots for stalls.

with Interfaces;

package Stress_State is

   --  Heartbeat slot assignments (fixed, so check.sh can name a stalled
   --  task from its slot index alone)

   Beat_Env       : constant := 1;
   Beat_Monitor   : constant := 2;
   Beat_Storm_1   : constant := 3;    --  core 0, priority 12
   Beat_Storm_2   : constant := 4;    --  core 0, priority 12 (FIFO peer)
   Beat_Storm_3   : constant := 5;    --  core 0, priority 13
   Beat_Storm_4   : constant := 6;    --  core 1, priority 12
   Beat_Ping_A1   : constant := 7;    --  SO pair 1, core 0
   Beat_Ping_B1   : constant := 8;    --  SO pair 1, core 1
   Beat_Ping_A2   : constant := 9;    --  SO pair 2, core 0
   Beat_Ping_B2   : constant := 10;   --  SO pair 2, core 1
   Beat_Entry_A   : constant := 11;   --  entry pair, core 0
   Beat_Entry_B   : constant := 12;   --  entry pair, core 1
   Beat_L3        : constant := 13;   --  SW-L3 (int 29) handler, core 0

   Beat_Count : constant := 13;

   type Beat_Array is array (1 .. Beat_Count) of Interfaces.Unsigned_32
     with Atomic_Components;

   Beats : Beat_Array := (others => 0)
     with Export, External_Name => "__stress_beats";

   Seed : Interfaces.Unsigned_32 := 0
     with Atomic, Export, External_Name => "__stress_seed";
   --  The boot-time CCOUNT that seeded every task's PRNG stream: record it
   --  from check.sh so a failing run can be reproduced.

   Round : Interfaces.Unsigned_32 := 0
     with Atomic, Export, External_Name => "__stress_round";
   --  Monitor sweep counter: advances every monitor period even after a
   --  stall has been recorded (a frozen Round means the SYSTEM froze).

   Stalled : Interfaces.Unsigned_32 := 0
     with Atomic, Export, External_Name => "__stress_stalled";
   --  0 = healthy; else the slot index of the first task whose heartbeat
   --  stopped advancing between two monitor sweeps (sticky).

end Stress_State;
