with ESP32S3.GPIO.Interrupts;

--  The GT911 INT line, on the GPIO the device was Setup with.
--
--  During normal operation the chip drives INT push-pull and pulses it once
--  per fresh coordinate report, so the pin is configured as a plain floating
--  input (never driven from this side -- INT doubles as the address strap at
--  reset, see the parent's RESET / ADDRESS note).  WHICH edge signals a report
--  is a module configuration choice (config register 0x804D bits 1:0); most
--  modules, the Waveshare 7-inch panel included, ship rising-edge, the default
--  here -- pass Falling_Edge if yours is strapped the other way.
--
--  These act on the INT pin stored in the Device by Setup -- pass No_Pin there
--  (no INT connection) and Attach / Detach are no-ops.
--
--  The Action runs in interrupt context (see ESP32S3.GPIO.Interrupts): keep it
--  short -- set a Suspension_Object or bump an Atomic flag, then do the I2C
--  work (Read_Touches) in a normal task.

package ESP32S3.GT911.Interrupts is

   --  The per-pin handler type (see ESP32S3.GPIO.Interrupts).
   subtype Callback is ESP32S3.GPIO.Interrupts.Callback;

   --  The pin trigger choices (see ESP32S3.GPIO.Interrupts).
   subtype Trigger is ESP32S3.GPIO.Interrupts.Trigger;

   --  Configure Dev's INT pin as a floating input and deliver an interrupt to
   --  Action on every report pulse.  No-op if Dev was set up with No_Pin.
   --  Routes the GPIO source to the runtime's level-3 device slot on first use
   --  (done by ESP32S3.GPIO.Interrupts).
   procedure Attach
     (Dev    : Device;
      Action : Callback;
      On     : Trigger := ESP32S3.GPIO.Interrupts.Rising_Edge);

   --  Stop delivering Dev's INT interrupt.  No-op if Dev has no INT pin.
   procedure Detach (Dev : Device);

end ESP32S3.GT911.Interrupts;
