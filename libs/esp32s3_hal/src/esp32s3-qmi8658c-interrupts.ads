with ESP32S3.GPIO.Interrupts;

--  The QMI8658C INT line (INT1 / INT2), on the GPIO the device was Setup with.
--
--  The QMI8658C drives INT as a push-pull, active-high data-ready / event line by
--  default, so the pin is configured as an input with a pull-down (idles low) and
--  triggers on the RISING edge.  (The on-chip polarity and which event drives the
--  pin are programmable; adjust this child if you change them.)
--
--  These act on the INT pin stored in the Device by Setup -- pass No_Pin there
--  (no INT connection) and Attach / Detach are no-ops.
--
--  The Action runs in interrupt context (see ESP32S3.GPIO.Interrupts): keep it
--  short -- set a Suspension_Object or bump an Atomic flag, then do the I2C work
--  (reading the samples / status) in a normal task.
package ESP32S3.QMI8658C.Interrupts is

   --  The per-pin handler type (see ESP32S3.GPIO.Interrupts).
   subtype Callback is ESP32S3.GPIO.Interrupts.Callback;

   --  Configure Dev's INT pin as a pulled-down input and deliver a rising-edge
   --  interrupt to Action whenever INT asserts.  No-op if Dev was set up with
   --  No_Pin.  Routes the GPIO source to the runtime's level-3 device slot on
   --  first use (done by ESP32S3.GPIO.Interrupts).
   procedure Attach (Dev : Device; Action : Callback);

   --  Stop delivering Dev's INT interrupt.  No-op if Dev has no INT pin.
   procedure Detach (Dev : Device);

end ESP32S3.QMI8658C.Interrupts;
