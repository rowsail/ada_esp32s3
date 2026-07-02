--  Dual-core SMP cross-core mailbox on the bare-metal ESP32-S3 (no FreeRTOS).
--  =========================================================================
--  What it demonstrates: a Producer task pinned to core 1 posts an incrementing
--  value to a mailbox every 500 ms and opens a protected-object entry barrier; a
--  Consumer task pinned to core 0 blocks in `entry Get when Full` until served,
--  so each value flows core 1 --> core 0 via the GNARL served-entry list plus an
--  inter-core poke.  The cross-core boot/takeover, CCOUNT sync and slave-scheduler
--  mechanics are involved; see README.md.  The work lives in package Comm.
--
--  Build & run:  ./x run smp   (no ESP-IDF; bare-boot dual-core image)
--
--  Output:       one line per transfer, e.g.
--                  value  1:  producer core 1  -->  consumer core 0
--                  value  2:  producer core 1  -->  consumer core 0
--                plus a per-period [rate] line confirming the entry truly blocks.
--
--  Hardware:     none (self-contained).
pragma Warnings (Off);
with Ada.Real_Time; use Ada.Real_Time;
with Comm;
pragma Unreferenced (Comm);

--  Pull the SMP slave-start wrapper (__gnat_start_slave_cpus, called from
--  glue.c after elaboration) into the link closure.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

--  The environment task just idles; the cross-core Producer/Consumer (package
--  Comm) do the work on cores 1 and 0.

procedure Main is
begin
   loop
      delay until Clock + Seconds (5);
   end loop;
end Main;
