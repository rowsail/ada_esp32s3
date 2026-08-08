with ESP32S3.UART;
with ESP32S3.TWAI;

--  The parts of the demonstration that must live at library level.
--
--  The UART's RX ring is written by the interrupt service, so it cannot be a
--  stack object; and Jorvik's No_Task_Hierarchy forbids a task declared inside
--  the main procedure.  Both therefore live here.
package Demo_State is

   --  Caller-owned ring for ESP32S3.UART.Enable_Buffered_Rx.  Declared WITHOUT
   --  bounds, taking them from the initial value: its nominal subtype is then
   --  the unconstrained Byte_Array the access type designates, which is what
   --  lets a plain 'Access be taken of it.  Written with explicit bounds --
   --  "(0 .. 255) := (others => 0)" -- it would be a constrained subtype, and
   --  'Access is then illegal.
   Rx_Ring : aliased ESP32S3.UART.Byte_Array := (0 .. 255 => 0);

   --  The frame the CAN reader task took off the interrupt-driven queue.
   Can_Frame : ESP32S3.TWAI.Queued_Frame;
   Can_Got   : Boolean := False with Volatile;

   --  ESP32S3.TWAI.Get blocks until the shared slot's handler queues a frame
   --  and has no timeout, so it waits here rather than in the main flow: a
   --  frame that never arrives leaves this task parked instead of hanging the
   --  report.
   task Can_Reader;

end Demo_State;
