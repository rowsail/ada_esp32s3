------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                    S Y S T E M . S E M I H O S T I N G                   --
--                                                                          --
--                                 S p e c                                  --
--                                                                          --
--            Copyright (C) 2017-2025, Free Software Foundation, Inc.       --
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
-- GNAT was originally developed  by the GNAT team at  New York University. --
-- Extensive contributions were provided by Ada Core Technologies Inc.      --
--                                                                          --
------------------------------------------------------------------------------

--  Semihosting is a mechanism that enables I/O between target and host
--  computer using the debugger. Although based on ARM definition of
--  semihosting, the features described here can be implemented on virtually
--  any platform.

package System.Semihosting is
   pragma No_Elaboration_Code_All;
   pragma Preelaborate;

   type Exit_Reason is mod Memory_Size with Size => Word_Size;
   --  Reason code describing the cause of the trap passed to SYS_EXIT

   --  Hardware vector reason codes

   ADP_Stopped_BranchThroughZero   : constant Exit_Reason := 16#20000#;
   ADP_Stopped_UndefinedInstr      : constant Exit_Reason := 16#20001#;
   ADP_Stopped_SoftwareInterrupt   : constant Exit_Reason := 16#20002#;
   ADP_Stopped_PrefetchAbort       : constant Exit_Reason := 16#20003#;
   ADP_Stopped_DataAbort           : constant Exit_Reason := 16#20004#;
   ADP_Stopped_AddressException    : constant Exit_Reason := 16#20005#;
   ADP_Stopped_IRQ                 : constant Exit_Reason := 16#20006#;
   ADP_Stopped_FIQ                 : constant Exit_Reason := 16#20007#;

   --  Software reason codes

   ADP_Stopped_BreakPoint          : constant Exit_Reason := 16#20020#;
   ADP_Stopped_WatchPoint          : constant Exit_Reason := 16#20021#;
   ADP_Stopped_StepComplete        : constant Exit_Reason := 16#20022#;
   ADP_Stopped_RunTimeErrorUnknown : constant Exit_Reason := 16#20023#;
   ADP_Stopped_InternalError       : constant Exit_Reason := 16#20024#;
   ADP_Stopped_UserInterruption    : constant Exit_Reason := 16#20025#;
   ADP_Stopped_ApplicationExit     : constant Exit_Reason := 16#20026#;
   ADP_Stopped_StackOverflow       : constant Exit_Reason := 16#20027#;
   ADP_Stopped_DivisionByZero      : constant Exit_Reason := 16#20028#;
   ADP_Stopped_OSSpecific          : constant Exit_Reason := 16#20029#;

   type Exit_Subcode is range -Memory_Size / 2 .. (Memory_Size / 2) - 1 with
     Size => Word_Size;

   procedure SH_Exit (Reason : Exit_Reason; Subcode : Exit_Subcode);
   --  Report an exception to the debugger directly.
   --
   --  No return is expected from these calls. However, it is possible for
   --  the debugger to request that the application continues by performing an
   --  RDI_Execute request or equivalent, in which case this procedure
   --  returns.
   --
   --  The meaning of the subcode depends on the reason code. In particular,
   --  for ADP_Stopped_ApplicationExit the subcode is the exit status code.
   --  Note that the subcode is ignored on 32-bit semihosting implementations.

   procedure Put (Item : Character);
   --  Put a character on the console

   procedure Put (Item : String);
   --  Put a string on the console

   procedure Get (Item : out Character);
   --  Get one character from the console

end System.Semihosting;
