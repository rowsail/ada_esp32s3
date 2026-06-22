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
   --  ceiling priority below.  The kernel reserves level 5 (tick + cross-core
   --  poke); the names below cover the interrupts free for device handlers.

   --  Level-2 device interrupts (ceiling Device_L2_Priority):
   Device_L2_0 : constant Interrupt_ID := 19;
   Device_L2_1 : constant Interrupt_ID := 20;
   Device_L2_2 : constant Interrupt_ID := 21;

   --  Level-3 device interrupts (ceiling Device_L3_Priority):
   Device_L3_0 : constant Interrupt_ID := 23;
   Device_L3_1 : constant Interrupt_ID := 27;
   SW_L3       : constant Interrupt_ID := 29;  --  software (wsr.intset)

   --  Level-4 device interrupt (ceiling Device_L4_Priority):
   Device_L4_0 : constant Interrupt_ID := 30;

   --  Kernel-reserved -- do NOT attach application handlers:
   Tick_Interrupt : constant Interrupt_ID := 16;  --  CCOMPARE2 (level 5)
   Poke_Interrupt : constant Interrupt_ID := 31;  --  cross-core IPI (level 5)

   --  Ceiling priorities matching each level (= Priority_Of_Interrupt):
   Device_L2_Priority : constant System.Interrupt_Priority :=
     System.Interrupt_Priority'Last - 3;
   Device_L3_Priority : constant System.Interrupt_Priority :=
     System.Interrupt_Priority'Last - 2;
   Device_L4_Priority : constant System.Interrupt_Priority :=
     System.Interrupt_Priority'Last - 1;

end Ada.Interrupts.Names;
