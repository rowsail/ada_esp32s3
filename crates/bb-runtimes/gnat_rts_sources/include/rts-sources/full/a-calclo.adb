------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                    A D A . C A L E N D A R . C L O C K                   --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                       Copyright (C) 2020-2025, AdaCore                   --
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

--  This is the bare metal Ravenscar runtime version of this function

with System.BB.Time;
with System.BB.Parameters; use System.BB.Parameters;

separate (Ada.Calendar)

-----------
-- Clock --
-----------

function Clock return Time is

   package SBBT renames System.BB.Time;

   use type SBBT.Time; --  a 64-bit unsigned number

   Elapsed_Ticks : constant SBBT.Time := SBBT.Clock - SBBT.Epoch;

   Elapsed_Seconds : Duration;
   Elapsed_Days    : Time'Base;

begin
   Elapsed_Seconds := Duration (Elapsed_Ticks / Ticks_Per_Second);
   Elapsed_Days := Elapsed_Seconds / Secs_Per_Day;
   return Radix_Time + Elapsed_Days;
end Clock;
