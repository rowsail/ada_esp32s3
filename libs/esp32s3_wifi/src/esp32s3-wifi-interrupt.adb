with Ada.Interrupts.Names;
with Ada.Unchecked_Conversion;

package body ESP32S3.WiFi.Interrupt is

   use type System.Address;

   --  The blob's ISR: void (*)(void *arg), plus its argument.
   type C_Isr is access procedure (Arg : System.Address) with Convention => C;
   function To_Isr is new Ada.Unchecked_Conversion (System.Address, C_Isr);

   Blob_Isr : System.Address := System.Null_Address;
   Blob_Arg : System.Address := System.Null_Address;

   procedure Rom_Route_Intr_Matrix
     (Cpu, Source, Num : Interfaces.Integer_32)
     with Import, Convention => C, External_Name => "esp_rom_route_intr_matrix";

   --  Protected handler attached to Device_L2_1 (CPU int 20).  GNARL dispatches
   --  the level-2 interrupt here; we call the blob's C ISR from within the
   --  protected action (runs at the Device_L2 ceiling, preempting the tasks).
   protected WMAC_ISR
     with Interrupt_Priority => Ada.Interrupts.Names.Device_L2_Priority
   is
      procedure Handler
        with Attach_Handler => Ada.Interrupts.Names.Device_L2_1;
   end WMAC_ISR;

   protected body WMAC_ISR is
      procedure Handler is
      begin
         if Blob_Isr /= System.Null_Address then
            To_Isr (Blob_Isr) (Blob_Arg);
         end if;
      end Handler;
   end WMAC_ISR;

   procedure Set_Handler (F : System.Address; Arg : System.Address) is
   begin
      Blob_Isr := F;
      Blob_Arg := Arg;
   end Set_Handler;

   procedure Route_Source (Source : Interfaces.Integer_32) is
   begin
      Rom_Route_Intr_Matrix (0, Source, WMAC_CPU_Int);
   end Route_Source;

   --  CPU int 20 is enabled by the GNARL Attach_Handler; the WMAC RX ISR is now
   --  safe once ESP32S3.WiFi.Port.Register_Wpa_Stub has populated g_ic+0x1b4.
end ESP32S3.WiFi.Interrupt;
