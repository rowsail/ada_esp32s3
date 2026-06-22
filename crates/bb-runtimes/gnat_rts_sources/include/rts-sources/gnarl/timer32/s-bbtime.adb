------------------------------------------------------------------------------
--                                                                          --
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                                                                          --
--                         S Y S T E M . B B . T I M E                      --
--                                                                          --
--                                  B o d y                                 --
--                                                                          --
--        Copyright (C) 1999-2002 Universidad Politecnica de Madrid         --
--             Copyright (C) 2003-2005 The European Space Agency            --
--                     Copyright (C) 2003-2025, AdaCore                     --
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
-- GNARL was developed by the GNARL team at Florida State University.       --
-- Extensive contributions were provided by Ada Core Technologies, Inc.     --
--                                                                          --
-- The port of GNARL to bare board targets was initially developed by the   --
-- Real-Time Systems Group at the Technical University of Madrid.           --
--                                                                          --
------------------------------------------------------------------------------

pragma Restrictions (No_Elaboration_Code);

with System.BB.Interrupts;
with System.BB.Board_Support;
with System.BB.Protection;
with System.BB.Parameters;
with System.BB.Threads.Queues;
with System.BB.Timing_Events;
with System.Multiprocessors.Fair_Locks;

package body System.BB.Time is

   use Board_Support.Time;
   use Parameters;
   use Board_Support.Multiprocessors;
   use System.Multiprocessors;
   use System.Multiprocessors.Fair_Locks;
   use Threads, Threads.Queues;

   -----------------------
   -- Local definitions --
   -----------------------

   Alarm_Lock : Fair_Lock := (Spinning => (others => False),
                              Lock     => (Flag   => 0));
   --  Used to protect access to shared alarm resources
   --  (Timer configuration and Pending_Alarm variable)

   subtype Clock_Interval is Board_Support.Time.Timer_Interval;

   type Clock_Periods is mod 2 ** 32;
   for Clock_Periods'Size use 32;

   function "&" (Left : Clock_Periods; Right : Clock_Interval) return Time is
     (Time (Left) * (Time (Max_Timer_Interval) + 1) + Time (Right));
   --  Combine MSP and LSP of clock to form time

   Periods_In_Epoch : constant Clock_Periods := 1;
   --  Epoch starts at 1 (not 0) so Unsynchronized_Clock can ignore an
   --  in-progress update and return an early time instead.

   type Composite_Time is record
      MSP : Clock_Periods  := Periods_In_Epoch;
      pragma Atomic (MSP);
      LSP : Clock_Interval := 0;
      pragma Atomic (LSP);
   end record;
   --  Time representation used for the software clock, allowing concurrent
   --  updates and reads, see Update_Clock.
   --
   --  Include a default expression for component LSP, even when not needed, to
   --  prevent the need for elaboration code to initialize default-initialized
   --  objects of this type (note that this package has a restriction
   --  No_Elaboration_Code).

   Software_Clock : Composite_Time;
   pragma Warnings (Off, Software_Clock);
   --  Vestigial: Read_Clock now reads the shared SYSTIMER directly, so the
   --  software clock is only seeded (never read back).  Suppress the
   --  assigned-but-never-read warning rather than unwind the donor
   --  Composite_Time machinery.
   --  Clock with same time-base as hardware clock, but allowing a larger
   --  range. This is always behind the actual time by less than one hardware
   --  clock period. See Update_Clock for read and update protocol.

   Pending_Alarm : array (CPU) of Time := (others => Time'Last);
   --  Time of the current alarm handled by the timer, PER CPU.  The hardware
   --  alarm (CCOMPARE2) and the Alarms_Table are per-core, so this bookkeeping
   --  must be too: a single global was clobbered cross-core (e.g. core1's idle
   --  clock-keeping Alarm_Handler reset it / re-armed it from its own empty
   --  queue, stranding a task alarm pending on core0 -- the CXD8002 hang).
   --  Used to tell whether an alarm is before the current one on this CPU,
   --  and so needs to re-configure that CPU's timer.

   Max_Sleep : Time := 0;
   --  The longest time we can sleep without updating the Software_Clock.
   --  Initialized by Initialize_Timers.

   -----------------------
   -- Local subprograms --
   -----------------------

   procedure Alarm_Handler (Interrupt : Interrupts.Interrupt_ID);
   --  Handler for the alarm interrupt

   procedure Update_Clock (Now : out Time);
   --  This procedure has to be executed at least once each period of the
   --  hardware clock. We also require that this procedure be called with
   --  interrupts disabled, to ensure no stale values will be written. Given
   --  that limitation, it is fine to do concurrent updates on SMP systems:
   --  no matter which update ultimately prevails, it can't be old. While, on
   --  SMP systems, the Period_Counter may not always be monotone, the time
   --  returned by Update_Clock and Clock is.

   -------------------
   -- Alarm_Handler --
   -------------------

   procedure Alarm_Handler (Interrupt : Interrupts.Interrupt_ID) is
      pragma Unreferenced (Interrupt);

      Now             : Time;
      Next_Alarm      : Time; -- Time

   begin
      --  Make sure there is an alarm pending.

      pragma Assert (Pending_Alarm (Current_CPU) /= Time'Last);

      Board_Support.Time.Clear_Alarm_Interrupt;

      --  The access to the queues must be protected

      Protection.Enter_Kernel;

      --  Reset Pending_Alarm before computing the next alarm time, as other
      --  processors may set alarms concurrently, and these alarms would be
      --  ignored otherwise. The alarm lock must be held for this.

      if Multiprocessor then
         Lock (Alarm_Lock);
         Pending_Alarm (Current_CPU) := Time'Last;
         Unlock (Alarm_Lock);

      --  No need for lock if not on multiprocessor

      else
         Pending_Alarm (Current_CPU) := Time'Last;
      end if;

      Update_Clock (Now);

      --  Ensure alarms will keep going to keep the software clock up-to-date.

      Next_Alarm := Now + Max_Sleep;

      --  Multiprocessor case special processing

      if Parameters.Multiprocessor then

         --  Wake any OTHER CPU whose alarm has expired but which has not yet
         --  serviced it (a poke runs its Poke_Handler).  We do NOT also arm
         --  THIS CPU's timer for another CPU's alarm: each CPU keeps its
         --  own CCOMPARE for its own alarms. That cross-core "shadow" arm only
         --  made an alarm storm + extra cross-core switches, leaving one
         --  core's timer vestigial -- part of the SMP delay-alarm-loss.

         for CPU_Id in CPU loop
            if CPU_Id /= Current_CPU
              and then Get_Next_Timeout (CPU_Id) <= Now
            then
               Board_Support.Multiprocessors.Poke_CPU (CPU_Id);
            end if;
         end loop;
      end if;

      --  Execute expired events of the current CPU

      Timing_Events.Execute_Expired_Timing_Events (Now);

      --  Wake up our alarms, and set any new alarm

      Wakeup_Expired_Alarms (Now);

      Next_Alarm := Time'Min (Get_Next_Timeout (Current_CPU), Next_Alarm);
      Update_Alarm (Next_Alarm);

      Protection.Leave_Kernel;
   end Alarm_Handler;

   -----------
   -- Clock --
   -----------

   function Clock return Time is
   begin
      --  Board_Support.Read_Clock is the ESP32-S3 SYSTIMER: a full, shared,
      --  monotone 64-bit clock (52-bit counter x15) read identically by both
      --  cores, so no Software_Clock reconstruction or SMP Update_In_Progress
      --  retry is needed -- that machinery only extends a 32-bit *wrapping*
      --  hardware counter, its cross-core retry stalled the busiest reader.
      --  Offset by Epoch so Clock stays >= Epoch (Ada.Calendar uses Clock -
      --  Epoch) and the top bit stays clear (safe Time_Span subtraction).
      return Epoch + Read_Clock;
   end Clock;

   -----------------
   -- Delay_Until --
   -----------------

   procedure Delay_Until (T : Time) is
      Now               : Time;
      Self              : Thread_Id;
      Inserted_As_First : Boolean;

   begin
      Protection.Enter_Kernel;

      Now := Clock;

      Self := Thread_Self;

      pragma Assert (Self.State = Runnable);

      --  Test if the alarm time is in the future

      if T > Now then

         --  Extract the thread from the ready queue. When a thread wants to
         --  wait for an alarm it becomes blocked.

         Self.State := Delayed;

         Extract (Self);

         --  Insert Thread_Id in the alarm queue (ordered by time) and if it
         --  was inserted at head then check if Alarm Time is closer than the
         --  next clock interrupt.

         Insert_Alarm (T, Self, Inserted_As_First);

         if Inserted_As_First then
            Update_Alarm (Get_Next_Timeout (Current_CPU));
         end if;

      else
         --  If alarm time is not in the future, the thread must yield the CPU

         Yield (Self);
      end if;

      Protection.Leave_Kernel;
   end Delay_Until;

   -----------
   -- Epoch --
   -----------

   function Epoch return Time is
   begin
      return Periods_In_Epoch & 0;
   end Epoch;

   ----------------------
   -- Get_Next_Timeout --
   ----------------------

   function Get_Next_Timeout (CPU_Id : CPU) return Time is
      Alarm_Time : constant Time := Get_Next_Alarm_Time (CPU_Id);
      Event_Time : constant Time := Timing_Events.Get_Next_Timeout (CPU_Id);
   begin
      return Time'Min (Alarm_Time, Event_Time);
   end Get_Next_Timeout;

   -----------------------
   -- Initialize_Timers --
   -----------------------

   procedure Initialize_Timers is
   begin
      --  There may never be more than Max_Timer_Interval clocks between
      --  updates of Software_Clock, or we lose track of time. Allow a 1/8th
      --  period safety for early wakeup. The alarm CPU should never have
      --  alarm interrupts disabled for longer than this, or we may miss
      --  clock updates.

      Max_Sleep := Time (Max_Timer_Interval / 8 * 7);

      --  Install alarm handler

      Board_Support.Time.Install_Alarm_Handler (Alarm_Handler'Access);

      --  It is important to initialize the software LSP with the value coming
      --  from the hardware. There is no guarantee that this hardware value is
      --  close to zero (it may have been initialized by monitor software with
      --  any value and at any moment in time). With this initialization we
      --  ensure that the first alarm is not too far (we need to ensure that
      --  the value in the software LSP is less than a period away from the
      --  actual value in hardware).

      Software_Clock.LSP := Clock_Interval (Read_Clock);

      --  Establish invariant that there always is a pending alarm at most
      --  Max_Sleep time in the future.

      Pending_Alarm (Current_CPU) := Clock + Max_Sleep;
      Board_Support.Time.Set_Alarm (Clock_Interval (Max_Sleep));
   end Initialize_Timers;

   -------------------
   --  Update_Alarm --
   -------------------

   procedure Update_Alarm (Alarm : Time) is
      Now             : constant Time := Clock;
      Time_Difference : Time;

   begin
      --  On multiprocessors we want to do the entire procedure while holding
      --  the alarm lock, as we shouldn't read or update the Pending_Alarm
      --  variable, or program the alarm, concurrently with another update.

      if Parameters.Multiprocessor then
         Lock (Alarm_Lock);
      end if;

      if Alarm <= Now then

         --  If alarm is in the past, set the minimum timer value so the
         --  interrupt will be triggered as soon as possible.

         Time_Difference := 1;

      else
         Time_Difference := Alarm - Now;
      end if;

      Time_Difference := Time'Min (Time_Difference, Max_Sleep);

      --  If next alarm time is closer than the currently pending alarm,
      --  reprogram the alarm.

      if Alarm < Pending_Alarm (Current_CPU) then
         pragma Assert (Time_Difference in 1 .. Max_Sleep);

         Board_Support.Time.Set_Alarm (Clock_Interval (Time_Difference));
         Pending_Alarm (Current_CPU) := Alarm;
      end if;

      if Parameters.Multiprocessor then
         Unlock (Alarm_Lock);
      end if;
   end Update_Alarm;

   -----------------
   -- Rearm_Alarm --
   -----------------

   procedure Rearm_Alarm is
      Now        : constant Time := Clock;
      Next_Alarm : Time := Now + Max_Sleep;

   begin
      --  Poke_Handler woke this CPU's expired alarms but did NOT re-arm the
      --  timer; the queue head advanced yet Pending_Alarm still holds the
      --  (passed) woken alarm's time, so plain Update_Alarm is refused by its
      --  "closer than Pending_Alarm" guard.  Reset Pending_Alarm (as
      --  Alarm_Handler does), then reprogram for the next alarm or Max_Sleep.

      if Parameters.Multiprocessor then
         Lock (Alarm_Lock);
         Pending_Alarm (Current_CPU) := Time'Last;
         Unlock (Alarm_Lock);
      else
         Pending_Alarm (Current_CPU) := Time'Last;
      end if;

      Next_Alarm := Time'Min (Get_Next_Timeout (Current_CPU), Next_Alarm);
      Update_Alarm (Next_Alarm);
   end Rearm_Alarm;

   ------------------
   -- Update_Clock --
   ------------------

   --  Must be called from within Kernel (interrupts disabled). Must only be
   --  called from one processor at a time.

   procedure Update_Clock (Now : out Time) is
   begin
      --  Clock is now the full shared SYSTIMER (no 32-bit wrap to track), so
      --  the Software_Clock needs no periodic update; just return the time.
      Now := Epoch + Read_Clock;
   end Update_Clock;
end System.BB.Time;
