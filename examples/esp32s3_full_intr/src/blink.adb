pragma Warnings (Off);
with Ada.Interrupts.Names;
with System;
with Intr_Vector_Test; use Intr_Vector_Test;   --  Clear_L2 / Clear_L3 (was glue.c)

--  L2/L3 interrupt handlers for the vector regression test.  Two library-level
--  protected objects attach to the L2 and L3 device interrupts -- on this port
--  Device_L2_0 = CPU_INT 19 and Device_L3_0 = CPU_INT 23.  example.adb fires
--  them via the FROM_CPU interrupt-matrix sources; each handler clears its
--  (level-triggered) source and counts.  This exercises __gnat_level2_vector /
--  __gnat_level3_vector (whose XT_STK frame build now masks debug across the
--  per-task stack watchpoint).  The handlers must be closure-free and
--  library-level -- a captured-environment handler would need a GNAT trampoline,
--  which faults on this part (No_Implicit_Dynamic_Code).

package body Blink is

   protected L2_PO
     with Interrupt_Priority => Ada.Interrupts.Names.Device_L2_Priority
   is
      function Count return Integer;
   private
      procedure Handle;
      pragma Attach_Handler (Handle, Ada.Interrupts.Names.Device_L2_0);
      Fired : Integer := 0;    --  times the L2 handler has run
   end L2_PO;

   protected body L2_PO is
      procedure Handle is
      begin
         Clear_L2;
         Fired := Fired + 1;
      end Handle;
      function Count return Integer
      is (Fired);
   end L2_PO;

   protected L3_PO
     with Interrupt_Priority => Ada.Interrupts.Names.Device_L3_Priority
   is
      function Count return Integer;
   private
      procedure Handle;
      pragma Attach_Handler (Handle, Ada.Interrupts.Names.Device_L3_0);
      Fired : Integer := 0;    --  times the L3 handler has run
   end L3_PO;

   protected body L3_PO is
      procedure Handle is
      begin
         Clear_L3;
         Fired := Fired + 1;
      end Handle;
      function Count return Integer
      is (Fired);
   end L3_PO;

   function L2_Count return Integer
   is (L2_PO.Count);
   function L3_Count return Integer
   is (L3_PO.Count);

end Blink;
