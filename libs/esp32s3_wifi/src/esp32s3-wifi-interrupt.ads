--  WMAC interrupt integration with the Jorvik runtime.
--
--  The GNAT runtime (GNARL) OWNS the Xtensa level-2..5 interrupt vectors and
--  dispatches them to Ada protected handlers registered via Attach_Handler.
--  Installing the blob's ISR through the bare xt_set_interrupt_handler is
--  therefore invisible to GNARL and faults in its dispatcher.  Instead we attach
--  a real protected handler to a free Device_L2 interrupt (Device_L2_1 = CPU int
--  20; UART already uses Device_L2_0 = 19) and have it call the blob's C handler.
--  The OS-adapter set_isr/set_intr slots feed this package; ints_on is a no-op
--  because attaching the handler already enables the CPU interrupt.
with Interfaces;
with System;

private package ESP32S3.WiFi.Interrupt is

   --  The CPU interrupt the WMAC source is routed to (Ada.Interrupts.Names
   --  .Device_L2_1).  set_intr routes the peripheral source here.
   WMAC_CPU_Int : constant := 20;

   --  Record the blob's ISR (from the OS-adapter set_isr slot).
   procedure Set_Handler (F : System.Address; Arg : System.Address);

   --  Route a peripheral interrupt source to WMAC_CPU_Int (from set_intr).
   procedure Route_Source (Source : Interfaces.Integer_32);

end ESP32S3.WiFi.Interrupt;
