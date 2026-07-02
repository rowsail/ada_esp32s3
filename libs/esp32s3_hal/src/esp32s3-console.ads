--  Reliable console over the ESP32-S3's built-in USB Serial/JTAG controller.
--
--  Why this exists: the ROM printf path (esp_rom_printf) writes the same 64-byte
--  IN FIFO but gives no backpressure -- when output bursts faster than the host
--  USB-CDC stack drains it (~1 ms poll latency), the ROM spins briefly then
--  SILENTLY DROPS the overflow, and it doesn't reliably flush a partial trailing
--  packet.  That is the "truncated console" symptom.  This driver instead:
--
--    * waits (bounded) for the endpoint to be drainable before each packet, so
--      bursts are held rather than dropped (DATA_FREE backpressure);
--    * flushes EVERY packet, including a short final one, with WR_DONE, so the
--      tail of the output is never left sitting in the FIFO;
--    * gives up after a bounded spin when nothing is draining, so a board with
--      no host attached drops output instead of hanging.
--
--  It talks to the USB_SERIAL_JTAG peripheral directly (ESP32S3_Registers.
--  USB_DEVICE), so it does NOT use the secondary stack, the heap, tasking, or
--  exceptions -- safe under the embedded/ZFP profiles, like ESP32S3.Log (which
--  now routes through here).  NOTE: this is fixed to the USB Serial/JTAG console;
--  it does not fall back to a UART the way the ROM printf can.
--
--  Output is LINE-BUFFERED: Write/Put accumulate into a small RAM buffer and are
--  pushed to the host only on a newline, when the buffer fills, or on an explicit
--  Flush.  This coalesces the many small writes that make up one log line into a
--  couple of full USB packets instead of one packet per write.  The cost is that
--  output WITHOUT a trailing newline stays buffered -- call Flush before a long
--  sleep, a risky operation, or in a fault handler to force the tail out.
--
--  No host, no cost: the driver never blocks on a host it has not confirmed is
--  reading (it only backpressures after observing the FIFO actually drain).  So a
--  board running with no USB host attached pays ZERO delay -- console output never
--  slows the application; the bytes are simply dropped.
--
--  Dropped output is OBSERVABLE, not silent: every dropped byte is tallied in a
--  saturating counter (Dropped_Bytes), and the next time the host is draining,
--  Flush prepends an in-band notice -- "[console: <n> bytes dropped]" -- so a gap
--  in the stream is both visible to a reader and queryable by the program.
with Interfaces;

package ESP32S3.Console is

   --  Append a string to the console buffer (flushed on newline / when full).
   --  When a flush happens with no host draining, the data is dropped (counted in
   --  Dropped_Bytes) rather than blocking.
   procedure Write (S : String);

   --  Append a single character (flushes if it is a newline / fills the buffer).
   procedure Put (C : Character);

   --  Push any buffered bytes to the host now, as 64-byte USB packets.
   procedure Flush;

   --  Non-blocking single-character INPUT from the USB Serial/JTAG OUT (host->
   --  device) FIFO.  Available is True and C holds the byte when one was waiting
   --  (reading pops exactly one byte from the RX FIFO); Available is False and C
   --  is NUL when nothing is ready.  Never blocks and never waits on a host, so a
   --  board with no host attached simply reports "nothing ready".  Callers that
   --  want blocking input spin on this (that is what ESP32S3.Text_IO does).
   procedure Read (C : out Character; Available : out Boolean);

   --  Total bytes dropped so far because no host was draining (saturating).  0
   --  means every byte handed to the console was delivered.
   function Dropped_Bytes return Interfaces.Unsigned_32;

   --  Reset the dropped-byte counter (e.g. after reporting it).
   procedure Clear_Dropped;

   --  Optional active notification: register a handler called whenever bytes are
   --  dropped, with Count = the number dropped in that event.  It runs
   --  synchronously from the dropping Flush, so keep it short, non-blocking, and
   --  do NOT raise.  It MAY call back into the console (e.g. to Write a note or
   --  set a pin) -- re-entrant drops will not re-fire the handler.  Pass null to
   --  disable.  Default is no handler, so the console stays side-effect-free and
   --  ZFP-safe unless you opt in.  The handler must be a LIBRARY-LEVEL procedure
   --  (No_Implicit_Dynamic_Code bars 'Access of a nested one -- no trampolines).
   type Drop_Handler is access procedure (Count : Natural);
   procedure On_Drop (Handler : Drop_Handler);

end ESP32S3.Console;
