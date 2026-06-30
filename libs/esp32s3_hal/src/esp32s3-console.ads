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
package ESP32S3.Console is

   --  Append a string to the console buffer (flushed on newline / when full).
   --  When a flush happens with no host draining, the data is dropped after a
   --  bounded wait rather than blocking forever.
   procedure Write (S : String);

   --  Append a single character (flushes if it is a newline / fills the buffer).
   procedure Put (C : Character);

   --  Push any buffered bytes to the host now, as 64-byte USB packets.
   procedure Flush;

end ESP32S3.Console;
