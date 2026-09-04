with System;
with Interfaces;                   use Interfaces;
with Ada.Real_Time;                use Ada.Real_Time;
with Ada.Synchronous_Task_Control; use Ada.Synchronous_Task_Control;
with ESP32S3.GPIO;
with ESP32S3.GPIO.Interrupts;
with ESP32S3.W5500.Sockets;

package body ESP32S3.W5500.Interrupts is

   use type ESP32S3.GPIO.Pad_Number;

   SIMR   : constant Unsigned_16 := 16#18#;   --  common: socket interrupt mask
   Sn_IMR : constant Unsigned_16 := 16#2C#;   --  socket: interrupt mask

   --  One per hardware socket; the owning task suspends on its own object.
   Events   : array (Socket_Id) of Suspension_Object;
   Is_Armed : Boolean := False
   with Volatile;

   procedure Signal_All is
   begin
      for I in Socket_Id loop
         Set_True (Events (I));
      end loop;
   end Signal_All;

   --  INTn ISR (interrupt context): no SPI here -- just wake the waiters, which
   --  re-read the chip from task context.
   procedure On_Int is
   begin
      Signal_All;
   end On_Int;

   --  Registered with the socket engine as its Event_Waiter.
   procedure Wait (Index : Socket_Id) is
   begin
      Suspend_Until_True (Events (Index));
   end Wait;

   --  Safety heartbeat (see the spec): bounds the worst-case wait if an edge is
   --  ever missed.  Idle unless armed.
   task Heartbeat
     with Priority => System.Priority'First + 1;
   task body Heartbeat is
      Period : constant Time_Span := Milliseconds (50);
      Next   : Time := Clock;
   begin
      loop
         Next := Next + Period;
         delay until Next;
         if Is_Armed then
            Signal_All;
         end if;
      end loop;
   end Heartbeat;

   procedure Enable (Dev : in out Device) is
   begin
      if Dev.Int = ESP32S3.GPIO.No_Pin then
         return;                       --  no INT line wired: keep polling

      end if;
      --  Enable socket interrupts on the chip: all sockets, all events.
      Write_U8 (Dev, Common_Regs, SIMR, 16#FF#);
      for I in Socket_Id loop
         Write_U8 (Dev, Socket_Regs (I), Sn_IMR, 16#FF#);
      end loop;
      --  Route the socket engine's blocking waits through us, then arm INTn.
      ESP32S3.W5500.Sockets.Set_Event_Waiter (Wait'Access);
      ESP32S3.GPIO.Interrupts.Enable
        (ESP32S3.GPIO.Pin_Id (Dev.Int),
         On     => ESP32S3.GPIO.Interrupts.Falling_Edge,
         Action => On_Int'Access);
      Is_Armed := True;
   end Enable;

   procedure Disable (Dev : in out Device) is
   begin
      Is_Armed := False;
      ESP32S3.W5500.Sockets.Set_Event_Waiter (null);
      if Dev.Int /= ESP32S3.GPIO.No_Pin then
         ESP32S3.GPIO.Interrupts.Disable (ESP32S3.GPIO.Pin_Id (Dev.Int));
      end if;
   end Disable;

   function Armed return Boolean
   is (Is_Armed);

end ESP32S3.W5500.Interrupts;
