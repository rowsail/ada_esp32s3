--  What it demonstrates
--  ---------------------
--  Runtime stack high-water-mark measurement (ESP32S3.Stack_Usage): paint the
--  environment-task stack with a sentinel, run a workload that drives the stack to
--  a known depth, then report the peak bytes actually used.  This is the MEASURED
--  companion to the static `./x stack` analysis -- it sees the runtime, the C
--  startup and assembly that the static call-graph pass cannot.
--
--  Build & run:  ./x run stack_usage          (or ./x stack stack_usage --run)
--  Output:       a "stack: env used=.. free=.. total=.. (NN%)" line that jumps
--                once the deep call has run, then holds steady.
--  Hardware:     none (self-contained).
with Ada.Real_Time; use Ada.Real_Time;
with ESP32S3.Stack_Usage;
with ESP32S3.Log;   use ESP32S3.Log;

with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  Each frame carries a chunky local buffer and does a NON-tail recursive call,
   --  so the optimiser cannot collapse it: the stack descends by ~(buffer+frame)
   --  per level, giving a predictable peak we can watch the watermark catch.
   function Burn (Depth : Natural) return Natural is
      --  Volatile so the optimiser cannot prove the loads and fold the array
      --  away: a plain uniform-fill `(others => Depth)` array is trivially
      --  eliminable at -O2 (both reads provably equal Depth), which would drop
      --  the 256 B and defeat the whole point -- the frame must actually cost
      --  ~(buffer+frame) for the watermark to catch it.
      Buf : array (1 .. 64) of Integer := (others => Depth);   --  256 B on-stack
      pragma Volatile (Buf);
   begin
      if Depth = 0 then
         return Buf (1);
      end if;
      return Buf (Depth mod 64 + 1) + Burn (Depth - 1);
   end Burn;

   Sink : Natural := 0;

begin
   --  Give the USB-serial-JTAG console time to re-enumerate after the reset.
   delay 2.0;
   Put_Line ("");
   Put_Line ("=== stack high-water demo ===");

   --  Paint first, as early as possible, so the mark covers everything after.
   ESP32S3.Stack_Usage.Paint_Env_Stack;

   Put ("baseline  ");
   ESP32S3.Stack_Usage.Report;          --  ~ just Main's frame so far

   Sink := Burn (20);                   --  drive ~ 20 * 260 B ~= 5 KiB deeper
   Put ("after Burn(20)  ");
   ESP32S3.Stack_Usage.Report;          --  the mark has jumped

   Put_Line ("done -- reporting every 3 s (peak holds steady):");
   loop
      delay until Clock + Seconds (3);
      --  Touch Sink so the deep call is not optimised away.
      Put ("  Sink=");
      Put (Sink);
      Put ("  ");
      ESP32S3.Stack_Usage.Report;
   end loop;
end Main;
