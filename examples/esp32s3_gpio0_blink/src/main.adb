pragma Warnings (Off);
with Ada.Real_Time; use Ada.Real_Time;

--  The GPIO0 blink driver + its task live in package GPIO; withing it pulls the
--  task into the program so it elaborates and runs.
with GPIO;
pragma Unreferenced (GPIO);

--  Pull the SMP slave-start entry (__gnat_start_slave_cpus, called from glue.c
--  after elaboration) into the link closure so core 1 is brought up (it idles
--  here -- the blink task runs on core 0).
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

--  GPIO0 blink demo: the environment task idles; package GPIO drives the pin.

procedure Main is
begin
   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
