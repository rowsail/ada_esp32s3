with System;
with System.Storage_Elements;

--  Runtime stack high-water-mark measurement by "stack painting": fill the unused
--  part of a stack with a sentinel word, run the workload, then scan for the lowest
--  word the program actually overwrote.  The gap between that and the top is the
--  peak depth ever reached -- the MEASURED counterpart to the static `x stack`
--  worst-case analysis, and the only way to account for the prebuilt runtime, the
--  C startup, ISRs, and hand-written assembly that the static pass cannot see.
--
--  Caveat: a sentinel-valued word that the program legitimately wrote looks
--  pristine, so the scan stops at the FIRST overwritten word from the bottom and
--  thus never UNDER-reports the peak (it can only be conservative).  Use a real
--  workload, then read the figure as "at least this much was used."

package ESP32S3.Stack_Usage is

   --  Paint the unused portion of the ENVIRONMENT task's stack (the one Main runs
   --  on, bounded by the linker symbols __stack_start/__stack_end).  Call ONCE, as
   --  early as possible in Main, so the high-water mark covers the whole run.  It
   --  paints everything below the caller's frame, so anything already on the stack
   --  (the call chain into Main) is left intact.
   procedure Paint_Env_Stack;

   --  Peak bytes of the env stack ever used since Paint_Env_Stack (the high-water
   --  mark), the bytes still pristine, and the total reserved size.
   function Env_Used return Natural;
   function Env_Free return Natural;
   function Env_Total return Natural;

   --  Print a one-line report via ESP32S3.Log, e.g.
   --    stack: env used=2048 free=14336 total=16384 (12%)
   --  The line contains the marker "stack:" so `./x stack --run` can capture it.
   procedure Report;

   --  A stack region.  Low is its lowest address, High one-past-the-top;
   --  stacks grow down from High towards Low.
   --
   --  ONE VALUE rather than two parameters, and deliberately so.  These used
   --  to be (Low, High : System.Address) -- adjacent, same type, so a
   --  positional call could transpose them with nothing to notice: not a
   --  compile error, not obvious at a glance, and Paint would then walk from
   --  High downward past Low, straight out of the region and over whatever
   --  lies beneath it.  A named aggregate cannot be transposed without the
   --  transposition being visible on the page.
   --
   --  The predicate catches a region built backwards.  Note it is a runtime
   --  check, so it only bites where assertions are enabled -- the record
   --  itself is what does the work in a release build.
   type Region is record
      Low  : System.Address;
      High : System.Address;
   end record
     with Dynamic_Predicate =>
       System.Storage_Elements."<="
         (System.Storage_Elements.To_Integer (Region.Low),
          System.Storage_Elements.To_Integer (Region.High));

   --  Primitives for ANY stack region (e.g. a library-level task measuring its
   --  own stack).  In the task, first thing: Paint (its own region); after the
   --  workload: High_Water (the same region) for the peak bytes used.
   procedure Paint (Within : Region);
   function High_Water (Within : Region) return Natural;

end ESP32S3.Stack_Usage;
