--  Full Ada tasking on the bare-metal ESP32-S3 -- the constructs the Jorvik
--  runtime profile forbids, here running over the BB kernel on core 0.  Build
--  and run with `./x run full_tasking`; this needs the FULL runtime profile,
--  which the example's build.sh selects (ESP32S3_RTS_PROFILE=full).
--
--  Two features are exercised.  (The "(M4)"/"(M5)" tags in the banner are this
--  project's tasking-roadmap milestone numbers -- M4 = dynamic tasks, M5 =
--  abort; they show up in the console banner only.)
--
--    * Dynamic task allocation with a task master.  `new Worker` allocates a
--      task object -- a "task allocator", forbidden by Jorvik.  The enclosing
--      block is the workers' master: leaving it blocks until both workers have
--      terminated, then reclaims their task control blocks.
--    * Asynchronous abort.  The periodic Heartbeat task never ends on its own;
--      the environment task aborts it, and its 'Terminated attribute flips
--      False -> True once it stops.
--
--  Each worker also reports whether its own stack is in external PSRAM.  That
--  depends only on where the Ada heap lives: with no __gnat_task_stack_alloc
--  hook (this example defines none) every task stack is carved from the heap.
--  The heap is internal DRAM by default, so the "stack is in PSRAM" line does
--  NOT print; rebuild with HEAP_PSRAM=1 to move the heap -- and with it the task
--  stacks -- into PSRAM, and it will.

with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Real_Time;           use Ada.Real_Time;
with System;
with System.Storage_Elements; use System.Storage_Elements;

procedure Main is

   --  The S3 maps external (octal) PSRAM into this data-bus address window; an
   --  address inside it is backed by PSRAM, anything else (e.g. the 0x3FC0_0000
   --  internal SRAM) is on-chip RAM.
   PSRAM_Window_Lo : constant Integer_Address := 16#3C00_0000#;
   PSRAM_Window_Hi : constant Integer_Address := 16#3E00_0000#;

   --  A task's local variable lives on that task's stack, so the address of one
   --  tells us where the stack was allocated.
   function In_PSRAM (A : System.Address) return Boolean is
      V : constant Integer_Address := To_Integer (A);
   begin
      return V >= PSRAM_Window_Lo and then V < PSRAM_Window_Hi;
   end In_PSRAM;

   --  A dynamically allocated worker task.  Id distinguishes the two instances.
   task type Worker (Id : Integer);
   task body Worker is
      Stack_Probe : Integer := Id;   --  a stack local; its address == this stack
   begin
      if In_PSRAM (Stack_Probe'Address) then
         Put_Line ("    [worker" & Integer'Image (Id) & " ] stack is in PSRAM");
      end if;
      for K in 1 .. 3 loop
         Put_Line ("    [worker" & Integer'Image (Id) & " ]" & Integer'Image (K));
         delay until Clock + Milliseconds (150);
      end loop;
      Put_Line ("    [worker" & Integer'Image (Id) & " ] terminating");
   end Worker;

   --  A periodic task with no natural end -- the environment task aborts it.
   task Heartbeat;
   task body Heartbeat is
   begin
      loop
         Put_Line ("    [heartbeat] beat");
         delay until Clock + Milliseconds (120);
      end loop;
   end Heartbeat;

begin
   New_Line;
   Put_Line ("=== full Ada tasking: dynamic tasks (M4) + abort (M5) ===");

   --  Allocate two workers inside a block.  The block is their master: leaving
   --  it blocks until both have terminated, then frees their task objects.
   declare
      type Worker_Ptr is access Worker;
      W1, W2 : Worker_Ptr;
   begin
      W1 := new Worker (1);
      W2 := new Worker (2);
      Put_Line ("[main] 2 dynamic tasks allocated; block awaits them");
   end;
   Put_Line ("[main] block exited -> both dynamic tasks terminated + freed");

   --  Abort the periodic task and watch 'Terminated change across the abort.
   Put_Line ("[main] Heartbeat'Terminated before abort = " & Boolean'Image (Heartbeat'Terminated));
   abort Heartbeat;
   delay until Clock + Milliseconds (300);
   Put_Line ("[main] Heartbeat'Terminated after  abort = " & Boolean'Image (Heartbeat'Terminated));
   Put_Line ("[main] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
