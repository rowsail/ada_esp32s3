--  Ada exception demonstration on the bare-metal ESP32-S3 (embedded profile)
--  =========================================================================
--  What it demonstrates
--    The four things that happen to an Ada exception, in order:
--
--    [1] LOCAL handling   -- raised and caught in the SAME block.
--    [2] PROPAGATION      -- raised in a called subprogram, caught by its caller
--                            (needs the embedded/full ZCX unwinder).
--    [3] RE-RAISE         -- a handler cleans up, then `raise;` hands the same
--                            exception to an outer handler.
--    [4] UNHANDLED        -- nobody catches it, so it reaches the LAST-CHANCE
--                            handler.  Our custom handler (see last_chance.adb)
--                            prints the exception and halts; the runtime default
--                            would reset the board.
--
--  Build & run
--    ./x run esp32s3_exceptions
--    Built for the EMBEDDED profile: light-tasking is No_Exception_Propagation,
--    so [2]/[3] could not propagate there -- every raise would go straight to
--    [4]; embedded (and full) add zero-cost (ZCX) exception propagation.
--
--  Output
--    Prints "[1]".."[4]" with the caught exception names/messages, then the
--    last-chance handler's "*** LAST CHANCE HANDLER ... ***" line and halts.
--    The demo body prints with Ada.Text_IO (which the runtime now routes to the
--    USB-serial console); the last-chance handler uses esp_rom_printf directly,
--    since it runs in the fragile state just after an exception escaped
--    everything.
--
--  Hardware
--    None (self-contained); USB-serial console only.
with Ada.Text_IO;    use Ada.Text_IO;
with Ada.Exceptions; use Ada.Exceptions;
with Ada.Real_Time;  use Ada.Real_Time;

--  Force the custom last-chance handler into the link so it overrides the
--  runtime's (which would reset rather than print + halt).
with Last_Chance;
pragma Unreferenced (Last_Chance);

--  Pull the SMP slave-start entry into the link closure (glue.c calls it after
--  elaboration); core 1 just idles -- the demo runs on core 0.
with System.BB.CPU_Primitives.Multiprocessors;
pragma Unreferenced (System.BB.CPU_Primitives.Multiprocessors);

procedure Main is

   --  A user-defined exception (a predefined one is exercised in [1]).
   Sensor_Fault : exception;

   --  A nested subprogram whose CALLER handles the raise -- propagation across a
   --  call (steps [2] and [3]).
   procedure Inner is
   begin
      raise Sensor_Fault with "inner detected a fault";
   end Inner;

begin
   New_Line;
   Put_Line ("=== ESP32-S3 exception demo (embedded profile) ===");

   --  [1] LOCAL: a predefined Constraint_Error (a failed range check) raised and
   --  caught in the same block.
   Put_Line ("[1] local handling:");
   declare
      Zero : Integer := 0
      with Volatile;   --  Volatile -> read (and checked) at
      X    : Positive;                      --  run time, not folded away
   begin
      X := Zero;                            --  0 is not in Positive -> raises
      Put_Line ("    unreachable:" & X'Image);
   exception
      when E : Constraint_Error =>
         Put_Line ("    caught locally: " & Exception_Name (E));
   end;

   --  [2] PROPAGATION: Inner raises, this frame catches it.
   Put_Line ("[2] propagation across a call:");
   begin
      Inner;
      Put_Line ("    unreachable");
   exception
      when E : Sensor_Fault =>
         Put_Line
           ("    caught from Inner: " & Exception_Name (E) & " (" & Exception_Message (E) & ")");
   end;

   --  [3] RE-RAISE: an inner handler does local cleanup, then `raise;` passes
   --  the same exception out to an outer handler.
   Put_Line ("[3] re-raise to an outer handler:");
   begin
      begin
         Inner;
      exception
         when others =>
            Put_Line ("    inner handler: cleaning up, then re-raising");
            raise;                 --  bare raise => re-raise the current one
      end;
   exception
      when E : Sensor_Fault =>
         Put_Line ("    outer handler caught the re-raised " & Exception_Name (E));
   end;

   --  [4] UNHANDLED: no handler -> the last-chance handler (prints + halts).
   Put_Line ("[4] unhandled exception -> last-chance handler:");
   Put_Line ("    raising with NO handler; the last-chance handler runs next...");
   delay until Clock + Milliseconds (50);   --  let the lines flush first
   raise Sensor_Fault with "nobody is going to catch this";
end Main;
