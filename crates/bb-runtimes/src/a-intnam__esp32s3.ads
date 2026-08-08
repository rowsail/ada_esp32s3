------------------------------------------------------------------------------
--                                                                          --
--                  GNAT RUN-TIME LIBRARY (GNARL) COMPONENTS                --
--                                                                          --
--                   A D A . I N T E R R U P T S . N A M E S                --
--                                                                          --
--                                  S p e c                                 --
--                                                                          --
--          Copyright (C) 1991-2016, Free Software Foundation, Inc.         --
--                                                                          --
-- GNAT is free software;  you can  redistribute it  and/or modify it under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  GNAT is distributed in the hope that it will be useful, but WITH- --
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

--  This is the ESP32-S3 (Xtensa LX7) version.

with System;

package Ada.Interrupts.Names is

   --  All identifiers in this unit are implementation defined

   pragma Implementation_Defined;

   --  ESP32-S3 CPU interrupts (0 .. 31).  A peripheral interrupt SOURCE is
   --  routed through the interrupt matrix to one of these CPU interrupt
   --  numbers; the number's fixed Xtensa level fixes its Ada priority (see
   --  Priority_Of_Interrupt in s-bbbosu__esp32s3.adb).  Attach a protected
   --  handler to the CPU interrupt the source is routed to, with the matching
   --  ceiling priority below.  The names here cover the interrupts free for
   --  device handlers; what the kernel keeps for itself is NOT named, so
   --  claiming it is a compile error rather than a field failure.

   --  Level-2 device interrupts (ceiling Device_L2_Priority):
   Device_L2_0 : constant Interrupt_ID := 19;
   Device_L2_1 : constant Interrupt_ID := 20;

   --  CPU_INT 21 is NOT named, because the KERNEL owns it.  bare_boot routes
   --  BOTH the SYSTIMER alarm and the cross-core FROM_CPU poke onto it (the
   --  only matrix-drivable slot at level <= 3), and Level2_Dispatch reads the
   --  FROM_CPU register to tell them apart.  A device handler there displaces
   --  the scheduler's tick and its cross-core wakeups -- the machinery behind
   --  the hardest faults this port has had.  Naming it invited exactly that:
   --  it read as the third free level-2 slot.

   --  Level-3 device interrupts (ceiling Device_L3_Priority):
   Device_L3_0 : constant Interrupt_ID := 23;
   Device_L3_1 : constant Interrupt_ID := 27;
   SW_L3       : constant Interrupt_ID := 29;  --  software (wsr.intset)

   --  Levels 4 and 5 have NO native dispatcher (only Level2_Dispatch /
   --  Level3_Dispatch exist; level 5 parks), so no attachable name is exported
   --  for them: a handler there would fire into an unhandled vector and crash.
   --  Attaching to one is thus a compile error (undefined name) rather than a
   --  field crash; a raw-literal escape is caught at elaboration by
   --  Install_Interrupt_Handler.

   --  Kernel-reserved -- do NOT attach application handlers.  Both are level-5
   --  IDs from the ORIGINAL design, kept for reference: the live tick and poke
   --  are on CPU_INT 21 (see above), because a level-5 tick could preempt a
   --  register-window spill mid-rotation and corrupt WINDOWSTART.  Both are
   --  caught at elaboration anyway -- level 5 has no dispatcher.
   Tick_Interrupt : constant Interrupt_ID := 16;  --  CCOMPARE2 (level 5)
   Poke_Interrupt : constant Interrupt_ID := 31;  --  cross-core IPI (level 5)

   --  Ceiling priorities matching each level (= Priority_Of_Interrupt):
   Device_L2_Priority : constant System.Interrupt_Priority :=
     System.Interrupt_Priority'Last - 3;
   Device_L3_Priority : constant System.Interrupt_Priority :=
     System.Interrupt_Priority'Last - 2;

end Ada.Interrupts.Names;
