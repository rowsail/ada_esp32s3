with Ada.Synchronous_Task_Control; use Ada.Synchronous_Task_Control;
with Interfaces;                   use Interfaces;
with Stress_State;

package body Stress_Pingpong is

   --  Suspension-object pairs

   SO_A1, SO_B1 : Suspension_Object;
   SO_A2, SO_B2 : Suspension_Object;

   --  Entry pair: each side waits on its own entry; the other core's
   --  procedure call opens the barrier

   protected Court_A with Priority => 15 is
      entry Wait;
      procedure Serve;
   private
      Open : Boolean := False;
   end Court_A;

   protected body Court_A is
      entry Wait when Open is
      begin
         Open := False;
      end Wait;
      procedure Serve is
      begin
         Open := True;
      end Serve;
   end Court_A;

   protected Court_B with Priority => 15 is
      entry Wait;
      procedure Serve;
   private
      Open : Boolean := False;
   end Court_B;

   protected body Court_B is
      entry Wait when Open is
      begin
         Open := False;
      end Wait;
      procedure Serve is
      begin
         Open := True;
      end Serve;
   end Court_B;

   task body Ping_A1 is
   begin
      loop
         Set_True (SO_B1);
         Suspend_Until_True (SO_A1);
         Stress_State.Beats (Stress_State.Beat_Ping_A1) :=
           Stress_State.Beats (Stress_State.Beat_Ping_A1) + 1;
      end loop;
   end Ping_A1;

   task body Ping_B1 is
   begin
      loop
         Suspend_Until_True (SO_B1);
         Set_True (SO_A1);
         Stress_State.Beats (Stress_State.Beat_Ping_B1) :=
           Stress_State.Beats (Stress_State.Beat_Ping_B1) + 1;
      end loop;
   end Ping_B1;

   task body Ping_A2 is
   begin
      loop
         Set_True (SO_B2);
         Suspend_Until_True (SO_A2);
         Stress_State.Beats (Stress_State.Beat_Ping_A2) :=
           Stress_State.Beats (Stress_State.Beat_Ping_A2) + 1;
      end loop;
   end Ping_A2;

   task body Ping_B2 is
   begin
      loop
         Suspend_Until_True (SO_B2);
         Set_True (SO_A2);
         Stress_State.Beats (Stress_State.Beat_Ping_B2) :=
           Stress_State.Beats (Stress_State.Beat_Ping_B2) + 1;
      end loop;
   end Ping_B2;

   task body Entry_A is
   begin
      loop
         Court_B.Serve;
         Court_A.Wait;
         Stress_State.Beats (Stress_State.Beat_Entry_A) :=
           Stress_State.Beats (Stress_State.Beat_Entry_A) + 1;
      end loop;
   end Entry_A;

   task body Entry_B is
   begin
      loop
         Court_B.Wait;
         Court_A.Serve;
         Stress_State.Beats (Stress_State.Beat_Entry_B) :=
           Stress_State.Beats (Stress_State.Beat_Entry_B) + 1;
      end loop;
   end Entry_B;

end Stress_Pingpong;
