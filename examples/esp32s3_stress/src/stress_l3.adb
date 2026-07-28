with System.Machine_Code;    use System.Machine_Code;
with Interfaces;             use Interfaces;
with Ada.Real_Time;          use Ada.Real_Time;
with Ada.Interrupts.Names;
with Stress_State;

package body Stress_L3 is

   Int_Bit : constant Unsigned_32 := 2 ** 29;   --  CPU_INT 29 (SW_L3)

   --  Attaching this handler enables CPU_INT 29 on the elaborating core
   --  (core 0 -- library-level POs elaborate on the environment task).
   protected L3_PO
     with Interrupt_Priority => Ada.Interrupts.Names.Device_L3_Priority
   is
      procedure Handle;
      pragma Attach_Handler (Handle, Ada.Interrupts.Names.SW_L3);
   end L3_PO;

   protected body L3_PO is
      procedure Handle is
      begin
         --  Ack the software interrupt (clear its pending bit) so it does not
         --  immediately re-fire, then advance the heartbeat.
         Asm ("wsr.intclear %0",
              Inputs   => Unsigned_32'Asm_Input ("r", Int_Bit),
              Volatile => True);
         Stress_State.Beats (Stress_State.Beat_L3) :=
           Stress_State.Beats (Stress_State.Beat_L3) + 1;
      end Handle;
   end L3_PO;

   task body L3_Driver is
   begin
      loop
         --  Set CPU_INT 29 pending; it fires as soon as INTLEVEL permits --
         --  ideally mid-poke on core 0.  The short delay yields (so nothing
         --  starves) and hammers the alarm/systimer path alongside the storm.
         Asm ("wsr.intset %0",
              Inputs   => Unsigned_32'Asm_Input ("r", Int_Bit),
              Volatile => True);
         delay until Clock + Microseconds (40);
      end loop;
   end L3_Driver;

end Stress_L3;
