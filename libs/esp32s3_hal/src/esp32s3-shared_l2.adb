with Ada.Interrupts.Names;

package body ESP32S3.Shared_L2 is

   type Service_Table is array (1 .. Max_Tenants) of Service_Proc;

   --  Everything lives in the protected object, so the table is read by the
   --  handler and written by Register under the same ceiling -- a driver may
   --  register while another tenant's interrupt is already live.
   protected Dispatcher
     with Interrupt_Priority => Ada.Interrupts.Names.Device_L2_Priority
   is
      procedure Add (Service : not null Service_Proc);
      function Holds (Service : not null Service_Proc) return Boolean;
      function Count return Natural;
      function Runs return Natural;
   private
      procedure Handler
        with Attach_Handler => Ada.Interrupts.Names.Device_L2_0;

      Services : Service_Table := (others => null);
      N        : Natural := 0;
      Ran      : Natural := 0;
   end Dispatcher;

   protected body Dispatcher is

      function Holds (Service : not null Service_Proc) return Boolean is
      begin
         for I in 1 .. N loop
            if Services (I) = Service then
               return True;
            end if;
         end loop;
         return False;
      end Holds;

      function Count return Natural is (N);
      function Runs return Natural is (Ran);

      procedure Add (Service : not null Service_Proc) is
      begin
         if Holds (Service) or else N = Max_Tenants then
            return;
         end if;
         N := N + 1;
         Services (N) := Service;
      end Add;

      --  The CPU interrupt says only that SOMETHING on the slot asserted, so
      --  ask each tenant in turn; each returns at once if its own peripheral's
      --  status says the interrupt was not its.  Order is registration order
      --  and carries no meaning: two sources may assert together, and both are
      --  serviced in one pass.
      procedure Handler is
      begin
         Ran := Ran + 1;
         for I in 1 .. N loop
            Services (I).all;
         end loop;
      end Handler;

   end Dispatcher;

   procedure Register (Service : not null Service_Proc) is
   begin
      Dispatcher.Add (Service);
   end Register;

   function Registered (Service : not null Service_Proc) return Boolean
   is (Dispatcher.Holds (Service));

   function Tenant_Count return Natural is (Dispatcher.Count);

   function Dispatches return Natural is (Dispatcher.Runs);

end ESP32S3.Shared_L2;
