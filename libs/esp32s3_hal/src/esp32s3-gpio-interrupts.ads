with Ada.Interrupts.Names;

--  GPIO pin interrupts for the ESP32-S3 bare-metal (Jorvik) runtime.
--
--  The GPIO peripheral has one interrupt SOURCE (the OR of all pins' latched
--  status); this module routes it through the interrupt matrix to the runtime's
--  level-3 device slot (Ada.Interrupts.Names.Device_L3_0 = CPU_INT 23) and owns
--  the ISR there.  The ISR demuxes by GPIO status and runs your per-pin
--  callback.
--
--  Ravenscar/Jorvik attaches handlers statically, so the application does not
--  pass an ISR -- it registers a per-pin Callback that this module's ISR calls.
--  That Callback runs in INTERRUPT context (inside a protected action at the
--  level-3 ceiling): keep it short, and don't call a lower-ceiling protected
--  object or block.  The usual idiom is to bump an Atomic flag or Set a
--  Suspension_Object that a normal task is waiting on, and do the real work
--  there.
--
--  Requires a tasking runtime.

package ESP32S3.GPIO.Interrupts is

   --  What raises the interrupt on the pin.
   type Trigger is
     (Rising_Edge, Falling_Edge, Any_Edge, Low_Level, High_Level);

   --  Per-pin action, run in interrupt context (see the note above).
   type Callback is access procedure;

   --  Enable Pin's interrupt with the given trigger and action.  On first use
   --  this also routes the GPIO source to the level-3 device slot.  The pin's
   --  input buffer must be on (ESP32S3.GPIO.Configure already enables it).
   procedure Enable (Pin : Pin_Id; On : Trigger; Action : Callback);

   --  Stop delivering Pin's interrupt.
   procedure Disable (Pin : Pin_Id);

end ESP32S3.GPIO.Interrupts;
