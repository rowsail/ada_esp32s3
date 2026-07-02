with ESP32S3.GPIO.Interrupts;

--  The PCF85063A INT line, on the GPIO the device was Setup with.
--
--  INT is active-low and open-drain: it idles high (via a pull-up) and the chip
--  pulls it low when the alarm fires (with the alarm interrupt enabled), holding
--  it low until the alarm flag is cleared (PCF85063A.Acknowledge_Alarm).  So the
--  pin is configured as an input with the internal pull-up on, triggering on the
--  FALLING edge.
--
--  These act on the INT pin stored in the Device by Setup -- pass No_Pin there
--  (a part with no INT connection) and Attach / Detach are no-ops.
--
--  The Action runs in interrupt context (see ESP32S3.GPIO.Interrupts): keep it
--  short -- set a Suspension_Object or bump an Atomic flag, then do the I2C work
--  (reading status, acknowledging the alarm) in a normal task.

package ESP32S3.PCF85063A.Interrupts is

   --  The per-pin handler type (see ESP32S3.GPIO.Interrupts).
   subtype Callback is ESP32S3.GPIO.Interrupts.Callback;

   --  Configure Dev's INT pin as a pulled-up input and deliver a falling-edge
   --  interrupt to Action whenever INT asserts.  No-op if Dev was set up with
   --  No_Pin.  Routes the GPIO source to the runtime's level-3 device slot on
   --  first use (done by ESP32S3.GPIO.Interrupts).
   procedure Attach (Dev : Device; Action : Callback);

   --  Stop delivering Dev's INT interrupt.  No-op if Dev has no INT pin.
   procedure Detach (Dev : Device);

end ESP32S3.PCF85063A.Interrupts;
