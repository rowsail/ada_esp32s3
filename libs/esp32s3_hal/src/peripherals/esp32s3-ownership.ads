--  The exclusive-ownership guard the peripheral facades share.
--
--  I2C, UART and TWAI each arbitrate "one session owns this host/port/
--  controller at a time", and each had grown its own copy of the same
--  protected object -- Host_Guard, Port_Guard and Guard, identical down to the
--  private Held flag.  One type serves all three: I2C and UART declare an array
--  of it (one per host / port), TWAI a single object, and the shape is the same
--  either way.
--
--  The guarded region is deliberately tiny -- it flips a flag and nothing more.
--  The transaction it protects runs OUTSIDE the protected action, so a slow bus
--  transfer never blocks another task inside the ceiling.  Acquire is an ENTRY,
--  so a second claimant suspends on its barrier rather than spinning or being
--  refused; Release is a procedure, so it cannot block.
--
--  No explicit ceiling is set, exactly as the three copies did not: these are
--  claimed from ordinary task context, never from an interrupt handler.

package ESP32S3.Ownership is

   protected type Guard is
      --  Suspends until the guarded resource is free, then claims it.
      entry Acquire;
      --  Hands it back.  Releasing an unheld Guard is harmless.
      procedure Release;
   private
      Held : Boolean := False;
   end Guard;

end ESP32S3.Ownership;
