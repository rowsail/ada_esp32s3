--  Library-level latch for the QMI8658C INT line.
--
--  ESP32S3.GPIO.Interrupts.Enable takes a library-level `access procedure`, and
--  its Callback runs in INTERRUPT context (a level-3 protected action): it must
--  stay short and must not touch the I2C bus.  So the ISR here only sets an
--  Atomic flag; the main task notices it, then does the slow I2C work (reading
--  the samples / status) at task level.
--
--  This board does not wire the QMI8658C INT line (the demo polls instead), so
--  the handler is a no-op in practice -- it exists to exercise the .Interrupts
--  child and to show the idiom for boards that do wire INT.
package IMU_IRQ is

   --  Set by Handler when INT fires; cleared by the main task.
   Fired : Boolean := False with Atomic, Volatile;

   --  The interrupt action handed to ESP32S3.QMI8658C.Interrupts.Attach.
   procedure Handler;

end IMU_IRQ;
