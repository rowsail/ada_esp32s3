------------------------------------------------------------------------------
--                                                                          --
--                 GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                 --
--                                                                          --
--                 SYSTEM.BB.CPU_PRIMITIVES.MULTIPROCESSORS                 --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                     Copyright (C) 2010-2025, AdaCore                     --
--                                                                          --
-- GNARL is free software; you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion. GNARL is distributed in the hope that it will be useful, but WITH- --
-- OUT ANY WARRANTY;  without even the  implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE.                                     --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
------------------------------------------------------------------------------

pragma Restrictions (No_Elaboration_Code);

with System.Multiprocessors;
with System.BB.Board_Support;
with System.BB.Threads.Queues;
with System.BB.Protection;
with System.BB.Timing_Events;
with System.BB.Time;

package body System.BB.CPU_Primitives.Multiprocessors is
   use System.Multiprocessors;

   Slaves_Started : Boolean := False;
   pragma Atomic (Slaves_Started);
   --  Guards the slave bring-up so Start_All_CPUs is idempotent: it can be
   --  triggered early (the first time the environment task blocks, so a
   --  cross-core task created during elaboration actually runs) and the
   --  binder's end-of-adainit call then becomes a no-op.

   --------------------
   -- Start_All_CPUs --
   --------------------

   procedure Start_All_CPUs is
   begin
      --  Nothing to do when there's only one CPU

      if System.Multiprocessors.Number_Of_CPUs = 1 then
         return;
      end if;

      --  Start the slaves at most once

      if Slaves_Started then
         return;
      end if;
      Slaves_Started := True;

      System.BB.Board_Support.Multiprocessors.Start_All_CPUs;
   end Start_All_CPUs;

   ------------------
   -- Poke_Handler --
   ------------------

   procedure Poke_Handler is
      Now : Time.Time;

   begin
      --  The access to the queues must be protected

      Protection.Enter_Kernel;

      --  Handle alarms in the case the alarm is system-wide

      Now := Time.Clock;

      --  Execute expired events of the current CPU

      Timing_Events.Execute_Expired_Timing_Events (Now);

      --  Wake up alarms

      Threads.Queues.Wakeup_Expired_Alarms (Now);

      --  Prompt delay-abort: a remote CPU may have asked us to alarm-cancel a
      --  task Delayed on this CPU (it cannot touch our per-CPU alarm queue).

      Threads.Queues.Run_Cross_Cancel;

      --  Re-arm this CPU's timer for its next pending alarm (this poke path
      --  does NOT otherwise reprogram CCOMPARE -> the next alarm is lost).

      Time.Rearm_Alarm;

      Protection.Leave_Kernel;
   end Poke_Handler;

   ------------------
   -- Cancel_Delay --
   ------------------

   function Cancel_Delay
     (Thread : System.BB.Threads.Thread_Id) return Boolean is
      use type System.BB.Threads.Thread_States;
      Thread_CPU : constant System.Multiprocessors.CPU :=
                     Threads.Get_CPU (Thread);
      Handled    : Boolean;
   begin
      Protection.Enter_Kernel;

      if Thread_CPU /=
           System.BB.Board_Support.Multiprocessors.Current_CPU
      then
         --  Cross-core wakeup of ANY state.  The target's ready and alarm
         --  queues are private to its own CPU, so record the request and Poke
         --  that CPU, whose Poke_Handler calls Run_Cross_Cancel to wake it
         --  locally (Delayed -> cancel alarm, Suspended -> Runnable+Insert).
         --  This serves both the cross-core delay-abort and any other cross-
         --  core wakeup -- notably a task on another core completing its
         --  activation handshake with a Suspended waiter (e.g. the env).

         Threads.Queues.Request_Cross_Cancel (Thread);
         System.BB.Board_Support.Multiprocessors.Poke_CPU (Thread_CPU);
         Handled := True;

      elsif Thread.State = Threads.Delayed then
         --  Same core, blocked in a delay: unlink the alarm and make Runnable.
         --  It resumes from Delay_Until and raises Abort_Signal at its
         --  Abort_Undefer -- the wake the timer would do at expiry, now.

         Threads.Queues.Cancel_Alarm (Thread);
         Handled := True;

      else
         --  Same core, not Delayed (Suspended / Runnable): the ordinary BB
         --  Wakeup handles it correctly, so let the caller use that.

         Handled := False;
      end if;

      Protection.Leave_Kernel;
      return Handled;
   end Cancel_Delay;

end System.BB.CPU_Primitives.Multiprocessors;
