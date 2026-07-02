--  Library-level latch for the PCF85063A INT line (whatever GPIO Rtc_Int in
--  Main names; No_Pin on this board, so this stays idle).
--
--  ESP32S3.GPIO.Interrupts.Enable takes a library-level `access procedure`, and
--  its Callback runs in INTERRUPT context (a level-3 protected action): it must
--  stay short and must not touch the I2C bus.  So the ISR here only sets an
--  Atomic flag; the main task notices it, then does the slow I2C work (reading
--  status, acknowledging the alarm) at task level.

package Alarm_IRQ is

   --  Set by Handler when the INT line falls; cleared by the main task.
   Fired : Boolean := False
   with Atomic, Volatile;

   --  The interrupt action handed to ESP32S3.PCF85063A.Interrupts.Attach.
   procedure Handler;

end Alarm_IRQ;
