with Ada.Real_Time;

--  A tiny, profile-agnostic timeout helper: poll a condition until it holds or a
--  deadline passes.  It uses only Ada.Real_Time (delay until) and an
--  access-to-function, so it is lock-free and builds under EVERY profile
--  (light-tasking, embedded, full) -- handy for the common "wait for the hardware,
--  but give up after a while" pattern without hand-rolling a deadline loop.
--
--  For a long or power-sensitive wait, prefer blocking on an interrupt
--  (a Suspension_Object or a protected entry) over polling; see the book's
--  "Waiting for an event" section.

package ESP32S3.Wait is

   --  Call Ready repeatedly until it returns True or Timeout elapses; return
   --  True if the condition became true, False on timeout.  Between checks it
   --  waits Poll (default 1 ms) with `delay until`, so other tasks run.
   function Until_True
     (Ready   : access function return Boolean;
      Timeout : Ada.Real_Time.Time_Span;
      Poll    : Ada.Real_Time.Time_Span := Ada.Real_Time.Milliseconds (1)) return Boolean;

end ESP32S3.Wait;
