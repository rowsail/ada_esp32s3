--  Ada task RENDEZVOUS on the bare-metal dual-core ESP32-S3 -- synchronous
--  task-to-task message passing (entries / `accept` / entry calls with `out`
--  parameters): the full tasking model that lives beyond Jorvik.  Build and run
--  with `./x run rendezvous`; this needs the FULL runtime profile, which the
--  example's build.sh selects (ESP32S3_RTS_PROFILE=full).
--
--  A "rendezvous" is Ada's synchronous message passing: a caller task calls a
--  server task's ENTRY and blocks; the server reaches a matching `accept`; the
--  two then execute the accept body together (the caller stays suspended), the
--  `in` and `out` parameters are exchanged, and both continue.
--
--  What the demo exercises -- each construct here is forbidden under Jorvik,
--  which permits only protected objects, not task entries / accept / select:
--    * A task ENTRY with `in`/`out` parameters (Add/Sub/Stop on Calculator).
--    * The `accept` body running while the caller is blocked in the rendezvous;
--      the `out` parameter is delivered to the caller when the accept completes.
--    * A SELECTIVE ACCEPT (`select ... or accept ... end select`), which waits
--      for whichever of several entries is called next and serves that one.
--    * A parameterless rendezvous (Stop) that lets the server task terminate.
--  A tiny `Calculator` server task offers the three entries; the environment
--  task (the body of `Main` -- itself an Ada task) is the client and calls them.
--
--  Output: the server announces it is ready, then for each entry call the calc
--  side prints the operation and the main side prints the result it got back
--  through the `out` parameter, ending with "[calc] stopped -- terminating" and
--  "[main] done." (see the README for the exact expected transcript).
--
--  Hardware: none (self-contained; logs through the console).
--
--  NOTE: this demo uses the environment task as the client for simplicity, but
--  a DEDICATED client task (two separately declared tasks) works fine too, as
--  does printing to the console from several tasks at once.  Both used to fault
--  ("corrupts memory during activation/handoff" / "console concurrency") -- that
--  was the ESP32-S3 W^X memory-protection feature refusing to execute the GCC
--  nested-function trampoline a frame-capturing client-task body needs.  On the
--  bare boot there is no sdkconfig and the memory-protection (PMS) feature is
--  simply never armed, so that trampoline executes freely; with that,
--  dedicated-client + multi-task console output run cleanly.

with Ada.Text_IO;   use Ada.Text_IO;
with Ada.Real_Time; use Ada.Real_Time;

procedure Main is

   --  The server task and the services it offers as entries.
   task Calculator is
      entry Add (X, Y : Integer; R : out Integer);
      entry Sub (X, Y : Integer; R : out Integer);
      entry Stop;
   end Calculator;

   task body Calculator is
      Open : Boolean := True;
   begin
      Put_Line ("[calc] server ready -- waiting for a rendezvous");
      while Open loop
         --  Selective accept: block until a caller is ready on ANY entry, then
         --  serve that one.  The accept body runs with the caller suspended;
         --  the OUT parameter is delivered when the accept completes.
         select
            accept Add (X, Y : Integer; R : out Integer) do
               R := X + Y;
               Put_Line
                 ("    [calc] Add ("
                  & Integer'Image (X)
                  & ","
                  & Integer'Image (Y)
                  & " ) =>"
                  & Integer'Image (R));
            end Add;
         or
            accept Sub (X, Y : Integer; R : out Integer) do
               R := X - Y;
               Put_Line
                 ("    [calc] Sub ("
                  & Integer'Image (X)
                  & ","
                  & Integer'Image (Y)
                  & " ) =>"
                  & Integer'Image (R));
            end Sub;
         or
            accept Stop do
               Open := False;
            end Stop;
         end select;
      end loop;
      Put_Line ("[calc] stopped -- terminating");
   end Calculator;

   Result : Integer;   --  receives each entry's `out` parameter

begin
   New_Line;
   Put_Line ("=== Ada task rendezvous on ESP32-S3 (full tasking) ===");

   --  Let the server reach its first `accept`, then drive it with entry calls.
   delay until Clock + Milliseconds (100);

   Calculator.Add (10, 5, Result);    --  entry call: blocks until accepted
   Put_Line ("[main] 10 + 5 =" & Integer'Image (Result));

   Calculator.Sub (10, 5, Result);
   Put_Line ("[main] 10 - 5 =" & Integer'Image (Result));

   Calculator.Add (100, 23, Result);
   Put_Line ("[main] 100 + 23 =" & Integer'Image (Result));

   Calculator.Stop;              --  parameterless rendezvous; ends the server
   Put_Line ("[main] done.");

   loop
      delay until Clock + Seconds (3600);
   end loop;
end Main;
