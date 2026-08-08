--  One owner for the level-2 device interrupt, so several drivers can use it.
--
--  Ada allows exactly ONE protected handler per Interrupt_ID: a second
--  Attach_Handler raises Program_Error inside System.BB.Interrupts, at
--  ELABORATION -- a boot loop, not a runtime error you can catch and report.
--  With only two dispatched device slots at level 2 (CPU_INT 19 and 20) and two
--  at level 3, "one driver, one interrupt" runs out almost immediately: the
--  buffered UART receiver and the TWAI (CAN) receiver both wanted CPU_INT 19,
--  so no image could contain both.
--
--  The ESP32-S3 interrupt matrix is happy to OR several peripheral sources onto
--  one CPU interrupt; what is missing is a way to tell them apart afterwards,
--  since the CPU interrupt says only "something asserted".  Each source has to
--  be asked.  That is exactly what the runtime already does for CPU_INT 21,
--  where the kernel's own tick and cross-core poke share a slot and
--  Level2_Dispatch reads the FROM_CPU register to decide which fired.
--
--  So: this package owns Device_L2_0 (CPU_INT 19), and drivers REGISTER with it
--  instead of attaching.  On each interrupt every registered service is called
--  in turn, and each looks at its own peripheral's status and returns
--  immediately if the interrupt was not its.  Drivers already work that way --
--  a handler that checks its own cause before acting is simply correct -- so
--  registering costs nothing but the calls.
--
--     procedure Service is           --  library-level: no trampolines
--     begin
--        Rx_Ctrl.Service;            --  a protected procedure, same ceiling
--     end Service;
--
--     ESP32S3.Shared_L2.Register (Service'Access);   --  where you route + enable
--
--  Registration is idempotent, so a driver may register from a routine that
--  runs more than once (per port, per re-open).  It is also the moment to do
--  it: registering where the interrupt is routed and enabled keeps the two from
--  drifting apart, and avoids depending on elaboration order.
--
--  A service runs at Device_L2_Priority inside this package's protected object,
--  so it is mutually exclusive with every other service and with any protected
--  operation at that ceiling.  Keep one short: every microsecond spent here
--  delays every other tenant of the slot, and the level-3 devices above it
--  (the LCD bounce refill) have deadlines.
--
--  Embedded/full profiles only (protected interrupt handlers).

package ESP32S3.Shared_L2 is

   --  Services registered on the slot.  Six is far more than the HAL has
   --  drivers for it; the array is static, so the cost of headroom is bytes.
   Max_Tenants : constant := 6;

   --  A parameterless library-level procedure.  The HAL's drivers are all
   --  singletons -- one UART engine, one TWAI engine -- so there is nothing a
   --  context parameter would carry.
   type Service_Proc is access procedure;

   --  Add Service to the slot.  Calling twice with the same procedure is a
   --  no-op, not a second registration.  Silently ignored once Max_Tenants are
   --  registered -- see Registered, which a driver can check if it wants to
   --  fail loudly instead.
   procedure Register (Service : not null Service_Proc);

   --  Is this service registered?
   function Registered (Service : not null Service_Proc) return Boolean;

   --  How many services the slot currently has.
   function Tenant_Count return Natural
     with Post => Tenant_Count'Result <= Max_Tenants;

   --  How many times the shared handler has run.  Answers "is my interrupt
   --  arriving at all?" without a debugger, which is the first question when a
   --  newly-registered driver stays silent.
   function Dispatches return Natural;

end ESP32S3.Shared_L2;
