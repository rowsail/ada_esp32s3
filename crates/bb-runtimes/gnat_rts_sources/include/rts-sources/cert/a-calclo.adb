------------------------------------------------------------------------------
--                                                                          --
--                         GNAT RUN-TIME COMPONENTS                         --
--                                                                          --
--                    A D A . C A L E N D A R . C L O C K                   --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--                    Copyright (C) 2012-2025, AdaCore                      --
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

--  This is the Deos version of this package. Requires to be linked with
--  libtime.

with Interfaces.C; use Interfaces.C;
with System.Parameters;

separate (Ada.Calendar)

-----------
-- Clock --
-----------

function Clock return Time is

   --  Deos Definitions

   type time_t is range -2 ** (System.Parameters.time_t_bits - 1)
     .. 2 ** (System.Parameters.time_t_bits - 1) - 1;

   type timespec is record
      ts_sec  : time_t;
      ts_nsec : long;
   end record;
   pragma Convention (C, timespec);

   type clockid_t is new int;
   CLOCK_REALTIME : constant clockid_t := 1;

   function clock_gettime
     (clock_id : clockid_t;
      tp       : not null access timespec) return int;
   pragma Import (C, clock_gettime, "clock_gettime");
   --  Time elapsed since the epoch (0H UT 1/1/1970)

   TS     : aliased timespec;
   Result : int;

   Elapsed_Seconds : Duration;
   Elapsed_Days    : Time;

begin
   Result := clock_gettime (CLOCK_REALTIME, TS'Unchecked_Access);
   pragma Assert (Result = 0);

   Elapsed_Seconds :=
     Duration (TS.ts_sec) + Duration (TS.ts_nsec) / 10#1#E9;
   Elapsed_Days := Elapsed_Seconds / Secs_Per_Day;

   return Radix_Time + Elapsed_Days;
end Clock;
