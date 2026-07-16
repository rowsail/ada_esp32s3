pragma Warnings (Off);
with Ada.Real_Time; use Ada.Real_Time;
with Big;

--  PSRAM d-bus mapping (bare_board_init) + freestanding abort, in Ada -- pull it
--  into the link closure (was psram/glue.c).
with Psram_Board;
pragma Unreferenced (Psram_Board);

--  Pull the SMP slave-start entry (__gnat_start_slave_cpus) into the link closure
--  so the shared bare boot brings up core 1.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

--  What it demonstrates: maps and exercises the module's external octal PSRAM
--  from bare Ada by filling and verifying a 1 MB static byte array placed in
--  external RAM (package Big), then idles.  See big.adb for how the array is
--  placed in the external-RAM bss section and this example's README for the
--  configuration.
--
--  Build & run: `./x run esp32s3_psram` (light-tasking profile, the default; no
--  heap -- the array is a static .ext_ram.bss array, not a malloc).
--
--  Output: glue.c prints the buffer's address (0x3d000000, the external-RAM data
--  range), its size, and a checksum that matches the expected value, proving the
--  full 1 MB round-trips through the cache to real PSRAM.  Then the environment
--  task idles.
--
--  Hardware: needs the in-package octal PSRAM (8 MB on the S3 module).  The
--  octal-PSRAM bring-up runs in our 2nd-stage bootloader, not the app.

procedure Main is

   --  Once Big.Run has reported its result there is nothing left to do, so the
   --  environment task just idles.  It must not return (that would tear the app
   --  down), so it sleeps in a loop; the period is arbitrarily long because
   --  nothing is waiting on it -- one hour keeps the wakeups rare.
   Idle_Period : constant Time_Span := Seconds (3600);

begin
   --  Fill, read back, and checksum the 1 MB PSRAM array, then report it.
   Big.Run;

   loop
      delay until Clock + Idle_Period;
   end loop;
end Main;
