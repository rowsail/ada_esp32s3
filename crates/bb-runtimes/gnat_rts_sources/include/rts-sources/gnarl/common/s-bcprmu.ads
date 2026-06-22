------------------------------------------------------------------------------
--                                                                          --
--                 GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                 --
--                                                                          --
--                 SYSTEM.BB.CPU_PRIMITIVES.MULTIPROCESSORS                 --
--                                                                          --
--                                 S p e c                                  --
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

with System.BB.Threads;

package System.BB.CPU_Primitives.Multiprocessors is
   pragma Preelaborate;

   procedure Poke_Handler;
   --  Handler for the Poke interrupt

   procedure Start_All_CPUs;
   pragma Export (C, Start_All_CPUs, "__gnat_start_slave_cpus");
   --  Start all CPUs

   function Cancel_Delay (Thread : System.BB.Threads.Thread_Id) return Boolean;
   --  Prompt delay-abort.  If Thread is blocked in Delay_Until (BB-Delayed),
   --  unlink its alarm and make it Runnable now -- so abort takes effect at
   --  once, not at the delay's natural expiry -- and return True.  Same-core:
   --  done directly.  Cross-core (alarm in the other CPU's queue): record the
   --  request and Poke that CPU, whose Poke_Handler runs the cancel; still
   --  return True.  Return False (doing nothing) if Thread is not Delayed; the
   --  caller then uses the ordinary Wakeup (which mishandles BB-Delayed).
   --  Here because this layer has the kernel lock, alarm queue, CPU identity
   --  and Poke together, and can with Threads without the circularity that
   --  System.BB.Time (which Threads itself withs) would create.

end System.BB.CPU_Primitives.Multiprocessors;
