with ESP32S3.GPIO.Interrupts;

--  The TCA9555 INT line, on the GPIO the device was Setup with.
--
--  INT is active-low and open-drain: it idles high (via a pull-up) and the chip
--  pulls it low when an input pin changes, holding it low until the input
--  register is read.  So the pin is configured as an input with the internal
--  pull-up on, triggering on the FALLING edge.
--
--  These act on the INT pin stored in the Device by Setup -- pass No_Pin there
--  (this board: INT not connected) and Attach / Detach are no-ops.  UNTESTED on
--  this board, since the INT line is not wired.
--
--  The Action runs in interrupt context (see ESP32S3.GPIO.Interrupts): keep it
--  short -- set a Suspension_Object or bump an Atomic flag, then read the inputs
--  (which also clears INT) in a normal task.
package ESP32S3.TCA9555.Interrupts is

   subtype Callback is ESP32S3.GPIO.Interrupts.Callback;

   --  Configure Dev's INT pin as a pulled-up input and deliver a falling-edge
   --  interrupt to Action.  No-op if Dev was set up with No_Pin.
   procedure Attach (Dev : Device; Action : Callback);

   --  Stop delivering Dev's INT interrupt.  No-op if Dev has no INT pin.
   procedure Detach (Dev : Device);

end ESP32S3.TCA9555.Interrupts;
